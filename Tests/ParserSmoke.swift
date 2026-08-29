import Foundation

// All device samples below use synthetic credentials, addresses, measurements and dates.
// Packet layouts reproduce protocol behavior; these bytes are not raw personal captures.

@main
enum ParserSmoke {
    static func main() throws {
        let xiaomi = Data([
            0x00, 0x22,             // kg, stabilized, impedance stabilized
            0xE4, 0x07, 1, 2, 3, 4, 5,
            0xF4, 0x01,             // 500 ohm
            0xE0, 0x2E              // 12000 / 200 = 60 kg
        ])
        let xiaomiValue = try XiaomiScaleParser.parse(xiaomi)
        precondition(abs(xiaomiValue.weightKG - 60) < 0.001)
        precondition(xiaomiValue.impedanceOhm == 500)
        precondition(xiaomiValue.isStable)

        let removed = Data([
            0x00, 0x80,
            0xE4, 0x07, 1, 2, 3, 4, 6,
            0x00, 0x00,
            0x00, 0x00
        ])
        if case .measurement = try XiaomiScaleParser.parsePacket(removed) {
            preconditionFailure("离秤包不得解析为测量值")
        }

        let standardWeight = Data([0x00, 0xE0, 0x2E]) // 12000 * 0.005 kg
        let weightValue = try StandardWeightScaleParser.parse(standardWeight)
        precondition(abs(weightValue.weightKG - 60) < 0.001)
        precondition(!weightValue.isStable)

        let xiaomiGATTLive = Data([0x12, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        let xiaomiGATTStable = Data([0x32, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        let xiaomiGATTRemoved = Data([0xB2, 0xE0, 0x2E, 0xE4, 0x07, 1, 2, 3, 4, 5])
        guard case .measurement(let liveValue) = try XiaomiGATTWeightParser.parsePacket(xiaomiGATTLive),
              case .measurement(let stableValue) = try XiaomiGATTWeightParser.parsePacket(xiaomiGATTStable),
              case .weightRemoved = try XiaomiGATTWeightParser.parsePacket(xiaomiGATTRemoved) else {
            preconditionFailure("小米 GATT 状态包解析失败")
        }
        precondition(abs(liveValue.weightKG - 60.0) < 0.001)
        precondition(!liveValue.isStable)
        precondition(abs(stableValue.weightKG - 60.0) < 0.001)
        precondition(stableValue.isStable)

        let standardBody = Data([
            0x00, 0x04,             // weight present
            0xFA, 0x00,             // 25.0% body fat
            0xE0, 0x2E              // 60 kg
        ])
        let bodyValue = try StandardBodyCompositionParser.parse(standardBody)
        precondition(abs(bodyValue.weightKG - 60) < 0.001)
        precondition(abs((bodyValue.bodyFatPercent ?? 0) - 25) < 0.001)

        do {
            _ = try StandardBodyCompositionParser.parse(Data([0x08, 0x00, 0xFA, 0x00, 0x01]))
            preconditionFailure("截断的可选字段必须被拒绝")
        } catch ScalePayloadError.tooShort {
            // Expected.
        }

        print("Parser smoke tests passed")
    }
}
