import Foundation

enum TrendMetric: String, CaseIterable, Identifiable {
    case weight
    case bmi
    case bodyFat
    case fatMass
    case muscleMass
    case musclePercent
    case waterPercent
    case waterMass
    case boneMass
    case bonePercent
    case visceralFat
    case basalMetabolism

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "体重"
        case .bmi: "BMI"
        case .bodyFat: "体脂率"
        case .fatMass: "脂肪量"
        case .muscleMass: "肌肉量"
        case .musclePercent: "肌肉率"
        case .waterPercent: "身体水分"
        case .waterMass: "水分量"
        case .boneMass: "骨量"
        case .bonePercent: "骨量占比"
        case .visceralFat: "内脏脂肪"
        case .basalMetabolism: "基础代谢"
        }
    }

    var systemImage: String {
        switch self {
        case .weight: "scalemass.fill"
        case .bmi: "ruler"
        case .bodyFat: "drop.fill"
        case .fatMass: "circle.dashed.inset.filled"
        case .muscleMass: "figure.strengthtraining.traditional"
        case .musclePercent: "figure.strengthtraining.functional"
        case .waterPercent: "humidity.fill"
        case .waterMass: "water.waves"
        case .boneMass: "figure.walk.motion"
        case .bonePercent: "figure.stand"
        case .visceralFat: "circle.circle"
        case .basalMetabolism: "flame.fill"
        }
    }

    var isEstimatedComposition: Bool {
        self != .weight && self != .bmi
    }

    var displayFractionDigits: Int { 2 }

    func value(for measurement: BodyMeasurement, profile: UserProfile) -> Double? {
        switch self {
        case .weight: measurement.weightKG
        case .bmi: measurement.bmi(heightCM: profile.heightCM)
        case .bodyFat: measurement.bodyFatPercent
        case .fatMass: measurement.fatMassKG
        case .muscleMass: measurement.muscleMassKG
        case .musclePercent: measurement.musclePercent
        case .waterPercent: measurement.waterPercent
        case .waterMass: measurement.waterMassKG
        case .boneMass: measurement.boneMassKG
        case .bonePercent: measurement.bonePercent
        case .visceralFat: measurement.visceralFat
        case .basalMetabolism: measurement.basalMetabolismKCal
        }
    }

    func displayValue(_ value: Double, unit: WeightUnit) -> Double {
        switch self {
        case .weight, .fatMass, .muscleMass, .waterMass, .boneMass:
            unit.value(fromKilograms: value)
        default:
            value
        }
    }

    func unitLabel(weightUnit: WeightUnit) -> String {
        switch self {
        case .weight, .fatMass, .muscleMass, .waterMass, .boneMass: weightUnit.symbol
        case .bodyFat, .musclePercent, .waterPercent, .bonePercent: "%"
        case .basalMetabolism: "kcal"
        case .bmi, .visceralFat: ""
        }
    }
}

enum TrendTimeRange: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case halfYear
    case year
    case all
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "近 7 天"
        case .month: "近 30 天"
        case .quarter: "近 3 个月"
        case .halfYear: "近 6 个月"
        case .year: "近 1 年"
        case .all: "全部时间"
        case .custom: "自定义范围"
        }
    }

    func startDate(endingAt endDate: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .week: calendar.date(byAdding: .day, value: -7, to: endDate)
        case .month: calendar.date(byAdding: .day, value: -30, to: endDate)
        case .quarter: calendar.date(byAdding: .month, value: -3, to: endDate)
        case .halfYear: calendar.date(byAdding: .month, value: -6, to: endDate)
        case .year: calendar.date(byAdding: .year, value: -1, to: endDate)
        case .all, .custom: nil
        }
    }
}

enum TrendDisplayScope: String, CaseIterable, Identifiable {
    case selectedRange
    case availableData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selectedRange: "完整区间"
        case .availableData: "聚焦数据"
        }
    }
}

