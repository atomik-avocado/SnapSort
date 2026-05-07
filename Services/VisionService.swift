import Foundation
import UIKit

/// Routes classification + detection to whichever backend the user has
/// selected — Mistral cloud or local Ollama.
actor VisionService {
    private let mistral: MistralClient
    private let ollama: OllamaClient
    private let config: ConfigStore

    init(mistral: MistralClient, ollama: OllamaClient, config: ConfigStore) {
        self.mistral = mistral
        self.ollama = ollama
        self.config = config
    }

    func classify(image: UIImage, knownApps: [String] = []) async throws -> String {
        switch await currentBackend() {
        case .mistral:
            return try await mistral.classify(image: image, knownApps: knownApps)
        case .ollama:
            return try await ollama.classify(image: image, knownApps: knownApps)
        }
    }

    func detectApps(in image: UIImage) async throws -> [String] {
        switch await currentBackend() {
        case .mistral:
            return try await mistral.detectApps(in: image)
        case .ollama:
            return try await ollama.detectApps(in: image)
        }
    }

    /// Returns the list of installed model tags. Mistral returns the static
    /// curated list; Ollama queries the running server.
    func availableModels() async throws -> [String] {
        switch await currentBackend() {
        case .mistral:
            return ConfigStore.availableMistralModels.map(\.id)
        case .ollama:
            return try await ollama.ping()
        }
    }

    private func currentBackend() async -> AIBackend {
        await MainActor.run { config.backend }
    }
}
