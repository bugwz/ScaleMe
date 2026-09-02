import Foundation

enum ScaleDiscoveryCompatibility: String, Equatable {
    case bluetoothSIG = "Bluetooth SIG 标准"
    case xiaomiAdvertisement = "0x181B 广播格式"
    case wolaiAFU = "Wolai AFU 实机样本"
    case qnAABBBroadcast = "QN/AABB 数据样本验证"
    case aaaSeriesBroadcast = "AAA 系列数据样本验证"
    case sinocareBroadcast = "Sinocare 数据样本验证"
    case scaleupBroadcast = "Scaleup 数据样本验证"
    case okokBroadcast = "OKOK 数据样本验证"
    case etekcityFit8SBroadcast = "Etekcity Fit 8S 数据样本验证"
    case eufyC20Broadcast = "Eufy C20 数据样本验证"
    case yunmaiXBroadcast = "Yunmai X 数据样本验证"
    case silvergear108Broadcast = "Silvergear 108 数据样本验证"
    case xiaomiMiScale2Advertisement = "小米 0x181D 广播格式"
    case huaweiHagridAuthorizationRequired = "华为 Hagrid 认证待配置"
    case unverified = "协议待验证"

    var isVerified: Bool {
        self != .unverified && self != .huaweiHagridAuthorizationRequired
    }
}

struct ScaleDiscoveryAdvertisement {
    var name: String
    var advertisedServiceUUIDs: Set<String>
    var serviceDataUUIDs: Set<String>
    var hasVerifiedXiaomiPayload: Bool
    var hasVerifiedWolaiAFUIdentity = false
    var hasHuaweiHagridIdentity = false
    var verifiedBroadcastProtocol: ScaleBroadcastProtocolFamily?
    var verifiedServiceDataProtocol: ScaleServiceDataProtocolFamily? = nil
}

enum ScaleDiscoveryClassifier {
    static func compatibility(for advertisement: ScaleDiscoveryAdvertisement) -> ScaleDiscoveryCompatibility {
        if advertisement.hasVerifiedWolaiAFUIdentity {
            return .wolaiAFU
        }
        if advertisement.hasHuaweiHagridIdentity {
            return .huaweiHagridAuthorizationRequired
        }
        switch advertisement.verifiedBroadcastProtocol {
        case .qnAABB: return .qnAABBBroadcast
        case .aaaSeries: return .aaaSeriesBroadcast
        case .sinocare: return .sinocareBroadcast
        case .scaleup: return .scaleupBroadcast
        case .okok: return .okokBroadcast
        case .etekcityFit8S: return .etekcityFit8SBroadcast
        case .eufyC20: return .eufyC20Broadcast
        case .yunmaiX: return .yunmaiXBroadcast
        case .silvergear108: return .silvergear108Broadcast
        case nil: break
        }
        switch advertisement.verifiedServiceDataProtocol {
        case .xiaomiMiScale2: return .xiaomiMiScale2Advertisement
        case nil: break
        }
        if advertisement.hasVerifiedXiaomiPayload {
            return .xiaomiAdvertisement
        }

        let advertisedServices = advertisement.advertisedServiceUUIDs.map(normalizedUUID)
        if advertisedServices.contains("181D") || advertisedServices.contains("181B") {
            return .bluetoothSIG
        }

        // Xiaomi also uses 0x181B for proprietary service data. Without a valid
        // captured payload, that UUID alone is not evidence of SIG conformance.
        let serviceDataServices = advertisement.serviceDataUUIDs.map(normalizedUUID)
        if serviceDataServices.contains("181D") {
            return .bluetoothSIG
        }
        return .unverified
    }

    static func discoveryPriority(
        for advertisement: ScaleDiscoveryAdvertisement,
        compatibility: ScaleDiscoveryCompatibility
    ) -> Int {
        if compatibility.isVerified { return 0 }
        return nameLooksLikeScale(advertisement.name) ? 1 : 2
    }

    private static func nameLooksLikeScale(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return ["scale", "body", "weight", "mibody", "xiaomi", "体脂", "体重", "秤"]
            .contains { lowercased.contains($0) }
    }

    private static func normalizedUUID(_ value: String) -> String {
        let uppercase = value.uppercased()
        let bluetoothBaseSuffix = "-0000-1000-8000-00805F9B34FB"
        guard uppercase.hasPrefix("0000"), uppercase.hasSuffix(bluetoothBaseSuffix) else {
            return uppercase
        }
        return String(uppercase.dropFirst(4).prefix(4))
    }
}
