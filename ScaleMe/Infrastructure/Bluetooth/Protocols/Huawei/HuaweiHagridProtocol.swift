import Foundation

/// Huawei Scale 2/3 "Hagrid" devices expose WSP commands through GATT
/// characteristics placed under otherwise standard-looking services. Measurement
/// traffic remains unavailable until the device-specific CAK/C1/C2 handshake has
/// completed; this type intentionally implements only identity and probe framing.
enum HuaweiHagridProtocol {
    struct Credentials: Equatable, Sendable {
        let cak: Data
        let c1: Data
        let c2: Data

        init(cak: Data, c1: Data, c2: Data) throws {
            guard cak.count == 16, c1.count == 16, c2.count == 16 else {
                throw ScalePayloadError.unsupported
            }
            self.cak = cak
            self.c1 = c1
            self.c2 = c2
        }

        init(cakHex: String, c1Hex: String, c2Hex: String) throws {
            try self.init(
                cak: HuaweiHagridProtocol.credentialData(from: cakHex),
                c1: HuaweiHagridProtocol.credentialData(from: c1Hex),
                c2: HuaweiHagridProtocol.credentialData(from: c2Hex)
            )
        }

        var encoded: Data {
            cak + c1 + c2
        }

        init(encoded: Data) throws {
            guard encoded.count == 48 else { throw ScalePayloadError.unsupported }
            try self.init(
                cak: Data(encoded[0..<16]),
                c1: Data(encoded[16..<32]),
                c2: Data(encoded[32..<48])
            )
        }
    }

    enum MeasurementStatus: Equatable {
        case ready
        case measuring
        case unknown(UInt8)
    }

    static let advertisementServiceUUID = "FDEE"
    static let userDataServiceUUID = "181C"

    static let requestAuthenticationCharacteristicUUID = "02B2A08E-F8B0-4047-B1FD-F4E0EFEEE679"
    static let realtimeWeightCharacteristicUUID = "46797C17-D639-488D-9476-4789E8472878"
    static let measurementStatusResultCharacteristicUUID = "BA216311-1787-472B-BEF6-3EB29E62293E"

    private static let writePlainPrefix: UInt8 = 0xDB
    private static let notificationPlainPrefix: UInt8 = 0xBD
    private static let notificationEncryptedPrefix: UInt8 = 0xCD
    private static let maximumChunkLength = 15

    struct NotificationFrame: Equatable {
        var isEncrypted: Bool
        var totalFrames: Int
        var frameIndex: Int
        var payload: Data
    }

    struct CompletedNotification: Equatable {
        var isEncrypted: Bool
        var payload: Data
    }

    struct NotificationAccumulator {
        private var expectedFrames = 0
        private var isEncrypted = false
        private var chunks: [Int: Data] = [:]

        mutating func ingest(_ frame: NotificationFrame) -> CompletedNotification? {
            if frame.totalFrames == 1 {
                reset()
                return CompletedNotification(isEncrypted: frame.isEncrypted, payload: frame.payload)
            }

            if frame.frameIndex == 0 {
                reset()
                expectedFrames = frame.totalFrames
                isEncrypted = frame.isEncrypted
            } else if expectedFrames == 0
                        || expectedFrames != frame.totalFrames
                        || isEncrypted != frame.isEncrypted {
                reset()
                return nil
            }

            chunks[frame.frameIndex] = frame.payload
            guard chunks.count == expectedFrames else { return nil }

            var payload = Data()
            for index in 0..<expectedFrames {
                guard let chunk = chunks[index] else {
                    reset()
                    return nil
                }
                payload.append(chunk)
            }
            let completed = CompletedNotification(isEncrypted: isEncrypted, payload: payload)
            reset()
            return completed
        }

        mutating func reset() {
            expectedFrames = 0
            isEncrypted = false
            chunks.removeAll(keepingCapacity: true)
        }
    }

    static func matchesIdentity(name: String, serviceDataUUIDs: Set<String>) -> Bool {
        let normalizedServices = Set(serviceDataUUIDs.map(CommunicationRuleCodec.normalizeUUID))
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedServices.contains(advertisementServiceUUID)
            && normalizedName.contains("huawei")
            && normalizedName.contains("scale")
    }

    static func isRequestAuthentication(serviceUUID: String, characteristicUUID: String) -> Bool {
        CommunicationRuleCodec.normalizeUUID(serviceUUID) == userDataServiceUUID
            && characteristicUUID.uppercased() == requestAuthenticationCharacteristicUUID
    }

