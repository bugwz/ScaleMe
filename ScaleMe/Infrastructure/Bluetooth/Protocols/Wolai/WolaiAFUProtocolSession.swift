import Foundation

final class WolaiAFUProtocolSession: ScaleConnectedProtocolSession,
    ScaleHistoryCapability,
    ScaleTimeSynchronizationCapability {
    static let protocolDescriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.wolai-afu",
        name: "Wolai AFU",
        parserID: "wolaiAFU",
        transport: .characteristicNotification,
        discoveryCompatibility: .wolaiAFU,
        capabilities: [.liveMeasurement, .historyRead, .timeSynchronization]
    )
    let descriptor = protocolDescriptor

    static let communicationRule = CommunicationRule(
        id: protocolDescriptor.id,
        name: protocolDescriptor.name,
        version: 2,
        summary: "解析 AFU-WL-TZ-A1 / FG2313UWB-D 的实时测量及秤端历史记录；历史时间、体重、双阻抗与逐条确认流程已通过真机抓包和应用记录交叉验证。",
        origin: .builtIn,
        match: .init(
            transport: protocolDescriptor.transport,
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
            minimumLength: 20,
            maximumLength: 20
        ),
        decoder: nil,
        builtInParser: protocolDescriptor.parserID,
        verification: .fixtureValidated,
        operations: CommunicationRuleOperations(
            historyRead: CommunicationGATTOperation(
                capability: .historyRead,
                subscriptions: [
                    .init(
                        serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                        characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID
                    )
                ],
                commands: [
                    CommunicationCommand(
                        target: .init(
                            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                            characteristicUUID: WolaiAFUScaleAdapter.controlCharacteristicUUID
                        ),
                        payloadHexTemplate: "{{wolaiTimeInitialization}}",
                        writeMode: .automatic
                    )
                ],
                acknowledgementCommands: [
                    CommunicationCommand(
                        target: .init(
                            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                            characteristicUUID: WolaiAFUScaleAdapter.controlCharacteristicUUID
                        ),
                        payloadHexTemplate: "AC2704D80000000000000000000000000000DFBB",
                        writeMode: .automatic
                    )
                ],
                historyResponse: CommunicationHistoryResponse(
                    recordMatcher: .init(
                        target: .init(
                            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                            characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID
                        ),
                        minimumLength: 20,
                        maximumLength: 20,
                        prefixHex: "AC2901"
                    ),
                    builtInParser: "wolaiHistory20"
                ),
                timeoutSeconds: 10
            )
        ),
        requirements: [.timeSynchronization, .historyStateMachine, .multiFrameSession]
    )

    private enum TimerID {
        static let historyTimeout = "wolai.history.timeout"
        static let historyQuietCompletion = "wolai.history.quiet-completion"
    }

    private var didInitialize = false
    private var completedFinal: BodyMeasurement?
    private var historySession: WolaiAFUScaleHistorySession?
    private var didStartHistoryRequest = false

    func handle(_ event: ScaleProtocolEvent) throws -> [ScaleProtocolAction] {
        switch event {
        case .connected:
            reset()
            return [.discoverServices([WolaiAFUScaleAdapter.serviceUUID])]
        case .disconnected:
            reset()
            return []
        case .servicesDiscovered(let services):
            guard services.contains(WolaiAFUScaleAdapter.serviceUUID) else { return [] }
            return [.discoverCharacteristics(
                serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                characteristicUUIDs: [
                    WolaiAFUScaleAdapter.controlCharacteristicUUID,
                    WolaiAFUScaleAdapter.measurementCharacteristicUUID
                ]
            )]
        case .characteristicsDiscovered(let serviceUUID, let characteristicUUIDs):
            guard serviceUUID == WolaiAFUScaleAdapter.serviceUUID,
                  characteristicUUIDs.contains(WolaiAFUScaleAdapter.measurementCharacteristicUUID) else {
                return []
            }
            return [.subscribe(.init(
                serviceUUID: serviceUUID,
                characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID
            ))]
        case .notificationStateChanged(
            let serviceUUID,
            let characteristicUUID,
            let isNotifying,
            let changedAt
        ):
            guard serviceUUID == WolaiAFUScaleAdapter.serviceUUID,
                  characteristicUUID == WolaiAFUScaleAdapter.measurementCharacteristicUUID,
                  isNotifying else { return [] }
            if historySession != nil, !didStartHistoryRequest {
                didStartHistoryRequest = true
                didInitialize = true
                return [.write(command(payload: WolaiAFUScaleAdapter.makeTimeInitialization(at: changedAt)))]
            }
            guard !didInitialize else { return [] }
            didInitialize = true
            return try synchronizeTime(changedAt)
        case .notification(let serviceUUID, let characteristicUUID, let payload, let receivedAt):
            guard serviceUUID == WolaiAFUScaleAdapter.serviceUUID,
                  characteristicUUID == WolaiAFUScaleAdapter.measurementCharacteristicUUID else {
                return []
            }
            if historySession != nil,
               payload.starts(with: [0xAC, 0x29, 0x01]) {
                return consumeHistory(payload, receivedAt: receivedAt)
            }
            return actions(for: try WolaiAFUScaleParser.parse(payload, now: receivedAt))
        case .writeCompleted(let serviceUUID, let characteristicUUID, let succeeded):
            guard historySession != nil,
                  serviceUUID == WolaiAFUScaleAdapter.serviceUUID,
                  characteristicUUID == WolaiAFUScaleAdapter.controlCharacteristicUUID else { return [] }
            guard succeeded else { return failHistory(.writeFailed) }
            return quietCompletionActions()
        case .timer(let id):
            if id == TimerID.historyTimeout, historySession != nil {
                return failHistory(.timeout)
            }
            if id == TimerID.historyQuietCompletion,
               let measurements = historySession?.completedMeasurements() {
                resetHistory()
                return [
                    .cancelTimer(id: TimerID.historyTimeout),
                    .completeHistory(measurements)
                ]
            }
            return []
        }
    }

    func startHistoryRead(
        configuration: ScaleHistoryReadConfiguration
    ) throws -> [ScaleProtocolAction] {
        historySession = WolaiAFUScaleHistorySession(
            maximumBytes: configuration.maximumResponseBytes,
            maximumRecords: configuration.maximumRecords
        )
        didStartHistoryRequest = false
        return [
            .cancelTimer(id: TimerID.historyQuietCompletion),
            .scheduleTimer(id: TimerID.historyTimeout, seconds: configuration.timeoutSeconds),
            .subscribe(.init(
                serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID
            ))
        ]
    }

    func synchronizeTime(_ date: Date) throws -> [ScaleProtocolAction] {
        [.write(command(payload: WolaiAFUScaleAdapter.makeTimeInitialization(at: date)))]
    }

    var timeSynchronizationTarget: CommunicationGATTTarget {
        .init(
            serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
            characteristicUUID: WolaiAFUScaleAdapter.controlCharacteristicUUID
        )
    }

    private func actions(for packet: WolaiAFUScaleParser.Packet) -> [ScaleProtocolAction] {
        switch packet.phase {
        case .live:
            var actions: [ScaleProtocolAction] = []
            if completedFinal != nil {
                completedFinal = nil
                actions.append(.resetMeasurement)
            }
            actions.append(.reportLiveMeasurement(
                packet.measurement,
                phase: .measuringWeight,
                loadCycle: .protocolManaged
            ))
            return actions
        case .stable:
            guard completedFinal == nil else { return [] }
            return [.reportLiveMeasurement(
                packet.measurement,
                phase: .measuringBodyComposition,
                loadCycle: .protocolManaged
            )]
        case .final:
            var measurement = packet.measurement
            if let previous = completedFinal {
                // D6 may first report zero impedance. Accept newly available channels
                // for this result without creating another record or copying values
                // between load cycles. A live frame explicitly starts the next cycle.
                guard abs(previous.weightKG - measurement.weightKG) < 0.001,
                      (0...20).contains(measurement.date.timeIntervalSince(previous.date)),
                      (previous.impedanceOhm == nil && measurement.impedanceOhm != nil)
                        || (previous.secondaryImpedanceOhm == nil && measurement.secondaryImpedanceOhm != nil)
                else { return [] }
                measurement.id = previous.id
                measurement.date = previous.date
                measurement.impedanceOhm = previous.impedanceOhm ?? measurement.impedanceOhm
                measurement.secondaryImpedanceOhm = previous.secondaryImpedanceOhm ?? measurement.secondaryImpedanceOhm
            }
            completedFinal = measurement
            return [
                .write(command(payload: WolaiAFUScaleAdapter.makeFinalAcknowledgement())),
                .emit(.measurement(measurement), reliability: .protocolFinal)
            ]
        }
    }

    private func consumeHistory(_ payload: Data, receivedAt: Date) -> [ScaleProtocolAction] {
        do {
            guard var session = historySession,
                  try session.consume(payload, now: receivedAt) != nil else { return [] }
            historySession = session
            return [
                .write(command(payload: WolaiAFUScaleAdapter.makeHistoryAcknowledgement())),
                .reportHistoryProgress(received: session.measurements.count, announced: nil),
                .cancelTimer(id: TimerID.historyQuietCompletion),
                .scheduleTimer(id: TimerID.historyQuietCompletion, seconds: 1)
            ]
        } catch {
            return failHistory(.invalidPayload)
        }
    }

    private func quietCompletionActions() -> [ScaleProtocolAction] {
        let seconds = historySession?.measurements.isEmpty == false ? 1.0 : 2.0
        return [
            .cancelTimer(id: TimerID.historyQuietCompletion),
            .scheduleTimer(id: TimerID.historyQuietCompletion, seconds: seconds)
        ]
    }

    private func failHistory(_ failure: ScaleProtocolHistoryFailure) -> [ScaleProtocolAction] {
        resetHistory()
        return [
            .cancelTimer(id: TimerID.historyTimeout),
            .cancelTimer(id: TimerID.historyQuietCompletion),
            .failHistory(failure)
        ]
    }

    private func command(payload: Data) -> CommunicationCommand {
        CommunicationCommand(
            target: .init(
                serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                characteristicUUID: WolaiAFUScaleAdapter.controlCharacteristicUUID
            ),
            payloadHexTemplate: payload.map { String(format: "%02X", $0) }.joined(),
            writeMode: .automatic
        )
    }

    private func reset() {
        didInitialize = false
        completedFinal = nil
        resetHistory()
    }

    private func resetHistory() {
        historySession = nil
        didStartHistoryRequest = false
    }
}
