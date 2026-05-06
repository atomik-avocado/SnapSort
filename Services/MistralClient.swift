import Foundation
import UIKit
import os.log

/// Mistral AI client. Uses La Plateforme's OpenAI-compatible Chat Completions
/// API at https://api.mistral.ai/v1/chat/completions with vision-capable
/// models such as `pixtral-12b-2409` and `pixtral-large-latest`.
actor MistralClient {
    enum ClientError: LocalizedError {
        case missingAPIKey
        case encodingFailed
        case badResponse(Int, String?)
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Mistral AI API key is missing. Add one in Settings."
            case .encodingFailed:
                return "Couldn't encode the screenshot for upload."
            case .badResponse(let code, let body):
                let snippet = body?.prefix(200).description ?? ""
                return "Mistral responded \(code). \(snippet)"
            case .malformedResponse:
                return "Mistral returned an unexpected response shape."
            }
        }
    }

    private let endpoint = URL(string: "https://api.mistral.ai/v1/chat/completions")!

    private let session: URLSession
    private let config: ConfigStore
    private let log = Logger(subsystem: "com.snapsort.app", category: "MistralClient")

    init(config: ConfigStore, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func classify(image: UIImage, knownApps: [String] = []) async throws -> String {
        let prompt: String
        if knownApps.isEmpty {
            prompt = "Identify which iOS or web app this screenshot was taken from. Respond with ONLY the app name as a single plain string. No punctuation, no quotes, no explanation. If you cannot identify it, respond with: Unknown"
        } else {
            let list = knownApps.map { "- \($0)" }.joined(separator: "\n")
            prompt = """
            You are sorting a screenshot into one of the user's installed apps.

            Pick EXACTLY ONE app from this list — these are the only valid answers:
            \(list)

            Rules:
            - You MUST choose one of the names above, copied exactly as written.
            - If you are unsure, pick your best guess. Never refuse, never invent a name, never respond with "Unknown".
            - Respond with ONLY the chosen app name. No punctuation, no quotes, no prefix, no explanation.
            """
        }
        let raw = try await chat(prompt: prompt, image: image, maxTokens: 32)
        let normalized = AppGroupNormalizer.normalize(raw)
        // If we constrained to a list, snap the response back to the closest
        // known name in case the model drifted (e.g. "Insta" → "Instagram").
        if !knownApps.isEmpty {
            return Self.snapToList(normalized, list: knownApps) ?? normalized
        }
        return normalized
    }

    func detectApps(in image: UIImage) async throws -> [String] {
        let prompt = """
        This is a screenshot of an iPhone Settings page that lists installed apps. \
        List every app name visible in the screenshot, one per line. \
        No numbering, no bullets, no explanation, no punctuation. \
        Just the app names exactly as they appear, one per line.
        """
        let raw = try await chat(prompt: prompt, image: image, maxTokens: 800)
        return raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Private

    private func chat(prompt: String, image: UIImage, maxTokens: Int) async throws -> String {
        let key = await MainActor.run { config.apiKey }
        let model = await MainActor.run { config.effectiveModel }
        guard let apiKey = key, !apiKey.isEmpty else {
            throw ClientError.missingAPIKey
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.5) else {
            throw ClientError.encodingFailed
        }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": dataURL]
                    ]
                ]
            ],
            "max_tokens": maxTokens,
            "temperature": 0
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)
            log.error("Mistral \(http.statusCode, privacy: .public): \(bodyText ?? "", privacy: .public)")
            throw ClientError.badResponse(http.statusCode, bodyText)
        }

        return try parseContent(from: data)
    }

    /// Snap the model's output to the closest known app name. Exact match first,
    /// then case-insensitive substring containment in either direction.
    private static func snapToList(_ candidate: String, list: [String]) -> String? {
        let lowered = candidate.lowercased()
        if let exact = list.first(where: { $0.lowercased() == lowered }) {
            return exact
        }
        // candidate contains a known name (e.g. "X (formerly Twitter)" → "X")
        if let containing = list.first(where: { lowered.contains($0.lowercased()) }) {
            return containing
        }
        // a known name contains the candidate (e.g. "insta" → "Instagram")
        if let contained = list.first(where: { $0.lowercased().contains(lowered) }) {
            return contained
        }
        return nil
    }

    private func parseContent(from data: Data) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            throw ClientError.malformedResponse
        }

        if let stringContent = message["content"] as? String {
            return stringContent
        }

        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
            if !text.isEmpty {
                return text
            }
        }

        throw ClientError.malformedResponse
    }
}
