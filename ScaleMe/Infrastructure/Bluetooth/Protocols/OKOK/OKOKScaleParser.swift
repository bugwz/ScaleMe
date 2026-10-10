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
// Adapted/referenced from openScale/OkOkHandler.kt at 6613db5838e4674a19652441073f82b3ee3d7009.
// See LICENSES/openScale/NOTICE.md for sources and adaptation details.

import Foundation

struct OKOKScaleParser {
    static func parse(
        _ packet: ScaleManufacturerPacket,
        advertisedName: String,
        now: Date = .now
    ) throws -> BodyMeasurement {
        switch packet.companyID {
        case 0x20CA:
            guard supportedName(advertisedName) else { throw ScalePayloadError.unsupported }
            return try parseV20(packet.payload, now: now)
        case 0x11CA:
            guard supportedName(advertisedName) else { throw ScalePayloadError.unsupported }
            return try parseV11(packet.payload, now: now)
        case 0xF0FF:
            guard supportedName(advertisedName) else { throw ScalePayloadError.unsupported }
            return try parseVF0(packet.payload, now: now)
        default:
            guard packet.companyID & 0x00FF == 0x00C0 else { throw ScalePayloadError.unsupported }
            return try parseC0(packet.payload, now: now)
        }
    }

    private static func parseV20(_ data: Data, now: Date) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count == 19 else { throw ScalePayloadError.tooShort }
        let checksum = bytes[0..<12].reduce(UInt8(0x20)) { $0 ^ $1 }
        guard checksum == bytes[12] else { throw ScalePayloadError.unsupported }
        let weightRaw = readUInt16BE(bytes, at: 8)
        let divider = bytes[6] & 0x04 != 0 ? 100.0 : 10.0
        let impedanceOhm = Double(readUInt16BE(bytes, at: 10)) / 10
        return try measurement(
            weightKG: Double(weightRaw) / divider,
            impedanceOhm: impedanceOhm > 0 ? impedanceOhm : nil,
            isStable: bytes[6] & 0x01 != 0,
            now: now
        )
    }

    private static func parseV11(_ data: Data, now: Date) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count == 23 else { throw ScalePayloadError.tooShort }
        let checksum = bytes[0..<16].reduce(UInt8(0xCA ^ 0x11)) { $0 ^ $1 }
        guard checksum == bytes[16] else { throw ScalePayloadError.unsupported }
        let properties = bytes[9]
        let divider = divider(for: properties)
        let weightKG = convertedWeightKG(
            raw: readUInt16BE(bytes, at: 3),
            properties: properties,
            divider: divider
        )
        return try measurement(weightKG: weightKG, impedanceOhm: nil, isStable: true, now: now)
    }

    private static func parseVF0(_ data: Data, now: Date) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { throw ScalePayloadError.tooShort }
        let rawWeight = UInt16(bytes[3]) << 8 | UInt16(bytes[2])
        return try measurement(weightKG: Double(rawWeight) / 10, impedanceOhm: nil, isStable: true, now: now)
    }

    private static func parseC0(_ data: Data, now: Date) throws -> BodyMeasurement {
        let bytes = [UInt8](data)
        guard bytes.count >= 13 else { throw ScalePayloadError.tooShort }
        let properties = bytes[6]
        let divider = divider(for: properties)
        let weightKG = convertedWeightKG(
            raw: readUInt16BE(bytes, at: 0),
            properties: properties,
            divider: divider
        )
        let impedanceOhm = Double(readUInt16BE(bytes, at: 2)) / 10
        return try measurement(
            weightKG: weightKG,
            impedanceOhm: impedanceOhm > 0 ? impedanceOhm : nil,
            isStable: properties & 0x01 != 0,
            now: now
        )
    }

    private static func measurement(
        weightKG: Double,
        impedanceOhm: Double?,
        isStable: Bool,
        now: Date
    ) throws -> BodyMeasurement {
        guard (5...300).contains(weightKG) else { throw ScalePayloadError.unsupported }
        return BodyMeasurement(
            date: now,
            weightKG: weightKG,
            impedanceOhm: impedanceOhm,
            source: .builtInProtocol,
            isStable: isStable
        )
    }

    private static func divider(for properties: UInt8) -> Double {
        switch (properties >> 1) & 0x03 {
        case 1: 1
        case 2: 100
        default: 10
        }
    }

    private static func convertedWeightKG(raw: UInt16, properties: UInt8, divider: Double) -> Double {
        switch (properties >> 3) & 0x03 {
        case 1: return Double(raw) / divider / 2
        case 2: return Double(raw) / divider * 0.453_592_37
        case 3:
            return Double(raw >> 8) * 6.350_293
                + Double(raw & 0xFF) / divider * 0.453_592_37
        default: return Double(raw) / divider
        }
    }

    private static func supportedName(_ name: String) -> Bool {
        let value = name.uppercased()
        return value == "ADV"
            || value == "CHIPSEA-BLE"
            || value.hasPrefix("YODA0")
            || value.hasPrefix("YODA1")
    }

    private static func readUInt16BE(_ bytes: [UInt8], at index: Int) -> UInt16 {
        UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
    }
}

extension OKOKScaleParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.okok",
        name: "OKOK 广播协议",
        parserID: "okokBroadcast",
        transport: .advertisementManufacturerData,
        discoveryCompatibility: .okokBroadcast,
        capabilities: [.liveMeasurement]
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "OKOK",
        version: 1,
        summary: "解析 OKOK V20、V11、VF0 与 C0 广播变体。已通过数据样本验证，待真机验证。",
        origin: .builtIn,
        match: .init(
            transport: descriptor.transport,
            serviceUUID: "MULTI",
            characteristicUUID: nil,
            minimumLength: 6
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
