import Foundation

enum SenssunIF2121ScaleProtocol {
    static let serviceUUID = "FFF0"
    static let liveCharacteristicUUID = "FFF1"
    static let resultCharacteristicUUID = "FFF3"
    static let builtInParserID = "senssunIF2121"
}

struct SenssunIF2121ScaleParser {
    enum Phase: Equatable {
        case live
        case stable
        case bodyCompositionProgress(UInt8)
        case final
    }

    enum Packet: Equatable {
        case measurement(Phase, BodyMeasurement)
        case weightRemoved
        case progress(Phase)
    }

    /// Reassembles a complete `33 CC` frame from characteristic notifications.
    /// The captured IF2121A sends its 40-byte final result as two 20-byte FFF3
    /// indications, while the 17-byte live frames fit in one FFF1 notification.
    struct FrameAccumulator {
        private static let maximumFrameLength = 64
        private var buffer = Data()

        mutating func ingest(_ fragment: Data, now: Date = .now) throws -> Packet? {
            guard !fragment.isEmpty else { throw ScalePayloadError.tooShort }
            let bytes = [UInt8](fragment)
            let startsFrame = bytes.count >= 2 && bytes[0] == 0x33 && bytes[1] == 0xCC

            if startsFrame {
                buffer = fragment
            } else {
                guard !buffer.isEmpty else { throw ScalePayloadError.unsupported }
                buffer.append(fragment)
            }

            guard buffer.count >= 3 else {
                buffer.removeAll(keepingCapacity: true)
                throw ScalePayloadError.tooShort
            }
            let expectedLength = Int(buffer[buffer.startIndex.advanced(by: 2)])
            guard (4...Self.maximumFrameLength).contains(expectedLength) else {
                buffer.removeAll(keepingCapacity: true)
                throw ScalePayloadError.unsupported
            }
            guard buffer.count <= expectedLength else {
                buffer.removeAll(keepingCapacity: true)
                throw ScalePayloadError.unsupported
            }
            guard buffer.count == expectedLength else { return nil }

            let completed = buffer
            buffer.removeAll(keepingCapacity: true)
            return try SenssunIF2121ScaleParser.parse(completed, now: now)
        }

        mutating func reset() {
            buffer.removeAll(keepingCapacity: true)
        }
    }

    static func parse(_ data: Data, now: Date = .now) throws -> Packet {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { throw ScalePayloadError.tooShort }
        guard bytes[0] == 0x33, bytes[1] == 0xCC else {
            throw ScalePayloadError.unsupported
        }
        guard Int(bytes[2]) == bytes.count, checksum(bytes) == bytes.last else {
            throw ScalePayloadError.unsupported
        }

        switch bytes.count {
        case 17:
            return try parseLive(bytes, now: now)
        case 10:
            return try parseProgress(bytes)
        case 40:
            return try parseFinal(bytes, now: now)
        default:
            throw ScalePayloadError.unsupported
        }
    }

    private static func parseLive(_ bytes: [UInt8], now: Date) throws -> Packet {
        guard bytes[3] == 0x00,
              bytes[4] == 0x00,
              bytes[5] == 0x03,
              bytes[6] == 0x80,
              bytes[7] == 0x00,
              bytes[12] == 0x02,
              bytes[13] == 0x01 else {
            throw ScalePayloadError.unsupported
        }

        let weightKG = Double(readUInt16BE(bytes, at: 8)) / 100
        let weightLB = Double(readUInt16BE(bytes, at: 10)) / 100
        try validateMirroredWeights(weightKG: weightKG, weightLB: weightLB)

        // The scale reports roughly one kilogram while idle. Treat every value
        // below its documented 2 kg operating range as removal rather than a
        // user measurement.
        guard weightKG >= 2 else { return .weightRemoved }
        guard MeasurementLimits.weightKG.contains(weightKG) else { throw ScalePayloadError.unsupported }

        let stable = bytes[15] & 0x80 != 0
        let measurement = BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .senssunIF2121,
            isStable: stable
        )
        return .measurement(stable ? .stable : .live, measurement)
    }

    private static func parseProgress(_ bytes: [UInt8]) throws -> Packet {
        guard bytes[3] == 0x00,
              bytes[4] == 0x00,
              bytes[5] == 0x03,
              bytes[6] == 0x82,
              bytes[7] == 0x00,
              bytes[8] == 0x40 || bytes[8] == 0x20 else {
            throw ScalePayloadError.unsupported
        }
        return .progress(.bodyCompositionProgress(bytes[8]))
    }

    private static func parseFinal(_ bytes: [UInt8], now: Date) throws -> Packet {
        guard bytes[3] == 0x00,
              bytes[5] == 0x03,
              bytes[6] == 0x81,
              bytes[7] == 0x01,
              bytes[8] == 0xFF,
              bytes[9] == 0xFF,
              bytes[14] == 0x02,
              bytes[15] == 0x01,
              bytes[16] == 0x02 else {
            throw ScalePayloadError.unsupported
        }

        let weightKG = Double(readUInt16BE(bytes, at: 10)) / 100
        let weightLB = Double(readUInt16BE(bytes, at: 12)) / 100
        try validateMirroredWeights(weightKG: weightKG, weightLB: weightLB)
        guard MeasurementLimits.weightKG.contains(weightKG) else { throw ScalePayloadError.unsupported }

        // Bytes 22...38 carry body-composition/status data, but the capture is
        // not sufficient to name their units safely. Preserve the confirmed
        // final weight and leave impedance/body metrics unset.
        return .measurement(
            .final,
            BodyMeasurement(
                date: now,
                weightKG: weightKG,
                source: .senssunIF2121,
                isStable: true
            )
        )
    }

    private static func validateMirroredWeights(weightKG: Double, weightLB: Double) throws {
        guard weightKG.isFinite, weightLB.isFinite,
              abs(weightKG - weightLB * 0.453_592_37) <= 0.1 else {
            throw ScalePayloadError.unsupported
        }
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt8 {
        UInt8((bytes.dropLast().reduce(UInt32(1)) { $0 + UInt32($1) }) & 0xFF)
    }

    private static func readUInt16BE(_ bytes: [UInt8], at index: Int) -> UInt16 {
        UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
    }
}
