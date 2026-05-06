import Foundation
import Photos
import UIKit
import os.log

actor ClassificationCoordinator {
    private let vision: VisionService
    private let cache: ClassificationCache
    private let library: PhotoLibraryService
    private let maxConcurrent = 5
    private let log = Logger(subsystem: "com.snapsort.app", category: "ClassificationCoordinator")

    private var inFlight: Set<String> = []
    private(set) var lastErrorMessage: String?

    init(
        vision: VisionService,
        cache: ClassificationCache,
        library: PhotoLibraryService
    ) {
        self.vision = vision
        self.cache = cache
        self.library = library
    }

    func clearLastError() {
        lastErrorMessage = nil
    }

    /// Classifies any assets that don't already have a cached value.
    /// `onResult` fires after each individual asset finishes (success or failure).
    func classifyMissing(
        assets: [PHAsset],
        knownApps: [String],
        onResult: @Sendable @escaping (String, String?) async -> Void
    ) async {
        let cached = await cache.snapshot()
        let pending = assets.filter { cached[$0.localIdentifier] == nil }
        guard !pending.isEmpty else { return }

        lastErrorMessage = nil

        let batches = stride(from: 0, to: pending.count, by: maxConcurrent).map {
            Array(pending[$0..<min($0 + maxConcurrent, pending.count)])
        }

        for batch in batches {
            await withTaskGroup(of: (String, String?).self) { group in
                for asset in batch {
                    let id = asset.localIdentifier
                    if inFlight.contains(id) { continue }
                    inFlight.insert(id)
                    group.addTask { [weak self] in
                        let name = await self?.classifyOne(asset: asset, knownApps: knownApps)
                        return (id, name)
                    }
                }
                for await (id, name) in group {
                    inFlight.remove(id)
                    if let name {
                        await cache.set(name, for: id)
                    }
                    await onResult(id, name)
                }
            }
        }
    }

    private func classifyOne(asset: PHAsset, knownApps: [String]) async -> String? {
        guard let image = await library.loadClassificationImage(for: asset) else {
            log.error("Could not load image for asset \(asset.localIdentifier, privacy: .public)")
            return nil
        }
        do {
            let raw = try await vision.classify(image: image, knownApps: knownApps)
            let normalized = AppGroupNormalizer.normalize(raw)
            return normalized
        } catch {
            log.error("Classify failed for \(asset.localIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }
}
