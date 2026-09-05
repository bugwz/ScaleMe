import Foundation

enum UpstreamAdapterSource: String, CaseIterable, Hashable {
    case bleScaleSync = "ble-scale-sync"
    case openScale = "openScale"
}

struct UpstreamScaleAdapterRecord: Identifiable, Hashable {
    var id: String
    var source: UpstreamAdapterSource
    var adapterName: String
    var sourceFile: String
    var models: [String]
    var transport: CommunicationTransport
    var serviceUUIDs: [String]
    var notifyCharacteristicUUIDs: [String]
    var writeCharacteristicUUIDs: [String]
    var requirements: [ProtocolRuntimeRequirement]
    var mappedRuleID: String?
    var implementation: ProtocolImplementationLevel
    var note: String

    var sourceURL: URL? {
        let value: String
        switch source {
        case .bleScaleSync:
            value = "https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/\(sourceFile)"
        case .openScale:
            value = "https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/\(sourceFile)"
        }
        return URL(string: value)
    }
}

/// Source-pinned inventory of every adapter registered by the two researched
/// projects. A record either maps to an executable ScaleMe rule or produces a
/// clearly labeled protocol-skeleton rule. Skeletons are intentionally visible
/// in the built-in catalog but cannot be selected for measurement yet.
enum UpstreamScaleAdapterCatalog {
    private static let profileSession: [ProtocolRuntimeRequirement] = [.userProfile, .multiFrameSession]
    private static let profileTimeSession: [ProtocolRuntimeRequirement] = [.userProfile, .timeSynchronization, .multiFrameSession]
    private static let encryptedSession: [ProtocolRuntimeRequirement] = [.encryption, .multiFrameSession]

    static let records: [UpstreamScaleAdapterRecord] = bleScaleSyncRecords + openScaleRecords

    static var skeletonRules: [CommunicationRule] {
        Dictionary(grouping: records.filter { $0.mappedRuleID == nil }) { record in
            compactSlug(for: record.id)
        }
        .sorted { $0.key < $1.key }
        .map { slug, records in
            makeSkeletonRule(records, id: "protocol.builtin.\(slug)")
        }
    }

    static func builtInRuleID(for record: UpstreamScaleAdapterRecord) -> String {
        if let mappedRuleID = record.mappedRuleID {
            return mappedRuleID
        }

        return "protocol.builtin.\(compactSlug(for: record.id))"
    }

    private static func record(
        _ id: String,
        _ source: UpstreamAdapterSource,
        _ name: String,
        _ file: String,
        models: [String] = [],
        transport: CommunicationTransport = .characteristicNotification,
        services: [String] = [],
        notify: [String] = [],
        write: [String] = [],
        requirements: [ProtocolRuntimeRequirement] = [.multiFrameSession],
        mappedRuleID: String? = nil,
        implementation: ProtocolImplementationLevel = .protocolSkeleton,
        note: String = "上游适配器定义已登记；本应用运行时尚未完整移植该会话。"
    ) -> UpstreamScaleAdapterRecord {
        UpstreamScaleAdapterRecord(
            id: id,
            source: source,
            adapterName: name,
            sourceFile: file,
            models: models,
            transport: transport,
            serviceUUIDs: services,
            notifyCharacteristicUUIDs: notify,
            writeCharacteristicUUIDs: write,
            requirements: requirements,
            mappedRuleID: mappedRuleID,
            implementation: implementation,
            note: note
        )
    }

    private static func compactSlug(for recordID: String) -> String {
        let rawSlug = recordID.split(separator: ".", maxSplits: 1).last.map(String.init) ?? recordID
        return switch rawSlug {
        case "standard-beurer": "beurer-sig"
        case "etekcity-esf551": "etekcity-551"
        case "exingtech": "exingtech-y1"
        case "yunmai-mini": "yunmai"
        default: rawSlug.replacingOccurrences(of: ".", with: "-")
        }
    }

