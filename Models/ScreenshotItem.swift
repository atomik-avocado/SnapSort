import Foundation
import Photos

struct ScreenshotItem: Identifiable, Hashable {
    let asset: PHAsset
    var classifiedApp: String?

    var id: String { asset.localIdentifier }
    var creationDate: Date? { asset.creationDate }
    var isClassified: Bool { classifiedApp != nil }

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.id == rhs.id && lhs.classifiedApp == rhs.classifiedApp
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