enum TrendChartMode: String, CaseIterable, Identifiable {
    case period
    case actual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .period: "汇总趋势"
        case .actual: "逐次测量"
        }
    }

    var subtitle: String {
        switch self {
        case .period: "按时间跨度合并为日、周或月均值"
        case .actual: "保留每次测量及其真实时间位置"
        }
    }

    var systemImage: String {
        switch self {
        case .period: "calendar.day.timeline.leading"
        case .actual: "point.3.connected.trianglepath.dotted"
        }
    }
}

struct TrendPoint: Identifiable, Equatable {
    let id: Date
    let date: Date
    let value: Double
    let measurementCount: Int
}

enum TrendAggregation: Equatable {
    case measurement
    case day
    case week
    case month
}

enum TrendAnalysis {
    static func measurements(
        from measurements: [BodyMeasurement],
        metric: TrendMetric,
        profile: UserProfile,
        range: TrendTimeRange,
        dateInterval: ClosedRange<Date>? = nil,
        endingAt endDate: Date = .now,
        calendar: Calendar = .current
    ) -> [BodyMeasurement] {
        let effectiveEndDate = dateInterval?.upperBound ?? endDate
        let startDate = dateInterval?.lowerBound ?? range.startDate(endingAt: effectiveEndDate, calendar: calendar)
        return measurements.filter { measurement in
            guard measurement.date <= effectiveEndDate,
                  metric.value(for: measurement, profile: profile) != nil else {
                return false
            }
            guard let startDate else { return true }
            return measurement.date >= startDate
        }
    }

    static func aggregation(
        for range: TrendTimeRange,
        measurements: [BodyMeasurement],
        dateInterval: ClosedRange<Date>? = nil
    ) -> TrendAggregation {
        switch range {
        case .week:
            return .day
        case .month:
            return .day
        case .quarter, .halfYear:
            return .week
        case .year:
            return .month
        case .custom:
            guard let dateInterval else { return .measurement }
            return aggregation(forDaySpan: dateInterval.upperBound.timeIntervalSince(dateInterval.lowerBound) / 86_400)
        case .all:
            guard let first = measurements.min(by: { $0.date < $1.date })?.date,
                  let last = measurements.max(by: { $0.date < $1.date })?.date else {
                return .measurement
            }
            return aggregation(forDaySpan: last.timeIntervalSince(first) / 86_400)
        }
    }

    static func points(
        from measurements: [BodyMeasurement],
        metric: TrendMetric,
        profile: UserProfile,
        range: TrendTimeRange,
        dateInterval: ClosedRange<Date>? = nil,
        mode: TrendChartMode = .period,
        calendar: Calendar = .current
    ) -> [TrendPoint] {
        let aggregation = mode == .actual
            ? TrendAggregation.measurement
            : aggregation(for: range, measurements: measurements, dateInterval: dateInterval)
        let valued = measurements.compactMap { measurement -> (Date, Double)? in
            metric.value(for: measurement, profile: profile).map { (measurement.date, $0) }
        }

        if aggregation == .measurement {
            return valued
                .map { TrendPoint(id: $0.0, date: $0.0, value: $0.1, measurementCount: 1) }
                .sorted { $0.date < $1.date }
        }

        let grouped = Dictionary(grouping: valued) { value in
            bucketStart(for: value.0, aggregation: aggregation, calendar: calendar)
        }

        return grouped.map { bucket, values in
            TrendPoint(
                id: bucket,
                date: bucket,
                value: values.map(\.1).reduce(0, +) / Double(values.count),
                measurementCount: values.count
            )
        }
        .sorted { $0.date < $1.date }
    }

    private static func aggregation(forDaySpan days: Double) -> TrendAggregation {
        if days <= 45 { return .day }
        if days <= 200 { return .week }
        return .month
    }

    private static func bucketStart(
        for date: Date,
        aggregation: TrendAggregation,
        calendar: Calendar
    ) -> Date {
        switch aggregation {
        case .measurement: date
        case .day: calendar.startOfDay(for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month: calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }
}
