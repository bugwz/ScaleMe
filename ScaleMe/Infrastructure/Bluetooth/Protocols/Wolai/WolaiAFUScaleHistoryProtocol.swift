import Foundation

enum WolaiAFUScaleHistoryProtocol {
    static func parseRecord(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count >= 20 else { throw ScalePayloadError.tooShort }
        guard bytes.count == 20,
              bytes[0] == 0xAC,
              bytes[1] == 0x29,
              bytes[2] == 0x01,
              bytes[7] == 0x80,
              bytes[15] == 0,
              bytes[16] == 0,
              bytes[17] == 0x29,
              bytes[18] == 0xD8,
              checksum(bytes) == bytes[19] else {
            throw ScalePayloadError.unsupported
        }

        let timestamp = readUInt32BE(bytes, at: 3)
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        guard date >= Date(timeIntervalSince1970: 946_684_800),
              date <= now.addingTimeInterval(24 * 60 * 60) else {
            throw ScalePayloadError.unsupported
        }

        let zeroOffset: UInt32 = 0x68_00_00
        let weightRaw = readUInt24BE(bytes, at: 8)
        guard weightRaw >= zeroOffset else { throw ScalePayloadError.unsupported }
        let weightKG = Double(weightRaw - zeroOffset) / 1_000
        guard MeasurementLimits.weightKG.contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: date,
            weightKG: weightKG,
            impedanceOhm: try impedance(bytes, at: 11),
            secondaryImpedanceOhm: try impedance(bytes, at: 13),
            source: .wolaiAFU,
            isStable: true
        )
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt8 {
        UInt8(bytes[2...18].reduce(0) { $0 + UInt32($1) } & 0x1F)
    }

    private static func impedance(_ bytes: [UInt8], at index: Int) throws -> Double? {
        let raw = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
        guard raw != 0 else { return nil }
        guard (100...2_000).contains(raw) else { throw ScalePayloadError.unsupported }
        return Double(raw)
    }

    private static func readUInt24BE(_ bytes: [UInt8], at index: Int) -> UInt32 {
        UInt32(bytes[index]) << 16 | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2])
    }

    private static func readUInt32BE(_ bytes: [UInt8], at index: Int) -> UInt32 {
        UInt32(bytes[index]) << 24
            | UInt32(bytes[index + 1]) << 16
            | UInt32(bytes[index + 2]) << 8
            | UInt32(bytes[index + 3])
    }
}

struct WolaiAFUScaleHistorySession {
    private(set) var responseBytes = 0
    private(set) var measurements: [BodyMeasurement] = []
    private let maximumBytes: Int
    private let maximumRecords: Int

    init(maximumBytes: Int = 65_536, maximumRecords: Int = 512) {
        self.maximumBytes = maximumBytes
        self.maximumRecords = maximumRecords
    }

    mutating func consume(_ data: Data, now: Date = .now) throws -> BodyMeasurement? {
        guard data.count == 20 else { return nil }
        let bytes = [UInt8](data)
        guard bytes.starts(with: [0xAC, 0x29, 0x01]) else { return nil }
        responseBytes += data.count
        guard responseBytes <= maximumBytes, measurements.count < maximumRecords else {
            throw ScalePayloadError.unsupported
        }
        let measurement = try WolaiAFUScaleHistoryProtocol.parseRecord(data, now: now)
        measurements.append(measurement)
        return measurement
    }

    func completedMeasurements() -> [BodyMeasurement] {
        var keys = Set<String>()
        return measurements.sorted { $0.date < $1.date }.filter { measurement in
            let key = "\(Int(measurement.date.timeIntervalSince1970))|\(Int((measurement.weightKG * 1_000).rounded()))"
            return keys.insert(key).inserted
        }
    }
}