    private static func makeSkeletonRule(_ records: [UpstreamScaleAdapterRecord], id: String) -> CommunicationRule {
        guard let record = records.first else {
            preconditionFailure("A grouped upstream protocol must contain at least one adapter record")
        }
        let primaryService = record.serviceUUIDs.first ?? "待捕获"
        let primaryNotify = record.notifyCharacteristicUUIDs.first
        let primaryMatch = CommunicationRuleMatch(
            transport: record.transport,
            serviceUUID: primaryService,
            characteristicUUID: primaryNotify,
            minimumLength: 1
        )
        let alternateMatches = record.serviceUUIDs.dropFirst().map { service in
            CommunicationRuleMatch(
                transport: record.transport,
                serviceUUID: service,
                characteristicUUID: primaryNotify,
                minimumLength: 1
            )
        }
        let hasKnownService = !primaryService.hasPrefix("待") && primaryService != "ANY"
        let notifyTargets = hasKnownService ? record.notifyCharacteristicUUIDs.map {
            CommunicationGATTTarget(serviceUUID: primaryService, characteristicUUID: $0)
        } : []
        let writeTargets = hasKnownService ? record.writeCharacteristicUUIDs.map {
            CommunicationGATTTarget(serviceUUID: primaryService, characteristicUUID: $0)
        } : []
        let sourceLinks = records.compactMap { candidate -> CommunicationRuleSourceLink? in
            guard let url = candidate.sourceURL else { return nil }
            return CommunicationRuleSourceLink(project: candidate.source.rawValue, url: url)
        }
        let sourceProjects = unique(records.map(\.source.rawValue))
        let supportedModels = unique(records.flatMap(\.models))
        return CommunicationRule(
            id: id,
            name: canonicalName(for: id, defaultName: record.adapterName),
            version: 1,
            summary: record.note,
            author: sourceProjects.map { "\($0) contributors" }.joined(separator: " + "),
            origin: .builtIn,
            sourceURL: sourceLinks.first?.url,
            sourceLinks: sourceLinks,
            match: primaryMatch,
            decoder: nil,
            builtInParser: nil,
            verification: .unverified,
            implementation: record.implementation,
            supportedModels: supportedModels,
            requirements: record.requirements,
            alternateMatches: alternateMatches.isEmpty ? nil : alternateMatches,
            notifyTargets: notifyTargets.isEmpty ? nil : notifyTargets,
            writeTargets: writeTargets.isEmpty ? nil : writeTargets
        )
    }

    private static func canonicalName(for id: String, defaultName: String) -> String {
        switch id {
        case "protocol.builtin.active-era": "Active Era BS-06/BF06"
        case "protocol.builtin.renpho-es26bb": "Renpho ES-26BB"
        case "protocol.builtin.yunmai": "Yunmai Signal/Mini/SE"
        default: defaultName
        }
    }

    private static func unique<Value: Hashable>(_ values: [Value]) -> [Value] {
        var seen = Set<Value>()
        return values.filter { seen.insert($0).inserted }
    }

