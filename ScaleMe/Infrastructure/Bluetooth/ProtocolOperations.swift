import Foundation

enum CommunicationOperationCapability: String, Codable, Hashable {
    case historyRead
    case historyClear
}

enum CommunicationWriteMode: String, Codable, Hashable {
    case withResponse
    case withoutResponse
    case automatic
}

struct CommunicationGATTTarget: Codable, Equatable, Hashable {
    var serviceUUID: String
    var characteristicUUID: String
}

struct CommunicationCommand: Codable, Equatable, Hashable {
    var target: CommunicationGATTTarget
    var payloadHexTemplate: String
    var writeMode: CommunicationWriteMode = .withResponse
}

struct CommunicationResponseMatcher: Codable, Equatable, Hashable {
    var target: CommunicationGATTTarget
    var minimumLength: Int = 1
    var maximumLength: Int? = nil
    var prefixHex: String? = nil
    var exactHex: String? = nil
}

enum CommunicationRecordFraming: String, Codable, Hashable {
    case notification
    case fixedLength
}

struct CommunicationHistoryResponse: Codable, Equatable, Hashable {
    var recordMatcher: CommunicationResponseMatcher
    var completionMatcher: CommunicationResponseMatcher? = nil
    var framing: CommunicationRecordFraming = .notification
    var recordLength: Int? = nil
    var decoder: CommunicationRuleDecoder? = nil
    var builtInParser: String? = nil
}

struct CommunicationGATTOperation: Codable, Equatable, Hashable {
    var capability: CommunicationOperationCapability
    var destructive: Bool = false
    var subscriptions: [CommunicationGATTTarget]
    var commands: [CommunicationCommand]
    var completionCommands: [CommunicationCommand] = []
    var acknowledgementCommands: [CommunicationCommand] = []
    var historyResponse: CommunicationHistoryResponse? = nil
    var timeoutSeconds: Double = 15
    var maximumResponseBytes: Int = 65_536
    var maximumRecords: Int = 512
}

struct CommunicationRuleOperations: Codable, Equatable, Hashable {
    var historyRead: CommunicationGATTOperation? = nil
    var historyClear: CommunicationGATTOperation? = nil
}

enum CommunicationPayloadTemplate {
    private static let allowedPlaceholders = [
        "{{sessionToken16BE}}",
        "{{currentTimeBLE}}",
        "{{wolaiTimeInitialization}}"
    ]
    private static let responsePattern = try? NSRegularExpression(pattern: #"\{\{response:(\d+):(\d+)\}\}"#)

    static func render(
        _ template: String,
        sessionToken: UInt16,
        now: Date = .now,
        response: Data? = nil
    ) throws -> Data {
        var value = template
        value = value.replacingOccurrences(
            of: "{{sessionToken16BE}}",
            with: String(format: "%04X", sessionToken)
        )
        value = value.replacingOccurrences(
            of: "{{currentTimeBLE}}",
            with: BluetoothCurrentTimeProtocol.payload(for: now).map { String(format: "%02X", $0) }.joined()
        )
        value = value.replacingOccurrences(
            of: "{{wolaiTimeInitialization}}",
            with: WolaiAFUScaleAdapter.makeTimeInitialization(at: now).map { String(format: "%02X", $0) }.joined()
        )
        value = try replacingResponseFields(in: value) { offset, length in
            guard let response, offset >= 0, length > 0, length <= 8,
                  offset + length <= response.count else {
                throw CommunicationRuleError.invalidDocument("命令引用的响应字段不存在或越界")
            }
            return response[offset..<(offset + length)].map { String(format: "%02X", $0) }.joined()
        }
        guard !value.contains("{{") && !value.contains("}}") else {
            throw CommunicationRuleError.invalidDocument("命令包含不受支持的动态字段")
        }
        return Data(try CommunicationRuleCodec.hexBytes(value))
    }

    static func validate(_ template: String) throws {
        var value = template
        value = value.replacingOccurrences(of: allowedPlaceholders[0], with: "0000")
        value = value.replacingOccurrences(of: allowedPlaceholders[1], with: String(repeating: "00", count: 10))
        value = value.replacingOccurrences(of: allowedPlaceholders[2], with: String(repeating: "00", count: 20))
        value = try replacingResponseFields(in: value) { offset, length in
            guard (0...4_095).contains(offset), (1...8).contains(length), offset + length <= 4_096 else {
                throw CommunicationRuleError.invalidDocument("命令引用的响应字段范围无效")
            }
            return String(repeating: "00", count: length)
        }
        guard !value.contains("{{") && !value.contains("}}") else {
            throw CommunicationRuleError.invalidDocument("命令包含不受支持的动态字段")
        }
        let bytes = try CommunicationRuleCodec.hexBytes(value)
        guard !bytes.isEmpty, bytes.count <= 128 else {
            throw CommunicationRuleError.invalidDocument("单条 GATT 命令必须为 1 至 128 字节")
        }
    }

    static func validateExternal(_ template: String) throws {
        guard !template.contains("{{wolaiTimeInitialization}}") else {
            throw CommunicationRuleError.invalidDocument("外部规则不能使用内置协议专用动态字段")
        }
        try validate(template)
    }

    private static func replacingResponseFields(
        in template: String,
        replacement: (Int, Int) throws -> String
    ) throws -> String {
        var value = template
        guard let responsePattern else {
            throw CommunicationRuleError.invalidDocument("响应字段模板不可用")
        }
        let range = NSRange(value.startIndex..., in: value)
        let matches = responsePattern.matches(in: value, range: range)
        for match in matches.reversed() {
            guard let whole = Range(match.range(at: 0), in: value),
                  let offsetRange = Range(match.range(at: 1), in: value),
                  let lengthRange = Range(match.range(at: 2), in: value),
                  let offset = Int(value[offsetRange]),
                  let length = Int(value[lengthRange]) else {
                throw CommunicationRuleError.invalidDocument("响应字段模板无效")
            }
            value.replaceSubrange(whole, with: try replacement(offset, length))
        }
        return value
    }
}

enum CommunicationOperationValidator {
    static func validate(_ operations: CommunicationRuleOperations) throws {
        if let read = operations.historyRead {
            guard read.capability == .historyRead, !read.destructive, read.historyResponse != nil else {
                throw CommunicationRuleError.invalidDocument("historyRead 必须是非破坏性操作并提供历史响应规则")
            }
            try validate(read)
        }
        if let clear = operations.historyClear {
            guard clear.capability == .historyClear, clear.destructive, clear.historyResponse == nil else {
                throw CommunicationRuleError.invalidDocument("historyClear 必须显式标记 destructive，且不能伪装成读取操作")
            }
            try validate(clear)
        }
    }

