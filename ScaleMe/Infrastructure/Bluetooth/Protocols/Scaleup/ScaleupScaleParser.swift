/*
 * openScale
 * Copyright (C) 2025 olie.xdev <olie.xdeveloper@googlemail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// SPDX-License-Identifier: GPL-3.0-or-later
// ScaleMe adaptations and modifications: Copyright (C) 2026 bugwz
// Modified 2026-10-10: preserve upstream attribution and identify the license.
// Adapted/referenced from openScale/ScaleupHandler.kt at 6613db5838e4674a19652441073f82b3ee3d7009.
// See LICENSES/openScale/NOTICE.md for sources and adaptation details.

import Foundation

struct ScaleupScaleParser {
    static func parse(_ packet: ScaleManufacturerPacket, now: Date = .now) throws -> BodyMeasurement {
        let flag = UInt8(packet.companyID & 0xFF)
        guard flag == 0xD0 || flag == 0xE0 else { throw ScalePayloadError.unsupported }
        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 9 else { throw ScalePayloadError.tooShort }
        let rawWeight = UInt16(packet.companyID >> 8) << 8 | UInt16(bytes[0])
        let weightKG = Double(rawWeight) / 100
        guard MeasurementLimits.weightKG.contains(weightKG) else { throw ScalePayloadError.unsupported }
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
