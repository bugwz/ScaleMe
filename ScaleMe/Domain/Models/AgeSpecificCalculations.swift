import Foundation

struct MeasurementAge {
    let days: Int
    let years: Int
    let fractionalYears: Double

    init?(birthDate: Date, measurementDate: Date) {
        guard birthDate.timeIntervalSinceReferenceDate.isFinite,
              measurementDate.timeIntervalSinceReferenceDate.isFinite else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birth = calendar.startOfDay(for: birthDate)
        let measured = calendar.startOfDay(for: measurementDate)
        guard measured >= birth,
              let days = calendar.dateComponents([.day], from: birth, to: measured).day,
              let years = calendar.dateComponents([.year], from: birth, to: measured).year,
              days >= 0, years >= 0 else { return nil }
        self.days = days
        self.years = years
        guard let anniversary = calendar.date(byAdding: .year, value: years, to: birth),
              let nextAnniversary = calendar.date(byAdding: .year, value: years + 1, to: birth),
              let elapsed = calendar.dateComponents([.day], from: anniversary, to: measured).day,
              let duration = calendar.dateComponents([.day], from: anniversary, to: nextAnniversary).day,
              duration > 0 else { return nil }
        self.fractionalYears = Double(years) + Double(elapsed) / Double(duration)
    }
}

enum AgeSpecificBMI {
    struct LMS {
        let l: Double
        let m: Double
        let s: Double

        func cutoff(_ z: Double) -> Double {
            abs(l) < 1e-12 ? m * exp(s * z) : m * pow(1 + l * s * z, 1 / l)
        }
    }

    private static func decode(_ text: String) -> [LMS] {
        text.split(separator: "\n").compactMap { line in
            let values = line.split(separator: ",").compactMap { Double($0) }
            guard values.count == 3 else { return nil }
            return LMS(l: values[0], m: values[1], s: values[2])
        }
    }

    private static let childBoys = decode(WHOBodyMassReferenceData.childBoys)
    private static let childGirls = decode(WHOBodyMassReferenceData.childGirls)
    private static let youthBoys = decode(WHOBodyMassReferenceData.youthBoys)
    private static let youthGirls = decode(WHOBodyMassReferenceData.youthGirls)

    static func reference(days: Int, sex: UserProfile.BiologicalSex) -> LMS? {
        guard days >= 0 else { return nil }
        if days <= 1856 {
            let rows = sex == .male ? childBoys : childGirls
            return rows.indices.contains(days) ? rows[days] : nil
        }
        // WHO age conversion: mean month = 365.25 / 12 days. Interpolate the
        // published monthly LMS values, rather than rounding a child to adult age.
        let month = Double(days) / 30.4375
        guard month >= 61, month <= 228 else { return nil }
        let rows = sex == .male ? youthBoys : youthGirls
        let index = Int(month.rounded(.down)) - 61
        guard rows.indices.contains(index) else { return nil }
        let first = rows[index]
        guard rows.indices.contains(index + 1) else { return first }
        let next = rows[index + 1]
        let fraction = month - floor(month)
        return LMS(l: first.l + (next.l - first.l) * fraction,
                   m: first.m + (next.m - first.m) * fraction,
                   s: first.s + (next.s - first.s) * fraction)
    }

    static func assessment(bmi: Double, age: MeasurementAge, sex: UserProfile.BiologicalSex) -> MetricAssessment {
        guard bmi.isFinite, bmi > 0 else { return .invalid }
        if age.years >= 19 {
            if bmi < 18.5 { return .low }
            if bmi < 25 { return .normal }
            if bmi < 30 { return .overweight }
            return .obesity
        }
        guard let lms = reference(days: age.days, sex: sex) else { return .notApplicable }
        // Compare BMI directly with LMS cutoffs, avoiding z-score tail extrapolation.
        if bmi < lms.cutoff(-3) { return .severelyLow }
        if bmi < lms.cutoff(-2) { return .low }
        if age.days <= 1856 {
            if bmi > lms.cutoff(3) { return .obesity }
            if bmi > lms.cutoff(2) { return .overweight }
            if bmi > lms.cutoff(1) { return .overweightRisk }
        } else {
            if bmi > lms.cutoff(2) { return .obesity }
            if bmi > lms.cutoff(1) { return .overweight }
        }
        return .normal
    }
}

enum AgeSpecificBasalEnergy {
    // FAO/WHO/UNU Human energy requirements, Table 5.2, Schofield (1985).
    // kcal/day = slope * weightKG + intercept; NOT daily dietary requirements.
    static func estimate(weightKG: Double, age: Int, sex: UserProfile.BiologicalSex) -> Double? {
        guard weightKG.isFinite, weightKG > 0, MeasurementLimits.weightKG.contains(weightKG), age >= 0 else { return nil }
        let coefficients: (Double, Double)
        switch (sex, age) {
        case (.male, 0..<3): coefficients = (59.512, -30.4)
        case (.male, 3..<10): coefficients = (22.706, 504.3)
        case (.male, 10..<18): coefficients = (17.686, 658.2)
        case (.male, 18..<30): coefficients = (15.057, 692.2)
        case (.male, 30..<60): coefficients = (11.472, 873.1)
        case (.male, _): coefficients = (11.711, 587.7)
        case (.female, 0..<3): coefficients = (58.317, -31.1)
        case (.female, 3..<10): coefficients = (20.315, 485.9)
        case (.female, 10..<18): coefficients = (13.384, 692.6)
        case (.female, 18..<30): coefficients = (14.818, 486.6)
        case (.female, 30..<60): coefficients = (8.126, 845.6)
        case (.female, _): coefficients = (9.082, 658.5)
        }
        let value = coefficients.0 * weightKG + coefficients.1
        return value.isFinite && value > 0 ? value : nil
    }
}
