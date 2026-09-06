import CommonCrypto
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
    static let bodyCompositionServiceUUID = "181B"

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
        return iv + (try cryptAES128CTR(plaintext, key: key, iv: iv))
    }

    static func decryptPayloadWithIV(_ payload: Data, key: Data) throws -> Data {
        guard payload.count >= 16, key.count == 16 else { throw ScalePayloadError.tooShort }
        let iv = Data(payload.prefix(16))
        let ciphertext = Data(payload.dropFirst(16))
        return try cryptAES128CTR(ciphertext, key: key, iv: iv)
    }

    private static func cryptAES128CTR(_ input: Data, key: Data, iv: Data) throws -> Data {
        guard !input.isEmpty else { return Data() }

        var cryptor: CCCryptorRef?
        let createStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                CCCryptorCreateWithMode(
                    CCOperation(kCCEncrypt),
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    ivBytes.baseAddress,
                    keyBytes.baseAddress,
                    key.count,
                    nil,
                    0,
                    0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }
        guard createStatus == kCCSuccess, let cryptor else {
            throw ScalePayloadError.unsupported
        }
        defer { CCCryptorRelease(cryptor) }

        var output = Data(count: input.count)
        let outputCapacity = output.count
        var outputLength = 0
        let updateStatus = output.withUnsafeMutableBytes { outputBytes in
            input.withUnsafeBytes { inputBytes in
                CCCryptorUpdate(
                    cryptor,
                    inputBytes.baseAddress,
                    input.count,
                    outputBytes.baseAddress,
                    outputCapacity,
                    &outputLength
                )
            }
        }
        guard updateStatus == kCCSuccess, outputLength == input.count else {
            throw ScalePayloadError.unsupported
        }
        return output
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
