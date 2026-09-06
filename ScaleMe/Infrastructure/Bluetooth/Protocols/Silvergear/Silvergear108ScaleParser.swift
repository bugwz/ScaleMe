import Foundation

/// Broadcast-only Silvergear Smart Scale 108 protocol derived from two iOS
/// PacketLogger captures with known displayed outcomes. The post-measurement
/// body frame remains intentionally undecoded because one sample is not enough
/// to identify its field semantics.
struct Silvergear108ScaleParser {
    static let companyID: UInt16 = 0xA0AC
    static let advertisedServiceUUID = "FFB0"

    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedServiceUUIDs: Set<String> = [],
        now: Date = .now
    ) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        if !advertisedServiceUUIDs.isEmpty {
            guard advertisedServiceUUIDs.contains(where: {
                CommunicationRuleCodec.normalizeUUID($0) == advertisedServiceUUID
            }) else { throw ScalePayloadError.unsupported }
        }

        let bytes = [UInt8](packet.payload)
        guard bytes.count == 12 else { throw ScalePayloadError.tooShort }
        let payload = Array(bytes[6..<12])
        guard payload[4] == 0x0D else { throw ScalePayloadError.unsupported }
        let expectedChecksum = payload[0..<5].reduce(0) { ($0 + Int($1)) & 0x1F }
        guard expectedChecksum == Int(payload[5] & 0x1F) else {
            throw ScalePayloadError.unsupported
        }

        let decodedWeight = Int(payload[1] ^ 0xA0) << 16
            | Int(payload[2] ^ 0xA0) << 8
            | Int(payload[3] ^ 0xA0)
        let grams = decodedWeight - 0x8C0000
        let weightKG = Double(grams) / 1_000
        guard (2...300).contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .builtInProtocol,
            isStable: ((payload[0] ^ 0xA0) & 0x80) != 0
        )
    }
}

extension Silvergear108ScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.silvergear-108",
        name: "Silvergear 108 广播协议",
        parserID: "silvergear108Broadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .silvergear108Broadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Silvergear 108",
        version: 1,
        summary: "解析 Company ID A0AC 的 12 字节广播、5 位校验、混淆后的克数与锁定状态。身体数据帧语义尚未确认，因此只读取体重。",
        author: "ble-scale-sync contributors",
        origin: .builtIn,
        sourceURL: URL(string: "https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/silvergear-108.ts"),
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "A0AC + FFB0",
            characteristicUUID: nil,
            minimumLength: 14,
            maximumLength: 14
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
        return .measurement(try parse(
            packet,
            advertisedServiceUUIDs: input.advertisedServiceUUIDs,
            now: input.receivedAt
        ))
    }
}
