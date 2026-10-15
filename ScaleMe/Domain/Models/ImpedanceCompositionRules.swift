import Foundation

/// Default *experimental* mapping of a scale's primary channel to a paper's input.
/// Formula selection does not establish that the scale measures the required
/// frequency, resistance/magnitude, electrode path, or reference population.
/// Never substitute the secondary channel for resistance or reactance.
enum ImpedanceCompositionRule: String, Codable, Hashable {
    case schaefer1994
    case tyrrell2001
    case sun2003
    case wu2015

    var method: BodyFatEstimationMethod {
        switch self {
        case .schaefer1994: .experimentalSchaeferImpedance
        case .tyrrell2001: .experimentalTyrrellImpedance
        case .sun2003: .experimentalSunImpedance
        case .wu2015: .experimentalFootToFootImpedance
        }
    }
}

enum CompositionUnavailableReason: String, Codable, Hashable, Error {
    case missingPrimaryImpedance
    case invalidInput
    case unsupportedAge
    case invalidPrediction
}

enum ImpedanceCompositionRules {
    struct Prediction {
        let rule: ImpedanceCompositionRule
        let fatFreeMassKG: Double
        let bodyFatPercent: Double
        let waterMassKG: Double?
    }

    // Bounds are application input guards, not evidence of validity for every
    // age/device inside the interval. Ages use decimal calendar years.
    static func evaluate(weightKG: Double, heightCM: Double, ageYears: Double,
                         sex: UserProfile.BiologicalSex, primaryOhm: Double?)
        -> Result<Prediction, CompositionUnavailableReason> {
        guard weightKG.isFinite, weightKG > 0, MeasurementLimits.weightKG.contains(weightKG),
              heightCM.isFinite, (20...250).contains(heightCM),
              ageYears.isFinite, ageYears >= 0 else { return .failure(.invalidInput) }
        guard let z = primaryOhm else { return .failure(.missingPrimaryImpedance) }
        guard z.isFinite, (100...2_000).contains(z) else { return .failure(.invalidInput) }
        // No extrapolation to infants or beyond the oldest studied population.
        guard (3.9...94).contains(ageYears) else { return .failure(.unsupportedAge) }

        let rule: ImpedanceCompositionRule
        if (4.9...10.9).contains(ageYears) {
            rule = .tyrrell2001
        } else if ageYears < 12 {
            rule = .schaefer1994
        } else if ageYears < 18 || ageYears > 75 {
            rule = .sun2003
        } else {
            rule = .wu2015
        }

        let heightIndex = heightCM * heightCM / z
        let male = sex == .male
        let fatFree: Double
        var water: Double?
        switch rule {
        case .schaefer1994:
            // PMID 8065848: ages 3.9–19.3, tetrapolar whole-body impedance.
            // Applying this to foot-to-foot hardware is an unvalidated path mapping.
            fatFree = 0.65 * heightIndex + 0.68 * ageYears + 0.15
        case .tyrrell2001:
            // DOI 10.1038/sj.ijo.0801531; foot-to-foot ages 4.9–10.9.
            // Equation also reproduced/tested in PLoS ONE 2014, PMC4245105 Table 2.
            // This paper codes boys=2, girls=1, unlike Wu's male=1/female=0.
            fatFree = 0.31 * heightIndex + 0.17 * heightCM + 0.11 * weightKG
                + 0.942 * (male ? 2 : 1) - 14.96
        case .sun2003:
            // PMID 12540391, ages 12–94; whole-body resistance at 50 kHz.
            // R is NOT interchangeable with an unknown foot-to-foot Z channel.
            // The default scale mapping remains experimental, including for AFU.
            fatFree = male
                ? -10.68 + 0.65 * heightIndex + 0.26 * weightKG + 0.02 * z
                : -9.53 + 0.69 * heightIndex + 0.17 * weightKG + 0.02 * z
            // Published TBW (liters), approximated as kg at 1 kg/L for display.
            // Separate from FFM: no fixed adult hydration ratio for adolescents.
            water = male
                ? 1.203 + 0.449 * heightIndex + 0.176 * weightKG
                : 3.747 + 0.450 * heightIndex + 0.113 * weightKG
        case .wu2015:
            // PMID 25986468: 50 kHz foot-to-foot, adult Asian sample.
            fatFree = 13.055 + 0.204 * weightKG + 0.394 * heightIndex
                - 0.136 * ageYears + 8.125 * (male ? 1 : 0)
        }
        guard fatFree.isFinite, fatFree > 0, fatFree < weightKG else {
            return .failure(.invalidPrediction)
        }
        // Never clip an impossible output into a seemingly valid percentage.
        let validWater = water.flatMap { $0.isFinite && $0 > 0 && $0 < fatFree ? $0 : nil }
        return .success(Prediction(rule: rule, fatFreeMassKG: fatFree,
            bodyFatPercent: 100 * (1 - fatFree / weightKG), waterMassKG: validWater))
    }
}
