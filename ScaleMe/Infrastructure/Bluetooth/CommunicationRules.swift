import Foundation

enum CommunicationRuleOrigin: String, Codable, CaseIterable {
    case builtIn
    case custom
    case community

    var title: String {
        switch self {
        case .builtIn: "内置"
        case .custom: "本地导入"
        case .community: "在线导入"
        }
    }
}

enum ProtocolVerificationLevel: String, Codable {
    case standardSpecification
    case fixtureValidated
    case hardwareSample
    case unverified

    var title: String {
        switch self {
        case .standardSpecification: "标准规范"
        case .fixtureValidated: "数据样本验证"
        case .hardwareSample: "实机样本"
        case .unverified: "未经验证"
        }
    }
}

enum ProtocolImplementationLevel: String, Codable, CaseIterable {
    case executable
    case experimental
    case protocolSkeleton
    case unsupportedPlatform

    var title: String {
        switch self {
        case .executable: "可执行"
        case .experimental: "实验性"
        case .protocolSkeleton: "协议骨架"
        case .unsupportedPlatform: "平台不支持"
        }
    }

    var canMeasure: Bool {
        self == .executable || self == .experimental
    }
}

enum ProtocolRuntimeRequirement: String, Codable, CaseIterable, Hashable {
    case userProfile
    case timeSynchronization
    case bonding
    case consentCode
    case bindKey
    case encryption
    case vendorRegistration
    case multiFrameSession
    case historyStateMachine
    case keepAlive
    case classicBluetooth

    var title: String {
        switch self {
        case .userProfile: "需要成员资料"
        case .timeSynchronization: "需要时间同步"
        case .bonding: "需要系统配对"
        case .consentCode: "需要用户同意码"
        case .bindKey: "需要设备绑定密钥"
        case .encryption: "需要加密会话"
        case .vendorRegistration: "需要厂商应用预注册"
        case .multiFrameSession: "需要多帧状态机"
        case .historyStateMachine: "需要历史记录状态机"
        case .keepAlive: "需要持续保活"
        case .classicBluetooth: "需要经典蓝牙"
        }
    }
}

enum CommunicationTransport: String, Codable {
    case advertisementServiceData
    case advertisementManufacturerData
    case characteristicNotification
    case classicSPP
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

struct CommunicationDateDecoder: Codable, Equatable, Hashable {
    var year: CommunicationField
    var month: CommunicationField
    var day: CommunicationField
    var hour: CommunicationField
    var minute: CommunicationField
    var second: CommunicationField? = nil
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
    var date: CommunicationDateDecoder? = nil
}

struct CommunicationRuleSourceLink: Codable, Identifiable, Equatable, Hashable {
    var project: String
    var url: URL

    var id: String { url.absoluteString }
}

struct CommunicationRule: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var version: Int
    var summary: String
    var author: String?
    var origin: CommunicationRuleOrigin
    var sourceURL: URL?
    var sourceLinks: [CommunicationRuleSourceLink]? = nil
    var match: CommunicationRuleMatch
    var decoder: CommunicationRuleDecoder?
    var builtInParser: String?
    var verification: ProtocolVerificationLevel? = nil
    var operations: CommunicationRuleOperations? = nil
    var implementation: ProtocolImplementationLevel? = nil
    var supportedModels: [String]? = nil
    var requirements: [ProtocolRuntimeRequirement]? = nil
    var alternateMatches: [CommunicationRuleMatch]? = nil
    var notifyTargets: [CommunicationGATTTarget]? = nil
    var writeTargets: [CommunicationGATTTarget]? = nil

    var isDeclarative: Bool { decoder != nil }
    var effectiveVerification: ProtocolVerificationLevel { verification ?? .unverified }
    var effectiveImplementation: ProtocolImplementationLevel {
        implementation ?? ((decoder != nil || builtInParser != nil) ? .executable : .protocolSkeleton)
    }
    var canMeasure: Bool { effectiveImplementation.canMeasure }
    var allMatches: [CommunicationRuleMatch] { [match] + (alternateMatches ?? []) }
    var capabilities: Set<CommunicationOperationCapability> {
        var result = Set<CommunicationOperationCapability>()
        if operations?.historyRead != nil { result.insert(.historyRead) }
        if operations?.historyClear != nil { result.insert(.historyClear) }
        return result
    }
}

