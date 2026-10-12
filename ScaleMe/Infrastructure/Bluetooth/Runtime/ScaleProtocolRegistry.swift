import Foundation

struct ScaleProtocolRegistry {
    private let advertisementAdapters: [AnyScaleAdvertisementProtocolAdapter]
    private let connectedSessionFactories: [String: () -> any ScaleConnectedProtocolSession]
    private let connectedDescriptors: [String: ScaleProtocolDescriptor]

    init(
        advertisementAdapters: [AnyScaleAdvertisementProtocolAdapter],
        connectedDescriptors declaredConnectedDescriptors: [ScaleProtocolDescriptor] = [],
        connectedSessionFactories: [String: () -> any ScaleConnectedProtocolSession] = [:]
    ) {
        var ids = Set<String>()
        var parserIDs = Set<String>()
        precondition(advertisementAdapters.allSatisfy { ids.insert($0.descriptor.id).inserted })
        precondition(advertisementAdapters.allSatisfy { parserIDs.insert($0.descriptor.parserID).inserted })
        var connectedDescriptors: [String: ScaleProtocolDescriptor] = [:]
        for descriptor in declaredConnectedDescriptors {
            precondition(connectedDescriptors[descriptor.id] == nil)
            precondition(parserIDs.insert(descriptor.parserID).inserted)
            connectedDescriptors[descriptor.id] = descriptor
        }
        for (id, factory) in connectedSessionFactories {
            let descriptor = factory().descriptor
            precondition(id == descriptor.id)
            if let declared = connectedDescriptors[id] {
                precondition(declared == descriptor)
            } else {
                precondition(parserIDs.insert(descriptor.parserID).inserted)
            }
            connectedDescriptors[id] = descriptor
        }
        self.advertisementAdapters = advertisementAdapters
        self.connectedSessionFactories = connectedSessionFactories
        self.connectedDescriptors = connectedDescriptors
    }

    func decodeAdvertisement(
        _ input: ScaleAdvertisementInput,
        preferredProtocolID: String? = nil
    ) -> ScaleProtocolMatch? {
        let preferredAdapter = preferredProtocolID.flatMap { protocolID in
            advertisementAdapters.first { $0.descriptor.id == protocolID }
        }
        // A connected-only protocol owns the complete measurement lifecycle.
        // A broadly matching weight advertisement must not bypass its GATT stages.
        if preferredAdapter == nil,
           let preferredProtocolID,
           connectedDescriptors[preferredProtocolID] != nil {
            return nil
        }
        if let preferredAdapter,
           let packet = try? preferredAdapter.decodeAdvertisement(input) {
            return ScaleProtocolMatch(descriptor: preferredAdapter.descriptor, packet: packet)
        }
        for adapter in advertisementAdapters where adapter.descriptor.id != preferredProtocolID {
            if let packet = try? adapter.decodeAdvertisement(input) {
                return ScaleProtocolMatch(descriptor: adapter.descriptor, packet: packet)
            }
        }
        return nil
    }

    func descriptor(parserID: String) -> ScaleProtocolDescriptor? {
        advertisementAdapters.first { $0.descriptor.parserID == parserID }?.descriptor
            ?? connectedDescriptors.values.first { $0.parserID == parserID }
    }

    func descriptor(protocolID: String) -> ScaleProtocolDescriptor? {
        advertisementAdapters.first { $0.descriptor.id == protocolID }?.descriptor
            ?? connectedDescriptors[protocolID]
    }

    var descriptors: [ScaleProtocolDescriptor] {
        let advertisementDescriptors = advertisementAdapters.map(\.descriptor)
        let advertisementIDs = Set(advertisementDescriptors.map(\.id))
        return advertisementDescriptors
            + connectedDescriptors.values
                .filter { !advertisementIDs.contains($0.id) }
                .sorted { $0.id < $1.id }
    }

    func makeConnectedSession(protocolID: String) -> (any ScaleConnectedProtocolSession)? {
        connectedSessionFactories[protocolID]?()
    }

    static let builtIn = ScaleProtocolRegistry(advertisementAdapters: [
        .init(QNAABBScaleParser.self),
        .init(AAASeriesScaleParser.self),
        .init(SinocareScaleParser.self),
        // Specific service-identified layouts must precede broad Company ID layouts.
        .init(EtekcityFit8SScaleParser.self),
        .init(EufyC20ScaleParser.self),
        .init(YunmaiXScaleParser.self),
        .init(Silvergear108ScaleParser.self),
        .init(OKOKScaleParser.self),
        .init(ScaleupScaleParser.self),
        .init(XiaomiMiScale2BroadcastParser.self)
    ], connectedDescriptors: [
        HuaweiHagridProtocolSession.protocolDescriptor
    ], connectedSessionFactories: [
        SenssunIF2121ProtocolSession.protocolDescriptor.id: { SenssunIF2121ProtocolSession() },
        WolaiAFUProtocolSession.protocolDescriptor.id: { WolaiAFUProtocolSession() },
        XiaomiMiScale2ProtocolSession.protocolDescriptor.id: { XiaomiMiScale2ProtocolSession() }
    ])
}
