import Foundation

enum CommunicationRuleOrigin: String, Codable, CaseIterable {
    case builtIn
    case custom

    var title: String {
        switch self {
        case .builtIn: "内置"
        case .custom: "本地导入"
        }
    }
}

enum ProtocolVerificationLevel: String, Codable {
    case standardSpecification
    case fixtureValidated
    case unverified

    var title: String {
        switch self {
        case .standardSpecification: "标准规范"
        case .fixtureValidated: "数据样本验证"
        case .unverified: "未经验证"
        }
    }
}

enum ProtocolImplementationLevel: String, Codable, CaseIterable {
    case executable
    case experimental
    case protocolSkeleton

    var title: String {
        switch self {
        case .executable: "可执行"
        case .experimental: "实验性"
        case .protocolSkeleton: "协议骨架"
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
        }
    }
}

enum CommunicationTransport: String, Codable {
    case advertisementServiceData
    case advertisementManufacturerData
    case characteristicNotification
}

enum CommunicationByteOrder: String, Codable {
    case littleEndian
    case bigEndian
}

enum CommunicationWeightUnit: String, Codable, CaseIterable, Hashable, Identifiable {
    case kilograms
    case pounds
    case jin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilograms: "公制（kg）"
        case .pounds: "英制（lb）"
        case .jin: "市斤（斤）"
        }
    }
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
    var subcutaneousFatPercent: CommunicationField? = nil
    var subcutaneousFatMassKG: CommunicationField? = nil
    var proteinPercent: CommunicationField? = nil
    var proteinMassKG: CommunicationField? = nil
    var skeletalMusclePercent: CommunicationField? = nil
    var skeletalMuscleMassKG: CommunicationField? = nil
    var stableWhen: CommunicationFlag?
    var removedWhen: CommunicationFlag?
    var date: CommunicationDateDecoder? = nil
}

struct CommunicationRuleSourceLink: Codable, Identifiable, Equatable, Hashable {
    var project: String
    var url: URL

    var id: String { url.absoluteString }

    static func bleScaleSync(_ sourceFile: String) -> Self {
        guard let url = URL(string: "https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/\(sourceFile)") else {
            preconditionFailure("Invalid ble-scale-sync source path")
        }
        return Self(
            project: "ble-scale-sync",
            url: url
        )
    }

    static func openScale(_ sourceFile: String) -> Self {
        guard let url = URL(string: "https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/\(sourceFile)") else {
            preconditionFailure("Invalid openScale source path")
        }
        return Self(
            project: "openScale",
            url: url
        )
    }
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
    var isConfirmedExecutable: Bool {
        effectiveImplementation == .executable && effectiveVerification != .unverified
    }
    var allMatches: [CommunicationRuleMatch] { [match] + (alternateMatches ?? []) }
    var capabilities: Set<CommunicationOperationCapability> {
        var result = Set<CommunicationOperationCapability>()
        if operations?.historyRead != nil { result.insert(.historyRead) }
        if operations?.historyClear != nil { result.insert(.historyClear) }
        return result
    }

    var implementedCapabilities: Set<ScaleProtocolCapability> {
        var result = Set<ScaleProtocolCapability>()
        if decoder != nil || builtInParser != nil { result.insert(.liveMeasurement) }
        if decoder?.removedWhen != nil { result.insert(.weightRemoval) }
        if operations?.historyRead != nil { result.insert(.historyRead) }
        if operations?.historyClear != nil { result.insert(.historyClear) }
        return result
    }
}