struct CommunicationRuleDocument: Codable, Equatable {
    var schemaVersion: Int
    var rules: [CommunicationRule]

    static let currentSchemaVersion = 2
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
    static let bluetoothSIGWeightID = "protocol.builtin.sig-weight"
    static let bluetoothSIGBodyID = "protocol.builtin.sig-body"
    static let huaweiHagridID = "protocol.builtin.huawei-hagrid"
    static let xiaomiLegacyID = "protocol.builtin.xiaomi-legacy"
    static let wolaiAFUID = "protocol.builtin.wolai-afu"
    static let qnAABBID = "protocol.builtin.qn-aabb"
    static let aaaSeriesID = "protocol.builtin.aaa-series"
    static let sinocareID = "protocol.builtin.sinocare"
    static let scaleupID = "protocol.builtin.scaleup"
    static let okokID = "protocol.builtin.okok"
    static let etekcityFit8SID = "protocol.builtin.fit8s"
    static let eufyC20ID = "protocol.builtin.eufy-c20"
    static let yunmaiXID = "protocol.builtin.yunmai-x"
    static let xiaomiMiScale2ID = "protocol.builtin.xiaomi-181d"
    static let silvergear108ID = "protocol.builtin.silvergear-108"

    private static let implemented: [CommunicationRule] = [
        CommunicationRule(
            id: bluetoothSIGWeightID,
            name: "SIG Weight",
            version: 1,
            summary: "Bluetooth SIG 标准体重服务（181D / 2A9D）。",
            origin: .builtIn,
            match: .init(transport: .characteristicNotification, serviceUUID: "181D", characteristicUUID: "2A9D", minimumLength: 3),
            decoder: nil,
            builtInParser: "bluetoothSIGWeight",
            verification: .standardSpecification
        ),
        CommunicationRule(
            id: bluetoothSIGBodyID,
            name: "SIG Body Composition",
            version: 1,
            summary: "Bluetooth SIG 标准体成分服务（181B / 2A9C）。",
            origin: .builtIn,
            match: .init(transport: .characteristicNotification, serviceUUID: "181B", characteristicUUID: "2A9C", minimumLength: 4),
            decoder: nil,
            builtInParser: "bluetoothSIGBodyComposition",
            verification: .standardSpecification
        ),
        CommunicationRule(
            id: huaweiHagridID,
            name: "Huawei Hagrid/WSP",
            version: 1,
            summary: "华为 Scale 2/3 私有连接协议；支持配置认证材料，完整认证与测量仍在适配。",
            origin: .builtIn,
            match: .init(
                transport: .characteristicNotification,
                serviceUUID: HuaweiHagridProtocol.userDataServiceUUID,
                characteristicUUID: HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID,
                minimumLength: 5
            ),
            decoder: nil,
            builtInParser: "huaweiHagridWSP",
            verification: .unverified,
            implementation: .protocolSkeleton,
            supportedModels: ["Huawei Scale 2", "Huawei Scale 3"],
            requirements: [.bindKey, .encryption, .multiFrameSession]
        ),
        CommunicationRule(
            id: xiaomiLegacyID,
            name: "Xiaomi 181B",
            version: 1,
            summary: "解析 0x181B 服务广播中的体重、稳定状态、时间与阻抗。",
            origin: .builtIn,
            match: .init(transport: .advertisementServiceData, serviceUUID: "181B", characteristicUUID: nil, minimumLength: 13),
            decoder: nil,
            builtInParser: "xiaomiLegacyAdvertisement",
            verification: .fixtureValidated,
            operations: CommunicationRuleOperations(
                historyRead: CommunicationGATTOperation(
                    capability: .historyRead,
                    subscriptions: [
                        CommunicationGATTTarget(
                            serviceUUID: "181B",
                            characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID
                        )
                    ],
                    commands: [
                        CommunicationCommand(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            payloadHexTemplate: "01968ABD62"
                        ),
                        CommunicationCommand(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            payloadHexTemplate: "01FFFFFFFF"
                        ),
                        CommunicationCommand(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            payloadHexTemplate: "02"
                        )
                    ],
                    completionCommands: [
                        CommunicationCommand(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            payloadHexTemplate: "03"
                        )
                    ],
                    acknowledgementCommands: [
                        CommunicationCommand(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            payloadHexTemplate: "04FFFFFFFF"
                        )
                    ],
                    historyResponse: CommunicationHistoryResponse(
                        recordMatcher: .init(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            minimumLength: 10,
                            maximumLength: 512
                        ),
                        completionMatcher: .init(
                            target: .init(serviceUUID: "181B", characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID),
                            minimumLength: 1,
                            maximumLength: 1,
                            exactHex: "03"
                        ),
                        framing: .fixedLength,
                        recordLength: 10,
                        builtInParser: "xiaomiHistory10"
                    )
                )
            )
        ),
        CommunicationRule(
            id: wolaiAFUID,
            name: "Wolai AFU",
            version: 1,
            summary: "适用于已有实机数据样本的 AFU-WL-TZ-A1 / FG2313UWB-D。",
            origin: .builtIn,
            match: .init(transport: .characteristicNotification, serviceUUID: WolaiAFUScaleAdapter.serviceUUID, characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID, minimumLength: 20, maximumLength: 20),
            decoder: nil,
            builtInParser: "wolaiAFU",
            verification: .hardwareSample
        ),
        CommunicationRule(
            id: qnAABBID,
            name: "QN/AABB",
            version: 1,
            summary: "解析 Company ID FFFF 厂商广播中的 AABB 体重与稳定状态。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "FFFF", characteristicUUID: nil, minimumLength: 21),
            decoder: nil,
            builtInParser: "qnAABBBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: aaaSeriesID,
            name: "AAA Series",
            version: 1,
            summary: "解析 AAA 系列厂商广播的 XOR 数据、5 位校验、克数与稳定状态。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "ANY", characteristicUUID: nil, minimumLength: 14),
            decoder: nil,
            builtInParser: "aaaSeriesBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: sinocareID,
            name: "Sinocare",
            version: 1,
            summary: "解析 Company ID FF64 的 XOR 校验和广播体重。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "FF64", characteristicUUID: nil, minimumLength: 19),
            decoder: nil,
            builtInParser: "sinocareBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: scaleupID,
            name: "Scaleup",
            version: 1,
            summary: "解析 D0/E0 状态、0.01 kg 体重与稳定状态。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "xxD0/xxE0", characteristicUUID: nil, minimumLength: 11),
            decoder: nil,
            builtInParser: "scaleupBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: okokID,
            name: "OKOK",
            version: 1,
            summary: "解析 OKOK V20、V11、VF0 与 C0 广播变体。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "MULTI", characteristicUUID: nil, minimumLength: 6),
            decoder: nil,
            builtInParser: "okokBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: etekcityFit8SID,
            name: "Etekcity Fit 8S",
            version: 1,
            summary: "解析 Company ID 06D0、FFD0 服务广播中的克数、阻抗与稳定状态。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "06D0 + FFD0", characteristicUUID: nil, minimumLength: 22, maximumLength: 22),
            decoder: nil,
            builtInParser: "etekcityFit8SBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: eufyC20ID,
            name: "Eufy C20",
            version: 1,
            summary: "解析 Company ID BC64 的体重与阻抗字段。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "BC64", characteristicUUID: nil, minimumLength: 16),
            decoder: nil,
            builtInParser: "eufyC20Broadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: yunmaiXID,
            name: "Yunmai X",
            version: 1,
            summary: "解析 1320 服务、0B7417 签名、XOR 校验、体重与阻抗。已通过数据样本验证，待真机验证。",
            origin: .builtIn,
            match: .init(transport: .advertisementManufacturerData, serviceUUID: "1320 + dynamic", characteristicUUID: nil, minimumLength: 16, maximumLength: 16),
            decoder: nil,
            builtInParser: "yunmaiXBroadcast",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: xiaomiMiScale2ID,
            name: "Xiaomi XMTZC04HM",
            version: 1,
            summary: "解析 MI SCALE2 的 10 字节 181D 广播、单位、锁定状态、离秤状态与时间。仅体重，已通过上游抓包样本验证，待本项目真机验证。",
            author: "ble-scale-sync contributors",
            origin: .builtIn,
            sourceURL: URL(string: "https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/xiaomi-mi-scale-legacy.ts"),
            match: .init(
                transport: .advertisementServiceData,
                serviceUUID: "181D",
                characteristicUUID: nil,
                minimumLength: 10,
                maximumLength: 10
            ),
            decoder: nil,
            builtInParser: "xiaomiMiScale2Advertisement",
            verification: .fixtureValidated
        ),
        CommunicationRule(
            id: silvergear108ID,
            name: "Silvergear 108",
            version: 1,
            summary: "解析 Company ID A0AC 的 12 字节广播、5 位校验、混淆后的克数与锁定状态。身体数据帧语义尚未确认，因此只读取体重。",
            author: "ble-scale-sync contributors",
            origin: .builtIn,
            sourceURL: URL(string: "https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/silvergear-108.ts"),
            match: .init(
                transport: .advertisementManufacturerData,
                serviceUUID: "A0AC + FFB0",
                characteristicUUID: nil,
                minimumLength: 14,
                maximumLength: 14
            ),
            decoder: nil,
            builtInParser: "silvergear108Broadcast",
            verification: .fixtureValidated
        )
    ]

