import Foundation

final class SenssunIF2121ProtocolSession: ScaleConnectedProtocolSession {
    static let protocolDescriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.senssun-if2121",
        name: "Senssun IF2121",
        parserID: SenssunIF2121ScaleProtocol.builtInParserID,
        transport: .characteristicNotification,
        discoveryCompatibility: .unverified,
        capabilities: [.liveMeasurement, .weightRemoval]
    )
    let descriptor = protocolDescriptor

    static let communicationRule = CommunicationRule(
        id: protocolDescriptor.id,
        name: protocolDescriptor.name,
        version: 1,
        summary: "解析香山 IF2121A 的 33CC 实时重量、稳定状态、检测阶段及 40 字节分片最终结果；未确认的身体成分字段不会入库。",
        author: "ScaleMe device capture",
        origin: .builtIn,
        match: .init(
            transport: protocolDescriptor.transport,
            serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
            characteristicUUID: SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
            minimumLength: 10,
            maximumLength: 17,
            prefixHex: "33CC"
        ),
        decoder: nil,
        builtInParser: protocolDescriptor.parserID,
        verification: .fixtureValidated,
        implementation: .experimental,
        supportedModels: ["IF2121A"],
        requirements: [.multiFrameSession],
        notifyTargets: [
            .init(
                serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
                characteristicUUID: SenssunIF2121ScaleProtocol.liveCharacteristicUUID
            ),
            .init(
                serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
                characteristicUUID: SenssunIF2121ScaleProtocol.resultCharacteristicUUID
            )
        ]
    )

    private var resultAccumulator = SenssunIF2121ScaleParser.FrameAccumulator()
    private var stableWeightKG: Double?

    func handle(_ event: ScaleProtocolEvent) throws -> [ScaleProtocolAction] {
        switch event {
        case .connected:
            reset()
            return [.discoverServices([SenssunIF2121ScaleProtocol.serviceUUID])]
        case .disconnected:
            reset()
            return []
        case .servicesDiscovered(let services):
            guard services.contains(SenssunIF2121ScaleProtocol.serviceUUID) else { return [] }
            return [.discoverCharacteristics(
                serviceUUID: SenssunIF2121ScaleProtocol.serviceUUID,
                characteristicUUIDs: [
                    SenssunIF2121ScaleProtocol.liveCharacteristicUUID,
                    SenssunIF2121ScaleProtocol.resultCharacteristicUUID
                ]
            )]
        case .characteristicsDiscovered(let serviceUUID, let characteristicUUIDs):
            guard serviceUUID == SenssunIF2121ScaleProtocol.serviceUUID else { return [] }
            return characteristicUUIDs.compactMap { characteristicUUID in
                guard characteristicUUID == SenssunIF2121ScaleProtocol.liveCharacteristicUUID
                    || characteristicUUID == SenssunIF2121ScaleProtocol.resultCharacteristicUUID else {
                    return nil
                }
                return .subscribe(.init(
                    serviceUUID: serviceUUID,
                    characteristicUUID: characteristicUUID
                ))
            }
        case .notification(let serviceUUID, let characteristicUUID, let payload, let receivedAt):
            guard serviceUUID == SenssunIF2121ScaleProtocol.serviceUUID else { return [] }
            let packet: SenssunIF2121ScaleParser.Packet?
            if characteristicUUID == SenssunIF2121ScaleProtocol.liveCharacteristicUUID {
                packet = try SenssunIF2121ScaleParser.parse(payload, now: receivedAt)
            } else if characteristicUUID == SenssunIF2121ScaleProtocol.resultCharacteristicUUID {
                do {
                    packet = try resultAccumulator.ingest(payload, now: receivedAt)
                } catch {
                    resultAccumulator.reset()
                    throw error
                }
            } else {
                return []
            }
            return packet.map(actions(for:)) ?? []
        case .notificationStateChanged, .writeCompleted, .timer:
            return []
        }
    }

    private func actions(for packet: SenssunIF2121ScaleParser.Packet) -> [ScaleProtocolAction] {
        switch packet {
        case .weightRemoved:
            stableWeightKG = nil
            return [.emit(.weightRemoved, reliability: .protocolStable)]
        case .progress:
            guard stableWeightKG != nil else { return [] }
            return []
        case .measurement(let phase, let measurement):
            switch phase {
            case .live:
                stableWeightKG = nil
                return [.reportLiveMeasurement(
                    measurement,
                    phase: .measuringWeight,
                    loadCycle: .coordinatorManaged
                )]
            case .stable:
                stableWeightKG = measurement.weightKG
                return [.reportLiveMeasurement(
                    measurement,
                    phase: .measuringBodyComposition,
                    loadCycle: .coordinatorManaged
                )]
            case .bodyCompositionProgress:
                return []
            case .final:
                guard let stableWeightKG,
                      abs(stableWeightKG - measurement.weightKG) <= 0.15 else { return [] }
                self.stableWeightKG = nil
                return [.emit(.measurement(measurement), reliability: .protocolFinal)]
            }
        }
    }

    private func reset() {
        resultAccumulator.reset()
        stableWeightKG = nil
    }
}
