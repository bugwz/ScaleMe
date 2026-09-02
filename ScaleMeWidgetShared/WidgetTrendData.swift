import CryptoKit
import Foundation
import Security

struct WidgetTrendPoint: Codable, Hashable {
    let id: String
    let date: Date
    let value: Double
}

struct WidgetTrendMetricMetadata: Codable, Hashable {
    let metricID: String
    let title: String
    let systemImage: String
    let unit: String
    let isEstimated: Bool
}

struct WidgetTrendProfile: Codable, Hashable {
    let id: String
    let name: String
    let relation: String
}

struct WidgetTrendDevice: Codable, Hashable {
    let id: String
    let name: String
    let modelName: String
}

struct WidgetTrendMeasurement: Codable, Hashable {
    let id: String
    let profileID: String
    let deviceID: String?
    let date: Date
    let values: [String: Double]
}

struct WidgetTrendSeries: Hashable {
    let metadata: WidgetTrendMetricMetadata
    let profileName: String
    let deviceName: String
    let rangeTitle: String
    let points: [WidgetTrendPoint]

    var latestPoint: WidgetTrendPoint? { points.last }
}

struct WidgetTrendSnapshot: Codable, Hashable {
    let generatedAt: Date
    let defaultProfileID: String
    let rangeTitles: [String: String]
    let allDevicesTitle: String
    let metrics: [WidgetTrendMetricMetadata]
    let profiles: [WidgetTrendProfile]
    let devices: [WidgetTrendDevice]
    let measurements: [WidgetTrendMeasurement]

    func profile(id: String?) -> WidgetTrendProfile? {
        let resolvedID = id ?? defaultProfileID
        return profiles.first { $0.id == resolvedID } ?? profiles.first
    }

    func series(
        metricID: String,
        profileID: String?,
        deviceID: String?,
        rangeID: String,
        displayStyleID: String,
        endingAt endDate: Date,
        calendar: Calendar = .current
    ) -> WidgetTrendSeries? {
        guard let metadata = metrics.first(where: { $0.metricID == metricID }),
              let profile = profile(id: profileID) else {
            return nil
        }
        let selectedDeviceID = deviceID == "all" ? nil : deviceID
        let startDate = Self.startDate(for: rangeID, endingAt: endDate, calendar: calendar)
        let valued = measurements.compactMap { measurement -> WidgetTrendMeasurement? in
            guard measurement.profileID == profile.id,
                  measurement.date <= endDate,
                  startDate.map({ measurement.date >= $0 }) ?? true,
                  selectedDeviceID.map({ measurement.deviceID == $0 }) ?? true,
                  measurement.values[metricID] != nil else {
                return nil
            }
            return measurement
        }
        .sorted { $0.date < $1.date }

        let usesActualMeasurements = displayStyleID.hasPrefix("actual")
        let points: [WidgetTrendPoint]
        if usesActualMeasurements {
            points = valued.compactMap { measurement in
                measurement.values[metricID].map {
                    WidgetTrendPoint(id: measurement.id, date: measurement.date, value: $0)
                }
            }
        } else {
            let aggregation = Self.aggregation(
                for: rangeID,
                measurements: valued,
                calendar: calendar
            )
            let grouped = Dictionary(grouping: valued) {
                Self.bucketStart(for: $0.date, aggregation: aggregation, calendar: calendar)
            }
            points = grouped.map { bucket, bucketMeasurements in
                let values = bucketMeasurements.compactMap { $0.values[metricID] }
                return WidgetTrendPoint(
                    id: String(bucket.timeIntervalSinceReferenceDate),
                    date: bucket,
                    value: values.reduce(0, +) / Double(values.count)
                )
            }
            .sorted { $0.date < $1.date }
        }

        let deviceName = selectedDeviceID.flatMap { selectedID in
            devices.first(where: { $0.id == selectedID })?.name
        } ?? allDevicesTitle
        return WidgetTrendSeries(
            metadata: metadata,
            profileName: profile.name,
            deviceName: deviceName,
            rangeTitle: rangeTitles[rangeID] ?? Self.rangeTitle(for: rangeID),
            points: points
        )
    }

    func dateDomain(
        rangeID: String,
        displayStyleID: String,
        endingAt endDate: Date,
        calendar: Calendar = .current
    ) -> ClosedRange<Date>? {
        guard displayStyleID.hasSuffix("FullRange"),
              let startDate = Self.startDate(for: rangeID, endingAt: endDate, calendar: calendar) else {
            return nil
        }
        return startDate ... endDate
    }

    private enum Aggregation {
        case measurement
        case day
        case week
        case month
    }