    static let builtIn: [CommunicationRule] = implemented + UpstreamScaleAdapterCatalog.skeletonRules

    static func rules(custom: [CommunicationRule]) -> [CommunicationRule] {
        builtIn + custom.filter { rule in !builtIn.contains(where: { $0.id == rule.id }) }
    }
}

enum CommunicationRuleCodec {
    static let maximumDocumentBytes = 512 * 1_024
    static let customIDPrefix = "protocol.custom."

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
            normalized.verification = .unverified
            normalized.match.serviceUUID = normalizeUUID(rule.match.serviceUUID)
            normalized.match.characteristicUUID = rule.match.characteristicUUID.map(normalizeUUID)
            normalized.alternateMatches = rule.alternateMatches?.map(normalize)
            normalized.notifyTargets = rule.notifyTargets?.map(normalize)
            normalized.writeTargets = rule.writeTargets?.map(normalize)
            normalized.operations = rule.operations.map(normalize)
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
        return try encoder.encode(CommunicationRuleDocument(schemaVersion: CommunicationRuleDocument.currentSchemaVersion, rules: rules))
    }

    static func validate(_ rule: CommunicationRule) throws {
        let shortID = String(rule.id.dropFirst(customIDPrefix.count))
        guard rule.id.hasPrefix(customIDPrefix),
              shortID.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"#, options: .regularExpression) != nil else {
            throw CommunicationRuleError.invalidDocument("外部规则 ID 必须为 protocol.custom.<名称>，名称限 1 至 64 位 ASCII 字符")
        }
        guard !rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommunicationRuleError.invalidDocument("规则名称不能为空")
        }
        guard (rule.alternateMatches?.count ?? 0) <= 16,
              (rule.notifyTargets?.count ?? 0) <= 32,
              (rule.writeTargets?.count ?? 0) <= 32,
              (rule.supportedModels?.count ?? 0) <= 64 else {
            throw CommunicationRuleError.invalidDocument("协议元数据数量超过限制")
        }
        for alternate in rule.alternateMatches ?? [] {
            guard !alternate.serviceUUID.isEmpty,
                  (1...4_096).contains(alternate.minimumLength),
                  alternate.maximumLength.map({ $0 >= alternate.minimumLength && $0 <= 4_096 }) ?? true else {
                throw CommunicationRuleError.invalidDocument("备用匹配范围无效")
            }
        }
        guard rule.version > 0 else { throw CommunicationRuleError.invalidDocument("规则版本必须大于 0") }
        guard rule.builtInParser == nil, rule.decoder != nil || rule.operations != nil else {
            throw CommunicationRuleError.invalidDocument("外部规则必须提供 decoder 或受限 GATT operations")
        }
        guard rule.match.transport != .advertisementManufacturerData else {
            throw CommunicationRuleError.invalidDocument("外部规则暂不支持厂商广播数据")
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
        if let decoder = rule.decoder {
            let dateFields = decoder.date.map {
                [$0.year, $0.month, $0.day, $0.hour, $0.minute, $0.second].compactMap { $0 }
            } ?? []
            let fields = [decoder.weight, decoder.impedance, decoder.bodyFatPercent, decoder.muscleMassKG,
                          decoder.waterPercent, decoder.visceralFat, decoder.basalMetabolismKCal, decoder.boneMassKG].compactMap { $0 } + dateFields
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
        if let operations = rule.operations {
            let usesPrivateParser = [operations.historyRead, operations.historyClear]
                .compactMap { $0?.historyResponse?.builtInParser }
                .isEmpty == false
            guard !usesPrivateParser else {
                throw CommunicationRuleError.invalidDocument("外部规则不能调用内置私有解析器")
            }
            try CommunicationOperationValidator.validate(operations)
        }
    }

    static func normalizeUUID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalize(_ operations: CommunicationRuleOperations) -> CommunicationRuleOperations {
        var result = operations
        result.historyRead = result.historyRead.map(normalize)
        result.historyClear = result.historyClear.map(normalize)
        return result
    }

    private static func normalize(_ operation: CommunicationGATTOperation) -> CommunicationGATTOperation {
        var result = operation
        result.subscriptions = result.subscriptions.map(normalize)
        result.commands = result.commands.map { command in
            var value = command
            value.target = normalize(command.target)
            return value
        }
        result.completionCommands = result.completionCommands.map { command in
            var value = command
            value.target = normalize(command.target)
            return value
        }
        result.acknowledgementCommands = result.acknowledgementCommands.map { command in
            var value = command
            value.target = normalize(command.target)
            return value
        }
        result.historyResponse = result.historyResponse.map { response in
            var value = response
            value.recordMatcher.target = normalize(response.recordMatcher.target)
            value.completionMatcher.target = normalize(response.completionMatcher.target)
            return value
        }
        return result
    }

    private static func normalize(_ target: CommunicationGATTTarget) -> CommunicationGATTTarget {
        CommunicationGATTTarget(
            serviceUUID: normalizeUUID(target.serviceUUID),
            characteristicUUID: normalizeUUID(target.characteristicUUID)
        )
    }

    private static func normalize(_ match: CommunicationRuleMatch) -> CommunicationRuleMatch {
        var result = match
        result.serviceUUID = normalizeUUID(match.serviceUUID)
        result.characteristicUUID = match.characteristicUUID.map(normalizeUUID)
        return result
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
        let measurementDate: Date
        if let date = decoder.date {
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = .current
            components.year = Int(try value(date.year, bytes: bytes))
            components.month = Int(try value(date.month, bytes: bytes))
            components.day = Int(try value(date.day, bytes: bytes))
            components.hour = Int(try value(date.hour, bytes: bytes))
            components.minute = Int(try value(date.minute, bytes: bytes))
            components.second = try date.second.map { Int(try value($0, bytes: bytes)) } ?? 0
            guard let parsed = components.date,
                  parsed >= Date(timeIntervalSince1970: 946_684_800),
                  parsed <= now.addingTimeInterval(86_400) else { throw ScalePayloadError.unsupported }
            measurementDate = parsed
        } else {
            measurementDate = now
        }
        return .measurement(BodyMeasurement(
            date: measurementDate,
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
