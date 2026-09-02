import Foundation

/// Xiaomi XMTZC04HM / `MI SCALE2` broadcasts a 10-byte, WSS-shaped payload
/// under service data 0x181D. RFU flag bits carry Xiaomi-specific stable,
/// removed and jin states, so this remains separate from the SIG parser.
struct XiaomiMiScale2BroadcastParser {
    static let serviceUUID = "181D"
    static let huamiCompanyID: UInt16 = 0x0157
    static let frameLength = 10

    enum Packet {
        case measurement(BodyMeasurement)
        case weightRemoved
    }

    static func matchesIdentity(name: String, manufacturerData: Data?) -> Bool {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "MI SCALE2" {
            return true
        }
        guard let manufacturerData,
              let packet = ScaleManufacturerPacket(appleManufacturerData: manufacturerData) else {
            return false
        }
        return packet.companyID == huamiCompanyID
    }

    static func parsePacket(_ data: Data, now: Date = .now) throws -> Packet {
        let bytes = [UInt8](data)
        guard bytes.count == frameLength else { throw ScalePayloadError.tooShort }
        let flags = bytes[0]
        guard flags & 0x80 == 0 else { return .weightRemoved }

        let rawWeight = Double(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
        let weightKG: Double
        if flags & 0x01 != 0 {
            weightKG = rawWeight / 100 * 0.453_592_37
        } else if flags & 0x10 != 0 {
            weightKG = rawWeight / 100 * 0.5
        } else {
            weightKG = rawWeight / 200
        }
        guard (5...350).contains(weightKG) else { throw ScalePayloadError.unsupported }

        let isStable = flags & 0x20 != 0
        return .measurement(BodyMeasurement(
            date: isStable ? (StandardWeightScaleParser.parseDate(Array(bytes[3...9])) ?? now) : now,
            weightKG: weightKG,
            source: .xiaomi,
            isStable: isStable
        ))
    }
}
