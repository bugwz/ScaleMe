import Foundation

enum XiaomiScaleHistoryProtocol {
    static let enableHistory = Data([0x01, 0x96, 0x8A, 0xBD, 0x62])
    static let requestRecent = Data([0x01, 0xFF, 0xFF, 0xFF, 0xFF])
    static let startTransfer = Data([0x02])
    static let stop = Data([0x03])
    static let acknowledgeRecent = Data([0x04, 0xFF, 0xFF, 0xFF, 0xFF])

    static func parseRecord(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count == 10 else { throw ScalePayloadError.tooShort }
        let status = bytes[0]
        guard status & 0x20 != 0, status & 0x80 == 0 else { throw ScalePayloadError.unsupported }

        let rawWeight = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
        let nativeWeight = Double(rawWeight) / ((status & 0x01 != 0 || status & 0x10 != 0) ? 100 : 200)
        let weightKG: Double
        if status & 0x01 != 0 {
            weightKG = nativeWeight * 0.453_592_37
        } else if status & 0x10 != 0 {
            weightKG = nativeWeight * 0.5
        } else {
            weightKG = nativeWeight
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = Int(bytes[3]) | Int(bytes[4]) << 8
        components.month = Int(bytes[5])
        components.day = Int(bytes[6])
        components.hour = Int(bytes[7])
        components.minute = Int(bytes[8])
        components.second = Int(bytes[9])
        guard let date = components.date,
              date >= Date(timeIntervalSince1970: 946_684_800),
              date <= now.addingTimeInterval(24 * 60 * 60) else {
            throw ScalePayloadError.unsupported
        }
        return BodyMeasurement(
            date: date,
            weightKG: weightKG,
            source: .xiaomi,
            isStable: true
        )
    }

    static func parseBodyCompositionRecord(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count == 13 else { throw ScalePayloadError.tooShort }
        let unitFlags = bytes[0]
        let status = bytes[1]
        guard status & 0x20 != 0, status & 0x80 == 0 else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt16(bytes[11]) | UInt16(bytes[12]) << 8
        let nativeWeight = Double(rawWeight) / ((unitFlags & 0x01 != 0 || status & 0x40 != 0) ? 100 : 200)
        let weightKG: Double
        if unitFlags & 0x01 != 0 {
            weightKG = nativeWeight * 0.453_592_37
        } else if status & 0x40 != 0 {
            weightKG = nativeWeight * 0.5
        } else {
            weightKG = nativeWeight
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = Int(bytes[2]) | Int(bytes[3]) << 8
        components.month = Int(bytes[4])
        components.day = Int(bytes[5])
        components.hour = Int(bytes[6])
        components.minute = Int(bytes[7])
        components.second = 0
        guard let date = components.date,
              date >= Date(timeIntervalSince1970: 946_684_800),
              date <= now.addingTimeInterval(86_400) else { throw ScalePayloadError.unsupported }
        let rawImpedance = UInt16(bytes[9]) | UInt16(bytes[10]) << 8
        let impedance = status & 0x02 != 0 && (50...3_000).contains(Int(rawImpedance))
            ? Double(rawImpedance) : nil
        return BodyMeasurement(
            date: date,
            weightKG: weightKG,
            impedanceOhm: impedance,
            source: .xiaomi,
            isStable: true
        )
    }
}

struct XiaomiScaleHistorySession {
    enum Event: Equatable {
        case progress(received: Int, announced: Int?)
        case completed([BodyMeasurement])
    }

    private(set) var announcedCount: Int?
    private(set) var responseBytes = 0
    private var buffer = Data()
    private var measurements: [BodyMeasurement] = []
    private let maximumBytes: Int
    private let maximumRecords: Int

    init(maximumBytes: Int = 65_536, maximumRecords: Int = 512) {
        self.maximumBytes = maximumBytes
        self.maximumRecords = maximumRecords
    }

    mutating func consume(_ data: Data, now: Date = .now) throws -> Event? {
        responseBytes += data.count
        guard responseBytes <= maximumBytes else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](data)
        if bytes == [0x03] {
            guard buffer.isEmpty else { throw ScalePayloadError.tooShort }
            return .completed(deduplicatedMeasurements())
        }
        if bytes.count >= 6, bytes[0] == 0x01 {
            let marker = UInt16(bytes[2]) << 8 | UInt16(bytes[3])
            if marker == 0xFFFF || marker == 0x0000 {
                announcedCount = Int(bytes[1])
                buffer.removeAll(keepingCapacity: true)
                return .progress(received: measurements.count, announced: announcedCount)
            }
            return nil
        }
        if bytes.count == 13 || bytes.count == 26 {
            for offset in stride(from: 0, to: bytes.count, by: 13) where measurements.count < maximumRecords {
                let record = Data(bytes[offset..<(offset + 13)])
                if let measurement = try? XiaomiScaleHistoryProtocol.parseBodyCompositionRecord(record, now: now) {
                    measurements.append(measurement)
                }
            }
            return .progress(received: measurements.count, announced: announcedCount)
        }
        buffer.append(data)
        while buffer.count >= 10, measurements.count < maximumRecords {
            let record = buffer.prefix(10)
            buffer.removeFirst(10)
            if let measurement = try? XiaomiScaleHistoryProtocol.parseRecord(Data(record), now: now) {
                measurements.append(measurement)
            }
        }
        guard measurements.count < maximumRecords || buffer.isEmpty else { throw ScalePayloadError.unsupported }
        return .progress(received: measurements.count, announced: announcedCount)
    }

    private func deduplicatedMeasurements() -> [BodyMeasurement] {
        var keys = Set<String>()
        return measurements.sorted { $0.date < $1.date }.filter { measurement in
            let key = "\(Int(measurement.date.timeIntervalSince1970))|\(Int((measurement.weightKG * 1_000).rounded()))"
            return keys.insert(key).inserted
        }
    }
}
