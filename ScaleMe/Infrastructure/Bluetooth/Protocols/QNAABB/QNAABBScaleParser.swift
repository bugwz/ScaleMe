import Foundation

/// Weight-only, non-connectable QN-lineage advertisements using the AABB frame.
/// The layout follows the captured AABB manufacturer-data samples.
struct QNAABBScaleParser {
    static let companyID: UInt16 = 0xFFFF

    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 19 else { throw ScalePayloadError.tooShort }
        guard bytes[0] == 0xAA, bytes[1] == 0xBB else { throw ScalePayloadError.unsupported }

        let rawWeight = UInt16(bytes[17]) | UInt16(bytes[18]) << 8
        let weightKG = Double(rawWeight) / 100
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .builtInProtocol,
            isStable: bytes[15] & 0x20 != 0
        )
    }
}

extension QNAABBScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.qn-aabb",
        name: "QN/AABB 广播协议",
        parserID: "qnAABBBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .qnAABBBroadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "QN/AABB",
        version: 1,
        summary: "解析 Company ID FFFF 厂商广播中的 AABB 体重与稳定状态。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "FFFF",
            characteristicUUID: nil,
            minimumLength: 21
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
