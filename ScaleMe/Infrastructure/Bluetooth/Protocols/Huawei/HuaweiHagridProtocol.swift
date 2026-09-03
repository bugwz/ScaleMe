import CryptoKit
import Foundation

/// Huawei Scale 2/3 "Hagrid" devices expose WSP commands through GATT
/// characteristics placed under otherwise standard-looking services. Measurement
/// traffic remains unavailable until the device-specific CAK/C1/C2 handshake has
/// completed. CoreBluetooth does not expose a peripheral's Bluetooth address, so
/// the address used to derive C3 is stored with the other device credentials.
enum HuaweiHagridProtocol {
    struct Credentials: Equatable, Sendable {
        private static let encodingVersion: UInt8 = 1

        let bluetoothAddress: Data
        let cak: Data
        let c1: Data
        let c2: Data

        init(bluetoothAddress: Data, cak: Data, c1: Data, c2: Data) throws {
            guard bluetoothAddress.count == 6,
                  cak.count == 16, c1.count == 16, c2.count == 16 else {
                throw ScalePayloadError.unsupported
            }
            self.bluetoothAddress = bluetoothAddress
            self.cak = cak
            self.c1 = c1
            self.c2 = c2
        }

        init(bluetoothAddress: String, cakHex: String, c1Hex: String, c2Hex: String) throws {
            try self.init(
                bluetoothAddress: HuaweiHagridProtocol.bluetoothAddressData(from: bluetoothAddress),
                cak: HuaweiHagridProtocol.credentialData(from: cakHex),
                c1: HuaweiHagridProtocol.credentialData(from: c1Hex),
                c2: HuaweiHagridProtocol.credentialData(from: c2Hex)
            )
        }

        var bluetoothAddressText: String {
            bluetoothAddress.map { String(format: "%02X", $0) }.joined(separator: ":")
        }

        var encoded: Data {
            Data([Self.encodingVersion]) + bluetoothAddress + cak + c1 + c2
        }

        init(encoded: Data) throws {
            guard encoded.count == 55, encoded.first == Self.encodingVersion else {
                throw ScalePayloadError.unsupported
            }
            try self.init(
                bluetoothAddress: Data(encoded[1..<7]),
                cak: Data(encoded[7..<23]),
                c1: Data(encoded[23..<39]),
                c2: Data(encoded[39..<55])
            )
        }
    }

    struct WeightMeasurement: Equatable, Sendable {
        let weightKG: Double
        let deviceFatPercent: Double
        let timestamp: Date?
        let lowFrequencyImpedance: [UInt16]
        let highFrequencyImpedance: [UInt16]
        let heartRateBPM: Int?
        let historyComplete: Bool?

        var representativeLowImpedanceOhm: Double? {
            lowFrequencyImpedance.lazy.compactMap(Self.impedanceOhm).first
        }

        var representativeHighImpedanceOhm: Double? {
            highFrequencyImpedance.lazy.compactMap(Self.impedanceOhm).first
        }

        private static func impedanceOhm(_ value: UInt16) -> Double? {
            switch value {
            case 1...3_999: Double(value)
            case 4_000...39_999: Double(value) / 10
            default: nil
            }
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
    static let authenticationTokenCharacteristicUUID = "32330A04-15D9-421A-91C5-2A2D5C7525C9"
    static let sendWorkKeyCharacteristicUUID = "A3D330F8-B84F-4F48-A78C-F8D1E33B597A"
    static let bindRequestCharacteristicUUID = "42596CBE-D291-4DA3-8CA6-D1AE5D1C9174"
    static let setUserInfoCharacteristicUUID = "8CC61D7D-66C0-4802-89C3-38C5A163592E"
    static let getManagerInfoCharacteristicUUID = "4338C65E-ED8E-4085-BBEA-A25E33CA6B54"
    static let currentTimeServiceUUID = "1805"
    static let currentTimeCharacteristicUUID = "2A2B"
    static let scaleVersionCharacteristicUUID = "1F5D3D5C-496D-4290-AF03-C7A8D5419741"
    static let weightUnitCharacteristicUUID = "7E6DBC73-42E7-45B9-A6EC-6AA2D7834695"
    static let measurementStatusPollCharacteristicUUID = "BFC36F6E-4150-4A4B-9052-3D359E52962E"
    static let realtimeWeightCharacteristicUUID = "46797C17-D639-488D-9476-4789E8472878"
    static let historyWeightCharacteristicUUID = "0212F42A-5F19-4BC1-BA52-D7EC7CCB71A4"
    static let measurementStatusResultCharacteristicUUID = "BA216311-1787-472B-BEF6-3EB29E62293E"

    private static let writePlainPrefix: UInt8 = 0xDB
    private static let writeEncryptedPrefix: UInt8 = 0xDC
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
        sessionNotificationCharacteristicUUIDs.contains(characteristicUUID.uppercased())
    }

