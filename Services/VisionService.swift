import Foundation
import UIKit

/// Thin wrapper around the Mistral AI vision client. Kept as a separate
/// type so call sites stay decoupled from the specific vendor.
actor VisionService {
    private let mistral: MistralClient

    init(mistral: MistralClient) {
        self.mistral = mistral
    }

    func classify(image: UIImage, knownApps: [String] = []) async throws -> String {
        try await mistral.classify(image: image, knownApps: knownApps)
    }

    func detectApps(in image: UIImage) async throws -> [String] {
        try await mistral.detectApps(in: image)
    }
}
