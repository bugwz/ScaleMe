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
    "verification": "fixtureValidated",
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
            CommunicationRuleCatalog.builtIn.contains {
                $0.id == CommunicationRuleCatalog.xiaomiMiScale2ID
                    && $0.builtInParser
                        == ScaleServiceDataProtocolFamily.xiaomiMiScale2.builtInParserID
                    && $0.match.transport == .advertisementServiceData
                    && $0.match.serviceUUID == "181D"
                    && $0.match.minimumLength == 10
                    && $0.match.maximumLength == 10
                    && $0.effectiveVerification == .fixtureValidated
            },
            "Xiaomi 181D service-data parser should be selectable in the built-in catalog"
        )
        expect(
            CommunicationRuleCatalog.builtIn.allSatisfy { $0.id.hasPrefix("protocol.builtin.") },
            "built-in rules should use the built-in protocol namespace"
        )
        let upstreamRecords = UpstreamScaleAdapterCatalog.records
        expect(upstreamRecords.count == 96, "all 33 ble-scale-sync and 63 openScale registrations should be inventoried")
        expect(
            upstreamRecords.filter { $0.source == .bleScaleSync }.count == 33,
            "ble-scale-sync registry should contain 33 adapters at the pinned revision"
        )
        expect(
            upstreamRecords.filter { $0.source == .openScale }.count == 63,
            "openScale ScaleFactory should contain 63 handler instances at the pinned revision"
        )
        expect(Set(upstreamRecords.map(\.id)).count == upstreamRecords.count, "upstream adapter IDs should be unique")
        let builtInIDs = Set(CommunicationRuleCatalog.builtIn.map(\.id))
        expect(builtInIDs.count == CommunicationRuleCatalog.builtIn.count, "built-in protocol IDs should be unique")
        let builtInNames = Set(CommunicationRuleCatalog.builtIn.map { $0.name.lowercased() })
        expect(builtInNames.count == CommunicationRuleCatalog.builtIn.count, "built-in protocol names should be unique")
        let displayedBuiltIn = CommunicationRuleCatalog.builtInForDisplay
        expect(
            displayedBuiltIn.prefix { $0.effectiveImplementation == .executable }.count
                == CommunicationRuleCatalog.builtIn.filter { $0.effectiveImplementation == .executable }.count,
            "displayed built-in protocols should place executable rules first"
        )
        guard var customRule = displayedBuiltIn.first else {
            preconditionFailure("built-in protocol catalog should not be empty")
        }
        customRule.id = "protocol.custom.selection-order"
        customRule.name = "External Selection Rule"
        customRule.origin = .custom
        let selectionRules = CommunicationRuleCatalog.rulesForSelection(custom: [customRule])
        expect(selectionRules.first?.id == customRule.id, "external protocols should precede built-in selection options")
        expect(
            Array(selectionRules.dropFirst().map(\.id)) == displayedBuiltIn.map(\.id),
            "built-in selection options should use the same order as the built-in protocol list"
        )
        expect(
            upstreamRecords.allSatisfy { record in
                let ruleID = UpstreamScaleAdapterCatalog.builtInRuleID(for: record)
                return builtInIDs.contains(ruleID)
            },
            "every upstream adapter should map to an executable rule or a visible protocol skeleton"
        )
        let groupedSkeletonRecords = Dictionary(
            grouping: upstreamRecords.filter { $0.mappedRuleID == nil },
            by: { UpstreamScaleAdapterCatalog.builtInRuleID(for: $0) }
        )
        expect(
            groupedSkeletonRecords.values.allSatisfy { records in
                guard let first = records.first else { return false }
                return records.allSatisfy {
                    $0.transport == first.transport
                        && $0.serviceUUIDs == first.serviceUUIDs
                        && $0.notifyCharacteristicUUIDs == first.notifyCharacteristicUUIDs
                        && $0.writeCharacteristicUUIDs == first.writeCharacteristicUUIDs
                        && $0.requirements == first.requirements
                }
            },
            "merged upstream records should describe the same transport, GATT topology, and session requirements"
        )
        expect(
            CommunicationRuleCatalog.builtIn.allSatisfy { rule in
                let slug = rule.id.dropFirst("protocol.builtin.".count)
                return slug.count <= 16
                    && !slug.contains(".")
                    && !slug.hasPrefix("ble-")
                    && !slug.hasPrefix("open-")
            },
            "built-in protocol ID slugs should be compact and source-neutral"
        )
        expect(
            UpstreamScaleAdapterCatalog.skeletonRules.allSatisfy {
                !$0.canMeasure && $0.effectiveVerification == .unverified
            },
            "incomplete upstream adapters should be explicitly unverified and unavailable for measurement"
        )
        expect(
            UpstreamScaleAdapterCatalog.skeletonRules.flatMap { $0.sourceLinks ?? [] }.count
                == upstreamRecords.filter { $0.mappedRuleID == nil }.count,
            "merged protocol skeletons should retain every upstream source link"
        )
        expect(
            UpstreamScaleAdapterCatalog.skeletonRules.contains {
                $0.name.contains("iHealth HS3") && $0.effectiveImplementation == .unsupportedPlatform
            },
            "Classic Bluetooth SPP adapters should be labeled as unsupported on the CoreBluetooth runtime"
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
