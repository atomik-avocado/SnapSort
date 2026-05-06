import Foundation
import Combine

@MainActor
final class KnownAppsStore: ObservableObject {
    private static let appsKey = "SnapSort.KnownApps.v1"
    private static let setupKey = "SnapSort.KnownAppsSetupComplete.v1"

    @Published private(set) var apps: [KnownApp] = []
    @Published private(set) var hasCompletedSetup: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedSetup = defaults.bool(forKey: Self.setupKey)
        load()
    }

    var sortedApps: [KnownApp] {
        apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var appNames: [String] {
        sortedApps.map(\.name)
    }

    /// Add app names that came back from a detection pass. Returns the number of new apps added.
    @discardableResult
    func addDetected(_ names: [String]) -> Int {
        addBatch(names, source: .detected)
    }

    /// Add a single app the user typed in. No-op if it duplicates an existing entry.
    @discardableResult
    func addManual(_ name: String) -> Bool {
        addBatch([name], source: .manual) > 0
    }

    func remove(_ app: KnownApp) {
        apps.removeAll { $0.id == app.id }
        save()
    }

    func clearAll() {
        apps.removeAll()
        save()
    }

    func markSetupComplete() {
        hasCompletedSetup = true
        defaults.set(true, forKey: Self.setupKey)
    }

    func resetSetup() {
        hasCompletedSetup = false
        defaults.set(false, forKey: Self.setupKey)
    }

    // MARK: - Private

    @discardableResult
    private func addBatch(_ rawNames: [String], source: KnownApp.Source) -> Int {
        var existing = Set(apps.map(\.id))
        var added = 0
        for raw in rawNames {
            let normalized = AppGroupNormalizer.normalize(raw)
            if normalized.isEmpty || normalized.lowercased() == "unknown" { continue }
            let candidate = KnownApp(name: normalized, source: source)
            if existing.contains(candidate.id) { continue }
            apps.append(candidate)
            existing.insert(candidate.id)
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.appsKey) else { return }
        if let decoded = try? JSONDecoder().decode([KnownApp].self, from: data) {
            apps = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        defaults.set(data, forKey: Self.appsKey)
    }
}
