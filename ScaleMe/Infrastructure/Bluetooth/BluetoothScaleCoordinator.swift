import CoreBluetooth
import Foundation

@MainActor
final class BluetoothScaleCoordinator: NSObject, ObservableObject {
    private enum ScanPurpose { case idle, adding, measuring, configuring(UUID) }
    private enum HistoryRequestOrigin: Equatable { case manual, automatic }
    private enum SettingsOperation {
        case unit(CommunicationWeightUnit)
        case currentTime
    }
    private enum DiagnosticPayloadKind {
        case xiaomiAdvertisement
        case standardWeight
        case standardBodyComposition
        case wolaiAFU
        case senssunIF2121
    }
    @Published private(set) var state: BluetoothScaleState = .idle
    @Published private(set) var devices: [DiscoveredScale] = []
    @Published private(set) var latestMeasurement: BodyMeasurement?
    @Published private(set) var liveWeightKG: Double?
    @Published private(set) var settingsState: ScaleDeviceSettingsState = .idle
    @Published private(set) var settingsSnapshot = ScaleDeviceSettingsSnapshot()
    @Published private(set) var settingsOperationMessage: String?
    @Published private(set) var settingsOperationSucceeded = false
    @Published private(set) var historyState: ScaleHistoryState = .unavailable
    @Published private(set) var automaticallyRetrievedHistory: AutomaticallyRetrievedHistory?
    @Published private var diagnosticLog = DeviceDiagnosticLog()

    var isDeviceDiagnosticCaptureEnabled: Bool { diagnosticLog.isCapturing }
    var deviceDiagnosticEvents: [DeviceDiagnosticEvent] { diagnosticLog.events }

    var currentScaleName: String? { activeScaleName }

    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    private var pendingBodyComposition: BodyMeasurement?
    private var measurementSession = MeasurementSession()
    private var connectionTimeoutTask: Task<Void, Never>?
    private var settingsReadbackTask: Task<Void, Never>?
    private var isWaitingForNextLoad = false
    private var minimumWeightAfterCompletionKG: Double?
    private var scanPurpose: ScanPurpose = .adding
    private var pairedScales = PairedScaleRegistry()
    private let protocolRegistry = ScaleProtocolRegistry.builtIn
    private var activeProtocolSession: (any ScaleConnectedProtocolSession)?
    private var activeProtocolSessionDeviceID: UUID?
    private var protocolTimerTasks: [String: Task<Void, Never>] = [:]
    private var measurementScaleID: UUID?
    private var activeScaleID: UUID?
    private var activeScaleName: String?
    private var settingsScaleID: UUID?
    private var pendingSettingsReconnect: PairedScale?
    private var settingsCurrentTimeCharacteristic: CBCharacteristic?
    private var activeProtocolHistoryOrigin: HistoryRequestOrigin?
    private var declarativeHistorySession: DeclarativeHistoryOperationSession?
    private var activeHistoryOperation: CommunicationGATTOperation?
    private var activeHistorySessionToken: UInt16?
    private var activeHistoryCompletionResponse: Data?
    private var pendingHistorySubscriptions = Set<String>()
    private var settingsCharacteristicsByTarget: [String: CBCharacteristic] = [:]
    private var historyTimeoutTask: Task<Void, Never>?
    private var pendingAutomaticHistoryImportID: UUID?
    private var pendingSettingsServiceIDs: Set<ObjectIdentifier> = []
    private var pendingSettingsOperation: SettingsOperation?
    private var pendingProtocolSettingsTarget: CommunicationGATTTarget?
    private var scanRequested = false
    private var discoverySequence = 0
    private var huaweiHagridDeviceIDs = Set<UUID>()
    private var didSendHuaweiHagridProbe = false
    private var didReceiveHuaweiHagridChallenge = false
    private var didSendHuaweiHagridRealtimeProbe = false
    private var lastHuaweiHagridMeasurementStatus: HuaweiHagridProtocol.MeasurementStatus?
    private var huaweiHagridNotificationAccumulators: [String: HuaweiHagridProtocol.NotificationAccumulator] = [:]
    private var settingsHuaweiAuthenticationCharacteristic: CBCharacteristic?
    private var settingsHuaweiRealtimeCharacteristic: CBCharacteristic?
    private var measurementProfile: UserProfile?

