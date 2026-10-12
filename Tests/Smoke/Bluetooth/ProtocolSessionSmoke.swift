import Foundation

// All device samples below use synthetic credentials, addresses, measurements and dates.
// Packet layouts reproduce protocol behavior; these bytes are not raw personal captures.

@main
enum ProtocolSessionSmoke {
    static func main() throws {
        let session = SenssunIF2121ProtocolSession()

        let connected = try session.handle(.connected)
        guard case .discoverServices(let services) = connected.first,
              services == [SenssunIF2121ScaleProtocol.serviceUUID] else {
            preconditionFailure("Senssun session should request only its service")
        }

        let discoveredServices = try session.handle(.servicesDiscovered([
            SenssunIF2121ScaleProtocol.serviceUUID
        ]))
        guard case .discoverCharacteristics(let serviceUUID, let characteristicUUIDs) = discoveredServices.first,
              serviceUUID == SenssunIF2121ScaleProtocol.serviceUUID,
              characteristicUUIDs == [
                SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
                SenssunIF2121ScaleProtocol.resultCharacteristicUUID
              ] else {
            preconditionFailure("Senssun session should own characteristic discovery")
        }

        let subscriptions = try session.handle(.characteristicsDiscovered(
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUIDs: [
                SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
                SenssunIF2121ScaleProtocol.resultCharacteristicUUID,
                "FFF2"
            ]
        ))
        precondition(subscriptions.count == 2)

        let live = try session.handle(.notification(
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUID: SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
            payload: hexData("33CC110000038000177033AC02010200FF"),
            receivedAt: .now
        ))
        guard case .reportLiveMeasurement(
            let liveMeasurement,
            .measuringWeight,
            .coordinatorManaged
        ) = live.first else {
            preconditionFailure("live weight should remain a non-final session update")
        }
        precondition(abs(liveMeasurement.weightKG - 60.0) < 0.001)

        let stable = try session.handle(.notification(
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUID: SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
            payload: hexData("33CC110000038000196437FA02010280C7"),
            receivedAt: .now
        ))
        guard case .reportLiveMeasurement(
            let stableMeasurement,
            .measuringBodyComposition,
            .coordinatorManaged
        ) = stable.first else {
            preconditionFailure("stable weight should transition to body-composition measurement")
        }
        precondition(abs(stableMeasurement.weightKG - 65.0) < 0.001)

        let firstFragment = try session.handle(.notification(
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUID: SenssunIF2121ScaleProtocol.resultCharacteristicUUID,
            payload: hexData("33CC280001038101FFFF196437FA020102000000"),
            receivedAt: .now
        ))
        precondition(firstFragment.isEmpty)
        let final = try session.handle(.notification(
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUID: SenssunIF2121ScaleProtocol.resultCharacteristicUUID,
            payload: hexData("00000102030405060708090A0B0C0D0E0F1011F8"),
            receivedAt: .now
        ))
        guard case .emit(.measurement(let finalMeasurement), .protocolFinal) = final.first else {
            preconditionFailure("complete correlated result should emit one final measurement")
        }
        precondition(abs(finalMeasurement.weightKG - 65.0) < 0.001)

        let removed = try session.handle(.notification(
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUID: SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
            payload: hexData("33CC110000038000006400DC02010300DA"),
            receivedAt: .now
        ))
        guard case .emit(.weightRemoved, .protocolStable) = removed.first else {
            preconditionFailure("removal should be emitted as a protocol event")
        }

        try verifyWolaiSession()
        try verifyXiaomiSession()
        try verifyHuaweiHagridSession()

        print("Connected protocol session smoke tests passed")
    }

