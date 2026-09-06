import Foundation

struct ScaleupScaleParser {
    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        let flag = UInt8(packet.companyID & 0xFF)
        guard flag == 0xD0 || flag == 0xE0 else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 9 else { throw ScalePayloadError.tooShort }
        let rawWeight = UInt16(packet.companyID >> 8) << 8 | UInt16(bytes[0])
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .builtInProtocol,
            isStable: flag == 0xE0
        )
    }
}

extension ScaleupScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.scaleup",
        name: "Scaleup 广播协议",
        parserID: "scaleupBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .scaleupBroadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Scaleup",
        version: 1,
        summary: "解析 D0/E0 状态、0.01 kg 体重与稳定状态。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "xxD0/xxE0",
            characteristicUUID: nil,
            minimumLength: 11
        ),
        decoder: nil,
        builtInParser: descriptor.parserID,
        verification: .fixtureValidated
    )

    static func decodeAdvertisement(_ input: ScaleAdvertisementInput) throws -> ScaleProtocolPacket {
        guard let data = input.manufacturerData,
              let packet = ScaleManufacturerPacket(appleManufacturerData: data) else {
            throw ScalePayloadError.unsupported
        }
        return .measurement(try parse(packet, now: input.receivedAt))
    }
}
