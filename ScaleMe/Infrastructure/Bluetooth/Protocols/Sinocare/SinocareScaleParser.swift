import Foundation

struct SinocareScaleParser {
    static let companyID: UInt16 = 0xFF64

    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 17 else { throw ScalePayloadError.tooShort }
        let checksum = bytes[6..<16].reduce(UInt8(0)) { $0 ^ $1 }
        guard checksum == bytes[16] else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt16(bytes[9]) | UInt16(bytes[10]) << 8
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .communityProtocol,
            isStable: false
        )
    }
}
