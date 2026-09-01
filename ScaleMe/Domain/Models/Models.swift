import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms = "kg"
    case jin = "斤"
    case pounds = "lb"

    var id: String { rawValue }

    func value(fromKilograms kg: Double) -> Double {
        switch self {
        case .kilograms: kg
        case .jin: kg * 2
        case .pounds: kg * 2.204_622_621_8
        }
    }
}

enum MeasurementSource: String, Codable {
    case xiaomi = "小米体重秤"
    case icomonAFU = "ICOMON AFU 体脂秤"
    case bluetoothSIG = "标准蓝牙体重秤"
    case communityProtocol = "社区协议体重秤"
    case customProtocol = "自定义通信协议"
    case manual = "手动记录"
    case demo = "示例数据"
}

struct BodyMeasurement: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var weightKG: Double
    var impedanceOhm: Double?
    /// A second raw impedance channel when the scale reports one. Its frequency
    /// is intentionally not named until the hardware protocol is verified.
    var secondaryImpedanceOhm: Double? = nil
    var bodyFatPercent: Double?
    var muscleMassKG: Double?
    var waterPercent: Double?
    var visceralFat: Double?
    var basalMetabolismKCal: Double?
    var boneMassKG: Double?
    var source: MeasurementSource
    var isStable: Bool
    var profileID: UUID? = nil
    var deviceID: UUID? = nil
    var deviceName: String? = nil

    func bmi(heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        return weightKG / pow(heightCM / 100, 2)
    }

    var hasBodyComposition: Bool {
        impedanceOhm != nil || bodyFatPercent != nil || muscleMassKG != nil || waterPercent != nil
    }

    var fatMassKG: Double? {
        bodyFatPercent.map { weightKG * $0 / 100 }
    }

    var musclePercent: Double? {
        muscleMassKG.map { $0 / weightKG * 100 }
    }

    var waterMassKG: Double? {
        waterPercent.map { weightKG * $0 / 100 }
    }

    var bonePercent: Double? {
        boneMassKG.map { $0 / weightKG * 100 }
    }

    var proteinMassKG: Double? {
        guard let bodyFatPercent, let waterMassKG, let boneMassKG else { return nil }
        let fatFreeMassKG = weightKG * (100 - bodyFatPercent) / 100
        return max(0, fatFreeMassKG - waterMassKG - boneMassKG)
    }

    var proteinPercent: Double? {
        proteinMassKG.map { $0 / weightKG * 100 }
    }
}

struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "我"
    var relation = "本人"
    var heightCM = 168.0
    var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var biologicalSex = BiologicalSex.female
    var athleteMode = false
    var avatar = MemberAvatar.adult

    enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
        case female = "女"
        case male = "男"
        var id: String { rawValue }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
    }
}

enum MemberAvatar: String, Codable, CaseIterable, Identifiable, Hashable {
    case child
    case childDaughter
    case youth
    case teenDaughter
    case adult
    case father
    case senior
    case paternalGrandfather
    case maternalGrandfather
    case maternalGrandmother

    var id: String { rawValue }

    var title: String {
        switch self {
        case .child: "童真"
        case .childDaughter: "女儿童真"
        case .youth: "活力"
        case .teenDaughter: "女儿青春"
        case .adult: "从容"
        case .father: "爸爸"
        case .senior: "舒展"
        case .paternalGrandfather: "爷爷"
        case .maternalGrandfather: "外公"
        case .maternalGrandmother: "外婆"
        }
    }

    var ageHint: String {
        switch self {
        case .child: "儿童"
        case .childDaughter: "儿童女儿"
        case .youth: "青少年"
        case .teenDaughter: "青少年女儿"
        case .adult: "成年人"
        case .father: "成年人"
        case .senior: "长辈"
        case .paternalGrandfather: "长辈"
        case .maternalGrandfather: "长辈"
        case .maternalGrandmother: "长辈"
        }
    }
}

