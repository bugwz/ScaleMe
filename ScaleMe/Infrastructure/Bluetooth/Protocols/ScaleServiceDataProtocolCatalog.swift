import Foundation

enum ScaleServiceDataProtocolFamily: String, Equatable {
    case xiaomiMiScale2 = "Xiaomi XMTZC04HM 181D 广播协议"

    var builtInParserID: String {
        switch self {
        case .xiaomiMiScale2: "xiaomiMiScale2Advertisement"
        }
    }
}

struct ScaleServiceDataProtocolMatch {
    enum Packet {
        case measurement(BodyMeasurement)
        case weightRemoved
    }

    var family: ScaleServiceDataProtocolFamily
    var packet: Packet
}

enum ScaleServiceDataProtocolCatalog {
    static func parse(
        name: String,
        serviceUUID: String,
        payload: Data,
        manufacturerData: Data?,
        now: Date = .now
    ) -> ScaleServiceDataProtocolMatch? {
        guard CommunicationRuleCodec.normalizeUUID(serviceUUID)
                == XiaomiMiScale2BroadcastParser.serviceUUID,
              payload.count == XiaomiMiScale2BroadcastParser.frameLength,
              XiaomiMiScale2BroadcastParser.matchesIdentity(
                  name: name,
                  manufacturerData: manufacturerData
              ),
              let packet = try? XiaomiMiScale2BroadcastParser.parsePacket(payload, now: now) else {
            return nil
        }
        switch packet {
        case .measurement(let measurement):
            return .init(family: .xiaomiMiScale2, packet: .measurement(measurement))
        case .weightRemoved:
            return .init(family: .xiaomiMiScale2, packet: .weightRemoved)
        }
    }
}
