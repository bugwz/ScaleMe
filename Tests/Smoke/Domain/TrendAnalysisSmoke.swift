import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private var calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    value.firstWeekday = 2
    return value
}()

private let profile = UserProfile(heightCM: 170)
private let endDate = Date(timeIntervalSince1970: 1_800_000_000)

private func date(daysBeforeEnd days: Int, hour: Int = 12) -> Date {
    guard let day = calendar.date(byAdding: .day, value: -days, to: endDate),
          let result = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else {
        fatalError("Unable to construct deterministic fixture date")
    }
    return result
}

private func measurement(daysBeforeEnd: Int, hour: Int = 12, weightKG: Double, bodyFat: Double? = nil) -> BodyMeasurement {
    BodyMeasurement(
        date: date(daysBeforeEnd: daysBeforeEnd, hour: hour),
        weightKG: weightKG,
        bodyFatPercent: bodyFat,
        source: .manual,
        isStable: true
    )
}

@main
private enum TrendAnalysisSmoke {
    static func main() {
        let fixtures = [
            measurement(daysBeforeEnd: 1, hour: 8, weightKG: 60, bodyFat: 20),
            measurement(daysBeforeEnd: 1, hour: 20, weightKG: 62, bodyFat: 22),
            measurement(daysBeforeEnd: 20, weightKG: 64),
            measurement(daysBeforeEnd: 40, weightKG: 66, bodyFat: 24),
            measurement(daysBeforeEnd: 400, weightKG: 70, bodyFat: 25)
        ]

        let monthWeights = TrendAnalysis.measurements(
            from: fixtures,
            metric: .weight,
            profile: profile,
            range: .month,
            endingAt: endDate,
            calendar: calendar
        )
        require(monthWeights.count == 3, "30-day range should exclude older measurements")

        let weekWeights = TrendAnalysis.measurements(
            from: fixtures,
            metric: .weight,
            profile: profile,
            range: .week,
            endingAt: endDate,
            calendar: calendar
        )
        let weekPoints = TrendAnalysis.points(
            from: weekWeights,
            metric: .weight,
            profile: profile,
            range: .week,
            mode: .period,
            calendar: calendar
        )
        require(weekWeights.count == 2, "7-day range should exclude older measurements")
        require(weekPoints.count == 1, "7-day period mode should produce one point per measured day")
        require(weekPoints.first?.value == 61, "7-day period mode should average same-day weights")

        let monthBodyFat = TrendAnalysis.measurements(
            from: fixtures,
            metric: .bodyFat,
            profile: profile,
            range: .month,
            endingAt: endDate,
            calendar: calendar
        )
        require(monthBodyFat.count == 2, "metric filtering should not fabricate unavailable values")

        let dailyPoints = TrendAnalysis.points(
            from: monthWeights,
            metric: .weight,
            profile: profile,
            range: .month,
            calendar: calendar
        )
        require(dailyPoints.count == 2, "month range should group measurements by day")
        require(dailyPoints.last?.value == 61, "same-day measurements should be averaged")
        require(dailyPoints.last?.measurementCount == 2, "point should retain its source count")
        require(
            dailyPoints.last?.date == calendar.startOfDay(for: date(daysBeforeEnd: 1)),
            "period points should align to the start of their calendar bucket"
        )

        let actualPoints = TrendAnalysis.points(
            from: monthWeights,
            metric: .weight,
            profile: profile,
            range: .month,
            mode: .actual,
            calendar: calendar
        )
        require(actualPoints.count == 3, "actual mode should retain every measurement")
        require(actualPoints.last?.date == date(daysBeforeEnd: 1, hour: 20), "actual mode should retain timestamps")

        require(
            TrendAnalysis.aggregation(for: .week, measurements: fixtures) == .day,
            "week period mode should use equal daily buckets"
        )
        require(
            TrendAnalysis.aggregation(for: .year, measurements: fixtures) == .month,
            "year range should use monthly density"
        )
        require(
            TrendAnalysis.aggregation(for: .all, measurements: fixtures) == .month,
            "long all-time range should adapt to monthly density"
        )
        require(
            Set(TrendMetric.allCases.map(\.systemImage)).count == TrendMetric.allCases.count,
            "each trend metric should have a distinct symbol"
        )

        let customInterval = date(daysBeforeEnd: 45) ... date(daysBeforeEnd: 15)
        let customWeights = TrendAnalysis.measurements(
            from: fixtures,
            metric: .weight,
            profile: profile,
            range: .custom,
            dateInterval: customInterval,
            endingAt: endDate,
            calendar: calendar
        )
        require(customWeights.count == 2, "custom range should include only measurements inside its bounds")
        require(
            TrendAnalysis.aggregation(
                for: .custom,
                measurements: customWeights,
                dateInterval: customInterval
            ) == .day,
            "custom range should adapt density to its selected span"
        )

        print("Trend analysis smoke checks passed")
    }
}
