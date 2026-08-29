import CoreBluetooth
import Foundation

struct DiscoveredScale: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int
    var compatibility: String
    var peripheral: CBPeripheral

    var isVerifiedCompatible: Bool { compatibility != "协议待验证" }

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

@MainActor
final class BLEScaleManager: NSObject, ObservableObject {
    private enum ScanPurpose { case adding, measuring }
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

    var currentScaleName: String? { activeScaleName }

    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    private var pendingBodyComposition: BodyMeasurement?
    private var measurementSession = MeasurementSession()
    private var connectionTimeoutTask: Task<Void, Never>?
    private var diagnosticCaptureStartedAt: Date?
    private var isWaitingForNextLoad = false
    private var minimumWeightAfterCompletionKG: Double?
    private var scanPurpose: ScanPurpose = .adding
    private var pairedScaleIDs: Set<UUID> = []
    private var pairedScaleNames: [UUID: String] = [:]
    private var activeScaleID: UUID?
    private var activeScaleName: String?

    private static let weightService = CBUUID(string: "181D")
    private static let bodyService = CBUUID(string: "181B")
    private static let weightMeasurement = CBUUID(string: "2A9D")
    private static let bodyMeasurement = CBUUID(string: "2A9C")

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        scanPurpose = .adding
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
        central.stopScan()
        if case .scanning = state { state = .idle }
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
        if scanPurpose == .measuring {
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

    private func compatibility(name: String, advertisement: [String: Any]) -> String {
        let lower = name.lowercased()
        if lower.contains("mi scale") || lower.contains("mibody") || lower.contains("xiaomi") { return "小米广播协议" }
        let serviceData = (advertisement[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]) ?? [:]
        if serviceData[Self.bodyService] != nil { return "0x181B 广播格式" }
        let services = (advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        if services.contains(Self.weightService) || services.contains(Self.bodyService) { return "Bluetooth SIG 标准" }
        return "协议待验证"
    }
}

extension BLEScaleManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            state = central.state == .poweredOn ? .idle : .unavailable(bluetoothStateText(central.state))
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
            if let payload = serviceData?[Self.bodyService] {
                captureDiagnosticPayload(payload, kind: .xiaomiAdvertisement, receivedAt: .now)
            }
            if scanPurpose == .measuring,
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

            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "未命名蓝牙设备"
            let isLikelyScale = serviceData?[Self.bodyService] != nil
                || name.localizedCaseInsensitiveContains("scale")
                || name.localizedCaseInsensitiveContains("body")
                || name.contains("秤")
            guard isLikelyScale else { return }
            let item = DiscoveredScale(id: peripheral.identifier, name: name, rssi: RSSI.intValue, compatibility: compatibility(name: name, advertisement: advertisementData), peripheral: peripheral)
            if let index = devices.firstIndex(where: { $0.id == item.id }) { devices[index] = item }
            else { devices.append(item); devices.sort { $0.rssi > $1.rssi } }

            if scanPurpose == .measuring,
               pairedScaleIDs.contains(peripheral.identifier),
               connected?.identifier != peripheral.identifier,
               item.isVerifiedCompatible,
               serviceData?[Self.bodyService] == nil {
                connect(item)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            state = .connected(peripheral.name ?? "体重秤")
            peripheral.discoverServices([Self.weightService, Self.bodyService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTask?.cancel()
            connected = nil
            if scanPurpose == .measuring, !pairedScaleIDs.isEmpty {
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
            if scanPurpose == .measuring, !pairedScaleIDs.isEmpty {
                beginScanning(clearDevices: false)
            } else {
                state = error == nil ? .idle : .unavailable("连接已断开")
            }
        }
    }
}

extension BLEScaleManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        for service in peripheral.services ?? [] { peripheral.discoverCharacteristics(nil, for: service) }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        let weightMeasurement = CBUUID(string: "2A9D")
        let bodyMeasurement = CBUUID(string: "2A9C")
        for characteristic in service.characteristics ?? [] where characteristic.uuid == weightMeasurement || characteristic.uuid == bodyMeasurement {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        Task { @MainActor in
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
}
