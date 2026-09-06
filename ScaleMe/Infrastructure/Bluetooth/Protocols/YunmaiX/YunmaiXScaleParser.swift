import Foundation

struct YunmaiXScaleParser {
    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedServiceUUIDs: Set<String>,
        now: Date = .now
    ) throws -> BodyMeasurement {
        guard advertisedServiceUUIDs.contains(where: { normalizedUUID($0) == "1320" }) else {
            throw ScalePayloadError.unsupported
        }
        let bytes = [UInt8](packet.payload)
        guard bytes.count == 14 else { throw ScalePayloadError.tooShort }
        guard Array(bytes[4...6]) == [0x0B, 0x74, 0x17] else { throw ScalePayloadError.unsupported }
        let checksum = bytes[7...12].reduce(UInt8(0)) { $0 ^ $1 }
        guard checksum == bytes[13] else { throw ScalePayloadError.unsupported }
        let state = bytes[8]
        guard (1...3).contains(state) else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt16(bytes[9]) << 8 | UInt16(bytes[10])
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        let rawImpedance = UInt16(bytes[11]) << 8 | UInt16(bytes[12])
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: state == 3 && rawImpedance > 0 ? Double(rawImpedance) : nil,
            source: .builtInProtocol,
            isStable: state == 3
        )
    }

    private static func normalizedUUID(_ value: String) -> String {
        let uppercase = value.uppercased()
        let suffix = "-0000-1000-8000-00805F9B34FB"
        guard uppercase.hasPrefix("0000"), uppercase.hasSuffix(suffix) else { return uppercase }
        return String(uppercase.dropFirst(4).prefix(4))
    }
}

extension YunmaiXScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.yunmai-x",
        name: "Yunmai X 广播协议",
        parserID: "yunmaiXBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .yunmaiXBroadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Yunmai X",
        version: 1,
        summary: "解析 1320 服务、0B7417 签名、XOR 校验、体重与阻抗。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "1320 + dynamic",
            characteristicUUID: nil,
            minimumLength: 16,
            maximumLength: 16
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
