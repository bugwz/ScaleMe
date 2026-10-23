import Foundation

@main
struct MetricAssessmentSmoke {
    static func main() throws {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        var profile = UserProfile(heightCM: 200,
            birthDate: calendar.date(byAdding: .year, value: -30, to: date)!, biologicalSex: .male)
        var record = BodyMeasurement(date: date, weightKG: 80, source: .manual, isStable: true)
        for (bmi, expected): (Double, MetricAssessment) in [
            (18.499, .low), (18.5, .normal), (24.999, .normal),
            (25, .overweight), (29.999, .overweight), (30, .obesity), (40, .obesity)
        ] {
            record.weightKG = bmi * 4
            precondition(DashboardMetricKind.bmi.assessment(in: record, profile: profile) == expected)
        }
        record.weightKG = 80
        for sex in UserProfile.BiologicalSex.allCases {
            profile.biologicalSex = sex
            for (age, male, female): (Int, [Double], [Double]) in [
                (20, [8, 20, 25], [21, 33, 39]), (39, [8, 20, 25], [21, 33, 39]),
                (40, [11, 22, 28], [23, 34, 40]), (59, [11, 22, 28], [23, 34, 40]),
                (60, [13, 25, 30], [24, 36, 42]), (79, [13, 25, 30], [24, 36, 42])
            ] {
                profile.birthDate = calendar.date(byAdding: .year, value: -age, to: date)!
                let limits = sex == .male ? male : female
                let cases: [(Double, MetricAssessment)] = [
                    (limits[0] - 0.001, .low), (limits[0], .normal),
                    (limits[1] - 0.001, .normal), (limits[1], .high),
                    (limits[2] - 0.001, .high), (limits[2], .veryHigh)
                ]
                for (fat, expected) in cases {
                    record.bodyFatPercent = fat
                    for kind in [DashboardMetricKind.bodyFatPercent, .fatMassKG] {
                        precondition(kind.assessment(in: record, profile: profile) == expected)
                    }
                }
            }
            profile.birthDate = calendar.date(byAdding: .year, value: -30, to: date)!
            let low = sex == .male ? 50.0 : 45.0
            let high = sex == .male ? 65.0 : 60.0
            for (water, expected): (Double, MetricAssessment) in [
                (low - 0.01, .low), (low, .normal), (high, .normal), (high + 0.01, .high)
            ] {
                record.waterPercent = water
                for kind in [DashboardMetricKind.waterPercent, .waterMassKG] {
                    precondition(kind.assessment(in: record, profile: profile) == expected)
                }
            }
        }
        for age in [19, 80] {
            profile.birthDate = calendar.date(byAdding: .year, value: -age, to: date)!
            precondition(DashboardMetricKind.bodyFatPercent.assessment(in: record, profile: profile) == .notApplicable)
        }
        profile.birthDate = calendar.date(byAdding: .year, value: -17, to: date)!
        precondition(DashboardMetricKind.bmi.assessment(in: record, profile: profile) == .normal)
        precondition(DashboardMetricKind.waterPercent.assessment(in: record, profile: profile) == .notApplicable)
        record.bodyFatPercent = nil
        precondition(DashboardMetricKind.bodyFatPercent.assessment(in: record, profile: profile) == .noData)
        record.bodyFatPercent = .nan
        precondition(DashboardMetricKind.bodyFatPercent.assessment(in: record, profile: profile) == .invalid)
        for kind in DashboardMetricKind.allCases {
            precondition(kind.assessment(in: nil, profile: profile) == .noData)
        }
        profile.birthDate = calendar.date(byAdding: .year, value: -30, to: date)!
        record.muscleMassKG = 55; record.boneMassKG = 3
        record.visceralFat = 10; record.basalMetabolismKCal = 1600
        for kind in [DashboardMetricKind.visceralFat, .basalMetabolismKCal] {
            precondition(kind.assessment(in: record, profile: profile) == .noReference)
        }
        // Synthetic data: inclusive published reference bounds, both sexes and age bands.
        record.weightKG = 100
        for sex in UserProfile.BiologicalSex.allCases {
            profile.biologicalSex = sex
            for age in [17, 18, 19, 20, 39, 40, 59, 60, 79, 80, 95] {
                profile.birthDate = calendar.date(byAdding: .year, value: -age, to: date)!
                for kind in [DashboardMetricKind.muscleMassKG, .musclePercent, .boneMassKG, .bonePercent] {
                    let bands = kind.referenceBands(in: record, profile: profile)
                    let supported = [.muscleMassKG, .musclePercent].contains(kind) ? (20...79).contains(age) : age >= 18
                    precondition(bands.isEmpty != supported)
                    guard supported else { continue }
                    let lo = bands[1].lower!, hi = bands[1].upper!
                    for (value, expected): (Double, MetricAssessment) in [(lo - 0.01, .low), (lo, .normal), (hi, .normal), (hi + 0.01, .high)] {
                        record.muscleMassKG = value
                        record.boneMassKG = value
                        precondition(kind.assessment(in: record, profile: profile) == expected)
                    }
                }
                record.applicationEstimate = BodyCompositionEstimate(ruleVersion: "synthetic", bodyFatMethod: nil,
                    impedanceUsedOhm: 500, heightCM: 200, age: age, sex: sex,
                    bodyFatPercent: nil, fatFreeMassKG: 60, restingEnergyKCal: nil)
                let kind = DashboardMetricKind.fatFreeMassKG
                let bands = kind.referenceBands(in: record, profile: profile)
                if age < 18 {
                    precondition(bands.isEmpty)
                    precondition(kind.assessment(in: record, profile: profile) == .notApplicable)
                } else {
                    let limit = (sex == .male ? 17.0 : 15.0) * 4
                    precondition(bands[1].lower == limit)
                    precondition(kind.assessment(in: record, profile: profile) == (60 < limit ? .low : .notLow))
                }
            }
        }
        record.applicationEstimate = nil
        record.weightKG = 80
        profile.biologicalSex = .male
        profile.birthDate = calendar.date(byAdding: .year, value: -30, to: date)!
        for (mass, rate) in [(DashboardMetricKind.muscleMassKG, DashboardMetricKind.musclePercent), (.boneMassKG, .bonePercent)] {
            let m = mass.referenceBands(in: record, profile: profile)
            let r = rate.referenceBands(in: record, profile: profile)
            precondition(abs(m[1].lower! - r[1].lower! * 0.8) < 0.000001)
            precondition(abs(m[1].upper! - r[1].upper! * 0.8) < 0.000001)
        }
        record.muscleMassKG = .infinity
        precondition(DashboardMetricKind.muscleMassKG.assessment(in: record, profile: profile) == .invalid)
        record.boneMassKG = nil
        precondition(DashboardMetricKind.boneMassKG.assessment(in: record, profile: profile) == .noData)
        profile.heightCM = .nan
        precondition(DashboardMetricKind.bmi.value(in: record, profile: profile) == nil)
        // Released configuration: preserve user choices and add BMI once, without resetting data.
        var config = AppConfiguration.standard
        config.dashboardMetricOrder = [.waterPercent, .bodyFatPercent]
        config.dashboardVisibleMetrics = [.waterPercent]
        let upgraded = try ConfigurationFileCodec.decode(ConfigurationFileCodec.encode(config, prettyPrinted: false))
        precondition(upgraded.dashboardMetricOrder == [.bmi, .waterPercent, .bodyFatPercent] + DashboardMetricKind.additionalCompositionMetrics)
        precondition(upgraded.dashboardVisibleMetrics == Set([.bmi, .waterPercent] + DashboardMetricKind.additionalCompositionMetrics))
        precondition(upgraded.profiles == config.profiles)
        var hidden = upgraded
        hidden.dashboardVisibleMetrics.remove(.bmi)
        let reloaded = try ConfigurationFileCodec.decode(ConfigurationFileCodec.encode(hidden, prettyPrinted: false))
        precondition(reloaded.dashboardVisibleMetrics == Set([.waterPercent] + DashboardMetricKind.additionalCompositionMetrics))
        precondition(reloaded.dashboardMetricOrder == hidden.dashboardMetricOrder)
        // Removing unsupported UI metrics must preserve the rest of a saved configuration.
        var document = try JSONSerialization.jsonObject(with: ConfigurationFileCodec.encode(hidden, prettyPrinted: false)) as! [String: Any]
        var dashboard = document["dashboard"] as! [String: Any]
        let removed = ["skeletalMuscleMassKG", "skeletalMusclePercent", "subcutaneousFatMassKG",
                       "subcutaneousFatPercent", "proteinMassKG", "proteinPercent"]
        dashboard["metricOrder"] = (dashboard["metricOrder"] as! [String]) + removed
        dashboard["visibleMetrics"] = (dashboard["visibleMetrics"] as! [String]) + removed
        document["dashboard"] = dashboard
        let cleaned = try ConfigurationFileCodec.decode(JSONSerialization.data(withJSONObject: document))
        precondition(cleaned.dashboardMetricOrder == reloaded.dashboardMetricOrder)
        precondition(cleaned.dashboardVisibleMetrics == reloaded.dashboardVisibleMetrics)
        precondition(cleaned.profiles == reloaded.profiles)
        precondition(DashboardMetricKind.allCases.count == 12)
        // Graphic boundaries must agree with status assessment, including exact cutoffs.
        profile.heightCM = 200
        for sex in UserProfile.BiologicalSex.allCases {
            profile.biologicalSex = sex
            for age in [0, 5, 17, 19, 20, 40, 60, 79, 80] {
                profile.birthDate = calendar.date(byAdding: .year, value: -age, to: date)!
                for kind in [DashboardMetricKind.bmi, .bodyFatPercent, .fatMassKG, .waterPercent, .waterMassKG] {
                    record.weightKG = 80
                    let bands = kind.referenceBands(in: record, profile: profile)
                    for cutoff in bands.compactMap(\.upper) {
                        for value in [cutoff - 0.001, cutoff, cutoff + 0.001] {
                            switch kind {
                            case .bmi: record.weightKG = value * 4
                            case .bodyFatPercent: record.bodyFatPercent = value
                            case .fatMassKG: record.bodyFatPercent = value / record.weightKG * 100
                            case .waterPercent: record.waterPercent = value
                            case .waterMassKG: record.waterPercent = value / record.weightKG * 100
                            default: break
                            }
                            // Compare exact boundaries for percentage/BMI; kg conversion may round at the last bit.
                            if (kind == .fatMassKG || kind == .waterMassKG) && value == cutoff { continue }
                            let matches = bands.filter { band in
                                let above = band.lower.map { band.includesLower ? value >= $0 : value > $0 } ?? true
                                let below = band.upper.map { band.includesUpper ? value <= $0 : value < $0 } ?? true
                                return above && below
                            }
                            precondition(matches.count == 1)
                            precondition(matches[0].status == kind.assessment(in: record, profile: profile))
                        }
                    }
                }
            }
        }
        precondition(DashboardMetricKind.visceralFat.referenceBands(in: record, profile: profile).isEmpty)
        precondition(DashboardMetricKind.bmi.referenceBands(in: nil, profile: profile).isEmpty)
        print("Metric assessment smoke checks passed")
    }
}