enum DashboardMetricKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case bodyFatPercent
    case fatMassKG
    case muscleMassKG
    case musclePercent
    case waterPercent
    case waterMassKG
    case proteinPercent
    case proteinMassKG
    case boneMassKG
    case bonePercent
    case visceralFat
    case basalMetabolismKCal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyFatPercent: "体脂率"
        case .fatMassKG: "脂肪量"
        case .muscleMassKG: "肌肉量"
        case .musclePercent: "肌肉率"
        case .waterPercent: "身体水分"
        case .waterMassKG: "水分量"
        case .proteinPercent: "蛋白质占比"
        case .proteinMassKG: "蛋白质量"
        case .boneMassKG: "骨量"
        case .bonePercent: "骨量占比"
        case .visceralFat: "内脏脂肪"
        case .basalMetabolismKCal: "基础代谢"
        }
    }

    var unit: String {
        switch self {
        case .bodyFatPercent, .musclePercent, .waterPercent, .proteinPercent, .bonePercent: "%"
        case .fatMassKG, .muscleMassKG, .waterMassKG, .proteinMassKG, .boneMassKG: "kg"
        case .basalMetabolismKCal: "kcal"
        case .visceralFat: "级"
        }
    }

    /// Kept identical to `TrendMetric.systemImage` so the same category reads consistently across screens.
    var icon: String {
        switch self {
        case .bodyFatPercent: "drop.fill"
        case .fatMassKG: "circle.dashed.inset.filled"
        case .muscleMassKG: "figure.strengthtraining.traditional"
        case .musclePercent: "figure.strengthtraining.functional"
        case .waterPercent: "humidity.fill"
        case .waterMassKG: "water.waves"
        case .proteinPercent: "chart.pie.fill"
        case .proteinMassKG: "fork.knife"
        case .boneMassKG: "figure.walk.motion"
        case .bonePercent: "figure.stand"
        case .visceralFat: "circle.circle"
        case .basalMetabolismKCal: "flame.fill"
        }
    }

    static let defaultVisible: Set<DashboardMetricKind> = [.bodyFatPercent, .muscleMassKG, .waterPercent, .basalMetabolismKCal]

    func value(in measurement: BodyMeasurement) -> Double? {
        switch self {
        case .bodyFatPercent: measurement.bodyFatPercent
        case .fatMassKG: measurement.fatMassKG
        case .muscleMassKG: measurement.muscleMassKG
        case .musclePercent: measurement.musclePercent
        case .waterPercent: measurement.waterPercent
        case .waterMassKG: measurement.waterMassKG
        case .proteinPercent: measurement.proteinPercent
        case .proteinMassKG: measurement.proteinMassKG
        case .boneMassKG: measurement.boneMassKG
        case .bonePercent: measurement.bonePercent
        case .visceralFat: measurement.visceralFat
        case .basalMetabolismKCal: measurement.basalMetabolismKCal
        }
    }
}

struct PairedScale: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var modelName: String
    var compatibility: String
    var communicationRuleID: String? = nil
    var addedAt = Date.now
}

struct AppConfiguration: Codable, Equatable {
    var profiles: [UserProfile]
    var selectedProfileID: UUID
    var pairedScales: [PairedScale]
    var unit: WeightUnit
    var languageSelection: AppLanguageSelection
    var appearance: AppAppearance
    var mergeFrequentMeasurements: Bool
    var isSimulationEnabled: Bool
    var appleHealthProfileID: UUID?
    var appleHealthDeviceIDs: Set<UUID>
    var customCommunicationRules: [CommunicationRule]
    var dashboardMetricOrder: [DashboardMetricKind]
    var dashboardVisibleMetrics: Set<DashboardMetricKind>

    init(
        profiles: [UserProfile],
        selectedProfileID: UUID,
        pairedScales: [PairedScale],
        unit: WeightUnit,
        languageSelection: AppLanguageSelection = .system,
        appearance: AppAppearance = .system,
        mergeFrequentMeasurements: Bool,
        isSimulationEnabled: Bool = false,
        appleHealthProfileID: UUID? = nil,
        appleHealthDeviceIDs: Set<UUID> = [],
        customCommunicationRules: [CommunicationRule],
        dashboardMetricOrder: [DashboardMetricKind] = DashboardMetricKind.allCases,
        dashboardVisibleMetrics: Set<DashboardMetricKind> = DashboardMetricKind.defaultVisible
    ) {
        self.profiles = profiles
        self.selectedProfileID = selectedProfileID
        self.pairedScales = pairedScales
        self.unit = unit
        self.languageSelection = languageSelection
        self.appearance = appearance
        self.mergeFrequentMeasurements = mergeFrequentMeasurements
        self.isSimulationEnabled = isSimulationEnabled
        self.appleHealthProfileID = appleHealthProfileID
        self.appleHealthDeviceIDs = appleHealthDeviceIDs
        self.customCommunicationRules = customCommunicationRules
        self.dashboardMetricOrder = dashboardMetricOrder
        self.dashboardVisibleMetrics = dashboardVisibleMetrics
    }

