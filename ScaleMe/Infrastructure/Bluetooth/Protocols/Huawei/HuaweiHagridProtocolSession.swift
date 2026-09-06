import Foundation
import Security

/// Owns the authenticated Huawei Hagrid wire session. CoreBluetooth transport
/// and Keychain credential retrieval intentionally remain outside this type.
final class HuaweiHagridProtocolSession: ScaleConnectedProtocolSession {
    static let protocolDescriptor = ScaleProtocolDescriptor(
        id: "protocol.builtin.huawei-hagrid",
        name: "Huawei Hagrid",
        parserID: "huaweiHagridWSP",
        transport: .characteristicNotification,
        discoveryCompatibility: .huaweiHagridAuthorizationRequired,
        capabilities: [.liveMeasurement, .authentication]
    )
    let descriptor = protocolDescriptor

    static let communicationRule = CommunicationRule(
        id: protocolDescriptor.id,
        name: "Huawei Hagrid/WSP",
        version: 2,
        summary: "华为 Hagrid/WSP 私有协议；分帧、认证派生、AES-CTR 解密及测量载荷已通过抓包夹具验证，完整 iOS 会话仍待真机验证。",
        author: "openScale contributors",
        origin: .builtIn,
        sourceURL: URL(string: "https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/HuaweiHagridWspHandler.kt"),
        match: .init(
            transport: protocolDescriptor.transport,
            serviceUUID: HuaweiHagridProtocol.userDataServiceUUID,
            characteristicUUID: HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID,
            minimumLength: 5
        ),
        decoder: nil,
        builtInParser: protocolDescriptor.parserID,
        verification: .fixtureValidated,
        implementation: .experimental,
        supportedModels: [
            "Huawei Scale 2 Pro",
            "Huawei Scale 3",
            "Huawei Scale 3 Pro",
            "Honor Scale 2"
        ],
        requirements: [.bindKey, .encryption, .userProfile, .timeSynchronization, .multiFrameSession],
        notifyTargets: [
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.authenticationTokenCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.setUserInfoCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.currentTimeServiceUUID, characteristicUUID: HuaweiHagridProtocol.measurementStatusResultCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.bodyCompositionServiceUUID, characteristicUUID: HuaweiHagridProtocol.realtimeWeightCharacteristicUUID)
        ],
        writeTargets: [
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.authenticationTokenCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.userDataServiceUUID, characteristicUUID: HuaweiHagridProtocol.setUserInfoCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.currentTimeServiceUUID, characteristicUUID: HuaweiHagridProtocol.currentTimeCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.currentTimeServiceUUID, characteristicUUID: HuaweiHagridProtocol.measurementStatusPollCharacteristicUUID),
            .init(serviceUUID: HuaweiHagridProtocol.bodyCompositionServiceUUID, characteristicUUID: HuaweiHagridProtocol.realtimeWeightCharacteristicUUID)
        ]
    )

    private enum HandshakeState {
        case idle
        case awaitingChallenge
        case awaitingAuthenticationResponse
        case awaitingWorkKeyAcknowledgement
        case awaitingUserInfoAcknowledgement
        case ready
        case failed
    }

    private enum TimerID {
        static let statusPoll = "huawei-hagrid.status-poll"
    }

    private static let requiredNotificationCharacteristics: Set<String> = [
        HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID,
        HuaweiHagridProtocol.authenticationTokenCharacteristicUUID,
        HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID,
        HuaweiHagridProtocol.setUserInfoCharacteristicUUID,
        HuaweiHagridProtocol.realtimeWeightCharacteristicUUID,
        HuaweiHagridProtocol.measurementStatusResultCharacteristicUUID
    ]

    private let credentials: HuaweiHagridProtocol.Credentials
    private let profile: UserProfile
    private let usesScale3GenderEncoding: Bool
    private let randomData: (Int) throws -> Data
    private var handshakeState: HandshakeState = .idle
    private var didSendAuthenticationProbe = false
    private var notifyingCharacteristics = Set<String>()
    private var notificationAccumulators: [String: HuaweiHagridProtocol.NotificationAccumulator] = [:]
    private var randomA: Data?
    private var randomB: Data?
    private var workKey: Data?
    private var statusPollCount = 0

    init(
        credentials: HuaweiHagridProtocol.Credentials,
        profile: UserProfile,
        usesScale3GenderEncoding: Bool,
        randomData: @escaping (Int) throws -> Data = HuaweiHagridProtocolSession.secureRandomData
    ) {
        self.credentials = credentials
        self.profile = profile
        self.usesScale3GenderEncoding = usesScale3GenderEncoding
        self.randomData = randomData
    }

    func handle(_ event: ScaleProtocolEvent) throws -> [ScaleProtocolAction] {
        switch event {
        case .connected:
            reset()
            handshakeState = .awaitingChallenge
            return [.discoverServices([
                HuaweiHagridProtocol.userDataServiceUUID,
                HuaweiHagridProtocol.currentTimeServiceUUID,
                HuaweiHagridProtocol.bodyCompositionServiceUUID
            ])]
        case .disconnected:
            reset()
            return []
        case .servicesDiscovered(let services):
            var actions: [ScaleProtocolAction] = []
            if services.contains(HuaweiHagridProtocol.userDataServiceUUID) {
                actions.append(.discoverCharacteristics(
                    serviceUUID: HuaweiHagridProtocol.userDataServiceUUID,
                    characteristicUUIDs: [
                        HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID,
                        HuaweiHagridProtocol.authenticationTokenCharacteristicUUID,
                        HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID,
                        HuaweiHagridProtocol.setUserInfoCharacteristicUUID
                    ]
                ))
            }
            if services.contains(HuaweiHagridProtocol.currentTimeServiceUUID) {
                actions.append(.discoverCharacteristics(
                    serviceUUID: HuaweiHagridProtocol.currentTimeServiceUUID,
                    characteristicUUIDs: [
                        HuaweiHagridProtocol.currentTimeCharacteristicUUID,
                        HuaweiHagridProtocol.measurementStatusPollCharacteristicUUID,
                        HuaweiHagridProtocol.measurementStatusResultCharacteristicUUID
                    ]
                ))
            }
            if services.contains(HuaweiHagridProtocol.bodyCompositionServiceUUID) {
                actions.append(.discoverCharacteristics(
                    serviceUUID: HuaweiHagridProtocol.bodyCompositionServiceUUID,
                    characteristicUUIDs: [
                        HuaweiHagridProtocol.realtimeWeightCharacteristicUUID
                    ]
                ))
            }
            return actions
        case .characteristicsDiscovered(let serviceUUID, let characteristicUUIDs):
            return characteristicUUIDs.filter {
                Self.requiredNotificationCharacteristics.contains($0)
                    && serviceUUID == self.serviceUUID(for: $0)
            }
                .sorted()
                .map { .subscribe(target(characteristicUUID: $0)) }
        case .notificationStateChanged(
            let serviceUUID,
            let characteristicUUID,
            let isNotifying,
            _
        ):
            guard serviceUUID == self.serviceUUID(for: characteristicUUID) else { return [] }
            if isNotifying {
                notifyingCharacteristics.insert(characteristicUUID.uppercased())
            } else {
                notifyingCharacteristics.remove(characteristicUUID.uppercased())
            }
            guard handshakeState == .awaitingChallenge,
                  !didSendAuthenticationProbe,
                  Self.requiredNotificationCharacteristics.isSubset(of: notifyingCharacteristics) else {
                return []
            }
            didSendAuthenticationProbe = true
            return plainWrite(
                Data(),
                characteristicUUID: HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID
            )
        case .notification(let serviceUUID, let characteristicUUID, let payload, let receivedAt):
            guard serviceUUID == self.serviceUUID(for: characteristicUUID) else { return [] }
            return try consumeNotification(
                payload,
                characteristicUUID: characteristicUUID,
                receivedAt: receivedAt
            )
        case .writeCompleted(_, _, let succeeded):
            guard succeeded else {
                handshakeState = .failed
                return [
                    .cancelTimer(id: TimerID.statusPoll),
                    .failSession(.writeFailed)
                ]
            }
            return []
        case .timer(let id):
            guard id == TimerID.statusPoll, handshakeState == .ready,
                  statusPollCount < 30 else { return [] }
            statusPollCount += 1
            return plainWrite(
                Data(),
                characteristicUUID: HuaweiHagridProtocol.measurementStatusPollCharacteristicUUID
            ) + [.scheduleTimer(id: TimerID.statusPoll, seconds: 3)]
        }
    }

    private func consumeNotification(
        _ data: Data,
        characteristicUUID: String,
        receivedAt: Date
    ) throws -> [ScaleProtocolAction] {
        let characteristicUUID = characteristicUUID.uppercased()
        let frame = try HuaweiHagridProtocol.parseNotificationFrame(data)
        var accumulator = notificationAccumulators[characteristicUUID] ?? .init()
        let completed = accumulator.ingest(frame)
        notificationAccumulators[characteristicUUID] = accumulator
        guard let completed else { return [] }

        do {
            switch characteristicUUID {
            case HuaweiHagridProtocol.requestAuthenticationCharacteristicUUID:
                return try handleChallenge(completed)
            case HuaweiHagridProtocol.authenticationTokenCharacteristicUUID:
                return try handleAuthenticationResponse(completed)
            case HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID:
                return try handleWorkKeyAcknowledgement(completed)
            case HuaweiHagridProtocol.setUserInfoCharacteristicUUID:
                return handleUserInfoAcknowledgement(completed)
            case HuaweiHagridProtocol.realtimeWeightCharacteristicUUID:
                return try handleRealtimeMeasurement(completed, receivedAt: receivedAt)
            case HuaweiHagridProtocol.measurementStatusResultCharacteristicUUID:
                return try handleMeasurementStatus(completed)
            default:
                return []
            }
        } catch {
            // Measurement corruption must not tear down an authenticated session;
            // later notifications can still contain a valid final result.
            guard handshakeState != .ready else { return [] }
            handshakeState = .failed
            return [
                .cancelTimer(id: TimerID.statusPoll),
                .failSession(.invalidResponse)
            ]
        }
    }

    private func handleChallenge(
        _ notification: HuaweiHagridProtocol.CompletedNotification
    ) throws -> [ScaleProtocolAction] {
        guard handshakeState == .awaitingChallenge, !notification.isEncrypted else {
            throw ScalePayloadError.unsupported
        }
        let challenge = try HuaweiHagridProtocol.parseAuthenticationChallenge(notification.payload)
        let clientRandom = try validatedRandomData()
        let token = try HuaweiHagridProtocol.makeAuthenticationTokenPayload(
            challenge: challenge,
            randomB: clientRandom,
            cak: credentials.cak
        )
        randomA = challenge
        randomB = clientRandom
        handshakeState = .awaitingAuthenticationResponse
        return plainWrite(
            token,
            characteristicUUID: HuaweiHagridProtocol.authenticationTokenCharacteristicUUID
        )
    }

    private func handleAuthenticationResponse(
        _ notification: HuaweiHagridProtocol.CompletedNotification
    ) throws -> [ScaleProtocolAction] {
        guard handshakeState == .awaitingAuthenticationResponse,
              !notification.isEncrypted,
              let randomA,
              let randomB else { throw ScalePayloadError.unsupported }
        let expected = try HuaweiHagridProtocol.expectedAuthenticationResponse(
            challenge: randomA,
            randomB: randomB,
            cak: credentials.cak
        )
        guard notification.payload == expected else { throw ScalePayloadError.unsupported }

        let newWorkKey = try validatedRandomData()
        workKey = newWorkKey
        handshakeState = .awaitingWorkKeyAcknowledgement
        return try encryptedWrite(
            newWorkKey,
            key: HuaweiHagridProtocol.deriveRootKey(credentials: credentials),
            characteristicUUID: HuaweiHagridProtocol.sendWorkKeyCharacteristicUUID
        )
    }

    private func handleWorkKeyAcknowledgement(
        _ notification: HuaweiHagridProtocol.CompletedNotification
    ) throws -> [ScaleProtocolAction] {
        guard handshakeState == .awaitingWorkKeyAcknowledgement,
              !notification.isEncrypted,
              notification.payload.first == 0,
              let workKey else { throw ScalePayloadError.unsupported }

        let compactAddress = credentials.bluetoothAddressText.replacingOccurrences(of: ":", with: "")
        let compactProfileID = profile.id.uuidString.replacingOccurrences(of: "-", with: "")
        let gender: UInt8 = if usesScale3GenderEncoding {
            profile.biologicalSex == .male ? 1 : 0
        } else {
            profile.biologicalSex == .male ? 0 : 1
        }
        let userInfo = HuaweiHagridProtocol.makeUserInfoPayload(
            huid: "scaleme:\(compactAddress)",
            uid: "u:\(compactProfileID.prefix(30))",
            gender: gender,
            ageYears: UInt8(clamping: profile.age),
            heightCM: UInt16(clamping: Int(profile.heightCM.rounded())),
            weightKG: 0
        )
        handshakeState = .awaitingUserInfoAcknowledgement
        return plainWrite(
            HuaweiHagridProtocol.makeCurrentTimePayload(),
            serviceUUID: HuaweiHagridProtocol.currentTimeServiceUUID,
            characteristicUUID: HuaweiHagridProtocol.currentTimeCharacteristicUUID
        ) + (try encryptedWrite(
            userInfo,
            key: workKey,
            characteristicUUID: HuaweiHagridProtocol.setUserInfoCharacteristicUUID
        ))
    }

    private func handleUserInfoAcknowledgement(
        _ notification: HuaweiHagridProtocol.CompletedNotification
    ) -> [ScaleProtocolAction] {
        guard handshakeState == .awaitingUserInfoAcknowledgement,
              !notification.isEncrypted,
              notification.payload.first == 0 else {
            handshakeState = .failed
            return []
        }
        handshakeState = .ready
        statusPollCount = 1
        return plainWrite(
            Data(),
            characteristicUUID: HuaweiHagridProtocol.realtimeWeightCharacteristicUUID
        ) + plainWrite(
            Data(),
            characteristicUUID: HuaweiHagridProtocol.measurementStatusPollCharacteristicUUID
        ) + [.scheduleTimer(id: TimerID.statusPoll, seconds: 3)]
    }

    private func handleRealtimeMeasurement(
        _ notification: HuaweiHagridProtocol.CompletedNotification,
        receivedAt: Date
    ) throws -> [ScaleProtocolAction] {
        guard handshakeState == .ready,
              notification.isEncrypted,
              let workKey else { throw ScalePayloadError.unsupported }
        let plaintext = try HuaweiHagridProtocol.decryptPayloadWithIV(
            notification.payload,
            key: workKey
        )
        let parsed = try HuaweiHagridProtocol.parseRealtimeMeasurement(plaintext)
        let measurement = BodyMeasurement(
            date: receivedAt,
            weightKG: parsed.weightKG,
            impedanceOhm: parsed.representativeLowImpedanceOhm,
            secondaryImpedanceOhm: parsed.representativeHighImpedanceOhm,
            bodyFatPercent: parsed.deviceFatPercent,
            source: .huaweiHagrid,
            isStable: true,
            profileID: profile.id
        )
        return [
            .cancelTimer(id: TimerID.statusPoll),
            .emit(.measurement(measurement), reliability: .protocolFinal)
        ]
    }

    private func handleMeasurementStatus(
        _ notification: HuaweiHagridProtocol.CompletedNotification
    ) throws -> [ScaleProtocolAction] {
        guard handshakeState == .ready, !notification.isEncrypted else {
            throw ScalePayloadError.unsupported
        }
        let frame = HuaweiHagridProtocol.NotificationFrame(
            isEncrypted: false,
            totalFrames: 1,
            frameIndex: 0,
            payload: notification.payload
        )
        switch try HuaweiHagridProtocol.parseMeasurementStatus(frame) {
        case .ready:
            return plainWrite(
                Data(),
                characteristicUUID: HuaweiHagridProtocol.realtimeWeightCharacteristicUUID
            )
        case .measuring:
            return [.reportLivePhase(.measuringWeight)]
        case .unknown:
            return []
        }
    }

    private func plainWrite(
        _ payload: Data,
        serviceUUID: String? = nil,
        characteristicUUID: String
    ) -> [ScaleProtocolAction] {
        let serviceUUID = serviceUUID ?? self.serviceUUID(for: characteristicUUID)
        return HuaweiHagridProtocol.makePlainWriteFrames(payload: payload).map {
            .write(command(payload: $0, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID))
        }
    }

    private func encryptedWrite(
        _ payload: Data,
        key: Data,
        characteristicUUID: String
    ) throws -> [ScaleProtocolAction] {
        let frames = try HuaweiHagridProtocol.makeEncryptedWriteFrames(
            payload: payload,
            key: key,
            iv: validatedRandomData()
        )
        return frames.map {
            .write(command(payload: $0, characteristicUUID: characteristicUUID))
        }
    }

    private func command(
        payload: Data,
        serviceUUID: String = HuaweiHagridProtocol.userDataServiceUUID,
        characteristicUUID: String
    ) -> CommunicationCommand {
        CommunicationCommand(
            target: .init(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID),
            payloadHexTemplate: payload.map { String(format: "%02X", $0) }.joined(),
            writeMode: .withResponse
        )
    }

    private func target(characteristicUUID: String) -> CommunicationGATTTarget {
        .init(
            serviceUUID: serviceUUID(for: characteristicUUID),
            characteristicUUID: characteristicUUID
        )
    }

    private func serviceUUID(for characteristicUUID: String) -> String {
        switch characteristicUUID.uppercased() {
        case HuaweiHagridProtocol.currentTimeCharacteristicUUID,
             HuaweiHagridProtocol.measurementStatusPollCharacteristicUUID,
             HuaweiHagridProtocol.measurementStatusResultCharacteristicUUID:
            HuaweiHagridProtocol.currentTimeServiceUUID
        case HuaweiHagridProtocol.realtimeWeightCharacteristicUUID,
             HuaweiHagridProtocol.historyWeightCharacteristicUUID:
            HuaweiHagridProtocol.bodyCompositionServiceUUID
        default:
            HuaweiHagridProtocol.userDataServiceUUID
        }
    }

    private func validatedRandomData() throws -> Data {
        let data = try randomData(16)
        guard data.count == 16 else { throw ScalePayloadError.unsupported }
        return data
    }

    private func reset() {
        handshakeState = .idle
        didSendAuthenticationProbe = false
        notifyingCharacteristics.removeAll()
        notificationAccumulators.removeAll()
        randomA = nil
        randomB = nil
        workKey = nil
        statusPollCount = 0
    }

    private static func secureRandomData(count: Int) throws -> Data {
        var data = Data(repeating: 0, count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard status == errSecSuccess else { throw ScalePayloadError.unsupported }
        return data
    }
}
