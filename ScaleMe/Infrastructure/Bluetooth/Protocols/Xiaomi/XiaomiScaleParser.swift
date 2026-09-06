import Foundation

struct XiaomiScaleParser {
    static let communicationRule = CommunicationRule(
        id: "protocol.builtin.xiaomi-legacy",
        name: "Xiaomi 181B",
        version: 1,
        summary: "解析 0x181B 服务广播中的体重、稳定状态、时间与阻抗。",
        origin: .builtIn,
        match: .init(
            transport: .advertisementServiceData,
            serviceUUID: "181B",
            characteristicUUID: nil,
            minimumLength: 13
        ),
        decoder: nil,
        builtInParser: "xiaomiLegacyAdvertisement",
        verification: .fixtureValidated
    )
    enum Packet {
        case measurement(BodyMeasurement)
        case weightRemoved
    }

    /// Xiaomi's legacy 13-byte payload advertised under service data 0x181B.
    static func parsePacket(_ data: Data, now: Date = .now) throws -> Packet {
        let bytes = [UInt8](data.suffix(13))
        guard bytes.count >= 13 else { throw ScalePayloadError.tooShort }
        let controlFlags = bytes[0]
        let measurementFlags = bytes[1]
        let isStable = measurementFlags & 0x20 != 0
        guard measurementFlags & 0x80 == 0 else { return .weightRemoved }

        let rawWeight = Double(UInt16(bytes[11]) | UInt16(bytes[12]) << 8)
        let weightKG: Double
        switch controlFlags & 0xF0 {
        case 0x10: weightKG = rawWeight / 100 * 0.453_592_37
        case 0x20: weightKG = rawWeight / 100 * 0.5
        default: weightKG = rawWeight / 200
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }

        let rawImpedance = UInt16(bytes[9]) | UInt16(bytes[10]) << 8
        let impedanceOhm = measurementFlags & 0x02 != 0 && rawImpedance > 0
            ? Double(rawImpedance)
            : nil
        return .measurement(BodyMeasurement(
            date: isStable ? (measurementDate(bytes) ?? now) : now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
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

    private static func measurementDate(_ bytes: [UInt8]) -> Date? {
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

struct XiaomiGATTWeightParser {
    enum Packet {
        case measurement(BodyMeasurement)
        case weightRemoved
    }

    /// Legacy Xiaomi variants use RFU bits in standard characteristic 0x2A9D.
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
