import Foundation

enum CommunicationRuleOrigin: String, Codable, CaseIterable {
    case builtIn
    case custom
    case community

    var title: String {
        switch self {
        case .builtIn: "应用内置"
        case .custom: "用户导入"
        case .community: "社区来源"
        }
    }
}

enum CommunicationTransport: String, Codable {
    case advertisementServiceData
    case characteristicNotification
}

enum CommunicationByteOrder: String, Codable {
    case littleEndian
    case bigEndian
}

enum CommunicationWeightUnit: String, Codable {
    case kilograms
    case pounds
    case jin
}

struct CommunicationField: Codable, Equatable, Hashable {
    var offset: Int
    var length: Int
    var byteOrder: CommunicationByteOrder = .littleEndian
    var scale: Double
    var add: Double = 0
}

struct CommunicationFlag: Codable, Equatable, Hashable {
    var offset: Int
    var mask: UInt8
    var equals: UInt8
}

struct CommunicationRuleMatch: Codable, Equatable, Hashable {
    var transport: CommunicationTransport
    var serviceUUID: String
    var characteristicUUID: String?
    var minimumLength: Int
    var maximumLength: Int?
    var prefixHex: String?
}

struct CommunicationRuleDecoder: Codable, Equatable, Hashable {
    var weight: CommunicationField
    var weightUnit: CommunicationWeightUnit = .kilograms
    var impedance: CommunicationField?
    var bodyFatPercent: CommunicationField?
    var muscleMassKG: CommunicationField?
    var waterPercent: CommunicationField?
    var visceralFat: CommunicationField?
    var basalMetabolismKCal: CommunicationField?
    var boneMassKG: CommunicationField?
    var stableWhen: CommunicationFlag?
    var removedWhen: CommunicationFlag?
}

struct CommunicationRule: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var version: Int
    var summary: String
    var author: String?
    var origin: CommunicationRuleOrigin
    var sourceURL: URL?
    var match: CommunicationRuleMatch
    var decoder: CommunicationRuleDecoder?
    var builtInParser: String?

    var isDeclarative: Bool { decoder != nil }
}

struct CommunicationRuleDocument: Codable, Equatable {
    var schemaVersion: Int
    var rules: [CommunicationRule]

    static let currentSchemaVersion = 1
}

enum CommunicationRuleError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidDocument(String)
    case unsupportedRemoteURL
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "不支持规则格式版本 \(version)"
        case .invalidDocument(let detail): "规则无效：\(detail)"
        case .unsupportedRemoteURL: "远程规则只允许使用 HTTPS 地址"
        case .responseTooLarge: "远程规则文件超过 512 KB 限制"
        }
    }
}

enum CommunicationRuleCatalog {
    static let bluetoothSIGWeightID = "app.scaleme.bluetooth-sig-weight"
    static let bluetoothSIGBodyID = "app.scaleme.bluetooth-sig-body-composition"
    static let xiaomiLegacyID = "app.scaleme.xiaomi-legacy-advertisement"
    static let icomonAFUID = "app.scaleme.icomon-afu"

    static let builtIn: [CommunicationRule] = [
        CommunicationRule(
            id: bluetoothSIGWeightID,
            name: "Bluetooth SIG 体重秤",
            version: 1,
            summary: "Weight Scale Service 0x181D / Weight Measurement 0x2A9D。",
            origin: .builtIn,
            match: .init(transport: .characteristicNotification, serviceUUID: "181D", characteristicUUID: "2A9D", minimumLength: 3),
            decoder: nil,
            builtInParser: "bluetoothSIGWeight"
        ),
        CommunicationRule(
            id: bluetoothSIGBodyID,
            name: "Bluetooth SIG 身体成分秤",
            version: 1,
            summary: "Body Composition Service 0x181B / Measurement 0x2A9C。",
            origin: .builtIn,
            match: .init(transport: .characteristicNotification, serviceUUID: "181B", characteristicUUID: "2A9C", minimumLength: 4),
            decoder: nil,
            builtInParser: "bluetoothSIGBodyComposition"
        ),
        CommunicationRule(
            id: xiaomiLegacyID,
            name: "小米传统广播协议",
            version: 1,
            summary: "解析 0x181B 服务广播中的体重、稳定状态、时间与阻抗。",
            origin: .builtIn,
            match: .init(transport: .advertisementServiceData, serviceUUID: "181B", characteristicUUID: nil, minimumLength: 13),
            decoder: nil,
            builtInParser: "xiaomiLegacyAdvertisement"
        ),
        CommunicationRule(
            id: icomonAFUID,
            name: "ICOMON AFU 协议",
            version: 1,
            summary: "适用于已有实测帧夹具的 AFU-WL-TZ-A1 / FG2313UWB-D。",
            origin: .builtIn,
            match: .init(transport: .characteristicNotification, serviceUUID: IcomonAFUScaleAdapter.serviceUUID, characteristicUUID: IcomonAFUScaleAdapter.measurementCharacteristicUUID, minimumLength: 20, maximumLength: 20),
            decoder: nil,
            builtInParser: "icomonAFU"
        )
    ]

