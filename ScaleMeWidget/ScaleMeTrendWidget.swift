import AppIntents
import Charts
import SwiftUI
import WidgetKit

enum WidgetTrendMetric: String, AppEnum {
    case weight, bmi, bodyFat, fatMass, muscleMass, musclePercent
    case waterPercent, waterMass, proteinPercent, proteinMass
    case boneMass, bonePercent, visceralFat, basalMetabolism

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "趋势类别"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .weight: "体重", .bmi: "BMI", .bodyFat: "体脂率", .fatMass: "脂肪量",
        .muscleMass: "肌肉量", .musclePercent: "肌肉率", .waterPercent: "身体水分",
        .waterMass: "水分量", .proteinPercent: "蛋白质占比", .proteinMass: "蛋白质量",
        .boneMass: "骨量", .bonePercent: "骨量占比", .visceralFat: "内脏脂肪",
        .basalMetabolism: "基础代谢"
    ]
}

enum WidgetTimeRange: String, AppEnum {
    case week, month, quarter, halfYear, year, all

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "时间范围"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .week: "近 7 天", .month: "近 30 天", .quarter: "近 3 个月",
        .halfYear: "近 6 个月", .year: "近 1 年", .all: "全部时间"
    ]
}

enum WidgetDisplayStyle: String, AppEnum {
    case periodFocused, periodFullRange, actualFocused, actualFullRange

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "显示方式"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .periodFocused: "汇总趋势 · 聚焦数据",
        .periodFullRange: "汇总趋势 · 完整区间",
        .actualFocused: "逐次测量 · 聚焦数据",
        .actualFullRange: "逐次测量 · 完整区间"
    ]

    var shortTitle: LocalizedStringKey {
        switch self {
        case .periodFocused, .periodFullRange: "汇总"
        case .actualFocused, .actualFullRange: "逐次"
        }
    }
}

struct WidgetProfileEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "用户"
    static let defaultQuery = WidgetProfileQuery()

    let id: String
    let name: String
    let relation: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(relation)")
    }
}

struct WidgetProfileQuery: EntityQuery {
    func entities(for identifiers: [WidgetProfileEntity.ID]) async throws -> [WidgetProfileEntity] {
        profiles.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetProfileEntity] { profiles }

    func defaultResult() async -> WidgetProfileEntity? {
        guard let snapshot = try? WidgetTrendRepository().load() else { return nil }
        return snapshot.profile(id: snapshot.defaultProfileID).map(WidgetProfileEntity.init)
    }

    private var profiles: [WidgetProfileEntity] {
        ((try? WidgetTrendRepository().load())?.profiles ?? []).map(WidgetProfileEntity.init)
    }
}

struct WidgetDeviceEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "来源设备"
    static let defaultQuery = WidgetDeviceQuery()
    static var all: WidgetDeviceEntity {
        WidgetDeviceEntity(
            id: "all",
            name: (try? WidgetTrendRepository().load())?.allDevicesTitle
                ?? String(localized: "全部设备"),
            modelName: ""
        )
    }

    let id: String
    let name: String
    let modelName: String

    var displayRepresentation: DisplayRepresentation {
        modelName.isEmpty
            ? DisplayRepresentation(title: "\(name)")
            : DisplayRepresentation(title: "\(name)", subtitle: "\(modelName)")
    }
}

struct WidgetDeviceQuery: EntityQuery {
    func entities(for identifiers: [WidgetDeviceEntity.ID]) async throws -> [WidgetDeviceEntity] {
        devices.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetDeviceEntity] { devices }
    func defaultResult() async -> WidgetDeviceEntity? { .all }

    private var devices: [WidgetDeviceEntity] {
        let snapshot = try? WidgetTrendRepository().load()
        let all = WidgetDeviceEntity(
            id: "all",
            name: snapshot?.allDevicesTitle ?? String(localized: "全部设备"),
            modelName: ""
        )
        return [all] + (snapshot?.devices ?? []).map(WidgetDeviceEntity.init)
    }
}

struct TrendWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "趋势图"
    static let description = IntentDescription("设置趋势类别、时间范围、来源设备、用户和显示方式。")

    @Parameter(title: "趋势类别", default: .weight) var metric: WidgetTrendMetric
    @Parameter(title: "时间范围", default: .month) var timeRange: WidgetTimeRange
    @Parameter(title: "来源设备") var device: WidgetDeviceEntity?
    @Parameter(title: "用户") var profile: WidgetProfileEntity?
    @Parameter(title: "显示方式", default: .periodFocused) var displayStyle: WidgetDisplayStyle
}

struct TrendWidgetEntry: TimelineEntry {
    let date: Date
    let localeIdentifier: String
    let displayStyle: WidgetDisplayStyle
    let series: WidgetTrendSeries?
    let dateDomain: ClosedRange<Date>?
}