    private static func validate(_ operation: CommunicationGATTOperation) throws {
        guard (1...60).contains(operation.timeoutSeconds),
              (1...1_048_576).contains(operation.maximumResponseBytes),
              (1...2_000).contains(operation.maximumRecords),
              !operation.commands.isEmpty,
              operation.commands.count <= 32,
              operation.completionCommands.count <= 16,
              operation.acknowledgementCommands.count <= 16,
              operation.subscriptions.count <= 8 else {
            throw CommunicationRuleError.invalidDocument("GATT 操作的步骤或资源上限无效")
        }
        if operation.capability == .historyRead, operation.subscriptions.isEmpty {
            throw CommunicationRuleError.invalidDocument("历史读取操作至少需要一个通知订阅目标")
        }
        if operation.commands.contains(where: { $0.payloadHexTemplate.contains("{{response:") }) {
            throw CommunicationRuleError.invalidDocument("起始命令不能引用尚未收到的响应字段")
        }
        if operation.capability == .historyClear,
           (operation.completionCommands + operation.acknowledgementCommands).contains(where: {
               $0.payloadHexTemplate.contains("{{response:")
           }) {
            throw CommunicationRuleError.invalidDocument("无响应规则的清除操作不能引用响应字段")
        }
        for target in operation.subscriptions { try validate(target) }
        for command in operation.commands + operation.completionCommands + operation.acknowledgementCommands {
            try validate(command.target)
            try CommunicationPayloadTemplate.validate(command.payloadHexTemplate)
        }
        if let response = operation.historyResponse {
            try validate(response.recordMatcher)
            if let completionMatcher = response.completionMatcher {
                try validate(completionMatcher)
            } else if response.builtInParser == nil {
                throw CommunicationRuleError.invalidDocument("声明式历史响应必须提供结束匹配规则")
            }
            if response.framing == .fixedLength {
                guard let length = response.recordLength, (1...512).contains(length) else {
                    throw CommunicationRuleError.invalidDocument("固定长度历史帧必须声明 1 至 512 字节的 recordLength")
                }
            }
            guard response.decoder != nil || response.builtInParser != nil else {
                throw CommunicationRuleError.invalidDocument("历史响应必须提供声明式 decoder 或内置解析器")
            }
            if let decoder = response.decoder {
                let length = response.recordLength ?? response.recordMatcher.minimumLength
                let dateFields = decoder.date.map {
                    [$0.year, $0.month, $0.day, $0.hour, $0.minute, $0.second].compactMap { $0 }
                } ?? []
                let fields = [decoder.weight, decoder.impedance, decoder.bodyFatPercent, decoder.muscleMassKG,
                              decoder.waterPercent, decoder.visceralFat, decoder.basalMetabolismKCal, decoder.boneMassKG]
                    .compactMap { $0 } + dateFields
                guard fields.allSatisfy({
                    $0.offset >= 0 && (1...8).contains($0.length)
                        && $0.scale.isFinite && $0.scale > 0 && $0.add.isFinite
                        && $0.offset + $0.length <= length
                }) else {
                    throw CommunicationRuleError.invalidDocument("历史记录 decoder 字段越界或缩放值无效")
                }
            }
        }
    }

    private static func validate(_ target: CommunicationGATTTarget) throws {
        guard !target.serviceUUID.isEmpty, !target.characteristicUUID.isEmpty else {
            throw CommunicationRuleError.invalidDocument("GATT 目标必须包含服务和特征 UUID")
        }
    }