    private enum CodingKeys: String, CodingKey {
        case profiles
        case selectedProfileID
        case pairedScales
        case unit
        case languageSelection
        case appearance
        case mergeFrequentMeasurements
        case isSimulationEnabled
        case appleHealthProfileID
        case appleHealthDeviceIDs
        case customCommunicationRules
        case dashboardMetricOrder
        case dashboardVisibleMetrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decode([UserProfile].self, forKey: .profiles)
        selectedProfileID = try container.decode(UUID.self, forKey: .selectedProfileID)
        pairedScales = try container.decode([PairedScale].self, forKey: .pairedScales)
        unit = try container.decode(WeightUnit.self, forKey: .unit)
        languageSelection = try container.decodeIfPresent(AppLanguageSelection.self, forKey: .languageSelection) ?? .system
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        mergeFrequentMeasurements = try container.decode(Bool.self, forKey: .mergeFrequentMeasurements)
        isSimulationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSimulationEnabled) ?? false
        appleHealthProfileID = try container.decodeIfPresent(UUID.self, forKey: .appleHealthProfileID)
        appleHealthDeviceIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .appleHealthDeviceIDs) ?? []
        customCommunicationRules = try container.decode([CommunicationRule].self, forKey: .customCommunicationRules)
        dashboardMetricOrder = try container.decodeIfPresent([DashboardMetricKind].self, forKey: .dashboardMetricOrder) ?? DashboardMetricKind.allCases
        dashboardVisibleMetrics = try container.decodeIfPresent(Set<DashboardMetricKind>.self, forKey: .dashboardVisibleMetrics) ?? DashboardMetricKind.defaultVisible
    }

    static var standard: AppConfiguration {
        let profile = UserProfile()
        return AppConfiguration(
            profiles: [profile],
            selectedProfileID: profile.id,
            pairedScales: [],
            unit: .kilograms,
            mergeFrequentMeasurements: false,
            isSimulationEnabled: false,
            customCommunicationRules: []
        )
    }
}

enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

struct MeasurementArchive: Codable, Equatable {
    var updatedAt: Date
    var measurements: [BodyMeasurement]
    var deletedMeasurementIDs: Set<UUID>

    static let empty = MeasurementArchive(
        updatedAt: .distantPast,
        measurements: [],
        deletedMeasurementIDs: []
    )

    func merging(_ other: MeasurementArchive) -> MeasurementArchive {
        let tombstones = deletedMeasurementIDs.union(other.deletedMeasurementIDs)
        let candidates = measurements + other.measurements
        var recordsByID: [UUID: BodyMeasurement] = [:]

        for measurement in candidates where !tombstones.contains(measurement.id) {
            if let existing = recordsByID[measurement.id], existing.date >= measurement.date {
                continue
            }
            recordsByID[measurement.id] = measurement
        }

        return MeasurementArchive(
            updatedAt: max(updatedAt, other.updatedAt),
            measurements: recordsByID.values.sorted { $0.date > $1.date },
            deletedMeasurementIDs: tombstones
        )
    }
}

enum MetricStatus: String {
    case low = "偏低"
    case standard = "标准"
    case high = "偏高"

    var tintName: String {
        switch self { case .standard: "mint"; case .low: "blue"; case .high: "orange" }
    }
}

struct BodyCompositionEstimator {
    static func enriching(_ measurement: BodyMeasurement, profile: UserProfile) -> BodyMeasurement {
        guard let impedance = measurement.impedanceOhm, impedance > 0 else { return measurement }
        var result = measurement
        let height = profile.heightCM
        let age = Double(profile.age)
        let sexOffset = profile.biologicalSex == .male ? 0.0 : 1.0
        let lbm = max(0, 0.756 * height * height / impedance + 0.110 * measurement.weightKG + 0.107 * age - 5.463 * sexOffset)
        let fat = min(60, max(3, (measurement.weightKG - lbm) / measurement.weightKG * 100))
        result.bodyFatPercent = result.bodyFatPercent ?? fat
        result.muscleMassKG = result.muscleMassKG ?? max(0, lbm * 0.94)
        // A commonly used BIA relationship assumes fat-free mass is 73.2% water.
        result.waterPercent = result.waterPercent ?? min(75, max(30, (100 - fat) * 0.732))
        result.boneMassKG = result.boneMassKG ?? max(1.5, min(5, lbm * 0.052))
        result.visceralFat = result.visceralFat ?? max(1, min(30, (fat - 12) * 0.45 + age * 0.03))
        result.basalMetabolismKCal = result.basalMetabolismKCal ?? (10 * measurement.weightKG + 6.25 * height - 5 * age + (profile.biologicalSex == .male ? 5 : -161))
        return result
    }
}