    private static func verifyHuaweiHagridSession() throws {
        guard ScaleProtocolRegistry.builtIn
            .descriptor(protocolID: HuaweiHagridProtocolSession.communicationRule.id)?
            .capabilities == [.liveMeasurement, .authentication] else {
            preconditionFailure("Huawei contextual session capabilities should be declared in the registry")
        }
        let credentials = try HuaweiHagridProtocol.Credentials(
            bluetoothAddress: "02:00:00:00:00:01",
            cakHex: "00112233445566778899AABBCCDDEEFF",
            c1Hex: "FFEEDDCCBBAA99887766554433221100",
            c2Hex: "0123456789ABCDEFFEDCBA9876543210"
        )
        let clientRandom = Data(repeating: 0xAB, count: 16)
        let session = HuaweiHagridProtocolSession(
            credentials: credentials,
            profile: UserProfile(),
            usesScale3GenderEncoding: true,
            randomData: { count in
                precondition(count == 16)
                return clientRandom
            }
        )
        guard case .discoverServices(let services) = try session.handle(.connected).first,
              services == [
                HuaweiHagridProtocol.bodyCompositionServiceUUID,
                HuaweiHagridProtocol.currentTimeServiceUUID,
                HuaweiHagridProtocol.userDataServiceUUID
              ] else {
            preconditionFailure("Huawei session should own authenticated service discovery")
        }
        let discovery = try session.handle(.servicesDiscovered([
            HuaweiHagridProtocol.userDataServiceUUID,
            HuaweiHagridProtocol.currentTimeServiceUUID,
            HuaweiHagridProtocol.bodyCompositionServiceUUID
        ]))
        precondition(discovery.count == 3)

        let notificationTargets: [(serviceUUID: String, characteristicUUID: String)] = [
            (HuaweiHagridProtocol.userDataServiceUUID, HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID),
            (HuaweiHagridProtocol.userDataServiceUUID, HuaweiHagridProtocol.authenticationTokenCharacteristicUUID),
            (HuaweiHagridProtocol.userDataServiceUUID, HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID),
            (HuaweiHagridProtocol.userDataServiceUUID, HuaweiHagridProtocol.setUserInfoCharacteristicUUID),
            (HuaweiHagridProtocol.currentTimeServiceUUID, HuaweiHagridProtocol.measurementStatusResultCharacteristicUUID),
            (HuaweiHagridProtocol.bodyCompositionServiceUUID, HuaweiHagridProtocol.realtimeWeightCharacteristicUUID)
        ]
        for serviceUUID in Set(notificationTargets.map(\.serviceUUID)) {
            let characteristics = Set(notificationTargets.lazy
                .filter { $0.serviceUUID == serviceUUID }
                .map(\.characteristicUUID))
            let subscriptions = try session.handle(.characteristicsDiscovered(
                serviceUUID: serviceUUID,
                characteristicUUIDs: characteristics
            ))
            precondition(subscriptions.count == characteristics.count)
        }

        var authenticationProbe: [ScaleProtocolAction] = []
        for target in notificationTargets {
            let actions = try session.handle(.notificationStateChanged(
                serviceUUID: target.serviceUUID,
                characteristicUUID: target.characteristicUUID,
                isNotifying: true,
                changedAt: .now
            ))
            if !actions.isEmpty { authenticationProbe = actions }
        }
        guard authenticationProbe.count == 1,
              case .write(let probeCommand) = authenticationProbe[0] else {
            preconditionFailure("Huawei authentication must wait for every required notification")
        }
        let renderedProbe = try rendered(probeCommand)
        precondition(renderedProbe == HuaweiHagridProtocol.makeAuthenticationProbe())

        let challenge = Data((0...15).map(UInt8.init))
        let authentication = try session.handle(.notification(
            serviceUUID: HuaweiHagridProtocol.userDataServiceUUID,
            characteristicUUID: HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID,
            payload: hexData("BD1300000102030405060708090A0B0C0D0E0F92C5"),
            receivedAt: .now
        ))
        let expectedToken = try HuaweiHagridProtocol.makeAuthenticationTokenPayload(
            challenge: challenge,
            randomB: clientRandom,
            cak: credentials.cak
        )
        let expectedFrames = HuaweiHagridProtocol.makePlainWriteFrames(payload: expectedToken)
        let authenticationFrames = try authentication.compactMap { action -> Data? in
            guard case .write(let command) = action else { return nil }
            return try rendered(command)
        }
        precondition(authenticationFrames == expectedFrames)
    }

