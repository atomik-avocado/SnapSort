import Foundation
import SwiftUI

struct AppGroup: Identifiable, Hashable {
    let name: String
    var screenshots: [ScreenshotItem]
    var pendingCount: Int

    var id: String { name }
    var totalCount: Int { screenshots.count }
    var hasPending: Bool { pendingCount > 0 }

    var initial: String {
        String(name.first ?? "?").uppercased()
    }

    var avatarColor: Color {
        let palette: [Color] = [
            Color(red: 0.95, green: 0.46, blue: 0.36),
            Color(red: 0.40, green: 0.62, blue: 0.95),
            Color(red: 0.51, green: 0.78, blue: 0.52),
            Color(red: 0.95, green: 0.72, blue: 0.30),
            Color(red: 0.69, green: 0.49, blue: 0.91),
            Color(red: 0.36, green: 0.78, blue: 0.78),
            Color(red: 0.95, green: 0.55, blue: 0.72),
            Color(red: 0.50, green: 0.55, blue: 0.65)
        ]
        let hash = abs(name.hashValue)
        return palette[hash % palette.count]
    }
}

enum AppGroupNormalizer {
    static func normalize(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?\"'"))
        guard !trimmed.isEmpty else { return "Unknown" }
        let lower = trimmed.lowercased()
        let words = lower.split(separator: " ")
        let cased = words.map { word -> String in
            let s = String(word)
            return s.prefix(1).uppercased() + s.dropFirst()
        }
        return cased.joined(separator: " ")
    }
}
