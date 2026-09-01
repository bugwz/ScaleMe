import Foundation

struct EtekcityFit8SScaleParser {
    static let companyID: UInt16 = 0x06D0

    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedServiceUUIDs: Set<String>,
        now: Date = .now
    ) throws -> BodyMeasurement {
        guard packet.companyID == companyID,
              advertisedServiceUUIDs.contains(where: { normalizedUUID($0) == "FFD0" }) else {
            throw ScalePayloadError.unsupported
        }
        let bytes = [UInt8](packet.payload)
        guard bytes.count == 20 else { throw ScalePayloadError.tooShort }
        guard bytes[0] == 0x01 else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt32(bytes[10]) | UInt32(bytes[11]) << 8 | UInt32(bytes[12]) << 16
        let weightKG = Double(rawWeight) / 1_000
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        let rawImpedance = UInt16(bytes[13]) | UInt16(bytes[14]) << 8
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: rawImpedance > 0 ? Double(rawImpedance) : nil,
            source: .communityProtocol,
            isStable: bytes[15] == 0x01
        )
    }

    private static func normalizedUUID(_ value: String) -> String {
        let uppercase = value.uppercased()
        let suffix = "-0000-1000-8000-00805F9B34FB"
        guard uppercase.hasPrefix("0000"), uppercase.hasSuffix(suffix) else { return uppercase }
        return String(uppercase.dropFirst(4).prefix(4))
    }
}
