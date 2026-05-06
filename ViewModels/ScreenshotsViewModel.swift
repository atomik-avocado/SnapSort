import Foundation
import Photos
import SwiftUI
import Combine

@MainActor
final class ScreenshotsViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    enum LoadState: Equatable {
        case idle
        case requestingPermission
        case permissionDenied
        case loading
        case classifying(done: Int, total: Int)
        case ready
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var groups: [AppGroup] = []
    @Published private(set) var totalScreenshots: Int = 0
    @Published var lastError: String?

    private let library: PhotoLibraryService
    private let coordinator: ClassificationCoordinator
    private let cache: ClassificationCache
    private let knownApps: KnownAppsStore

    private var assetsByID: [String: PHAsset] = [:]
    private var classifications: [String: String] = [:]
    private var fetchResultIDs: [String] = []
    private var observerRegistered = false
    private var hasBootstrapped = false
    private var lastClassifiedSignature: String?
    private var cancellables: Set<AnyCancellable> = []

    var isClassifying: Bool {
        if case .classifying = state { return true }
        return false
    }

    var pendingCount: Int {
        fetchResultIDs.reduce(into: 0) { acc, id in
            if classifications[id] == nil { acc += 1 }
        }
    }

    init(
        library: PhotoLibraryService,
        coordinator: ClassificationCoordinator,
        cache: ClassificationCache,
        knownApps: KnownAppsStore
    ) {
        self.library = library
        self.coordinator = coordinator
        self.cache = cache
        self.knownApps = knownApps
        super.init()

        // Re-sort when the user's known apps list changes meaningfully.
        // Debounced to avoid spamming the API when a batch is added.
        knownApps.$apps
            .map { $0.map(\.name).sorted().joined(separator: "|") }
            .removeDuplicates()
            .dropFirst() // skip initial value
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.handleKnownAppsChanged() }
            }
            .store(in: &cancellables)
    }

    deinit {
        if observerRegistered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }

    /// Initial app launch: get permission, fetch assets, classify any uncached.
    func bootstrap() async {
        let current = library.currentAuthorization()
        let granted: Bool
        switch current {
        case .notDetermined:
            state = .requestingPermission
            let result = await library.requestAuthorization()
            granted = (result == .authorized || result == .limited)
        case .authorized, .limited:
            granted = true
        default:
            granted = false
        }

        guard granted else {
            state = .permissionDenied
            return
        }

        if !observerRegistered {
            library.register(observer: self)
            observerRegistered = true
        }

        state = .loading
        await reloadAssets()
        await classifyUnclassified()
        hasBootstrapped = true
    }

    /// User-triggered: re-fetch the library and classify anything new.
    func sort() async {
        guard !isClassifying else { return }
        await reloadAssets()
        await classifyUnclassified()
    }

    /// Wipe all classifications and re-run sort with the current known-apps list.
    func forceResort() async {
        guard !isClassifying else { return }
        await cache.clearAll()
        classifications.removeAll()
        rebuildGroups()
        await reloadAssets()
        await classifyUnclassified()
    }

    func screenshots(for appName: String) -> [ScreenshotItem] {
        groups.first(where: { $0.name == appName })?.screenshots ?? []
    }

    func deleteScreenshot(_ item: ScreenshotItem) async {
        await deleteScreenshots([item])
    }

    /// Batch-delete screenshots. Used by the multi-select toolbar in DetailView.
    func deleteScreenshots(_ items: [ScreenshotItem]) async {
        guard !items.isEmpty else { return }
        do {
            try await library.deleteAssets(items.map(\.asset))
            for item in items {
                await cache.remove(item.id)
                classifications.removeValue(forKey: item.id)
            }
            rebuildGroups()
        } catch {
            // Deletion may fail if the user denies the system prompt.
        }
    }

    /// Delete every screenshot in the named groups. Used by Dashboard select mode.
    func deleteGroups(named groupNames: Set<String>) async {
        let toDelete = groups
            .filter { groupNames.contains($0.name) }
            .flatMap(\.screenshots)
        await deleteScreenshots(toDelete)
    }

    func dismissError() {
        lastError = nil
    }

    // MARK: - PHPhotoLibraryChangeObserver

    /// Library changed (new screenshot, deletion, etc). Refresh the asset
    /// list using *only* cached classifications — no API calls. The user
    /// must press Sort to classify any new screenshots.
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            await self.reloadAssets()
            if !self.isClassifying {
                self.state = .ready
            }
        }
    }

    // MARK: - Internal

    private func handleKnownAppsChanged() async {
        // Skip until bootstrap has completed at least once — otherwise the
        // first-launch flow (where AppDetectionView populates the list) would
        // immediately trigger an extra resort.
        guard hasBootstrapped else { return }
        guard !isClassifying else { return }

        let current = currentSignature()
        guard current != lastClassifiedSignature else { return }

        await forceResort()
    }

    private func currentSignature() -> String {
        knownApps.apps.map(\.name).sorted().joined(separator: "|")
    }

    private func reloadAssets() async {
        let assets = library.fetchScreenshots()
        let validIDs = Set(assets.map(\.localIdentifier))
        await cache.keep(only: validIDs)

        var byID: [String: PHAsset] = [:]
        byID.reserveCapacity(assets.count)
        for asset in assets { byID[asset.localIdentifier] = asset }
        self.assetsByID = byID
        self.fetchResultIDs = assets.map(\.localIdentifier)
        self.totalScreenshots = assets.count

        let cached = await cache.snapshot()
        self.classifications = cached
        rebuildGroups()
    }

    private func classifyUnclassified() async {
        let assets = fetchResultIDs.compactMap { assetsByID[$0] }
        let unclassified = assets.filter { classifications[$0.localIdentifier] == nil }

        guard !unclassified.isEmpty else {
            lastClassifiedSignature = currentSignature()
            state = .ready
            return
        }

        state = .classifying(done: 0, total: unclassified.count)

        let total = unclassified.count
        let counter = ProgressCounter()
        let appNames = knownApps.appNames

        await coordinator.classifyMissing(assets: unclassified, knownApps: appNames) { [weak self] id, name in
            let done = await counter.increment()
            guard let self else { return }
            await self.handleClassification(id: id, name: name, done: done, total: total)
        }

        if let err = await coordinator.lastErrorMessage {
            lastError = err
        }
        lastClassifiedSignature = currentSignature()
        state = .ready
    }

    private func handleClassification(id: String, name: String?, done: Int, total: Int) async {
        if let name {
            classifications[id] = name
            rebuildGroups()
        }
        if done < total {
            state = .classifying(done: done, total: total)
        }
    }

    private func rebuildGroups() {
        var bucket: [String: [ScreenshotItem]] = [:]

        for id in fetchResultIDs {
            guard let asset = assetsByID[id] else { continue }
            let name = classifications[id]
            guard let name else { continue }
            let item = ScreenshotItem(asset: asset, classifiedApp: name)
            bucket[name, default: []].append(item)
        }

        var groupModels: [AppGroup] = bucket.map { name, items in
            AppGroup(name: name, screenshots: items, pendingCount: 0)
        }
        groupModels.sort { lhs, rhs in
            if lhs.totalCount != rhs.totalCount { return lhs.totalCount > rhs.totalCount }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        groups = groupModels
    }
}

private actor ProgressCounter {
    private var value = 0
    func increment() -> Int {
        value += 1
        return value
    }
}
