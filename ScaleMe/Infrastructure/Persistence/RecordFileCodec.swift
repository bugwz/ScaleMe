import Foundation

enum RecordFileCodec {
    static let currentSchemaVersion = 2

    fileprivate static let columns = [
        "id", "date", "weightKG", "profileRef", "deviceRef", "sourceRef", "isStable",
        "impedanceOhm", "secondaryImpedanceOhm", "bodyFatPercent", "muscleMassKG",
        "waterPercent", "visceralFat", "basalMetabolismKCal", "boneMassKG"
    ]

    static func encode(_ archive: MeasurementArchive, prettyPrinted: Bool) throws -> Data {
        let references = References(archive: archive)
        let value = OrderedJSONValue.object([
            ("schemaVersion", .number(String(currentSchemaVersion))),
            ("updatedAt", try dateValue(archive.updatedAt)),
            ("references", references.jsonValue),
            ("columns", .array(columns.map { .string($0) })),
            ("records", .array(try archive.measurements.map { try references.row(for: $0) })),
            ("deletedRecords", .array(try archive.deletedMeasurements
                .sorted { $0.id.uuidString < $1.id.uuidString }
                .map(deletedRecordValue)))
        ])
        return Data(value.rendered(prettyPrinted: prettyPrinted).utf8)
    }

    static func decode(_ data: Data) throws -> MeasurementArchive {
        let document = try JSONDecoder().decode(RecordDocument.self, from: data)
        guard document.schemaVersion == currentSchemaVersion else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported record schema version"
            ))
        }
        return try document.archive()
    }

    fileprivate static func dateValue(_ value: Date) throws -> OrderedJSONValue {
        .number(try numberString(value.timeIntervalSinceReferenceDate))
    }

    fileprivate static func numberValue(_ value: Double?) throws -> OrderedJSONValue {
        guard let value else { return .null }
        return .number(try numberString(value))
    }

    private static func deletedRecordValue(_ marker: DeletedMeasurementMarker) throws -> OrderedJSONValue {
        .object([
            ("id", .string(marker.id.uuidString)),
            ("date", try dateValue(marker.date)),
            ("weightKG", try numberValue(marker.weightKG)),
            ("source", .string(marker.source.rawValue)),
            ("deviceID", marker.deviceID.map { .string($0.uuidString) } ?? .null)
        ])
    }

    private static func numberString(_ value: Double) throws -> String {
        guard value.isFinite else {
            throw EncodingError.invalidValue(
                value,
                .init(codingPath: [], debugDescription: "Record values must be finite")
            )
        }
        if value.rounded() == value {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        return String(value)
    }
}

private struct DeviceReference: Codable, Hashable {
    var id: UUID?
    var name: String?

    var jsonValue: OrderedJSONValue {
        var pairs: [(String, OrderedJSONValue)] = []
        if let id { pairs.append(("id", .string(id.uuidString))) }
        if let name { pairs.append(("name", .string(name))) }
        return .object(pairs)
    }
}

private struct References {
    var profiles: [UUID]
    var devices: [DeviceReference]
    var sources: [MeasurementSource]

    private var profileIndex: [UUID: Int]
    private var deviceIndex: [DeviceReference: Int]
    private var sourceIndex: [MeasurementSource: Int]

    init(archive: MeasurementArchive) {
        profiles = Array(Set(archive.measurements.compactMap(\.profileID)))
            .sorted { $0.uuidString < $1.uuidString }
        devices = Array(Set(archive.measurements.compactMap { record in
            guard record.deviceID != nil || record.deviceName != nil else { return nil }
            return DeviceReference(id: record.deviceID, name: record.deviceName)
        })).sorted {
            ($0.id?.uuidString ?? "", $0.name ?? "") < ($1.id?.uuidString ?? "", $1.name ?? "")
        }
        sources = Array(Set(archive.measurements.map(\.source))).sorted { $0.rawValue < $1.rawValue }
        profileIndex = Dictionary(uniqueKeysWithValues: profiles.enumerated().map { ($1, $0) })
        deviceIndex = Dictionary(uniqueKeysWithValues: devices.enumerated().map { ($1, $0) })
        sourceIndex = Dictionary(uniqueKeysWithValues: sources.enumerated().map { ($1, $0) })
    }

    var jsonValue: OrderedJSONValue {
        .object([
            ("profiles", .array(profiles.map { .string($0.uuidString) })),
            ("devices", .array(devices.map(\.jsonValue))),
            ("sources", .array(sources.map { .string($0.rawValue) }))
        ])
    }

