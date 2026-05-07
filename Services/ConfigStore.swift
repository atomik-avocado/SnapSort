import Foundation
import Combine

@MainActor
final class ConfigStore: ObservableObject {
    // MARK: - Storage keys
    private static let backendKey         = "AI_BACKEND"
    private static let mistralKeyKey      = "MISTRAL_API_KEY"
    private static let mistralModelKey    = "MISTRAL_MODEL"
    private static let ollamaURLKey       = "OLLAMA_BASE_URL"
    private static let ollamaModelKey     = "OLLAMA_MODEL"
    private static let plistName = "Config"

    // MARK: - Mistral defaults & curated list
    nonisolated static let defaultMistralModel = "pixtral-12b-2409"

    struct ModelOption: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let tagline: String
    }

    nonisolated static let availableMistralModels: [ModelOption] = [
        ModelOption(id: "pixtral-12b-2409",
                    name: "Pixtral 12B",
                    tagline: "Fast · free-tier friendly · default"),
        ModelOption(id: "pixtral-large-latest",
                    name: "Pixtral Large",
                    tagline: "Most accurate · slower · higher cost"),
        ModelOption(id: "mistral-medium-latest",
                    name: "Mistral Medium 3",
                    tagline: "Balanced quality and speed"),
        ModelOption(id: "mistral-small-latest",
                    name: "Mistral Small 3",
                    tagline: "Cheapest paid tier")
    ]

    // MARK: - Ollama defaults
    nonisolated static let defaultOllamaBaseURL = "http://localhost:11434"
    nonisolated static let defaultOllamaModel = "llama3.2-vision"

    /// Common multimodal Ollama models. Surfaced as suggestions in Settings.
    nonisolated static let suggestedOllamaModels: [ModelOption] = [
        ModelOption(id: "llama3.2-vision",
                    name: "Llama 3.2 Vision (11B)",
                    tagline: "Meta · default · ~8 GB"),
        ModelOption(id: "llava",
                    name: "LLaVA 7B",
                    tagline: "Original LLaVA · ~4 GB · fast"),
        ModelOption(id: "llava:13b",
                    name: "LLaVA 13B",
                    tagline: "Sharper · ~8 GB"),
        ModelOption(id: "moondream",
                    name: "Moondream 2",
                    tagline: "Tiny · ~1.7 GB · for older Macs"),
        ModelOption(id: "minicpm-v",
                    name: "MiniCPM-V 2.6",
                    tagline: "Strong vision · ~5 GB"),
        ModelOption(id: "bakllava",
                    name: "BakLLaVA",
                    tagline: "Mistral 7B base · ~5 GB")
    ]

    // MARK: - Published state

    @Published private(set) var backend: AIBackend
    @Published private(set) var mistralKey: String?
    @Published private(set) var mistralModelOverride: String?
    @Published private(set) var ollamaBaseURL: String?
    @Published private(set) var ollamaModelOverride: String?

    init() {
        self.backend = Self.loadBackend()
        self.mistralKey = Self.loadString(udKey: Self.mistralKeyKey, plistKey: Self.mistralKeyKey)
        self.mistralModelOverride = Self.loadString(udKey: Self.mistralModelKey, plistKey: Self.mistralModelKey)
        self.ollamaBaseURL = Self.loadString(udKey: Self.ollamaURLKey, plistKey: Self.ollamaURLKey)
        self.ollamaModelOverride = Self.loadString(udKey: Self.ollamaModelKey, plistKey: Self.ollamaModelKey)
    }

    // MARK: - Resolved state

    /// Whether the active backend is configured well enough to make a request.
    var isReady: Bool {
        switch backend {
        case .mistral: return hasMistralKey
        case .ollama:  return hasOllamaURL
        }
    }

    var hasMistralKey: Bool {
        guard let k = mistralKey else { return false }
        return !k.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasOllamaURL: Bool {
        guard let url = ollamaBaseURL else { return false }
        return !url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var mistralEffectiveModel: String {
        mistralModelOverride?.nonEmpty ?? Self.defaultMistralModel
    }

    var ollamaEffectiveBaseURL: String {
        ollamaBaseURL?.nonEmpty ?? Self.defaultOllamaBaseURL
    }

    var ollamaEffectiveModel: String {
        ollamaModelOverride?.nonEmpty ?? Self.defaultOllamaModel
    }

    // MARK: - Mutators

    func setBackend(_ b: AIBackend) {
        backend = b
        UserDefaults.standard.set(b.rawValue, forKey: Self.backendKey)
    }

    func saveMistralKey(_ key: String) {
        let stored = trimmedOrNil(key)
        UserDefaults.standard.set(stored, forKey: Self.mistralKeyKey)
        self.mistralKey = stored
    }

    func clearMistralKey() {
        UserDefaults.standard.removeObject(forKey: Self.mistralKeyKey)
        self.mistralKey = nil
    }

    func saveMistralModel(_ model: String) {
        let stored = trimmedOrNil(model)
        UserDefaults.standard.set(stored, forKey: Self.mistralModelKey)
        self.mistralModelOverride = stored
    }

    func saveOllamaBaseURL(_ url: String) {
        let stored = trimmedOrNil(url)
        UserDefaults.standard.set(stored, forKey: Self.ollamaURLKey)
        self.ollamaBaseURL = stored
    }

    func clearOllamaBaseURL() {
        UserDefaults.standard.removeObject(forKey: Self.ollamaURLKey)
        self.ollamaBaseURL = nil
    }

    func saveOllamaModel(_ model: String) {
        let stored = trimmedOrNil(model)
        UserDefaults.standard.set(stored, forKey: Self.ollamaModelKey)
        self.ollamaModelOverride = stored
    }

    // MARK: - Lookup helpers

    nonisolated static func mistralOption(for id: String) -> ModelOption? {
        availableMistralModels.first(where: { $0.id == id })
    }

    nonisolated static func ollamaOption(for id: String) -> ModelOption? {
        suggestedOllamaModels.first(where: { $0.id == id })
    }

    // MARK: - Private

    private func trimmedOrNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func loadBackend() -> AIBackend {
        let raw = UserDefaults.standard.string(forKey: backendKey) ?? ""
        return AIBackend(rawValue: raw) ?? .mistral
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
