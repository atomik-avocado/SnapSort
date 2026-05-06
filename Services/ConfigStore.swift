import Foundation
import Combine

@MainActor
final class ConfigStore: ObservableObject {
    private static let apiKeyKey = "MISTRAL_API_KEY"
    private static let modelKey  = "MISTRAL_MODEL"
    private static let plistName = "Config"

    static let defaultModel = "pixtral-12b-2409"

    /// Curated set of Mistral vision-capable models exposed in the
    /// Settings dropdown. Add or trim as Mistral's lineup evolves.
    struct ModelOption: Identifiable, Hashable {
        let id: String
        let name: String
        let tagline: String
    }

    static let availableModels: [ModelOption] = [
        ModelOption(
            id: "pixtral-12b-2409",
            name: "Pixtral 12B",
            tagline: "Fast · free-tier friendly · default"
        ),
        ModelOption(
            id: "pixtral-large-latest",
            name: "Pixtral Large",
            tagline: "Most accurate · slower · higher cost"
        ),
        ModelOption(
            id: "mistral-medium-latest",
            name: "Mistral Medium 3",
            tagline: "Balanced quality and speed"
        ),
        ModelOption(
            id: "mistral-small-latest",
            name: "Mistral Small 3",
            tagline: "Cheapest paid tier"
        )
    ]

    static func option(for id: String) -> ModelOption? {
        availableModels.first(where: { $0.id == id })
    }

    @Published private(set) var apiKey: String?
    @Published private(set) var modelOverride: String?

    init() {
        self.apiKey = Self.loadString(udKey: Self.apiKeyKey, plistKey: Self.apiKeyKey)
        self.modelOverride = Self.loadString(udKey: Self.modelKey, plistKey: Self.modelKey)
    }

    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var effectiveModel: String {
        modelOverride?.nonEmpty ?? Self.defaultModel
    }

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored: String? = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(stored, forKey: Self.apiKeyKey)
        self.apiKey = stored
    }

    func clearKey() {
        UserDefaults.standard.removeObject(forKey: Self.apiKeyKey)
        self.apiKey = nil
    }

    func saveModel(_ model: String) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored: String? = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(stored, forKey: Self.modelKey)
        self.modelOverride = stored
    }

    private static func loadString(udKey: String, plistKey: String) -> String? {
        if let plistValue = readPlistString(key: plistKey), !plistValue.isEmpty {
            return plistValue
        }
        let stored = UserDefaults.standard.string(forKey: udKey)
        return (stored?.isEmpty ?? true) ? nil : stored
    }

    private static func readPlistString(key: String) -> String? {
        guard
            let url = Bundle.main.url(forResource: plistName, withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization
                .propertyList(from: data, format: nil) as? [String: Any],
            let value = dict[key] as? String
        else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
