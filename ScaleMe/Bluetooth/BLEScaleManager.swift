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

struct XiaomiDiagnosticSample: Identifiable {
    let id = UUID()
    var elapsedSeconds: TimeInterval
    var source: String
    var payloadHex: String
    var summary: String

    var reportLine: String {
        String(format: "%7.3fs  %-10@  %@  %@", elapsedSeconds, source, payloadHex, summary)
    }
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

struct DeviceSettingsBLEExchange: Identifiable, Equatable {
    enum Direction: String {
        case write = "写入"
        case acknowledgement = "回执"
        case read = "读取"
        case received = "返回"
        case error = "错误"
    }

    let id = UUID()
    var elapsedSeconds: TimeInterval
    var direction: Direction
    var characteristicUUID: String
    var payloadHex: String?
    var summary: String

    var reportLine: String {
        String(
            format: "%7.3fs  %-4@  %-36@  %-24@  %@",
            elapsedSeconds,
            direction.rawValue,
            characteristicUUID,
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

    var title: String {
        switch self {
        case .idle: "尚未检测"
        case .locating: "正在寻找设备"
        case .connecting: "正在连接"
        case .discovering: "正在读取设备能力"
        case .ready: "设备能力已更新"
        case .failed(let message): message
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
    }
    enum State: Equatable {
        case idle, unavailable(String), scanning, connecting(String), connected(String), measuring, stabilizing, completed

        var title: String {
            switch self {
            case .idle: "准备连接"
            case .unavailable(let reason): reason
            case .scanning: "正在等待已关联的秤"
            case .connecting(let name): "正在连接 \(name)"
            case .connected(let name): "已连接 \(name)"
            case .measuring: "已感知到体重，正在测量"
            case .stabilizing: "读数正在稳定，请保持站立"
            case .completed: "测量完成，最终值已保存"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var devices: [DiscoveredScale] = []
    @Published private(set) var latestMeasurement: BodyMeasurement?
    @Published private(set) var liveWeightKG: Double?
    @Published private(set) var isCapturingXiaomiDiagnostics = false
    @Published private(set) var xiaomiDiagnosticSamples: [XiaomiDiagnosticSample] = []
    @Published private(set) var settingsState: ScaleDeviceSettingsState = .idle
    @Published private(set) var settingsSnapshot = ScaleDeviceSettingsSnapshot()
    @Published private(set) var settingsOperationMessage: String?
    @Published private(set) var settingsOperationSucceeded = false
    @Published private(set) var isSettingsBLECaptureEnabled = false
    @Published private(set) var settingsBLEExchanges: [DeviceSettingsBLEExchange] = []

    var currentScaleName: String? { activeScaleName }

    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    private var pendingBodyComposition: BodyMeasurement?
    private var measurementSession = MeasurementSession()
    private var connectionTimeoutTask: Task<Void, Never>?
    private var settingsReadbackTask: Task<Void, Never>?
    private var diagnosticCaptureStartedAt: Date?
    private var isWaitingForNextLoad = false
    private var minimumWeightAfterCompletionKG: Double?
    private var scanPurpose: ScanPurpose = .adding
    private var pairedScaleIDs: Set<UUID> = []
    private var pairedScaleNames: [UUID: String] = [:]
    private var activeScaleID: UUID?
    private var activeScaleName: String?
    private var settingsScaleID: UUID?
    private var settingsConfigurationCharacteristic: CBCharacteristic?
    private var settingsCurrentTimeCharacteristic: CBCharacteristic?
    private var pendingSettingsServiceIDs: Set<ObjectIdentifier> = []
    private var pendingSettingsOperation: SettingsOperation?
    private var settingsCaptureStartedAt: Date?
    private var scanRequested = false
    private var discoverySequence = 0

    private static let weightService = CBUUID(string: "181D")
    private static let bodyService = CBUUID(string: "181B")
    private static let weightMeasurement = CBUUID(string: "2A9D")
    private static let bodyMeasurement = CBUUID(string: "2A9C")
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
        scanPurpose = .measuring
        liveWeightKG = nil
        latestMeasurement = nil
        pendingBodyComposition = nil
        measurementSession.reset()
        isWaitingForNextLoad = false
        minimumWeightAfterCompletionKG = nil
        guard !scales.isEmpty else {
            scanRequested = false
            central.stopScan()
            state = .idle
            return
        }
        beginScanning(clearDevices: false)
        connectKnownStandardScale(from: scales)
    }

    func updatePairedScales(_ scales: [PairedScale]) {
        pairedScaleIDs = Set(scales.map(\.id))
        pairedScaleNames = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.name) })
        if let activeScaleID, let scale = scales.first(where: { $0.id == activeScaleID }) {
            activeScaleName = scale.name
        }
    }

    func startXiaomiDiagnosticCapture() {
        xiaomiDiagnosticSamples.removeAll(keepingCapacity: true)
        diagnosticCaptureStartedAt = .now
        isCapturingXiaomiDiagnostics = true
    }

    func stopXiaomiDiagnosticCapture() {
        isCapturingXiaomiDiagnostics = false
    }

    var xiaomiDiagnosticReport: String {
        let header = "ScaleMe BLE scale diagnostic\nelapsed  source      payload  parsed\n"
        return header + xiaomiDiagnosticSamples.map(\.reportLine).joined(separator: "\n")
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
        settingsOperationMessage = nil
        settingsOperationSucceeded = false
        isSettingsBLECaptureEnabled = false
        settingsBLEExchanges.removeAll(keepingCapacity: true)
        settingsCaptureStartedAt = nil
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
        pendingSettingsServiceIDs.removeAll()
        stopScanning()
        disconnectSettingsPeripheral()
        settingsScaleID = nil
        isSettingsBLECaptureEnabled = false
        settingsCaptureStartedAt = nil
        settingsState = .idle
    }

    var settingsBLEReport: String {
        let services = settingsSnapshot.discoveredServiceUUIDs.joined(separator: ", ")
        let header = "ScaleMe device settings BLE capture\nservices: \(services)\nelapsed  type  characteristic                        payload                   summary\n"
        return header + settingsBLEExchanges.map(\.reportLine).joined(separator: "\n")
    }

    func setSettingsBLECaptureEnabled(_ isEnabled: Bool) {
        isSettingsBLECaptureEnabled = isEnabled
        if isEnabled, settingsCaptureStartedAt == nil {
            settingsCaptureStartedAt = .now
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
        captureSettingsExchange(
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
        captureSettingsExchange(
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

    private func connectForSettings(_ peripheral: CBPeripheral, name: String) {
        central.stopScan()
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
                    self.captureSettingsExchange(
                        direction: .read,
                        characteristic: characteristic,
                        summary: "等待秤端处理后读取单位配置"
                    )
                    peripheral.readValue(for: characteristic)
                    self.settingsReadbackTask = nil
                }
            } else {
                settingsOperationMessage = wasAcknowledged ? "写入回执成功，正在读回分析" : "命令已发送，正在读回分析"
                captureSettingsExchange(
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

    private func captureSettingsExchange(
        direction: DeviceSettingsBLEExchange.Direction,
        characteristic: CBCharacteristic,
        payload: Data? = nil,
        summary: String
    ) {
        guard isSettingsBLECaptureEnabled, let settingsCaptureStartedAt else { return }
        settingsBLEExchanges.append(DeviceSettingsBLEExchange(
            elapsedSeconds: Date.now.timeIntervalSince(settingsCaptureStartedAt),
            direction: direction,
            characteristicUUID: characteristic.uuid.uuidString.uppercased(),
            payloadHex: payload.map { $0.map { String(format: "%02X", $0) }.joined() },
            summary: summary
        ))
        if settingsBLEExchanges.count > 200 {
            settingsBLEExchanges.removeFirst(settingsBLEExchanges.count - 200)
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

    private func captureDiagnosticPayload(
        _ payload: Data,
        kind: DiagnosticPayloadKind,
        receivedAt: Date
    ) {
        guard isCapturingXiaomiDiagnostics, let diagnosticCaptureStartedAt else { return }
        let source = switch kind {
        case .xiaomiAdvertisement: "ADV-181B"
        case .standardWeight: "GATT-2A9D"
        case .standardBodyComposition: "GATT-2A9C"
        }
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
            }
        } catch {
            summary = "rejected=\(error.localizedDescription)"
        }
        xiaomiDiagnosticSamples.append(XiaomiDiagnosticSample(
            elapsedSeconds: receivedAt.timeIntervalSince(diagnosticCaptureStartedAt),
            source: source,
            payloadHex: payload.map { String(format: "%02X", $0) }.joined(),
            summary: summary
        ))
        if xiaomiDiagnosticSamples.count > 300 {
            xiaomiDiagnosticSamples.removeFirst(xiaomiDiagnosticSamples.count - 300)
        }
    }

    private func connectKnownStandardScale(from scales: [PairedScale]) {
        guard central.state == .poweredOn,
              connected == nil,
              let scale = scales.first(where: { $0.compatibility == "Bluetooth SIG 标准" }) else { return }
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

    private func discoveryAdvertisement(
        name: String,
        advertisement: [String: Any],
        hasVerifiedXiaomiPayload: Bool
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
            hasVerifiedXiaomiPayload: hasVerifiedXiaomiPayload
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
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
            let xiaomiPayload = serviceData?[Self.bodyService]
            let hasVerifiedXiaomiPayload = xiaomiPayload.flatMap {
                try? XiaomiScaleParser.parsePacket($0, now: .now)
            } != nil
            if let payload = xiaomiPayload {
                captureDiagnosticPayload(payload, kind: .xiaomiAdvertisement, receivedAt: .now)
            }
            if case .measuring = scanPurpose,
               pairedScaleIDs.contains(peripheral.identifier),
               let payload = serviceData?[Self.bodyService] {
                let receivedAt = Date.now
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

            let name = discoveredName(for: peripheral, advertisement: advertisementData)
            if case .configuring(let scaleID) = scanPurpose,
               scaleID == peripheral.identifier,
               connected?.identifier != peripheral.identifier {
                connectForSettings(peripheral, name: pairedScaleNames[scaleID] ?? name)
                return
            }
            let discovery = discoveryAdvertisement(
                name: name,
                advertisement: advertisementData,
                hasVerifiedXiaomiPayload: hasVerifiedXiaomiPayload
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
               item.isVerifiedCompatible,
               !hasVerifiedXiaomiPayload {
                connect(item)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            state = .connected(peripheral.name ?? "体重秤")
            if settingsScaleID == peripheral.identifier {
                settingsState = .discovering
                armSettingsTimeout(for: peripheral.identifier)
                peripheral.discoverServices(nil)
            } else {
                peripheral.discoverServices([Self.weightService, Self.bodyService])
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            connected = nil
            if settingsScaleID == peripheral.identifier {
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
                    settingsState = .failed(error?.localizedDescription ?? "无法读取设备服务")
                }
                return
            }
            let services = peripheral.services ?? []
            if settingsScaleID == peripheral.identifier {
                settingsSnapshot.discoveredServiceUUIDs = services
                    .map { $0.uuid.uuidString.uppercased() }
                    .sorted()
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
                    settingsState = .failed(error?.localizedDescription ?? "无法读取设备特征")
                }
                return
            }
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == Self.weightMeasurement || characteristic.uuid == Self.bodyMeasurement {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                guard settingsScaleID == peripheral.identifier else { continue }
                inspectSettingsCharacteristic(characteristic, in: service, on: peripheral)
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
                if settingsScaleID == peripheral.identifier,
                   characteristic.uuid == Self.xiaomiConfiguration || characteristic.uuid == Self.currentTime,
                   pendingSettingsOperation != nil {
                    captureSettingsExchange(
                        direction: .error,
                        characteristic: characteristic,
                        summary: "读取失败：\(error.localizedDescription)"
                    )
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
                if characteristic.uuid == Self.xiaomiConfiguration || characteristic.uuid == Self.currentTime {
                    captureSettingsExchange(
                        direction: .received,
                        characteristic: characteristic,
                        payload: data,
                        summary: settingsResponseSummary(data, characteristic: characteristic)
                    )
                }
                consumeSettingsValue(data, from: characteristic)
            }
            if characteristic.uuid == Self.weightMeasurement {
                captureDiagnosticPayload(data, kind: .standardWeight, receivedAt: .now)
            } else if characteristic.uuid == Self.bodyMeasurement {
                captureDiagnosticPayload(data, kind: .standardBodyComposition, receivedAt: .now)
            }

            if characteristic.uuid == Self.weightMeasurement,
               XiaomiGATTWeightParser.matches(data),
               let packet = try? XiaomiGATTWeightParser.parsePacket(data) {
                switch packet {
                case .measurement(let measurement):
                    consume(measurement, reliability: .protocolStable)
                case .weightRemoved:
                    weightWasRemoved()
                }
            } else if characteristic.uuid == Self.weightMeasurement, let value = try? StandardWeightScaleParser.parse(data) {
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
            } else if characteristic.uuid == Self.bodyMeasurement, let value = try? StandardBodyCompositionParser.parse(data) {
                pendingBodyComposition = value
                let reliability: MeasurementSampleReliability = characteristic.properties.contains(.indicate)
                    ? .protocolFinal
                    : .requiresStability
                consume(value, reliability: reliability)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard settingsScaleID == peripheral.identifier,
                  characteristic.uuid == Self.xiaomiConfiguration || characteristic.uuid == Self.currentTime else { return }
            if let error {
                captureSettingsExchange(
                    direction: .error,
                    characteristic: characteristic,
                    summary: "写入失败：\(error.localizedDescription)"
                )
                settingsOperationSucceeded = false
                settingsOperationMessage = "写入失败：\(error.localizedDescription)"
                pendingSettingsOperation = nil
            } else {
                captureSettingsExchange(
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
            if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
        case Self.xiaomiConfiguration:
            if service.uuid == Self.xiaomiConfigurationService {
                settingsConfigurationCharacteristic = characteristic
                settingsSnapshot.canConfigureXiaomiUnit = isWritable
                if characteristic.properties.contains(.read) {
                    captureSettingsExchange(
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
            settingsSnapshot.hasHistoryChannel = true
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

    private func settingsResponseSummary(_ data: Data, characteristic: CBCharacteristic) -> String {
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
        return "未识别响应"
    }
}