    private static func validate(_ matcher: CommunicationResponseMatcher) throws {
        try validate(matcher.target)
        guard (1...4_096).contains(matcher.minimumLength),
              matcher.maximumLength.map({ $0 >= matcher.minimumLength && $0 <= 4_096 }) ?? true else {
            throw CommunicationRuleError.invalidDocument("响应匹配长度无效")
        }
        if let prefix = matcher.prefixHex { _ = try CommunicationRuleCodec.hexBytes(prefix) }
        if let exact = matcher.exactHex {
            let bytes = try CommunicationRuleCodec.hexBytes(exact)
            guard bytes.count >= matcher.minimumLength,
                  matcher.maximumLength.map({ bytes.count <= $0 }) ?? true else {
                throw CommunicationRuleError.invalidDocument("exactHex 与响应长度约束冲突")
            }
        }
    }
}

struct DeclarativeHistoryOperationSession {
    enum Event {
        case progress(received: Int)
        case completed([BodyMeasurement], response: Data)
    }

    private let operation: CommunicationGATTOperation
    private var buffer = Data()
    private var responseBytes = 0
    private var measurements: [BodyMeasurement] = []

    init(operation: CommunicationGATTOperation) throws {
        guard operation.capability == .historyRead,
              operation.historyResponse?.decoder != nil,
              operation.historyResponse?.builtInParser == nil else {
            throw CommunicationRuleError.invalidDocument("该历史读取操作没有可执行的声明式解码器")
        }
        self.operation = operation
    }

    mutating func consume(
        _ data: Data,
        serviceUUID: String,
        characteristicUUID: String,
        now: Date = .now
    ) throws -> Event? {
        guard let response = operation.historyResponse else { return nil }
        let target = CommunicationGATTTarget(
            serviceUUID: CommunicationRuleCodec.normalizeUUID(serviceUUID),
            characteristicUUID: CommunicationRuleCodec.normalizeUUID(characteristicUUID)
        )
        if let completionMatcher = response.completionMatcher,
           matches(data, matcher: completionMatcher, target: target) {
            if response.framing == .fixedLength, !buffer.isEmpty {
                throw CommunicationRuleError.invalidDocument("历史传输结束时仍有不完整记录")
            }
            return .completed(deduplicatedMeasurements(), response: data)
        }
        guard matches(data, matcher: response.recordMatcher, target: target) else { return nil }
        responseBytes += data.count
        guard responseBytes <= operation.maximumResponseBytes else {
            throw CommunicationRuleError.invalidDocument("历史响应超过规则声明的字节上限")
        }
        switch response.framing {
        case .notification:
            try appendRecord(data, decoder: response.decoder, now: now)
        case .fixedLength:
            guard let recordLength = response.recordLength else { return nil }
            buffer.append(data)
            while buffer.count >= recordLength {
                let record = Data(buffer.prefix(recordLength))
                buffer.removeFirst(recordLength)
                try appendRecord(record, decoder: response.decoder, now: now)
            }
        }
        return .progress(received: measurements.count)
    }

    private mutating func appendRecord(_ data: Data, decoder: CommunicationRuleDecoder?, now: Date) throws {
        guard measurements.count < operation.maximumRecords, let decoder else {
            throw CommunicationRuleError.invalidDocument("历史记录超过规则声明的数量上限")
        }
        let rule = CommunicationRule(
            id: "runtime.history.decoder",
            name: "History decoder",
            version: 1,
            summary: "",
            origin: .custom,
            match: CommunicationRuleMatch(
                transport: .characteristicNotification,
                serviceUUID: "RUNTIME",
                characteristicUUID: "RUNTIME",
                minimumLength: data.count,
                maximumLength: data.count
            ),
            decoder: decoder
        )
        guard case .measurement(let measurement) = try DeclarativeCommunicationRuleParser.parse(data, rule: rule, now: now) else {
            return
        }
        measurements.append(measurement)
    }

    private func matches(
        _ data: Data,
        matcher: CommunicationResponseMatcher,
        target: CommunicationGATTTarget
    ) -> Bool {
        guard matcher.target == target,
              data.count >= matcher.minimumLength,
              matcher.maximumLength.map({ data.count <= $0 }) ?? true else { return false }
        if let exact = matcher.exactHex,
           let bytes = try? CommunicationRuleCodec.hexBytes(exact), data != Data(bytes) { return false }
        if let prefix = matcher.prefixHex,
           let bytes = try? CommunicationRuleCodec.hexBytes(prefix), !data.starts(with: bytes) { return false }
        return true
    }

    private func deduplicatedMeasurements() -> [BodyMeasurement] {
        var keys = Set<String>()
        return measurements.sorted { $0.date < $1.date }.filter { measurement in
            let key = "\(Int(measurement.date.timeIntervalSince1970))|\(Int((measurement.weightKG * 1_000).rounded()))"
            return keys.insert(key).inserted
        }
    }
}
