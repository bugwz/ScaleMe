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
    enum Packet {
        case measurement(BodyMeasurement)
        case weightRemoved
    }

    /// Parses the 13-byte payload advertised under Xiaomi's 0x181B service.
    /// Layout: control flags, measurement flags, 7-byte date, impedance LE, weight LE.
    static func parsePacket(_ data: Data, now: Date = .now) throws -> Packet {
        let bytes = [UInt8](data.suffix(13))
        guard bytes.count >= 13 else { throw ScalePayloadError.tooShort }

        let flags0 = bytes[0]
        let flags1 = bytes[1]
        let isStable = (flags1 & 0x20) != 0
        let weightRemoved = (flags1 & 0x80) != 0
        guard !weightRemoved else { return .weightRemoved }

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
        // Xiaomi only guarantees that the embedded timestamp is valid for a stable value.
        let date = isStable ? (measurementDate(bytes: bytes) ?? now) : now

        return .measurement(BodyMeasurement(
            date: date,
            weightKG: weightKG,
            impedanceOhm: impedance,
            source: .xiaomi,
            isStable: isStable
        ))
    }

    static func parse(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        switch try parsePacket(data, now: now) {
        case .measurement(let measurement): measurement
        case .weightRemoved: throw ScalePayloadError.unstable
        }
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
        } else if flags & 0x02 != 0 {
            throw ScalePayloadError.tooShort
        } else { timestamp = nil }
        if flags & 0x04 != 0 {
            guard bytes.count > cursor else { throw ScalePayloadError.tooShort }
            cursor += 1
        }
        var bmi: Double?
        if flags & 0x08 != 0 {
            guard bytes.count >= cursor + 4 else { throw ScalePayloadError.tooShort }
            bmi = Double(UInt16(bytes[cursor]) | UInt16(bytes[cursor + 1]) << 8) * 0.1
        }
        _ = bmi // BMI is derived from the selected local profile for consistency.
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(date: timestamp ?? now, weightKG: weightKG, source: .bluetoothSIG, isStable: false)
    }

    fileprivate static func parseDate(_ bytes: [UInt8]) -> Date? {
        guard bytes.count == 7 else { return nil }
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.year = Int(UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
        c.month = Int(bytes[2]); c.day = Int(bytes[3]); c.hour = Int(bytes[4]); c.minute = Int(bytes[5]); c.second = Int(bytes[6])
        return c.date
    }
}

struct XiaomiGATTWeightParser {
    enum Packet {
        case measurement(BodyMeasurement)
        case weightRemoved
    }

    /// Some Xiaomi scales send legacy status bits in the RFU nibble of 0x2A9D.
    /// Bit 5 marks the final stable value and bit 7 marks weight removal.
    static func matches(_ data: Data) -> Bool {
        guard let flags = data.first else { return false }
        return flags & 0xF0 != 0
    }

    static func parsePacket(_ data: Data, now: Date = .now) throws -> Packet {
        guard matches(data), let flags = data.first else { throw ScalePayloadError.unsupported }
        guard flags & 0x80 == 0 else { return .weightRemoved }

        var measurement = try StandardWeightScaleParser.parse(data, now: now)
        measurement.source = .xiaomi
        measurement.isStable = flags & 0x20 != 0
        return .measurement(measurement)
    }
}

struct IcomonAFUScaleParser {
    enum Phase: String {
        case live
        case stable
        case final
    }

