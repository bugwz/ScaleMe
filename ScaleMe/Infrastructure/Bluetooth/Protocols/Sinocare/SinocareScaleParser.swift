import Foundation

struct SinocareScaleParser {
    static let companyID: UInt16 = 0xFF64

    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 17 else { throw ScalePayloadError.tooShort }
        let checksum = bytes[6..<16].reduce(UInt8(0)) { $0 ^ $1 }
        guard checksum == bytes[16] else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt16(bytes[9]) | UInt16(bytes[10]) << 8
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .builtInProtocol,
            isStable: false
        )
    }
}

extension SinocareScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.sinocare",
        name: "Sinocare 广播协议",
        parserID: "sinocareBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .sinocareBroadcast,
        capabilities: [.liveMeasurement],
        stabilityPolicy: .repeatedSamples
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Sinocare",
        version: 1,
        summary: "解析 Company ID FF64 的 XOR 校验和广播体重。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "FF64",
            characteristicUUID: nil,
            minimumLength: 19
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
