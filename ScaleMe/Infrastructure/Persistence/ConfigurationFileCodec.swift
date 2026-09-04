import CoreFoundation
import Foundation

enum ConfigurationFileCodec {
    static let currentSchemaVersion = 1

    static func encode(_ configuration: AppConfiguration, prettyPrinted: Bool) throws -> Data {
        let value = try orderedValue(for: configuration)
        return Data(value.rendered(prettyPrinted: prettyPrinted).utf8)
    }

    static func decode(_ data: Data) throws -> AppConfiguration {
        let document = try JSONDecoder().decode(ConfigurationDocument.self, from: data)
        guard document.schemaVersion == currentSchemaVersion else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported configuration schema version"
            ))
        }
        return document.configuration
    }

    private static func orderedValue(for configuration: AppConfiguration) throws -> OrderedJSONValue {
        .object([
            ("schemaVersion", .number(String(currentSchemaVersion))),
            ("members", .object([
                ("profiles", .array(configuration.profiles.map(profileValue)))
            ])),
            ("devices", .object([
                ("pairedScales", .array(configuration.pairedScales.map(pairedScaleValue)))
            ])),
            ("communication", .object([
                ("customRules", try .encoded(configuration.customCommunicationRules))
            ])),
            ("general", .object([
                ("appearance", .string(configuration.appearance.rawValue)),
                ("isSimulationEnabled", .bool(configuration.isSimulationEnabled)),
                ("languageSelection", .string(configuration.languageSelection.rawValue))
            ])),
            ("measurement", .object([
                ("mergeFrequentMeasurements", .bool(configuration.mergeFrequentMeasurements)),
                ("unit", .string(configuration.unit.rawValue))
            ])),
            ("appleHealth", .object(
                optionalIDPair("profileID", configuration.appleHealthProfileID)
                    + [("deviceIDs", .array(configuration.appleHealthDeviceIDs
                        .sorted { $0.uuidString < $1.uuidString }
                        .map { .string($0.uuidString) }))]
            )),
            ("dashboard", .object([
                ("metricOrder", .array(configuration.dashboardMetricOrder.map { .string($0.rawValue) })),
                ("visibleMetrics", .array(orderedVisibleMetrics(configuration).map { .string($0.rawValue) }))
            ])),
            ("widget", .object(
                optionalIDPair("profileID", configuration.widgetProfileID)
                    + [
                        ("timeRange", .string(configuration.widgetTimeRange.rawValue)),
                        ("displayStyle", .string(configuration.widgetDisplayStyle.rawValue))
                    ]
            ))
        ])
    }

    private static func profileValue(_ profile: UserProfile) -> OrderedJSONValue {
        .object([
            ("id", .string(profile.id.uuidString)),
            ("name", .string(profile.name)),
            ("relation", .string(profile.relation)),
            ("heightCM", .number(numberString(profile.heightCM))),
            ("referenceWeightKG", .number(numberString(profile.referenceWeightKG))),
            ("birthDate", .number(numberString(profile.birthDate.timeIntervalSinceReferenceDate))),
            ("biologicalSex", .string(profile.biologicalSex.rawValue)),
            ("avatar", .string(profile.avatar.rawValue))
        ])
    }

    private static func pairedScaleValue(_ scale: PairedScale) -> OrderedJSONValue {
        var pairs: [(String, OrderedJSONValue)] = [
            ("id", .string(scale.id.uuidString)),
            ("name", .string(scale.name)),
            ("modelName", .string(scale.modelName)),
            ("compatibility", .string(scale.compatibility))
        ]
        if let communicationRuleID = scale.communicationRuleID {
            pairs.append(("communicationRuleID", .string(communicationRuleID)))
        }
        pairs.append(("addedAt", .number(numberString(scale.addedAt.timeIntervalSinceReferenceDate))))
        return .object(pairs)
    }

    private static func optionalIDPair(_ key: String, _ id: UUID?) -> [(String, OrderedJSONValue)] {
        id.map { [(key, .string($0.uuidString))] } ?? []
    }

    private static func orderedVisibleMetrics(_ configuration: AppConfiguration) -> [DashboardMetricKind] {
        let ordered = configuration.dashboardMetricOrder.filter(configuration.dashboardVisibleMetrics.contains)
        let remaining = configuration.dashboardVisibleMetrics
            .subtracting(ordered)
            .sorted { $0.rawValue < $1.rawValue }
        return ordered + remaining
    }

    private static func numberString(_ value: Double) -> String {
        if value.isFinite, value.rounded() == value {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        return String(value)
    }
}

