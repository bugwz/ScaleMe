import Foundation

/// Capabilities are implemented independently. A protocol family only exposes
/// the capabilities for which it has an executable implementation.
enum ScaleProtocolCapability: String, Codable, CaseIterable, Hashable {
    case liveMeasurement
    case weightRemoval
    case historyRead
    case historyClear
    case hardwareUnitConfiguration
    case timeSynchronization
    case authentication
}

enum ScaleProtocolStabilityPolicy: Equatable {
    case protocolReported
    case repeatedSamples
}

struct ScaleProtocolDescriptor: Equatable {
    var id: String
    var name: String
    var parserID: String
    var transport: CommunicationTransport
    var discoveryCompatibility: ScaleDiscoveryCompatibility
    var capabilities: Set<ScaleProtocolCapability>
    var stabilityPolicy: ScaleProtocolStabilityPolicy = .protocolReported
}

struct ScaleAdvertisementInput {
    var name: String
    var manufacturerData: Data?
    var advertisedServiceUUIDs: Set<String>
    var serviceData: [String: Data]
    var receivedAt: Date

    init(
        name: String,
        manufacturerData: Data? = nil,
        advertisedServiceUUIDs: Set<String> = [],
        serviceData: [String: Data] = [:],
        receivedAt: Date = .now
    ) {
        self.name = name
        self.manufacturerData = manufacturerData
        self.advertisedServiceUUIDs = advertisedServiceUUIDs
        self.serviceData = Dictionary(uniqueKeysWithValues: serviceData.map {
            (CommunicationRuleCodec.normalizeUUID($0.key), $0.value)
        })
        self.receivedAt = receivedAt
    }
}

enum ScaleProtocolPacket {
    case measurement(BodyMeasurement)
    case weightRemoved
}

enum ScaleProtocolLivePhase: Equatable {
    case measuringWeight
    case measuringBodyComposition
}

enum ScaleProtocolLoadCyclePolicy: Equatable {
    case coordinatorManaged
    case protocolManaged
}

enum ScaleProtocolMeasurementReliability {
    case requiresStability
    case protocolStable
    case protocolFinal
}

struct ScaleProtocolMatch {
    var descriptor: ScaleProtocolDescriptor
    var packet: ScaleProtocolPacket
}

/// Stateless advertisement protocols conform directly on their parser type.
/// Connected protocols can additionally provide one or more optional capability
/// interfaces below without adding no-op methods to this base contract.
protocol ScaleAdvertisementProtocolAdapter {
    static var descriptor: ScaleProtocolDescriptor { get }
    static func decodeAdvertisement(_ input: ScaleAdvertisementInput) throws -> ScaleProtocolPacket
}

struct ScaleHistoryReadConfiguration: Equatable {
    var timeoutSeconds: Double
    var maximumResponseBytes: Int
    var maximumRecords: Int
}

protocol ScaleHistoryCapability: AnyObject {
    func startHistoryRead(
        configuration: ScaleHistoryReadConfiguration
    ) throws -> [ScaleProtocolAction]
}

protocol ScaleHistoryImportConfirmationCapability: AnyObject {
    func confirmHistoryImport() throws -> [ScaleProtocolAction]
}

protocol ScaleUnitConfigurationCapability: AnyObject {
    var supportedHardwareUnits: Set<CommunicationWeightUnit> { get }
    var hardwareUnitConfigurationTarget: CommunicationGATTTarget { get }
    func configureHardwareUnit(_ unit: CommunicationWeightUnit) throws -> [ScaleProtocolAction]
}

protocol ScaleTimeSynchronizationCapability: AnyObject {
    var timeSynchronizationTarget: CommunicationGATTTarget { get }
    func synchronizeTime(_ date: Date) throws -> [ScaleProtocolAction]
}

enum ScaleProtocolEvent {
    case connected
    case disconnected
    case servicesDiscovered(Set<String>)
    case characteristicsDiscovered(serviceUUID: String, characteristicUUIDs: Set<String>)
    case notification(serviceUUID: String, characteristicUUID: String, payload: Data, receivedAt: Date)
    case notificationStateChanged(serviceUUID: String, characteristicUUID: String, isNotifying: Bool, changedAt: Date)
    case writeCompleted(serviceUUID: String, characteristicUUID: String, succeeded: Bool)
    case timer(String)
}

enum ScaleProtocolAction {
    case discoverServices(Set<String>)
    case discoverCharacteristics(serviceUUID: String, characteristicUUIDs: Set<String>)
    case subscribe(CommunicationGATTTarget)
    case write(CommunicationCommand)
    case reportLiveMeasurement(
        BodyMeasurement,
        phase: ScaleProtocolLivePhase,
        loadCycle: ScaleProtocolLoadCyclePolicy
    )
    case reportLivePhase(ScaleProtocolLivePhase)
    case resetMeasurement
    case emit(ScaleProtocolPacket, reliability: ScaleProtocolMeasurementReliability)
    case reportHistoryProgress(received: Int, announced: Int?)
    case completeHistory([BodyMeasurement])
    case failHistory(ScaleProtocolHistoryFailure)
    case failSession(ScaleProtocolSessionFailure)
    case scheduleTimer(id: String, seconds: Double)
    case cancelTimer(id: String)
}

enum ScaleProtocolHistoryFailure: Equatable {
    case timeout
    case invalidPayload
    case writeFailed
}

enum ScaleProtocolSessionFailure: Equatable {
    case invalidResponse
    case writeFailed
}

protocol ScaleConnectedProtocolSession: AnyObject {
    var descriptor: ScaleProtocolDescriptor { get }
    func handle(_ event: ScaleProtocolEvent) throws -> [ScaleProtocolAction]
}

struct AnyScaleAdvertisementProtocolAdapter {
    let descriptor: ScaleProtocolDescriptor
    private let decode: (ScaleAdvertisementInput) throws -> ScaleProtocolPacket

    init<Adapter: ScaleAdvertisementProtocolAdapter>(_ adapter: Adapter.Type) {
        descriptor = adapter.descriptor
        decode = adapter.decodeAdvertisement
    }

    func decodeAdvertisement(_ input: ScaleAdvertisementInput) throws -> ScaleProtocolPacket {
        try decode(input)
    }
}

struct ScaleManufacturerPacket: Equatable {
    var companyID: UInt16
    var payload: Data

    /// CoreBluetooth includes the little-endian Bluetooth Company Identifier
    /// as the first two bytes of manufacturer data.
    init?(appleManufacturerData data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }
        companyID = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        payload = Data(bytes.dropFirst(2))
    }

    init(companyID: UInt16, payload: Data) {
        self.companyID = companyID
        self.payload = payload
    }
}