extension CommunicationRule {
    static func pendingBuiltIn(
        id: String,
        name: String,
        transport: CommunicationTransport = .characteristicNotification,
        services: [String],
        notify: [String] = [],
        write: [String] = [],
        supportedModels: [String] = [],
        requirements: [ProtocolRuntimeRequirement] = [.multiFrameSession],
        implementation: ProtocolImplementationLevel = .protocolSkeleton,
        summary: String = "协议特征已登记；解析或会话逻辑尚未完整实现并通过验证。",
        sources: [CommunicationRuleSourceLink]
    ) -> Self {
        guard let primaryService = services.first else {
            preconditionFailure("A pending built-in protocol must declare at least one service identifier")
        }
        let hasConcreteService = !primaryService.hasPrefix("待")
            && primaryService != "ANY"
            && !primaryService.contains("xx")
        let matches = services.dropFirst().map {
            CommunicationRuleMatch(
                transport: transport,
                serviceUUID: $0,
                characteristicUUID: notify.first,
                minimumLength: 1
            )
        }
        return Self(
            id: id,
            name: name,
            version: 1,
            summary: summary,
            author: sources.map(\.project).uniqued().map { "\($0) contributors" }.joined(separator: " + "),
            origin: .builtIn,
            sourceURL: sources.first?.url,
            sourceLinks: sources,
            match: CommunicationRuleMatch(
                transport: transport,
                serviceUUID: primaryService,
                characteristicUUID: notify.first,
                minimumLength: 1
            ),
            decoder: nil,
            builtInParser: nil,
            verification: .unverified,
            implementation: implementation,
            supportedModels: supportedModels.isEmpty ? nil : supportedModels,
            requirements: requirements,
            alternateMatches: matches.isEmpty ? nil : matches,
            notifyTargets: hasConcreteService && !notify.isEmpty
                ? notify.map { CommunicationGATTTarget(serviceUUID: primaryService, characteristicUUID: $0) }
                : nil,
            writeTargets: hasConcreteService && !write.isEmpty
                ? write.map { CommunicationGATTTarget(serviceUUID: primaryService, characteristicUUID: $0) }
                : nil
        )
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

/// Public, data-only definition accepted from a local protocol file. Runtime-only
/// fields such as origin, verification, implementation and built-in parser IDs
/// are deliberately absent, so an imported file cannot claim trusted behavior.
struct ExternalCommunicationRuleDefinition: Codable, Equatable {
    var id: String
    var name: String
    var version: Int
    var summary: String
    var author: String? = nil
    var sourceLinks: [CommunicationRuleSourceLink]? = nil
    var match: CommunicationRuleMatch
    var decoder: CommunicationRuleDecoder? = nil
    var operations: CommunicationRuleOperations? = nil
    var supportedModels: [String]? = nil
    var requirements: [ProtocolRuntimeRequirement]? = nil
    var alternateMatches: [CommunicationRuleMatch]? = nil
    var notifyTargets: [CommunicationGATTTarget]? = nil
    var writeTargets: [CommunicationGATTTarget]? = nil

    init(runtimeRule rule: CommunicationRule) {
        id = rule.id
        name = rule.name
        version = rule.version
        summary = rule.summary
        author = rule.author
        sourceLinks = rule.sourceLinks
        match = rule.match
        decoder = rule.decoder
        operations = rule.operations
        supportedModels = rule.supportedModels
        requirements = rule.requirements
        alternateMatches = rule.alternateMatches
        notifyTargets = rule.notifyTargets
        writeTargets = rule.writeTargets
    }

    var runtimeRule: CommunicationRule {
        CommunicationRule(
            id: id,
            name: name,
            version: version,
            summary: summary,
            author: author,
            origin: .custom,
            sourceLinks: sourceLinks,
            match: match,
            decoder: decoder,
            builtInParser: nil,
            verification: .unverified,
            operations: operations,
            implementation: nil,
            supportedModels: supportedModels,
            requirements: requirements,
            alternateMatches: alternateMatches,
            notifyTargets: notifyTargets,
            writeTargets: writeTargets
        )
    }
}

struct ExternalCommunicationRuleDocument: Codable, Equatable {
    var schemaVersion: Int
    var rules: [ExternalCommunicationRuleDefinition]

    static let currentSchemaVersion = 3
}

enum SimulationCommunicationRuleCatalog {
    static let initialRules = [
        makeRule(
            id: "protocol.custom.simulated-body-pro",
            name: "ScaleMe Demo Body Pro",
            summary: "模拟外部体脂秤协议，可解析体重、阻抗与稳定状态。",
            serviceUUID: "FFE0",
            characteristicUUID: "FFE1",
            minimumLength: 7,
            decoder: CommunicationRuleDecoder(
                weight: CommunicationField(offset: 1, length: 2, byteOrder: .bigEndian, scale: 0.01),
                impedance: CommunicationField(offset: 3, length: 2, byteOrder: .bigEndian, scale: 1),
                stableWhen: CommunicationFlag(offset: 5, mask: 0x01, equals: 0x01)
            )
        ),
        makeRule(
            id: "protocol.custom.simulated-weight-mini",
            name: "ScaleMe Demo Weight Mini",
            summary: "模拟外部体重秤协议，可解析体重与稳定状态。",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            minimumLength: 4,
            decoder: CommunicationRuleDecoder(
                weight: CommunicationField(offset: 1, length: 2, byteOrder: .littleEndian, scale: 0.01),
                stableWhen: CommunicationFlag(offset: 3, mask: 0x80, equals: 0x80)
            )
        )
    ]

    static func importedRule(fileName: String, attempt: Int) -> CommunicationRule {
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? "本地文件" : trimmedName
        return makeRule(
            id: "protocol.custom.simulated-import-\(attempt)",
            name: "\(displayName) · 模拟协议",
            summary: "由模拟导入流程生成，用于演示外部协议的解析、校验、列表与详情界面。",
            serviceUUID: "ABF0",
            characteristicUUID: "ABF1",
            minimumLength: 8,
            decoder: CommunicationRuleDecoder(
                weight: CommunicationField(offset: 2, length: 2, byteOrder: .bigEndian, scale: 0.01),
                impedance: CommunicationField(offset: 4, length: 2, byteOrder: .littleEndian, scale: 1),
                stableWhen: CommunicationFlag(offset: 6, mask: 0x01, equals: 0x01)
            )
        )
    }

    private static func makeRule(
        id: String,
        name: String,
        summary: String,
        serviceUUID: String,
        characteristicUUID: String,
        minimumLength: Int,
        decoder: CommunicationRuleDecoder
    ) -> CommunicationRule {
        CommunicationRule(
            id: id,
            name: name,
            version: 1,
            summary: summary,
            origin: .custom,
            match: CommunicationRuleMatch(
                transport: .characteristicNotification,
                serviceUUID: serviceUUID,
                characteristicUUID: characteristicUUID,
                minimumLength: minimumLength
            ),
            decoder: decoder,
            verification: .unverified,
            implementation: .experimental
        )
    }
}

struct SimulationCommunicationRuleImportSequence {
    private(set) var attemptCount = 0

    mutating func makeImportData(fileName: String) throws -> Data {
        attemptCount += 1
        if attemptCount.isMultiple(of: 2) {
            throw CommunicationRuleError.invalidDocument("weight 字段超出数据包范围")
        }
        let rule = SimulationCommunicationRuleCatalog.importedRule(
            fileName: fileName,
            attempt: attemptCount
        )
        return try CommunicationRuleCodec.encode([rule])
    }
}

enum CommunicationRuleError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidDocument(String)
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "不支持规则格式版本 \(version)"
        case .invalidDocument(let detail): "规则无效：\(detail)"
        case .responseTooLarge: "协议文件超过 512 KB 限制"
        }
    }
}

