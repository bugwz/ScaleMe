import Foundation

enum XiaomiScaleHistoryProtocol {
    // Both Zepp and Mi Fitness used this cursor in the captured XMTZC04HM sessions.
    static let capturedQueryCursor = Data([0x98, 0x84, 0x30, 0x59])
    static let startTransfer = Data([0x02])
    static let stop = Data([0x03])

    static func query(since cursor: Data = capturedQueryCursor) -> Data {
        Data([0x01]) + cursor
    }

    static func acknowledge(since cursor: Data) -> Data {
        Data([0x04]) + cursor
    }

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
}

struct XiaomiScaleHistorySession {
    enum Event: Equatable {
        case readyToTransfer(announced: Int)
        case progress(received: Int, announced: Int?)
        case completed([BodyMeasurement])
    }

    private(set) var announcedCount: Int?
    let cursor: Data
    private(set) var responseBytes = 0
    private var buffer = Data()
    private var measurements: [BodyMeasurement] = []
    private var receivedRecords = 0
    private(set) var discardedRecords = 0
    private let maximumBytes: Int
    private let maximumRecords: Int

    init(
        cursor: Data = XiaomiScaleHistoryProtocol.capturedQueryCursor,
        maximumBytes: Int = 65_536,
        maximumRecords: Int = 512
    ) {
        self.cursor = cursor
        self.maximumBytes = maximumBytes
        self.maximumRecords = maximumRecords
    }

    mutating func consume(_ data: Data, now: Date = .now) throws -> Event? {
        responseBytes += data.count
        guard responseBytes <= maximumBytes else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](data)
        if bytes == [0x03] {
            guard buffer.isEmpty,
                  let announcedCount,
                  receivedRecords == announcedCount else {
                throw ScalePayloadError.tooShort
            }
            return .completed(deduplicatedMeasurements())
        }
        if bytes.count == 7, bytes[0] == 0x01 {
            guard announcedCount == nil,
                  Data(bytes[3...6]) == cursor else {
                throw ScalePayloadError.unsupported
            }
            let count = Int(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
            guard count <= maximumRecords else { throw ScalePayloadError.unsupported }
            announcedCount = count
            return .readyToTransfer(announced: count)
        }
        guard announcedCount != nil else { throw ScalePayloadError.unsupported }
        buffer.append(data)
        while buffer.count >= 10 {
            guard receivedRecords < maximumRecords else { throw ScalePayloadError.unsupported }
            let record = buffer.prefix(10)
            buffer.removeFirst(10)
            // A scale whose clock was never initialized can retain otherwise well-framed
            // records dated 1970. Count the slot so the transfer can finish, but never
            // persist a measurement with an invalid timestamp. One unusable device
            // record must not abort valid records later in the same history batch.
            if let measurement = try? XiaomiScaleHistoryProtocol.parseRecord(Data(record), now: now) {
                measurements.append(measurement)
            } else {
                discardedRecords += 1
            }
            receivedRecords += 1
        }
        guard announcedCount.map({ receivedRecords <= $0 }) == true else {
            throw ScalePayloadError.unsupported
        }
        return .progress(received: receivedRecords, announced: announcedCount)
    }

    private func deduplicatedMeasurements() -> [BodyMeasurement] {
        var keys = Set<String>()
        return measurements.sorted { $0.date < $1.date }.filter { measurement in
            let key = "\(Int(measurement.date.timeIntervalSince1970))|\(Int((measurement.weightKG * 1_000).rounded()))"
            return keys.insert(key).inserted
        }
    }
}
