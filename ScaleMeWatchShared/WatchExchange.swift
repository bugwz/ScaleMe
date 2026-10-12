import Foundation

/// Only presentation snapshots cross devices. The phone owns the archive.
struct WatchRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var weight: String
    var details: [WatchMetric]
    var device: String
}

struct WatchMetric: Codable, Equatable {
    var title: String
    var value: String
}

struct WatchSnapshot: Codable, Equatable {
    var generatedAt: Date
    var revision: UUID
    var language: String
    var profileID: UUID
    var profileName: String
    var isSimulation: Bool
    var records: [WatchRecord]
    var totalRecords: Int
}

struct WatchRequest: Codable {
    enum Action: String, Codable { case refresh, history }
    var id = UUID()
    var action: Action
    var profileID: UUID?
    var revision: UUID?
    var offset: Int = 0
}

struct WatchReply: Codable {
    var snapshot: WatchSnapshot
    var error: String?
    var history: [WatchRecord]?
    var offset: Int?
}

enum WatchExchange {
    static let pageSize = 20
    static let maximumPayloadBytes = 60_000

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let data = try JSONEncoder().encode(value)
        guard data.count <= maximumPayloadBytes else { throw CocoaError(.coderInvalidValue) }
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count <= maximumPayloadBytes else { throw CocoaError(.coderInvalidValue) }
        return try JSONDecoder().decode(type, from: data)
    }
}

/// Shared catalog, also usable before the first phone snapshot arrives.
enum WatchText {
    static func text(_ key: String, language: String? = nil) -> String {
        let bundle = language.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: "Watch")
    }
}
