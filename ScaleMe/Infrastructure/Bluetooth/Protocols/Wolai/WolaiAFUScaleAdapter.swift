import Foundation

enum WolaiAFUScaleAdapter {
    static let serviceUUID = "FFB0"
    static let measurementCharacteristicUUID = "FFB2"

    static func matchesIdentity(name: String, advertisedServiceUUIDs: Set<String>) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalizedName == "AFU-WL-TZ-A1"
            && advertisedServiceUUIDs.map(normalizedUUID).contains(serviceUUID)
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
