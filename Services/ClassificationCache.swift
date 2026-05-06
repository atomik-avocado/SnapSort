import Foundation

actor ClassificationCache {
    private static let storeKey = "SnapSort.ClassificationCache.v1"

    private var memory: [String: String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let dict = defaults.dictionary(forKey: Self.storeKey) as? [String: String] {
            self.memory = dict
        } else {
            self.memory = [:]
        }
    }

    func value(for localIdentifier: String) -> String? {
        memory[localIdentifier]
    }

    func snapshot() -> [String: String] {
        memory
    }

    func set(_ value: String, for localIdentifier: String) {
        memory[localIdentifier] = value
        persist()
    }

    func remove(_ localIdentifier: String) {
        memory.removeValue(forKey: localIdentifier)
        persist()
    }

    func clearAll() {
        guard !memory.isEmpty else { return }
        memory.removeAll()
        persist()
    }

    func keep(only validIdentifiers: Set<String>) {
        let toRemove = memory.keys.filter { !validIdentifiers.contains($0) }
        guard !toRemove.isEmpty else { return }
        for key in toRemove { memory.removeValue(forKey: key) }
        persist()
    }

    private func persist() {
        defaults.set(memory, forKey: Self.storeKey)
    }
}
