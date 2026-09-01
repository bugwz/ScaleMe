import Foundation

enum ScaleBroadcastProtocolFamily: String, Equatable {
    case qnAABB = "QN/AABB 广播协议"
    case aaaSeries = "AAA 系列广播协议"
    case sinocare = "Sinocare 广播协议"
    case scaleup = "Scaleup 广播协议"
    case okok = "OKOK 广播协议"
    case etekcityFit8S = "Etekcity Fit 8S 广播协议"
    case eufyC20 = "Eufy C20 广播协议"
    case yunmaiX = "Yunmai X 广播协议"

    var builtInParserID: String {
        switch self {
        case .qnAABB: "qnAABBBroadcast"
        case .aaaSeries: "aaaSeriesBroadcast"
        case .sinocare: "sinocareBroadcast"
        case .scaleup: "scaleupBroadcast"
        case .okok: "okokBroadcast"
        case .etekcityFit8S: "etekcityFit8SBroadcast"
        case .eufyC20: "eufyC20Broadcast"
        case .yunmaiX: "yunmaiXBroadcast"
        }
    }

    static let allBuiltInParserIDs: [String] = [
        Self.qnAABB,
        .aaaSeries,
        .sinocare,
        .scaleup,
        .okok,
        .etekcityFit8S,
        .eufyC20,
        .yunmaiX
    ].map(\.builtInParserID)
}

struct ScaleManufacturerPacket: Equatable {
    var companyID: UInt16
    var payload: Data

    /// CoreBluetooth includes the little-endian Bluetooth Company Identifier
    /// as the first two bytes of CBAdvertisementDataManufacturerDataKey.
    init?(appleManufacturerData data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }
        companyID = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        payload = Data(bytes.dropFirst(2))
    }

    init(companyID: UInt16, payload: Data) {
        self.companyID = companyID
        self.payload = payload
    }
}

struct ScaleBroadcastProtocolMatch {
    var family: ScaleBroadcastProtocolFamily
    var measurement: BodyMeasurement
}

enum ScaleBroadcastProtocolCatalog {
    static func parse(
        name: String,
        manufacturerData: Data,
        advertisedServiceUUIDs: Set<String> = [],
        now: Date = .now
    ) -> ScaleBroadcastProtocolMatch? {
        guard let packet = ScaleManufacturerPacket(appleManufacturerData: manufacturerData) else {
            return nil
        }

        if let measurement = try? QNAABBScaleParser.parse(packet, now: now) {
            return ScaleBroadcastProtocolMatch(family: .qnAABB, measurement: measurement)
        }
        if let measurement = try? AAASeriesScaleParser.parse(packet, advertisedName: name, now: now) {
            return ScaleBroadcastProtocolMatch(family: .aaaSeries, measurement: measurement)
        }
        if let measurement = try? SinocareScaleParser.parse(packet, now: now) {
            return ScaleBroadcastProtocolMatch(family: .sinocare, measurement: measurement)
        }
        // Match protocols with an identifying service UUID before broad Company
        // Identifier layouts. Etekcity's 0x06D0 otherwise resembles Scaleup's
        // intentionally variable xxD0 measuring frame.
        if let measurement = try? EtekcityFit8SScaleParser.parse(
            packet,
            advertisedServiceUUIDs: advertisedServiceUUIDs,
            now: now
        ) {
            return ScaleBroadcastProtocolMatch(family: .etekcityFit8S, measurement: measurement)
        }
        if let measurement = try? EufyC20ScaleParser.parse(packet, now: now) {
            return ScaleBroadcastProtocolMatch(family: .eufyC20, measurement: measurement)
        }
        if let measurement = try? YunmaiXScaleParser.parse(
            packet,
            advertisedServiceUUIDs: advertisedServiceUUIDs,
            now: now
        ) {
            return ScaleBroadcastProtocolMatch(family: .yunmaiX, measurement: measurement)
        }
        if let measurement = try? OKOKScaleParser.parse(packet, advertisedName: name, now: now) {
            return ScaleBroadcastProtocolMatch(family: .okok, measurement: measurement)
        }
        if let measurement = try? ScaleupScaleParser.parse(packet, now: now) {
            return ScaleBroadcastProtocolMatch(family: .scaleup, measurement: measurement)
        }
        return nil
    }
}
