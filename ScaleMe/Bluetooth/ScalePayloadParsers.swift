import Foundation

enum ScalePayloadError: LocalizedError {
    case tooShort
    case unsupported
    case unstable

    var errorDescription: String? {
        switch self {
        case .tooShort: "蓝牙数据长度不足"
        case .unsupported: "暂不支持该数据格式"
        case .unstable: "等待秤面读数稳定"
        }
    }
}

struct XiaomiScaleParser {
    /// Parses the 13-byte payload advertised under Xiaomi's 0x181B service.
    /// Layout: control flags, measurement flags, 7-byte date, impedance LE, weight LE.
    static func parse(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let bytes = [UInt8](data.suffix(13))
        guard bytes.count >= 13 else { throw ScalePayloadError.tooShort }

        let flags0 = bytes[0]
        let flags1 = bytes[1]
        let isStable = (flags1 & 0x20) != 0
        let weightRemoved = (flags1 & 0x80) != 0
        guard !weightRemoved else { throw ScalePayloadError.unstable }

        let rawWeight = Double(UInt16(bytes[11]) | UInt16(bytes[12]) << 8)
        let unitBits = flags0 & 0xF0
        let weightKG: Double
        switch unitBits {
        case 0x10: weightKG = rawWeight / 100.0 * 0.453_592_37 // lb
        case 0x20: weightKG = rawWeight / 100.0 * 0.5         // 斤
        default: weightKG = rawWeight / 200.0                 // kg
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }

        let rawImpedance = UInt16(bytes[9]) | UInt16(bytes[10]) << 8
        let impedanceStable = (flags1 & 0x02) != 0
        let impedance = impedanceStable && rawImpedance > 0 ? Double(rawImpedance) : nil
        let date = measurementDate(bytes: bytes) ?? now

        return BodyMeasurement(
            date: date,
            weightKG: weightKG,
            impedanceOhm: impedance,
            source: .xiaomi,
            isStable: isStable
        )
    }

    private static func measurementDate(bytes: [UInt8]) -> Date? {
        let year = Int(UInt16(bytes[2]) | UInt16(bytes[3]) << 8)
        guard (2015...2100).contains(year) else { return nil }
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = year
        components.month = Int(bytes[4])
        components.day = Int(bytes[5])
        components.hour = Int(bytes[6])
        components.minute = Int(bytes[7])
        components.second = Int(bytes[8])
        return components.date
    }
}

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
        } else { timestamp = nil }
        if flags & 0x04 != 0 { cursor += 1 }
        var bmi: Double?
        if flags & 0x08 != 0, bytes.count >= cursor + 4 {
            bmi = Double(UInt16(bytes[cursor]) | UInt16(bytes[cursor + 1]) << 8) * 0.1
        }
        _ = bmi // BMI is derived from the selected local profile for consistency.
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(date: timestamp ?? now, weightKG: weightKG, source: .bluetoothSIG, isStable: true)
    }

    private static func parseDate(_ bytes: [UInt8]) -> Date? {
        guard bytes.count == 7 else { return nil }
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.year = Int(UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
        c.month = Int(bytes[2]); c.day = Int(bytes[3]); c.hour = Int(bytes[4]); c.minute = Int(bytes[5]); c.second = Int(bytes[6])
        return c.date
    }
}

struct StandardBodyCompositionParser {
    /// Bluetooth SIG Body Composition Measurement (0x2A9C).
    static func parse(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let b = [UInt8](data)
        guard b.count >= 4 else { throw ScalePayloadError.tooShort }
        let flags = UInt16(b[0]) | UInt16(b[1]) << 8
        let imperial = flags & 0x0001 != 0
        var cursor = 2
        let bodyFat = Double(readUInt16(b, &cursor)) * 0.1
        if flags & 0x0002 != 0 { cursor += 7 } // timestamp
        if flags & 0x0004 != 0 { cursor += 1 } // user ID
        var metabolism: Double?
        if flags & 0x0008 != 0 { metabolism = Double(readUInt16(b, &cursor)) }
        if flags & 0x0010 != 0 { cursor += 2 } // muscle percentage
        var muscleMass: Double?
        if flags & 0x0020 != 0 { muscleMass = mass(readUInt16(b, &cursor), imperial: imperial) }
        if flags & 0x0040 != 0 { cursor += 2 } // fat-free mass
        if flags & 0x0080 != 0 { cursor += 2 } // soft lean mass
        var waterMass: Double?
        if flags & 0x0100 != 0 { waterMass = mass(readUInt16(b, &cursor), imperial: imperial) }
        var impedance: Double?
        if flags & 0x0200 != 0 { impedance = Double(readUInt16(b, &cursor)) * 0.1 }
        var weight: Double?
        if flags & 0x0400 != 0 { weight = mass(readUInt16(b, &cursor), imperial: imperial) }
        guard let weight, (5...350).contains(weight) else { throw ScalePayloadError.unsupported }
        let waterPercent = waterMass.map { $0 / weight * 100 }
        return BodyMeasurement(date: now, weightKG: weight, impedanceOhm: impedance, bodyFatPercent: bodyFat, muscleMassKG: muscleMass, waterPercent: waterPercent, basalMetabolismKCal: metabolism, source: .bluetoothSIG, isStable: true)
    }

    private static func readUInt16(_ bytes: [UInt8], _ cursor: inout Int) -> UInt16 {
        guard cursor + 1 < bytes.count else { cursor = bytes.count; return 0 }
        defer { cursor += 2 }
        return UInt16(bytes[cursor]) | UInt16(bytes[cursor + 1]) << 8
    }

    private static func mass(_ raw: UInt16, imperial: Bool) -> Double {
        let value = Double(raw) * (imperial ? 0.01 : 0.005)
        return imperial ? value * 0.453_592_37 : value
    }
}
