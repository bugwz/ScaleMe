import Foundation

enum ScaleDiscoveryCompatibility: String, Equatable {
    case bluetoothSIG = "Bluetooth SIG 标准"
    case xiaomiAdvertisement = "0x181B 广播格式"
    case unverified = "协议待验证"

    var isVerified: Bool { self != .unverified }
}

struct ScaleDiscoveryAdvertisement {
    var name: String
    var advertisedServiceUUIDs: Set<String>
    var serviceDataUUIDs: Set<String>
    var hasVerifiedXiaomiPayload: Bool
}

enum ScaleDiscoveryClassifier {
    static func compatibility(for advertisement: ScaleDiscoveryAdvertisement) -> ScaleDiscoveryCompatibility {
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