    static func rules(custom: [CommunicationRule]) -> [CommunicationRule] {
        builtIn + custom.filter { rule in !builtIn.contains(where: { $0.id == rule.id }) }
    }
}

enum CommunicationRuleCodec {
    static let maximumDocumentBytes = 512 * 1_024

    static func decode(_ data: Data, importedFrom sourceURL: URL? = nil) throws -> [CommunicationRule] {
        guard data.count <= maximumDocumentBytes else { throw CommunicationRuleError.responseTooLarge }
        let document: CommunicationRuleDocument
        do {
            document = try JSONDecoder().decode(CommunicationRuleDocument.self, from: data)
        } catch {
            throw CommunicationRuleError.invalidDocument(error.localizedDescription)
        }
        guard document.schemaVersion == CommunicationRuleDocument.currentSchemaVersion else {
            throw CommunicationRuleError.unsupportedSchema(document.schemaVersion)
        }
        guard !document.rules.isEmpty, document.rules.count <= 64 else {
            throw CommunicationRuleError.invalidDocument("每个文件必须包含 1 至 64 条规则")
        }
        var ids = Set<String>()
        return try document.rules.map { rule in
            var normalized = rule
            normalized.origin = sourceURL == nil ? .custom : .community
            normalized.sourceURL = sourceURL
            normalized.match.serviceUUID = normalizeUUID(rule.match.serviceUUID)
            normalized.match.characteristicUUID = rule.match.characteristicUUID.map(normalizeUUID)
            try validate(normalized)
            guard ids.insert(normalized.id).inserted else {
                throw CommunicationRuleError.invalidDocument("规则 ID \(normalized.id) 重复")
            }
            return normalized
        }
    }

    static func encode(_ rules: [CommunicationRule], prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] }
        return try encoder.encode(CommunicationRuleDocument(schemaVersion: 1, rules: rules))
    }

    static func validate(_ rule: CommunicationRule) throws {
        guard rule.id.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$"#, options: .regularExpression) != nil else {
            throw CommunicationRuleError.invalidDocument("规则 ID 需为 3 至 128 位 ASCII 标识符")
        }
        guard !rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommunicationRuleError.invalidDocument("规则名称不能为空")
        }
        guard rule.version > 0 else { throw CommunicationRuleError.invalidDocument("规则版本必须大于 0") }
        guard rule.builtInParser == nil, let decoder = rule.decoder else {
            throw CommunicationRuleError.invalidDocument("外部规则只能使用声明式 decoder")
        }
        guard !rule.match.serviceUUID.isEmpty else { throw CommunicationRuleError.invalidDocument("serviceUUID 不能为空") }
        if rule.match.transport == .characteristicNotification,
           rule.match.characteristicUUID?.isEmpty != false {
            throw CommunicationRuleError.invalidDocument("特征通知规则必须提供 characteristicUUID")
        }
        guard (1...4_096).contains(rule.match.minimumLength) else {
            throw CommunicationRuleError.invalidDocument("minimumLength 必须在 1 至 4096 之间")
        }
        if let maximum = rule.match.maximumLength, maximum < rule.match.minimumLength || maximum > 4_096 {
            throw CommunicationRuleError.invalidDocument("maximumLength 范围无效")
        }
        if let prefix = rule.match.prefixHex {
            let bytes = try hexBytes(prefix)
            guard bytes.count <= rule.match.minimumLength else {
                throw CommunicationRuleError.invalidDocument("prefixHex 不能长于 minimumLength")
            }
        }
        let fields = [decoder.weight, decoder.impedance, decoder.bodyFatPercent, decoder.muscleMassKG,
                      decoder.waterPercent, decoder.visceralFat, decoder.basalMetabolismKCal, decoder.boneMassKG].compactMap { $0 }
        for field in fields {
            guard field.offset >= 0, (1...8).contains(field.length),
                  field.scale.isFinite, field.scale > 0, field.add.isFinite,
                  field.offset + field.length <= rule.match.minimumLength else {
                throw CommunicationRuleError.invalidDocument("字段范围或缩放值无效")
            }
        }
        for flag in [decoder.stableWhen, decoder.removedWhen].compactMap({ $0 }) {
            guard flag.offset >= 0, flag.offset < rule.match.minimumLength, flag.mask != 0,
                  flag.equals & ~flag.mask == 0 else {
                throw CommunicationRuleError.invalidDocument("状态标志范围无效")
            }
        }
    }

    static func normalizeUUID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func hexBytes(_ value: String) throws -> [UInt8] {
        let compact = value.filter { !$0.isWhitespace && $0 != ":" && $0 != "-" }
        guard !compact.isEmpty, compact.count.isMultiple(of: 2) else {
            throw CommunicationRuleError.invalidDocument("prefixHex 必须是偶数位十六进制")
        }
        var result: [UInt8] = []
        var index = compact.startIndex
        while index < compact.endIndex {
            let end = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<end], radix: 16) else {
                throw CommunicationRuleError.invalidDocument("prefixHex 含有非十六进制字符")
            }
            result.append(byte)
            index = end
        }
        return result
    }
}

