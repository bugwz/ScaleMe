import SwiftUI

enum TrendMetricPalette {
    static let weight = Color(red: 0.08, green: 0.68, blue: 0.55)
    static let bmi = Color(red: 0.43, green: 0.76, blue: 0.90)
    static let bodyFat = Color(red: 0.98, green: 0.67, blue: 0.43)
    static let fatMass = Color(red: 0.91, green: 0.47, blue: 0.43)
    static let muscleMass = Color(red: 0.32, green: 0.66, blue: 0.41)
    static let musclePercent = Color(red: 0.12, green: 0.62, blue: 0.63)
    static let waterPercent = Color(red: 0.25, green: 0.56, blue: 0.82)
    static let waterMass = Color(red: 0.31, green: 0.70, blue: 0.78)
    static let proteinPercent = Color(red: 0.67, green: 0.70, blue: 0.29)
    static let proteinMass = Color(red: 0.47, green: 0.64, blue: 0.22)
    static let boneMass = Color(red: 0.58, green: 0.66, blue: 0.88)
    static let bonePercent = Color(red: 0.67, green: 0.52, blue: 0.79)
    static let visceralFat = Color(red: 0.94, green: 0.55, blue: 0.61)
    static let basalMetabolism = Color(red: 0.86, green: 0.50, blue: 0.24)

    static func color(forMetricID metricID: String) -> Color {
        switch metricID {
        case "weight": weight
        case "bmi": bmi
        case "bodyFat": bodyFat
        case "fatMass": fatMass
        case "muscleMass": muscleMass
        case "musclePercent": musclePercent
        case "waterPercent": waterPercent
        case "waterMass": waterMass
        case "proteinPercent": proteinPercent
        case "proteinMass": proteinMass
        case "boneMass": boneMass
        case "bonePercent": bonePercent
        case "visceralFat": visceralFat
        case "basalMetabolism": basalMetabolism
        default: weight
        }
    }
}