struct TrendWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TrendWidgetEntry {
        makeEntry(
            metric: .weight,
            timeRange: .month,
            deviceID: "all",
            profileID: WidgetTrendSnapshot.placeholder.defaultProfileID,
            displayStyle: .periodFocused,
            snapshot: .placeholder
        )
    }

    func snapshot(for configuration: TrendWidgetIntent, in context: Context) async -> TrendWidgetEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: TrendWidgetIntent, in context: Context) async -> Timeline<TrendWidgetEntry> {
        let entry = makeEntry(configuration: configuration)
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func makeEntry(configuration: TrendWidgetIntent) -> TrendWidgetEntry {
        let snapshot = try? WidgetTrendRepository().load()
        let profileID: String?
        if let requestedProfileID = configuration.profile?.id,
           snapshot?.profiles.contains(where: { $0.id == requestedProfileID }) == true {
            profileID = requestedProfileID
        } else {
            profileID = snapshot?.defaultProfileID
        }
        let requestedDeviceID = configuration.device?.id ?? "all"
        let deviceID = requestedDeviceID == "all"
            || snapshot?.devices.contains(where: { $0.id == requestedDeviceID }) == true
            ? requestedDeviceID
            : "all"
        return makeEntry(
            metric: configuration.metric,
            timeRange: configuration.timeRange,
            deviceID: deviceID,
            profileID: profileID,
            displayStyle: configuration.displayStyle,
            snapshot: snapshot
        )
    }

    private func makeEntry(
        metric: WidgetTrendMetric,
        timeRange: WidgetTimeRange,
        deviceID: String?,
        profileID: String?,
        displayStyle: WidgetDisplayStyle,
        snapshot: WidgetTrendSnapshot?
    ) -> TrendWidgetEntry {
        let now = Date.now
        return TrendWidgetEntry(
            date: now,
            localeIdentifier: snapshot?.localeIdentifier ?? Locale.current.identifier,
            displayStyle: displayStyle,
            series: snapshot?.series(
                metricID: metric.rawValue,
                profileID: profileID,
                deviceID: deviceID,
                rangeID: timeRange.rawValue,
                displayStyleID: displayStyle.rawValue,
                endingAt: now
            ),
            dateDomain: snapshot?.dateDomain(
                rangeID: timeRange.rawValue,
                displayStyleID: displayStyle.rawValue,
                endingAt: now
            )
        )
    }
}

struct ScaleMeTrendWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetTrendRepository.widgetKind,
            intent: TrendWidgetIntent.self,
            provider: TrendWidgetProvider()
        ) { entry in
            TrendWidgetView(entry: entry)
                .environment(\.locale, Locale(identifier: entry.localeIdentifier))
                .containerBackground(for: .widget) { WidgetPalette.canvas }
        }
        .configurationDisplayName("身体趋势")
        .description("分别设置类别、时间、设备、用户和趋势显示方式。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct ScaleMeWidgetBundle: WidgetBundle {
    var body: some Widget { ScaleMeTrendWidget() }
}

