import CoreBluetooth
import Foundation

struct DiscoveredScale: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int
    var compatibility: String
    var peripheral: CBPeripheral

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.rssi == rhs.rssi }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
final class BLEScaleManager: NSObject, ObservableObject {
    enum State: Equatable {
        case idle, unavailable(String), scanning, connecting(String), connected(String), measuring

        var title: String {
            switch self {
            case .idle: "准备连接"
            case .unavailable(let reason): reason
            case .scanning: "正在寻找附近的秤"
            case .connecting(let name): "正在连接 \(name)"
            case .connected(let name): "已连接 \(name)"
            case .measuring: "正在读取，请保持站立"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var devices: [DiscoveredScale] = []
    @Published private(set) var latestMeasurement: BodyMeasurement?
    @Published private(set) var liveWeightKG: Double?

    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    private var pendingBodyComposition: BodyMeasurement?

    private static let weightService = CBUUID(string: "181D")
    private static let bodyService = CBUUID(string: "181B")
    private static let weightMeasurement = CBUUID(string: "2A9D")
    private static let bodyMeasurement = CBUUID(string: "2A9C")

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard central.state == .poweredOn else {
            state = .unavailable(bluetoothStateText(central.state)); return
        }
        devices.removeAll()
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
        central.stopScan()
        connected = device.peripheral
        device.peripheral.delegate = self
        state = .connecting(device.name)
        central.connect(device.peripheral)
    }

    func disconnect() {
        if let connected { central.cancelPeripheralConnection(connected) }
        connected = nil
        state = .idle
    }

    private func consume(_ measurement: BodyMeasurement) {
        liveWeightKG = measurement.weightKG
        state = .measuring
        guard measurement.isStable else { return }
        latestMeasurement = measurement
        state = .connected(connected?.name ?? measurement.source.rawValue)
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
        let services = (advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        if services.contains(Self.weightService) || services.contains(Self.bodyService) { return "Bluetooth SIG 标准" }
        return "可发现 · 协议待验证"
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
            if let payload = serviceData?[Self.bodyService], let measurement = try? XiaomiScaleParser.parse(payload) {
                consume(measurement)
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
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            state = .connected(peripheral.name ?? "体重秤")
            peripheral.discoverServices([Self.weightService, Self.bodyService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in state = .unavailable(error?.localizedDescription ?? "连接失败，请重试") }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connected = nil
            state = error == nil ? .idle : .unavailable("连接已断开")
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
            if characteristic.uuid == Self.weightMeasurement, let value = try? StandardWeightScaleParser.parse(data) {
                if let body = pendingBodyComposition, abs(body.date.timeIntervalSinceNow) < 20 {
                    var merged = body; merged.weightKG = value.weightKG; consume(merged)
                } else { consume(value) }
            } else if characteristic.uuid == Self.bodyMeasurement, let value = try? StandardBodyCompositionParser.parse(data) {
                pendingBodyComposition = value; consume(value)
            }
        }
    }
}
