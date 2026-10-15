import Foundation

/// Application-level weight bounds in kilograms, inclusive of both endpoints.
/// Protocol status markers and device-specific removal signals remain separate.
enum MeasurementLimits {
    static let weightKG: ClosedRange<Double> = 0...500
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms = "kg"
    case jin
    case pounds = "lb"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .kilograms: "kg"
        case .jin: "斤"
        case .pounds: "lb"
        }
    }

    func value(fromKilograms kg: Double) -> Double {
        switch self {
        case .kilograms: kg
        case .jin: kg * 2
        case .pounds: kg * 2.204_622_621_8
        }
    }
}

enum WidgetTrendTimeRange: String, Codable, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case halfYear
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "近 7 天"
        case .month: "近 30 天"
        case .quarter: "近 3 个月"
        case .halfYear: "近 6 个月"
        case .year: "近 1 年"
        case .all: "全部时间"
        }
    }
}

enum WidgetTrendDisplayStyle: String, Codable, CaseIterable, Identifiable {
    case periodFocused
    case periodFullRange
    case actualFocused
    case actualFullRange

    var id: String { rawValue }

    var chartMode: TrendChartMode {
        switch self {
        case .periodFocused, .periodFullRange: .period
        case .actualFocused, .actualFullRange: .actual
        }
    }

    var displayScope: TrendDisplayScope {
        switch self {
        case .periodFocused, .actualFocused: .availableData
        case .periodFullRange, .actualFullRange: .selectedRange
        }
    }
}

enum MeasurementSource: String, Codable, Hashable {
    case xiaomi
    case wolaiAFU
    case senssunIF2121
    case huaweiHagrid
    case bluetoothSIG
    case builtInProtocol
    case customProtocol
    case manual
    case appleHealth
    case demo

    var localizationKey: String {
        switch self {
        case .xiaomi: "小米体重秤"
        case .wolaiAFU: "Wolai AFU 体脂秤"
        case .senssunIF2121: "香山 IF2121 体脂秤"
        case .huaweiHagrid: "华为 Hagrid/WSP 体脂秤"
        case .bluetoothSIG: "标准蓝牙体重秤"
        case .builtInProtocol: "内置协议体重秤"
        case .customProtocol: "自定义通信协议"
        case .manual: "手动记录"
        case .appleHealth: "Apple 健康"
        case .demo: "示例数据"
        }
    }
}

struct DeletedMeasurementMarker: Codable, Hashable {
    var id: UUID
    var date: Date
    var weightKG: Double
    var source: MeasurementSource
    var deviceID: UUID?

    init(_ measurement: BodyMeasurement) {
        id = measurement.id
        date = measurement.date
        weightKG = measurement.weightKG
        source = measurement.source
        deviceID = measurement.deviceID
    }

    func matches(_ measurement: BodyMeasurement) -> Bool {
        if measurement.id == id { return true }
        guard abs(measurement.date.timeIntervalSince(date)) < 2,
              abs(measurement.weightKG - weightKG) < 0.02 else { return false }
        if let deviceID, let measurementDeviceID = measurement.deviceID {
            return measurementDeviceID == deviceID
        }
        return measurement.source == source
    }
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
    var subcutaneousFatPercent: Double? = nil
    var subcutaneousFatMassKG: Double? = nil
    var proteinPercent: Double? = nil
    var proteinMassKG: Double? = nil
    var skeletalMusclePercent: Double? = nil
    var skeletalMuscleMassKG: Double? = nil
    var source: MeasurementSource
    var isStable: Bool
    var profileID: UUID? = nil
    var deviceID: UUID? = nil
    var deviceName: String? = nil

    /// Presentation-only estimates; the record codec persists hardware/input fields only.
    var applicationEstimate: BodyCompositionEstimate? = nil

