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
// Adapted/referenced from openScale/SinocareHandler.kt at 6613db5838e4674a19652441073f82b3ee3d7009.
// See LICENSES/openScale/NOTICE.md for sources and adaptation details.

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
