import Foundation

struct KnownApp: Identifiable, Hashable, Codable {
    enum Source: String, Codable {
        case detected
        case manual
    }

    var id: String { name.lowercased() }
    var name: String
    var source: Source
    var addedAt: Date

    init(name: String, source: Source, addedAt: Date = Date()) {
        self.name = name
        self.source = source
        self.addedAt = addedAt
    }
}