enum CommunicationRuleCatalog {
    static func automaticRuleID(for compatibility: String) -> String? {
        switch ScaleDiscoveryCompatibility(rawValue: compatibility) {
        case .bluetoothSIG: StandardWeightScaleParser.communicationRule.id
        case .xiaomiAdvertisement: XiaomiScaleParser.communicationRule.id
        case .wolaiAFU: WolaiAFUProtocolSession.communicationRule.id
        case .qnAABBBroadcast: QNAABBScaleParser.communicationRule.id
        case .aaaSeriesBroadcast: AAASeriesScaleParser.communicationRule.id
        case .sinocareBroadcast: SinocareScaleParser.communicationRule.id
        case .scaleupBroadcast: ScaleupScaleParser.communicationRule.id
        case .okokBroadcast: OKOKScaleParser.communicationRule.id
        case .etekcityFit8SBroadcast: EtekcityFit8SScaleParser.communicationRule.id
        case .eufyC20Broadcast: EufyC20ScaleParser.communicationRule.id
        case .yunmaiXBroadcast: YunmaiXScaleParser.communicationRule.id
        case .silvergear108Broadcast: Silvergear108ScaleParser.communicationRule.id
        case .xiaomiMiScale2Advertisement: XiaomiMiScale2BroadcastParser.communicationRule.id
        case .huaweiHagridAuthorizationRequired: HuaweiHagridProtocolSession.communicationRule.id
        case .unverified, nil: nil
        }
    }

