import Foundation

/// Weight-only, non-connectable QN-lineage advertisements using the AABB frame.
/// The layout follows the captured AABB manufacturer-data samples.
struct QNAABBScaleParser {
    static let companyID: UInt16 = 0xFFFF

    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 19 else { throw ScalePayloadError.tooShort }
        guard bytes[0] == 0xAA, bytes[1] == 0xBB else { throw ScalePayloadError.unsupported }

        let rawWeight = UInt16(bytes[17]) | UInt16(bytes[18]) << 8
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .communityProtocol,
            isStable: bytes[15] & 0x20 != 0
        )
    }
}
