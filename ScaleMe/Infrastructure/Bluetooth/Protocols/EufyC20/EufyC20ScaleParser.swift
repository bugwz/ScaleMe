// Upstream: openScale; no file-level copyright notice in EufyC20Handler.kt.
// Repository copyright and license are preserved in LICENSES/openScale/.
// SPDX-License-Identifier: GPL-3.0-or-later
// ScaleMe adaptations and modifications: Copyright (C) 2026 bugwz
// Modified 2026-10-10: preserve upstream attribution and identify the license.
// Adapted/referenced from openScale/EufyC20Handler.kt at 6613db5838e4674a19652441073f82b3ee3d7009.
// See LICENSES/openScale/NOTICE.md for sources and adaptation details.

import Foundation

struct EufyC20ScaleParser {
    static let companyID: UInt16 = 48_228

    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        guard packet.companyID == companyID else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 14 else { throw ScalePayloadError.tooShort }
        let flags = bytes[10]
        guard flags & 0x01 != 0 else { throw ScalePayloadError.unsupported }
        let rawWeight = UInt16(bytes[12]) | UInt16(bytes[13]) << 8
        let weightKG = Double(rawWeight) / 100
        guard MeasurementLimits.weightKG.contains(weightKG) else { throw ScalePayloadError.unsupported }
        var impedanceOhm: Double?
        if flags & 0x40 != 0 {
            guard bytes.count >= 19 else { throw ScalePayloadError.tooShort }
            let rawImpedance = UInt16(bytes[17]) | UInt16(bytes[18]) << 8
            if rawImpedance > 0 { impedanceOhm = Double(rawImpedance) / 10 }
        }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
            source: .builtInProtocol,
            isStable: impedanceOhm != nil
        )
    }
}

extension EufyC20ScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.eufy-c20",
        name: "Eufy C20 广播协议",
        parserID: "eufyC20Broadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .eufyC20Broadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Eufy C20",
        version: 1,
        summary: "解析 Company ID BC64 的体重与阻抗字段。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "BC64",
            characteristicUUID: nil,
            minimumLength: 16
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
