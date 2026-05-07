import Foundation

enum AIBackend: String, CaseIterable, Identifiable, Codable {
    case mistral
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mistral: return "Mistral AI"
        case .ollama:  return "Ollama (local)"
        }
    }

    var shortName: String {
        switch self {
        case .mistral: return "Mistral"
        case .ollama:  return "Ollama"
        }
    }

    var iconName: String {
        switch self {
        case .mistral: return "cloud.fill"
        case .ollama:  return "macbook"
        }
    }

    var subtitle: String {
        switch self {
        case .mistral: return "Cloud · needs API key"
        case .ollama:  return "On your computer · no key needed"
        }
    }
}
