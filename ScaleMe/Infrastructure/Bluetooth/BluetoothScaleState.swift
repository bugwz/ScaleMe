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
    case empty
    case awaitingImport([BodyMeasurement])
    case imported(DeviceHistoryImportSummary)
    case clearCommandSent
    case failed(String)
}

struct AutomaticallyRetrievedHistory: Identifiable, Equatable {
    let id = UUID()
    var measurements: [BodyMeasurement]
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

enum BluetoothScaleState: Equatable {
    case idle, unavailable(String), scanning, connecting(String), connected(String)
    case measuringWeight, measuringBodyComposition, confirmingMeasurement, completed

    func title(in language: AppLanguage) -> String {
        switch self {
        case .idle: language.text("准备连接")
        case .unavailable(let reason): language.text(reason)
        case .scanning: language.text("正在等待已关联的设备")
        case .connecting(let name): language.format("正在连接 %@", name)
        case .connected(let name): language.format("已连接 %@", name)
        case .measuringWeight: language.text("正在测量体重，请保持站立")
        case .measuringBodyComposition: language.text("体重测量完成，正在测量身体成分，请保持站立")
        case .confirmingMeasurement: language.text("正在确认测量结果，请保持站立")
        case .completed: language.text("测量完成，最终值已保存")
        }
    }
}