private struct ConfigurationDocument: Codable {
    var schemaVersion: Int
    var members: Members
    var devices: Devices
    var communication: Communication
    var general: General
    var measurement: Measurement
    var appleHealth: AppleHealth
    var dashboard: Dashboard
    var widget: Widget

    struct Members: Codable {
        var profiles: [UserProfile]
    }

    struct Devices: Codable {
        var pairedScales: [PairedScale]
    }

    struct Communication: Codable {
        var customRules: [CommunicationRule]
    }

    struct General: Codable {
        var appearance: AppAppearance
        var isSimulationEnabled: Bool
        var languageSelection: AppLanguageSelection
    }

    struct Measurement: Codable {
        var mergeFrequentMeasurements: Bool
        var unit: WeightUnit
    }

    struct AppleHealth: Codable {
        var profileID: UUID?
        var deviceIDs: Set<UUID>
    }

    struct Dashboard: Codable {
        var metricOrder: [DashboardMetricKind]
        var visibleMetrics: Set<DashboardMetricKind>
    }

    struct Widget: Codable {
        var profileID: UUID?
        var timeRange: WidgetTrendTimeRange
        var displayStyle: WidgetTrendDisplayStyle
    }

    var configuration: AppConfiguration {
        AppConfiguration(
            profiles: members.profiles,
            pairedScales: devices.pairedScales,
            unit: measurement.unit,
            languageSelection: general.languageSelection,
            appearance: general.appearance,
            mergeFrequentMeasurements: measurement.mergeFrequentMeasurements,
            isSimulationEnabled: general.isSimulationEnabled,
            appleHealthProfileID: appleHealth.profileID,
            appleHealthDeviceIDs: appleHealth.deviceIDs,
            customCommunicationRules: communication.customRules,
            dashboardMetricOrder: dashboard.metricOrder,
            dashboardVisibleMetrics: dashboard.visibleMetrics,
            widgetProfileID: widget.profileID,
            widgetTimeRange: widget.timeRange,
            widgetDisplayStyle: widget.displayStyle
        )
    }
}

indirect enum OrderedJSONValue {
    case object([(String, OrderedJSONValue)])
    case array([OrderedJSONValue])
    case inlineArray([OrderedJSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    static func encoded<T: Encodable>(_ value: T) throws -> OrderedJSONValue {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let object = try JSONSerialization.jsonObject(with: encoder.encode(value), options: [.fragmentsAllowed])
        return try fromFoundation(object)
    }

    private static func fromFoundation(_ value: Any) throws -> OrderedJSONValue {
        if let value = value as? [String: Any] {
            return try .object(value.keys.sorted().map { ($0, try fromFoundation(value[$0] as Any)) })
        }
        if let value = value as? [Any] {
            return try .array(value.map(fromFoundation))
        }
        if let value = value as? String { return .string(value) }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }
            return .number(value.stringValue)
        }
        if value is NSNull { return .null }
        throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Unsupported JSON value"))
    }

    func rendered(prettyPrinted: Bool, depth: Int = 0) -> String {
        switch self {
        case .object(let pairs):
            guard !pairs.isEmpty else { return "{}" }
            if !prettyPrinted {
                return "{" + pairs.map { "\(Self.quoted($0.0)):\($0.1.rendered(prettyPrinted: false))" }.joined(separator: ",") + "}"
            }
            let indentation = String(repeating: "  ", count: depth + 1)
            let closingIndentation = String(repeating: "  ", count: depth)
            let body = pairs.map {
                "\(indentation)\(Self.quoted($0.0)): \($0.1.rendered(prettyPrinted: true, depth: depth + 1))"
            }.joined(separator: ",\n")
            return "{\n\(body)\n\(closingIndentation)}"
        case .array(let values):
            guard !values.isEmpty else { return "[]" }
            if !prettyPrinted {
                return "[" + values.map { $0.rendered(prettyPrinted: false) }.joined(separator: ",") + "]"
            }
            let indentation = String(repeating: "  ", count: depth + 1)
            let closingIndentation = String(repeating: "  ", count: depth)
            let body = values.map {
                "\(indentation)\($0.rendered(prettyPrinted: true, depth: depth + 1))"
            }.joined(separator: ",\n")
            return "[\n\(body)\n\(closingIndentation)]"
        case .inlineArray(let values):
            let separator = prettyPrinted ? ", " : ","
            return "[" + values.map { $0.rendered(prettyPrinted: false) }.joined(separator: separator) + "]"
        case .string(let value): return Self.quoted(value)
        case .number(let value): return value
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        }
    }

    private static func quoted(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
    }
}
