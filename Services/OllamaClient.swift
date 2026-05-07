import Foundation
import UIKit
import os.log

/// Ollama client. Calls the OpenAI-compatible Chat Completions endpoint
/// at <base>/v1/chat/completions. Auth header is omitted (Ollama's
/// default config doesn't require one).
///
/// Requires Ollama 0.4+ and a multimodal model (e.g. `llama3.2-vision`,
/// `llava`, `moondream`, `minicpm-v`). The user must run
/// `OLLAMA_HOST=0.0.0.0 ollama serve` so the iPhone can reach it on the LAN.
actor OllamaClient {
    enum ClientError: LocalizedError {
        case missingBaseURL
        case malformedBaseURL
        case encodingFailed
        case badResponse(Int, String?)
        case malformedResponse
        case offline

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "Ollama server URL is missing. Set one in Settings."
            case .malformedBaseURL:
                return "The Ollama server URL doesn't look right. Try http://192.168.x.x:11434"
            case .encodingFailed:
                return "Couldn't encode the screenshot for upload."
            case .badResponse(let code, let body):
                let snippet = body?.prefix(200).description ?? ""
                return "Ollama responded \(code). \(snippet)"
            case .malformedResponse:
                return "Ollama returned an unexpected response shape."
            case .offline:
                return "Couldn't reach the Ollama server. Is `ollama serve` running and bound to your LAN?"
            }
        }
    }

    private let session: URLSession
    private let config: ConfigStore
    private let log = Logger(subsystem: "com.snapsort.app", category: "OllamaClient")

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

    /// Verify that the Ollama server is reachable. Returns the list of
    /// installed model tags if successful. Used by the Settings "Test
    /// connection" button.
    func ping() async throws -> [String] {
        let baseURL = await MainActor.run { config.ollamaEffectiveBaseURL }
        guard let url = URL(string: trimmedURL(baseURL))?
            .appendingPathComponent("api/tags")
        else {
            throw ClientError.malformedBaseURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw ClientError.badResponse(code, body)
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                return models.compactMap { $0["name"] as? String }
            }
            return []
        } catch let urlError as URLError {
            log.error("Ollama ping URLError: \(urlError.localizedDescription, privacy: .public)")
            throw ClientError.offline
        }
    }

    // MARK: - Private

    private func chat(prompt: String, image: UIImage, maxTokens: Int) async throws -> String {
        let baseURL = await MainActor.run { config.ollamaEffectiveBaseURL }
        let model = await MainActor.run { config.ollamaEffectiveModel }
        guard !baseURL.isEmpty else { throw ClientError.missingBaseURL }
        guard let endpoint = URL(string: trimmedURL(baseURL))?
            .appendingPathComponent("v1/chat/completions")
        else {
            throw ClientError.malformedBaseURL
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
                        ["type": "image_url",
                         "image_url": ["url": dataURL]]
                    ]
                ]
            ],
            "max_tokens": maxTokens,
            "temperature": 0
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        // Local inference is slow; allow more time than the Mistral path.
        request.timeoutInterval = 180

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log.error("Ollama request failed: \(error.localizedDescription, privacy: .public)")
            throw ClientError.offline
        }
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)
            log.error("Ollama \(http.statusCode, privacy: .public): \(bodyText ?? "", privacy: .public)")
            throw ClientError.badResponse(http.statusCode, bodyText)
        }

        return try parseContent(from: data)
    }

    private func trimmedURL(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private static func snapToList(_ candidate: String, list: [String]) -> String? {
        let lowered = candidate.lowercased()
        if let exact = list.first(where: { $0.lowercased() == lowered }) {
            return exact
        }
        if let containing = list.first(where: { lowered.contains($0.lowercased()) }) {
            return containing
        }
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
            if !text.isEmpty { return text }
        }
        throw ClientError.malformedResponse
    }
}
