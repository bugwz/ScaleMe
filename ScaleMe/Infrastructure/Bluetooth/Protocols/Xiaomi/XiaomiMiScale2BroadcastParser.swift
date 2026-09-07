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

extension XiaomiMiScale2BroadcastParser: ScaleAdvertisementProtocolAdapter {
    static let descriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.xiaomi-181d",
        name: "Xiaomi XMTZC04HM 181D 广播协议",
        parserID: "xiaomiMiScale2Advertisement",
        transport: .advertisementServiceData,
        discoveryCompatibility: .xiaomiMiScale2Advertisement,
        capabilities: [
            .liveMeasurement,
            .weightRemoval,
            .historyRead,
            .hardwareUnitConfiguration,
            .timeSynchronization
        ],
        stabilityPolicy: .lockedSampleIsFinal
    )

    static let communicationRule = CommunicationRule(
        id: descriptor.id,
        name: "Xiaomi XMTZC04HM",
        version: 1,
        summary: "解析 MI SCALE2 的 10 字节 181D 广播、单位、锁定状态、离秤状态与时间。仅体重，已通过上游抓包样本验证，待本项目真机验证。",
        author: "ble-scale-sync contributors",
        origin: .builtIn,
        sourceURL: URL(string: "https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/xiaomi-mi-scale-legacy.ts"),
        match: .init(
            transport: descriptor.transport,
            serviceUUID: serviceUUID,
            characteristicUUID: nil,
            minimumLength: frameLength,
            maximumLength: frameLength
        ),
        decoder: nil,
        builtInParser: descriptor.parserID,
        verification: .fixtureValidated,
        operations: CommunicationRuleOperations(
            historyRead: CommunicationGATTOperation(
                capability: .historyRead,
                subscriptions: [historyTarget],
                commands: [
                    historyCommand("0198843059"),
                    historyCommand("02")
                ],
                completionCommands: [historyCommand("03")],
                acknowledgementCommands: [historyCommand("0498843059")],
                historyResponse: CommunicationHistoryResponse(
                    recordMatcher: .init(
                        target: historyTarget,
                        minimumLength: 10,
                        maximumLength: 20
                    ),
                    completionMatcher: .init(
                        target: historyTarget,
                        minimumLength: 1,
                        maximumLength: 1,
                        exactHex: "03"
                    ),
                    framing: .fixedLength,
                    recordLength: 10,
                    builtInParser: "xiaomiHistory10"
                )
            )
        ),
        supportedModels: ["MI SCALE2"],
        requirements: [.multiFrameSession, .historyStateMachine]
    )

    private static let historyTarget = CommunicationGATTTarget(
        serviceUUID: serviceUUID,
        characteristicUUID: XiaomiScaleConfigurationProtocol.historyCharacteristicUUID
    )

    private static func historyCommand(_ payload: String) -> CommunicationCommand {
        CommunicationCommand(
            target: historyTarget,
            payloadHexTemplate: payload,
            writeMode: .automatic
        )
    }

    static func decodeAdvertisement(_ input: ScaleAdvertisementInput) throws -> ScaleProtocolPacket {
        guard matchesIdentity(name: input.name, manufacturerData: input.manufacturerData),
              let payload = input.serviceData[serviceUUID], payload.count == frameLength else {
            throw ScalePayloadError.unsupported
        }
        switch try parsePacket(payload, now: input.receivedAt) {
        case .measurement(let measurement): return .measurement(measurement)
        case .weightRemoved: return .weightRemoved
        }
    }
}