    private static let weightService = CBUUID(string: "181D")
    private static let bodyService = CBUUID(string: "181B")
    private static let weightMeasurement = CBUUID(string: "2A9D")
    private static let bodyMeasurement = CBUUID(string: "2A9C")
    private static let wolaiService = CBUUID(string: WolaiAFUScaleAdapter.serviceUUID)
    private static let wolaiMeasurement = CBUUID(string: WolaiAFUScaleAdapter.measurementCharacteristicUUID)
    private static let serialNumber = CBUUID(string: "2A25")
    private static let hardwareRevision = CBUUID(string: "2A27")
    private static let softwareRevision = CBUUID(string: "2A28")
    private static let currentTime = CBUUID(string: "2A2B")
    private static let xiaomiConfigurationService = CBUUID(
        string: XiaomiScaleConfigurationProtocol.configurationServiceUUID
    )
    private static let xiaomiConfiguration = CBUUID(
        string: XiaomiScaleConfigurationProtocol.configurationCharacteristicUUID
    )

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        scanPurpose = .adding
        discoverySequence = 0
        beginScanning(clearDevices: true)
    }

    func startMeasurementMonitoring(
        scales: [PairedScale],
        selectedScaleID: UUID,
        profile: UserProfile? = nil
    ) {
        pairedScales.updateScales(scales)
        measurementScaleID = pairedScales.contains(selectedScaleID) ? selectedScaleID : nil
        scanPurpose = .measuring
        liveWeightKG = nil
        latestMeasurement = nil
        pendingBodyComposition = nil
        measurementSession.reset()
        isWaitingForNextLoad = false
        minimumWeightAfterCompletionKG = nil
        resetActiveProtocolSession()
        measurementProfile = profile
        if let connected, !isMonitoredScale(connected.identifier) {
            connectionTimeoutTask?.cancel()
            central.cancelPeripheralConnection(connected)
            self.connected = nil
            activeScaleID = nil
            activeScaleName = nil
        }
        guard measurementScaleID != nil else {
            scanPurpose = .idle
            scanRequested = false
            central.stopScan()
            state = .idle
            return
        }
        if let connected, isMonitoredScale(connected.identifier) {
            _ = startConnectedProtocolSessionIfAvailable(on: connected)
        }
        beginScanning(clearDevices: false)
        connectKnownScale(from: scales)
    }

    func updatePairedScales(
        _ scales: [PairedScale],
        communicationRules: [CommunicationRule] = CommunicationRuleCatalog.builtIn
    ) {
        pairedScales.updateScales(scales)
        pairedScales.updateRules(communicationRules)
        if let activeScaleID, let scale = scales.first(where: { $0.id == activeScaleID }) {
            activeScaleName = scale.name
        }
        if let connected, settingsScaleID == nil, case .measuring = scanPurpose {
            resetActiveProtocolSession()
            _ = startConnectedProtocolSessionIfAvailable(on: connected)
        }
    }

    private func selectedRule(for deviceID: UUID) -> CommunicationRule? {
        pairedScales.selectedRule(for: deviceID)
    }

    private func effectiveRule(for deviceID: UUID) -> CommunicationRule? {
        pairedScales.effectiveRule(for: deviceID)
    }

    private func selectedProtocolID(for deviceID: UUID) -> String? {
        effectiveRule(for: deviceID)?.id
    }

    private func connectedProtocolSession(for deviceID: UUID) -> (any ScaleConnectedProtocolSession)? {
        guard let protocolID = selectedProtocolID(for: deviceID) else { return nil }
        if let activeProtocolSession,
           activeProtocolSessionDeviceID == deviceID,
           activeProtocolSession.descriptor.id == protocolID {
            return activeProtocolSession
        }
        guard let session = protocolRegistry.makeConnectedSession(protocolID: protocolID) else {
            return nil
        }
        resetActiveProtocolSession()
        activeProtocolSession = session
        activeProtocolSessionDeviceID = deviceID
        return session
    }

    private func historyOperation(for deviceID: UUID) -> CommunicationGATTOperation? {
        effectiveRule(for: deviceID)?.operations?.historyRead
    }

    private func refreshHistoryAvailability(for deviceID: UUID) {
        guard let operation = historyOperation(for: deviceID) else { return }
        let canSubscribe = operation.subscriptions.allSatisfy { target in
            guard let characteristic = settingsCharacteristicsByTarget[targetKey(target)] else { return false }
            return characteristic.properties.contains(.notify)
                || characteristic.properties.contains(.indicate)
        }
        let canWrite = operation.commands.allSatisfy { command in
            guard let characteristic = settingsCharacteristicsByTarget[targetKey(command.target)] else { return false }
            switch command.writeMode {
            case .withResponse:
                return characteristic.properties.contains(.write)
            case .withoutResponse:
                return characteristic.properties.contains(.writeWithoutResponse)
            case .automatic:
                return characteristic.properties.contains(.write)
                    || characteristic.properties.contains(.writeWithoutResponse)
            }
        }
        guard canSubscribe, canWrite else { return }
        settingsSnapshot.hasHistoryChannel = true
        if case .unavailable = historyState {
            historyState = .ready
        }
    }

    private func refreshProtocolConfigurationAvailability(for deviceID: UUID) {
        guard let protocolID = selectedProtocolID(for: deviceID),
              let session = protocolRegistry.makeConnectedSession(protocolID: protocolID) else {
            return
        }
        if let capability = session as? any ScaleUnitConfigurationCapability,
           let characteristic = settingsCharacteristicsByTarget[
            targetKey(capability.hardwareUnitConfigurationTarget)
           ], characteristic.properties.contains(.write)
                || characteristic.properties.contains(.writeWithoutResponse) {
            settingsSnapshot.canConfigureHardwareUnit = true
        }
        if let capability = session as? any ScaleTimeSynchronizationCapability,
           let characteristic = settingsCharacteristicsByTarget[
            targetKey(capability.timeSynchronizationTarget)
           ], characteristic.properties.contains(.write)
                || characteristic.properties.contains(.writeWithoutResponse) {
            settingsSnapshot.canSynchronizeTime = true
        }
    }

    private func isHuaweiHagridSelected(for deviceID: UUID) -> Bool {
        selectedProtocolID(for: deviceID) == HuaweiHagridProtocolSession.communicationRule.id
    }

    private func isSenssunIF2121Selected(for deviceID: UUID) -> Bool {
        selectedProtocolID(for: deviceID) == SenssunIF2121ProtocolSession.communicationRule.id
    }

    private func isWolaiAFUSelected(for deviceID: UUID) -> Bool {
        effectiveRule(for: deviceID)?.builtInParser == "wolaiAFU"
    }

    private func isMonitoredScale(_ deviceID: UUID) -> Bool {
        pairedScales.contains(deviceID) && measurementScaleID == deviceID
    }

    private func allowsBuiltInParser(_ parser: String, for deviceID: UUID) -> Bool {
        // Automatically resolved connected sessions own their measurement input,
        // just like an explicit choice. Keep SIG's automatic weight/body pairing.
        let connectedRule = effectiveRule(for: deviceID).flatMap { rule in
            protocolRegistry.descriptor(protocolID: rule.id)?.transport == .characteristicNotification
                ? rule : nil
        }
        guard let selected = selectedRule(for: deviceID) ?? connectedRule else { return true }
        return selected.builtInParser == parser
    }

    private func customRule(
        for deviceID: UUID,
        transport: CommunicationTransport,
        serviceUUID: String,
        characteristicUUID: String? = nil
    ) -> CommunicationRule? {
        guard let selected = selectedRule(for: deviceID), selected.isDeclarative,
              selected.match.transport == transport,
              selected.match.serviceUUID == CommunicationRuleCodec.normalizeUUID(serviceUUID) else { return nil }
        if transport == .characteristicNotification {
            guard selected.match.characteristicUUID == characteristicUUID.map(CommunicationRuleCodec.normalizeUUID) else { return nil }
        }
        return selected
    }

    private func consumeCustomPacket(_ data: Data, rule: CommunicationRule, deviceID: UUID) {
        guard let packet = try? DeclarativeCommunicationRuleParser.parse(data, rule: rule) else { return }
        switch packet {
        case .measurement(let measurement):
            consume(
                measurement,
                reliability: measurement.isStable ? .protocolStable : .requiresStability,
                deviceID: deviceID,
                deviceName: pairedScales.names[deviceID]
            )
        case .weightRemoved:
            weightWasRemoved()
        }
    }

    private func beginScanning(clearDevices: Bool) {
        scanRequested = true
        guard central.state == .poweredOn else {
            state = .unavailable(bluetoothStateText(central.state)); return
        }
        if clearDevices { devices.removeAll() }
        state = .scanning
        // Xiaomi broadcasts BCS-shaped service data without requiring a connection.
        // nil also discovers proprietary devices so adapters can be added incrementally.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func stopScanning() {
        scanRequested = false
        central.stopScan()
        if case .scanning = state { state = .idle }
    }

    func stopMeasurementMonitoring() {
        guard case .measuring = scanPurpose else { return }
        scanPurpose = .idle
        scanRequested = false
        central.stopScan()
        disconnect()
        measurementScaleID = nil
    }

    func inspectSettings(for scale: PairedScale) {
        pendingSettingsReconnect = nil
        if let connected, connected.identifier == scale.id {
            resetSettingsInspection(for: scale)
            settingsState = .discovering
            armSettingsTimeout(for: scale.id)
            connected.discoverServices(nil)
            return
        }
        disconnectSettingsPeripheral()
        resetSettingsInspection(for: scale)

        guard central.state == .poweredOn else {
            settingsState = .failed(bluetoothStateText(central.state))
            return
        }
        armSettingsTimeout(for: scale.id)
        if let peripheral = central.retrievePeripherals(withIdentifiers: [scale.id]).first {
            connectForSettings(peripheral, name: scale.name)
        } else {
            beginScanning(clearDevices: false)
            settingsState = .locating
        }
    }

    func reconnectSettings(for scale: PairedScale) {
        pendingSettingsReconnect = nil
        connectionTimeoutTask?.cancel()

        guard central.state == .poweredOn else {
            resetSettingsInspection(for: scale)
            settingsState = .failed(bluetoothStateText(central.state))
            return
        }

        guard let connected, connected.identifier == scale.id else {
            inspectSettings(for: scale)
            return
        }

        resetSettingsInspection(for: scale)
        pendingSettingsReconnect = scale
        settingsState = .connecting
        armSettingsTimeout(for: scale.id)
        central.cancelPeripheralConnection(connected)
    }

    private func resetSettingsInspection(for scale: PairedScale) {
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        settingsScaleID = scale.id
        settingsSnapshot = ScaleDeviceSettingsSnapshot()
        historyState = .unavailable
        activeProtocolHistoryOrigin = nil
        declarativeHistorySession = nil
        activeHistoryOperation = nil
        activeHistorySessionToken = nil
        activeHistoryCompletionResponse = nil
        pendingHistorySubscriptions.removeAll()
        settingsCharacteristicsByTarget.removeAll()
        historyTimeoutTask?.cancel()
        settingsOperationMessage = nil
        settingsOperationSucceeded = false
        pendingSettingsOperation = nil
        pendingProtocolSettingsTarget = nil
        didSendHuaweiHagridProbe = false
        didReceiveHuaweiHagridChallenge = false
        didSendHuaweiHagridRealtimeProbe = false
        lastHuaweiHagridMeasurementStatus = nil
        huaweiHagridNotificationAccumulators.removeAll()
        settingsHuaweiAuthenticationCharacteristic = nil
        settingsHuaweiRealtimeCharacteristic = nil
        diagnosticLog.resetIfInactive()
        settingsState = .locating
        scanPurpose = .configuring(scale.id)
    }

    func endSettingsInspection() {
        pendingSettingsReconnect = nil
        connectionTimeoutTask?.cancel()
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        pendingSettingsOperation = nil
        pendingProtocolSettingsTarget = nil
        settingsCurrentTimeCharacteristic = nil
        declarativeHistorySession = nil
        activeHistoryOperation = nil
        activeHistorySessionToken = nil
        activeHistoryCompletionResponse = nil
        pendingHistorySubscriptions.removeAll()
        settingsCharacteristicsByTarget.removeAll()
        historyTimeoutTask?.cancel()
        pendingSettingsServiceIDs.removeAll()
        stopScanning()
        disconnectSettingsPeripheral()
        settingsScaleID = nil
        diagnosticLog.end()
        settingsState = .idle
    }

    func makeDeviceDiagnosticReport() -> String {
        diagnosticLog.report(
            deviceID: settingsScaleID,
            serviceUUIDs: settingsSnapshot.discoveredServiceUUIDs
        )
    }

    func startDeviceDiagnosticCapture(for scale: PairedScale) {
        diagnosticLog.start()
        inspectSettings(for: scale)
        appendDiagnosticEvent(kind: .service, source: "SESSION", summary: "开始采集目标设备 \(scale.name)")
        beginScanning(clearDevices: false)
    }

    func stopDeviceDiagnosticCapture() {
        appendDiagnosticEvent(kind: .service, source: "SESSION", summary: "停止采集")
        diagnosticLog.stop()
        if connected?.identifier == settingsScaleID {
            scanRequested = false
            central.stopScan()
        }
    }

    func configureHardwareUnit(_ unit: CommunicationWeightUnit) {
        guard let connected,
              connected.identifier == settingsScaleID,
              let session = connectedProtocolSession(for: connected.identifier),
              let capability = session as? any ScaleUnitConfigurationCapability,
              capability.supportedHardwareUnits.contains(unit),
              let characteristic = protocolCharacteristic(
                capability.hardwareUnitConfigurationTarget,
                on: connected
              ),
              characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            settingsOperationSucceeded = false
            settingsOperationMessage = "当前协议没有可执行的设备单位设置能力"
            return
        }
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        pendingSettingsOperation = .unit(unit)
        pendingProtocolSettingsTarget = capability.hardwareUnitConfigurationTarget
        settingsOperationSucceeded = false
        settingsOperationMessage = "正在写入秤端单位"
        do {
            let actions = try capability.configureHardwareUnit(unit)
            try executeProtocolActions(actions, on: connected)
            if let mode = protocolWriteMode(
                in: actions,
                target: capability.hardwareUnitConfigurationTarget
            ), writeType(for: mode, characteristic: characteristic) == .withoutResponse {
                pendingProtocolSettingsTarget = nil
                verifySettingsWrite(on: connected, characteristic: characteristic, wasAcknowledged: false)
            }
        } catch {
            pendingProtocolSettingsTarget = nil
            pendingSettingsOperation = nil
            settingsOperationMessage = "设备单位设置命令生成失败"
        }
    }

    func synchronizeScaleTime() {
        guard let connected,
              connected.identifier == settingsScaleID else {
            settingsOperationSucceeded = false
            settingsOperationMessage = "当前设备未连接"
            return
        }
        if let session = connectedProtocolSession(for: connected.identifier),
           let capability = session as? any ScaleTimeSynchronizationCapability,
           let characteristic = protocolCharacteristic(capability.timeSynchronizationTarget, on: connected),
           characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
            performProtocolTimeSynchronization(
                capability,
                target: capability.timeSynchronizationTarget,
                characteristic: characteristic,
                on: connected
            )
            return
        }
        guard let characteristic = settingsCurrentTimeCharacteristic,
              characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            settingsOperationSucceeded = false
            settingsOperationMessage = "当前连接未发现可写的标准时间特征"
            return
        }
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        pendingSettingsOperation = .currentTime
        settingsOperationSucceeded = false
        settingsOperationMessage = "正在同步秤端时间"
        let command = BluetoothCurrentTimeProtocol.payload(for: .now)
        captureCharacteristicEvent(
            direction: .write,
            characteristic: characteristic,
            payload: command,
            summary: "同步当前时间；类型：\(writeType == .withResponse ? "有响应" : "无响应")"
        )
        connected.writeValue(command, for: characteristic, type: writeType)
        if writeType == .withoutResponse {
            verifySettingsWrite(on: connected, characteristic: characteristic, wasAcknowledged: false)
        }
    }

    private func performProtocolTimeSynchronization(
        _ capability: any ScaleTimeSynchronizationCapability,
        target: CommunicationGATTTarget,
        characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) {
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        pendingSettingsOperation = .currentTime
        pendingProtocolSettingsTarget = target
        settingsOperationSucceeded = false
        settingsOperationMessage = "正在同步秤端时间"
        do {
            let actions = try capability.synchronizeTime(.now)
            try executeProtocolActions(actions, on: peripheral)
            if let mode = protocolWriteMode(in: actions, target: target),
               writeType(for: mode, characteristic: characteristic) == .withoutResponse {
                pendingProtocolSettingsTarget = nil
                verifySettingsWrite(on: peripheral, characteristic: characteristic, wasAcknowledged: false)
            }
        } catch {
            pendingProtocolSettingsTarget = nil
            pendingSettingsOperation = nil
            settingsOperationMessage = "设备时间同步命令生成失败"
        }
    }

    func readDeviceHistory() {
        guard let scaleID = settingsScaleID,
              let operation = historyOperation(for: scaleID) else {
            historyState = .failed("当前协议没有声明可执行的历史读取操作")
            return
        }
        if operation.historyResponse?.builtInParser == nil {
            readDeclarativeHistory(operation)
        } else if operation.historyResponse?.builtInParser != nil {
            readConnectedProtocolHistory(operation)
        } else {
            historyState = .failed("当前协议的历史解析器尚未实现")
        }
    }

    private func readConnectedProtocolHistory(_ operation: CommunicationGATTOperation) {
        guard let connected,
              connected.identifier == settingsScaleID,
              let session = connectedProtocolSession(for: connected.identifier),
              let history = session as? any ScaleHistoryCapability else {
            historyState = .failed("当前协议没有实现历史读取能力")
            return
        }
        resetActiveProtocolSession()
        activeProtocolSession = session
        activeProtocolSessionDeviceID = connected.identifier
        activeProtocolHistoryOrigin = .manual
        historyState = .reading(received: 0, announced: nil)
        do {
            let configuration = historyConfiguration(for: operation)
            try executeProtocolActions(history.startHistoryRead(configuration: configuration), on: connected)
            if let target = operation.subscriptions.first,
               let measurement = protocolCharacteristic(target, on: connected),
               measurement.isNotifying {
                try executeProtocolActions(session.handle(.notificationStateChanged(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(target.serviceUUID),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(target.characteristicUUID),
                    isNotifying: true,
                    changedAt: .now
                )), on: connected)
            }
        } catch {
            activeProtocolHistoryOrigin = nil
            resetActiveProtocolSession()
            historyState = .failed("历史读取会话启动失败")
        }
    }

    private func startAutomaticConnectedProtocolHistoryIfNeeded(on peripheral: CBPeripheral) -> Bool {
        guard pairedScales.automaticHistoryIDs.contains(peripheral.identifier),
              activeProtocolHistoryOrigin == nil,
              activeProtocolSessionDeviceID == peripheral.identifier,
              let operation = historyOperation(for: peripheral.identifier),
              operation.historyResponse?.builtInParser != nil,
              let session = activeProtocolSession,
              let history = session as? any ScaleHistoryCapability else { return false }
        do {
            activeProtocolHistoryOrigin = .automatic
            try executeProtocolActions(
                history.startHistoryRead(configuration: historyConfiguration(for: operation)),
                on: peripheral
            )
            return true
        } catch {
            activeProtocolHistoryOrigin = nil
            return false
        }
    }

    private func historyConfiguration(
        for operation: CommunicationGATTOperation
    ) -> ScaleHistoryReadConfiguration {
        ScaleHistoryReadConfiguration(
            timeoutSeconds: operation.timeoutSeconds,
            maximumResponseBytes: operation.maximumResponseBytes,
            maximumRecords: operation.maximumRecords
        )
    }

    func importPendingHistory(into store: MeasurementStore) {
        guard case .awaitingImport(let measurements) = historyState,
              let connected else { return }
        let summary = store.importDeviceHistory(measurements)
        if summary.unmatchedCount == 0 {
            if activeProtocolSessionDeviceID == connected.identifier,
               let confirmation = activeProtocolSession as? any ScaleHistoryImportConfirmationCapability {
                try? executeProtocolActions(try confirmation.confirmHistoryImport(), on: connected)
            } else if let operation = activeHistoryOperation {
                write(operation.acknowledgementCommands, on: connected, response: activeHistoryCompletionResponse)
            }
        }
        historyState = .imported(summary)
    }

    func finishAutomaticHistoryImport(_ batchID: UUID, summary: DeviceHistoryImportSummary) {
        guard pendingAutomaticHistoryImportID == batchID else { return }
        pendingAutomaticHistoryImportID = nil
        if summary.unmatchedCount == 0,
           let connected,
           activeProtocolSessionDeviceID == connected.identifier,
           let confirmation = activeProtocolSession as? any ScaleHistoryImportConfirmationCapability {
            try? executeProtocolActions(try confirmation.confirmHistoryImport(), on: connected)
        }
    }

    func clearDeviceHistory() {
        guard let scaleID = settingsScaleID,
              let connected,
              let operation = selectedRule(for: scaleID)?.operations?.historyClear else {
            historyState = .failed("当前协议没有声明可执行的历史清除操作")
            return
        }
        do {
            try CommunicationOperationValidator.validate(.init(historyClear: operation))
            guard operation.commands.allSatisfy({ command in
                guard let characteristic = settingsCharacteristicsByTarget[targetKey(command.target)] else { return false }
                switch command.writeMode {
                case .withResponse: return characteristic.properties.contains(.write)
                case .withoutResponse: return characteristic.properties.contains(.writeWithoutResponse)
                case .automatic:
                    return characteristic.properties.contains(.write)
                        || characteristic.properties.contains(.writeWithoutResponse)
                }
            }) else {
                historyState = .failed("清除规则声明的服务或特征与当前设备不匹配")
                return
            }
            activeHistorySessionToken = UInt16.random(in: .min ... .max)
            write(operation.commands, on: connected)
            historyState = .clearCommandSent
        } catch {
            historyState = .failed(error.localizedDescription)
        }
    }

    private func readDeclarativeHistory(_ operation: CommunicationGATTOperation) {
        guard let connected else { return }
        do {
            try CommunicationOperationValidator.validate(.init(historyRead: operation))
            let commandTargets = operation.commands + operation.completionCommands + operation.acknowledgementCommands
            guard operation.subscriptions.allSatisfy({ target in
                guard let characteristic = settingsCharacteristicsByTarget[targetKey(target)] else { return false }
                return characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
            }), commandTargets.allSatisfy({ command in
                guard let characteristic = settingsCharacteristicsByTarget[targetKey(command.target)] else { return false }
                switch command.writeMode {
                case .withResponse: return characteristic.properties.contains(.write)
                case .withoutResponse: return characteristic.properties.contains(.writeWithoutResponse)
                case .automatic:
                    return characteristic.properties.contains(.write)
                        || characteristic.properties.contains(.writeWithoutResponse)
                }
            }) else {
                historyState = .failed("规则声明的服务或特征与当前设备不匹配")
                return
            }
            declarativeHistorySession = try DeclarativeHistoryOperationSession(operation: operation)
            activeHistoryOperation = operation
            activeHistorySessionToken = UInt16.random(in: .min ... .max)
            activeHistoryCompletionResponse = nil
            historyState = .reading(received: 0, announced: nil)
            pendingHistorySubscriptions = Set(operation.subscriptions.compactMap { target in
                guard let characteristic = settingsCharacteristicsByTarget[targetKey(target)], !characteristic.isNotifying else {
                    return nil
                }
                connected.setNotifyValue(true, for: characteristic)
                return targetKey(target)
            })
            armHistoryOperationTimeout(seconds: operation.timeoutSeconds)
            if pendingHistorySubscriptions.isEmpty { write(operation.commands, on: connected) }
        } catch {
            historyState = .failed(error.localizedDescription)
        }
    }

    private func armHistoryOperationTimeout(seconds: Double) {
        historyTimeoutTask?.cancel()
        historyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, case .reading = self.historyState else { return }
            self.declarativeHistorySession = nil
            self.activeHistoryOperation = nil
            self.activeHistorySessionToken = nil
            self.activeHistoryCompletionResponse = nil
            self.historyState = .failed("读取历史超时，请唤醒秤后重试")
        }
    }

    private func write(
        _ commands: [CommunicationCommand],
        on peripheral: CBPeripheral,
        response: Data? = nil
    ) {
        for command in commands {
            guard let characteristic = settingsCharacteristicsByTarget[targetKey(command.target)],
                  let payload = try? CommunicationPayloadTemplate.render(
                    command.payloadHexTemplate,
                    sessionToken: activeHistorySessionToken ?? 0,
                    response: response
                  ) else { continue }
            let type = writeType(for: command.writeMode, characteristic: characteristic)
            captureCharacteristicEvent(direction: .write, characteristic: characteristic, payload: payload, summary: "外部协议历史命令")
            peripheral.writeValue(payload, for: characteristic, type: type)
        }
    }

    private func targetKey(_ target: CommunicationGATTTarget) -> String {
        "\(CommunicationRuleCodec.normalizeUUID(target.serviceUUID))|\(CommunicationRuleCodec.normalizeUUID(target.characteristicUUID))"
    }

    private func consumeDeclarativeHistory(
        _ data: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) -> Bool {
        guard var session = declarativeHistorySession,
              let operation = activeHistoryOperation,
              let response = operation.historyResponse,
              let serviceUUID = characteristic.service?.uuid.uuidString else { return false }
        let target = CommunicationGATTTarget(
            serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
            characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString)
        )
        guard target == response.recordMatcher.target
            || response.completionMatcher.map({ target == $0.target }) == true else { return false }
        do {
            let event = try session.consume(
                data,
                serviceUUID: serviceUUID,
                characteristicUUID: characteristic.uuid.uuidString
            )
            declarativeHistorySession = session
            switch event {
            case .progress(let received):
                historyState = .reading(received: received, announced: nil)
            case .completed(let measurements, let response):
                historyTimeoutTask?.cancel()
                declarativeHistorySession = nil
                activeHistoryCompletionResponse = response
                write(operation.completionCommands, on: peripheral, response: response)
                let attributed = measurements.map { value -> BodyMeasurement in
                    var result = value
                    result.deviceID = peripheral.identifier
                    result.deviceName = pairedScales.names[peripheral.identifier] ?? peripheral.name
                    return result
                }
                historyState = .awaitingImport(attributed)
            case nil:
                break
            }
        } catch {
            historyTimeoutTask?.cancel()
            declarativeHistorySession = nil
            activeHistoryOperation = nil
            activeHistorySessionToken = nil
            activeHistoryCompletionResponse = nil
            historyState = .failed("外部协议返回的数据无效或超过安全上限")
        }
        return true
    }

    private func connectForSettings(_ peripheral: CBPeripheral, name: String) {
        if !isDeviceDiagnosticCaptureEnabled {
            scanRequested = false
            central.stopScan()
        }
        connected = peripheral
        activeScaleID = peripheral.identifier
        activeScaleName = name
        peripheral.delegate = self
        settingsState = .connecting
        state = .connecting(name)
        central.connect(peripheral)
    }

    private func armSettingsTimeout(for scaleID: UUID) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled, let self,
                  self.settingsScaleID == scaleID,
                  self.settingsState.isBusy else { return }
            self.central.stopScan()
            self.settingsState = .failed("未能读取设备能力，请唤醒秤后重试")
        }
    }

    private func disconnectSettingsPeripheral() {
        guard let connected, connected.identifier == settingsScaleID else { return }
        central.cancelPeripheralConnection(connected)
        self.connected = nil
        activeScaleID = nil
        activeScaleName = nil
    }

    private func verifySettingsWrite(
        on peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        wasAcknowledged: Bool = true
    ) {
        if characteristic.properties.contains(.read) {
            settingsOperationSucceeded = true
            if characteristic.uuid == Self.xiaomiConfiguration,
               case .unit(let expected) = pendingSettingsOperation {
                settingsOperationMessage = wasAcknowledged ? "写入回执成功，正在等待秤端响应" : "命令已发送，正在等待秤端响应"
                settingsReadbackTask?.cancel()
                settingsReadbackTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(1_250))
                    guard !Task.isCancelled, let self,
                          case .unit(let pendingUnit) = self.pendingSettingsOperation,
                          pendingUnit == expected,
                          self.connected === peripheral else { return }
                    self.captureCharacteristicEvent(
                        direction: .read,
                        characteristic: characteristic,
                        summary: "等待秤端处理后读取单位配置"
                    )
                    peripheral.readValue(for: characteristic)
                    self.settingsReadbackTask = nil
                }
            } else {
                settingsOperationMessage = wasAcknowledged ? "写入回执成功，正在读回分析" : "命令已发送，正在读回分析"
                captureCharacteristicEvent(
                    direction: .read,
                    characteristic: characteristic,
                    summary: "请求读取特征值以辅助分析"
                )
                peripheral.readValue(for: characteristic)
            }
        } else {
            settingsOperationSucceeded = true
            settingsOperationMessage = "命令已发送；该特征不可读，请核对秤面显示"
            pendingSettingsOperation = nil
        }
    }

    private func captureCharacteristicEvent(
        direction: DeviceDiagnosticEvent.Kind,
        characteristic: CBCharacteristic,
        payload: Data? = nil,
        summary: String
    ) {
        appendDiagnosticEvent(
            kind: direction,
            source: characteristic.uuid.uuidString.uppercased(),
            payload: payload,
            summary: summary
        )
    }

    private func appendDiagnosticEvent(
        kind: DeviceDiagnosticEvent.Kind,
        source: String,
        payload: Data? = nil,
        summary: String,
        receivedAt: Date = .now
    ) {
        diagnosticLog.append(
            kind: kind,
            source: source,
            payloadHex: payload.map(Self.hexString),
            summary: summary,
            receivedAt: receivedAt
        )
    }

    func connect(_ device: DiscoveredScale) {
        if case .measuring = scanPurpose {
            guard isMonitoredScale(device.id),
                  connected == nil || connected?.identifier == device.id else { return }
        }
        connectionTimeoutTask?.cancel()
        central.stopScan()
        connected = device.peripheral
        activeScaleID = device.id
        activeScaleName = pairedScales.names[device.id] ?? device.name
        device.peripheral.delegate = self
        state = .connecting(device.name)
        central.connect(device.peripheral)
        if case .measuring = scanPurpose {
            let peripheralID = device.id
            connectionTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled, let self,
                      self.connected?.identifier == peripheralID,
                      case .connecting = self.state else { return }
                self.central.cancelPeripheralConnection(device.peripheral)
                self.connected = nil
                self.beginScanning(clearDevices: false)
            }
        }
    }

    func disconnect() {
        connectionTimeoutTask?.cancel()
        if let connected { central.cancelPeripheralConnection(connected) }
        resetActiveProtocolSession()
        connected = nil
        activeScaleID = nil
        activeScaleName = nil
        state = .idle
    }

    private func consume(
        _ measurement: BodyMeasurement,
        reliability: MeasurementSampleReliability,
        deviceID: UUID? = nil,
        deviceName: String? = nil
    ) {
        var attributed = measurement
        attributed.deviceID = deviceID ?? activeScaleID
        attributed.deviceName = deviceName ?? activeScaleName

        if reliability == .protocolStable, let completed = latestMeasurement {
            if isWaitingForNextLoad {
                let minimum = min(minimumWeightAfterCompletionKG ?? attributed.weightKG, attributed.weightKG)
                minimumWeightAfterCompletionKG = minimum
                guard attributed.weightKG >= minimum + 2 else { return }
                isWaitingForNextLoad = false
                minimumWeightAfterCompletionKG = nil
                measurementSession.reset()
            } else if case .completed = state,
                      !attributed.isStable || attributed.weightKG <= completed.weightKG - 2 {
                isWaitingForNextLoad = true
                minimumWeightAfterCompletionKG = attributed.weightKG
                measurementSession.reset()
                return
            }
        }

        let update = measurementSession.ingest(attributed, reliability: reliability)
        if let liveMeasurement = update.liveMeasurement {
            liveWeightKG = liveMeasurement.weightKG
        }
        switch update.phase {
        case .measuring:
            state = .measuringWeight
        case .stabilizing:
            state = .confirmingMeasurement
        case .completed:
            guard let completed = update.completedMeasurement else { return }
            latestMeasurement = completed
            liveWeightKG = completed.weightKG
            isWaitingForNextLoad = false
            minimumWeightAfterCompletionKG = nil
            state = .completed
        case .ignored:
            break
        }
    }

    private func weightWasRemoved() {
        measurementSession.reset()
        pendingBodyComposition = nil
        isWaitingForNextLoad = true
        minimumWeightAfterCompletionKG = 0
        if latestMeasurement == nil {
            liveWeightKG = nil
            state = connected.map { .connected($0.name ?? "体重秤") } ?? .scanning
        }
    }

    private func resetActiveProtocolSession() {
        if let activeProtocolSession {
            _ = try? activeProtocolSession.handle(.disconnected)
        }
        activeProtocolSession = nil
        activeProtocolSessionDeviceID = nil
        activeProtocolHistoryOrigin = nil
        protocolTimerTasks.values.forEach { $0.cancel() }
        protocolTimerTasks.removeAll()
    }

    @discardableResult
    private func startConnectedProtocolSessionIfAvailable(on peripheral: CBPeripheral) -> Bool {
        guard settingsScaleID == nil,
              let ruleID = selectedProtocolID(for: peripheral.identifier) else {
            return false
        }
        let session: any ScaleConnectedProtocolSession
        if let registered = protocolRegistry.makeConnectedSession(protocolID: ruleID) {
            session = registered
        } else if ruleID == HuaweiHagridProtocolSession.communicationRule.id {
            guard let credentials = try? HuaweiHagridCredentialStore().load(for: peripheral.identifier) else {
                resetActiveProtocolSession()
                state = .unavailable("华为 Hagrid 认证待配置")
                return true
            }
            guard let profile = measurementProfile else {
                resetActiveProtocolSession()
                state = .unavailable("需要成员资料")
                return true
            }
            let modelName = pairedScales.modelNames[peripheral.identifier] ?? peripheral.name ?? ""
            session = HuaweiHagridProtocolSession(
                credentials: credentials,
                profile: profile,
                usesScale3GenderEncoding: modelName.localizedCaseInsensitiveContains("Scale 3")
            )
        } else {
            return false
        }
        resetActiveProtocolSession()
        activeProtocolSession = session
        activeProtocolSessionDeviceID = peripheral.identifier
        do {
            try executeProtocolActions(session.handle(.connected), on: peripheral)
            return true
        } catch {
            resetActiveProtocolSession()
            state = .unavailable("协议会话启动失败")
            return false
        }
    }

    private func executeProtocolActions(
        _ actions: [ScaleProtocolAction],
        on peripheral: CBPeripheral
    ) throws {
        for action in actions {
            switch action {
            case .discoverServices(let serviceUUIDs):
                peripheral.discoverServices(serviceUUIDs.map(CBUUID.init(string:)))
            case .discoverCharacteristics(let serviceUUID, let characteristicUUIDs):
                guard let service = peripheral.services?.first(where: {
                    CommunicationRuleCodec.normalizeUUID($0.uuid.uuidString) == serviceUUID
                }) else { continue }
                peripheral.discoverCharacteristics(
                    characteristicUUIDs.map(CBUUID.init(string:)),
                    for: service
                )
            case .subscribe(let target):
                guard let characteristic = protocolCharacteristic(target, on: peripheral),
                      characteristic.properties.contains(.notify)
                        || characteristic.properties.contains(.indicate) else { continue }
                peripheral.setNotifyValue(true, for: characteristic)
            case .write(let command):
                guard let characteristic = protocolCharacteristic(command.target, on: peripheral) else { continue }
                let payload = try CommunicationPayloadTemplate.render(
                    command.payloadHexTemplate,
                    sessionToken: 0
                )
                let writeType = writeType(for: command.writeMode, characteristic: characteristic)
                guard writeType == .withResponse
                    ? characteristic.properties.contains(.write)
                    : characteristic.properties.contains(.writeWithoutResponse) else { continue }
                if settingsScaleID == peripheral.identifier {
                    captureCharacteristicEvent(
                        direction: .write,
                        characteristic: characteristic,
                        payload: payload,
                        summary: "协议会话命令"
                    )
                }
                peripheral.writeValue(payload, for: characteristic, type: writeType)
                if writeType == .withoutResponse,
                   activeProtocolSessionDeviceID == peripheral.identifier,
                   let session = activeProtocolSession {
                    try executeProtocolActions(session.handle(.writeCompleted(
                        serviceUUID: CommunicationRuleCodec.normalizeUUID(command.target.serviceUUID),
                        characteristicUUID: CommunicationRuleCodec.normalizeUUID(command.target.characteristicUUID),
                        succeeded: true
                    )), on: peripheral)
                }
            case .reportLiveMeasurement(let measurement, let phase, let loadCycle):
                if loadCycle == .coordinatorManaged,
                   !prepareForConnectedProtocolLiveWeight(measurement.weightKG) { continue }
                liveWeightKG = measurement.weightKG
                state = phase == .measuringWeight ? .measuringWeight : .measuringBodyComposition
            case .reportLivePhase(let phase):
                state = phase == .measuringWeight ? .measuringWeight : .measuringBodyComposition
            case .resetMeasurement:
                measurementSession.reset()
            case .emit(let packet, let reliability):
                switch packet {
                case .measurement(let measurement):
                    let sessionReliability: MeasurementSampleReliability
                    switch reliability {
                    case .requiresStability: sessionReliability = .requiresStability
                    case .protocolStable: sessionReliability = .protocolStable
                    case .protocolFinal: sessionReliability = .protocolFinal
                    }
                    consume(
                        measurement,
                        reliability: sessionReliability,
                        deviceID: peripheral.identifier,
                        deviceName: pairedScales.names[peripheral.identifier] ?? peripheral.name
                    )
                case .weightRemoved:
                    weightWasRemoved()
                }
            case .reportHistoryProgress(let received, let announced):
                if activeProtocolHistoryOrigin == .manual {
                    historyState = .reading(received: received, announced: announced)
                }
            case .completeHistory(let measurements):
                let origin = activeProtocolHistoryOrigin
                activeProtocolHistoryOrigin = nil
                let attributed = measurements.map { value -> BodyMeasurement in
                    var result = value
                    result.deviceID = peripheral.identifier
                    result.deviceName = pairedScales.names[peripheral.identifier] ?? peripheral.name
                    return result
                }
                if origin == .automatic {
                    if attributed.isEmpty {
                        if let confirmation = activeProtocolSession
                            as? any ScaleHistoryImportConfirmationCapability {
                            try executeProtocolActions(
                                try confirmation.confirmHistoryImport(),
                                on: peripheral
                            )
                        }
                    } else {
                        let batch = AutomaticallyRetrievedHistory(measurements: attributed)
                        pendingAutomaticHistoryImportID = batch.id
                        automaticallyRetrievedHistory = batch
                    }
                } else if origin == .manual {
                    historyState = attributed.isEmpty ? .empty : .awaitingImport(attributed)
                }
            case .failHistory(let failure):
                let origin = activeProtocolHistoryOrigin
                activeProtocolHistoryOrigin = nil
                if origin == .manual {
                    switch failure {
                    case .timeout:
                        historyState = .failed("读取历史超时，请唤醒秤后重试")
                    case .invalidPayload:
                        historyState = .failed("历史数据格式无效或超过安全上限")
                    case .writeFailed:
                        historyState = .failed("历史读取命令写入失败")
                    }
                }
            case .failSession(let failure):
                protocolTimerTasks.values.forEach { $0.cancel() }
                protocolTimerTasks.removeAll()
                switch failure {
                case .invalidResponse:
                    state = .unavailable("协议响应无效")
                case .writeFailed:
                    state = .unavailable("写入失败")
                }
            case .scheduleTimer(let id, let seconds):
                protocolTimerTasks[id]?.cancel()
                protocolTimerTasks[id] = Task { [weak self, weak peripheral] in
                    try? await Task.sleep(for: .seconds(seconds))
                    guard !Task.isCancelled, let self, let peripheral,
                          self.activeProtocolSessionDeviceID == peripheral.identifier,
                          self.connected === peripheral,
                          let session = self.activeProtocolSession else { return }
                    if let actions = try? session.handle(.timer(id)) {
                        try? self.executeProtocolActions(actions, on: peripheral)
                    }
                }
            case .cancelTimer(let id):
                protocolTimerTasks[id]?.cancel()
                protocolTimerTasks[id] = nil
            }
        }
    }

    private func protocolCharacteristic(
        _ target: CommunicationGATTTarget,
        on peripheral: CBPeripheral
    ) -> CBCharacteristic? {
        peripheral.services?.first(where: {
            CommunicationRuleCodec.normalizeUUID($0.uuid.uuidString)
                == CommunicationRuleCodec.normalizeUUID(target.serviceUUID)
        })?.characteristics?.first(where: {
            CommunicationRuleCodec.normalizeUUID($0.uuid.uuidString)
                == CommunicationRuleCodec.normalizeUUID(target.characteristicUUID)
        })
    }

    private func writeType(
        for mode: CommunicationWriteMode,
        characteristic: CBCharacteristic
    ) -> CBCharacteristicWriteType {
        switch mode {
        case .withResponse: .withResponse
        case .withoutResponse: .withoutResponse
        case .automatic:
            characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        }
    }

    private func protocolWriteMode(
        in actions: [ScaleProtocolAction],
        target: CommunicationGATTTarget
    ) -> CommunicationWriteMode? {
        actions.lazy.compactMap { action in
            guard case .write(let command) = action,
                  self.targetKey(command.target) == self.targetKey(target) else { return nil }
            return command.writeMode
        }.first
    }

    private func isWolaiMeasurement(_ characteristic: CBCharacteristic) -> Bool {
        characteristic.uuid == Self.wolaiMeasurement
            && characteristic.service?.uuid == Self.wolaiService
    }

    private func prepareForConnectedProtocolLiveWeight(_ weightKG: Double) -> Bool {
        if let completed = latestMeasurement, case .completed = state {
            if isWaitingForNextLoad {
                let minimum = min(minimumWeightAfterCompletionKG ?? weightKG, weightKG)
                minimumWeightAfterCompletionKG = minimum
                guard weightKG >= minimum + 2 else { return false }
                isWaitingForNextLoad = false
                minimumWeightAfterCompletionKG = nil
                measurementSession.reset()
            } else if weightKG <= completed.weightKG - 2 {
                weightWasRemoved()
                return false
            } else {
                // Ignore the final weight replay observed while the user steps
                // off; the following sub-2 kg frame opens the next session.
                return false
            }
        } else if isWaitingForNextLoad {
            let minimum = min(minimumWeightAfterCompletionKG ?? weightKG, weightKG)
            minimumWeightAfterCompletionKG = minimum
            guard weightKG >= minimum + 2 else { return false }
            isWaitingForNextLoad = false
            minimumWeightAfterCompletionKG = nil
            measurementSession.reset()
        }
        return true
    }

    private func diagnosticSummary(
        _ payload: Data,
        kind: DiagnosticPayloadKind,
        receivedAt: Date
    ) -> String {
        let summary: String
        do {
            switch kind {
            case .xiaomiAdvertisement:
                switch try XiaomiScaleParser.parsePacket(payload, now: receivedAt) {
                case .measurement(let measurement):
                    summary = String(
                        format: "weight=%.3fkg stable=%@ impedance=%@",
                        measurement.weightKG,
                        measurement.isStable ? "1" : "0",
                        measurement.impedanceOhm.map { String(format: "%.0f", $0) } ?? "-"
                    )
                case .weightRemoved:
                    summary = "weightRemoved=1"
                }
            case .standardWeight:
                if XiaomiGATTWeightParser.matches(payload) {
                    switch try XiaomiGATTWeightParser.parsePacket(payload, now: receivedAt) {
                    case .measurement(let measurement):
                        summary = String(
                            format: "weight=%.3fkg xiaomiStable=%@",
                            measurement.weightKG,
                            measurement.isStable ? "1" : "0"
                        )
                    case .weightRemoved:
                        summary = "xiaomiWeightRemoved=1"
                    }
                } else {
                    let measurement = try StandardWeightScaleParser.parse(payload, now: receivedAt)
                    summary = String(format: "weight=%.3fkg", measurement.weightKG)
                }
            case .standardBodyComposition:
                let measurement = try StandardBodyCompositionParser.parse(payload, now: receivedAt)
                summary = String(
                    format: "weight=%.3fkg fat=%@ impedance=%@",
                    measurement.weightKG,
                    measurement.bodyFatPercent.map { String(format: "%.1f", $0) } ?? "-",
                    measurement.impedanceOhm.map { String(format: "%.0f", $0) } ?? "-"
                )
            case .wolaiAFU:
                let packet = try WolaiAFUScaleParser.parse(payload, now: receivedAt)
                summary = String(
                    format: "phase=%@ weight=%.5fkg impedance=%@ secondaryImpedance=%@",
                    packet.phase.rawValue,
                    packet.measurement.weightKG,
                    packet.measurement.impedanceOhm.map { String(format: "%.0f", $0) } ?? "-",
                    packet.measurement.secondaryImpedanceOhm.map { String(format: "%.0f", $0) } ?? "-"
                )
            case .senssunIF2121:
                switch try SenssunIF2121ScaleParser.parse(payload, now: receivedAt) {
                case .measurement(let phase, let measurement):
                    summary = String(
                        format: "phase=%@ weight=%.2fkg",
                        String(describing: phase),
                        measurement.weightKG
                    )
                case .weightRemoved:
                    summary = "weightRemoved=1"
                case .progress(let phase):
                    summary = "phase=\(String(describing: phase))"
                }
            }
        } catch {
            summary = "rejected=\(error.localizedDescription)"
        }
        return summary
    }

    private func captureAdvertisement(
        from peripheral: CBPeripheral,
        data: [String: Any],
        rssi: Int,
        receivedAt: Date
    ) {
        guard isDeviceDiagnosticCaptureEnabled, peripheral.identifier == settingsScaleID else { return }
        let name = discoveredName(for: peripheral, advertisement: data)
        let connectable = (data[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        let txPower = (data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        var metadata = "name=\(name) rssi=\(rssi)"
        if let connectable { metadata += " connectable=\(connectable ? 1 : 0)" }
        if let txPower { metadata += " txPower=\(txPower)" }
        appendDiagnosticEvent(
            kind: .advertisement,
            source: "ADV",
            summary: metadata,
            receivedAt: receivedAt
        )

        let advertisedServices = [
            CBAdvertisementDataServiceUUIDsKey,
            CBAdvertisementDataOverflowServiceUUIDsKey,
            CBAdvertisementDataSolicitedServiceUUIDsKey
        ].flatMap { data[$0] as? [CBUUID] ?? [] }
        if !advertisedServices.isEmpty {
            appendDiagnosticEvent(
                kind: .advertisement,
                source: "ADV-SERVICES",
                summary: advertisedServices.map { $0.uuidString.uppercased() }.joined(separator: ", "),
                receivedAt: receivedAt
            )
        }
        let protocolMatch = protocolRegistry.decodeAdvertisement(
            advertisementInput(name: name, advertisement: data, receivedAt: receivedAt),
            preferredProtocolID: selectedProtocolID(for: peripheral.identifier)
        )
        if let manufacturerData = data[CBAdvertisementDataManufacturerDataKey] as? Data {
            let protocolSummary: String
            if let match = protocolMatch,
               match.descriptor.transport == .advertisementManufacturerData,
               case .measurement(let measurement) = match.packet {
                protocolSummary = String(
                    format: "%@ weight=%.3fkg stable=%@",
                    match.descriptor.name,
                    measurement.weightKG,
                    measurement.isStable ? "1" : "0"
                )
            } else {
                protocolSummary = "厂商自定义数据"
            }
            appendDiagnosticEvent(
                kind: .advertisement,
                source: "ADV-MANUFACTURER",
                payload: manufacturerData,
                summary: protocolSummary,
                receivedAt: receivedAt
            )
        }
        let serviceData = data[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        for (uuid, payload) in serviceData.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            let summary: String
            if let protocolMatch,
               protocolMatch.descriptor.transport == .advertisementServiceData {
                switch protocolMatch.packet {
                case .measurement(let measurement):
                    summary = String(
                        format: "%@ weight=%.3fkg stable=%@",
                        protocolMatch.descriptor.name,
                        measurement.weightKG,
                        measurement.isStable ? "1" : "0"
                    )
                case .weightRemoved:
                    summary = "\(protocolMatch.descriptor.name) weightRemoved=1"
                }
            } else if uuid == Self.bodyService {
                summary = diagnosticSummary(payload, kind: .xiaomiAdvertisement, receivedAt: receivedAt)
            } else {
                summary = "服务数据"
            }
            appendDiagnosticEvent(
                kind: .advertisement,
                source: "ADV-\(uuid.uuidString.uppercased())",
                payload: payload,
                summary: summary,
                receivedAt: receivedAt
            )
        }
    }

    private static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined()
    }

    private func connectKnownScale(from scales: [PairedScale]) {
        guard central.state == .poweredOn,
              connected == nil,
              let scale = scales.first(where: {
                  isMonitoredScale($0.id)
                      && (pairedScales.automaticHistoryIDs.contains($0.id)
                          || $0.compatibility == ScaleDiscoveryCompatibility.bluetoothSIG.rawValue
                          || effectiveRule(for: $0.id)?.match.transport == .characteristicNotification)
              }) else { return }
        let peripherals = central.retrievePeripherals(withIdentifiers: [scale.id])
        guard let peripheral = peripherals.first else { return }
        connect(DiscoveredScale(
            id: scale.id,
            name: scale.name,
            rssi: 0,
            compatibility: scale.compatibility,
            discoveryPriority: 0,
            discoveryOrder: 0,
            peripheral: peripheral
        ))
    }

    private func bluetoothStateText(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOff: "请打开蓝牙"
        case .unauthorized: "请在系统设置中允许蓝牙"
        case .unsupported: "此设备不支持蓝牙低功耗"
        case .resetting: "蓝牙正在重置"
        default: "蓝牙尚未就绪"
        }
    }

    private func measurementReliability(
        for descriptor: ScaleProtocolDescriptor,
        measurement: BodyMeasurement
    ) -> MeasurementSampleReliability {
        switch descriptor.stabilityPolicy {
        case .protocolReported:
            return .protocolStable
        case .lockedSampleIsFinal:
            return measurement.isStable ? .protocolLocked : .protocolStable
        case .repeatedSamples:
            return .requiresStability
        }
    }

    private func advertisementInput(
        name: String,
        advertisement: [String: Any],
        receivedAt: Date
    ) -> ScaleAdvertisementInput {
        let advertisedServices = Set([
            CBAdvertisementDataServiceUUIDsKey,
            CBAdvertisementDataOverflowServiceUUIDsKey,
            CBAdvertisementDataSolicitedServiceUUIDsKey
        ].flatMap { advertisement[$0] as? [CBUUID] ?? [] }.map(\.uuidString))
        let serviceData = advertisement[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        return ScaleAdvertisementInput(
            name: name,
            manufacturerData: advertisement[CBAdvertisementDataManufacturerDataKey] as? Data,
            advertisedServiceUUIDs: advertisedServices,
            serviceData: Dictionary(uniqueKeysWithValues: serviceData.map { ($0.key.uuidString, $0.value) }),
            receivedAt: receivedAt
        )
    }

    private func discoveryAdvertisement(
        name: String,
        advertisement: [String: Any],
        hasVerifiedXiaomiPayload: Bool,
        recognizedProtocol: ScaleProtocolMatch?
    ) -> ScaleDiscoveryAdvertisement {
        let advertisedServices = [
            CBAdvertisementDataServiceUUIDsKey,
            CBAdvertisementDataOverflowServiceUUIDsKey,
            CBAdvertisementDataSolicitedServiceUUIDsKey
        ].flatMap { advertisement[$0] as? [CBUUID] ?? [] }
        let serviceData = advertisement[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        return ScaleDiscoveryAdvertisement(
            name: name,
            advertisedServiceUUIDs: Set(advertisedServices.map(\.uuidString)),
            serviceDataUUIDs: Set(serviceData.keys.map(\.uuidString)),
            hasVerifiedXiaomiPayload: hasVerifiedXiaomiPayload,
            hasVerifiedWolaiAFUIdentity: WolaiAFUScaleAdapter.matchesIdentity(
                name: name,
                advertisedServiceUUIDs: Set(advertisedServices.map(\.uuidString))
            ),
            hasHuaweiHagridIdentity: HuaweiHagridProtocol.matchesIdentity(
                name: name,
                serviceDataUUIDs: Set(serviceData.keys.map(\.uuidString))
            ),
            recognizedProtocolCompatibility: recognizedProtocol?.descriptor.discoveryCompatibility
        )
    }

    private func discoveredName(for peripheral: CBPeripheral, advertisement: [String: Any]) -> String {
        let advertisedName = (advertisement[CBAdvertisementDataLocalNameKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let advertisedName, !advertisedName.isEmpty { return advertisedName }
        if let peripheralName = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !peripheralName.isEmpty {
            return peripheralName
        }
        return "未命名设备 \(peripheral.identifier.uuidString.suffix(4))"
    }

    private func upsertDiscoveredScale(_ item: DiscoveredScale) {
        if let index = devices.firstIndex(where: { $0.id == item.id }) {
            let previous = devices[index]
            var updated = item
            updated.discoveryOrder = previous.discoveryOrder
            updated.discoveryPriority = min(previous.discoveryPriority, item.discoveryPriority)
            if previous.isVerifiedCompatible {
                updated.compatibility = previous.compatibility
            }
            if !previous.name.hasPrefix("未命名设备"),
               previous.discoveryPriority <= item.discoveryPriority {
                updated.name = previous.name
            }
            if item.rssi == 127 {
                updated.rssi = previous.rssi
            } else if previous.rssi != 127 {
                updated.rssi = Int((Double(previous.rssi) * 0.75 + Double(item.rssi) * 0.25).rounded())
            }
            devices[index] = updated
        } else {
            var inserted = item
            inserted.discoveryOrder = discoverySequence
            discoverySequence += 1
            devices.append(inserted)
        }
        devices.sort {
            if $0.discoveryPriority != $1.discoveryPriority {
                return $0.discoveryPriority < $1.discoveryPriority
            }
            return $0.discoveryOrder < $1.discoveryOrder
        }
    }
}

extension BluetoothScaleCoordinator: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn, scanRequested {
                beginScanning(clearDevices: false)
            } else {
                state = central.state == .poweredOn ? .idle : .unavailable(bluetoothStateText(central.state))
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let receivedAt = Date.now
            captureAdvertisement(
                from: peripheral,
                data: advertisementData,
                rssi: RSSI.intValue,
                receivedAt: receivedAt
            )
            let name = discoveredName(for: peripheral, advertisement: advertisementData)
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
            let protocolMatch = protocolRegistry.decodeAdvertisement(
                advertisementInput(name: name, advertisement: advertisementData, receivedAt: receivedAt),
                preferredProtocolID: selectedProtocolID(for: peripheral.identifier)
            )
            let xiaomiPayload = serviceData?[Self.bodyService]
            let hasVerifiedXiaomiPayload = xiaomiPayload.flatMap {
                try? XiaomiScaleParser.parsePacket($0, now: receivedAt)
            } != nil
            let isHuaweiHagrid = HuaweiHagridProtocol.matchesIdentity(
                name: name,
                serviceDataUUIDs: Set(serviceData?.keys.map(\.uuidString) ?? [])
            )
            if isHuaweiHagrid {
                huaweiHagridDeviceIDs.insert(peripheral.identifier)
            }
            if case .measuring = scanPurpose,
               isMonitoredScale(peripheral.identifier) {
                if let protocolMatch,
                   allowsBuiltInParser(protocolMatch.descriptor.parserID, for: peripheral.identifier) {
                    switch protocolMatch.packet {
                    case .measurement(let measurement):
                        consume(
                            measurement,
                            reliability: measurementReliability(
                                for: protocolMatch.descriptor,
                                measurement: measurement
                            ),
                            deviceID: peripheral.identifier,
                            deviceName: pairedScales.names[peripheral.identifier] ?? peripheral.name
                        )
                    case .weightRemoved:
                        weightWasRemoved()
                    }
                } else if let custom = selectedRule(for: peripheral.identifier), custom.isDeclarative,
                   custom.match.transport == .advertisementServiceData,
                   let payload = serviceData?.first(where: {
                       CommunicationRuleCodec.normalizeUUID($0.key.uuidString) == custom.match.serviceUUID
                   })?.value {
                    consumeCustomPacket(payload, rule: custom, deviceID: peripheral.identifier)
                } else if allowsBuiltInParser("xiaomiLegacyAdvertisement", for: peripheral.identifier),
                          let payload = serviceData?[Self.bodyService] {
                if let packet = try? XiaomiScaleParser.parsePacket(payload, now: receivedAt) {
                    switch packet {
                    case .measurement(let measurement):
                        consume(
                            measurement,
                            reliability: .protocolStable,
                            deviceID: peripheral.identifier,
                            deviceName: pairedScales.names[peripheral.identifier] ?? peripheral.name
                        )
                    case .weightRemoved:
                        weightWasRemoved()
                    }
                }
                }
            }

            if case .configuring(let scaleID) = scanPurpose,
               scaleID == peripheral.identifier,
               connected?.identifier != peripheral.identifier {
                connectForSettings(peripheral, name: pairedScales.names[scaleID] ?? name)
                return
            }
            let discovery = discoveryAdvertisement(
                name: pairedScales.modelNames[peripheral.identifier] ?? name,
                advertisement: advertisementData,
                hasVerifiedXiaomiPayload: hasVerifiedXiaomiPayload,
                recognizedProtocol: protocolMatch
            )
            let compatibility = ScaleDiscoveryClassifier.compatibility(for: discovery)
            let item = DiscoveredScale(
                id: peripheral.identifier,
                name: name,
                rssi: RSSI.intValue,
                compatibility: compatibility.rawValue,
                discoveryPriority: ScaleDiscoveryClassifier.discoveryPriority(
                    for: discovery,
                    compatibility: compatibility
                ),
                peripheral: peripheral
            )
            if case .adding = scanPurpose {
                upsertDiscoveredScale(item)
            }

            if case .measuring = scanPurpose,
               isMonitoredScale(peripheral.identifier),
               connected?.identifier != peripheral.identifier,
               pairedScales.automaticHistoryIDs.contains(peripheral.identifier)
                    || ((item.isVerifiedCompatible
                        || effectiveRule(for: peripheral.identifier)?.match.transport == .characteristicNotification)
                        && protocolMatch == nil
                        && (!hasVerifiedXiaomiPayload
                            || effectiveRule(for: peripheral.identifier)?.match.transport == .characteristicNotification)) {
                connect(item)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            if settingsScaleID != peripheral.identifier {
                guard case .measuring = scanPurpose,
                      isMonitoredScale(peripheral.identifier),
                      connected === peripheral else {
                    central.cancelPeripheralConnection(peripheral)
                    return
                }
            }
            connectionTimeoutTask?.cancel()
            if settingsScaleID == peripheral.identifier {
                appendDiagnosticEvent(kind: .service, source: "CONNECTION", summary: "设备已连接")
                didSendHuaweiHagridProbe = false
                didReceiveHuaweiHagridChallenge = false
                didSendHuaweiHagridRealtimeProbe = false
                lastHuaweiHagridMeasurementStatus = nil
                huaweiHagridNotificationAccumulators.removeAll()
            }
            state = .connected(peripheral.name ?? "体重秤")
            if settingsScaleID == peripheral.identifier {
                settingsState = .discovering
                armSettingsTimeout(for: peripheral.identifier)
                peripheral.discoverServices(nil)
            } else {
                let selected = selectedRule(for: peripheral.identifier)
                if startConnectedProtocolSessionIfAvailable(on: peripheral) {
                    // The protocol session owns service and characteristic discovery.
                } else if selected?.isDeclarative == true
                    || selected?.notifyTargets?.isEmpty == false {
                    peripheral.discoverServices(nil)
                } else {
                    peripheral.discoverServices([Self.weightService, Self.bodyService, Self.wolaiService])
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            guard connected?.identifier == peripheral.identifier else { return }
            connectionTimeoutTask?.cancel()
            connected = nil
            if settingsScaleID == peripheral.identifier {
                appendDiagnosticEvent(
                    kind: .error,
                    source: "CONNECTION",
                    summary: "连接失败：\(error?.localizedDescription ?? "未知错误")"
                )
                settingsState = .failed(error?.localizedDescription ?? "无法连接设备，请唤醒秤后重试")
            } else if case .measuring = scanPurpose, !pairedScales.ids.isEmpty {
                beginScanning(clearDevices: false)
            } else {
                state = .unavailable(error?.localizedDescription ?? "连接失败，请重试")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            guard connected?.identifier == peripheral.identifier else { return }
            let reconnectScale = pendingSettingsReconnect?.id == peripheral.identifier
                ? pendingSettingsReconnect
                : nil
            pendingSettingsReconnect = nil
            connected = nil
            activeScaleID = nil
            activeScaleName = nil
            resetActiveProtocolSession()
            if let reconnectScale {
                appendDiagnosticEvent(
                    kind: .service,
                    source: "CONNECTION",
                    summary: "正在重新连接设备"
                )
                armSettingsTimeout(for: reconnectScale.id)
                if let retrieved = central.retrievePeripherals(withIdentifiers: [reconnectScale.id]).first {
                    connectForSettings(retrieved, name: reconnectScale.name)
                } else {
                    beginScanning(clearDevices: false)
                    settingsState = .locating
                }
                return
            }
            if settingsScaleID == peripheral.identifier {
                appendDiagnosticEvent(
                    kind: error == nil ? .service : .error,
                    source: "CONNECTION",
                    summary: error.map { "连接断开：\($0.localizedDescription)" } ?? "设备已断开"
                )
                if error != nil {
                    settingsState = .failed("设备连接已断开")
                }
            } else if case .measuring = scanPurpose, !pairedScales.ids.isEmpty {
                beginScanning(clearDevices: false)
            } else {
                state = error == nil ? .idle : .unavailable("连接已断开")
            }
        }
    }
}

extension BluetoothScaleCoordinator: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                if settingsScaleID == peripheral.identifier {
                    appendDiagnosticEvent(
                        kind: .error,
                        source: "GATT-SERVICES",
                        summary: "服务发现失败：\(error?.localizedDescription ?? "未知错误")"
                    )
                    settingsState = .failed(error?.localizedDescription ?? "无法读取设备服务")
                }
                return
            }
            let services = peripheral.services ?? []
            if settingsScaleID != peripheral.identifier,
               activeProtocolSessionDeviceID == peripheral.identifier,
               let session = activeProtocolSession {
                let serviceUUIDs = Set(services.map {
                    CommunicationRuleCodec.normalizeUUID($0.uuid.uuidString)
                })
                if let actions = try? session.handle(.servicesDiscovered(serviceUUIDs)) {
                    try? executeProtocolActions(actions, on: peripheral)
                }
                return
            }
            if settingsScaleID == peripheral.identifier {
                settingsSnapshot.discoveredServiceUUIDs = services
                    .map { $0.uuid.uuidString.uppercased() }
                    .sorted()
                for service in services {
                    appendDiagnosticEvent(
                        kind: .service,
                        source: service.uuid.uuidString.uppercased(),
                        summary: "发现 GATT 服务"
                    )
                }
                pendingSettingsServiceIDs = Set(services.map(ObjectIdentifier.init))
                guard !services.isEmpty else {
                    settingsState = .failed("设备没有公开可发现的 GATT 服务")
                    return
                }
            }
            for service in services { peripheral.discoverCharacteristics(nil, for: service) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                if settingsScaleID == peripheral.identifier {
                    appendDiagnosticEvent(
                        kind: .error,
                        source: service.uuid.uuidString.uppercased(),
                        summary: "特征发现失败：\(error?.localizedDescription ?? "未知错误")"
                    )
                    settingsState = .failed(error?.localizedDescription ?? "无法读取设备特征")
                }
                return
            }
            if settingsScaleID != peripheral.identifier,
               activeProtocolSessionDeviceID == peripheral.identifier,
               let session = activeProtocolSession {
                let serviceUUID = CommunicationRuleCodec.normalizeUUID(service.uuid.uuidString)
                let characteristicUUIDs = Set((service.characteristics ?? []).map {
                    CommunicationRuleCodec.normalizeUUID($0.uuid.uuidString)
                })
                if let actions = try? session.handle(.characteristicsDiscovered(
                    serviceUUID: serviceUUID,
                    characteristicUUIDs: characteristicUUIDs
                )) {
                    try? executeProtocolActions(actions, on: peripheral)
                }
                return
            }
            if CommunicationRuleCodec.normalizeUUID(service.uuid.uuidString)
                == HuaweiHagridProtocol.userDataServiceUUID,
               service.characteristics?.contains(where: {
                   HuaweiHagridProtocol.isRequestAuthenticationCharacteristic($0.uuid.uuidString)
               }) == true {
                huaweiHagridDeviceIDs.insert(peripheral.identifier)
            }
            for characteristic in service.characteristics ?? [] {
                let characteristicTarget = CommunicationGATTTarget(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(service.uuid.uuidString),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString)
                )
                let isSelectedNotificationTarget = selectedRule(for: peripheral.identifier)?
                    .notifyTargets?.contains(characteristicTarget) == true
                let isWolaiService = service.uuid == Self.wolaiService
                    && isWolaiAFUSelected(for: peripheral.identifier)
                let isDiagnosticTarget = settingsScaleID == peripheral.identifier
                    && isDeviceDiagnosticCaptureEnabled
                let isHuaweiDiagnosticTarget = isDiagnosticTarget
                    && huaweiHagridDeviceIDs.contains(peripheral.identifier)
                let shouldSubscribeDiagnostic = isHuaweiDiagnosticTarget
                    ? HuaweiHagridProtocol.isProbeNotificationCharacteristic(
                        characteristic.uuid.uuidString
                    )
                    : isDiagnosticTarget
                if characteristic.uuid == Self.weightMeasurement
                    || characteristic.uuid == Self.bodyMeasurement
                    || isWolaiService && characteristic.uuid == Self.wolaiMeasurement
                    || isSelectedNotificationTarget
                    || customRule(
                        for: peripheral.identifier,
                        transport: .characteristicNotification,
                        serviceUUID: service.uuid.uuidString,
                        characteristicUUID: characteristic.uuid.uuidString
                    ) != nil
                    || shouldSubscribeDiagnostic
                        && (characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                guard settingsScaleID == peripheral.identifier else { continue }
                settingsCharacteristicsByTarget[targetKey(.init(
                    serviceUUID: service.uuid.uuidString,
                    characteristicUUID: characteristic.uuid.uuidString
                ))] = characteristic
                appendDiagnosticEvent(
                    kind: .characteristic,
                    source: characteristic.uuid.uuidString.uppercased(),
                    summary: "service=\(service.uuid.uuidString.uppercased()) properties=\(characteristicPropertiesDescription(characteristic.properties))"
                )
                inspectSettingsCharacteristic(characteristic, in: service, on: peripheral)
                if HuaweiHagridProtocol.isRequestAuthenticationCharacteristic(
                    characteristic.uuid.uuidString
                ) {
                    settingsHuaweiAuthenticationCharacteristic = characteristic
                } else if HuaweiHagridProtocol.isRealtimeWeightCharacteristic(
                    characteristic.uuid.uuidString
                ) {
                    settingsHuaweiRealtimeCharacteristic = characteristic
                }
                let isKnownAutoRead = characteristic.uuid == Self.softwareRevision
                    || characteristic.uuid == Self.hardwareRevision
                    || characteristic.uuid == Self.serialNumber
                    || characteristic.uuid == Self.xiaomiConfiguration
                if isDiagnosticTarget,
                   characteristic.properties.contains(.read),
                   !isKnownAutoRead {
                    captureCharacteristicEvent(
                        direction: .read,
                        characteristic: characteristic,
                        summary: "诊断读取可读特征"
                    )
                    peripheral.readValue(for: characteristic)
                }
            }
            if settingsScaleID == peripheral.identifier {
                pendingSettingsServiceIDs.remove(ObjectIdentifier(service))
                if pendingSettingsServiceIDs.isEmpty {
                    refreshHistoryAvailability(for: peripheral.identifier)
                    refreshProtocolConfigurationAvailability(for: peripheral.identifier)
                    settingsState = .ready
                    scheduleHuaweiHagridDiagnosticProbe(on: peripheral)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            Task { @MainActor in
                if settingsScaleID == peripheral.identifier {
                    captureCharacteristicEvent(
                        direction: .error,
                        characteristic: characteristic,
                        summary: "接收失败：\(error.localizedDescription)"
                    )
                }
                if settingsScaleID == peripheral.identifier,
                   (characteristic.uuid == Self.xiaomiConfiguration || characteristic.uuid == Self.currentTime),
                   pendingSettingsOperation != nil {
                    settingsOperationSucceeded = true
                    settingsOperationMessage = "命令已写入，但设备不支持可靠读回；请核对秤面显示"
                    pendingSettingsOperation = nil
                }
            }
            return
        }
        guard let data = characteristic.value else { return }
        Task { @MainActor in
            if settingsScaleID != peripheral.identifier {
                guard case .measuring = scanPurpose,
                      isMonitoredScale(peripheral.identifier),
                      connected === peripheral else { return }
            }
            if activeProtocolHistoryOrigin != nil,
               activeProtocolSessionDeviceID == peripheral.identifier,
               let session = activeProtocolSession,
               let serviceUUID = characteristic.service?.uuid.uuidString,
               historyOperation(for: peripheral.identifier)?.subscriptions.contains(where: {
                   targetKey($0) == targetKey(.init(
                    serviceUUID: serviceUUID,
                    characteristicUUID: characteristic.uuid.uuidString
                   ))
               }) == true {
                if let actions = try? session.handle(.notification(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString),
                    payload: data,
                    receivedAt: .now
                )) {
                    try? executeProtocolActions(actions, on: peripheral)
                }
                return
            }
            if settingsScaleID == peripheral.identifier {
                captureCharacteristicEvent(
                    direction: characteristic.isNotifying ? .notification : .received,
                    characteristic: characteristic,
                    payload: data,
                    summary: diagnosticValueSummary(data, characteristic: characteristic)
                )
                if let frame = try? HuaweiHagridProtocol.parseNotificationFrame(data),
                   HuaweiHagridProtocol.isRequestAuthenticationCharacteristic(
                       characteristic.uuid.uuidString
                   ) {
                    let key = characteristic.uuid.uuidString.uppercased()
                    var accumulator = huaweiHagridNotificationAccumulators[key] ?? .init()
                    let completed = accumulator.ingest(frame)
                    huaweiHagridNotificationAccumulators[key] = accumulator
                    if let completed,
                       !completed.isEncrypted,
                       (try? HuaweiHagridProtocol.parseAuthenticationChallenge(completed.payload)) != nil {
                        didReceiveHuaweiHagridChallenge = true
                        appendDiagnosticEvent(
                            kind: .received,
                            source: key,
                            summary: "Huawei Hagrid 认证挑战重组完成（\(completed.payload.count) 字节）"
                        )
                        sendHuaweiHagridRealtimeProbeIfReady(on: peripheral)
                    }
                }
                if let frame = try? HuaweiHagridProtocol.parseNotificationFrame(data),
                   HuaweiHagridProtocol.isMeasurementStatusResultCharacteristic(
                       characteristic.uuid.uuidString
                   ),
                   let status = try? HuaweiHagridProtocol.parseMeasurementStatus(frame),
                   status != lastHuaweiHagridMeasurementStatus {
                    lastHuaweiHagridMeasurementStatus = status
                    if status == .measuring {
                        sendHuaweiHagridRealtimeProbeIfReady(
                            on: peripheral,
                            reason: "测量活动开始",
                            allowRepeat: true
                        )
                    }
                }
                consumeSettingsValue(data, from: characteristic)
                if consumeDeclarativeHistory(data, peripheral: peripheral, characteristic: characteristic) {
                    return
                }
            }

            if settingsScaleID != peripheral.identifier,
               activeProtocolSessionDeviceID == peripheral.identifier,
               let session = activeProtocolSession,
               let serviceUUID = characteristic.service?.uuid.uuidString {
                guard case .measuring = scanPurpose,
                      connected === peripheral,
                      isMonitoredScale(peripheral.identifier) else { return }
                if let actions = try? session.handle(.notification(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString),
                    payload: data,
                    receivedAt: .now
                )) {
                    try? executeProtocolActions(actions, on: peripheral)
                }
                return
            }

            if let serviceUUID = characteristic.service?.uuid.uuidString,
               let custom = customRule(
                   for: peripheral.identifier,
                   transport: .characteristicNotification,
                   serviceUUID: serviceUUID,
                   characteristicUUID: characteristic.uuid.uuidString
               ) {
                guard case .measuring = scanPurpose else { return }
                consumeCustomPacket(data, rule: custom, deviceID: peripheral.identifier)
                return
            }

            if characteristic.uuid == Self.weightMeasurement,
               allowsBuiltInParser("bluetoothSIGWeight", for: peripheral.identifier),
               XiaomiGATTWeightParser.matches(data),
               let packet = try? XiaomiGATTWeightParser.parsePacket(data) {
                switch packet {
                case .measurement(let measurement):
                    consume(measurement, reliability: .protocolStable)
                case .weightRemoved:
                    weightWasRemoved()
                }
            } else if characteristic.uuid == Self.weightMeasurement,
                      allowsBuiltInParser("bluetoothSIGWeight", for: peripheral.identifier),
                      let value = try? StandardWeightScaleParser.parse(data) {
                let reliability: MeasurementSampleReliability = characteristic.properties.contains(.indicate)
                    ? .protocolFinal
                    : .requiresStability
                if let body = pendingBodyComposition, abs(body.date.timeIntervalSinceNow) < 20 {
                    var merged = body
                    merged.weightKG = value.weightKG
                    merged.date = value.date
                    consume(merged, reliability: reliability)
                } else {
                    consume(value, reliability: reliability)
                }
            } else if characteristic.uuid == Self.bodyMeasurement,
                      allowsBuiltInParser("bluetoothSIGBodyComposition", for: peripheral.identifier),
                      let value = try? StandardBodyCompositionParser.parse(data) {
                pendingBodyComposition = value
                let reliability: MeasurementSampleReliability = characteristic.properties.contains(.indicate)
                    ? .protocolFinal
                    : .requiresStability
                consume(value, reliability: reliability)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if error == nil,
               activeProtocolSessionDeviceID == peripheral.identifier,
               let session = activeProtocolSession,
               let serviceUUID = characteristic.service?.uuid.uuidString {
                if settingsScaleID != peripheral.identifier,
                   characteristic.isNotifying {
                    _ = startAutomaticConnectedProtocolHistoryIfNeeded(on: peripheral)
                }
                if let actions = try? session.handle(.notificationStateChanged(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(
                        characteristic.uuid.uuidString
                    ),
                    isNotifying: characteristic.isNotifying,
                    changedAt: .now
                )) {
                    try? executeProtocolActions(actions, on: peripheral)
                }
            }
            guard settingsScaleID == peripheral.identifier else { return }
            if let error {
                captureCharacteristicEvent(
                    direction: .error,
                    characteristic: characteristic,
                    summary: "订阅失败：\(error.localizedDescription)"
                )
            } else {
                captureCharacteristicEvent(
                    direction: .notification,
                    characteristic: characteristic,
                    summary: characteristic.isNotifying ? "通知已订阅" : "通知已取消"
                )
                if HuaweiHagridProtocol.isRequestAuthenticationCharacteristic(
                    characteristic.uuid.uuidString
                ) {
                    sendHuaweiHagridAuthenticationProbeIfReady(on: peripheral)
                } else if HuaweiHagridProtocol.isRealtimeWeightCharacteristic(
                    characteristic.uuid.uuidString
                ) {
                    sendHuaweiHagridRealtimeProbeIfReady(on: peripheral)
                }
                if let service = characteristic.service {
                    let key = targetKey(.init(
                        serviceUUID: service.uuid.uuidString,
                        characteristicUUID: characteristic.uuid.uuidString
                    ))
                    if pendingHistorySubscriptions.remove(key) != nil,
                       pendingHistorySubscriptions.isEmpty,
                       let operation = activeHistoryOperation {
                        write(operation.commands, on: peripheral)
                    }
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let session = activeProtocolSession,
               activeProtocolSessionDeviceID == peripheral.identifier,
               let serviceUUID = characteristic.service?.uuid.uuidString {
                let writtenTarget = CommunicationGATTTarget(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString)
                )
                let operation = historyOperation(for: peripheral.identifier)
                let historyCommands = (operation?.commands ?? [])
                    + (operation?.completionCommands ?? [])
                    + (operation?.acknowledgementCommands ?? [])
                let wasHistoryWrite = activeProtocolHistoryOrigin != nil
                    && historyCommands.contains(where: { $0.target == writtenTarget })
                if settingsScaleID == peripheral.identifier {
                    captureCharacteristicEvent(
                        direction: error == nil ? .acknowledgement : .error,
                        characteristic: characteristic,
                        summary: error.map { "协议会话命令写入失败：\($0.localizedDescription)" }
                            ?? "协议会话命令 ATT 写入回执成功"
                    )
                }
                if let actions = try? session.handle(.writeCompleted(
                    serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
                    characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString),
                    succeeded: error == nil
                )) {
                    try? executeProtocolActions(actions, on: peripheral)
                }
                if settingsScaleID == peripheral.identifier,
                   pendingProtocolSettingsTarget.map({ targetKey($0) }) == targetKey(writtenTarget) {
                    pendingProtocolSettingsTarget = nil
                    if let error {
                        settingsOperationSucceeded = false
                        settingsOperationMessage = "写入失败：\(error.localizedDescription)"
                        pendingSettingsOperation = nil
                    } else {
                        verifySettingsWrite(on: peripheral, characteristic: characteristic)
                    }
                    return
                }
                if wasHistoryWrite { return }
            }
            guard settingsScaleID == peripheral.identifier else { return }
            if isDeviceDiagnosticCaptureEnabled,
               (HuaweiHagridProtocol.isRequestAuthenticationCharacteristic(characteristic.uuid.uuidString)
                    || HuaweiHagridProtocol.isRealtimeWeightCharacteristic(characteristic.uuid.uuidString)) {
                let kind = HuaweiHagridProtocol.isRequestAuthenticationCharacteristic(
                    characteristic.uuid.uuidString
                ) ? "认证" : "实时测量"
                captureCharacteristicEvent(
                    direction: error == nil ? .acknowledgement : .error,
                    characteristic: characteristic,
                    summary: error.map { "华为 Hagrid \(kind)探针写入失败：\($0.localizedDescription)" }
                        ?? "华为 Hagrid \(kind)探针 ATT 写入回执成功"
                )
                return
            }
            guard characteristic.uuid == Self.xiaomiConfiguration
                    || characteristic.uuid == Self.currentTime else { return }
            if let error {
                captureCharacteristicEvent(
                    direction: .error,
                    characteristic: characteristic,
                    summary: "写入失败：\(error.localizedDescription)"
                )
                settingsOperationSucceeded = false
                settingsOperationMessage = "写入失败：\(error.localizedDescription)"
                pendingSettingsOperation = nil
            } else {
                captureCharacteristicEvent(
                    direction: .acknowledgement,
                    characteristic: characteristic,
                    summary: "ATT 写入回执成功"
                )
                verifySettingsWrite(on: peripheral, characteristic: characteristic)
            }
        }
    }

    private func inspectSettingsCharacteristic(
        _ characteristic: CBCharacteristic,
        in service: CBService,
        on peripheral: CBPeripheral
    ) {
        let isWritable = characteristic.properties.contains(.write)
            || characteristic.properties.contains(.writeWithoutResponse)
        if isWritable {
            let uuid = characteristic.uuid.uuidString.uppercased()
            if !settingsSnapshot.writableCharacteristicUUIDs.contains(uuid) {
                settingsSnapshot.writableCharacteristicUUIDs.append(uuid)
                settingsSnapshot.writableCharacteristicUUIDs.sort()
            }
        }

        switch characteristic.uuid {
        case Self.softwareRevision, Self.hardwareRevision, Self.serialNumber:
            if characteristic.properties.contains(.read) {
                captureCharacteristicEvent(
                    direction: .read,
                    characteristic: characteristic,
                    summary: "读取设备信息"
                )
                peripheral.readValue(for: characteristic)
            }
        case Self.xiaomiConfiguration:
            if service.uuid == Self.xiaomiConfigurationService {
                settingsSnapshot.canConfigureHardwareUnit = isWritable
                if characteristic.properties.contains(.read) {
                    captureCharacteristicEvent(
                        direction: .read,
                        characteristic: characteristic,
                        summary: "读取当前配置"
                    )
                    peripheral.readValue(for: characteristic)
                }
            }
        case Self.currentTime:
            settingsCurrentTimeCharacteristic = characteristic
            settingsSnapshot.canSynchronizeTime = isWritable
        default:
            break
        }
    }

    private func consumeSettingsValue(_ data: Data, from characteristic: CBCharacteristic) {
        switch characteristic.uuid {
        case Self.softwareRevision:
            settingsSnapshot.firmwareRevision = decodedDeviceInformationString(data)
        case Self.hardwareRevision:
            settingsSnapshot.hardwareRevision = decodedDeviceInformationString(data)
        case Self.serialNumber:
            settingsSnapshot.serialNumber = decodedDeviceInformationString(data)
        case Self.xiaomiConfiguration:
            if case .unit(let expected) = pendingSettingsOperation {
                let directUnit = XiaomiScaleConfigurationProtocol.parseUnit(from: data)
                let commandResponse = XiaomiScaleConfigurationProtocol.parseUnitCommandResponse(from: data)
                if directUnit == expected || (commandResponse?.unit == expected && commandResponse?.status == 0x01) {
                    settingsSnapshot.hardwareUnit = expected
                    settingsOperationSucceeded = true
                    settingsOperationMessage = "已从秤端读回并确认单位设置"
                } else if let directUnit {
                    settingsOperationSucceeded = true
                    settingsOperationMessage = "单位设置命令已成功写入；辅助读回仍为\(directUnit.title)"
                } else if let commandResponse, commandResponse.status == 0x01 {
                    settingsOperationSucceeded = true
                    settingsOperationMessage = "单位设置命令已成功写入；收到上一条单位命令的延迟响应"
                } else {
                    settingsOperationSucceeded = true
                    settingsOperationMessage = "单位设置命令已成功写入"
                }
                pendingSettingsOperation = nil
            } else if let unit = XiaomiScaleConfigurationProtocol.parseUnit(from: data) {
                settingsSnapshot.hardwareUnit = unit
            }
        case Self.currentTime:
            if case .currentTime = pendingSettingsOperation {
                let scaleDate = BluetoothCurrentTimeProtocol.parseDate(from: data)
                let matchesCurrentTime = scaleDate.map { abs($0.timeIntervalSinceNow) < 120 } == true
                settingsOperationSucceeded = true
                settingsOperationMessage = matchesCurrentTime
                    ? "已从秤端读回并确认当前时间"
                    : "命令已写入；即时读回时间未同步，请稍后重新检测"
                pendingSettingsOperation = nil
            }
        default:
            break
        }
    }

    private func decodedDeviceInformationString(_ data: Data) -> String? {
        let trimmingSet = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: trimmingSet)
        return value?.isEmpty == false ? value : nil
    }

    private func diagnosticValueSummary(_ data: Data, characteristic: CBCharacteristic) -> String {
        if let frame = try? HuaweiHagridProtocol.parseNotificationFrame(data) {
            let encryption = frame.isEncrypted ? "encrypted" : "plain"
            let sequence = "\(frame.frameIndex + 1)/\(frame.totalFrames)"
            if HuaweiHagridProtocol.isRequestAuthenticationCharacteristic(characteristic.uuid.uuidString),
               !frame.isEncrypted,
               frame.payload.count == 16 {
                return "Huawei Hagrid 认证挑战（16 字节） frame=\(sequence)"
            }
            if HuaweiHagridProtocol.isMeasurementStatusResultCharacteristic(
                characteristic.uuid.uuidString
            ), let status = try? HuaweiHagridProtocol.parseMeasurementStatus(frame) {
                let state: String
                let value: UInt8
                switch status {
                case .ready:
                    state = "测量完成或空闲"
                    value = 0x00
                case .measuring:
                    state = "测量活动中"
                    value = 0x01
                case let .unknown(rawValue):
                    state = "未知状态"
                    value = rawValue
                }
                return "Huawei Hagrid 测量状态=\(String(format: "%02X", value))（\(state)） frame=\(sequence)"
            }
            return "Huawei Hagrid WSP \(encryption) frame=\(sequence) payload=\(frame.payload.count)字节"
        }
        if characteristic.uuid == Self.weightMeasurement {
            return diagnosticSummary(data, kind: .standardWeight, receivedAt: .now)
        }
        if characteristic.uuid == Self.bodyMeasurement {
            return diagnosticSummary(data, kind: .standardBodyComposition, receivedAt: .now)
        }
        if isWolaiMeasurement(characteristic) {
            return diagnosticSummary(data, kind: .wolaiAFU, receivedAt: .now)
        }
        if CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString)
            == SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
           let deviceID = characteristic.service?.peripheral?.identifier,
           isSenssunIF2121Selected(for: deviceID) {
            return diagnosticSummary(data, kind: .senssunIF2121, receivedAt: .now)
        }
        if CommunicationRuleCodec.normalizeUUID(characteristic.uuid.uuidString)
            == SenssunIF2121ScaleProtocol.resultCharacteristicUUID,
           let deviceID = characteristic.service?.peripheral?.identifier,
           isSenssunIF2121Selected(for: deviceID) {
            return data.starts(with: [0x33, 0xCC])
                ? "Senssun IF2121 最终结果首分片（\(data.count)/40 字节）"
                : "Senssun IF2121 最终结果续分片（\(data.count) 字节）"
        }
        if characteristic.uuid == Self.xiaomiConfiguration {
            if let unit = XiaomiScaleConfigurationProtocol.parseUnit(from: data) {
                return "解析为单位配置：\(unit.title)"
            }
            if let response = XiaomiScaleConfigurationProtocol.parseUnitCommandResponse(from: data) {
                return "单位命令响应：\(response.unit.title)；状态：\(String(format: "%02X", response.status))"
            }
            return "未识别的配置返回值"
        }
        if characteristic.uuid == Self.currentTime,
           let date = BluetoothCurrentTimeProtocol.parseDate(from: data) {
            return "解析时间：\(date.formatted(.dateTime.year().month().day().hour().minute().second()))"
        }
        if let string = decodedDeviceInformationString(data),
           string.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
            return "UTF-8：\(string)"
        }
        return "未识别的原始值（\(data.count) 字节）"
    }

    private func scheduleHuaweiHagridDiagnosticProbe(on peripheral: CBPeripheral) {
        guard isDeviceDiagnosticCaptureEnabled,
              huaweiHagridDeviceIDs.contains(peripheral.identifier) else { return }
        Task { @MainActor [weak self, weak peripheral] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, let peripheral else { return }
            self.sendHuaweiHagridAuthenticationProbeIfReady(on: peripheral)
        }
    }

    private func sendHuaweiHagridAuthenticationProbeIfReady(on peripheral: CBPeripheral) {
        guard isDeviceDiagnosticCaptureEnabled,
              !didSendHuaweiHagridProbe,
              let characteristic = settingsHuaweiAuthenticationCharacteristic,
              characteristic.isNotifying,
              characteristic.properties.contains(.write) else { return }
        didSendHuaweiHagridProbe = true
        let probe = HuaweiHagridProtocol.makeAuthenticationProbe()
        captureCharacteristicEvent(
            direction: .write,
            characteristic: characteristic,
            payload: probe,
            summary: "华为 Hagrid WSP 认证探针（不含密钥）"
        )
        peripheral.writeValue(probe, for: characteristic, type: .withResponse)
    }

    private func sendHuaweiHagridRealtimeProbeIfReady(
        on peripheral: CBPeripheral,
        reason: String = "认证挑战后",
        allowRepeat: Bool = false
    ) {
        guard isDeviceDiagnosticCaptureEnabled,
              didReceiveHuaweiHagridChallenge,
              allowRepeat || !didSendHuaweiHagridRealtimeProbe,
              let characteristic = settingsHuaweiRealtimeCharacteristic,
              characteristic.isNotifying,
              characteristic.properties.contains(.write) else { return }
        didSendHuaweiHagridRealtimeProbe = true
        let probe = HuaweiHagridProtocol.makeAuthenticationProbe()
        captureCharacteristicEvent(
            direction: .write,
            characteristic: characteristic,
            payload: probe,
            summary: "华为 Hagrid 未认证实时测量探针（\(reason)）"
        )
        peripheral.writeValue(probe, for: characteristic, type: .withResponse)
    }

    private func characteristicPropertiesDescription(_ properties: CBCharacteristicProperties) -> String {
        var values: [String] = []
        if properties.contains(.broadcast) { values.append("broadcast") }
        if properties.contains(.read) { values.append("read") }
        if properties.contains(.writeWithoutResponse) { values.append("writeWithoutResponse") }
        if properties.contains(.write) { values.append("write") }
        if properties.contains(.notify) { values.append("notify") }
        if properties.contains(.indicate) { values.append("indicate") }
        if properties.contains(.authenticatedSignedWrites) { values.append("signedWrite") }
        if properties.contains(.extendedProperties) { values.append("extended") }
        if properties.contains(.notifyEncryptionRequired) { values.append("notifyEncrypted") }
        if properties.contains(.indicateEncryptionRequired) { values.append("indicateEncrypted") }
        return values.isEmpty ? "none" : values.joined(separator: "|")
    }
}