private struct TrendWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: TrendWidgetEntry

    var body: some View {
        Group {
            if let series = entry.series { content(series) } else { unavailableContent }
        }
        .widgetURL(URL(string: "scaleme://trends"))
    }

    @ViewBuilder
    private func content(_ series: WidgetTrendSeries) -> some View {
        switch widgetFamily {
        case .systemSmall:
            compactContent(series)
        case .systemLarge:
            detailedContent(series)
        default:
            mediumContent(series)
        }
    }

    private func compactContent(_ series: WidgetTrendSeries) -> some View {
        let metricColor = TrendMetricPalette.color(forMetricID: series.metadata.metricID)

        return VStack(alignment: .leading, spacing: 6) {
            Label(series.metadata.title, systemImage: series.metadata.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(1)

            if let latest = series.latestPoint {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formattedValue(latest.value))
                        .font(.title.bold())
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                    if !series.metadata.unit.isEmpty {
                        Text(series.metadata.unit)
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(metricColor)

                if let change = change(for: series.points) {
                    changeLabel(change, color: metricColor)
                }
            }

            if series.points.isEmpty {
                noMeasurements
            } else {
                trendChart(series.points, color: metricColor)
                    .frame(minHeight: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(series.profileName) · \(series.rangeTitle)")
                    .lineLimit(1)
                if series.metadata.isEstimated {
                    estimatedDisclaimer
                }
            }
            .font(.caption2)
            .foregroundStyle(WidgetPalette.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func mediumContent(_ series: WidgetTrendSeries) -> some View {
        let metricColor = TrendMetricPalette.color(forMetricID: series.metadata.metricID)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(series.metadata.title, systemImage: series.metadata.systemImage)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let latest = series.latestPoint {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(formattedValue(latest.value))
                            .font(.title3.bold())
                            .monospacedDigit()
                        if !series.metadata.unit.isEmpty {
                            Text(series.metadata.unit).font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(metricColor)
                }
            }

            if series.points.isEmpty {
                noMeasurements
            } else {
                trendChart(series.points, color: metricColor)
            }

            HStack(spacing: 4) {
                Text("\(series.profileName) · \(series.deviceName)").lineLimit(1)
                Spacer(minLength: 4)
                if series.metadata.isEstimated {
                    estimatedDisclaimer
                    Text("·")
                }
                Text(entry.displayStyle.shortTitle)
                Text("·")
                Text(series.rangeTitle)
            }
            .font(.caption2)
            .foregroundStyle(WidgetPalette.secondary)
        }
        .padding(2)
        .accessibilityElement(children: .combine)
    }

    private func detailedContent(_ series: WidgetTrendSeries) -> some View {
        let metricColor = TrendMetricPalette.color(forMetricID: series.metadata.metricID)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(series.metadata.title, systemImage: series.metadata.systemImage)
                        .font(.headline)
                        .foregroundStyle(WidgetPalette.ink)
                    Text("\(series.profileName) · \(series.deviceName)")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let latest = series.latestPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(formattedValue(latest.value))
                                .font(.title2.bold())
                                .monospacedDigit()
                            if !series.metadata.unit.isEmpty {
                                Text(series.metadata.unit)
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .foregroundStyle(metricColor)
                        Text(latest.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.secondary)
                    }
                }
            }

            if series.points.isEmpty {
                noMeasurements
            } else {
                HStack(spacing: 8) {
                    statisticCard(
                        title: "较期初",
                        value: change(for: series.points).map {
                            series.metadata.formattedSignedValue($0)
                        } ?? "--",
                        unit: series.metadata.unit,
                        color: metricColor
                    )
                    statisticCard(
                        title: "平均",
                        value: series.metadata.formattedValue(average(of: series.points)),
                        unit: series.metadata.unit,
                        color: WidgetPalette.ink
                    )
                    statisticCard(
                        title: "区间",
                        value: formattedRange(of: series.points),
                        unit: series.metadata.unit,
                        color: WidgetPalette.ink
                    )
                }

                detailedTrendChart(series.points, color: metricColor)
            }

            HStack(spacing: 4) {
                Text(entry.displayStyle.shortTitle)
                Text("·")
                Text(series.rangeTitle)
                Spacer(minLength: 4)
                Text(series.measurementCount, format: .number)
                Text("次记录")
            }
            .font(.caption2)
            .foregroundStyle(WidgetPalette.secondary)

            if series.metadata.isEstimated {
                estimatedDisclaimer
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.secondary)
            }
        }
        .padding(2)
        .accessibilityElement(children: .combine)
    }

    private func statisticCard(
        title: LocalizedStringKey,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(WidgetPalette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(WidgetPalette.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
    }

    private func changeLabel(_ change: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: changeIcon(for: change))
            Text("较期初")
            Text(entry.series?.metadata.formattedSignedValue(change) ?? "--")
            if let unit = entry.series?.metadata.unit, !unit.isEmpty {
                Text(unit)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(1)
    }

    private var estimatedDisclaimer: some View {
        Label("估算数据，仅供趋势参考", systemImage: "info.circle")
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private func trendChart(_ points: [WidgetTrendPoint], color: Color) -> some View {
        Chart(points, id: \.id) { point in
            AreaMark(
                x: .value("日期", point.date),
                yStart: .value("基线", chartValueDomain(for: points).lowerBound),
                yEnd: .value("数值", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(x: .value("日期", point.date), y: .value("数值", point.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(entry.displayStyle.rawValue.hasPrefix("actual") ? .linear : .catmullRom)

            PointMark(x: .value("日期", point.date), y: .value("数值", point.value))
                .foregroundStyle(color)
                .symbolSize(points.count == 1 ? 34 : 12)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: chartDateDomain(for: points))
        .chartYScale(domain: chartValueDomain(for: points))
    }

    private func detailedTrendChart(_ points: [WidgetTrendPoint], color: Color) -> some View {
        Chart(points, id: \.id) { point in
            AreaMark(
                x: .value("日期", point.date),
                yStart: .value("基线", chartValueDomain(for: points).lowerBound),
                yEnd: .value("数值", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.24), color.opacity(0.01)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(x: .value("日期", point.date), y: .value("数值", point.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(entry.displayStyle.rawValue.hasPrefix("actual") ? .linear : .catmullRom)

            PointMark(x: .value("日期", point.date), y: .value("数值", point.value))
                .foregroundStyle(color)
                .symbolSize(points.count == 1 ? 34 : 12)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(WidgetPalette.secondary.opacity(0.12))
                AxisValueLabel(format: .dateTime.month(.twoDigits).day())
                    .foregroundStyle(WidgetPalette.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(WidgetPalette.secondary.opacity(0.12))
                AxisValueLabel(
                    format: FloatingPointFormatStyle<Double>.number.precision(
                        .fractionLength(entry.series?.metadata.fractionDigits ?? 2)
                    )
                )
                .foregroundStyle(WidgetPalette.secondary)
            }
        }
        .chartXScale(domain: chartDateDomain(for: points))
        .chartYScale(domain: chartValueDomain(for: points))
    }

    private func change(for points: [WidgetTrendPoint]) -> Double? {
        guard let first = points.first, let latest = points.last, first.id != latest.id else { return nil }
        return latest.value - first.value
    }

    private func average(of points: [WidgetTrendPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private func formattedRange(of points: [WidgetTrendPoint]) -> String {
        guard let minimum = points.map(\.value).min(), let maximum = points.map(\.value).max() else {
            return "--"
        }
        guard let metadata = entry.series?.metadata else { return "--" }
        return "\(metadata.formattedValue(minimum))–\(metadata.formattedValue(maximum))"
    }

    private func formattedValue(_ value: Double) -> String {
        entry.series?.metadata.formattedValue(value) ?? "--"
    }

    private func changeIcon(for change: Double) -> String {
        if abs(change) < 0.005 { return "minus" }
        return change > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private func chartDateDomain(for points: [WidgetTrendPoint]) -> ClosedRange<Date> {
        if let dateDomain = entry.dateDomain { return dateDomain }
        guard let first = points.first?.date, let last = points.last?.date else {
            return entry.date ... entry.date.addingTimeInterval(1)
        }
        return first == last
            ? first.addingTimeInterval(-43_200) ... last.addingTimeInterval(43_200)
            : first ... last
    }

    private func chartValueDomain(for points: [WidgetTrendPoint]) -> ClosedRange<Double> {
        let values = points.map(\.value)
        guard let minimum = values.min(), let maximum = values.max() else { return 0 ... 1 }
        let padding = max((maximum - minimum) * 0.22, max(abs(maximum) * 0.015, 0.5))
        return (minimum - padding) ... (maximum + padding)
    }

    private var noMeasurements: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
            Text("所选范围暂无此项数据")
        }
        .font(.subheadline)
        .foregroundStyle(WidgetPalette.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("身体趋势", systemImage: "chart.xyaxis.line")
                .font(.headline)
                .foregroundStyle(WidgetPalette.ink)
            Spacer()
            Text("打开观我后即可配置用户与设备趋势")
                .font(.subheadline)
                .foregroundStyle(WidgetPalette.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(2)
    }
}

private enum WidgetPalette {
    static let ink = Color(red: 18 / 255, green: 51 / 255, blue: 46 / 255)
    static let secondary = Color(red: 92 / 255, green: 120 / 255, blue: 115 / 255)
    static let canvas = Color(red: 246 / 255, green: 252 / 255, blue: 250 / 255)
    static let paleMint = Color(red: 230 / 255, green: 250 / 255, blue: 242 / 255)
}

private extension WidgetProfileEntity {
    init(_ profile: WidgetTrendProfile) {
        self.init(id: profile.id, name: profile.name, relation: profile.relation)
    }
}

private extension WidgetDeviceEntity {
    init(_ device: WidgetTrendDevice) {
        self.init(id: device.id, name: device.name, modelName: device.modelName)
    }
}

private extension WidgetTrendSnapshot {
    static let placeholder: WidgetTrendSnapshot = {
        let profile = WidgetTrendProfile(
            id: "preview",
            name: String(localized: "我"),
            relation: String(localized: "本人")
        )
        let metric = WidgetTrendMetricMetadata(
            metricID: WidgetTrendMetric.weight.rawValue,
            title: String(localized: "体重"),
            systemImage: "scalemass.fill",
            unit: "kg",
            fractionDigits: 2,
            isEstimated: false
        )
        let measurements = (0..<8).map { index in
            WidgetTrendMeasurement(
                id: "preview-\(index)",
                profileID: profile.id,
                deviceID: nil,
                date: Calendar.current.date(byAdding: .day, value: index - 7, to: .now) ?? .now,
                values: [metric.metricID: 60.2 + sin(Double(index) * 0.9) * 0.6]
            )
        }
        return WidgetTrendSnapshot(
            generatedAt: .now,
            localeIdentifier: Locale.current.identifier,
            defaultProfileID: profile.id,
            rangeTitles: ["month": String(localized: "近 30 天")],
            allDevicesTitle: String(localized: "全部设备"),
            metrics: [metric],
            profiles: [profile],
            devices: [],
            measurements: measurements
        )
    }()
}
