import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let json = #"""
{
  "schemaVersion": 1,
  "rules": [{
    "id": "community.fixture.demo-scale",
    "name": "Fixture Demo Scale",
    "version": 1,
    "summary": "smoke fixture",
    "origin": "custom",
    "match": {
      "transport": "characteristicNotification",
      "serviceUUID": "fff0",
      "characteristicUUID": "fff1",
      "minimumLength": 6,
      "maximumLength": 6,
      "prefixHex": "A55A"
    },
    "decoder": {
      "weight": {
        "offset": 2,
        "length": 2,
        "byteOrder": "bigEndian",
        "scale": 0.01,
        "add": 0
      },
      "weightUnit": "kilograms",
      "impedance": {
        "offset": 4,
        "length": 2,
        "byteOrder": "littleEndian",
        "scale": 1,
        "add": 0
      },
      "stableWhen": { "offset": 0, "mask": 128, "equals": 128 }
    }
  }]
}
"""#

@main
struct CommunicationRuleSmoke {
    static func main() throws {
        let rules = try CommunicationRuleCodec.decode(Data(json.utf8))
        expect(rules.count == 1, "one rule should decode")
        expect(rules[0].match.serviceUUID == "FFF0", "UUID should normalize")

        let payload = Data([0xA5, 0x5A, 0x1B, 0x94, 0xF4, 0x01])
        guard case .measurement(let measurement) = try DeclarativeCommunicationRuleParser.parse(payload, rule: rules[0]) else {
            fatalError("expected measurement")
        }
        expect(abs(measurement.weightKG - 70.60) < 0.0001, "big-endian weight should decode")
        expect(measurement.impedanceOhm == 500, "little-endian impedance should decode")
        expect(measurement.isStable, "masked stable flag should decode")
        expect(measurement.source == .customProtocol, "source should identify a custom protocol")

        let invalid = json.replacingOccurrences(of: "\"minimumLength\": 6", with: "\"minimumLength\": 3")
        do {
            _ = try CommunicationRuleCodec.decode(Data(invalid.utf8))
            fatalError("out-of-range fields should fail validation")
        } catch {
            // Expected.
        }

        print("Communication rule smoke tests passed")
    }
}