    private static func startDate(for rangeID: String, endingAt endDate: Date, calendar: Calendar) -> Date? {
        switch rangeID {
        case "week": calendar.date(byAdding: .day, value: -7, to: endDate)
        case "month": calendar.date(byAdding: .day, value: -30, to: endDate)
        case "quarter": calendar.date(byAdding: .month, value: -3, to: endDate)
        case "halfYear": calendar.date(byAdding: .month, value: -6, to: endDate)
        case "year": calendar.date(byAdding: .year, value: -1, to: endDate)
        default: nil
        }
    }

    private static func rangeTitle(for rangeID: String) -> String {
        switch rangeID {
        case "week": "近 7 天"
        case "quarter": "近 3 个月"
        case "halfYear": "近 6 个月"
        case "year": "近 1 年"
        case "all": "全部时间"
        default: "近 30 天"
        }
    }

    private static func aggregation(
        for rangeID: String,
        measurements: [WidgetTrendMeasurement],
        calendar: Calendar
    ) -> Aggregation {
        switch rangeID {
        case "week", "month": return .day
        case "quarter", "halfYear": return .week
        case "year": return .month
        default:
            guard let first = measurements.first?.date, let last = measurements.last?.date else {
                return .measurement
            }
            let days = last.timeIntervalSince(first) / 86_400
            if days <= 45 { return .day }
            if days <= 200 { return .week }
            return .month
        }
    }

    private static func bucketStart(for date: Date, aggregation: Aggregation, calendar: Calendar) -> Date {
        switch aggregation {
        case .measurement: date
        case .day: calendar.startOfDay(for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month: calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }
}

enum WidgetTrendRepositoryError: Error {
    case appGroupUnavailable
    case keychainAccessGroupUnavailable
    case keychain(OSStatus)
    case invalidEncryptedData
}

struct WidgetTrendRepository {
    static let appGroupIdentifier = "group.com.scaleme.app"
    static let widgetKind = "ScaleMeTrendWidget"

    private static let fileName = "widget-trends-v2.enc"
    private static let keyService = "com.scaleme.app.widget-encryption"
    private static let keyAccount = "widget-trend-snapshot-key"
    private static let authenticatedContext = Data("ScaleMe.widget-trends.v2".utf8)

    private let fileURL: URL
    private let keyAccessGroup: String

    init(fileManager: FileManager = .default, bundle: Bundle = .main) throws {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            throw WidgetTrendRepositoryError.appGroupUnavailable
        }
        guard let accessGroup = bundle.object(
            forInfoDictionaryKey: "ScaleMeKeychainAccessGroup"
        ) as? String,
              !accessGroup.isEmpty else {
            throw WidgetTrendRepositoryError.keychainAccessGroupUnavailable
        }
        fileURL = containerURL.appending(path: Self.fileName)
        keyAccessGroup = accessGroup
    }

    func save(_ snapshot: WidgetTrendSnapshot) throws {
        let plaintext = try JSONEncoder().encode(snapshot)
        let encryptedData = try encrypt(plaintext, keyData: loadOrCreateKey())
        try encryptedData.write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func load() throws -> WidgetTrendSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let keyData = try loadKey() else {
            return nil
        }
        let encryptedData = try Data(contentsOf: fileURL)
        let plaintext = try decrypt(encryptedData, keyData: keyData)
        return try JSONDecoder().decode(WidgetTrendSnapshot.self, from: plaintext)
    }

    private func encrypt(_ plaintext: Data, keyData: Data) throws -> Data {
        let box = try AES.GCM.seal(
            plaintext,
            using: SymmetricKey(data: keyData),
            authenticating: Self.authenticatedContext
        )
        guard let combined = box.combined else {
            throw WidgetTrendRepositoryError.invalidEncryptedData
        }
        return combined
    }

    private func decrypt(_ encryptedData: Data, keyData: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(
                box,
                using: SymmetricKey(data: keyData),
                authenticating: Self.authenticatedContext
            )
        } catch {
            throw WidgetTrendRepositoryError.invalidEncryptedData
        }
    }

    private func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey() { return existing }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keyService,
            kSecAttrAccount: Self.keyAccount,
            kSecAttrAccessGroup: keyAccessGroup,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: keyData
        ] as CFDictionary, nil)

        if status == errSecDuplicateItem, let existing = try loadKey() {
            return existing
        }
        guard status == errSecSuccess else {
            throw WidgetTrendRepositoryError.keychain(status)
        }
        return keyData
    }

    private func loadKey() throws -> Data? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keyService,
            kSecAttrAccount: Self.keyAccount,
            kSecAttrAccessGroup: keyAccessGroup,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw WidgetTrendRepositoryError.keychain(status)
        }
        return result as? Data
    }
}
