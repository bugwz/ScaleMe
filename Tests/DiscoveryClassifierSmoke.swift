import Foundation

private func advertisement(
    name: String = "Unknown",
    advertised: Set<String> = [],
    serviceData: Set<String> = [],
    verifiedXiaomi: Bool = false
) -> ScaleDiscoveryAdvertisement {
    ScaleDiscoveryAdvertisement(
        name: name,
        advertisedServiceUUIDs: advertised,
        serviceDataUUIDs: serviceData,
        hasVerifiedXiaomiPayload: verifiedXiaomi
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
