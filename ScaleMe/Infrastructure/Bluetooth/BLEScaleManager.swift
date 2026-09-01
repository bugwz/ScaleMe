import CoreBluetooth
import Foundation

struct DiscoveredScale: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int
    var compatibility: String
    var discoveryPriority: Int
    var discoveryOrder = 0
    var peripheral: CBPeripheral

    var isVerifiedCompatible: Bool {
        ScaleDiscoveryCompatibility(rawValue: compatibility)?.isVerified == true
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.rssi == rhs.rssi }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ScaleDeviceSettingsSnapshot: Equatable {
    var firmwareRevision: String?
    var hardwareRevision: String?
    var serialNumber: String?
    var hardwareUnit: XiaomiScaleHardwareUnit?
    var canConfigureXiaomiUnit = false
    var canSynchronizeTime = false
    var hasHistoryChannel = false
    var discoveredServiceUUIDs: [String] = []
    var writableCharacteristicUUIDs: [String] = []
}

enum ScaleHistoryState: Equatable {
    case unavailable
    case ready
    case reading(received: Int, announced: Int?)
    case awaitingImport([BodyMeasurement])
    case imported(Int)
    case clearCommandSent
    case failed(String)
}

struct DeviceDiagnosticEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case advertisement = "广播"
        case service = "服务"
        case characteristic = "特征"
        case notification = "通知"
        case write = "写入"
        case acknowledgement = "回执"
        case read = "读取"
        case received = "返回"
        case error = "错误"
    }

    let id = UUID()
    var elapsedSeconds: TimeInterval
    var kind: Kind
    var source: String
    var payloadHex: String?
    var summary: String

    var reportLine: String {
        String(
            format: "%7.3fs  %-4@  %-36@  %-24@  %@",
            elapsedSeconds,
            kind.rawValue,
            source,
            payloadHex ?? "-",
            summary
        )
    }
}

enum ScaleDeviceSettingsState: Equatable {
    case idle
    case locating
    case connecting
    case discovering
    case ready
    case failed(String)

    func title(in language: AppLanguage) -> String {
        switch self {
        case .idle: language.text("尚未检测")
        case .locating: language.text("正在寻找设备")
        case .connecting: language.text("正在连接")
        case .discovering: language.text("正在读取设备能力")
        case .ready: language.text("设备能力已更新")
        case .failed(let message): language.text(message)
        }
    }

    var isBusy: Bool {
        switch self {
        case .locating, .connecting, .discovering: true
        default: false
        }
    }
}

@MainActor
final class BLEScaleManager: NSObject, ObservableObject {
    private enum ScanPurpose { case adding, measuring, configuring(UUID) }
    private enum SettingsOperation {
        case unit(XiaomiScaleHardwareUnit)
        case currentTime
    }
    private enum DiagnosticPayloadKind {
        case xiaomiAdvertisement
        case standardWeight
        case standardBodyComposition
        case icomonAFU
    }
    enum State: Equatable {
        case idle, unavailable(String), scanning, connecting(String), connected(String), measuring, stabilizing, completed