    static let sessionNotificationCharacteristicUUIDs: Set<String> = [
        requestAuthenticationCharacteristicUUID,
        authenticationTokenCharacteristicUUID,
        sendWorkKeyCharacteristicUUID,
        setUserInfoCharacteristicUUID,
        currentTimeCharacteristicUUID,
        scaleVersionCharacteristicUUID,
        weightUnitCharacteristicUUID,
        measurementStatusPollCharacteristicUUID,
        measurementStatusResultCharacteristicUUID,
        realtimeWeightCharacteristicUUID,
        historyWeightCharacteristicUUID
    ]

    static let sessionWriteCharacteristicUUIDs: Set<String> = [
        requestAuthenticationCharacteristicUUID,
        authenticationTokenCharacteristicUUID,
        sendWorkKeyCharacteristicUUID,
        setUserInfoCharacteristicUUID,
        currentTimeCharacteristicUUID,
        measurementStatusPollCharacteristicUUID,
        realtimeWeightCharacteristicUUID,
        historyWeightCharacteristicUUID
    ]

    static func isSessionCharacteristic(_ characteristicUUID: String) -> Bool {
        let normalized = characteristicUUID.uppercased()
        return sessionNotificationCharacteristicUUIDs.contains(normalized)
            || sessionWriteCharacteristicUUIDs.contains(normalized)
    }

    static func makeAuthenticationProbe() -> Data {
        makePlainWriteFrames(payload: Data()).first ?? Data()
    }

    static func makePlainWriteFrames(payload: Data) -> [Data] {
        makeWriteFrames(payload: payload, encrypted: false)
    }

    static func makeEncryptedWriteFrames(payload: Data, key: Data, iv: Data) throws -> [Data] {
        let encrypted = try encryptedPayloadWithIV(payload, key: key, iv: iv)
        return makeWriteFrames(payload: encrypted, encrypted: true)
    }

    private static func makeWriteFrames(payload: Data, encrypted: Bool) -> [Data] {
        precondition(payload.count <= maximumChunkLength * 16)
        let bytes = [UInt8](payload)
        let frameCount = max(1, (bytes.count + maximumChunkLength - 1) / maximumChunkLength)
        return (0..<frameCount).map { index in
            let start = index * maximumChunkLength
            let end = min(start + maximumChunkLength, bytes.count)
            let chunk = start < end ? Array(bytes[start..<end]) : []
            var frame = [encrypted ? writeEncryptedPrefix : writePlainPrefix, UInt8(chunk.count + 3)]
            frame.append(UInt8(((frameCount - 1) << 4) | index))
            frame.append(contentsOf: chunk)
            frame.append(contentsOf: [0, 0])
            let checksum = crc16CCITT(frame)
            frame[frame.count - 2] = UInt8(checksum & 0xFF)
            frame[frame.count - 1] = UInt8(checksum >> 8)
            return Data(frame)
        }
    }

    static func makeAuthenticationTokenPayload(
        challenge randomA: Data,
        randomB: Data,
        cak: Data
    ) throws -> Data {
        guard randomA.count == 16, randomB.count == 16, cak.count == 16 else {
            throw ScalePayloadError.unsupported
        }
        return randomB + authenticationToken(
            randomA: randomA,
            randomB: randomB,
            cak: cak,
            suffix: Data("1123".utf8)
        )
    }

    static func expectedAuthenticationResponse(
        challenge randomA: Data,
        randomB: Data,
        cak: Data
    ) throws -> Data {
        guard randomA.count == 16, randomB.count == 16, cak.count == 16 else {
            throw ScalePayloadError.unsupported
        }
        return authenticationToken(
            randomA: randomA,
            randomB: randomB,
            cak: cak,
            suffix: Data("9856".utf8)
        )
    }

    static func deriveRootKey(credentials: Credentials) -> Data {
        let mixed = zip(credentials.c1, credentials.c2).map {
            UInt8((Int($0.0) << 4 ^ Int($0.1)) & 0xFF)
        }
        let firstDigest = Data(SHA256.hash(data: Data(mixed)).prefix(16))
        let address = credentials.bluetoothAddress
            .map { String(format: "%02X", $0) }
            .joined()
        let c3 = [UInt8](Data((address + "0000").utf8))
        let folded = zip(firstDigest, c3).map {
            ($0.0 >> 6) ^ $0.1
        }
        return Data(SHA256.hash(data: Data(folded)).prefix(16))
    }

    static func encryptedPayloadWithIV(_ plaintext: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == 16, iv.count == 16 else { throw ScalePayloadError.unsupported }
        return iv + Data(AES128CTR.crypt([UInt8](plaintext), key: [UInt8](key), iv: [UInt8](iv)))
    }

