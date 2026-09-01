import Foundation

struct EufyC20ScaleParser {
    static let companyID: UInt16 = 48_228

    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 14 else { throw ScalePayloadError.tooShort }
        let flags = bytes[10]
        guard flags & 0x01 != 0 else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt16(bytes[12]) | UInt16(bytes[13]) << 8
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        var impedanceOhm: Double?
        if flags & 0x40 != 0 {
            guard bytes.count >= 19 else { throw ScalePayloadError.tooShort }
            let rawImpedance = UInt16(bytes[17]) | UInt16(bytes[18]) << 8
            if rawImpedance > 0 { impedanceOhm = Double(rawImpedance) / 10 }
        }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
            source: .communityProtocol,
            isStable: impedanceOhm != nil
        )
    }
}