    // The code registry at the pinned revision contains 33 adapter instances.
    private static let bleScaleSyncRecords: [UpstreamScaleAdapterRecord] = [
        record("ble.eufy-p2", .bleScaleSync, "Eufy P2/P2 Pro", "eufy-p2.ts", models: ["T9148", "T9149"], services: ["FFF0"], notify: ["FFF2", "FFF4"], write: ["FFF1", "FFF4"], requirements: [.encryption, .multiFrameSession]),
        record("ble.senssun", .bleScaleSync, "Senssun", "senssun.ts", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileSession),
        record("ble.qn", .bleScaleSync, "QN GATT", "qn-scale.ts", services: ["FFF0", "FFE0", "AE00", "181B", "181D"], notify: ["FFF1", "FFE1", "AE01", "2A9D"], write: ["FFF2", "FFE3", "AE02", "2A9F"], requirements: profileTimeSession),
        record("ble.renpho", .bleScaleSync, "Renpho ES-WBE28", "renpho.ts", services: ["181B", "181D", "181C", "FFE0", "FFF0"], notify: ["2A9D", "2A9C", "FFE1"], write: ["2A9F", "FFE2"], requirements: [.userProfile, .consentCode, .multiFrameSession]),
        record("ble.renpho-msc04", .bleScaleSync, "Renpho R-MSC04", "renpho-msc04.ts", models: ["MorphoScan Nova"], services: ["1A10"], notify: ["2A10", "2A12"], write: ["2A11"], requirements: [.historyStateMachine, .multiFrameSession]),
        record("ble.renpho-es26bb", .bleScaleSync, "Renpho ES-26BB-B", "renpho-es26bb.ts", services: ["1A10"], notify: ["2A10"], write: ["2A11"], requirements: profileSession),
        record("ble.beurer-bf720", .bleScaleSync, "Beurer SIG scales", "beurer-bf720.ts", models: ["BF720", "BF105", "BF500", "BF788", "BF950"], services: ["181B", "181D", "181C"], notify: ["2A9C", "2A9D", "FFF2"], write: ["2A9F", "FFF3"], requirements: [.bonding, .consentCode, .userProfile, .multiFrameSession]),
        record("ble.xiaomi-181d", .bleScaleSync, "Xiaomi XMTZC04HM", "xiaomi-mi-scale-legacy.ts", models: ["MI SCALE2"], transport: .advertisementServiceData, services: ["181D"], requirements: [], mappedRuleID: "protocol.builtin.xiaomi-181d", implementation: .experimental),
        record("ble.silvergear-108", .bleScaleSync, "Silvergear 108", "silvergear-108.ts", transport: .advertisementManufacturerData, services: ["A0AC", "FFB0"], requirements: [], mappedRuleID: "protocol.builtin.silvergear-108", implementation: .experimental),
        record("ble.mi-scale-2", .bleScaleSync, "Xiaomi Mi Scale 2", "mi-scale-2.ts", models: ["MIBCS", "MIBFS", "XMTZC05HM"], transport: .advertisementServiceData, services: ["181B"], requirements: [], mappedRuleID: "protocol.builtin.xiaomi-legacy", implementation: .experimental),
        record("ble.xiaomi-s800", .bleScaleSync, "Xiaomi S800", "xiaomi-s800.ts", models: ["ms116"], transport: .advertisementServiceData, services: ["FE95"], requirements: [.bindKey, .encryption], note: "已登记 FE95 加密 MiBeacon；需要逐设备 bind key，8 电极 GATT 数据尚未解码。"),
        record("ble.yunmai", .bleScaleSync, "Yunmai Signal/Mini/SE", "yunmai.ts", services: ["FFE0"], notify: ["FFE4"], write: ["FFE9"], requirements: profileSession),
        record("ble.beurer-sanitas", .bleScaleSync, "Beurer/Sanitas FFE0", "beurer-sanitas.ts", services: ["FFE0"], notify: ["FFE1"], write: ["FFE1"], requirements: [.vendorRegistration, .userProfile, .multiFrameSession]),
        record("ble.sanitas-sbf72", .bleScaleSync, "Sanitas SBF72/73", "sanitas-sbf72.ts", services: ["181B", "181C"], notify: ["2A9C"], write: ["2A9F"], requirements: [.vendorRegistration, .userProfile]),
        record("ble.soehnle", .bleScaleSync, "Soehnle Shape/Style", "soehnle.ts", models: ["Shape200", "Shape100", "Shape50", "Style100"], services: ["352E0000-28E9-40B8-A361-6DB4CCA4147C"], notify: ["352E3001-28E9-40B8-A361-6DB4CCA4147C"], write: ["352E3002-28E9-40B8-A361-6DB4CCA4147C"], requirements: [.vendorRegistration, .multiFrameSession]),
        record("ble.medisana", .bleScaleSync, "Medisana BS44x", "medisana-bs44x.ts", models: ["BS430", "BS440", "BS444"], services: ["78B2"], notify: ["8A21"], write: ["8A81"], requirements: profileTimeSession),
        record("ble.trisa", .bleScaleSync, "Trisa/ADE BA1600", "trisa.ts", services: ["78B2"], notify: ["8A21", "8A24", "8A22", "8A82"], write: ["8A81"], requirements: profileTimeSession),
        record("ble.es-cs20m", .bleScaleSync, "ES-CS20M / ES-32MD", "es-cs20m.ts", services: ["1A10"], notify: ["2A10"], write: ["2A11"], requirements: [.multiFrameSession]),
        record("ble.exingtech-y1", .bleScaleSync, "Exingtech Y1", "exingtech-y1.ts", models: ["vscale"], services: ["F433BD80-75B8-11E2-97D9-0002A5D5C51B"], notify: ["1A2EA400-75B9-11E2-BE05-0002A5D5C51B"], write: ["29F11080-75B9-11E2-8BF6-0002A5D5C51B"], requirements: profileSession),
        record("ble.excelvan", .bleScaleSync, "Excelvan CF369", "excelvan-cf369.ts", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: profileSession),
        record("ble.hesley", .bleScaleSync, "Hesley / YunChen", "hesley.ts", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: [.multiFrameSession]),
        record("ble.koogeek", .bleScaleSync, "Koogeek S1", "koogeek-s1.ts", services: ["FFF0"], notify: ["FFF4"], write: ["FFF3"], requirements: profileSession),
        record("ble.inlife", .bleScaleSync, "Inlife FatScale", "inlife.ts", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileSession),
        record("ble.digoo", .bleScaleSync, "Digoo / Mengii", "digoo.ts", models: ["DG-SO38H"], services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileSession),
        record("ble.onebyone", .bleScaleSync, "1byone / Eufy C1/P1/A1", "one-byone.ts", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: profileTimeSession),
        record("ble.onebyone-new", .bleScaleSync, "1byone Scale new", "one-by-one.ts", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: [.multiFrameSession]),
        record("ble.active-era", .bleScaleSync, "Active Era BS-06", "active-era.ts", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: [.multiFrameSession]),
        record("ble.robi-s9", .bleScaleSync, "Robi S9", "robi-s9.ts", services: ["FFB0"], notify: ["FFB2", "FFB3"], write: ["FFB1"], requirements: profileTimeSession),
        record("ble.hutbit", .bleScaleSync, "Hutbit 218008 / WL292", "hutbit.ts", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: profileTimeSession),
        record("ble.mgb", .bleScaleSync, "MGB Swan/Icomon/YG", "mgb.ts", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: profileTimeSession),
        record("ble.hoffen", .bleScaleSync, "Hoffen BS-8107", "hoffen.ts", services: ["FFB0"], notify: ["FFB2"], write: ["FFB2"], requirements: profileSession),
        record("ble.salter", .bleScaleSync, "Salter SA00656/SA00432", "salter.ts", services: ["FFCC"], notify: ["FFC1"], write: ["FFC1"], requirements: [.timeSynchronization, .historyStateMachine, .multiFrameSession]),
        record("ble.standard-gatt", .bleScaleSync, "Standard GATT BCS/WSS", "standard-gatt.ts", services: ["181B", "181D"], notify: ["2A9C", "2A9D"], write: ["2A9F"], requirements: [], mappedRuleID: "protocol.builtin.sig-body", implementation: .executable)
    ]