enum CommunicationRulePacket {
    case measurement(BodyMeasurement)
    case weightRemoved
}

struct DeclarativeCommunicationRuleParser {
    static func matches(_ data: Data, rule: CommunicationRule) -> Bool {
        guard data.count >= rule.match.minimumLength else { return false }
        if let maximum = rule.match.maximumLength, data.count > maximum { return false }
        if let prefix = rule.match.prefixHex,
           let prefixBytes = try? CommunicationRuleCodec.hexBytes(prefix),
           !data.starts(with: prefixBytes) { return false }
        return true
    }

    static func parse(_ data: Data, rule: CommunicationRule, now: Date = .now) throws -> CommunicationRulePacket {
        guard matches(data, rule: rule), let decoder = rule.decoder else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](data)
        if let removed = decoder.removedWhen, flag(removed, bytes: bytes) { return .weightRemoved }
        let weightRaw = try value(decoder.weight, bytes: bytes)
        let weightKG: Double
        switch decoder.weightUnit {
        case .kilograms: weightKG = weightRaw
        case .pounds: weightKG = weightRaw * 0.453_592_37
        case .jin: weightKG = weightRaw * 0.5
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }
        let impedance = try decoder.impedance.map { try value($0, bytes: bytes) }
        if let impedance, !(50...3_000).contains(impedance) { throw ScalePayloadError.unsupported }
        let bodyFat = try decoder.bodyFatPercent.map { try value($0, bytes: bytes) }
        if let bodyFat, !(1...75).contains(bodyFat) { throw ScalePayloadError.unsupported }
        let stable = decoder.stableWhen.map { flag($0, bytes: bytes) } ?? false
        let muscle = try decoder.muscleMassKG.map { try value($0, bytes: bytes) }
        let water = try decoder.waterPercent.map { try value($0, bytes: bytes) }
        let visceral = try decoder.visceralFat.map { try value($0, bytes: bytes) }
        let metabolism = try decoder.basalMetabolismKCal.map { try value($0, bytes: bytes) }
        let bone = try decoder.boneMassKG.map { try value($0, bytes: bytes) }
        guard muscle.map({ (0...350).contains($0) }) ?? true,
              water.map({ (1...100).contains($0) }) ?? true,
              visceral.map({ (0...100).contains($0) }) ?? true,
              metabolism.map({ (100...10_000).contains($0) }) ?? true,
              bone.map({ (0...20).contains($0) }) ?? true else {
            throw ScalePayloadError.unsupported
        }
        return .measurement(BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: impedance,
            bodyFatPercent: bodyFat,
            muscleMassKG: muscle,
            waterPercent: water,
            visceralFat: visceral,
            basalMetabolismKCal: metabolism,
            boneMassKG: bone,
            source: .customProtocol,
            isStable: stable
        ))
    }

    private static func flag(_ condition: CommunicationFlag, bytes: [UInt8]) -> Bool {
        bytes.indices.contains(condition.offset) && bytes[condition.offset] & condition.mask == condition.equals
    }

    private static func value(_ field: CommunicationField, bytes: [UInt8]) throws -> Double {
        guard field.offset >= 0, field.length > 0, field.offset + field.length <= bytes.count else {
            throw ScalePayloadError.tooShort
        }
        let slice = bytes[field.offset..<(field.offset + field.length)]
        let raw: UInt64
        switch field.byteOrder {
        case .littleEndian:
            raw = slice.enumerated().reduce(0) { $0 | UInt64($1.element) << UInt64($1.offset * 8) }
        case .bigEndian:
            raw = slice.reduce(0) { $0 << 8 | UInt64($1) }
        }
        return Double(raw) * field.scale + field.add
    }
}