    private static let implemented: [CommunicationRule] = [
        StandardWeightScaleParser.communicationRule,
        StandardBodyCompositionParser.communicationRule,
        HuaweiHagridProtocolSession.communicationRule,
        SenssunIF2121ProtocolSession.communicationRule,
        XiaomiScaleParser.communicationRule,
        WolaiAFUProtocolSession.communicationRule,
        QNAABBScaleParser.communicationRule,
        AAASeriesScaleParser.communicationRule,
        SinocareScaleParser.communicationRule,
        ScaleupScaleParser.communicationRule,
        OKOKScaleParser.communicationRule,
        EtekcityFit8SScaleParser.communicationRule,
        EufyC20ScaleParser.communicationRule,
        YunmaiXScaleParser.communicationRule,
        XiaomiMiScale2BroadcastParser.communicationRule,
        Silvergear108ScaleParser.communicationRule
    ]
    private static let pending: [CommunicationRule] = [
        ActiveEraPendingProtocols.communicationRules,
        BeurerSanitasPendingProtocols.communicationRules,
        BodyConnectPendingProtocols.communicationRules,
        CultPendingProtocols.communicationRules,
        DigooPendingProtocols.communicationRules,
        DrTrustPendingProtocols.communicationRules,
        EEBBLPendingProtocols.communicationRules,
        ESCS20MPendingProtocols.communicationRules,
        EbelterPendingProtocols.communicationRules,
        EtekcityPendingProtocols.communicationRules,
        EufyPendingProtocols.communicationRules,
        ExcelvanPendingProtocols.communicationRules,
        ExingtechPendingProtocols.communicationRules,
        FitTrackPendingProtocols.communicationRules,
        HealthKeepPendingProtocols.communicationRules,
        HesleyPendingProtocols.communicationRules,
        HoffenPendingProtocols.communicationRules,
        HuaweiPendingProtocols.communicationRules,
        HumePendingProtocols.communicationRules,
        HutbitPendingProtocols.communicationRules,
        InlifePendingProtocols.communicationRules,
        KeepPendingProtocols.communicationRules,
        KoogeekPendingProtocols.communicationRules,
        MGBPendingProtocols.communicationRules,
        MedisanaPendingProtocols.communicationRules,
        OmronPendingProtocols.communicationRules,
        OneByOnePendingProtocols.communicationRules,
        PicoocPendingProtocols.communicationRules,
        QNPendingProtocols.communicationRules,
        RealmePendingProtocols.communicationRules,
        RelaxmedicPendingProtocols.communicationRules,
        RenphoPendingProtocols.communicationRules,
        RobiPendingProtocols.communicationRules,
        RunstarPendingProtocols.communicationRules,
        RyFitPendingProtocols.communicationRules,
        SalterPendingProtocols.communicationRules,
        SenssunPendingProtocols.communicationRules,
        SoehnlePendingProtocols.communicationRules,
        TaylorPendingProtocols.communicationRules,
        TrisaPendingProtocols.communicationRules,
        VitafitPendingProtocols.communicationRules,
        WeightGurusPendingProtocols.communicationRules,
        WolaiPendingProtocols.communicationRules,
        XiaomiPendingProtocols.communicationRules,
        YunmaiPendingProtocols.communicationRules
    ].flatMap { $0 }

    static let builtIn: [CommunicationRule] = implemented + pending

    static var builtInForDisplay: [CommunicationRule] {
        builtIn.sorted(by: displayOrder)
    }

    static var confirmedExecutableBuiltIn: [CommunicationRule] {
        builtInForDisplay.filter(\.isConfirmedExecutable)
    }

    static var pendingBuiltIn: [CommunicationRule] {
        builtInForDisplay.filter { !$0.isConfirmedExecutable }
    }

