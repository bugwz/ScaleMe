import Foundation

@main
struct AgeSpecificCalculationSmoke {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birth = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        var profile = UserProfile(heightCM: 100, birthDate: birth, biologicalSex: .male)
        func date(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: birth)! }
        func age(_ days: Int) -> MeasurementAge { MeasurementAge(birthDate: birth, measurementDate: date(days))! }
        // Official WHO birth medians, daily/monthly coverage and source-table endpoints.
        precondition(AgeSpecificBMI.reference(days: 0, sex: .male)?.m == 13.4069)
        precondition(AgeSpecificBMI.reference(days: 0, sex: .female)?.m == 13.3363)
        precondition(AgeSpecificBMI.reference(days: 1856, sex: .male)?.m == 15.184)
        for sex in UserProfile.BiologicalSex.allCases {
            for days in 0...6939 {
                guard let lms = AgeSpecificBMI.reference(days: days, sex: sex) else { preconditionFailure("WHO table gap: \(days)") }
                precondition(lms.cutoff(-3) < lms.cutoff(-2) && lms.cutoff(-2) < lms.m)
                precondition(lms.m < lms.cutoff(1) && lms.cutoff(1) < lms.cutoff(2))
                precondition(AgeSpecificBMI.assessment(bmi: lms.m, age: age(days), sex: sex) == .normal)
            }
            for days in [0, 1, 730, 731, 1856, 1857, 3653, 6574] {
                let lms = AgeSpecificBMI.reference(days: days, sex: sex)!
                let measuredAge = age(days)
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(-3) - 0.001, age: measuredAge, sex: sex) == .severelyLow)
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(-3), age: measuredAge, sex: sex) == .low)
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(-2), age: measuredAge, sex: sex) == .normal)
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(1), age: measuredAge, sex: sex) == .normal)
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(1) + 0.001, age: measuredAge, sex: sex) == (days <= 1856 ? .overweightRisk : .overweight))
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(2) + 0.001, age: measuredAge, sex: sex) == (days <= 1856 ? .overweight : .obesity))
                precondition(AgeSpecificBMI.assessment(bmi: lms.cutoff(3) + 0.001, age: measuredAge, sex: sex) == .obesity)
            }
        }
        precondition(AgeSpecificBMI.reference(days: -1, sex: .male) == nil)
        precondition(AgeSpecificBMI.reference(days: 6940, sex: .male) == nil)
        precondition(MeasurementAge(birthDate: birth, measurementDate: date(-1)) == nil)
        precondition(MeasurementAge(birthDate: .init(timeIntervalSinceReferenceDate: .nan), measurementDate: birth) == nil)
        // Child and adult categories must differ for the same BMI, including ages 18/19.
        let eighteenth = calendar.date(byAdding: .year, value: 18, to: birth)!
        let nineteenth = calendar.date(byAdding: .year, value: 19, to: birth)!
        let age18 = MeasurementAge(birthDate: birth, measurementDate: eighteenth)!
        let age19 = MeasurementAge(birthDate: birth, measurementDate: nineteenth)!
        let threshold18 = AgeSpecificBMI.reference(days: age18.days, sex: .male)!.cutoff(1)
        precondition(threshold18 < 25)
        precondition(AgeSpecificBMI.assessment(bmi: (threshold18 + 25) / 2, age: age18, sex: .male) == .overweight)
        precondition(AgeSpecificBMI.assessment(bmi: (threshold18 + 25) / 2, age: age19, sex: .male) == .normal)
        // FAO Table 5.2 independently transcribed expected values at each branch boundary.
        let cases: [(Int, Double, Double)] = [
            (0, 445.696, 435.436), (2, 445.696, 435.436),
            (3, 685.948, 648.42), (9, 685.948, 648.42),
            (10, 799.688, 799.672), (17, 799.688, 799.672),
            (18, 812.656, 605.144), (29, 812.656, 605.144),
            (30, 964.876, 910.608), (59, 964.876, 910.608),
            (60, 681.388, 731.156), (100, 681.388, 731.156)
        ]
        for (years, male, female) in cases {
            precondition(abs(AgeSpecificBasalEnergy.estimate(weightKG: 8, age: years, sex: .male)! - male) < 1e-8)
            precondition(abs(AgeSpecificBasalEnergy.estimate(weightKG: 8, age: years, sex: .female)! - female) < 1e-8)
        }
        precondition(AgeSpecificBasalEnergy.estimate(weightKG: .nan, age: 30, sex: .male) == nil)
        precondition(AgeSpecificBasalEnergy.estimate(weightKG: 8, age: -1, sex: .male) == nil)
        // An infant's low BMI must not block BMR; adults' body-composition rules are not reused.
        var infant = BodyMeasurement(date: date(180), weightKG: 7, impedanceOhm: 500, source: .wolaiAFU, isStable: true)
        profile.heightCM = 65
        let infantDisplay = BodyCompositionCalculation.applying(to: infant, profile: profile)
        precondition(infantDisplay.displayedBasalMetabolismKCal != nil)
        precondition(infantDisplay.displayedBodyFatPercent == nil && infantDisplay.displayedWaterPercent == nil)
        infant.bodyFatPercent = 25
        let reported = BodyCompositionCalculation.applying(to: infant, profile: profile)
        precondition(reported.displayedBodyFatPercent == 25 && reported.fatMassKG == 1.75)
        precondition(reported.applicationEstimate?.fatFreeMassKG == 5.25)
        precondition(reported.displayedBoneMassKG == nil && reported.displayedMuscleMassKG == nil && reported.displayedVisceralFat == nil)
        // No age permits estimates without primary impedance.
        let decoder = CommunicationRuleDecoder(weight: CommunicationField(offset: 0, length: 2, scale: 0.01),
            bodyFatPercent: CommunicationField(offset: 2, length: 2, scale: 0.1))
        profile.heightCM = 150
        for years in [6, 7, 15, 16, 83, 84, 100] {
            let measured = calendar.date(byAdding: .year, value: years, to: birth)!
            let raw = BodyMeasurement(date: measured, weightKG: 45, source: .bluetoothSIG, isStable: true)
            let result = BodyCompositionCalculation.applying(to: raw, profile: profile, decoder: decoder)
            precondition(result.applicationEstimate == nil)
            precondition(BodyCompositionCalculation.applying(to: raw, profile: profile).applicationEstimate == nil)
        }
        print("Age-specific calculation smoke checks passed")
    }
}