    private static func verifyXiaomiSession() throws {
        guard let session = ScaleProtocolRegistry.builtIn.makeConnectedSession(
            protocolID: "protocol.builtin.xiaomi-181d"
        ), let history = session as? any ScaleHistoryCapability,
           let confirmation = session as? any ScaleHistoryImportConfirmationCapability,
           let unitConfiguration = session as? any ScaleUnitConfigurationCapability,
           let timeSynchronization = session as? any ScaleTimeSynchronizationCapability else {
            preconditionFailure("Xiaomi 181D should expose only its implemented optional capabilities")
        }
        guard case .discoverServices(let services) = try session.handle(.connected).first,
              services == [
                "1805",
                "181D",
                XiaomiScaleConfigurationProtocol.configurationServiceUUID
              ] else {
            preconditionFailure("Xiaomi session should discover measurement and configuration services")
        }
        let discovery = try session.handle(.servicesDiscovered(["181D"]))
        guard case .discoverCharacteristics(let serviceUUID, let characteristics) = discovery.first,
              serviceUUID == "181D",
              characteristics.contains("2A9D"),
              characteristics.contains(XiaomiScaleConfigurationProtocol.historyCharacteristicUUID) else {
            preconditionFailure("Xiaomi session should own live and history characteristic discovery")
        }
        let subscriptions = try session.handle(.characteristicsDiscovered(
            serviceUUID: "181D",
            characteristicUUIDs: [
                "2A9D",
                XiaomiScaleConfigurationProtocol.historyCharacteristicUUID
            ]
        ))
        precondition(subscriptions.count == 2)

        precondition(unitConfiguration.supportedHardwareUnits == Set(CommunicationWeightUnit.allCases))
        let unitActions = try unitConfiguration.configureHardwareUnit(.pounds)
        guard case .write(let unitCommand) = unitActions.first else {
            preconditionFailure("Xiaomi unit capability should produce its private configuration command")
        }
        let renderedUnitCommand = try rendered(unitCommand)
        precondition(renderedUnitCommand == XiaomiScaleConfigurationProtocol.unitCommand(.pounds))

        let synchronizationDate = Date(timeIntervalSince1970: 1_787_800_000)
        let timeActions = try timeSynchronization.synchronizeTime(synchronizationDate)
        guard case .write(let timeCommand) = timeActions.first else {
            preconditionFailure("Xiaomi time capability should produce a Current Time write")
        }
        let renderedTimeCommand = try rendered(timeCommand)
        precondition(renderedTimeCommand == BluetoothCurrentTimeProtocol.payload(for: synchronizationDate))

        let live = try session.handle(.notification(
            serviceUUID: "181D",
            characteristicUUID: "2A9D",
            payload: hexData("12E02EE4070102030405"),
            receivedAt: .now
        ))
        guard case .emit(.measurement(let liveMeasurement), .protocolStable) = live.first,
              abs(liveMeasurement.weightKG - 60.0) < 0.001 else {
            preconditionFailure("Xiaomi connected session should emit GATT weight packets")
        }

        let start = try history.startHistoryRead(configuration: .init(
            timeoutSeconds: 20,
            maximumResponseBytes: 65_536,
            maximumRecords: 512
        ))
        precondition(start.count == 2)
        let notificationReady = try session.handle(.notificationStateChanged(
            serviceUUID: "181D",
            characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID,
            isNotifying: true,
            changedAt: .now
        ))
        guard case .write(let query) = notificationReady.first else {
            preconditionFailure("Xiaomi history should query only after notification subscription")
        }
        let renderedQuery = try rendered(query)
        precondition(renderedQuery == XiaomiScaleHistoryProtocol.query())

        let count = try session.handle(xiaomiHistoryNotification("01020098843059"))
        guard count.count == 2,
              case .reportHistoryProgress(received: 0, announced: 2) = count[0],
              case .write(let startTransfer) = count[1] else {
            preconditionFailure("Xiaomi count response should start the record transfer")
        }
        let renderedStartTransfer = try rendered(startTransfer)
        precondition(renderedStartTransfer == XiaomiScaleHistoryProtocol.startTransfer)
        let records = try session.handle(xiaomiHistoryNotification(
            "321027E407010203040532E02EE4070103030405"
        ))
        guard case .reportHistoryProgress(received: 2, announced: 2) = records.first else {
            preconditionFailure("Xiaomi fixed-length records should report progress")
        }
        let completed = try session.handle(xiaomiHistoryNotification("03"))
        guard completed.count == 3,
              case .write(let stop) = completed[1],
              case .completeHistory(let measurements) = completed[2],
              measurements.count == 2 else {
            preconditionFailure("Xiaomi completion should stop transfer and expose history")
        }
        let renderedStop = try rendered(stop)
        precondition(renderedStop == XiaomiScaleHistoryProtocol.stop)
        let confirmed = try confirmation.confirmHistoryImport()
        guard case .write(let acknowledgement) = confirmed.first else {
            preconditionFailure("successful import should expose Xiaomi cursor acknowledgement")
        }
        let renderedAcknowledgement = try rendered(acknowledgement)
        precondition(
            renderedAcknowledgement == XiaomiScaleHistoryProtocol.acknowledge(
                since: XiaomiScaleHistoryProtocol.capturedQueryCursor
            )
        )
        let repeatedConfirmation = try confirmation.confirmHistoryImport()
        precondition(repeatedConfirmation.isEmpty)
    }