    var displayedBodyFatPercent: Double? { bodyFatPercent ?? applicationEstimate?.bodyFatPercent }
    var displayedMuscleMassKG: Double? { muscleMassKG ?? applicationEstimate?.muscleMassKG }
    var displayedWaterPercent: Double? { waterPercent ?? applicationEstimate?.waterPercent }
    var displayedBoneMassKG: Double? { boneMassKG ?? applicationEstimate?.boneMassKG }
    var displayedVisceralFat: Double? { visceralFat ?? applicationEstimate?.visceralFat }
    var displayedBasalMetabolismKCal: Double? { basalMetabolismKCal ?? applicationEstimate?.basalMetabolismKCal }
    var displayedSubcutaneousFatPercent: Double? {
        if let subcutaneousFatPercent { return subcutaneousFatPercent }
        guard weightKG > 0 else { return nil }
        return subcutaneousFatMassKG.map { $0 / weightKG * 100 }
    }
    var displayedSubcutaneousFatMassKG: Double? {
        subcutaneousFatMassKG ?? subcutaneousFatPercent.map { weightKG * $0 / 100 }
    }
    var displayedProteinPercent: Double? {
        if let proteinPercent { return proteinPercent }
        guard weightKG > 0 else { return nil }
        return proteinMassKG.map { $0 / weightKG * 100 }
    }
    var displayedProteinMassKG: Double? {
        proteinMassKG ?? proteinPercent.map { weightKG * $0 / 100 }
    }
    var displayedSkeletalMusclePercent: Double? {
        if let skeletalMusclePercent { return skeletalMusclePercent }
        guard weightKG > 0 else { return nil }
        return skeletalMuscleMassKG.map { $0 / weightKG * 100 }
    }
    var displayedSkeletalMuscleMassKG: Double? {
        skeletalMuscleMassKG ?? skeletalMusclePercent.map { weightKG * $0 / 100 }
    }
    var hasApplicationEstimates: Bool {
        DashboardMetricKind.allCases.contains { $0.usesApplicationEstimate(in: self) }
    }
    var usesEstimatedBodyFat: Bool { bodyFatPercent == nil && applicationEstimate?.bodyFatPercent != nil }

    func mergingContinuousMeasurement(_ next: BodyMeasurement) -> BodyMeasurement? {
        guard profileID == next.profileID,
              deviceID == next.deviceID,
              source == next.source,
              abs(date.timeIntervalSince(next.date)) < 30 else { return nil }
        // Continuous samples update one record. A deletion marker for the old
        // sample would also match the retained sample during archive import.
        var merged = next
        merged.id = id
        return merged
    }

    func bmi(heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        return weightKG / pow(heightCM / 100, 2)
    }

    var hasBodyComposition: Bool {
        impedanceOhm != nil || secondaryImpedanceOhm != nil || displayedBodyFatPercent != nil
            || displayedMuscleMassKG != nil || displayedWaterPercent != nil || displayedBoneMassKG != nil
            || displayedVisceralFat != nil || displayedBasalMetabolismKCal != nil
            || displayedSubcutaneousFatPercent != nil || displayedSubcutaneousFatMassKG != nil || displayedProteinPercent != nil || displayedProteinMassKG != nil || displayedSkeletalMusclePercent != nil || displayedSkeletalMuscleMassKG != nil
    }

    var fatMassKG: Double? {
        displayedBodyFatPercent.map { weightKG * $0 / 100 }
    }

    var musclePercent: Double? {
        guard weightKG > 0 else { return nil }
        return displayedMuscleMassKG.map { $0 / weightKG * 100 }
    }

    var waterMassKG: Double? {
        displayedWaterPercent.map { weightKG * $0 / 100 }
    }

    var bonePercent: Double? {
        guard weightKG > 0 else { return nil }
        return displayedBoneMassKG.map { $0 / weightKG * 100 }
    }


}

struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "我"
    var role = "本人"
    var heightCM = 168.0
    var referenceWeightKG = 60.0
    var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var biologicalSex = BiologicalSex.female
    var avatar = MemberAvatar.adult

    enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
        case female
        case male

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .female: "女"
            case .male: "男"
            }
        }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
    }
}

