import Foundation

/// Broadcast-only AAA002 / AAA007 / AAA013 family. The application payload is
/// XOR-obfuscated with the high byte of the Company Identifier and carries a
/// 5-bit checksum. Only validated weight frames are accepted.
struct AAASeriesScaleParser {
    private static let supportedNames: Set<String> = ["AAA002", "AAA007", "AAA013"]

    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedName: String,
        now: Date = .now
    ) throws -> BodyMeasurement {
        let normalizedName = advertisedName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard supportedNames.contains(normalizedName) else { throw ScalePayloadError.unsupported }

        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 12 else { throw ScalePayloadError.tooShort }
        let xorKey = UInt8((packet.companyID >> 8) & 0xFF)
        let decoded = bytes[6..<12].map { $0 ^ xorKey }
        let expectedChecksum = UInt8(decoded[0..<5].reduce(0) { $0 + UInt32($1) } & 0x1F)
        guard expectedChecksum == decoded[5] & 0x1F, decoded[4] == 0xAD else {
            throw ScalePayloadError.unsupported
        }

        let value = UInt32(decoded[0]) << 24
            | UInt32(decoded[1]) << 16
            | UInt32(decoded[2]) << 8
            | UInt32(decoded[3])
        let weightKG = Double(value & 0x3_FFFF) / 1_000
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .communityProtocol,
            isStable: value & 0x8000_0000 != 0
        )
    }
}
