import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let json = #"""
{
  "schemaVersion": 3,
  "rules": [{
    "id": "protocol.custom.demo-scale",
    "name": "Fixture Demo Scale",
    "version": 1,
    "summary": "smoke fixture",
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
        for offset in [Int.min, -1, 6, Int.max - 1, Int.max] {
            let invalidOffsetJSON = json.replacingOccurrences(
                of: "\"offset\": 2,",
                with: "\"offset\": \(offset),"
            )
            do {
                _ = try CommunicationRuleCodec.decode(Data(invalidOffsetJSON.utf8))
                preconditionFailure("out-of-bounds offsets must be rejected without overflowing")
            } catch CommunicationRuleError.invalidDocument {
                // Expected through the actual file-import validation path.
            }
            var invalidRule = rules[0]
            invalidRule.decoder?.weight.offset = offset
            do {
                _ = try DeclarativeCommunicationRuleParser.parse(
                    Data([0xA5, 0x5A, 0x17, 0x70, 0xF4, 0x01]), rule: invalidRule
                )
                preconditionFailure("runtime parsing must reject invalid offsets even without import validation")
            } catch ScalePayloadError.tooShort {
                // Expected.
            }
        }
        for length in [Int.min, 0, 9, Int.max] {
            var invalidRule = rules[0]
            invalidRule.decoder?.weight.length = length
            do {
                try CommunicationRuleCodec.validate(invalidRule)
                preconditionFailure("invalid field lengths must be rejected")
            } catch CommunicationRuleError.invalidDocument {
                // Expected.
            }
            do {
                _ = try DeclarativeCommunicationRuleParser.parse(
                    Data([0xA5, 0x5A, 0x17, 0x70, 0xF4, 0x01]), rule: invalidRule
                )
                preconditionFailure("runtime parsing must reject invalid lengths without overflowing")
            } catch ScalePayloadError.tooShort {
                // Expected.
            }
        }
        expect(rules[0].id == "protocol.custom.demo-scale", "external rule should use the custom protocol namespace")
        expect(rules[0].origin == .custom, "file imports should always be identified as local imports")
        expect(rules[0].sourceURL == nil, "file imports should not create a runtime source URL")
        expect(rules[0].implementedCapabilities == [.liveMeasurement], "capabilities should be derived from executable definitions")
        expect(rules[0].match.serviceUUID == "FFF0", "UUID should normalize")
        expect(
            CommunicationRuleCodec.normalizeUUID("0000ffb1-0000-1000-8000-00805f9b34fb") == "FFB1",
            "16-bit Bluetooth Base UUIDs should normalize to the rule identifier"
        )
        expect(
            CommunicationRuleCodec.normalizeUUID("12345678-0000-1000-8000-00805f9b34fb") == "12345678",
            "32-bit Bluetooth Base UUIDs should normalize to the assigned number"
        )
        expect(rules[0].effectiveVerification == .unverified, "external rules cannot claim hardware validation")
        expect(
            SimulationCommunicationRuleCatalog.initialRules.count == 2,
            "simulation should start with two external protocols"
        )
        for rule in SimulationCommunicationRuleCatalog.initialRules {
            try CommunicationRuleCodec.validate(rule)
        }
        let encodedRuleData = try CommunicationRuleCodec.encode([rules[0]])
        let encodedDocument = try JSONSerialization.jsonObject(with: encodedRuleData) as? [String: Any]
        let encodedRules = encodedDocument?["rules"] as? [[String: Any]]
        expect(encodedDocument?["schemaVersion"] as? Int == 3, "external protocol files should use schema 3")
        expect(encodedRules?.first?["origin"] == nil, "runtime origin must not be part of the public schema")
        expect(encodedRules?.first?["builtInParser"] == nil, "external files must not address private parsers")
        expect(encodedRules?.first?["verification"] == nil, "external files must not claim verification")
        expect(encodedRules?.first?["implementation"] == nil, "runtime implementation state must not be imported")
        let privateParserJSON = json.replacingOccurrences(
            of: "\"match\": {",
            with: "\"builtInParser\": \"bluetoothSIGWeight\", \"match\": {"
        )
        do {
            _ = try CommunicationRuleCodec.decode(Data(privateParserJSON.utf8))
            fatalError("external files must reject runtime-only parser fields")
        } catch CommunicationRuleError.invalidDocument {
            // Expected.
        }
        var simulatedImports = SimulationCommunicationRuleImportSequence()
        let firstSimulationRules = try CommunicationRuleCodec.decode(
            simulatedImports.makeImportData(fileName: "")
        )
        expect(firstSimulationRules.count == 1, "an empty simulation file should produce a valid protocol")
        do {
            _ = try simulatedImports.makeImportData(fileName: "anything.bin")
            preconditionFailure("the second simulation import should demonstrate field validation failure")
        } catch CommunicationRuleError.invalidDocument(let detail) {
            expect(detail.contains("weight 字段"), "the simulated validation error should identify the field")
        }
        let thirdSimulationRules = try CommunicationRuleCodec.decode(
            simulatedImports.makeImportData(fileName: "third.txt")
        )
        expect(thirdSimulationRules.count == 1, "the third simulation import should succeed again")
        do {
            _ = try simulatedImports.makeImportData(fileName: "fourth.data")
            preconditionFailure("even-numbered simulation imports should demonstrate field validation failure")
        } catch CommunicationRuleError.invalidDocument(let detail) {
            expect(detail.contains("weight 字段"), "the fourth simulation import should fail on the field again")
        }
        do {
            _ = try CommunicationRuleCodec.decode(
                Data(repeating: 0, count: CommunicationRuleCodec.maximumDocumentBytes + 1)
            )
            preconditionFailure("oversized protocol files should be rejected")
        } catch CommunicationRuleError.responseTooLarge {
            // Expected.
        }
        expect(
            CommunicationRuleCatalog.builtIn.first(where: { $0.id == XiaomiMiScale2BroadcastParser.communicationRule.id })?
                .capabilities.contains(.historyRead) == true,
            "MI SCALE2 built-in rule should declare captured 181D history support"
        )
        expect(
            CommunicationRuleCatalog.builtIn.first(where: { $0.id == XiaomiScaleParser.communicationRule.id })?
                .capabilities.contains(.historyRead) == false,
            "Xiaomi 181B advertising support must not claim unverified GATT history support"
        )
        let huaweiRule = CommunicationRuleCatalog.builtIn.first {
            $0.id == HuaweiHagridProtocolSession.communicationRule.id
        }
        expect(
            huaweiRule?.requirements?.contains(.historyStateMachine) == false
                && huaweiRule?.notifyTargets?.contains(.init(
                    serviceUUID: HuaweiHagridProtocol.bodyCompositionServiceUUID,
                    characteristicUUID: HuaweiHagridProtocol.historyWeightCharacteristicUUID
                )) == false
                && huaweiRule?.writeTargets?.contains(.init(
                    serviceUUID: HuaweiHagridProtocol.userDataServiceUUID,
                    characteristicUUID: HuaweiHagridProtocol.setUserInfoCharacteristicUUID
                )) == true,
            "Huawei rule targets should describe the implemented authenticated live session only"
        )
        let wolaiRule = CommunicationRuleCatalog.builtIn.first {
            $0.id == WolaiAFUProtocolSession.communicationRule.id
        }
        expect(
            CommunicationRuleCatalog.automaticRuleID(
                for: ScaleDiscoveryCompatibility.wolaiAFU.rawValue
            ) == WolaiAFUProtocolSession.communicationRule.id
                &&
            wolaiRule?.capabilities.contains(.historyRead) == true
                && wolaiRule?.operations?.historyRead?.historyResponse?.builtInParser == "wolaiHistory20",
            "automatic Wolai AFU selection should expose the captured history operation"
        )
        guard let automaticWolaiID = UUID(uuidString: "B9A86CC2-299B-4D52-AD2D-8E19AF1A0AF1") else {
            preconditionFailure("invalid deterministic Wolai device ID")
        }
        var pairedScaleRegistry = PairedScaleRegistry()
        pairedScaleRegistry.updateScales([PairedScale(
            id: automaticWolaiID,
            name: "AFU-WL-TZ-A1",
            modelName: "AFU-WL-TZ-A1",
            compatibility: ScaleDiscoveryCompatibility.wolaiAFU.rawValue
        )])
        expect(
            pairedScaleRegistry.selectedRule(for: automaticWolaiID) == nil
                && pairedScaleRegistry.effectiveRule(for: automaticWolaiID)?.id
                    == WolaiAFUProtocolSession.communicationRule.id,
            "an automatically identified Wolai scale should resolve its built-in connected protocol before app state refresh"
        )
        guard let automaticXiaomiID = UUID(uuidString: "B9A86CC2-299B-4D52-AD2D-8E19AF1A0AF2"),
              let automaticHuaweiID = UUID(uuidString: "B9A86CC2-299B-4D52-AD2D-8E19AF1A0AF3") else {
            preconditionFailure("invalid deterministic connected protocol device IDs")
        }
        let automaticConnectedProtocols: [(UUID, String, String)] = [
            (automaticWolaiID, ScaleDiscoveryCompatibility.wolaiAFU.rawValue, WolaiAFUProtocolSession.communicationRule.id),
            (automaticXiaomiID, ScaleDiscoveryCompatibility.xiaomiMiScale2Advertisement.rawValue, XiaomiMiScale2BroadcastParser.communicationRule.id),
            (automaticHuaweiID, ScaleDiscoveryCompatibility.huaweiHagridAuthorizationRequired.rawValue, HuaweiHagridProtocolSession.communicationRule.id)
        ]
        pairedScaleRegistry.updateScales(automaticConnectedProtocols.map { deviceID, compatibility, _ in
            PairedScale(id: deviceID, name: "Fixture scale", modelName: "Fixture scale", compatibility: compatibility)
        })
        for (deviceID, _, expectedRuleID) in automaticConnectedProtocols {
            expect(
                pairedScaleRegistry.effectiveRule(for: deviceID)?.id == expectedRuleID,
                "each automatically recognized connected protocol should resolve before app state refresh"
            )
        }

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
        let wolaiTime = Date(timeIntervalSince1970: TimeInterval(0x5E0C0C25))
        let wolaiHistoryRequest = try CommunicationPayloadTemplate.render(
            "{{wolaiTimeInitialization}}",
            sessionToken: 0,
            now: wolaiTime
        )
        expect(
            wolaiHistoryRequest == WolaiAFUScaleAdapter.makeTimeInitialization(at: wolaiTime),
            "Wolai history time template should render a checksummed request"
        )

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

        for raw: UInt16 in [0, 1, 499, 35_001, 50_000] {
            let payload = Data([0xA5, 0x5A, UInt8(raw >> 8), UInt8(raw & 0xFF), 0xF4, 0x01])
            guard case .measurement(let decoded) = try DeclarativeCommunicationRuleParser.parse(payload, rule: rules[0]) else {
                fatalError("weights within 0...500 kg must decode")
            }
            expect(abs(decoded.weightKG - Double(raw) * 0.01) < 0.000_001, "inclusive weight bounds")
        }
        for raw: UInt16 in [50_001, 65_535] {
            do {
                _ = try DeclarativeCommunicationRuleParser.parse(
                    Data([0xA5, 0x5A, UInt8(raw >> 8), UInt8(raw & 0xFF), 0xF4, 0x01]), rule: rules[0]
                )
                fatalError("weights above 500 kg must be rejected")
            } catch ScalePayloadError.unsupported {}
        }
        var negativeWeightRule = rules[0]
        negativeWeightRule.decoder?.weight.add = -1
        do {
            _ = try DeclarativeCommunicationRuleParser.parse(
                Data([0xA5, 0x5A, 0, 0, 0xF4, 0x01]), rule: negativeWeightRule
            )
            fatalError("negative decoded weights must be rejected")
        } catch ScalePayloadError.unsupported {}

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
                $0.id == QNAABBScaleParser.communicationRule.id
                    && $0.match.transport == .advertisementManufacturerData
            },
            "QN manufacturer broadcast parser should be in the built-in catalog"
        )
        expect(
            CommunicationRuleCatalog.builtIn.contains {
                $0.id == SenssunIF2121ProtocolSession.communicationRule.id
                    && $0.builtInParser == SenssunIF2121ScaleProtocol.builtInParserID
                    && $0.match.serviceUUID == SenssunIF2121ScaleProtocol.serviceUUID
                    && $0.match.characteristicUUID == SenssunIF2121ScaleProtocol.liveCharacteristicUUID
                    && $0.notifyTargets == [
                        CommunicationGATTTarget(
                            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
                            characteristicUUID: SenssunIF2121ScaleProtocol.liveCharacteristicUUID
                        ),
                        CommunicationGATTTarget(
                            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
                            characteristicUUID: SenssunIF2121ScaleProtocol.resultCharacteristicUUID
                        )
                    ]
                    && $0.effectiveVerification == .fixtureValidated
                    && $0.effectiveImplementation == .experimental
            },
            "Senssun IF2121 GATT parser should be selectable with both notification targets"
        )
        expect(
            CommunicationRuleCatalog.builtIn.contains {
                $0.id == AAASeriesScaleParser.communicationRule.id
                    && $0.builtInParser == AAASeriesScaleParser.descriptor.parserID
            },
            "AAA-series parser should be in the built-in catalog"
        )
        let expectedBroadcastParserIDs = Set(
            ScaleProtocolRegistry.builtIn.descriptors
                .filter { $0.transport == .advertisementManufacturerData }
                .map(\.parserID)
        )
        let catalogBroadcastParserIDs = Set(
            CommunicationRuleCatalog.builtIn
                .filter { $0.match.transport == .advertisementManufacturerData }
                .compactMap(\.builtInParser)
        )
        expect(
            expectedBroadcastParserIDs == catalogBroadcastParserIDs,
            "every broadcast protocol family should be selectable in the built-in catalog"
        )
        for descriptor in ScaleProtocolRegistry.builtIn.descriptors {
            let rule = CommunicationRuleCatalog.builtIn.first { $0.id == descriptor.id }
            expect(rule?.builtInParser == descriptor.parserID, "adapter and communication rule IDs must stay aligned")
            expect(rule?.match.transport == descriptor.transport, "adapter and communication rule transports must stay aligned")
        }
        expect(
            CommunicationRuleCatalog.builtIn
                .filter { $0.match.transport == .advertisementManufacturerData }
                .allSatisfy { $0.effectiveVerification == .fixtureValidated },
            "manufacturer broadcast built-ins should be labeled as sample validated"
        )
        expect(
            CommunicationRuleCatalog.builtIn.contains {
                $0.id == XiaomiMiScale2BroadcastParser.communicationRule.id
                    && $0.builtInParser
                        == XiaomiMiScale2BroadcastParser.descriptor.parserID
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
        let confirmedIDs = Set(CommunicationRuleCatalog.confirmedExecutableBuiltIn.map(\.id))
        let pendingIDs = Set(CommunicationRuleCatalog.pendingBuiltIn.map(\.id))
        expect(
            confirmedIDs.isDisjoint(with: pendingIDs)
                && confirmedIDs.union(pendingIDs) == Set(CommunicationRuleCatalog.builtIn.map(\.id)),
            "built-in protocol groups should partition the complete catalog"
        )
        expect(
            CommunicationRuleCatalog.confirmedExecutableBuiltIn.allSatisfy(\.isConfirmedExecutable)
                && CommunicationRuleCatalog.pendingBuiltIn.allSatisfy { !$0.isConfirmedExecutable },
            "built-in protocol groups should follow implementation and verification state"
        )
        expect(
            pendingIDs.contains(HuaweiHagridProtocolSession.communicationRule.id)
                && pendingIDs.contains(SenssunIF2121ProtocolSession.communicationRule.id),
            "experimental sessions should remain visible in the pending built-in group"
        )
        let catalogedPendingProtocols = CommunicationRuleCatalog.pendingBuiltIn.filter {
            $0.builtInParser == nil
        }
        expect(catalogedPendingProtocols.count == 55, "all cataloged pending device protocols should remain visible")
        expect(
            catalogedPendingProtocols.allSatisfy {
                $0.effectiveVerification == .unverified
                    && !($0.sourceLinks ?? []).isEmpty
            },
            "pending device protocols should retain sources without claiming executable parsing or validation"
        )
        expect(
            pendingIDs.contains("protocol.builtin.eufy-p2")
                && pendingIDs.contains("protocol.builtin.renpho")
                && pendingIDs.contains("protocol.builtin.xiaomi-s800"),
            "previously cataloged community device protocols should remain in the pending group"
        )
        expect(
            Set(CommunicationRuleCatalog.builtIn.map(\.id)).count == CommunicationRuleCatalog.builtIn.count,
            "every built-in protocol ID should be unique"
        )
        let selectionRules = CommunicationRuleCatalog.rulesForSelection(custom: rules)
        let selectableBuiltIn = CommunicationRuleCatalog.builtInForDisplay.filter(\.canMeasure)
        expect(
            Array(selectionRules.prefix(selectableBuiltIn.count)).map(\.id) == selectableBuiltIn.map(\.id),
            "device protocol selection should show executable built-in protocols before external protocols"
        )
        expect(
            selectionRules.allSatisfy(\.canMeasure)
                && Set(selectionRules.map(\.id)).isDisjoint(with: Set(catalogedPendingProtocols.map(\.id))),
            "protocol skeletons should remain cataloged but must not be selectable for live measurement"
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

        var privateTemplateRule = rules[0]
        privateTemplateRule.operations = CommunicationRuleOperations(
            historyClear: CommunicationGATTOperation(
                capability: .historyClear,
                destructive: true,
                subscriptions: [],
                commands: [CommunicationCommand(
                    target: .init(serviceUUID: "FFF0", characteristicUUID: "FFF1"),
                    payloadHexTemplate: "{{wolaiTimeInitialization}}"
                )]
            )
        )
        do {
            try CommunicationRuleCodec.validate(privateTemplateRule)
            fatalError("external rules must not use a built-in protocol placeholder")
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