enum AppleHealthDataType: String, Codable, CaseIterable, Identifiable, Hashable {
    case bodyMass
    case bodyFatPercentage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyMass: "体重"
        case .bodyFatPercentage: "体脂率"
        }
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
    case bmi
    case fatMassKG
    case bodyFatPercent
    case muscleMassKG
    case musclePercent
    case waterMassKG
    case waterPercent
    case boneMassKG
    case bonePercent
    case visceralFat
    case fatFreeMassKG
    case skeletalMuscleMassKG
    case skeletalMusclePercent
    case subcutaneousFatMassKG
    case subcutaneousFatPercent
    case proteinMassKG
    case proteinPercent
    case basalMetabolismKCal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fatFreeMassKG: "去脂体重"
        case .bmi: "BMI"
        case .subcutaneousFatPercent: "皮下脂肪率"
        case .subcutaneousFatMassKG: "皮下脂肪量"
        case .proteinPercent: "蛋白质占比"
        case .proteinMassKG: "蛋白质含量"
        case .skeletalMusclePercent: "骨骼肌率"
        case .skeletalMuscleMassKG: "骨骼肌量"

        case .bodyFatPercent: "体脂率"
        case .fatMassKG: "脂肪量"
        case .muscleMassKG: "肌肉量"
        case .musclePercent: "肌肉率"
        case .waterPercent: "体水分率"
        case .waterMassKG: "体水分量"
        case .boneMassKG: "骨量"
        case .bonePercent: "骨量占比"
        case .visceralFat: "内脏脂肪等级"
        case .basalMetabolismKCal: "基础代谢"
        }
    }

    var unit: String {
        switch self {
        case .bmi: "kg/m²"
        case .bodyFatPercent, .musclePercent, .waterPercent, .bonePercent, .subcutaneousFatPercent, .proteinPercent, .skeletalMusclePercent: "%"
        case .fatFreeMassKG, .fatMassKG, .muscleMassKG, .waterMassKG, .boneMassKG, .subcutaneousFatMassKG, .proteinMassKG, .skeletalMuscleMassKG: "kg"
        case .basalMetabolismKCal: "kcal"
        case .visceralFat: "级"
        }
    }

    /// Shared vector artwork for each body-composition category.
    var icon: String {
        switch self {
        case .fatFreeMassKG: "MetricMuscle"
        case .bmi: "MetricBMI"
        case .bodyFatPercent, .fatMassKG: "MetricFat"
        case .muscleMassKG, .musclePercent: "MetricMuscle"
        case .waterPercent, .waterMassKG: "MetricWater"
        case .boneMassKG, .bonePercent: "MetricBone"
        case .visceralFat: "MetricVisceral"
        case .subcutaneousFatPercent, .subcutaneousFatMassKG: "MetricSubcutaneous"
        case .proteinPercent, .proteinMassKG: "MetricProtein"
        case .skeletalMusclePercent, .skeletalMuscleMassKG: "MetricSkeletalMuscle"
        case .basalMetabolismKCal: "MetricMetabolism"
        }
    }

    static let additionalCompositionMetrics: [Self] = [.fatFreeMassKG, .skeletalMuscleMassKG, .skeletalMusclePercent, .subcutaneousFatMassKG, .subcutaneousFatPercent, .proteinMassKG, .proteinPercent]

    static let defaultVisible: Set<DashboardMetricKind> = Set([.bmi, .bodyFatPercent, .muscleMassKG, .waterPercent, .basalMetabolismKCal] + additionalCompositionMetrics)

    func value(in measurement: BodyMeasurement, profile: UserProfile) -> Double? {
        switch self {
        case .bmi:
            guard profile.heightCM.isFinite, profile.heightCM > 0,
                  measurement.weightKG.isFinite, measurement.weightKG > 0 else { return nil }
            let value = measurement.bmi(heightCM: profile.heightCM)
            return value.isFinite ? value : nil
        case .subcutaneousFatPercent: return measurement.displayedSubcutaneousFatPercent
        case .subcutaneousFatMassKG: return measurement.displayedSubcutaneousFatMassKG
        case .proteinPercent: return measurement.displayedProteinPercent
        case .proteinMassKG: return measurement.displayedProteinMassKG
        case .skeletalMusclePercent: return measurement.displayedSkeletalMusclePercent
        case .skeletalMuscleMassKG: return measurement.displayedSkeletalMuscleMassKG
        case .fatFreeMassKG: return measurement.applicationEstimate?.fatFreeMassKG
        case .bodyFatPercent: return measurement.displayedBodyFatPercent
        case .fatMassKG: return measurement.fatMassKG
        case .muscleMassKG: return measurement.displayedMuscleMassKG
        case .musclePercent: return measurement.musclePercent
        case .waterPercent: return measurement.displayedWaterPercent
        case .waterMassKG: return measurement.waterMassKG
        case .boneMassKG: return measurement.displayedBoneMassKG
        case .bonePercent: return measurement.bonePercent
        case .visceralFat: return measurement.displayedVisceralFat
        case .basalMetabolismKCal: return measurement.displayedBasalMetabolismKCal
        }
    }

    func usesApplicationEstimate(in measurement: BodyMeasurement) -> Bool {
        guard let estimate = measurement.applicationEstimate else { return false }
        switch self {
        case .fatFreeMassKG: return estimate.fatFreeMassKG != nil
        case .bmi, .subcutaneousFatPercent, .subcutaneousFatMassKG, .proteinPercent, .proteinMassKG, .skeletalMusclePercent, .skeletalMuscleMassKG: return false
        case .bodyFatPercent, .fatMassKG: return measurement.usesEstimatedBodyFat
        case .muscleMassKG, .musclePercent: return measurement.muscleMassKG == nil && estimate.muscleMassKG != nil
        case .waterPercent, .waterMassKG: return measurement.waterPercent == nil && estimate.waterPercent != nil
        case .boneMassKG, .bonePercent: return measurement.boneMassKG == nil && estimate.boneMassKG != nil
        case .visceralFat: return measurement.visceralFat == nil && estimate.visceralFat != nil
        case .basalMetabolismKCal: return measurement.basalMetabolismKCal == nil && estimate.basalMetabolismKCal != nil
        }
    }
}