    static func isRequestAuthenticationCharacteristic(_ characteristicUUID: String) -> Bool {
        characteristicUUID.uppercased() == requestAuthenticationCharacteristicUUID
    }

    static func isRealtimeWeightCharacteristic(_ characteristicUUID: String) -> Bool {
        characteristicUUID.uppercased() == realtimeWeightCharacteristicUUID
    }

    static func isMeasurementStatusResultCharacteristic(_ characteristicUUID: String) -> Bool {
        characteristicUUID.uppercased() == measurementStatusResultCharacteristicUUID
    }

    static func isProbeNotificationCharacteristic(_ characteristicUUID: String) -> Bool {
        isRequestAuthenticationCharacteristic(characteristicUUID)
            || isRealtimeWeightCharacteristic(characteristicUUID)
            || isMeasurementStatusResultCharacteristic(characteristicUUID)
    }

    static func makeAuthenticationProbe() -> Data {
        makePlainWriteFrames(payload: Data()).first ?? Data()
    }

    static func makePlainWriteFrames(payload: Data) -> [Data] {
        precondition(payload.count <= maximumChunkLength * 16)
        let bytes = [UInt8](payload)
        let frameCount = max(1, (bytes.count + maximumChunkLength - 1) / maximumChunkLength)
        return (0..<frameCount).map { index in
            let start = index * maximumChunkLength
            let end = min(start + maximumChunkLength, bytes.count)
            let chunk = start < end ? Array(bytes[start..<end]) : []
            var frame = [writePlainPrefix, UInt8(chunk.count + 3)]
            frame.append(UInt8(((frameCount - 1) << 4) | index))
            frame.append(contentsOf: chunk)
            frame.append(contentsOf: [0, 0])
            let checksum = crc16CCITT(frame)
            frame[frame.count - 2] = UInt8(checksum & 0xFF)
            frame[frame.count - 1] = UInt8(checksum >> 8)
            return Data(frame)
        }
    }

    static func parseNotificationFrame(_ data: Data) throws -> NotificationFrame {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else { throw ScalePayloadError.tooShort }
        guard bytes[0] == notificationPlainPrefix || bytes[0] == notificationEncryptedPrefix else {
            throw ScalePayloadError.unsupported
        }
        let payloadLength = Int(bytes[1]) - 3
        guard payloadLength >= 0, bytes.count == payloadLength + 5 else {
            throw ScalePayloadError.unsupported
        }
        let expectedCRC = UInt16(bytes[bytes.count - 2]) | UInt16(bytes[bytes.count - 1]) << 8
        guard crc16Modbus(Array(bytes.dropLast(2))) == expectedCRC else {
            throw ScalePayloadError.unsupported
        }
        let totalFrames = Int(bytes[2] >> 4) + 1
        let frameIndex = Int(bytes[2] & 0x0F)
        guard frameIndex < totalFrames else { throw ScalePayloadError.unsupported }
        return NotificationFrame(
            isEncrypted: bytes[0] == notificationEncryptedPrefix,
            totalFrames: totalFrames,
            frameIndex: frameIndex,
            payload: Data(bytes[3..<(3 + payloadLength)])
        )
    }

    static func parseMeasurementStatus(_ frame: NotificationFrame) throws -> MeasurementStatus {
        guard frame.payload.count == 1, let value = frame.payload.first else {
            throw ScalePayloadError.unsupported
        }
        switch value {
        case 0x00: return .ready
        case 0x01: return .measuring
        default: return .unknown(value)
        }
    }

    /// Captured Scale 3 firmware appends a zero result byte after the 16-byte
    /// random challenge; some Hagrid variants provide the random value alone.
    static func parseAuthenticationChallenge(_ payload: Data) throws -> Data {
        if payload.count == 16 {
            return payload
        }
        if payload.count == 17, payload.last == 0x00 {
            return Data(payload.prefix(16))
        }
        throw ScalePayloadError.unsupported
    }

    static func normalizedCredentialInput(_ value: String) -> String {
        String(value.uppercased().filter { $0.isHexDigit }.prefix(32))
    }

    private static func credentialData(from value: String) throws -> Data {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 32, normalized.allSatisfy(\.isHexDigit) else {
            throw ScalePayloadError.unsupported
        }
        var data = Data(capacity: 16)
        var index = normalized.startIndex
        for _ in 0..<16 {
            let next = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<next], radix: 16) else {
                throw ScalePayloadError.unsupported
            }
            data.append(byte)
            index = next
        }
        return data
    }

    private static func crc16CCITT(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }

    private static func crc16Modbus(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }
}