    func row(for record: BodyMeasurement) throws -> OrderedJSONValue {
        let device = DeviceReference(id: record.deviceID, name: record.deviceName)
        var values: [OrderedJSONValue] = [
            .string(record.id.uuidString),
            try RecordFileCodec.dateValue(record.date),
            try RecordFileCodec.numberValue(record.weightKG),
            record.profileID.flatMap { profileIndex[$0] }.map { .number(String($0)) } ?? .null,
            (record.deviceID != nil || record.deviceName != nil)
                ? deviceIndex[device].map { .number(String($0)) } ?? .null
                : .null,
            sourceIndex[record.source].map { .number(String($0)) } ?? .null,
            .bool(record.isStable),
            try RecordFileCodec.numberValue(record.impedanceOhm),
            try RecordFileCodec.numberValue(record.secondaryImpedanceOhm),
            try RecordFileCodec.numberValue(record.bodyFatPercent),
            try RecordFileCodec.numberValue(record.muscleMassKG),
            try RecordFileCodec.numberValue(record.waterPercent),
            try RecordFileCodec.numberValue(record.visceralFat),
            try RecordFileCodec.numberValue(record.basalMetabolismKCal),
            try RecordFileCodec.numberValue(record.boneMassKG)
        ]
        while case .null? = values.last { values.removeLast() }
        return .inlineArray(values)
    }
}

private struct RecordDocument: Decodable {
    var schemaVersion: Int
    var updatedAt: Date
    var references: ReferenceDocument
    var columns: [String]
    var records: [RecordRow]
    var deletedRecords: Set<DeletedMeasurementMarker>

    func archive() throws -> MeasurementArchive {
        guard columns == RecordFileCodec.columns else {
            throw dataCorrupted("Unsupported record columns")
        }
        let entries = try records.map { row in
            guard references.sources.indices.contains(row.sourceRef) else {
                throw dataCorrupted("Invalid source reference")
            }
            let profileID = try resolved(row.profileRef, in: references.profiles, name: "profile")
            let device = try resolved(row.deviceRef, in: references.devices, name: "device")
            return BodyMeasurement(
                id: row.id,
                date: row.date,
                weightKG: row.weightKG,
                impedanceOhm: row.impedanceOhm,
                secondaryImpedanceOhm: row.secondaryImpedanceOhm,
                bodyFatPercent: row.bodyFatPercent,
                muscleMassKG: row.muscleMassKG,
                waterPercent: row.waterPercent,
                visceralFat: row.visceralFat,
                basalMetabolismKCal: row.basalMetabolismKCal,
                boneMassKG: row.boneMassKG,
                source: references.sources[row.sourceRef],
                isStable: row.isStable,
                profileID: profileID,
                deviceID: device?.id,
                deviceName: device?.name
            )
        }
        return MeasurementArchive(
            updatedAt: updatedAt,
            measurements: entries,
            deletedMeasurements: deletedRecords
        )
    }

    private func resolved<T>(_ index: Int?, in values: [T], name: String) throws -> T? {
        guard let index else { return nil }
        guard values.indices.contains(index) else {
            throw dataCorrupted("Invalid \(name) reference")
        }
        return values[index]
    }

    private func dataCorrupted(_ description: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: description))
    }

    struct ReferenceDocument: Decodable {
        var profiles: [UUID]
        var devices: [DeviceReference]
        var sources: [MeasurementSource]
    }
}

private struct RecordRow: Decodable {
    var id: UUID
    var date: Date
    var weightKG: Double
    var profileRef: Int?
    var deviceRef: Int?
    var sourceRef: Int
    var isStable: Bool
    var impedanceOhm: Double?
    var secondaryImpedanceOhm: Double?
    var bodyFatPercent: Double?
    var muscleMassKG: Double?
    var waterPercent: Double?
    var visceralFat: Double?
    var basalMetabolismKCal: Double?
    var boneMassKG: Double?

    init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        id = try values.decode(UUID.self)
        date = try values.decode(Date.self)
        weightKG = try values.decode(Double.self)
        profileRef = try values.decodeIfPresent(Int.self)
        deviceRef = try values.decodeIfPresent(Int.self)
        sourceRef = try values.decode(Int.self)
        isStable = try values.decode(Bool.self)
        impedanceOhm = try Self.trailing(Double.self, from: &values)
        secondaryImpedanceOhm = try Self.trailing(Double.self, from: &values)
        bodyFatPercent = try Self.trailing(Double.self, from: &values)
        muscleMassKG = try Self.trailing(Double.self, from: &values)
        waterPercent = try Self.trailing(Double.self, from: &values)
        visceralFat = try Self.trailing(Double.self, from: &values)
        basalMetabolismKCal = try Self.trailing(Double.self, from: &values)
        boneMassKG = try Self.trailing(Double.self, from: &values)
        guard values.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: values,
                debugDescription: "Record contains too many columns"
            )
        }
    }

    private static func trailing<T: Decodable>(
        _ type: T.Type,
        from values: inout UnkeyedDecodingContainer
    ) throws -> T? {
        guard !values.isAtEnd else { return nil }
        return try values.decodeIfPresent(type)
    }
}