/// Screening/reference categories, never a diagnosis. Boundaries use unrounded values.
enum MetricAssessment: String {
    case severelyLow = "严重偏低"
    case overweightRisk = "超重风险"
    case low = "偏低"
    case normal = "标准"
    case high = "偏高"
    case veryHigh = "很高"
    case overweight = "超重"
    case obesity = "肥胖"
    case notLow = "未偏低"
    case noReference = "不评级"
    case notApplicable = "不适用"
    case noData = "无数据"
    case invalid = "数据异常"
}

extension DashboardMetricKind {
    func assessment(in measurement: BodyMeasurement?, profile: UserProfile) -> MetricAssessment {
        guard let measurement, let value = value(in: measurement, profile: profile) else { return .noData }
        guard value.isFinite, value > 0 else { return .invalid }
        switch self {
        case .visceralFat, .basalMetabolismKCal, .subcutaneousFatPercent, .subcutaneousFatMassKG:
            // Total muscle is not appendicular skeletal muscle; scale bone mass is not
            // DXA density. Proprietary visceral indices and BMR lack transferable cutoffs.
            return .noReference
        default: break
        }
        guard let measuredAge = MeasurementAge(birthDate: profile.birthDate, measurementDate: measurement.date) else { return .notApplicable }
        let age = measuredAge.years
        // Assess these references from the very same intervals drawn in the UI.
        if [.muscleMassKG, .musclePercent, .boneMassKG, .bonePercent,
            .proteinMassKG, .proteinPercent, .fatFreeMassKG].contains(self) {
            if self != .fatFreeMassKG {
                guard measurement.weightKG.isFinite, measurement.weightKG > 0,
                      value < (unit == "%" ? 100 : measurement.weightKG) else { return .invalid }
            } else {
                guard profile.heightCM.isFinite, profile.heightCM > 0,
                      measurement.weightKG.isFinite, value <= measurement.weightKG else { return .invalid }
            }
            let bands = referenceBands(in: measurement, profile: profile)
            guard !bands.isEmpty else { return .notApplicable }
            return bands.first { band in
                (band.lower.map { band.includesLower ? value >= $0 : value > $0 } ?? true)
                    && (band.upper.map { band.includesUpper ? value <= $0 : value < $0 } ?? true)
            }?.status ?? .invalid
        }
        switch self {
        case .skeletalMusclePercent, .skeletalMuscleMassKG:
            guard (18...80).contains(age) else { return .notApplicable }
            guard let percentage = measurement.displayedSkeletalMusclePercent,
                  percentage.isFinite, percentage > 0, percentage < 100 else { return .invalid }
            // OMRON's table is published to one decimal place; round before categorization.
            let rounded = (percentage * 10).rounded() / 10
            let cuts = Self.skeletalMuscleCutoffs(age: age, sex: profile.biologicalSex)
            if rounded < cuts[0] { return .low }
            if rounded < cuts[1] { return .normal }
            if rounded < cuts[2] { return .high }
            return .veryHigh
        case .bmi:
            return AgeSpecificBMI.assessment(bmi: value, age: measuredAge, sex: profile.biologicalSex)
        case .bodyFatPercent, .fatMassKG:
            guard (20...79).contains(age) else { return .notApplicable }
            guard let fat = measurement.displayedBodyFatPercent, fat.isFinite, fat > 0, fat < 100 else { return .invalid }
            // OMRON BF508 manual p.10, age/sex reference table based on Gallagher
            // (PMID 10966886); a reference adopted by the app, not a WHO fat standard.
            let limits: (Double, Double, Double)
            switch (profile.biologicalSex, age) {
            case (.male, 20...39): limits = (8, 20, 25)
            case (.male, 40...59): limits = (11, 22, 28)
            case (.male, _): limits = (13, 25, 30)
            case (.female, 20...39): limits = (21, 33, 39)
            case (.female, 40...59): limits = (23, 34, 40)
            case (.female, _): limits = (24, 36, 42)
            }
            if fat < limits.0 { return .low }
            if fat < limits.1 { return .normal }
            if fat < limits.2 { return .high }
            return .veryHigh
        case .waterPercent, .waterMassKG:
            guard age >= 18 else { return .notApplicable }
            guard let water = measurement.displayedWaterPercent, water.isFinite, water > 0, water < 100 else { return .invalid }
            // TANITA Europe public adult guidance, not diagnostic hydration thresholds.
            let range: ClosedRange<Double> = profile.biologicalSex == .male ? 50...65 : 45...60
            if water < range.lowerBound { return .low }
            if water > range.upperBound { return .high }
            return .normal
        default: return .noReference
        }
    }
}