    static func rulesForSelection(custom: [CommunicationRule]) -> [CommunicationRule] {
        let builtInIDs = Set(builtIn.map(\.id))
        let external = custom
            .filter { !builtInIDs.contains($0.id) && $0.canMeasure }
            .sorted(by: displayOrder)
        return builtInForDisplay.filter(\.canMeasure) + external
    }

    static func rules(custom: [CommunicationRule]) -> [CommunicationRule] {
        builtIn + custom.filter { rule in !builtIn.contains(where: { $0.id == rule.id }) }
    }

    private static func displayOrder(_ lhs: CommunicationRule, _ rhs: CommunicationRule) -> Bool {
        let lhsIsFullyUsable = lhs.isConfirmedExecutable
        let rhsIsFullyUsable = rhs.isConfirmedExecutable
        if lhsIsFullyUsable != rhsIsFullyUsable {
            return lhsIsFullyUsable
        }

        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }
        return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
    }
}

enum CommunicationRuleCodec {
    static let maximumDocumentBytes = 512 * 1_024
    static let customIDPrefix = "protocol.custom."

    static func decode(_ data: Data) throws -> [CommunicationRule] {
        guard data.count <= maximumDocumentBytes else { throw CommunicationRuleError.responseTooLarge }
        try rejectRuntimeOnlyFields(in: data)
        let document: ExternalCommunicationRuleDocument
        do {
            document = try JSONDecoder().decode(ExternalCommunicationRuleDocument.self, from: data)
        } catch {
            throw CommunicationRuleError.invalidDocument(error.localizedDescription)
        }
        guard document.schemaVersion == ExternalCommunicationRuleDocument.currentSchemaVersion else {
            throw CommunicationRuleError.unsupportedSchema(document.schemaVersion)
        }
        guard !document.rules.isEmpty, document.rules.count <= 64 else {
            throw CommunicationRuleError.invalidDocument("每个文件必须包含 1 至 64 条规则")
        }
        var ids = Set<String>()
        return try document.rules.map { definition in
            var normalized = definition.runtimeRule
            normalized.match.serviceUUID = normalizeUUID(normalized.match.serviceUUID)
            normalized.match.characteristicUUID = normalized.match.characteristicUUID.map(normalizeUUID)
            normalized.alternateMatches = normalized.alternateMatches?.map(normalize)
            normalized.notifyTargets = normalized.notifyTargets?.map(normalize)
            normalized.writeTargets = normalized.writeTargets?.map(normalize)
            normalized.operations = normalized.operations.map(normalize)
            try validate(normalized)
            guard ids.insert(normalized.id).inserted else {
                throw CommunicationRuleError.invalidDocument("规则 ID \(normalized.id) 重复")
            }
            return normalized
        }
    }

