import Foundation

struct StandardWeightScaleParser {
    /// Bluetooth SIG Weight Measurement (0x2A9D), WSS 1.0.1.
    static func parse(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count >= 3 else { throw ScalePayloadError.tooShort }
        let flags = bytes[0]
        let imperial = flags & 0x01 != 0
        let raw = Double(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
        let weightKG = imperial ? raw * 0.01 * 0.453_592_37 : raw * 0.005
        var cursor = 3
        let timestamp: Date?
        if flags & 0x02 != 0, bytes.count >= cursor + 7 {
            timestamp = parseDate(Array(bytes[cursor..<(cursor + 7)]))
            cursor += 7
        } else if flags & 0x02 != 0 {
            throw ScalePayloadError.tooShort
        } else {
            timestamp = nil
        }
        if flags & 0x04 != 0 {
            guard bytes.count > cursor else { throw ScalePayloadError.tooShort }
            cursor += 1
        }
        if flags & 0x08 != 0 {
            guard bytes.count >= cursor + 4 else { throw ScalePayloadError.tooShort }
            // BMI is intentionally ignored and derived from the selected local profile.
            _ = UInt16(bytes[cursor]) | UInt16(bytes[cursor + 1]) << 8
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: timestamp ?? now,
            weightKG: weightKG,
            source: .bluetoothSIG,
            isStable: false
        )
    }

    static func parseDate(_ bytes: [UInt8]) -> Date? {
        guard bytes.count == 7 else { return nil }
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = Int(UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
        components.month = Int(bytes[2])
        components.day = Int(bytes[3])
        components.hour = Int(bytes[4])
        components.minute = Int(bytes[5])
        components.second = Int(bytes[6])
        return components.date
    }
}
