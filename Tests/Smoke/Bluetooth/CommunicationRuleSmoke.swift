import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let json = #"""
{
  "schemaVersion": 2,
  "rules": [{
    "id": "protocol.custom.demo-scale",
    "name": "Fixture Demo Scale",
    "version": 1,
    "summary": "smoke fixture",
    "origin": "custom",
    "verification": "hardwareSample",
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
        expect(rules[0].id == "protocol.custom.demo-scale", "external rule should use the custom protocol namespace")
        expect(rules[0].match.serviceUUID == "FFF0", "UUID should normalize")
        expect(rules[0].effectiveVerification == .unverified, "external rules cannot claim hardware validation")
        expect(
            CommunicationRuleCatalog.builtIn.first(where: { $0.id == CommunicationRuleCatalog.xiaomiLegacyID })?
                .capabilities.contains(.historyRead) == true,
            "Xiaomi built-in rule should declare history read support"
        )

        let rendered = try CommunicationPayloadTemplate.render(
            "01FFFF{{sessionToken16BE}}",
            sessionToken: 0x1234
        )
        expect(rendered == Data([0x01, 0xFF, 0xFF, 0x12, 0x34]), "session token template should be bounded and deterministic")
        let responseRendered = try CommunicationPayloadTemplate.render(
            "03{{response:1:2}}",
            sessionToken: 0,
            response: Data([0xAA, 0x12, 0x34])
        )
        expect(responseRendered == Data([0x03, 0x12, 0x34]), "completion commands should reference bounded response fields")

        let historyTarget = CommunicationGATTTarget(serviceUUID: "FFF0", characteristicUUID: "FFF2")
        let byte = { (offset: Int) in
            CommunicationField(offset: offset, length: 1, byteOrder: .bigEndian, scale: 1)
        }
        let historyDecoder = CommunicationRuleDecoder(
            weight: CommunicationField(offset: 0, length: 2, byteOrder: .bigEndian, scale: 0.01),
            date: CommunicationDateDecoder(
                year: CommunicationField(offset: 2, length: 2, byteOrder: .bigEndian, scale: 1),
                month: byte(4), day: byte(5), hour: byte(6), minute: byte(7), second: byte(8)
            )
        )
        let historyOperation = CommunicationGATTOperation(
            capability: .historyRead,
            subscriptions: [historyTarget],
            commands: [CommunicationCommand(target: historyTarget, payloadHexTemplate: "F200")],
            historyResponse: CommunicationHistoryResponse(
                recordMatcher: .init(target: historyTarget, minimumLength: 1, maximumLength: 32),
                completionMatcher: .init(target: historyTarget, minimumLength: 1, maximumLength: 1, exactHex: "FF"),
                framing: .fixedLength,
                recordLength: 9,
                decoder: historyDecoder
            )
        )
        try CommunicationOperationValidator.validate(.init(historyRead: historyOperation))
        var historySession = try DeclarativeHistoryOperationSession(operation: historyOperation)
        _ = try historySession.consume(Data([0x17, 0x70, 0x07]), serviceUUID: "FFF0", characteristicUUID: "FFF2")
        guard case .progress(received: 1) = try historySession.consume(
            Data([0xEA, 8, 29, 10, 13, 32]),
            serviceUUID: "FFF0",
            characteristicUUID: "FFF2"
        ), case .completed(let history, _) = try historySession.consume(
            Data([0xFF]),
            serviceUUID: "FFF0",
            characteristicUUID: "FFF2"
        ) else {
            fatalError("declarative history framing should decode fragmented records")
        }
        expect(history.count == 1 && abs(history[0].weightKG - 60) < 0.001, "declarative history should decode weight and date")

        let payload = Data([0xA5, 0x5A, 0x1B, 0x94, 0xF4, 0x01])
        guard case .measurement(let measurement) = try DeclarativeCommunicationRuleParser.parse(payload, rule: rules[0]) else {
            fatalError("expected measurement")
        }
        expect(abs(measurement.weightKG - 70.60) < 0.0001, "big-endian weight should decode")
        expect(measurement.impedanceOhm == 500, "little-endian impedance should decode")
        expect(measurement.isStable, "masked stable flag should decode")
        expect(measurement.source == .customProtocol, "source should identify a custom protocol")
        expect(
            CommunicationRuleCatalog.builtIn.contains {
                $0.id == CommunicationRuleCatalog.qnAABBID
                    && $0.match.transport == .advertisementManufacturerData
            },
            "QN manufacturer broadcast parser should be in the built-in catalog"
        )
        expect(
            CommunicationRuleCatalog.builtIn.contains {
                $0.id == CommunicationRuleCatalog.aaaSeriesID
                    && $0.builtInParser == ScaleBroadcastProtocolFamily.aaaSeries.builtInParserID
            },
            "AAA-series parser should be in the built-in catalog"
        )
        let expectedBroadcastParserIDs = Set(ScaleBroadcastProtocolFamily.allBuiltInParserIDs)
        let catalogBroadcastParserIDs = Set(
            CommunicationRuleCatalog.builtIn
                .filter { $0.match.transport == .advertisementManufacturerData }
                .compactMap(\.builtInParser)
        )
        expect(
            expectedBroadcastParserIDs == catalogBroadcastParserIDs,
            "every broadcast protocol family should be selectable in the built-in catalog"
        )
        expect(
            CommunicationRuleCatalog.builtIn
                .filter { $0.match.transport == .advertisementManufacturerData }
                .allSatisfy { $0.effectiveVerification == .fixtureValidated },
            "manufacturer broadcast built-ins should be labeled as sample validated"
        )
        expect(
            CommunicationRuleCatalog.builtIn.allSatisfy { $0.id.hasPrefix("protocol.builtin.") },
            "built-in rules should use the built-in protocol namespace"
        )

        let invalidID = json.replacingOccurrences(of: "protocol.custom.demo-scale", with: "demo-scale")
        do {
            _ = try CommunicationRuleCodec.decode(Data(invalidID.utf8))
            fatalError("external rule without the custom protocol namespace should fail validation")
        } catch {
            // Expected.
        }

        let invalid = json.replacingOccurrences(of: "\"minimumLength\": 6", with: "\"minimumLength\": 3")
        do {
            _ = try CommunicationRuleCodec.decode(Data(invalid.utf8))
            fatalError("out-of-range fields should fail validation")
        } catch {
            // Expected.
        }

        var unsafeClear = rules[0]
        unsafeClear.operations = CommunicationRuleOperations(
            historyClear: CommunicationGATTOperation(
                capability: .historyClear,
                destructive: false,
                subscriptions: [],
                commands: [
                    CommunicationCommand(
                        target: .init(serviceUUID: "FFF0", characteristicUUID: "FFF1"),
                        payloadHexTemplate: "F201"
                    )
                ]
            )
        )
        do {
            try CommunicationRuleCodec.validate(unsafeClear)
            fatalError("history clear without destructive marker should fail validation")
        } catch {
            // Expected.
        }

        let unsafeManufacturerRule = json
            .replacingOccurrences(of: "characteristicNotification", with: "advertisementManufacturerData")
        do {
            _ = try CommunicationRuleCodec.decode(Data(unsafeManufacturerRule.utf8))
            fatalError("external manufacturer-data rules should remain disabled")
        } catch {
            // Expected.
        }

        print("Communication rule smoke tests passed")
    }
}