    static func encode(_ rules: [CommunicationRule], prettyPrinted: Bool = true) throws -> Data {
        for rule in rules {
            try validate(rule)
        }
        let encoder = JSONEncoder()
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] }
        return try encoder.encode(ExternalCommunicationRuleDocument(
            schemaVersion: ExternalCommunicationRuleDocument.currentSchemaVersion,
            rules: rules.map(ExternalCommunicationRuleDefinition.init(runtimeRule:))
        ))
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
                  alternate.transport != .advertisementManufacturerData,
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
        for target in (rule.notifyTargets ?? []) + (rule.writeTargets ?? []) {
            guard !target.serviceUUID.isEmpty, !target.characteristicUUID.isEmpty else {
                throw CommunicationRuleError.invalidDocument("通知和写入目标必须包含服务及特征 UUID")
            }
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
                          decoder.waterPercent, decoder.visceralFat, decoder.basalMetabolismKCal, decoder.boneMassKG, decoder.subcutaneousFatPercent, decoder.subcutaneousFatMassKG, decoder.proteinPercent, decoder.proteinMassKG, decoder.skeletalMusclePercent, decoder.skeletalMuscleMassKG].compactMap { $0 } + dateFields
            for field in fields {
                guard field.offset >= 0, field.offset <= rule.match.minimumLength,
                      (1...8).contains(field.length),
                      field.scale.isFinite, field.scale > 0, field.add.isFinite,
                      field.length <= rule.match.minimumLength - field.offset else {
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
            for operation in [operations.historyRead, operations.historyClear].compactMap({ $0 }) {
                for command in operation.commands
                    + operation.completionCommands
                    + operation.acknowledgementCommands {
                    try CommunicationPayloadTemplate.validateExternal(command.payloadHexTemplate)
                }
            }
        }
    }

    static func normalizeUUID(_ value: String) -> String {
        let uppercase = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let bluetoothBaseSuffix = "-0000-1000-8000-00805F9B34FB"
        guard uppercase.hasSuffix(bluetoothBaseSuffix) else { return uppercase }
        let assignedNumber = String(uppercase.dropLast(bluetoothBaseSuffix.count))
        guard assignedNumber.count == 8 else { return uppercase }
        return assignedNumber.hasPrefix("0000")
            ? String(assignedNumber.dropFirst(4))
            : assignedNumber
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
            value.completionMatcher = response.completionMatcher.map { matcher in
                var normalized = matcher
                normalized.target = normalize(matcher.target)
                return normalized
            }
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

    private static func rejectRuntimeOnlyFields(in data: Data) throws {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CommunicationRuleError.invalidDocument(error.localizedDescription)
        }
        guard let object = root as? [String: Any],
              let rules = object["rules"] as? [[String: Any]] else { return }
        let forbidden = Set(["origin", "sourceURL", "verification", "implementation", "builtInParser"])
        if rules.contains(where: { !forbidden.isDisjoint(with: $0.keys) }) {
            throw CommunicationRuleError.invalidDocument("外部规则包含仅供应用内部使用的字段")
        }
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
        guard MeasurementLimits.weightKG.contains(weightKG) else { throw ScalePayloadError.unsupported }
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
        let subcutaneousFatPercent = try decoder.subcutaneousFatPercent.map { try value($0, bytes: bytes) }
        if let value = subcutaneousFatPercent, !value.isFinite || !(0...100).contains(value) { throw ScalePayloadError.unsupported }
        let subcutaneousFatMassKG = try decoder.subcutaneousFatMassKG.map { try value($0, bytes: bytes) }
        if let value = subcutaneousFatMassKG, !value.isFinite || !(0...weightKG).contains(value) { throw ScalePayloadError.unsupported }
        let proteinPercent = try decoder.proteinPercent.map { try value($0, bytes: bytes) }
        if let value = proteinPercent, !value.isFinite || !(0...100).contains(value) { throw ScalePayloadError.unsupported }
        let proteinMassKG = try decoder.proteinMassKG.map { try value($0, bytes: bytes) }
        if let value = proteinMassKG, !value.isFinite || !(0...weightKG).contains(value) { throw ScalePayloadError.unsupported }
        let skeletalMusclePercent = try decoder.skeletalMusclePercent.map { try value($0, bytes: bytes) }
        if let value = skeletalMusclePercent, !value.isFinite || !(0...100).contains(value) { throw ScalePayloadError.unsupported }
        let skeletalMuscleMassKG = try decoder.skeletalMuscleMassKG.map { try value($0, bytes: bytes) }
        if let value = skeletalMuscleMassKG, !value.isFinite || !(0...weightKG).contains(value) { throw ScalePayloadError.unsupported }

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
            subcutaneousFatPercent: subcutaneousFatPercent,
            subcutaneousFatMassKG: subcutaneousFatMassKG,
            proteinPercent: proteinPercent,
            proteinMassKG: proteinMassKG,
            skeletalMusclePercent: skeletalMusclePercent,
            skeletalMuscleMassKG: skeletalMuscleMassKG,

            source: .customProtocol,
            isStable: stable
        ))
    }

    private static func flag(_ condition: CommunicationFlag, bytes: [UInt8]) -> Bool {
        bytes.indices.contains(condition.offset) && bytes[condition.offset] & condition.mask == condition.equals
    }

    private static func value(_ field: CommunicationField, bytes: [UInt8]) throws -> Double {
        guard field.offset >= 0, field.offset <= bytes.count,
              (1...8).contains(field.length), field.length <= bytes.count - field.offset else {
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