struct PairedScale: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var modelName: String
    var compatibility: String
    var communicationRuleID: String? = nil
    var automaticallyImportsHistory = false
    var addedAt = Date.now

}

struct AppConfiguration: Codable, Equatable {
    var profiles: [UserProfile]
    var pairedScales: [PairedScale]
    var unit: WeightUnit
    var languageSelection: AppLanguageSelection
    var visualTheme: AppVisualTheme
    var appearance: AppAppearance
    var mergeFrequentMeasurements: Bool
    var isSimulationEnabled: Bool
    var appleHealthProfileID: UUID?
    var appleHealthDeviceIDs: Set<UUID>
    var isAppleHealthSyncEnabled: Bool
    var isAppleHealthImportEnabled: Bool
    var appleHealthReadTypes: Set<AppleHealthDataType>
    var customCommunicationRules: [CommunicationRule]
    var dashboardMetricOrder: [DashboardMetricKind]
    var dashboardVisibleMetrics: Set<DashboardMetricKind>
    var widgetProfileID: UUID?
    var widgetTimeRange: WidgetTrendTimeRange
    var widgetDisplayStyle: WidgetTrendDisplayStyle

    init(
        profiles: [UserProfile],
        pairedScales: [PairedScale],
        unit: WeightUnit,
        languageSelection: AppLanguageSelection = .system,
        visualTheme: AppVisualTheme = .standard,
        appearance: AppAppearance = .system,
        mergeFrequentMeasurements: Bool,
        isSimulationEnabled: Bool = false,
        appleHealthProfileID: UUID? = nil,
        appleHealthDeviceIDs: Set<UUID> = [],
        isAppleHealthSyncEnabled: Bool = false,
        isAppleHealthImportEnabled: Bool = false,
        appleHealthReadTypes: Set<AppleHealthDataType> = Set(AppleHealthDataType.allCases),
        customCommunicationRules: [CommunicationRule],
        dashboardMetricOrder: [DashboardMetricKind] = DashboardMetricKind.allCases,
        dashboardVisibleMetrics: Set<DashboardMetricKind> = DashboardMetricKind.defaultVisible,
        widgetProfileID: UUID? = nil,
        widgetTimeRange: WidgetTrendTimeRange = .month,
        widgetDisplayStyle: WidgetTrendDisplayStyle = .periodFocused
    ) {
        self.profiles = profiles
        self.pairedScales = pairedScales
        self.unit = unit
        self.languageSelection = languageSelection
        self.visualTheme = visualTheme
        self.appearance = appearance
        self.mergeFrequentMeasurements = mergeFrequentMeasurements
        self.isSimulationEnabled = isSimulationEnabled
        self.appleHealthProfileID = appleHealthProfileID
        self.appleHealthDeviceIDs = appleHealthDeviceIDs
        self.isAppleHealthSyncEnabled = isAppleHealthSyncEnabled
        self.isAppleHealthImportEnabled = isAppleHealthImportEnabled
        self.appleHealthReadTypes = appleHealthReadTypes
        self.customCommunicationRules = customCommunicationRules
        self.dashboardMetricOrder = dashboardMetricOrder
        self.dashboardVisibleMetrics = dashboardVisibleMetrics
        self.widgetProfileID = widgetProfileID
        self.widgetTimeRange = widgetTimeRange
        self.widgetDisplayStyle = widgetDisplayStyle
    }

    static var standard: AppConfiguration {
        return AppConfiguration(
            profiles: [],
            pairedScales: [],
            unit: .kilograms,
            mergeFrequentMeasurements: false,
            isSimulationEnabled: false,
            customCommunicationRules: []
        )
    }
}

enum AppVisualTheme: String, CaseIterable, Codable, Identifiable {
    case standard
    case colorVisionAccessible

    var id: String { rawValue }
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
    var deletedMeasurements: Set<DeletedMeasurementMarker>

    static let empty = MeasurementArchive(
        updatedAt: .distantPast,
        measurements: [],
        deletedMeasurements: []
    )

