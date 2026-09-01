import Foundation

private func advertisement(
    name: String = "Unknown",
    advertised: Set<String> = [],
    serviceData: Set<String> = [],
    verifiedXiaomi: Bool = false,
    verifiedIcomonAFU: Bool = false,
    huaweiHagrid: Bool = false,
    verifiedBroadcastProtocol: ScaleBroadcastProtocolFamily? = nil
) -> ScaleDiscoveryAdvertisement {
    ScaleDiscoveryAdvertisement(
        name: name,
        advertisedServiceUUIDs: advertised,
        serviceDataUUIDs: serviceData,
        hasVerifiedXiaomiPayload: verifiedXiaomi,
        hasVerifiedIcomonAFUIdentity: verifiedIcomonAFU,
        hasHuaweiHagridIdentity: huaweiHagrid,
        verifiedBroadcastProtocol: verifiedBroadcastProtocol
    )
}

@main
struct DiscoveryClassifierSmoke {
    static func main() {
        let standardWeight = advertisement(advertised: ["181D"])
        precondition(ScaleDiscoveryClassifier.compatibility(for: standardWeight) == .bluetoothSIG)

        let fullBodyUUID = advertisement(
            advertised: ["0000181B-0000-1000-8000-00805F9B34FB"]
        )
        precondition(ScaleDiscoveryClassifier.compatibility(for: fullBodyUUID) == .bluetoothSIG)

        let xiaomi = advertisement(serviceData: ["181B"], verifiedXiaomi: true)
        precondition(ScaleDiscoveryClassifier.compatibility(for: xiaomi) == .xiaomiAdvertisement)

        let ambiguousBodyData = advertisement(serviceData: ["181B"])
        precondition(ScaleDiscoveryClassifier.compatibility(for: ambiguousBodyData) == .unverified)

        let icomonAFU = advertisement(
            name: "AFU-WL-TZ-A1",
            advertised: ["0000FFB0-0000-1000-8000-00805F9B34FB"],
            verifiedIcomonAFU: true
        )
        precondition(ScaleDiscoveryClassifier.compatibility(for: icomonAFU) == .icomonAFU)
        precondition(IcomonAFUScaleAdapter.matchesIdentity(
            name: icomonAFU.name,
            advertisedServiceUUIDs: icomonAFU.advertisedServiceUUIDs
        ))

        let genericFFB0 = advertisement(name: "Private Scale", advertised: ["FFB0"])
        precondition(ScaleDiscoveryClassifier.compatibility(for: genericFFB0) == .unverified)
        precondition(!IcomonAFUScaleAdapter.matchesIdentity(
            name: genericFFB0.name,
            advertisedServiceUUIDs: genericFFB0.advertisedServiceUUIDs
        ))

        let huawei = advertisement(
            name: "HUAWEI Scale 3 BLE-379",
            serviceData: ["FDEE"],
            huaweiHagrid: true
        )
        precondition(HuaweiHagridProtocol.matchesIdentity(
            name: huawei.name,
            serviceDataUUIDs: huawei.serviceDataUUIDs
        ))
        precondition(
            ScaleDiscoveryClassifier.compatibility(for: huawei)
                == .huaweiHagridAuthorizationRequired
        )
        precondition(!ScaleDiscoveryClassifier.compatibility(for: huawei).isVerified)
        guard let huaweiRule = CommunicationRuleCatalog.builtIn.first(where: {
            $0.id == CommunicationRuleCatalog.huaweiHagridID
        }) else {
            preconditionFailure("华为 Hagrid 内置通信协议缺失")
        }
        precondition(huaweiRule.match.transport == .characteristicNotification)
        precondition(huaweiRule.match.serviceUUID == HuaweiHagridProtocol.userDataServiceUUID)
        precondition(huaweiRule.match.characteristicUUID == HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID)
        precondition(huaweiRule.effectiveVerification == .unverified)

        let qn = advertisement(verifiedBroadcastProtocol: .qnAABB)
        precondition(ScaleDiscoveryClassifier.compatibility(for: qn) == .qnAABBBroadcast)

        let aaa = advertisement(name: "AAA007", verifiedBroadcastProtocol: .aaaSeries)
        precondition(ScaleDiscoveryClassifier.compatibility(for: aaa) == .aaaSeriesBroadcast)

        let communityFamilies: [(ScaleBroadcastProtocolFamily, ScaleDiscoveryCompatibility)] = [
            (.sinocare, .sinocareBroadcast),
            (.scaleup, .scaleupBroadcast),
            (.okok, .okokBroadcast),
            (.etekcityFit8S, .etekcityFit8SBroadcast),
            (.eufyC20, .eufyC20Broadcast),
            (.yunmaiX, .yunmaiXBroadcast)
        ]
        for (family, expectedCompatibility) in communityFamilies {
            precondition(
                ScaleDiscoveryClassifier.compatibility(
                    for: advertisement(verifiedBroadcastProtocol: family)
                ) == expectedCompatibility
            )
        }

        let likelyPrivateScale = advertisement(name: "My Weight Device")
        let privateCompatibility = ScaleDiscoveryClassifier.compatibility(for: likelyPrivateScale)
        precondition(privateCompatibility == .unverified)
        precondition(
            ScaleDiscoveryClassifier.discoveryPriority(
                for: likelyPrivateScale,
                compatibility: privateCompatibility
            ) == 1
        )

        let unrelatedDevice = advertisement(name: "Desk Sensor")
        precondition(
            ScaleDiscoveryClassifier.discoveryPriority(
                for: unrelatedDevice,
                compatibility: .unverified
            ) == 2
        )

        print("Discovery classifier smoke checks passed")
    }
}