    // ScaleFactory.createHandlers() at the pinned revision contains 63 instances.
    private static let openScaleRecords: [UpstreamScaleAdapterRecord] = [
        record("open.healthkeep280", .openScale, "HealthKeep 280", "HealthKeep280Handler.kt", services: ["FFB0"], notify: ["FFB2", "FFB3"], write: ["FFB1"], requirements: profileSession),
        record("open.picooc", .openScale, "Picooc", "PicoocHandler.kt", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileTimeSession),
        record("open.active-era", .openScale, "Active Era BF06", "ActiveEraBF06Handler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: [.multiFrameSession]),
        record("open.afu-b1", .openScale, "AFU B1", "AfuB1Handler.kt", services: ["FC50", "AF000000-9F2D-4C8A-8D6F-6A7B45F90000"], notify: [], write: ["AF000002-9F2D-4C8A-8D6F-6A7B45F90000"], requirements: [.historyStateMachine, .multiFrameSession]),
        record("open.keep-s3", .openScale, "Keep S3", "KeepS3Handler.kt", services: ["待捕获"], requirements: profileTimeSession),
        record("open.omron-wlc", .openScale, "Omron WLC/WLP", "OmronWlcHandler.kt", services: ["ECBE3980-C9A2-11E1-B1BD-0002A5D5C51B"], notify: ["DB5B55E0-AEE7-11E1-965E-0002A5D5C51B"], write: ["49123040-AEE8-11E1-A74D-0002A5D5C51B"], requirements: [.bonding, .historyStateMachine, .multiFrameSession]),
        record("open.beurer-bf450", .openScale, "Beurer BF450", "BeurerBF450Handler.kt", services: ["FFFF"], notify: ["FFF0", "FFF5", "2A9C", "2A9D"], write: ["FFF1", "FFF2", "FFF4", "FFF7"], requirements: profileSession),
        record("open.taylor-bia", .openScale, "Taylor BIA", "TaylorBIAHandler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: [.multiFrameSession]),
        record("open.ryfit", .openScale, "RyFit", "RyFitHandler.kt", services: ["FFE0"], notify: ["FFE1"], write: ["FFE1"], requirements: profileTimeSession),
        record("open.cult-smart", .openScale, "Cult Smart Scale Pro", "CultSmartScaleProHandler.kt", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: profileSession),
        record("open.realme", .openScale, "Realme Smart Scale", "RealmeSmartScaleHandler.kt", services: ["A602"], notify: ["A621", "A625"], write: ["A622", "A624"], requirements: [.encryption, .keepAlive, .userProfile, .historyStateMachine, .multiFrameSession]),
        record("open.yunmai", .openScale, "Yunmai", "YunmaiHandler.kt", services: ["FFE0"], notify: ["FFE4"], write: ["FFE9"], requirements: profileSession),
        record("open.yunmai-mini", .openScale, "Yunmai Mini", "YunmaiHandler.kt", services: ["FFE0"], notify: ["FFE4"], write: ["FFE9"], requirements: profileSession),
        record("open.yunmai-x", .openScale, "Yunmai X", "YunmaiXHandler.kt", transport: .advertisementManufacturerData, services: ["1320"], requirements: [], mappedRuleID: "protocol.builtin.yunmai-x", implementation: .experimental),
        record("open.trisa", .openScale, "Trisa Body Analyze", "TrisaBodyAnalyzeHandler.kt", services: ["78B2"], notify: ["8A21", "8A24", "8A22", "8A82"], write: ["8A81"], requirements: profileTimeSession),
        record("open.sanitas-sbf72", .openScale, "Sanitas SBF72", "SanitasSbf72Handler.kt", services: ["181B", "181C"], notify: ["2A9C"], write: ["2A9F"], requirements: [.vendorRegistration, .userProfile]),
        record("open.standard-beurer", .openScale, "Beurer/Sanitas SIG", "StandardBeurerSanitasHandler.kt", services: ["181B", "181D", "181C"], notify: ["2A9C", "2A9D"], write: ["2A9F"], requirements: [.bonding, .consentCode, .userProfile]),
        record("open.soehnle", .openScale, "Soehnle", "SoehnleHandler.kt", services: ["352E0000-28E9-40B8-A361-6DB4CCA4147C"], notify: ["352E3001-28E9-40B8-A361-6DB4CCA4147C"], write: ["352E3002-28E9-40B8-A361-6DB4CCA4147C"], requirements: [.vendorRegistration, .multiFrameSession]),
        record("open.sinocare", .openScale, "Sinocare", "SinocareHandler.kt", transport: .advertisementManufacturerData, services: ["FF64"], requirements: [], mappedRuleID: "protocol.builtin.sinocare", implementation: .experimental),
        record("open.senssun", .openScale, "Senssun", "SenssunHandler.kt", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileSession),
        record("open.renpho", .openScale, "Renpho", "RenphoHandler.kt", services: ["181B", "181D", "181C", "FFE0", "FFF0"], notify: ["2A9D", "2A9C", "FFE1"], write: ["2A9F", "FFE2"], requirements: [.userProfile, .consentCode, .multiFrameSession]),
        record("open.qn-broadcast", .openScale, "QN Broadcast", "QNHandlerBroadcast.kt", transport: .advertisementManufacturerData, services: ["FFFF"], requirements: [], mappedRuleID: "protocol.builtin.qn-aabb", implementation: .experimental),
        record("open.qn", .openScale, "QN GATT", "QNHandler.kt", services: ["FFF0", "FFE0", "AE00", "181B", "181D"], notify: ["FFF1", "FFE1", "AE01", "2A9D"], write: ["FFF2", "FFE3", "AE02", "2A9F"], requirements: profileTimeSession),
        record("open.onebyone", .openScale, "1byone", "OneByoneHandler.kt", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: profileTimeSession),
        record("open.onebyone-new", .openScale, "1byone New", "OneByoneNewHandler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: [.multiFrameSession]),
        record("open.okok", .openScale, "OKOK", "OkOkHandler.kt", transport: .advertisementManufacturerData, services: ["20CA", "11CA", "F0FF", "xxC0"], requirements: [], mappedRuleID: "protocol.builtin.okok", implementation: .experimental),
        record("open.mi-s400", .openScale, "Xiaomi S400", "MiScaleS400Handler.kt", transport: .advertisementServiceData, services: ["FE95"], requirements: [.bindKey, .encryption]),
        record("open.xiaomi-s800", .openScale, "Xiaomi S800", "XiaomiS800Handler.kt", transport: .advertisementServiceData, services: ["FE95"], requirements: [.bindKey, .encryption]),
        record("open.mi-scale", .openScale, "Xiaomi Mi Scale", "MiScaleHandler.kt", transport: .advertisementServiceData, services: ["181B"], requirements: [], mappedRuleID: "protocol.builtin.xiaomi-legacy", implementation: .experimental),
        record("open.runstar-r6", .openScale, "Runstar R6", "RunstarR6Handler.kt", services: ["FFB0"], notify: ["FFB2", "FFB3"], write: ["FFB1"], requirements: [.historyStateMachine, .multiFrameSession]),
        record("open.runstar-r5", .openScale, "Runstar R5", "RunstarR5Handler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: profileTimeSession),
        record("open.relaxmedic", .openScale, "Relaxmedic", "RelaxmedicHandler.kt", services: ["FFB0"], notify: ["FFB2", "FFB3"], write: ["FFB1"], requirements: profileSession),
        record("open.robi-s9", .openScale, "Robi S9", "RobiS9Handler.kt", services: ["FFB0"], notify: ["FFB2", "FFB3"], write: ["FFB1"], requirements: profileTimeSession),
        record("open.vitafit", .openScale, "Vitafit VT701", "VitafitVT701Handler.kt", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: [.multiFrameSession]),
        record("open.eebbl", .openScale, "EEBBL", "EEBBLHandler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: profileTimeSession),
        record("open.fittrack", .openScale, "FitTrack Dara", "FitTrackDaraHandler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: profileSession),
        record("open.drtrust", .openScale, "Dr Trust SSW532", "DrTrustSSW532Handler.kt", services: ["FFB0"], notify: ["FFB2", "FFB3"], write: ["FFB1"], requirements: profileSession),
        record("open.mgb", .openScale, "MGB", "MGBHandler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB1"], requirements: profileTimeSession),
        record("open.medisana", .openScale, "Medisana BS44x", "MedisanaBs44xHandler.kt", services: ["78B2"], notify: ["8A21"], write: ["8A81"], requirements: profileTimeSession),
        record("open.inlife", .openScale, "Inlife", "InlifeHandler.kt", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileSession),
        record("open.ihealth-hs3", .openScale, "iHealth HS3", "IHealthHS3Handler.kt", transport: .classicSPP, services: ["RFCOMM"], requirements: [.classicBluetooth], implementation: .unsupportedPlatform, note: "协议为 Classic Bluetooth SPP；CoreBluetooth 不提供 RFCOMM 访问，当前 iOS 架构不可执行。"),
        record("open.huawei-ah100", .openScale, "Huawei AH100", "HuaweiAhCh100Handler.kt", services: ["FAA0"], notify: ["FAA2"], write: ["FAA1"], requirements: encryptedSession),
        record("open.huawei-ch100s", .openScale, "Huawei CH100S", "HuaweiCH100SHandler.kt", services: ["FAA0"], notify: ["FAA2"], write: ["FAA1"], requirements: [.encryption, .historyStateMachine, .multiFrameSession]),
        record("open.huawei-hagrid", .openScale, "Huawei Hagrid/WSP", "HuaweiHagridWspHandler.kt", services: ["181C"], notify: ["2A9E"], write: ["2A9F"], requirements: [.bindKey, .encryption, .multiFrameSession], mappedRuleID: "protocol.builtin.huawei-hagrid"),
        record("open.hoffen", .openScale, "Hoffen BS-8107", "HoffenBbs8107Handler.kt", services: ["FFB0"], notify: ["FFB2"], write: ["FFB2"], requirements: profileSession),
        record("open.hesley", .openScale, "Hesley", "HesleyHandler.kt", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: [.multiFrameSession]),
        record("open.exingtech", .openScale, "Exingtech Y1", "ExingtechY1Handler.kt", services: ["F433BD80-75B8-11E2-97D9-0002A5D5C51B"], notify: ["1A2EA400-75B9-11E2-BE05-0002A5D5C51B"], write: ["29F11080-75B9-11E2-8BF6-0002A5D5C51B"], requirements: profileSession),
        record("open.ebelter", .openScale, "Ebelter Body Fat B2", "EbelterBodyFatB2Handler.kt", services: ["FAA0"], notify: ["FAA2"], write: ["FAA1"], requirements: [.multiFrameSession]),
        record("open.hume-dara2", .openScale, "Hume Dara 2", "HumeDara2Handler.kt", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: profileSession),
        record("open.excelvan", .openScale, "Excelvan CF36x", "ExcelvanCF36xHandler.kt", services: ["FFF0"], notify: ["FFF4"], write: ["FFF1"], requirements: profileSession),
        record("open.etekcity-esf551", .openScale, "Etekcity ESF551", "EtekcityESF551Handler.kt", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: [.multiFrameSession]),
        record("open.etekcity-fit8s", .openScale, "Etekcity Fit 8S", "EtekcityFit8SHandler.kt", transport: .advertisementManufacturerData, services: ["06D0", "FFD0"], requirements: [], mappedRuleID: "protocol.builtin.fit8s", implementation: .experimental),
        record("open.eufy-c20", .openScale, "Eufy C20", "EufyC20Handler.kt", transport: .advertisementManufacturerData, services: ["BC64"], requirements: [], mappedRuleID: "protocol.builtin.eufy-c20", implementation: .experimental),
        record("open.eufy-p2", .openScale, "Eufy P2", "EufyP2Handler.kt", services: ["FFF0"], notify: ["FFF2", "FFF4"], write: ["FFF1", "FFF4"], requirements: [.encryption, .multiFrameSession]),
        record("open.es-cs20m", .openScale, "ES-CS20M", "ESCS20MHandler.kt", services: ["1A10"], notify: ["2A10"], write: ["2A11"], requirements: [.multiFrameSession]),
        record("open.renpho-es26bb", .openScale, "Renpho ES-26BB", "RenphoES26BBHandler.kt", services: ["1A10"], notify: ["2A10"], write: ["2A11"], requirements: profileSession),
        record("open.digoo", .openScale, "Digoo DG-SO38H", "DigooDGSO38HHandler.kt", services: ["FFF0"], notify: ["FFF1"], write: ["FFF2"], requirements: profileSession),
        record("open.custom", .openScale, "Custom Protocol", "CustomOpenScaleHandler.kt", services: ["待用户定义"], requirements: [], note: "上游自定义处理器入口已登记；本应用使用受限外部通信规则承担对应能力。"),
        record("open.beurer-sanitas", .openScale, "Beurer / Sanitas", "BeurerSanitasHandler.kt", services: ["FFE0"], notify: ["FFE1"], write: ["FFE1"], requirements: [.vendorRegistration, .userProfile, .multiFrameSession]),
        record("open.aaa", .openScale, "AAA002 / AAA007 / AAA013", "AAAxHandler.kt", transport: .advertisementManufacturerData, services: ["ANY"], requirements: [], mappedRuleID: "protocol.builtin.aaa-series", implementation: .experimental),
        record("open.scaleup", .openScale, "Scaleup", "ScaleupHandler.kt", transport: .advertisementManufacturerData, services: ["xxD0", "xxE0"], requirements: [], mappedRuleID: "protocol.builtin.scaleup", implementation: .experimental),
        record("open.bodyconnect", .openScale, "BodyConnect", "BodyConnectHandler.kt", services: ["7892"], notify: ["8A24", "8A22", "8A82"], write: ["8A81"], requirements: [.consentCode, .userProfile, .timeSynchronization, .multiFrameSession]),
        record("open.weightgurus-a3", .openScale, "Weight Gurus A3", "WeightGurusA3Handler.kt", services: ["0D005750-C36B-11E3-9C1A-0800200C9A66"], notify: ["8A24", "8A22", "8A82"], write: ["8A81"], requirements: [.consentCode, .userProfile, .timeSynchronization, .multiFrameSession])
    ]
}