    struct Packet {
        var phase: Phase
        var measurement: BodyMeasurement
        var secondaryImpedanceOhm: Double?
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
                    isStable: phase == .stable,
                    now: now
                ),
                secondaryImpedanceOhm: nil
            )

        case (0x02, 0xD6):
            guard bytes[3] == 0,
                  bytes[8] == 0x01,
                  bytes[9] == 0x80,
                  bytes[13...16].allSatisfy({ $0 == 0 }) else {
                throw ScalePayloadError.unsupported
            }
            let primaryImpedance = Double(readUInt16BE(bytes, at: 4))
            let secondaryImpedance = Double(readUInt16BE(bytes, at: 6))
            guard (100...2_000).contains(primaryImpedance),
                  (100...2_000).contains(secondaryImpedance) else {
                throw ScalePayloadError.unsupported
            }
            return Packet(
                phase: .final,
                measurement: try measurement(
                    weightRaw: readUInt24BE(bytes, at: 10),
                    impedanceOhm: primaryImpedance,
                    isStable: true,
                    now: now
                ),
                secondaryImpedanceOhm: secondaryImpedance
            )

        default:
            throw ScalePayloadError.unsupported
        }
    }

    private static func measurement(
        weightRaw: UInt32,
        impedanceOhm: Double?,
        isStable: Bool,
        now: Date
    ) throws -> BodyMeasurement {
        let weightKG = Double(weightRaw) / 100_000
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
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

struct StandardBodyCompositionParser {
    /// Bluetooth SIG Body Composition Measurement (0x2A9C).
    static func parse(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let b = [UInt8](data)
        guard b.count >= 4 else { throw ScalePayloadError.tooShort }
        let flags = UInt16(b[0]) | UInt16(b[1]) << 8
        let imperial = flags & 0x0001 != 0
        var cursor = 2
        let bodyFat = Double(try readUInt16(b, &cursor)) * 0.1
        var timestamp: Date?
        if flags & 0x0002 != 0 {
            guard b.count >= cursor + 7 else { throw ScalePayloadError.tooShort }
            timestamp = StandardWeightScaleParser.parseDate(Array(b[cursor..<(cursor + 7)]))
            cursor += 7
        }
        if flags & 0x0004 != 0 {
            guard b.count > cursor else { throw ScalePayloadError.tooShort }
            cursor += 1
        }
        var metabolism: Double?
        if flags & 0x0008 != 0 { metabolism = Double(try readUInt16(b, &cursor)) }
        if flags & 0x0010 != 0 { _ = try readUInt16(b, &cursor) } // muscle percentage
        var muscleMass: Double?
        if flags & 0x0020 != 0 { muscleMass = mass(try readUInt16(b, &cursor), imperial: imperial) }
        if flags & 0x0040 != 0 { _ = try readUInt16(b, &cursor) } // fat-free mass
        if flags & 0x0080 != 0 { _ = try readUInt16(b, &cursor) } // soft lean mass
        var waterMass: Double?
        if flags & 0x0100 != 0 { waterMass = mass(try readUInt16(b, &cursor), imperial: imperial) }
        var impedance: Double?
        if flags & 0x0200 != 0 { impedance = Double(try readUInt16(b, &cursor)) * 0.1 }
        var weight: Double?
        if flags & 0x0400 != 0 { weight = mass(try readUInt16(b, &cursor), imperial: imperial) }
        guard let weight, (5...350).contains(weight) else { throw ScalePayloadError.unsupported }
        let waterPercent = waterMass.map { $0 / weight * 100 }
        return BodyMeasurement(date: timestamp ?? now, weightKG: weight, impedanceOhm: impedance, bodyFatPercent: bodyFat, muscleMassKG: muscleMass, waterPercent: waterPercent, basalMetabolismKCal: metabolism, source: .bluetoothSIG, isStable: false)
    }

    private static func readUInt16(_ bytes: [UInt8], _ cursor: inout Int) throws -> UInt16 {
        guard cursor + 1 < bytes.count else {
            cursor = bytes.count
            throw ScalePayloadError.tooShort
        }
        defer { cursor += 2 }
        return UInt16(bytes[cursor]) | UInt16(bytes[cursor + 1]) << 8
    }

    private static func mass(_ raw: UInt16, imperial: Bool) -> Double {
        let value = Double(raw) * (imperial ? 0.01 : 0.005)
        return imperial ? value * 0.453_592_37 : value
    }
}
