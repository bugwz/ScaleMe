import Foundation

struct StandardBodyCompositionParser {
    /// Bluetooth SIG Body Composition Measurement (0x2A9C), BCS 1.0.
    static func parse(_ data: Data, now: Date = .now) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { throw ScalePayloadError.tooShort }
        let flags = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        let imperial = flags & 0x0001 != 0
        var cursor = 2
        let bodyFatPercent = Double(try readUInt16(bytes, cursor: &cursor)) * 0.1
        var timestamp: Date?
        if flags & 0x0002 != 0 {
            guard bytes.count >= cursor + 7 else { throw ScalePayloadError.tooShort }
            timestamp = StandardWeightScaleParser.parseDate(Array(bytes[cursor..<(cursor + 7)]))
            cursor += 7
        }
        if flags & 0x0004 != 0 {
            guard bytes.count > cursor else { throw ScalePayloadError.tooShort }
            cursor += 1
        }
        var basalMetabolismKCal: Double?
        if flags & 0x0008 != 0 {
            basalMetabolismKCal = Double(try readUInt16(bytes, cursor: &cursor))
        }
        if flags & 0x0010 != 0 { _ = try readUInt16(bytes, cursor: &cursor) }
        var muscleMassKG: Double?
        if flags & 0x0020 != 0 {
            muscleMassKG = massKG(try readUInt16(bytes, cursor: &cursor), imperial: imperial)
        }
        if flags & 0x0040 != 0 { _ = try readUInt16(bytes, cursor: &cursor) }
        if flags & 0x0080 != 0 { _ = try readUInt16(bytes, cursor: &cursor) }
        var waterMassKG: Double?
        if flags & 0x0100 != 0 {
            waterMassKG = massKG(try readUInt16(bytes, cursor: &cursor), imperial: imperial)
        }
        var impedanceOhm: Double?
        if flags & 0x0200 != 0 {
            impedanceOhm = Double(try readUInt16(bytes, cursor: &cursor)) * 0.1
        }
        var weightKG: Double?
        if flags & 0x0400 != 0 {
            weightKG = massKG(try readUInt16(bytes, cursor: &cursor), imperial: imperial)
        }
        guard let weightKG, (5...350).contains(weightKG) else {
            throw ScalePayloadError.unsupported
        }
        return BodyMeasurement(
            date: timestamp ?? now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
            bodyFatPercent: bodyFatPercent,
            muscleMassKG: muscleMassKG,
            waterPercent: waterMassKG.map { $0 / weightKG * 100 },
            basalMetabolismKCal: basalMetabolismKCal,
            source: .bluetoothSIG,
            isStable: false
        )
    }

    private static func readUInt16(_ bytes: [UInt8], cursor: inout Int) throws -> UInt16 {
        guard cursor + 1 < bytes.count else {
            cursor = bytes.count
            throw ScalePayloadError.tooShort
        }
        defer { cursor += 2 }
        return UInt16(bytes[cursor]) | UInt16(bytes[cursor + 1]) << 8
    }

    private static func massKG(_ raw: UInt16, imperial: Bool) -> Double {
        let value = Double(raw) * (imperial ? 0.01 : 0.005)
        return imperial ? value * 0.453_592_37 : value
    }
}
