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
// Adapted/referenced from openScale/AAAxHandler.kt at 6613db5838e4674a19652441073f82b3ee3d7009.
// See LICENSES/openScale/NOTICE.md for sources and adaptation details.

import Foundation

/// Broadcast-only AAA002 / AAA007 / AAA013 family. The application payload is
/// XOR-obfuscated with the high byte of the Company Identifier and carries a
/// 5-bit checksum. Only validated weight frames are accepted.
struct AAASeriesScaleParser {
    private static let supportedNames: Set<String> = ["AAA002", "AAA007", "AAA013"]

    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedName: String,
        now: Date = .now
    ) throws -> BodyMeasurement {
        let normalizedName = advertisedName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard supportedNames.contains(normalizedName) else { throw ScalePayloadError.unsupported }

        let bytes = [UInt8](packet.payload)
        guard bytes.count >= 12 else { throw ScalePayloadError.tooShort }
        let xorKey = UInt8((packet.companyID >> 8) & 0xFF)
        let decoded = bytes[6..<12].map { $0 ^ xorKey }
        let expectedChecksum = UInt8(decoded[0..<5].reduce(0) { $0 + UInt32($1) } & 0x1F)
        guard expectedChecksum == decoded[5] & 0x1F, decoded[4] == 0xAD else {
            throw ScalePayloadError.unsupported
        }

        let value = UInt32(decoded[0]) << 24
            | UInt32(decoded[1]) << 16
            | UInt32(decoded[2]) << 8
            | UInt32(decoded[3])
        let weightKG = Double(value & 0x3_FFFF) / 1_000
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }

        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            source: .builtInProtocol,
            isStable: value & 0x8000_0000 != 0
        )
    }
}

extension AAASeriesScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.aaa-series",
        name: "AAA 系列广播协议",
        parserID: "aaaSeriesBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .aaaSeriesBroadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "AAA Series",
        version: 1,
        summary: "解析 AAA 系列厂商广播的 XOR 数据、5 位校验、克数与稳定状态。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "ANY",
            characteristicUUID: nil,
            minimumLength: 14
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
        return .measurement(try parse(packet, advertisedName: input.name, now: input.receivedAt))
    }
}
