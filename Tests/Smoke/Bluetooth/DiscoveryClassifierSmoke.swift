import Foundation

private func advertisement(
    name: String = "Unknown",
    advertised: Set<String> = [],
    serviceData: Set<String> = [],
    verifiedXiaomi: Bool = false,
    verifiedWolaiAFU: Bool = false,
    huaweiHagrid: Bool = false,
    verifiedBroadcastProtocol: ScaleBroadcastProtocolFamily? = nil,
    verifiedServiceDataProtocol: ScaleServiceDataProtocolFamily? = nil
) -> ScaleDiscoveryAdvertisement {
    ScaleDiscoveryAdvertisement(
        name: name,
        advertisedServiceUUIDs: advertised,
        serviceDataUUIDs: serviceData,
        hasVerifiedXiaomiPayload: verifiedXiaomi,
        hasVerifiedWolaiAFUIdentity: verifiedWolaiAFU,
        hasHuaweiHagridIdentity: huaweiHagrid,
        verifiedBroadcastProtocol: verifiedBroadcastProtocol,
        verifiedServiceDataProtocol: verifiedServiceDataProtocol
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

        let wolaiAFU = advertisement(
            name: "AFU-WL-TZ-A1",
            advertised: ["0000FFB0-0000-1000-8000-00805F9B34FB"],
            verifiedWolaiAFU: true
        )
        precondition(ScaleDiscoveryClassifier.compatibility(for: wolaiAFU) == .wolaiAFU)
        precondition(WolaiAFUScaleAdapter.matchesIdentity(
            name: wolaiAFU.name,
            advertisedServiceUUIDs: wolaiAFU.advertisedServiceUUIDs
        ))

        let genericFFB0 = advertisement(name: "Private Scale", advertised: ["FFB0"])
        precondition(ScaleDiscoveryClassifier.compatibility(for: genericFFB0) == .unverified)
        precondition(!WolaiAFUScaleAdapter.matchesIdentity(
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
        precondition(huaweiRule.effectiveVerification == .fixtureValidated)
        precondition(huaweiRule.effectiveImplementation == .experimental)

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
            (.yunmaiX, .yunmaiXBroadcast),
            (.silvergear108, .silvergear108Broadcast)
        ]
        for (family, expectedCompatibility) in communityFamilies {
            precondition(
                ScaleDiscoveryClassifier.compatibility(
                    for: advertisement(verifiedBroadcastProtocol: family)
                ) == expectedCompatibility
            )
        }

        let xiaomiMiScale2 = advertisement(
            name: "MI SCALE2",
            serviceData: ["181D"],
            verifiedServiceDataProtocol: .xiaomiMiScale2
        )
        precondition(
            ScaleDiscoveryClassifier.compatibility(for: xiaomiMiScale2)
                == .xiaomiMiScale2Advertisement
        )

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
