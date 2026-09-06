import Foundation

enum XiaomiScaleConfigurationProtocol {
    struct UnitCommandResponse: Equatable {
        let unit: CommunicationWeightUnit
        let status: UInt8
    }

    static let configurationServiceUUID = "00001530-0000-3512-2118-0009AF100700"
    static let configurationCharacteristicUUID = "00001542-0000-3512-2118-0009AF100700"
    static let historyCharacteristicUUID = "00002A2F-0000-3512-2118-0009AF100700"

    static func unitCommand(_ unit: CommunicationWeightUnit) -> Data {
        Data([0x06, 0x04, 0x00, rawValue(for: unit)])
    }

    static func parseUnit(from data: Data) -> CommunicationWeightUnit? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4,
              bytes[0] == 0x06,
              bytes[1] == 0x04,
              bytes[2] == 0x00 else { return nil }
        return unit(for: bytes[3])
    }

    static func parseUnitCommandResponse(from data: Data) -> UnitCommandResponse? {
        let bytes = [UInt8](data)
        guard bytes.count == 5,
              bytes[0] == 0x10,
              bytes[1] == 0x06,
              bytes[2] == 0x04,
              let unit = unit(for: bytes[3]) else { return nil }
        return UnitCommandResponse(unit: unit, status: bytes[4])
    }

    private static func rawValue(for unit: CommunicationWeightUnit) -> UInt8 {
        switch unit {
        case .kilograms: 0x00
        case .pounds: 0x01
        case .jin: 0x02
        }
    }

    private static func unit(for rawValue: UInt8) -> CommunicationWeightUnit? {
        switch rawValue {
        case 0x00: .kilograms
        case 0x01: .pounds
        case 0x02: .jin
        default: nil
        }
    }
}

enum BluetoothCurrentTimeProtocol {
    static func payload(for date: Date, calendar: Calendar = .current) -> Data {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday],
            from: date
        )
        let year = UInt16(clamping: components.year ?? 0)
        let weekday = UInt8(clamping: ((components.weekday ?? 1) + 5) % 7 + 1)
        return Data([
            UInt8(year & 0x00FF), UInt8(year >> 8),
            UInt8(clamping: components.month ?? 0),
            UInt8(clamping: components.day ?? 0),
            UInt8(clamping: components.hour ?? 0),
            UInt8(clamping: components.minute ?? 0),
            UInt8(clamping: components.second ?? 0),
            weekday,
            0x00,
            0x01
        ])
    }

    static func parseDate(from data: Data, calendar: Calendar = .current) -> Date? {
        let bytes = [UInt8](data)
        guard bytes.count >= 7 else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = Int(UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
        components.month = Int(bytes[2])
        components.day = Int(bytes[3])
        components.hour = Int(bytes[4])
        components.minute = Int(bytes[5])
        components.second = Int(bytes[6])
        return components.date
    }
}
