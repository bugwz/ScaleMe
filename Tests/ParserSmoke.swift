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

        let standardWeight = Data([0x00, 0xE0, 0x2E]) // 12000 * 0.005 kg
        let weightValue = try StandardWeightScaleParser.parse(standardWeight)
        precondition(abs(weightValue.weightKG - 60) < 0.001)

        let standardBody = Data([
            0x00, 0x04,             // weight present
            0xFA, 0x00,             // 25.0% body fat
            0xE0, 0x2E              // 60 kg
        ])
        let bodyValue = try StandardBodyCompositionParser.parse(standardBody)
        precondition(abs(bodyValue.weightKG - 60) < 0.001)
        precondition(abs((bodyValue.bodyFatPercent ?? 0) - 25) < 0.001)

        print("Parser smoke tests passed")
    }
}