    static func decryptPayloadWithIV(_ payload: Data, key: Data) throws -> Data {
        guard payload.count >= 16, key.count == 16 else { throw ScalePayloadError.tooShort }
        let iv = Data(payload.prefix(16))
        let ciphertext = Data(payload.dropFirst(16))
        return Data(AES128CTR.crypt([UInt8](ciphertext), key: [UInt8](key), iv: [UInt8](iv)))
    }

    static func parseRealtimeMeasurement(_ payload: Data) throws -> WeightMeasurement {
        try parseWeightMeasurement(payload, allowedLengths: [26, 38], requiresTimestamp: false)
    }

    static func parseHistoryMeasurement(_ payload: Data) throws -> WeightMeasurement {
        try parseWeightMeasurement(payload, allowedLengths: [27, 28, 39, 40], requiresTimestamp: true)
    }

    static func makeCurrentTimePayload(date: Date = .now, calendar: Calendar = .current) -> Data {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday],
            from: date
        )
        let year = components.year ?? 0
        let weekday = ((components.weekday ?? 1) + 5) % 7 + 1
        return Data([
            UInt8(year & 0xFF), UInt8((year >> 8) & 0xFF),
            UInt8(components.month ?? 0), UInt8(components.day ?? 0),
            UInt8(components.hour ?? 0), UInt8(components.minute ?? 0),
            UInt8(components.second ?? 0), UInt8(weekday)
        ])
    }

    static func makeUserInfoPayload(
        huid: String,
        uid: String,
        gender: UInt8,
        ageYears: UInt8,
        heightCM: UInt16,
        weightKG: Double,
        userType: UInt8 = 0
    ) -> Data {
        var payload = Data(repeating: 0, count: 69)
        copyUTF8(huid, to: &payload, at: 0, maximumLength: 30)
        copyUTF8(uid, to: &payload, at: 30, maximumLength: 32)
        payload[62] = gender
        payload[63] = ageYears
        payload[64] = UInt8(heightCM & 0xFF)
        payload[65] = UInt8(heightCM >> 8)
        let centiKG = weightKG.isFinite && weightKG > 0
            ? UInt16(clamping: Int((weightKG * 100).rounded()))
            : 0
        payload[66] = UInt8(centiKG & 0xFF)
        payload[67] = UInt8(centiKG >> 8)
        payload[68] = userType
        return payload
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

    private static func authenticationToken(
        randomA: Data,
        randomB: Data,
        cak: Data,
        suffix: Data
    ) -> Data {
        let random = randomA + randomB
        let innerKey = SymmetricKey(data: cak + suffix)
        let inner = Data(HMAC<SHA256>.authenticationCode(for: random, using: innerKey))
        return Data(HMAC<SHA256>.authenticationCode(
            for: random,
            using: SymmetricKey(data: inner)
        ))
    }

    private static func parseWeightMeasurement(
        _ payload: Data,
        allowedLengths: Set<Int>,
        requiresTimestamp: Bool
    ) throws -> WeightMeasurement {
        let bytes = [UInt8](payload)
        guard allowedLengths.contains(bytes.count) else { throw ScalePayloadError.unsupported }
        let hasHighFrequency = bytes.count >= 38
        let baseLength = hasHighFrequency ? 38 : 26
        let weightKG = Double(u16LE(bytes, at: 0)) / 100
        let fatPercent = Double(u16LE(bytes, at: 2)) / 10
        guard (1...350).contains(weightKG), (0...80).contains(fatPercent) else {
            throw ScalePayloadError.unsupported
        }

        let timestamp = timestamp(from: bytes, at: 4)
        if requiresTimestamp, timestamp == nil { throw ScalePayloadError.unsupported }

        let low = stride(from: 12, to: 24, by: 2).map { u16LE(bytes, at: $0) }
        let high = hasHighFrequency
            ? stride(from: 26, to: 38, by: 2).map { u16LE(bytes, at: $0) }
            : []
        let heartRateRaw = Int(u16LE(bytes, at: 24))
        let heartRate = (1...240).contains(heartRateRaw) ? heartRateRaw : nil
        let historyComplete = bytes.count > baseLength + 1 ? bytes[baseLength + 1] == 0 : nil

        return WeightMeasurement(
            weightKG: weightKG,
            deviceFatPercent: fatPercent,
            timestamp: timestamp,
            lowFrequencyImpedance: low,
            highFrequencyImpedance: high,
            heartRateBPM: heartRate,
            historyComplete: historyComplete
        )
    }

    private static func u16LE(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func timestamp(from bytes: [UInt8], at offset: Int) -> Date? {
        guard bytes.count >= offset + 7 else { return nil }
        let year = Int(u16LE(bytes, at: offset))
        let month = Int(bytes[offset + 2])
        let day = Int(bytes[offset + 3])
        let hour = Int(bytes[offset + 4])
        let minute = Int(bytes[offset + 5])
        let second = Int(bytes[offset + 6])
        guard year >= 2000, (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let date = calendar.date(from: components) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard verified.year == year, verified.month == month, verified.day == day,
              verified.hour == hour, verified.minute == minute, verified.second == second else {
            return nil
        }
        return date
    }

    private static func copyUTF8(
        _ value: String,
        to payload: inout Data,
        at offset: Int,
        maximumLength: Int
    ) {
        for (index, byte) in value.utf8.prefix(maximumLength).enumerated() {
            payload[offset + index] = byte
        }
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

    private static func bluetoothAddressData(from value: String) throws -> Data {
        let compact = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0 != ":" && $0 != "-" }
        guard compact.count == 12, compact.allSatisfy(\.isHexDigit) else {
            throw ScalePayloadError.unsupported
        }
        var result = Data(capacity: 6)
        var index = compact.startIndex
        for _ in 0..<6 {
            let next = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<next], radix: 16) else {
                throw ScalePayloadError.unsupported
            }
            result.append(byte)
            index = next
        }
        return result
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

private enum AES128CTR {
    private static let substitutionBox: [UInt8] = [
        0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
        0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
        0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
        0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
        0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
        0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
        0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
        0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
        0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
        0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
        0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
        0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
        0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
        0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
        0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
        0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16
    ]

    static func crypt(_ input: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8] {
        precondition(key.count == 16 && iv.count == 16)
        let roundKeys = expandedKey(key)
        var counter = iv
        var output = [UInt8](repeating: 0, count: input.count)
        var offset = 0
        while offset < input.count {
            let stream = encryptBlock(counter, roundKeys: roundKeys)
            let count = min(16, input.count - offset)
            for index in 0..<count {
                output[offset + index] = input[offset + index] ^ stream[index]
            }
            increment(&counter)
            offset += count
        }
        return output
    }

    private static func expandedKey(_ key: [UInt8]) -> [UInt8] {
        var expanded = key
        expanded.reserveCapacity(176)
        var rcon: UInt8 = 1
        while expanded.count < 176 {
            var word = Array(expanded.suffix(4))
            if expanded.count.isMultiple(of: 16) {
                word = [word[1], word[2], word[3], word[0]]
                word = word.map { substitutionBox[Int($0)] }
                word[0] ^= rcon
                rcon = multiplyByX(rcon)
            }
            for byte in word {
                expanded.append(expanded[expanded.count - 16] ^ byte)
            }
        }
        return expanded
    }

    private static func encryptBlock(_ input: [UInt8], roundKeys: [UInt8]) -> [UInt8] {
        var state = input
        addRoundKey(&state, roundKeys: roundKeys, offset: 0)
        for round in 1..<10 {
            state = state.map { substitutionBox[Int($0)] }
            shiftRows(&state)
            mixColumns(&state)
            addRoundKey(&state, roundKeys: roundKeys, offset: round * 16)
        }
        state = state.map { substitutionBox[Int($0)] }
        shiftRows(&state)
        addRoundKey(&state, roundKeys: roundKeys, offset: 160)
        return state
    }

    private static func addRoundKey(_ state: inout [UInt8], roundKeys: [UInt8], offset: Int) {
        for index in 0..<16 { state[index] ^= roundKeys[offset + index] }
    }

    private static func shiftRows(_ state: inout [UInt8]) {
        let original = state
        state[1] = original[5]
        state[5] = original[9]
        state[9] = original[13]
        state[13] = original[1]

        state[2] = original[10]
        state[6] = original[14]
        state[10] = original[2]
        state[14] = original[6]

        state[3] = original[15]
        state[7] = original[3]
        state[11] = original[7]
        state[15] = original[11]
    }

    private static func mixColumns(_ state: inout [UInt8]) {
        for column in 0..<4 {
            let offset = column * 4
            let a = Array(state[offset..<(offset + 4)])
            let all = a[0] ^ a[1] ^ a[2] ^ a[3]
            state[offset] = a[0] ^ all ^ multiplyByX(a[0] ^ a[1])
            state[offset + 1] = a[1] ^ all ^ multiplyByX(a[1] ^ a[2])
            state[offset + 2] = a[2] ^ all ^ multiplyByX(a[2] ^ a[3])
            state[offset + 3] = a[3] ^ all ^ multiplyByX(a[3] ^ a[0])
        }
    }

    private static func multiplyByX(_ value: UInt8) -> UInt8 {
        (value << 1) ^ ((value & 0x80) == 0 ? 0 : 0x1B)
    }

    private static func increment(_ counter: inout [UInt8]) {
        for index in stride(from: counter.count - 1, through: 0, by: -1) {
            counter[index] &+= 1
            if counter[index] != 0 { return }
        }
    }
}
