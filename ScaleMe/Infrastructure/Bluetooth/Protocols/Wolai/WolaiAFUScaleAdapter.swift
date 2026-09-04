import Foundation

enum WolaiAFUScaleAdapter {
    static let serviceUUID = "FFB0"
    static let controlCharacteristicUUID = "FFB1"
    static let measurementCharacteristicUUID = "FFB2"

    static func makeTimeInitialization(at date: Date) -> Data {
        let seconds = UInt32(clamping: Int64(date.timeIntervalSince1970.rounded(.down)))
        return makeWriteFrame(payload: [
            0x08,
            UInt8((seconds >> 24) & 0xFF),
            UInt8((seconds >> 16) & 0xFF),
            UInt8((seconds >> 8) & 0xFF),
            UInt8(seconds & 0xFF),
            0x20
        ] + Array(repeating: 0, count: 10))
    }

    static func makeFinalAcknowledgement() -> Data {
        makeWriteFrame(payload: [0x04, 0xD6] + Array(repeating: 0, count: 14))
    }

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

    private static func makeWriteFrame(payload: [UInt8]) -> Data {
        precondition(payload.count == 16)
        var bytes: [UInt8] = [0xAC, 0x27]
        bytes.append(contentsOf: payload)
        bytes.append(0xDF)
        bytes.append(UInt8(bytes[2...18].reduce(0) { $0 + UInt32($1) } & 0xFF))
        return Data(bytes)
    }
}
