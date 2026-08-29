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
    case bluetoothSIG = "标准蓝牙体重秤"
    case manual = "手动记录"
    case demo = "示例数据"
}

struct BodyMeasurement: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var weightKG: Double
    var impedanceOhm: Double?
    var bodyFatPercent: Double?
    var muscleMassKG: Double?
    var waterPercent: Double?
    var visceralFat: Double?
    var basalMetabolismKCal: Double?
    var boneMassKG: Double?
    var source: MeasurementSource
    var isStable: Bool

    func bmi(heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        return weightKG / pow(heightCM / 100, 2)
    }
}

struct UserProfile: Codable, Equatable {
    var name = "我"
    var heightCM = 168.0
    var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var biologicalSex = BiologicalSex.female
    var athleteMode = false

    enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
        case female = "女"
        case male = "男"
        var id: String { rawValue }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
    }
}

struct AppConfiguration: Codable, Equatable {
    var profile: UserProfile
    var unit: WeightUnit

    static let standard = AppConfiguration(profile: UserProfile(), unit: .kilograms)
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
        result.waterPercent = result.waterPercent ?? min(75, max(30, 65 - fat * 0.65))
        result.boneMassKG = result.boneMassKG ?? max(1.5, min(5, lbm * 0.052))
        result.visceralFat = result.visceralFat ?? max(1, min(30, (fat - 12) * 0.45 + age * 0.03))
        result.basalMetabolismKCal = result.basalMetabolismKCal ?? (10 * measurement.weightKG + 6.25 * height - 5 * age + (profile.biologicalSex == .male ? 5 : -161))
        return result
    }
}
