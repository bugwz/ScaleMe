import Foundation

struct IcomonAFUScaleParser {
    enum Phase: String {
        case live
        case stable
        case final
    }

    struct Packet {
        var phase: Phase
        var measurement: BodyMeasurement
    }

    /// Captured AFU-WL-TZ-A1 / FG2313UWB-D frames notified on FFB2.
    static func parse(_ data: Data, now: Date = .now) throws -> Packet {
        let bytes = [UInt8](data)
        guard bytes.count >= 20 else { throw ScalePayloadError.tooShort }
        guard bytes.count == 20,
              bytes[0] == 0xAC,
              bytes[1] == 0x29,
              bytes[17] == 0x29,
              checksum(bytes) == bytes[19] else {
            throw ScalePayloadError.unsupported
        }

        switch (bytes[2], bytes[18]) {
        case (0x00, 0xD5), (0x80, 0xD5):
            guard Array(bytes[6...16]) == [0x02, 0x00, 0x05, 0x40, 0x00, 0x64, 0, 0, 0, 0, 0] else {
                throw ScalePayloadError.unsupported
            }
            let phase: Phase = bytes[2] == 0x80 ? .stable : .live
            return Packet(
                phase: phase,
                measurement: try measurement(
                    weightRaw: readUInt24BE(bytes, at: 3),
                    impedanceOhm: nil,
                    secondaryImpedanceOhm: nil,
                    isStable: phase == .stable,
                    now: now
                )
            )
        case (0x02, 0xD6):
            guard bytes[3] == 0,
                  bytes[8] == 0x01,
                  bytes[9] == 0x80,
                  bytes[13...16].allSatisfy({ $0 == 0 }) else {
                throw ScalePayloadError.unsupported
            }
            let primaryImpedanceOhm = Double(readUInt16BE(bytes, at: 4))
            let secondaryImpedanceOhm = Double(readUInt16BE(bytes, at: 6))
            guard (100...2_000).contains(primaryImpedanceOhm),
                  (100...2_000).contains(secondaryImpedanceOhm) else {
                throw ScalePayloadError.unsupported
            }
            return Packet(
                phase: .final,
                measurement: try measurement(
                    weightRaw: readUInt24BE(bytes, at: 10),
                    impedanceOhm: primaryImpedanceOhm,
                    secondaryImpedanceOhm: secondaryImpedanceOhm,
                    isStable: true,
                    now: now
                )
            )
        default:
            throw ScalePayloadError.unsupported
        }
    }

    private static func measurement(
        weightRaw: UInt32,
        impedanceOhm: Double?,
        secondaryImpedanceOhm: Double?,
        isStable: Bool,
        now: Date
    ) throws -> BodyMeasurement {
        let zeroOffset: UInt32 = 0x68_00_00
        guard weightRaw >= zeroOffset else { throw ScalePayloadError.unsupported }
        let weightKG = Double(weightRaw - zeroOffset) / 1_000
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
            secondaryImpedanceOhm: secondaryImpedanceOhm,
            source: .icomonAFU,
            isStable: isStable
        )
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt8 {
        UInt8(bytes[2...18].reduce(0) { $0 + UInt32($1) } & 0x1F)
    }

    private static func readUInt16BE(_ bytes: [UInt8], at index: Int) -> UInt16 {
        UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
    }

    private static func readUInt24BE(_ bytes: [UInt8], at index: Int) -> UInt32 {
        UInt32(bytes[index]) << 16 | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2])
    }
}