    private static func xiaomiHistoryNotification(_ payload: String) -> ScaleProtocolEvent {
        .notification(
            serviceUUID: "181D",
            characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID,
            payload: hexData(payload),
            receivedAt: .now
        )
    }

    private static func rendered(_ command: CommunicationCommand) throws -> Data {
        try CommunicationPayloadTemplate.render(command.payloadHexTemplate, sessionToken: 0)
    }

    private static func verifyWolaiSession() throws {
        guard ScaleProtocolRegistry.builtIn
            .descriptor(protocolID: "protocol.builtin.wolai-afu")?
            .capabilities.contains(.historyRead) == true else {
            preconditionFailure("connected protocol capabilities should be inspectable without starting a session")
        }
        guard let session = ScaleProtocolRegistry.builtIn.makeConnectedSession(
            protocolID: "protocol.builtin.wolai-afu"
        ) else {
            preconditionFailure("Wolai connected session should be registered")
        }
        guard case .discoverServices(let services) = try session.handle(.connected).first,
              services == [WolaiAFUScaleAdapter.serviceUUID] else {
            preconditionFailure("Wolai session should own service discovery")
        }
        let characteristicActions = try session.handle(.servicesDiscovered([
            WolaiAFUScaleAdapter.serviceUUID
        ]))
        guard case .discoverCharacteristics(let serviceUUID, let characteristicUUIDs)
            = characteristicActions.first,
              serviceUUID == WolaiAFUScaleAdapter.serviceUUID,
              characteristicUUIDs == [
                WolaiAFUScaleAdapter.controlCharacteristicUUID,
                WolaiAFUScaleAdapter.measurementCharacteristicUUID
              ] else {
            preconditionFailure("Wolai session should discover its control and measurement characteristics")
        }
        let subscribe = try session.handle(.characteristicsDiscovered(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUIDs: [
                WolaiAFUScaleAdapter.controlCharacteristicUUID,
                WolaiAFUScaleAdapter.measurementCharacteristicUUID
            ]
        ))
        guard case .subscribe(let target) = subscribe.first,
              target.characteristicUUID == WolaiAFUScaleAdapter.measurementCharacteristicUUID else {
            preconditionFailure("Wolai session should subscribe to measurements")
        }

        let initializationDate = Date(timeIntervalSince1970: TimeInterval(0x5E0C0C25))
        let initialization = try session.handle(.notificationStateChanged(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
            isNotifying: true,
            changedAt: initializationDate
        ))
        guard case .write(let initializationCommand) = initialization.first else {
            preconditionFailure("Wolai session should initialize time after notification subscription")
        }
        precondition(initializationCommand.writeMode == .automatic)
        let renderedInitialization = try CommunicationPayloadTemplate.render(
            initializationCommand.payloadHexTemplate,
            sessionToken: 0
        )
        precondition(renderedInitialization == WolaiAFUScaleAdapter.makeTimeInitialization(at: initializationDate))
        let repeatedInitialization = try session.handle(.notificationStateChanged(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
            isNotifying: true,
            changedAt: initializationDate
        ))
        precondition(repeatedInitialization.isEmpty)

        let live = try session.handle(wolaiNotification("AC2900684E20020005400064000000000029D51F"))
        guard live.count == 1,
              case .reportLiveMeasurement(let liveWeight, .measuringWeight, .protocolManaged) = live.first else {
            preconditionFailure("Wolai live frame should report protocol-managed live weight")
        }
        precondition(liveWeight.weightKG == 20, "First live frame must immediately expose weight")
        // The captured session switches offset 11 from 0x64 to 0x0A before
        // reporting live/stable weight. Measurements here are synthetic.
        let nextWeight = try session.handle(wolaiNotification("AC290068EA6002000540000A000000000029D501"))
        guard nextWeight.count == 1,
              case .reportLiveMeasurement(let updatedWeight, .measuringWeight, .protocolManaged) = nextWeight.first else {
            preconditionFailure("0x0A live frame must update weight before the final result")
        }
        precondition(updatedWeight.weightKG == 60)
        let stable = try session.handle(wolaiNotification("AC298068EA6002000540000A000000000029D501"))
        guard stable.count == 1,
              case .reportLiveMeasurement(let stableWeight, .measuringBodyComposition, .protocolManaged) = stable.first else {
            preconditionFailure("Wolai stable frame should enter body-composition phase")
        }
        precondition(stableWeight.weightKG == 60)
        for _ in 0..<5 {
            let repeated = try session.handle(wolaiNotification("AC298068EA6002000540000A000000000029D501"))
            guard repeated.count == 1,
                  case .reportLiveMeasurement(_, .measuringBodyComposition, .protocolManaged) = repeated.first else {
                preconditionFailure("Repeated stable weights must not finish AFU before impedance arrives")
            }
        }
        let finalEvent = wolaiNotification("AC29020001F40258018068EA600000000029D603")
        let final = try session.handle(finalEvent)
        guard final.count == 2,
              case .write(let acknowledgement) = final[0],
              case .emit(.measurement(let measurement), .protocolFinal) = final[1] else {
            preconditionFailure("Wolai final frame should acknowledge and emit exactly once")
        }
        let renderedAcknowledgement = try CommunicationPayloadTemplate.render(
            acknowledgement.payloadHexTemplate,
            sessionToken: 0
        )
        precondition(renderedAcknowledgement == WolaiAFUScaleAdapter.makeFinalAcknowledgement())
        precondition(abs(measurement.weightKG - 60.0) < 0.001)
        precondition(measurement.impedanceOhm == 500)
        precondition(measurement.secondaryImpedanceOhm == 600)
        precondition(measurement.bodyFatPercent == nil, "Raw impedance is not a device-supplied fat percentage")
        let duplicateFinal = try session.handle(finalEvent)
        precondition(duplicateFinal.isEmpty)

        let nextLive = try session.handle(wolaiNotification(
            "AC2900684E20020005400064000000000029D51F"
        ))
        guard nextLive.count == 2,
              case .resetMeasurement = nextLive[0],
              case .reportLiveMeasurement(_, .measuringWeight, .protocolManaged) = nextLive[1] else {
            preconditionFailure("first live frame after a final result should open a new measurement")
        }

        guard let history = session as? any ScaleHistoryCapability else {
            preconditionFailure("Wolai session should expose optional history capability")
        }
        let historyStart = try history.startHistoryRead(configuration: .init(
            timeoutSeconds: 15,
            maximumResponseBytes: 65_536,
            maximumRecords: 512
        ))
        precondition(historyStart.count == 3)
        guard case .subscribe(let historyTarget) = historyStart[2],
              historyTarget.characteristicUUID == WolaiAFUScaleAdapter.measurementCharacteristicUUID else {
            preconditionFailure("history capability should request its notification target")
        }
        let historyNow = Date(timeIntervalSince1970: TimeInterval(0x5E12A3A5 + 60))
        let historyInitialization = try session.handle(.notificationStateChanged(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
            isNotifying: true,
            changedAt: historyNow
        ))
        guard case .write = historyInitialization.first else {
            preconditionFailure("history read should begin with protocol-owned time initialization")
        }
        let historyRecord = try session.handle(.notification(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
            payload: hexData("AC29015E0D5DA58068C35001F40258000029D819"),
            receivedAt: historyNow
        ))
        guard historyRecord.count == 4,
              case .write(let historyAcknowledgement) = historyRecord[0],
              case .reportHistoryProgress(received: 1, announced: nil) = historyRecord[1] else {
            preconditionFailure("history record should be acknowledged and reported as progress")
        }
        let renderedHistoryAcknowledgement = try CommunicationPayloadTemplate.render(
            historyAcknowledgement.payloadHexTemplate,
            sessionToken: 0
        )
        precondition(renderedHistoryAcknowledgement == WolaiAFUScaleAdapter.makeHistoryAcknowledgement())
        let historyCompletion = try session.handle(.timer("wolai.history.quiet-completion"))
        guard historyCompletion.count == 2,
              case .completeHistory(let measurements) = historyCompletion[1],
              measurements.count == 1,
              abs(measurements[0].weightKG - 50.0) < 0.001 else {
            preconditionFailure("quiet history completion should emit collected measurements")
        }

        _ = try history.startHistoryRead(configuration: .init(
            timeoutSeconds: 15,
            maximumResponseBytes: 65_536,
            maximumRecords: 512
        ))
        let historyTimeout = try session.handle(.timer("wolai.history.timeout"))
        guard case .failHistory(.timeout) = historyTimeout.last else {
            preconditionFailure("history timeout should stay inside the optional capability")
        }
    }

    private static func wolaiNotification(_ payload: String) -> ScaleProtocolEvent {
        .notification(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
            payload: hexData(payload),
            receivedAt: .now
        )
    }

    private static func hexData(_ value: String) -> Data {
        var data = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let end = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<end], radix: 16) else {
                preconditionFailure("invalid hexadecimal fixture")
            }
            data.append(byte)
            index = end
        }
        return data
    }
}
