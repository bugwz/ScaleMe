import Foundation

final class XiaomiMiScale2ProtocolSession: ScaleConnectedProtocolSession,
    ScaleHistoryCapability,
    ScaleHistoryImportConfirmationCapability,
    ScaleUnitConfigurationCapability,
    ScaleTimeSynchronizationCapability {
    static let protocolDescriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.xiaomi-181d",
        name: "Xiaomi XMTZC04HM",
        parserID: "xiaomiMiScale2Connected",
        transport: .characteristicNotification,
        discoveryCompatibility: .xiaomiMiScale2Advertisement,
        capabilities: [
            .liveMeasurement,
            .weightRemoval,
            .historyRead,
            .hardwareUnitConfiguration,
            .timeSynchronization
        ]
    )
    let descriptor = protocolDescriptor

    private enum TimerID {
        static let historyTimeout = "xiaomi.history.timeout"
    }

    private static let serviceUUID = "181D"
    private static let weightCharacteristicUUID = "2A9D"
    private static let currentTimeServiceUUID = "1805"
    private static let currentTimeCharacteristicUUID = "2A2B"
    private static let historyCharacteristicUUID =
        XiaomiScaleConfigurationProtocol.historyCharacteristicUUID

    private var historySession: XiaomiScaleHistorySession?
    private var pendingHistoryCursor: Data?
    private var didStartHistoryRequest = false

    func handle(_ event: ScaleProtocolEvent) throws -> [ScaleProtocolAction] {
        switch event {
        case .connected:
            reset()
            return [.discoverServices([
                Self.serviceUUID,
                Self.currentTimeServiceUUID,
                XiaomiScaleConfigurationProtocol.configurationServiceUUID
            ])]
        case .disconnected:
            reset()
            return []
        case .servicesDiscovered(let services):
            var actions: [ScaleProtocolAction] = []
            if services.contains(Self.serviceUUID) {
                actions.append(.discoverCharacteristics(
                    serviceUUID: Self.serviceUUID,
                    characteristicUUIDs: [
                        Self.weightCharacteristicUUID,
                        Self.historyCharacteristicUUID
                    ]
                ))
            }
            if services.contains(Self.currentTimeServiceUUID) {
                actions.append(.discoverCharacteristics(
                    serviceUUID: Self.currentTimeServiceUUID,
                    characteristicUUIDs: [Self.currentTimeCharacteristicUUID]
                ))
            }
            if services.contains(XiaomiScaleConfigurationProtocol.configurationServiceUUID) {
                actions.append(.discoverCharacteristics(
                    serviceUUID: XiaomiScaleConfigurationProtocol.configurationServiceUUID,
                    characteristicUUIDs: [
                        XiaomiScaleConfigurationProtocol.configurationCharacteristicUUID
                    ]
                ))
            }
            return actions
        case .characteristicsDiscovered(let serviceUUID, let characteristicUUIDs):
            guard serviceUUID == Self.serviceUUID else { return [] }
            return characteristicUUIDs.intersection([
                Self.weightCharacteristicUUID,
                Self.historyCharacteristicUUID
            ]).sorted().map { characteristicUUID in
                .subscribe(.init(
                    serviceUUID: Self.serviceUUID,
                    characteristicUUID: characteristicUUID
                ))
            }
        case .notificationStateChanged(
            let serviceUUID,
            let characteristicUUID,
            let isNotifying,
            _
        ):
            guard serviceUUID == Self.serviceUUID,
                  characteristicUUID == Self.historyCharacteristicUUID,
                  isNotifying,
                  historySession != nil,
                  !didStartHistoryRequest else { return [] }
            didStartHistoryRequest = true
            return [.write(command(payload: XiaomiScaleHistoryProtocol.query()))]
        case .notification(let serviceUUID, let characteristicUUID, let payload, let receivedAt):
            guard serviceUUID == Self.serviceUUID else { return [] }
            if characteristicUUID == Self.historyCharacteristicUUID,
               historySession != nil {
                return consumeHistory(payload, receivedAt: receivedAt)
            }
            guard characteristicUUID == Self.weightCharacteristicUUID else { return [] }
            switch try XiaomiGATTWeightParser.parsePacket(payload, now: receivedAt) {
            case .measurement(let measurement):
                return [.emit(.measurement(measurement), reliability: .protocolStable)]
            case .weightRemoved:
                return [.emit(.weightRemoved, reliability: .protocolStable)]
            }
        case .writeCompleted(let serviceUUID, let characteristicUUID, let succeeded):
            guard serviceUUID == Self.serviceUUID,
                  characteristicUUID == Self.historyCharacteristicUUID,
                  historySession != nil,
                  !succeeded else { return [] }
            return failHistory(.writeFailed)
        case .timer(let id):
            guard id == TimerID.historyTimeout, historySession != nil else { return [] }
            return failHistory(.timeout)
        }
    }

    func startHistoryRead(
        configuration: ScaleHistoryReadConfiguration
    ) throws -> [ScaleProtocolAction] {
        let cursor = XiaomiScaleHistoryProtocol.capturedQueryCursor
        historySession = XiaomiScaleHistorySession(
            cursor: cursor,
            maximumBytes: configuration.maximumResponseBytes,
            maximumRecords: configuration.maximumRecords
        )
        pendingHistoryCursor = cursor
        didStartHistoryRequest = false
        return [
            .scheduleTimer(id: TimerID.historyTimeout, seconds: configuration.timeoutSeconds),
            .subscribe(historyTarget)
        ]
    }

    func confirmHistoryImport() throws -> [ScaleProtocolAction] {
        guard let cursor = pendingHistoryCursor else { return [] }
        pendingHistoryCursor = nil
        return [.write(command(payload: XiaomiScaleHistoryProtocol.acknowledge(since: cursor)))]
    }

    var supportedHardwareUnits: Set<CommunicationWeightUnit> {
        Set(CommunicationWeightUnit.allCases)
    }

    var hardwareUnitConfigurationTarget: CommunicationGATTTarget {
        .init(
            serviceUUID: XiaomiScaleConfigurationProtocol.configurationServiceUUID,
            characteristicUUID: XiaomiScaleConfigurationProtocol.configurationCharacteristicUUID
        )
    }

    func configureHardwareUnit(_ unit: CommunicationWeightUnit) throws -> [ScaleProtocolAction] {
        guard supportedHardwareUnits.contains(unit) else { return [] }
        return [.write(command(
            payload: XiaomiScaleConfigurationProtocol.unitCommand(unit),
            target: hardwareUnitConfigurationTarget
        ))]
    }

    var timeSynchronizationTarget: CommunicationGATTTarget {
        .init(
            serviceUUID: Self.currentTimeServiceUUID,
            characteristicUUID: Self.currentTimeCharacteristicUUID
        )
    }

    func synchronizeTime(_ date: Date) throws -> [ScaleProtocolAction] {
        [.write(command(
            payload: BluetoothCurrentTimeProtocol.payload(for: date),
            target: timeSynchronizationTarget
        ))]
    }

    private func consumeHistory(_ payload: Data, receivedAt: Date) -> [ScaleProtocolAction] {
        do {
            guard var session = historySession,
                  let event = try session.consume(payload, now: receivedAt) else { return [] }
            historySession = session
            switch event {
            case .readyToTransfer(let announced):
                return [
                    .reportHistoryProgress(received: 0, announced: announced),
                    .write(command(payload: XiaomiScaleHistoryProtocol.startTransfer))
                ]
            case .progress(let received, let announced):
                return [.reportHistoryProgress(received: received, announced: announced)]
            case .completed(let measurements):
                historySession = nil
                didStartHistoryRequest = false
                return [
                    .cancelTimer(id: TimerID.historyTimeout),
                    .write(command(payload: XiaomiScaleHistoryProtocol.stop)),
                    .completeHistory(measurements)
                ]
            }
        } catch {
            return failHistory(.invalidPayload)
        }
    }

    private var historyTarget: CommunicationGATTTarget {
        .init(
            serviceUUID: Self.serviceUUID,
            characteristicUUID: Self.historyCharacteristicUUID
        )
    }

    private func command(
        payload: Data,
        target: CommunicationGATTTarget? = nil
    ) -> CommunicationCommand {
        CommunicationCommand(
            target: target ?? historyTarget,
            payloadHexTemplate: payload.map { String(format: "%02X", $0) }.joined(),
            writeMode: .automatic
        )
    }

    private func failHistory(_ failure: ScaleProtocolHistoryFailure) -> [ScaleProtocolAction] {
        historySession = nil
        pendingHistoryCursor = nil
        didStartHistoryRequest = false
        return [
            .cancelTimer(id: TimerID.historyTimeout),
            .failHistory(failure)
        ]
    }

    private func reset() {
        historySession = nil
        pendingHistoryCursor = nil
        didStartHistoryRequest = false
    }
}
