import Foundation

struct ScaleupScaleParser {
    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        let flag = UInt8(packet.companyID & 0xFF)
        guard flag == 0xD0 || flag == 0xE0 else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 9 else { throw ScalePayloadError.tooShort }
        let rawWeight = UInt16(packet.companyID >> 8) << 8 | UInt16(bytes[0])
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .communityProtocol,
            isStable: flag == 0xE0
        )
    }
}
