import Foundation

struct EtekcityFit8SScaleParser {
    static let companyID: UInt16 = 0x06D0

    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedServiceUUIDs: Set<String>,
        now: Date = .now
    ) throws -> BodyMeasurement {
        guard packet.companyID == companyID,
              advertisedServiceUUIDs.contains(where: { normalizedUUID($0) == "FFD0" }) else {
            throw ScalePayloadError.unsupported
        }
        let bytes = [UInt8](packet.payload)
        guard bytes.count == 20 else { throw ScalePayloadError.tooShort }
        guard bytes[0] == 0x01 else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt32(bytes[10]) | UInt32(bytes[11]) << 8 | UInt32(bytes[12]) << 16
        let weightKG = Double(rawWeight) / 1_000
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        let rawImpedance = UInt16(bytes[13]) | UInt16(bytes[14]) << 8
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: rawImpedance > 0 ? Double(rawImpedance) : nil,
            source: .builtInProtocol,
            isStable: bytes[15] == 0x01
        )
    }

    private static func normalizedUUID(_ value: String) -> String {
        let uppercase = value.uppercased()
        let suffix = "-0000-1000-8000-00805F9B34FB"
        guard uppercase.hasPrefix("0000"), uppercase.hasSuffix(suffix) else { return uppercase }
        return String(uppercase.dropFirst(4).prefix(4))
    }
}

extension EtekcityFit8SScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.fit8s",
        name: "Etekcity Fit 8S 广播协议",
        parserID: "etekcityFit8SBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .etekcityFit8SBroadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Etekcity Fit 8S",
        version: 1,
        summary: "解析 Company ID 06D0、FFD0 服务广播中的克数、阻抗与稳定状态。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "06D0 + FFD0",
            characteristicUUID: nil,
            minimumLength: 22,
            maximumLength: 22
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