        func title(in language: AppLanguage) -> String {
            switch self {
            case .idle: language.text("准备连接")
            case .unavailable(let reason): language.text(reason)
            case .scanning: language.text("正在等待已关联的设备")
            case .connecting(let name): language.format("正在连接 %@", name)
            case .connected(let name): language.format("已连接 %@", name)
            case .measuring: language.text("已感知到体重，正在测量")
            case .stabilizing: language.text("读数正在稳定，请保持站立")
            case .completed: language.text("测量完成，最终值已保存")
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var devices: [DiscoveredScale] = []
    @Published private(set) var latestMeasurement: BodyMeasurement?
    @Published private(set) var liveWeightKG: Double?
    @Published private(set) var settingsState: ScaleDeviceSettingsState = .idle
    @Published private(set) var settingsSnapshot = ScaleDeviceSettingsSnapshot()
    @Published private(set) var settingsOperationMessage: String?
    @Published private(set) var settingsOperationSucceeded = false
    @Published private(set) var historyState: ScaleHistoryState = .unavailable
    @Published private(set) var isDeviceDiagnosticCaptureEnabled = false
    @Published private(set) var deviceDiagnosticEvents: [DeviceDiagnosticEvent] = []

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
    private var pairedScaleIDs: Set<UUID> = []
    private var pairedScaleNames: [UUID: String] = [:]
    private var pairedScaleModelNames: [UUID: String] = [:]
    private var pairedScaleRuleIDs: [UUID: String] = [:]
    private var communicationRulesByID: [String: CommunicationRule] = [:]
    private var activeScaleID: UUID?
    private var activeScaleName: String?
    private var settingsScaleID: UUID?
    private var settingsConfigurationCharacteristic: CBCharacteristic?
    private var settingsCurrentTimeCharacteristic: CBCharacteristic?
    private var settingsHistoryCharacteristic: CBCharacteristic?
    private var xiaomiHistorySession: XiaomiScaleHistorySession?
    private var declarativeHistorySession: DeclarativeHistoryOperationSession?
    private var activeHistoryOperation: CommunicationGATTOperation?
    private var activeHistorySessionToken: UInt16?
    private var activeHistoryCompletionResponse: Data?
    private var pendingHistorySubscriptions = Set<String>()
    private var settingsCharacteristicsByTarget: [String: CBCharacteristic] = [:]
    private var historyTimeoutTask: Task<Void, Never>?
    private var pendingSettingsServiceIDs: Set<ObjectIdentifier> = []
    private var pendingSettingsOperation: SettingsOperation?
    private var deviceDiagnosticCaptureStartedAt: Date?
    private var scanRequested = false
    private var discoverySequence = 0
    private var didCompleteIcomonFinal = false

    private static let weightService = CBUUID(string: "181D")
    private static let bodyService = CBUUID(string: "181B")
    private static let weightMeasurement = CBUUID(string: "2A9D")
    private static let bodyMeasurement = CBUUID(string: "2A9C")
    private static let icomonService = CBUUID(string: IcomonAFUScaleAdapter.serviceUUID)
    private static let icomonMeasurement = CBUUID(string: IcomonAFUScaleAdapter.measurementCharacteristicUUID)
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
    private static let xiaomiHistory = CBUUID(
        string: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID
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

    func startMeasurementMonitoring(scales: [PairedScale]) {
        pairedScaleIDs = Set(scales.map(\.id))
        pairedScaleNames = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.name) })
        pairedScaleModelNames = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.modelName) })
        pairedScaleRuleIDs = Dictionary(uniqueKeysWithValues: scales.compactMap { scale in
            scale.communicationRuleID.map { (scale.id, $0) }
        })
        scanPurpose = .measuring
        liveWeightKG = nil
        latestMeasurement = nil
        pendingBodyComposition = nil
        measurementSession.reset()
        isWaitingForNextLoad = false
        minimumWeightAfterCompletionKG = nil
        didCompleteIcomonFinal = false
        guard !scales.isEmpty else {
            scanRequested = false
            central.stopScan()
            state = .idle
            return
        }
        beginScanning(clearDevices: false)
        connectKnownStandardScale(from: scales)
    }

    func updatePairedScales(
        _ scales: [PairedScale],
        communicationRules: [CommunicationRule] = CommunicationRuleCatalog.builtIn
    ) {
        pairedScaleIDs = Set(scales.map(\.id))
        pairedScaleNames = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.name) })
        pairedScaleModelNames = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.modelName) })
        pairedScaleRuleIDs = Dictionary(uniqueKeysWithValues: scales.compactMap { scale in
            scale.communicationRuleID.map { (scale.id, $0) }
        })
        communicationRulesByID = Dictionary(uniqueKeysWithValues: communicationRules.map { ($0.id, $0) })
        if let activeScaleID, let scale = scales.first(where: { $0.id == activeScaleID }) {
            activeScaleName = scale.name
        }
    }

    private func selectedRule(for deviceID: UUID) -> CommunicationRule? {
        pairedScaleRuleIDs[deviceID].flatMap { communicationRulesByID[$0] }
    }

    private func allowsBuiltInParser(_ parser: String, for deviceID: UUID) -> Bool {
        guard let selected = selectedRule(for: deviceID) else { return true }
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
                deviceName: pairedScaleNames[deviceID]
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

    func inspectSettings(for scale: PairedScale) {
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

    private func resetSettingsInspection(for scale: PairedScale) {
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        settingsScaleID = scale.id
        settingsSnapshot = ScaleDeviceSettingsSnapshot()
        historyState = .unavailable
        settingsHistoryCharacteristic = nil
        xiaomiHistorySession = nil
        declarativeHistorySession = nil
        activeHistoryOperation = nil
        activeHistorySessionToken = nil
        activeHistoryCompletionResponse = nil
        pendingHistorySubscriptions.removeAll()
        settingsCharacteristicsByTarget.removeAll()
        historyTimeoutTask?.cancel()
        settingsOperationMessage = nil
        settingsOperationSucceeded = false
        if !isDeviceDiagnosticCaptureEnabled {
            deviceDiagnosticEvents.removeAll(keepingCapacity: true)
            deviceDiagnosticCaptureStartedAt = nil
        }
        settingsState = .locating
        scanPurpose = .configuring(scale.id)
    }

    func endSettingsInspection() {
        connectionTimeoutTask?.cancel()
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        pendingSettingsOperation = nil
        settingsConfigurationCharacteristic = nil
        settingsCurrentTimeCharacteristic = nil
        settingsHistoryCharacteristic = nil
        xiaomiHistorySession = nil
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
        isDeviceDiagnosticCaptureEnabled = false
        deviceDiagnosticCaptureStartedAt = nil
        settingsState = .idle
    }

    func makeDeviceDiagnosticReport() async -> String {
        let services = settingsSnapshot.discoveredServiceUUIDs.joined(separator: ", ")
        let device = settingsScaleID?.uuidString ?? "-"
        let events = deviceDiagnosticEvents

        return await Task.detached(priority: .userInitiated) {
            let header = "ScaleMe device diagnostic capture\ndevice: \(device)\nservices: \(services)\nelapsed  type  source                                payload                   summary\n"
            return header + events.map(\.reportLine).joined(separator: "\n")
        }.value
    }

    func startDeviceDiagnosticCapture(for scale: PairedScale) {
        deviceDiagnosticEvents.removeAll(keepingCapacity: true)
        deviceDiagnosticCaptureStartedAt = .now
        isDeviceDiagnosticCaptureEnabled = true
        inspectSettings(for: scale)
        appendDiagnosticEvent(kind: .service, source: "SESSION", summary: "开始采集目标设备 \(scale.name)")
        beginScanning(clearDevices: false)
    }

    func stopDeviceDiagnosticCapture() {
        appendDiagnosticEvent(kind: .service, source: "SESSION", summary: "停止采集")
        isDeviceDiagnosticCaptureEnabled = false
        if connected?.identifier == settingsScaleID {
            scanRequested = false
            central.stopScan()
        }
    }

    func configureHardwareUnit(_ unit: XiaomiScaleHardwareUnit) {
        guard let connected,
              connected.identifier == settingsScaleID,
              let characteristic = settingsConfigurationCharacteristic,
              characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            settingsOperationSucceeded = false
            settingsOperationMessage = "当前连接未发现可写的小米二代单位特征"
            return
        }
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        settingsReadbackTask?.cancel()
        settingsReadbackTask = nil
        pendingSettingsOperation = .unit(unit)
        settingsOperationSucceeded = false
        settingsOperationMessage = "正在写入秤端单位"
        let command = XiaomiScaleConfigurationProtocol.unitCommand(unit)
        captureCharacteristicEvent(
            direction: .write,
            characteristic: characteristic,
            payload: command,
            summary: "设置单位：\(unit.title)；类型：\(writeType == .withResponse ? "有响应" : "无响应")"
        )
        connected.writeValue(command, for: characteristic, type: writeType)
        if writeType == .withoutResponse {
            verifySettingsWrite(on: connected, characteristic: characteristic, wasAcknowledged: false)
        }
    }

    func synchronizeScaleTime() {
        guard let connected,
              connected.identifier == settingsScaleID,
              let characteristic = settingsCurrentTimeCharacteristic,
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

    func readDeviceHistory() {
        if let scaleID = settingsScaleID,
           let operation = selectedRule(for: scaleID)?.operations?.historyRead,
           operation.historyResponse?.builtInParser == nil {
            readDeclarativeHistory(operation)
        } else {
            readXiaomiHistory()
        }
    }

    private func readXiaomiHistory() {
        guard let connected,
              connected.identifier == settingsScaleID,
              let characteristic = settingsHistoryCharacteristic,
              characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate),
              characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            historyState = .failed("当前连接未发现可读写的小米历史特征")
            return
        }
        xiaomiHistorySession = XiaomiScaleHistorySession()
        declarativeHistorySession = nil
        activeHistoryOperation = nil
        historyState = .reading(received: 0, announced: nil)
        historyTimeoutTask?.cancel()
        historyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, case .reading = self.historyState else { return }
            self.xiaomiHistorySession = nil
            self.historyState = .failed("读取历史超时，请唤醒秤后重试")
        }
        if characteristic.isNotifying {
            sendXiaomiHistoryRequest(on: connected, characteristic: characteristic)
        } else {
            connected.setNotifyValue(true, for: characteristic)
        }
    }

    func importPendingHistory(into store: MeasurementStore) {
        guard case .awaitingImport(let measurements) = historyState,
              let connected else { return }
        let imported = store.importDeviceHistory(measurements)
        if let operation = activeHistoryOperation {
            write(operation.acknowledgementCommands, on: connected, response: activeHistoryCompletionResponse)
        } else if let characteristic = settingsHistoryCharacteristic {
            writeHistoryCommand(XiaomiScaleHistoryProtocol.acknowledgeRecent, on: connected, characteristic: characteristic)
        }
        historyState = .imported(imported)
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
                }
            }) else {
                historyState = .failed("规则声明的服务或特征与当前设备不匹配")
                return
            }
            declarativeHistorySession = try DeclarativeHistoryOperationSession(operation: operation)
            xiaomiHistorySession = nil
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
            let type: CBCharacteristicWriteType = command.writeMode == .withResponse ? .withResponse : .withoutResponse
            captureCharacteristicEvent(direction: .write, characteristic: characteristic, payload: payload, summary: "外部协议历史命令")
            peripheral.writeValue(payload, for: characteristic, type: type)
        }
    }

    private func targetKey(_ target: CommunicationGATTTarget) -> String {
        "\(CommunicationRuleCodec.normalizeUUID(target.serviceUUID))|\(CommunicationRuleCodec.normalizeUUID(target.characteristicUUID))"
    }

    private func sendXiaomiHistoryRequest(on peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        writeHistoryCommand(XiaomiScaleHistoryProtocol.enableHistory, on: peripheral, characteristic: characteristic)
        writeHistoryCommand(XiaomiScaleHistoryProtocol.requestRecent, on: peripheral, characteristic: characteristic)
        writeHistoryCommand(XiaomiScaleHistoryProtocol.startTransfer, on: peripheral, characteristic: characteristic)
    }

    private func writeHistoryCommand(_ data: Data, on peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        captureCharacteristicEvent(direction: .write, characteristic: characteristic, payload: data, summary: "历史操作命令")
        peripheral.writeValue(data, for: characteristic, type: type)
    }

    private func consumeXiaomiHistory(_ data: Data, peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard var session = xiaomiHistorySession else { return }
        do {
            guard let event = try session.consume(data) else {
                xiaomiHistorySession = session
                return
            }
            xiaomiHistorySession = session
            switch event {
            case .progress(let received, let announced):
                historyState = .reading(received: received, announced: announced)
            case .completed(let measurements):
                historyTimeoutTask?.cancel()
                xiaomiHistorySession = nil
                writeHistoryCommand(XiaomiScaleHistoryProtocol.stop, on: peripheral, characteristic: characteristic)
                let attributed = measurements.map { value -> BodyMeasurement in
                    var result = value
                    result.deviceID = peripheral.identifier
                    result.deviceName = pairedScaleNames[peripheral.identifier] ?? peripheral.name
                    return result
                }
                historyState = .awaitingImport(attributed)
            }
        } catch {
            historyTimeoutTask?.cancel()
            xiaomiHistorySession = nil
            historyState = .failed("历史数据格式无效或超过安全上限")
        }
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
        guard target == response.recordMatcher.target || target == response.completionMatcher.target else { return false }
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
                    result.deviceName = pairedScaleNames[peripheral.identifier] ?? peripheral.name
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
        guard isDeviceDiagnosticCaptureEnabled, let deviceDiagnosticCaptureStartedAt else { return }
        deviceDiagnosticEvents.append(DeviceDiagnosticEvent(
            elapsedSeconds: receivedAt.timeIntervalSince(deviceDiagnosticCaptureStartedAt),
            kind: kind,
            source: source,
            payloadHex: payload.map(Self.hexString),
            summary: summary
        ))
        if deviceDiagnosticEvents.count > 500 {
            deviceDiagnosticEvents.removeFirst(deviceDiagnosticEvents.count - 500)
        }
    }

    func connect(_ device: DiscoveredScale) {
        connectionTimeoutTask?.cancel()
        central.stopScan()
        connected = device.peripheral
        activeScaleID = device.id
        activeScaleName = pairedScaleNames[device.id] ?? device.name
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
            state = .measuring
        case .stabilizing:
            state = .stabilizing
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
            case .icomonAFU:
                let packet = try IcomonAFUScaleParser.parse(payload, now: receivedAt)
                summary = String(
                    format: "phase=%@ weight=%.5fkg impedance=%@ secondaryImpedance=%@",
                    packet.phase.rawValue,
                    packet.measurement.weightKG,
                    packet.measurement.impedanceOhm.map { String(format: "%.0f", $0) } ?? "-",
                    packet.measurement.secondaryImpedanceOhm.map { String(format: "%.0f", $0) } ?? "-"
                )
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
        if let manufacturerData = data[CBAdvertisementDataManufacturerDataKey] as? Data {
            let protocolSummary: String
            if let match = ScaleBroadcastProtocolCatalog.parse(
                name: name,
                manufacturerData: manufacturerData,
                advertisedServiceUUIDs: Set(advertisedServices.map(\.uuidString)),
                now: receivedAt
            ) {
                protocolSummary = String(
                    format: "%@ weight=%.3fkg stable=%@",
                    match.family.rawValue,
                    match.measurement.weightKG,
                    match.measurement.isStable ? "1" : "0"
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
            let summary = uuid == Self.bodyService
                ? diagnosticSummary(payload, kind: .xiaomiAdvertisement, receivedAt: receivedAt)
                : "服务数据"
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

    private func connectKnownStandardScale(from scales: [PairedScale]) {
        guard central.state == .poweredOn,
              connected == nil,
              let scale = scales.first(where: {
                  $0.compatibility == "Bluetooth SIG 标准"
                      || selectedRule(for: $0.id)?.match.transport == .characteristicNotification
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

    private func broadcastReliability(
        for family: ScaleBroadcastProtocolFamily
    ) -> MeasurementSampleReliability {
        // Sinocare has no protocol-level stable bit and is finalized by repeated
        // readings. Other built-in broadcast families expose an explicit stable
        // or final state, which generic convergence must not replace.
        family == .sinocare ? .requiresStability : .protocolStable
    }

    private func discoveryAdvertisement(
        name: String,
        advertisement: [String: Any],
        hasVerifiedXiaomiPayload: Bool,
        verifiedBroadcastProtocol: ScaleBroadcastProtocolFamily?
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
            hasVerifiedIcomonAFUIdentity: IcomonAFUScaleAdapter.matchesIdentity(
                name: name,
                advertisedServiceUUIDs: Set(advertisedServices.map(\.uuidString))
            ),
            verifiedBroadcastProtocol: verifiedBroadcastProtocol
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

extension BLEScaleManager: CBCentralManagerDelegate {
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
            let advertisedServiceUUIDs = Set([
                CBAdvertisementDataServiceUUIDsKey,
                CBAdvertisementDataOverflowServiceUUIDsKey,
                CBAdvertisementDataSolicitedServiceUUIDsKey
            ].flatMap { advertisementData[$0] as? [CBUUID] ?? [] }.map(\.uuidString))
            let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
            let broadcastMatch = manufacturerData.flatMap {
                ScaleBroadcastProtocolCatalog.parse(
                    name: name,
                    manufacturerData: $0,
                    advertisedServiceUUIDs: advertisedServiceUUIDs,
                    now: receivedAt
                )
            }
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
            let xiaomiPayload = serviceData?[Self.bodyService]
            let hasVerifiedXiaomiPayload = xiaomiPayload.flatMap {
                try? XiaomiScaleParser.parsePacket($0, now: receivedAt)
            } != nil
            if case .measuring = scanPurpose,
               pairedScaleIDs.contains(peripheral.identifier) {
                if let broadcastMatch,
                   allowsBuiltInParser(broadcastMatch.family.builtInParserID, for: peripheral.identifier) {
                    consume(
                        broadcastMatch.measurement,
                        reliability: broadcastReliability(for: broadcastMatch.family),
                        deviceID: peripheral.identifier,
                        deviceName: pairedScaleNames[peripheral.identifier] ?? peripheral.name
                    )
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
                            deviceName: pairedScaleNames[peripheral.identifier] ?? peripheral.name
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
                connectForSettings(peripheral, name: pairedScaleNames[scaleID] ?? name)
                return
            }
            let discovery = discoveryAdvertisement(
                name: pairedScaleModelNames[peripheral.identifier] ?? name,
                advertisement: advertisementData,
                hasVerifiedXiaomiPayload: hasVerifiedXiaomiPayload,
                verifiedBroadcastProtocol: broadcastMatch?.family
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
               pairedScaleIDs.contains(peripheral.identifier),
               connected?.identifier != peripheral.identifier,
               (item.isVerifiedCompatible
                    || selectedRule(for: peripheral.identifier)?.match.transport == .characteristicNotification),
               broadcastMatch == nil,
               (!hasVerifiedXiaomiPayload
                    || selectedRule(for: peripheral.identifier)?.match.transport == .characteristicNotification) {
                connect(item)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            if settingsScaleID == peripheral.identifier {
                appendDiagnosticEvent(kind: .service, source: "CONNECTION", summary: "设备已连接")
            }
            state = .connected(peripheral.name ?? "体重秤")
            if settingsScaleID == peripheral.identifier {
                settingsState = .discovering
                armSettingsTimeout(for: peripheral.identifier)
                peripheral.discoverServices(nil)
            } else {
                let selected = selectedRule(for: peripheral.identifier)
                if selected?.isDeclarative == true {
                    peripheral.discoverServices(nil)
                } else {
                    peripheral.discoverServices([Self.weightService, Self.bodyService, Self.icomonService])
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            connected = nil
            if settingsScaleID == peripheral.identifier {
                appendDiagnosticEvent(
                    kind: .error,
                    source: "CONNECTION",
                    summary: "连接失败：\(error?.localizedDescription ?? "未知错误")"
                )
                settingsState = .failed(error?.localizedDescription ?? "无法连接设备，请唤醒秤后重试")
            } else if case .measuring = scanPurpose, !pairedScaleIDs.isEmpty {
                beginScanning(clearDevices: false)
            } else {
                state = .unavailable(error?.localizedDescription ?? "连接失败，请重试")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            connected = nil
            activeScaleID = nil
            activeScaleName = nil
            if settingsScaleID == peripheral.identifier {
                appendDiagnosticEvent(
                    kind: error == nil ? .service : .error,
                    source: "CONNECTION",
                    summary: error.map { "连接断开：\($0.localizedDescription)" } ?? "设备已断开"
                )
                if error != nil {
                    settingsState = .failed("设备连接已断开")
                }
            } else if case .measuring = scanPurpose, !pairedScaleIDs.isEmpty {
                beginScanning(clearDevices: false)
            } else {
                state = error == nil ? .idle : .unavailable("连接已断开")
            }
        }
    }
}

extension BLEScaleManager: CBPeripheralDelegate {
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
            for characteristic in service.characteristics ?? [] {
                let isDiagnosticTarget = settingsScaleID == peripheral.identifier
                    && isDeviceDiagnosticCaptureEnabled
                if characteristic.uuid == Self.weightMeasurement
                    || characteristic.uuid == Self.bodyMeasurement
                    || characteristic.uuid == Self.icomonMeasurement
                    || customRule(
                        for: peripheral.identifier,
                        transport: .characteristicNotification,
                        serviceUUID: service.uuid.uuidString,
                        characteristicUUID: characteristic.uuid.uuidString
                    ) != nil
                    || isDiagnosticTarget && (characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)) {
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
                    settingsState = .ready
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
            if settingsScaleID == peripheral.identifier {
                captureCharacteristicEvent(
                    direction: characteristic.isNotifying ? .notification : .received,
                    characteristic: characteristic,
                    payload: data,
                    summary: diagnosticValueSummary(data, characteristic: characteristic)
                )
                consumeSettingsValue(data, from: characteristic)
                if consumeDeclarativeHistory(data, peripheral: peripheral, characteristic: characteristic) {
                    return
                }
                if characteristic.uuid == Self.xiaomiHistory {
                    consumeXiaomiHistory(data, peripheral: peripheral, characteristic: characteristic)
                    return
                }
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

            if characteristic.uuid == Self.icomonMeasurement,
               allowsBuiltInParser("icomonAFU", for: peripheral.identifier),
               let packet = try? IcomonAFUScaleParser.parse(data) {
                guard case .measuring = scanPurpose else { return }
                switch packet.phase {
                case .live:
                    if didCompleteIcomonFinal {
                        measurementSession.reset()
                        didCompleteIcomonFinal = false
                    }
                    liveWeightKG = packet.measurement.weightKG
                    state = .measuring
                case .stable:
                    guard !didCompleteIcomonFinal else { return }
                    liveWeightKG = packet.measurement.weightKG
                    state = .stabilizing
                case .final:
                    guard !didCompleteIcomonFinal else { return }
                    didCompleteIcomonFinal = true
                    consume(packet.measurement, reliability: .protocolFinal)
                }
            } else if characteristic.uuid == Self.weightMeasurement,
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
                if characteristic.uuid == Self.xiaomiHistory,
                   characteristic.isNotifying,
                   case .reading = historyState {
                    sendXiaomiHistoryRequest(on: peripheral, characteristic: characteristic)
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
            guard settingsScaleID == peripheral.identifier,
                  characteristic.uuid == Self.xiaomiConfiguration || characteristic.uuid == Self.currentTime else { return }
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
                settingsConfigurationCharacteristic = characteristic
                settingsSnapshot.canConfigureXiaomiUnit = isWritable
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
        case Self.xiaomiHistory:
            let canNotify = characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
            settingsSnapshot.hasHistoryChannel = canNotify && isWritable
            if settingsSnapshot.hasHistoryChannel {
                settingsHistoryCharacteristic = characteristic
                historyState = .ready
            }
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
        if characteristic.uuid == Self.weightMeasurement {
            return diagnosticSummary(data, kind: .standardWeight, receivedAt: .now)
        }
        if characteristic.uuid == Self.bodyMeasurement {
            return diagnosticSummary(data, kind: .standardBodyComposition, receivedAt: .now)
        }
        if characteristic.uuid == Self.icomonMeasurement {
            return diagnosticSummary(data, kind: .icomonAFU, receivedAt: .now)
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