    func merging(_ other: MeasurementArchive) -> MeasurementArchive {
        let tombstones = deletedMeasurements.union(other.deletedMeasurements)
        let candidates = measurements + other.measurements
        var recordsByID: [UUID: BodyMeasurement] = [:]

        for measurement in candidates where !tombstones.contains(where: { $0.matches(measurement) }) {
            if let existing = recordsByID[measurement.id], existing.date >= measurement.date {
                continue
            }
            recordsByID[measurement.id] = measurement
        }

        return MeasurementArchive(
            updatedAt: max(updatedAt, other.updatedAt),
            measurements: recordsByID.values.sorted { $0.date > $1.date },
            deletedMeasurements: tombstones
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

/// Presentation provenance is independent of raw device fields.
enum BodyFatEstimationMethod: String, Codable, Hashable {
    case experimentalFootToFootImpedance
    case experimentalSchaeferImpedance
    case experimentalTyrrellImpedance
    case experimentalSunImpedance
}

/// See ImpedanceCompositionRules for age-specific BIA models;
/// resting energy: PMID 2305711. Mapping an unknown channel to a paper is experimental,
/// not validation of that device or a reconstruction of its manufacturer's algorithm.
struct BodyCompositionEstimate: Codable, Hashable {
    let ruleVersion: String
    let bodyFatMethod: BodyFatEstimationMethod?
    let impedanceUsedOhm: Double?
    let heightCM: Double
    let age: Int
    let sex: UserProfile.BiologicalSex
    let bodyFatPercent: Double?
    let fatFreeMassKG: Double?
    let restingEnergyKCal: Double?
    var waterPercent: Double? = nil
    var boneMassKG: Double? = nil
    var muscleMassKG: Double? = nil
    var visceralFat: Double? = nil
    var basalMetabolismKCal: Double? = nil
    var impedanceRule: ImpedanceCompositionRule? = nil
    var bodyFatUnavailableReason: CompositionUnavailableReason? = nil
    var fractionalAge: Double? = nil
}

enum BodyCompositionCalculation {
    static func supportsEstimation(_ measurement: BodyMeasurement, decoder: CommunicationRuleDecoder? = nil) -> Bool {
        // A product name alone is not evidence of body-composition capability.
        guard ![MeasurementSource.manual, .appleHealth].contains(measurement.source) else { return false }
        if [.wolaiAFU, .senssunIF2121, .huaweiHagrid].contains(measurement.source) { return true }
        if measurement.impedanceOhm != nil || measurement.secondaryImpedanceOhm != nil { return true }
        if [measurement.bodyFatPercent, measurement.muscleMassKG, measurement.waterPercent,
            measurement.boneMassKG, measurement.visceralFat].contains(where: { $0 != nil }) { return true }
        guard let decoder else { return false }
        return decoder.impedance != nil || decoder.bodyFatPercent != nil || decoder.muscleMassKG != nil
            || decoder.waterPercent != nil || decoder.boneMassKG != nil || decoder.visceralFat != nil
    }

    static func applying(to measurement: BodyMeasurement, profile: UserProfile,
                         decoder: CommunicationRuleDecoder? = nil) -> BodyMeasurement {
        var result = measurement
        // Recompute from raw data after profile changes; never reuse another owner's estimates.
        result.applicationEstimate = nil
        guard measurement.isStable, supportsEstimation(measurement, decoder: decoder),
              measurement.weightKG.isFinite, measurement.weightKG > 0,
              MeasurementLimits.weightKG.contains(measurement.weightKG),
              profile.heightCM.isFinite, (20...250).contains(profile.heightCM),
              let measuredAge = MeasurementAge(birthDate: profile.birthDate, measurementDate: measurement.date) else { return result }
        let age = measuredAge.years
        // Missing or invalid primary impedance disables every default composition estimate.
        // A secondary channel cannot substitute for the primary measurement.
        guard let primaryOhm = measurement.impedanceOhm,
              primaryOhm.isFinite, (100...2000).contains(primaryOhm) else { return result }
        let sex = profile.biologicalSex == .male ? 1.0 : 0.0
        var estimatedFat: Double?
        var method: BodyFatEstimationMethod?
        var impedanceUsed: Double?
        var impedancePrediction: ImpedanceCompositionRules.Prediction?
        var unavailableReason: CompositionUnavailableReason?
        if measurement.bodyFatPercent == nil {
            switch ImpedanceCompositionRules.evaluate(weightKG: measurement.weightKG,
                heightCM: profile.heightCM, ageYears: measuredAge.fractionalYears,
                sex: profile.biologicalSex, primaryOhm: measurement.impedanceOhm) {
            case .success(let prediction):
                impedancePrediction = prediction
                estimatedFat = prediction.bodyFatPercent
                method = prediction.rule.method
                impedanceUsed = measurement.impedanceOhm
            case .failure(let reason):
                unavailableReason = reason
            }
        }
        let resolvedFat = measurement.bodyFatPercent ?? estimatedFat
        let fatFreeMass = resolvedFat.flatMap { value -> Double? in
            guard value.isFinite, value > 0, value < 100 else { return nil }
            return measurement.weightKG * (1 - value / 100)
        }
        // Received fat must not prevent an independently missing water value
        // from using the age-appropriate impedance water model.
        if measurement.bodyFatPercent != nil, measurement.waterPercent == nil,
           case .success(let prediction) = ImpedanceCompositionRules.evaluate(
                weightKG: measurement.weightKG, heightCM: profile.heightCM,
                ageYears: measuredAge.fractionalYears, sex: profile.biologicalSex,
                primaryOhm: measurement.impedanceOhm), prediction.rule == .sun2003 {
            impedancePrediction = prediction
            impedanceUsed = measurement.impedanceOhm
        }
        // REE is intentionally separate from the device's basal-metabolism field.
        let ree = 10 * measurement.weightKG + 6.25 * profile.heightCM - 5 * Double(age) + (sex == 1 ? 5 : -161)
        let restingEnergy = measurement.basalMetabolismKCal == nil && (19...78).contains(age)
            && ree.isFinite && ree > 0 ? ree : nil
        var estimate = BodyCompositionEstimate(ruleVersion: "composition-6", bodyFatMethod: method,
            impedanceUsedOhm: impedanceUsed, heightCM: profile.heightCM,
            age: age, sex: profile.biologicalSex, bodyFatPercent: estimatedFat,
            fatFreeMassKG: fatFreeMass, restingEnergyKCal: restingEnergy)
        estimate.impedanceRule = impedancePrediction?.rule
        estimate.bodyFatUnavailableReason = unavailableReason
        estimate.fractionalAge = measuredAge.fractionalYears
        if measurement.waterPercent == nil, let water = impedancePrediction?.waterMassKG,
           let fatFreeMass, water < fatFreeMass {
            estimate.waterPercent = 100 * water / measurement.weightKG
        }
        // Adult hydration and heuristic proportions are not validated for growth.
        if let fatFreeMass, age >= 18 {
            // Water: adult fat-free mass hydration assumption (PMID 10232621).
            if measurement.waterPercent == nil && estimate.waterPercent == nil,
               impedancePrediction?.rule != .sun2003 {
                estimate.waterPercent = 100 * 0.732 * fatFreeMass / measurement.weightKG
            }
            // App-defined experimental proportions, NOT coefficients from the cited
            // impedance paper. The muscle proxy is bone-free lean mass, not measured
            // skeletal muscle. Keep all outputs separate from hardware fields.
            if measurement.boneMassKG == nil { estimate.boneMassKG = 0.052 * fatFreeMass }
            if measurement.muscleMassKG == nil,
               let bone = measurement.boneMassKG ?? estimate.boneMassKG,
               bone.isFinite, bone > 0, bone < fatFreeMass {
                estimate.muscleMassKG = fatFreeMass - bone
            }
            if measurement.visceralFat == nil, let fat = resolvedFat {
                // Legacy application index; no equivalence to a manufacturer's scale
                // or anatomical visceral-fat quantity is established.
                estimate.visceralFat = min(30, max(1, (fat - 12) * 0.45 + Double(age) * 0.03))
            }
        }
        if measurement.basalMetabolismKCal == nil {
            estimate.basalMetabolismKCal = AgeSpecificBasalEnergy.estimate(
                weightKG: measurement.weightKG, age: age, sex: profile.biologicalSex)
        }
        result.applicationEstimate = estimate
        return result
    }
}

/// Display intervals use the same unrounded boundaries as metric assessment.
struct MetricReferenceBand {
    let status: MetricAssessment
    let lower: Double?
    let upper: Double?
    var includesLower = true
    var includesUpper = false
}

extension DashboardMetricKind {
    func referenceBands(in measurement: BodyMeasurement?, profile: UserProfile) -> [MetricReferenceBand] {
        guard let measurement,
              let age = MeasurementAge(birthDate: profile.birthDate, measurementDate: measurement.date) else { return [] }
        var cuts: [Double]
        var statuses: [MetricAssessment]
        var upperInclusiveFrom: Int? = nil
        switch self {
        case .muscleMassKG, .musclePercent:
            guard (20...79).contains(age.years) else { return [] }
            switch (profile.biologicalSex, age.years) {
            case (.male, 20...39): cuts = [75, 89]
            case (.male, 40...59): cuts = [73, 86]
            case (.male, _): cuts = [70, 84]
            case (.female, 20...39): cuts = [63, 75.5]
            case (.female, 40...59): cuts = [62, 73.5]
            case (.female, _): cuts = [60, 72.5]
            }
            statuses = [.low, .normal, .high]
            upperInclusiveFrom = 1
        case .boneMassKG, .bonePercent:
            // Withings supplies no age table; adulthood is an app scope restriction,
            // not a claim that the manufacturer validated every adult age.
            guard age.years >= 18 else { return [] }
            cuts = profile.biologicalSex == .male ? [3, 5] : [2.5, 4]
            statuses = [.low, .normal, .high]
            upperInclusiveFrom = 1
        case .proteinMassKG, .proteinPercent:
            // PHICOMM S7 product reference, restricted to adults by this app.
            guard age.years >= 18 else { return [] }
            cuts = [16, 20]
            statuses = [.low, .normal, .high]
            upperInclusiveFrom = 1
        case .fatFreeMassKG:
            guard age.years >= 18, profile.heightCM.isFinite, profile.heightCM > 0 else { return [] }
            let heightM = profile.heightCM / 100
            cuts = [(profile.biologicalSex == .male ? 17 : 15) * heightM * heightM]
            statuses = [.low, .notLow]
        case .bmi:
            if age.years >= 19 {
                cuts = [18.5, 25, 30]
                statuses = [.low, .normal, .overweight, .obesity]
            } else {
                guard let lms = AgeSpecificBMI.reference(days: age.days, sex: profile.biologicalSex) else { return [] }
                let scores: [Double] = age.days <= 1856 ? [-3, -2, 1, 2, 3] : [-3, -2, 1, 2]
                cuts = scores.map { lms.cutoff($0) }
                statuses = age.days <= 1856
                    ? [.severelyLow, .low, .normal, .overweightRisk, .overweight, .obesity]
                    : [.severelyLow, .low, .normal, .overweight, .obesity]
                upperInclusiveFrom = 2
            }
        case .bodyFatPercent, .fatMassKG:
            guard (20...79).contains(age.years) else { return [] }
            switch (profile.biologicalSex, age.years) {
            case (.male, 20...39): cuts = [8, 20, 25]
            case (.male, 40...59): cuts = [11, 22, 28]
            case (.male, _): cuts = [13, 25, 30]
            case (.female, 20...39): cuts = [21, 33, 39]
            case (.female, 40...59): cuts = [23, 34, 40]
            case (.female, _): cuts = [24, 36, 42]
            }
            statuses = [.low, .normal, .high, .veryHigh]
        case .skeletalMusclePercent, .skeletalMuscleMassKG:
            guard (18...80).contains(age.years) else { return [] }
            // Half-step cutoffs match one-decimal rounding in the assessment table.
            cuts = Self.skeletalMuscleCutoffs(age: age.years, sex: profile.biologicalSex).map { $0 - 0.05 }
            statuses = [.low, .normal, .high, .veryHigh]
        case .waterPercent, .waterMassKG:
            guard age.years >= 18 else { return [] }
            cuts = profile.biologicalSex == .male ? [50, 65] : [45, 60]
            statuses = [.low, .normal, .high]
            upperInclusiveFrom = 1
        default: return []
        }
        if [.fatMassKG, .waterMassKG, .skeletalMuscleMassKG, .muscleMassKG, .boneMassKG, .proteinMassKG].contains(self) {
            guard measurement.weightKG.isFinite, measurement.weightKG > 0 else { return [] }
            cuts = cuts.map { $0 * measurement.weightKG / 100 }
        }
        return statuses.indices.map { index in
            MetricReferenceBand(status: statuses[index],
                lower: index == 0 ? nil : cuts[index - 1],
                upper: index == cuts.count ? nil : cuts[index],
                includesLower: upperInclusiveFrom.map { index <= $0 } ?? true,
                includesUpper: upperInclusiveFrom.map { index >= $0 } ?? false)
        }
    }
}

extension DashboardMetricKind {
    private static func skeletalMuscleCutoffs(age: Int, sex: UserProfile.BiologicalSex) -> [Double] {
        switch (sex, age) {
        case (.male, 18...39): [33.3, 39.4, 44.1]
        case (.male, 40...59): [33.1, 39.2, 43.9]
        case (.male, _): [32.9, 39.0, 43.7]
        case (.female, 18...39): [24.3, 30.4, 35.4]
        case (.female, 40...59): [24.1, 30.2, 35.2]
        case (.female, _): [23.9, 30.0, 35.0]
        }
    }
}
