import Foundation

@main
struct ImpedanceCompositionRuleSmoke {
    static func main() throws {
        func predict(_ age: Double, _ sex: UserProfile.BiologicalSex = .male,
                     weight: Double = 70, height: Double = 170, z: Double? = 600)
            -> Result<ImpedanceCompositionRules.Prediction, CompositionUnavailableReason> {
            ImpedanceCompositionRules.evaluate(weightKG: weight, heightCM: height,
                ageYears: age, sex: sex, primaryOhm: z)
        }
        func close(_ actual: Double, _ expected: Double) {
            precondition(abs(actual - expected) < 1e-8, "Unexpected calculation")
        }
        func failure(_ result: Result<ImpedanceCompositionRules.Prediction, CompositionUnavailableReason>,
                     _ expected: CompositionUnavailableReason) {
            guard case .failure(let reason) = result else { preconditionFailure("Expected rejection") }
            precondition(reason == expected)
        }
        // Synthetic profiles. Expected FFM/TBW independently evaluated from the
        // published equations, including Tyrrell's unusual sex encoding.
        for sex in UserProfile.BiologicalSex.allCases {
            close(try predict(4, sex, weight: 16, height: 100).get().fatFreeMassKG, 13.703333333333333)
            let child = try predict(8, sex, weight: 30, height: 130).get()
            close(child.fatFreeMassKG, sex == .male ? 21.055666666666667 : 20.113666666666667)
            precondition(child.waterMassKG == nil)
            let adolescent = try predict(14, sex, weight: 55, height: 160, z: 650).get()
            close(adolescent.fatFreeMassKG, sex == .male ? 42.22 : 39.995384615384615)
            close(adolescent.waterMassKG!, sex == .male ? 28.566692307692308 : 27.685076923076923)
            let elder = try predict(80, sex).get()
            close(elder.fatFreeMassKG, sex == .male ? 50.828333333333333 : 47.605)
            close(elder.waterMassKG!, sex == .male ? 35.149833333333333 : 33.332)
        }
        // Branch boundaries: no undocumented rounding of a child to an adult.
        let branches: [(Double, ImpedanceCompositionRule)] = [
            (3.9, .schaefer1994), (4.899, .schaefer1994), (4.9, .tyrrell2001),
            (10.9, .tyrrell2001), (10.901, .schaefer1994), (11.999, .schaefer1994),
            (12, .sun2003), (17.999, .sun2003), (18, .wu2015),
            (75, .wu2015), (75.001, .sun2003), (94, .sun2003)
        ]
        for (age, rule) in branches {
            let prediction = try predict(age).get()
            precondition(prediction.rule == rule)
        }
        for age in [0.0, 0.5, 3.899, 94.001, 100] { failure(predict(age), .unsupportedAge) }
        failure(predict(-1), .invalidInput)
        failure(predict(.nan), .invalidInput)
        failure(predict(.infinity), .invalidInput)
        failure(predict(8, z: nil), .missingPrimaryImpedance)
        for z in [Double.nan, .infinity, -1, 0, 99, 2001] { failure(predict(8, z: z), .invalidInput) }
        failure(predict(8, z: 100), .invalidPrediction)
        failure(predict(30, weight: 40), .invalidPrediction)
        // BMI is not an admission criterion for impedance estimates.
        let lowBMI = try predict(30, weight: 40, z: 1000).get()
        precondition(lowBMI.rule == .wu2015)
        let highBMI = try predict(30, weight: 150).get()
        precondition(highBMI.rule == .wu2015)
        for age in [4.0, 8, 14, 30, 80] {
            let a = try predict(age).get()
            let b = try predict(age, z: 700).get()
            precondition(a.bodyFatPercent != b.bodyFatPercent)
            close(a.fatFreeMassKG + 70 * a.bodyFatPercent / 100, 70)
        }
        // Full application path, source priority, raw preservation and second channel.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birth = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        let profile = UserProfile(heightCM: 170, birthDate: birth, biologicalSex: .male)
        for years in [0, 4, 8, 14, 30, 80, 100] {
            let date = calendar.date(byAdding: .year, value: years, to: birth)!
            var raw = BodyMeasurement(date: date, weightKG: 70, impedanceOhm: 600,
                secondaryImpedanceOhm: 900, source: .wolaiAFU, isStable: true)
            let result = BodyCompositionCalculation.applying(to: raw, profile: profile)
            precondition(result.bodyFatPercent == nil && result.waterPercent == nil)
            precondition(result.displayedBasalMetabolismKCal != nil)
            if years == 0 || years == 100 {
                precondition(result.applicationEstimate?.bodyFatUnavailableReason == .unsupportedAge)
            } else {
                precondition(result.displayedBodyFatPercent != nil)
                precondition(result.applicationEstimate?.impedanceRule != nil)
                precondition(result.applicationEstimate?.bodyFatUnavailableReason == nil)
                raw.secondaryImpedanceOhm = 300
                precondition(BodyCompositionCalculation.applying(to: raw, profile: profile).displayedBodyFatPercent
                    == result.displayedBodyFatPercent)
            }
            raw.impedanceOhm = nil
            let missing = BodyCompositionCalculation.applying(to: raw, profile: profile)
            precondition(missing.applicationEstimate == nil)
            precondition(missing.displayedBodyFatPercent == nil)
            // Received body composition wins at every age, even without impedance.
            raw.bodyFatPercent = 25; raw.waterPercent = 55; raw.boneMassKG = 3
            raw.muscleMassKG = 48; raw.visceralFat = 7; raw.basalMetabolismKCal = 1500
            let supplied = BodyCompositionCalculation.applying(to: raw, profile: profile)
            precondition(supplied.displayedBodyFatPercent == 25 && supplied.displayedWaterPercent == 55)
            precondition(supplied.displayedBoneMassKG == 3 && supplied.displayedMuscleMassKG == 48)
            precondition(supplied.displayedVisceralFat == 7 && supplied.displayedBasalMetabolismKCal == 1500)
            precondition(supplied.applicationEstimate?.impedanceRule == nil)
            precondition(supplied.applicationEstimate?.bodyFatUnavailableReason == nil)
        }
        let teenDate = calendar.date(byAdding: .year, value: 14, to: birth)!
        var partial = BodyMeasurement(date: teenDate, weightKG: 70, impedanceOhm: 600,
            bodyFatPercent: 25, source: .wolaiAFU, isStable: true)
        let waterOnly = BodyCompositionCalculation.applying(to: partial, profile: profile)
        precondition(waterOnly.displayedBodyFatPercent == 25)
        precondition(waterOnly.applicationEstimate?.bodyFatPercent == nil)
        precondition(waterOnly.applicationEstimate?.bodyFatMethod == nil)
        precondition(waterOnly.applicationEstimate?.impedanceRule == .sun2003)
        close(waterOnly.waterMassKG!, 35.149833333333333)
        partial.bodyFatPercent = 90 // Sun water would exceed received fat-free mass.
        precondition(BodyCompositionCalculation.applying(to: partial, profile: profile).displayedWaterPercent == nil)
        partial.bodyFatPercent = nil
        partial.waterPercent = 50
        let fatOnly = BodyCompositionCalculation.applying(to: partial, profile: profile)
        precondition(fatOnly.displayedBodyFatPercent != nil && fatOnly.displayedWaterPercent == 50)
        precondition(fatOnly.applicationEstimate?.waterPercent == nil)
        partial.impedanceOhm = nil
        partial.secondaryImpedanceOhm = 600
        precondition(BodyCompositionCalculation.applying(to: partial, profile: profile).displayedBodyFatPercent == nil)
        // Decimal age is based on calendar anniversaries, including a leap birthday.
        let leapBirth = calendar.date(from: DateComponents(year: 2000, month: 2, day: 29))!
        let anniversary = calendar.date(byAdding: .year, value: 18, to: leapBirth)!
        close(MeasurementAge(birthDate: leapBirth, measurementDate: anniversary)!.fractionalYears, 18)
        print("Impedance composition rule smoke checks passed")
    }
}
