import Foundation

/// Broadcast-only Silvergear Smart Scale 108 protocol derived from two iOS
/// PacketLogger captures with known displayed outcomes. The post-measurement
/// body frame remains intentionally undecoded because one sample is not enough
/// to identify its field semantics.
struct Silvergear108ScaleParser {
    static let companyID: UInt16 = 0xA0AC
    static let advertisedServiceUUID = "FFB0"

    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedServiceUUIDs: Set<String> = [],
        now: Date = .now
    ) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        if !advertisedServiceUUIDs.isEmpty {
            guard advertisedServiceUUIDs.contains(where: {
                CommunicationRuleCodec.normalizeUUID($0) == advertisedServiceUUID
            }) else { throw ScalePayloadError.unsupported }
        }

        let bytes = [UInt8](packet.payload)
        guard bytes.count == 12 else { throw ScalePayloadError.tooShort }
        let payload = Array(bytes[6..<12])
        guard payload[4] == 0x0D else { throw ScalePayloadError.unsupported }
        let expectedChecksum = payload[0..<5].reduce(0) { ($0 + Int($1)) & 0x1F }
        guard expectedChecksum == Int(payload[5] & 0x1F) else {
            throw ScalePayloadError.unsupported
        }

        let decodedWeight = Int(payload[1] ^ 0xA0) << 16
            | Int(payload[2] ^ 0xA0) << 8
            | Int(payload[3] ^ 0xA0)
        let grams = decodedWeight - 0x8C0000
        let weightKG = Double(grams) / 1_000
        guard (2...300).contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .communityProtocol,
            isStable: ((payload[0] ^ 0xA0) & 0x80) != 0
        )
    }
}
