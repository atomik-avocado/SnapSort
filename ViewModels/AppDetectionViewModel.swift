import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class AppDetectionViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loadingImages
        case detecting(done: Int, total: Int)
        case review(detected: [String], skipped: Int)
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle

    private let vision: VisionService
    private let knownAppsStore: KnownAppsStore

    init(vision: VisionService, knownAppsStore: KnownAppsStore) {
        self.vision = vision
        self.knownAppsStore = knownAppsStore
    }

    func process(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        phase = .loadingImages

        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        guard !images.isEmpty else {
            phase = .error("Couldn't load any of the selected screenshots.")
            return
        }

        phase = .detecting(done: 0, total: images.count)

        var allNames: Set<String> = []
        var failures = 0
        var lastError: String?

        for (index, image) in images.enumerated() {
            do {
                let names = try await vision.detectApps(in: image)
                for n in names {
                    let normalized = AppGroupNormalizer.normalize(n)
                    if !normalized.isEmpty, normalized.lowercased() != "unknown" {
                        allNames.insert(normalized)
                    }
                }
            } catch {
                failures += 1
                lastError = error.localizedDescription
            }
            phase = .detecting(done: index + 1, total: images.count)
        }

        if allNames.isEmpty {
            phase = .error(lastError ?? "No apps were recognized in those screenshots.")
            return
        }

        let sorted = allNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        phase = .review(detected: sorted, skipped: failures)
    }

    func saveDetected(_ names: [String]) {
        knownAppsStore.addDetected(names)
        knownAppsStore.markSetupComplete()
    }

    func skipSetup() {
        knownAppsStore.markSetupComplete()
    }

    func reset() {
        phase = .idle
    }
}
