import Foundation

@main
enum DeviceConfigurationSmoke {
    static func main() {
        for unit in XiaomiScaleHardwareUnit.allCases {
            let command = XiaomiScaleConfigurationProtocol.unitCommand(unit)
            precondition(command.count == 4)
            precondition(XiaomiScaleConfigurationProtocol.parseUnit(from: command) == unit)
        }

        precondition(XiaomiScaleConfigurationProtocol.parseUnit(from: Data([0x06, 0x04, 0x00])) == nil)
        precondition(XiaomiScaleConfigurationProtocol.parseUnit(from: Data([0x07, 0x04, 0x00, 0x00])) == nil)

        let poundsResponse = XiaomiScaleConfigurationProtocol.parseUnitCommandResponse(
            from: Data([0x10, 0x06, 0x04, 0x01, 0x01])
        )
        precondition(poundsResponse?.unit == .pounds)
        precondition(poundsResponse?.status == 0x01)
        let kilogramsResponse = XiaomiScaleConfigurationProtocol.parseUnitCommandResponse(
            from: Data([0x10, 0x06, 0x04, 0x00, 0x01])
        )
        precondition(kilogramsResponse?.unit == .kilograms)
        precondition(kilogramsResponse?.status == 0x01)
        precondition(XiaomiScaleConfigurationProtocol.parseUnitCommandResponse(from: Data([0x03, 0x01])) == nil)

        guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            preconditionFailure("无法创建测试时区")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 29,
            hour: 18,
            minute: 20,
            second: 30
        )) else {
            preconditionFailure("无法创建测试日期")
        }
        let time = [UInt8](BluetoothCurrentTimeProtocol.payload(for: date, calendar: calendar))
        precondition(time == [0xEA, 0x07, 8, 29, 18, 20, 30, 6, 0, 1])
        let parsedDate = BluetoothCurrentTimeProtocol.parseDate(from: Data(time), calendar: calendar)
        precondition(parsedDate == date)
        precondition(BluetoothCurrentTimeProtocol.parseDate(from: Data(time.prefix(6)), calendar: calendar) == nil)

        print("Device configuration smoke tests passed")
    }
}
