import Charts
import SwiftUI
import UIKit

struct ExpandedTrendContext: Identifiable {
    let metric: TrendMetric
    let points: [TrendPoint]
    let allPoints: [TrendPoint]
    let measurementDates: [Date]
    let measurementCount: Int
    let chartMode: TrendChartMode
    let aggregation: TrendAggregation

    var id: String { metric.id }
}

struct ExpandedTrendPresentation: Identifiable {
    let context: ExpandedTrendContext
    let unit: WeightUnit
    let range: TrendTimeRange
    let rangeTitle: String
    let dateInterval: ClosedRange<Date>?
    let displayScope: TrendDisplayScope

    var id: String { context.id }
}

struct TrendChartCard: View {
    @Environment(\.appLanguage) private var language
    let metric: TrendMetric
    let measurements: [BodyMeasurement]
    let profile: UserProfile
    let unit: WeightUnit
    let range: TrendTimeRange
    let dateInterval: ClosedRange<Date>?
    let displayScope: TrendDisplayScope
    let chartMode: TrendChartMode
    let onExpand: (ExpandedTrendContext) -> Void

    @State private var selectedDate: Date?

    var body: some View {
        let filteredMeasurements = TrendAnalysis.measurements(
            from: measurements,
            metric: metric,
            profile: profile,
            range: range,
            dateInterval: dateInterval
        )
        let points = TrendAnalysis.points(
            from: filteredMeasurements,
            metric: metric,
            profile: profile,
            range: range,
            dateInterval: dateInterval,
            mode: chartMode
        )
        let allMetricMeasurements = TrendAnalysis.measurements(
            from: measurements,
            metric: metric,
            profile: profile,
            range: .all
        )
        let allPoints = TrendAnalysis.points(
            from: allMetricMeasurements,
            metric: metric,
            profile: profile,
            range: .all,
            mode: .actual
        )
        let aggregation = chartMode == .actual
            ? TrendAggregation.measurement
            : TrendAnalysis.aggregation(for: range, measurements: filteredMeasurements, dateInterval: dateInterval)
        let rangeChangeText: String? = {
        guard let first = points.first, let last = points.last else { return nil }
        let delta = metric.displayValue(last.value - first.value, unit: unit)
        let sign = delta > 0 ? "+" : ""
        let unitLabel = metric.unitLabel(weightUnit: unit)
        let suffix = unitLabel.isEmpty ? "" : " \(unitLabel)"
        return "\(sign)\(delta.formatted(metric.displayFractionDigits))\(suffix)"
        }()

        return SoftCard(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label {
                        AppLocalizedText(metric.title)
                    } icon: {
                        trendMetricIcon(metric, size: 18)
                    }
                        .font(.headline)
                        .foregroundStyle(metricTint(metric))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    if let rangeChangeText {
                        Text(rangeChangeText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(metricTint(metric))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Button {
                        onExpand(ExpandedTrendContext(
                            metric: metric,
                            points: points,
                            allPoints: allPoints,
                            measurementDates: allMetricMeasurements.map(\.date).sorted(),
                            measurementCount: filteredMeasurements.count,
                            chartMode: chartMode,
                            aggregation: aggregation
                        ))
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.secondary)
                    .accessibilityLabel(language.format("放大%@趋势图", language.text(metric.title)))
                }

                TrendChartPlot(
                    metric: metric,
                    points: points,
                    unit: unit,
                    range: range,
                    dateInterval: dateInterval,
                    displayScope: displayScope,
                    chartMode: chartMode,
                    aggregation: aggregation,
                    selectedDate: $selectedDate,
                    isExpanded: false
                )
                .frame(height: 168)
            }
        }
        .onChange(of: range) { selectedDate = nil }
        .onChange(of: dateInterval) { selectedDate = nil }
        .onChange(of: displayScope) { selectedDate = nil }
        .onChange(of: chartMode) { selectedDate = nil }
    }
}

struct ExpandedTrendChartView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language

    let presentation: ExpandedTrendPresentation
    let onClose: () -> Void

    @State private var selectedDate: Date?
    @State private var visibleDateRange: ClosedRange<Date>?
    @State private var isContentVisible = true
    @State private var isClosing = false

    private var context: ExpandedTrendContext { presentation.context }

    private var visibleMeasurementCount: Int {
        guard let visibleDateRange else { return context.measurementCount }
        let lowerIndex = context.measurementDates.firstPartitionIndex {
            $0 >= visibleDateRange.lowerBound
        }
        let upperIndex = context.measurementDates.firstPartitionIndex {
            $0 > visibleDateRange.upperBound
        }
        return upperIndex - lowerIndex
    }

    private var visibleRangeTitle: String {
        guard let visibleDateRange else { return language.text(presentation.rangeTitle) }
        let span = visibleDateRange.upperBound.timeIntervalSince(visibleDateRange.lowerBound)
        let style = span <= 2 * 86_400
            ? Date.FormatStyle.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
            : Date.FormatStyle.dateTime.year().month(.twoDigits).day(.twoDigits)
        return "\(visibleDateRange.lowerBound.formatted(style.locale(language.locale)))–\(visibleDateRange.upperBound.formatted(style.locale(language.locale)))"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.format("%@趋势", language.text(context.metric.title)))
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.ink)
                    Text(
                        language.format(
                            "%@ · %lld 次测量",
                            visibleRangeTitle,
                            visibleMeasurementCount
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Button {
                    guard !isClosing else { return }
                    isClosing = true
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                        isContentVisible = false
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 180))
                        onClose()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.ink)
                .disabled(isClosing)
                .accessibilityLabel("关闭全屏趋势图")
            }

            TrendChartPlot(
                metric: context.metric,
                points: context.points,
                unit: presentation.unit,
                range: presentation.range,
                dateInterval: presentation.dateInterval,
                displayScope: presentation.displayScope,
                chartMode: context.chartMode,
                aggregation: context.aggregation,
                selectedDate: $selectedDate,
                isExpanded: true,
                allPoints: context.allPoints,
                onVisibleDateRangeChange: { visibleDateRange = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .opacity(isContentVisible ? 1 : 0)
        .scaleEffect(isContentVisible || reduceMotion ? 1 : 0.99)
        .compositingGroup()
    }
}

enum TrendFilterPopover: Hashable {
    case metrics
    case timeRange
    case source
    case profile
    case displayScope
}

struct TrendFilterAnchorKey: PreferenceKey {
    static var defaultValue: [TrendFilterPopover: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TrendFilterPopover: Anchor<CGRect>],
        nextValue: () -> [TrendFilterPopover: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct TrendMetricDropdown: View {
    @Environment(\.appLanguage) private var language
    @Binding var selection: Set<TrendMetric>
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("展示类别")
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                    Text(language.format("已选择 %lld 项", Int64(selection.count)))
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Button {
                    if selection.count == TrendMetric.allCases.count {
                        selection = [.weight, .bmi, .bodyFat]
                    } else {
                        selection = Set(TrendMetric.allCases)
                    }
                } label: {
                    AppLocalizedText(selection.count == TrendMetric.allCases.count ? "常用" : "全选")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(AppColor.paleMint, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.ink)
                .accessibilityLabel("关闭展示类别列表")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Rectangle()
                .fill(AppColor.mint.opacity(0.09))
                .frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(TrendMetric.allCases) { metric in
                        Button {
                            toggle(metric)
                        } label: {
                            HStack(spacing: 12) {
                                trendMetricIcon(metric, size: 16)
                                    .foregroundStyle(metricTint(metric))
                                    .frame(width: 32, height: 32)
                                    .background(metricTint(metric).opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                                AppLocalizedText(metric.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColor.ink)
                                Spacer()
                                if selection.contains(metric) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .frame(width: 24, height: 24)
                                        .foregroundStyle(.white)
                                        .background(AppColor.mint, in: Circle())
                                } else {
                                    Circle()
                                        .stroke(AppColor.secondary.opacity(0.28), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(
                                selection.contains(metric) ? AppColor.paleMint.opacity(0.68) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.text(metric.title))
                        .accessibilityValue(language.text(selection.contains(metric) ? "已选择" : "未选择"))
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 344)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColor.mint.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: AppColor.ink.opacity(0.12), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func toggle(_ metric: TrendMetric) {
        if selection.contains(metric) {
            guard selection.count > 1 else { return }
            selection.remove(metric)
        } else {
            selection.insert(metric)
        }
    }
}

struct TrendTimeRangeDropdown: View {
    @Binding var selection: TrendTimeRange
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    let onDismiss: () -> Void

    @State private var editsCustomRange = false
    @State private var activeBoundary = CustomRangeBoundary.start

    var body: some View {
        VStack(spacing: 0) {
            dropdownHeader

            Rectangle()
                .fill(AppColor.mint.opacity(0.09))
                .frame(height: 1)

            if editsCustomRange {
                customRangeEditor
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                presetOptions
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColor.mint.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: AppColor.ink.opacity(0.12), radius: 22, y: 10)
    }

    private var dropdownHeader: some View {
        HStack {
            if editsCustomRange {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { editsCustomRange = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(AppColor.paleMint, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.ink)
                .accessibilityLabel("返回时间范围列表")
            }
            AppLocalizedText(editsCustomRange ? "自定义时间" : "时间范围")
                .font(.headline)
                .foregroundStyle(AppColor.ink)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .frame(width: 28, height: 28)
                    .background(AppColor.paleMint, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColor.ink)
            .accessibilityLabel("关闭时间范围列表")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var presetOptions: some View {
        VStack(spacing: 4) {
            ForEach(TrendTimeRange.allCases.filter { $0 != .custom }) { item in
                rangeOption(item)
            }
            Button {
                withAnimation(.easeOut(duration: 0.18)) { editsCustomRange = true }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .frame(width: 32, height: 32)
                        .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自定义范围")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColor.ink)
                        if selection == .custom {
                            Text(customRangeTitle)
                                .font(.caption2)
                                .foregroundStyle(AppColor.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: selection == .custom ? "checkmark" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(selection == .custom ? AppColor.mint : AppColor.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(
                    selection == .custom ? AppColor.paleMint.opacity(0.68) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }

    private func rangeOption(_ item: TrendTimeRange) -> some View {
        Button {
            selection = item
            onDismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 32, height: 32)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 9))
                AppLocalizedText(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                if selection == item {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .background(AppColor.mint, in: Circle())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(
                selection == item ? AppColor.paleMint.opacity(0.68) : Color.clear,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customRangeEditor: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                boundaryButton(.start, title: "开始", date: customStartDate)
                boundaryButton(.end, title: "结束", date: customEndDate)
            }

            if activeBoundary == .start {
                DatePicker(
                    "开始日期",
                    selection: $customStartDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .onChange(of: customStartDate) {
                    if customEndDate < customStartDate { customEndDate = customStartDate }
                }
            } else {
                DatePicker(
                    "结束日期",
                    selection: $customEndDate,
                    in: customStartDate ... Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }

            Button {
                selection = .custom
                onDismiss()
            } label: {
                Label("应用时间范围", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .tint(AppColor.mint)
    }

    private func boundaryButton(_ boundary: CustomRangeBoundary, title: String, date: Date) -> some View {
        let isActive = activeBoundary == boundary
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { activeBoundary = boundary }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                AppLocalizedText(title)
                    .font(.caption2)
                    .foregroundStyle(isActive ? AppColor.mint : AppColor.secondary)
                Text(date, format: .dateTime.year().month().day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(
                isActive ? AppColor.paleMint : AppColor.canvas,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isActive ? AppColor.mint.opacity(0.28) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var customRangeTitle: String {
        "\(customStartDate.formatted(.dateTime.month().day())) – \(customEndDate.formatted(.dateTime.month().day()))"
    }
}

private enum CustomRangeBoundary {
    case start
    case end
}

struct TrendDropdownOption<Value: Hashable>: Identifiable {
    let id: String
    let value: Value
    let title: String
    let subtitle: String?
    let icon: TrendDropdownIcon

    init(
        id: String,
        value: Value,
        title: String,
        subtitle: String? = nil,
        icon: TrendDropdownIcon
    ) {
        self.id = id
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
}

enum TrendDropdownIcon {
    case system(String)
    case asset(String)
    case avatar(MemberAvatar)
}

struct TrendDisplayDropdown: View {
    @Environment(\.appLanguage) private var language
    @Binding var scope: TrendDisplayScope
    @Binding var chartMode: TrendChartMode
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("图表显示")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(AppColor.paleMint, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.ink)
                .accessibilityLabel("关闭图表显示选项")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Rectangle()
                .fill(AppColor.mint.opacity(0.09))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("数据呈现")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 4)

                ForEach(TrendChartMode.allCases) { mode in
                    optionRow(
                        title: mode.title,
                        subtitle: mode.subtitle,
                        icon: mode.systemImage,
                        isSelected: chartMode == mode
                    ) {
                        chartMode = mode
                    }
                }

                Rectangle()
                    .fill(AppColor.mint.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, 3)

                Text("横轴范围")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 4)

                optionRow(
                    title: TrendDisplayScope.availableData.title,
                    subtitle: "横轴从首条数据延伸至末条数据",
                    icon: "chart.xyaxis.line",
                    isSelected: scope == .availableData
                ) {
                    scope = .availableData
                }
                optionRow(
                    title: TrendDisplayScope.selectedRange.title,
                    subtitle: "横轴覆盖所选区间，包括无数据时段",
                    icon: "arrow.left.and.right",
                    isSelected: scope == .selectedRange
                ) {
                    scope = .selectedRange
                }
            }
            .padding(8)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColor.mint.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: AppColor.ink.opacity(0.12), radius: 22, y: 10)
    }

    private func optionRow(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : AppColor.mint)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? AppColor.mint : AppColor.paleMint, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    AppLocalizedText(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.ink)
                    AppLocalizedText(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(AppColor.mint)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 50)
            .background(
                isSelected ? AppColor.paleMint.opacity(0.68) : Color.clear,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(language.text(isSelected ? "已选择" : "未选择"))
    }
}

struct TrendSingleChoiceDropdown<Value: Hashable>: View {
    @Environment(\.appLanguage) private var language
    let title: String
    let options: [TrendDropdownOption<Value>]
    @Binding var selection: Value
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppLocalizedText(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(AppColor.paleMint, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.ink)
                .accessibilityLabel(language.format("关闭%@列表", language.text(title)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Rectangle()
                .fill(AppColor.mint.opacity(0.09))
                .frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(options) { option in
                        Button {
                            selection = option.value
                            onDismiss()
                        } label: {
                            HStack(spacing: 12) {
                                dropdownIcon(option.icon)
                                    .foregroundStyle(AppColor.mint)
                                    .frame(width: 32, height: 32)
                                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 2) {
                                    AppLocalizedText(option.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppColor.ink)
                                    if let subtitle = option.subtitle {
                                        AppLocalizedText(subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(AppColor.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if selection == option.value {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .frame(width: 24, height: 24)
                                        .foregroundStyle(.white)
                                        .background(AppColor.mint, in: Circle())
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 46)
                            .background(
                                selection == option.value ? AppColor.paleMint.opacity(0.68) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(language.text(selection == option.value ? "已选择" : "未选择"))
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 344)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColor.mint.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: AppColor.ink.opacity(0.12), radius: 22, y: 10)
    }

    @ViewBuilder
    private func dropdownIcon(_ icon: TrendDropdownIcon) -> some View {
        switch icon {
        case let .system(name):
            Image(systemName: name)
                .font(.subheadline.weight(.semibold))
        case let .asset(name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(8.5)
        case let .avatar(avatar):
            MemberAvatarView(avatar: avatar, width: 28, height: 28, showsBackdrop: false)
        }
    }
}

private struct PlottedTrendPoint: Identifiable {
    let source: TrendPoint
    let x: Double

    var id: TrendPoint.ID { source.id }
}

private struct TrendAxisMarkValue: Identifiable {
    let x: Double
    let date: Date

    var id: Double { x }
}

private extension RandomAccessCollection {
    func firstPartitionIndex(where predicate: (Element) -> Bool) -> Index {
        var lower = startIndex
        var upper = endIndex
        while lower != upper {
            let middle = index(lower, offsetBy: distance(from: lower, to: upper) / 2)
            if predicate(self[middle]) {
                upper = middle
            } else {
                lower = index(after: middle)
            }
        }
        return lower
    }
}

private struct TrendChartPlot: View {
    @Environment(\.appLanguage) private var language
    let metric: TrendMetric
    let points: [TrendPoint]
    let unit: WeightUnit
    let range: TrendTimeRange
    let dateInterval: ClosedRange<Date>?
    let displayScope: TrendDisplayScope
    let chartMode: TrendChartMode
    let aggregation: TrendAggregation
    @Binding var selectedDate: Date?
    let isExpanded: Bool
    var allPoints: [TrendPoint]? = nil
    var onVisibleDateRangeChange: ((ClosedRange<Date>?) -> Void)? = nil

    @State private var zoomedXDomain: ClosedRange<Double>?
    @State private var magnificationStartDomain: ClosedRange<Double>?

    private let calendar = Calendar.current

    private var usesDateXValues: Bool {
        isExpanded || chartMode == .actual
    }

    private var selectedDateDomain: ClosedRange<Date>? {
        guard let first = points.first?.date, let last = points.last?.date else { return nil }
        if displayScope == .selectedRange {
            if let dateInterval { return dateInterval }
            if let start = range.startDate(endingAt: .now) { return start ... .now }
        }
        if first == last {
            let padding: TimeInterval = 12 * 60 * 60
            return first.addingTimeInterval(-padding) ... last.addingTimeInterval(padding)
        }
        return first ... last
    }

    private var axisSpanDays: Double {
        if let zoomedXDomain {
            let visibleRange = dateRange(for: zoomedXDomain)
            return visibleRange.upperBound.timeIntervalSince(visibleRange.lowerBound) / 86_400
        }
        guard let selectedDateDomain else { return 0 }
        return selectedDateDomain.upperBound.timeIntervalSince(selectedDateDomain.lowerBound) / 86_400
    }

    private var chartAggregation: TrendAggregation {
        guard isExpanded, chartMode == .period else { return aggregation }
        let spanDays = axisSpanDays
        if spanDays <= 45 { return .day }
        if spanDays <= 200 { return .week }
        return .month
    }

    private var periodOriginDate: Date {
        let candidate: Date
        if displayScope == .selectedRange, let selectedDateDomain {
            candidate = selectedDateDomain.lowerBound
        } else {
            candidate = points.first?.date ?? .now
        }
        return alignedDate(candidate)
    }

    private var plottedPoints: [PlottedTrendPoint] {
        if usesDateXValues {
            return chartPoints.map {
                PlottedTrendPoint(source: $0, x: $0.date.timeIntervalSinceReferenceDate)
            }
        }
        if chartAggregation == .measurement {
            return chartPoints.enumerated().map {
                PlottedTrendPoint(source: $0.element, x: Double($0.offset))
            }
        }
        return chartPoints.map {
            PlottedTrendPoint(source: $0, x: Double(periodOffset(from: periodOriginDate, to: $0.date)))
        }
    }

    private var chartPoints: [TrendPoint] {
        guard isExpanded, let allPoints else { return points }
        let lowerIndex = allPoints.firstPartitionIndex {
            $0.date.timeIntervalSinceReferenceDate >= xDomain.lowerBound
        }
        let upperIndex = allPoints.firstPartitionIndex {
            $0.date.timeIntervalSinceReferenceDate > xDomain.upperBound
        }
        let visiblePoints = Array(allPoints[lowerIndex ..< upperIndex])
        guard chartAggregation != .measurement else { return visiblePoints }

        let grouped = Dictionary(grouping: visiblePoints) {
            alignedDate($0.date)
        }
        return grouped.map { date, samples in
            let measurementCount = samples.map(\.measurementCount).reduce(0, +)
            let weightedValue = samples.reduce(0) {
                $0 + $1.value * Double($1.measurementCount)
            }
            let visibleStartDate = Date(timeIntervalSinceReferenceDate: xDomain.lowerBound)
            let plottedDate = max(date, visibleStartDate)
            return TrendPoint(
                id: plottedDate,
                date: plottedDate,
                value: weightedValue / Double(measurementCount),
                measurementCount: measurementCount
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var fullXDomain: ClosedRange<Double> {
        if isExpanded, let allPoints, let first = allPoints.first?.date, let last = allPoints.last?.date {
            let available = normalizedDomain(
                first.timeIntervalSinceReferenceDate,
                last.timeIntervalSinceReferenceDate
            )
            let initial = initialXDomain
            return min(available.lowerBound, initial.lowerBound) ... max(available.upperBound, initial.upperBound)
        }
        guard let first = plottedPoints.first?.x, let last = plottedPoints.last?.x else { return 0 ... 1 }
        if chartMode == .actual, let selectedDateDomain {
            let lower = selectedDateDomain.lowerBound.timeIntervalSinceReferenceDate
            let upper = selectedDateDomain.upperBound.timeIntervalSinceReferenceDate
            return normalizedDomain(lower, upper)
        }
        if chartMode == .period,
           displayScope == .selectedRange,
           let selectedDateDomain,
           aggregation != .measurement {
            let end = Double(periodOffset(from: periodOriginDate, to: alignedDate(selectedDateDomain.upperBound)))
            return normalizedDomain(0, max(end, last))
        }
        return normalizedDomain(first, last)
    }

    private var initialXDomain: ClosedRange<Double> {
        if isExpanded, let selectedDateDomain {
            return normalizedDomain(
                selectedDateDomain.lowerBound.timeIntervalSinceReferenceDate,
                selectedDateDomain.upperBound.timeIntervalSinceReferenceDate
            )
        }
        guard let first = points.first?.date, let last = points.last?.date else { return 0 ... 1 }
        return normalizedDomain(
            first.timeIntervalSinceReferenceDate,
            last.timeIntervalSinceReferenceDate
        )
    }

    private var xDomain: ClosedRange<Double> {
        zoomedXDomain ?? (isExpanded ? initialXDomain : fullXDomain)
    }

    private func selectedPoint(in plottedPoints: [PlottedTrendPoint]) -> PlottedTrendPoint? {
        guard let selectedDate else { return nil }
        return plottedPoints.min {
            abs($0.source.date.timeIntervalSince(selectedDate))
                < abs($1.source.date.timeIntervalSince(selectedDate))
        }
    }

    private var metricUnit: String {
        metric.unitLabel(weightUnit: unit)
    }

    private var verticalAxisUnit: String {
        switch metric {
        case .bmi: "kg/m²"
        case .visceralFat: "级"
        default: metricUnit
        }
    }

    private func yDomain(for points: [TrendPoint]) -> ClosedRange<Double> {
        guard let first = points.first else { return 0 ... 1 }
        var minimum = metric.displayValue(first.value, unit: unit)
        var maximum = minimum
        for point in points.dropFirst() {
            let value = metric.displayValue(point.value, unit: unit)
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        if minimum == maximum {
            let padding = max(abs(minimum) * 0.05, 1)
            return (minimum - padding) ... (maximum + padding)
        }
        let spread = maximum - minimum
        return (minimum - spread * 0.12) ... (maximum + spread * 0.34)
    }

    private var tint: Color {
        metricTint(metric)
    }

    var body: some View {
        if points.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(AppColor.secondary.opacity(0.72))
                Text(language.format("此范围暂无%@数据", language.text(metric.title)))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            GeometryReader { proxy in
                chart(availableWidth: proxy.size.width)
            }
        }
    }

    private func chart(availableWidth: CGFloat) -> some View {
        let sourcePoints = chartPoints
        let allPlottedPoints = plottedPoints(from: sourcePoints)
        let plottedPoints = downsampledPlottedPoints(
            allPlottedPoints,
            maximumCount: isExpanded ? max(160, Int(availableWidth * 0.75)) : .max
        )
        let xDomain = self.xDomain
        let yDomain = yDomain(for: sourcePoints)
        let selectedPoint = selectedPoint(in: plottedPoints)
        let labelPoints = visibleLabelPoints(
            in: plottedPoints,
            xDomain: xDomain,
            availableWidth: availableWidth
        )
        let labelPointIDs = Set(labelPoints.map(\.id))
        let showsEveryPointSymbol = plottedPoints.count <= max(120, Int(availableWidth / 3))
        let axisMarks = visibleAxisMarks(availableWidth: availableWidth, labelPoints: labelPoints)
        let selectedXBinding = selectedXBinding(for: plottedPoints)

        return Chart(plottedPoints) { point in
            AreaMark(
                x: .value("横轴位置", point.x),
                yStart: .value("图表下界", yDomain.lowerBound),
                yEnd: .value(metric.title, metric.displayValue(point.source.value, unit: unit))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.24), tint.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("横轴位置", point.x),
                y: .value(metric.title, metric.displayValue(point.source.value, unit: unit))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(tint)
            .lineStyle(.init(lineWidth: isExpanded ? 3 : 2.5, lineCap: .round, lineJoin: .round))

            if showsEveryPointSymbol || labelPointIDs.contains(point.id) || selectedPoint?.id == point.id {
                PointMark(
                    x: .value("横轴位置", point.x),
                    y: .value(metric.title, metric.displayValue(point.source.value, unit: unit))
                )
                .foregroundStyle(tint)
                .symbolSize(selectedPoint?.id == point.id ? 72 : 24)
                .annotation(position: .top, spacing: 3, overflowResolution: .init(x: .fit, y: .fit)) {
                    if labelPointIDs.contains(point.id), selectedPoint?.id != point.id {
                        Text(formattedNumericValue(point.source.value))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColor.secondary)
                            .monospacedDigit()
                    }
                }
            }

            if selectedPoint?.id == point.id {
                RuleMark(x: .value("选中位置", point.x))
                    .foregroundStyle(AppColor.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedValue(point.source.value))
                                .font(.caption.bold())
                            Text(selectedDateText(point.source.date))
                                .font(.caption2)
                            if point.source.measurementCount > 1 {
                                Text(
                                    language.format(
                                        "%lld 次测量均值",
                                        point.source.measurementCount
                                    )
                                )
                                    .font(.caption2)
                                    .foregroundStyle(AppColor.secondary)
                            }
                        }
                        .padding(8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 7))
                    }
            }
        }
        .chartXSelection(value: selectedXBinding)
        .chartXScale(
            domain: xDomain,
            range: .plotDimension(padding: isExpanded ? 30 : 26)
        )
        .chartYScale(domain: yDomain)
        .chartYAxisLabel(position: .topTrailing, alignment: .trailing, spacing: 6) {
            if isExpanded {
                Text(verticalAxisUnit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.secondary)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: axisMarks.map(\.x)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(AppColor.secondary.opacity(0.18))
                AxisValueLabel(
                    centered: false,
                    anchor: .top,
                    multiLabelAlignment: .center,
                    collisionResolution: .disabled
                ) {
                    if let x = value.as(Double.self), let mark = nearestAxisMark(to: x, in: axisMarks) {
                        axisDateLabel(mark.date)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) {
                AxisGridLine().foregroundStyle(AppColor.secondary.opacity(0.12))
                AxisValueLabel(
                    format: FloatingPointFormatStyle<Double>.number.precision(
                        .fractionLength(metric.displayFractionDigits)
                    )
                )
            }
        }
        .background {
            if isExpanded {
                TrendPinchGestureBridge { state, magnification, anchor in
                    handlePinch(state: state, magnification: magnification, anchor: anchor)
                }
            }
        }
    }

    private func handlePinch(
        state: UIGestureRecognizer.State,
        magnification: Double,
        anchor: Double
    ) {
        switch state {
        case .began:
            magnificationStartDomain = xDomain
        case .changed:
            guard let startDomain = magnificationStartDomain else { return }
            updateZoom(from: startDomain, magnification: magnification, anchor: anchor)
        case .ended:
            guard let startDomain = magnificationStartDomain else { return }
            let finalDomain = updateZoom(
                from: startDomain,
                magnification: magnification,
                anchor: anchor
            )
            magnificationStartDomain = nil
            if let finalDomain {
                onVisibleDateRangeChange?(dateRange(for: finalDomain))
            }
        case .cancelled, .failed:
            magnificationStartDomain = nil
        default:
            break
        }
    }

    @discardableResult
    private func updateZoom(
        from startDomain: ClosedRange<Double>,
        magnification: Double,
        anchor: Double
    ) -> ClosedRange<Double>? {
        let fullSpan = fullXDomain.upperBound - fullXDomain.lowerBound
        guard fullSpan > 0 else { return nil }

        let startSpan = startDomain.upperBound - startDomain.lowerBound
        let minimumSpan = minimumZoomSpan(fullSpan: fullSpan)
        let targetSpan = min(fullSpan, max(minimumSpan, startSpan / max(magnification, 0.01)))
        let clampedAnchor = min(max(anchor, 0), 1)
        let anchorX = startDomain.lowerBound + startSpan * clampedAnchor
        var lower = anchorX - targetSpan * clampedAnchor
        var upper = lower + targetSpan

        if lower < fullXDomain.lowerBound {
            lower = fullXDomain.lowerBound
            upper = lower + targetSpan
        }
        if upper > fullXDomain.upperBound {
            upper = fullXDomain.upperBound
            lower = upper - targetSpan
        }

        let domain = lower ... upper
        zoomedXDomain = domain
        if selectedDate != nil {
            selectedDate = nil
        }
        return domain
    }

    private func minimumZoomSpan(fullSpan: Double) -> Double {
        if chartMode == .period {
            return min(fullSpan, max(86_400, fullSpan / 1_000))
        }
        return min(fullSpan, max(3_600, fullSpan / 1_000))
    }

    private func dateRange(for domain: ClosedRange<Double>) -> ClosedRange<Date> {
        let lower = date(forX: domain.lowerBound)
        let upper = date(forX: domain.upperBound)
        return min(lower, upper) ... max(lower, upper)
    }

    private func date(forX x: Double) -> Date {
        if usesDateXValues {
            return Date(timeIntervalSinceReferenceDate: x)
        }

        if aggregation == .measurement {
            let boundedX = min(max(x, 0), Double(max(plottedPoints.count - 1, 0)))
            let lowerIndex = Int(boundedX.rounded(.down))
            let upperIndex = min(lowerIndex + 1, plottedPoints.count - 1)
            let lowerDate = plottedPoints[lowerIndex].source.date
            let upperDate = plottedPoints[upperIndex].source.date
            let progress = boundedX - Double(lowerIndex)
            return lowerDate.addingTimeInterval(upperDate.timeIntervalSince(lowerDate) * progress)
        }

        let lowerOffset = Int(x.rounded(.down))
        let upperOffset = lowerOffset + 1
        let lowerDate = periodDate(from: periodOriginDate, offset: lowerOffset)
        let upperDate = periodDate(from: periodOriginDate, offset: upperOffset)
        return lowerDate.addingTimeInterval(
            upperDate.timeIntervalSince(lowerDate) * (x - Double(lowerOffset))
        )
    }

    private func selectedXBinding(for plottedPoints: [PlottedTrendPoint]) -> Binding<Double?> {
        Binding(
            get: { selectedPoint(in: plottedPoints)?.x },
            set: { x in
                guard let x else {
                    selectedDate = nil
                    return
                }
                selectedDate = plottedPoints.min { abs($0.x - x) < abs($1.x - x) }?.source.date
            }
        )
    }

    private func plottedPoints(from chartPoints: [TrendPoint]) -> [PlottedTrendPoint] {
        if usesDateXValues {
            return chartPoints.map {
                PlottedTrendPoint(source: $0, x: $0.date.timeIntervalSinceReferenceDate)
            }
        }
        if chartAggregation == .measurement {
            return chartPoints.enumerated().map {
                PlottedTrendPoint(source: $0.element, x: Double($0.offset))
            }
        }
        return chartPoints.map {
            PlottedTrendPoint(source: $0, x: Double(periodOffset(from: periodOriginDate, to: $0.date)))
        }
    }

    private func downsampledPlottedPoints(
        _ points: [PlottedTrendPoint],
        maximumCount: Int
    ) -> [PlottedTrendPoint] {
        guard maximumCount >= 4, points.count > maximumCount else { return points }

        let interior = points.dropFirst().dropLast()
        let bucketCount = max(1, (maximumCount - 2) / 2)
        let bucketSize = max(1, Int(ceil(Double(interior.count) / Double(bucketCount))))
        var sampled = [PlottedTrendPoint]()
        sampled.reserveCapacity(maximumCount)
        sampled.append(points[0])

        var bucketStart = interior.startIndex
        while bucketStart < interior.endIndex {
            let bucketEnd = min(bucketStart + bucketSize, interior.endIndex)
            let bucket = interior[bucketStart ..< bucketEnd]
            guard let minimum = bucket.min(by: { $0.source.value < $1.source.value }),
                  let maximum = bucket.max(by: { $0.source.value < $1.source.value }) else {
                bucketStart = bucketEnd
                continue
            }
            if minimum.x <= maximum.x {
                sampled.append(minimum)
                if maximum.id != minimum.id { sampled.append(maximum) }
            } else {
                sampled.append(maximum)
                if maximum.id != minimum.id { sampled.append(minimum) }
            }
            bucketStart = bucketEnd
        }

        sampled.append(points[points.count - 1])
        return sampled
    }

    private func visibleLabelPoints(
        in plottedPoints: [PlottedTrendPoint],
        xDomain: ClosedRange<Double>,
        availableWidth: CGFloat
    ) -> [PlottedTrendPoint] {
        let usableWidth = max(availableWidth - 54, 1)
        let minimumSpacing: CGFloat = isExpanded ? 64 : 60
        let span = max(xDomain.upperBound - xDomain.lowerBound, 1)
        var selected: [PlottedTrendPoint] = []
        var lastPixel: CGFloat?

        for point in plottedPoints.filter({ xDomain.contains($0.x) }).reversed() {
            let progress = (point.x - xDomain.lowerBound) / span
            let pixel = CGFloat(progress) * usableWidth
            if lastPixel.map({ $0 - pixel >= minimumSpacing }) ?? true {
                selected.append(point)
                lastPixel = pixel
            }
        }
        return selected.reversed()
    }

    private func visibleAxisMarks(
        availableWidth: CGFloat,
        labelPoints: [PlottedTrendPoint]
    ) -> [TrendAxisMarkValue] {
        if usesDateXValues {
            guard labelPoints.isEmpty else {
                return labelPoints.map { TrendAxisMarkValue(x: $0.x, date: $0.source.date) }
            }
            return [
                TrendAxisMarkValue(x: xDomain.lowerBound, date: date(forX: xDomain.lowerBound)),
                TrendAxisMarkValue(x: xDomain.upperBound, date: date(forX: xDomain.upperBound))
            ]
        }
        if chartAggregation == .measurement {
            return labelPoints.map { TrendAxisMarkValue(x: $0.x, date: $0.source.date) }
        }

        let maximumCount = max(2, Int(max(availableWidth - 54, 1) / 60))
        let firstOffset = Int(xDomain.lowerBound.rounded(.up))
        let lastOffset = Int(xDomain.upperBound.rounded(.down))
        guard lastOffset > firstOffset else {
            let offset = Int(((xDomain.lowerBound + xDomain.upperBound) / 2).rounded())
            return [TrendAxisMarkValue(x: Double(offset), date: periodDate(from: periodOriginDate, offset: offset))]
        }
        let count = min(maximumCount, lastOffset - firstOffset + 1)
        let offsets = (0 ..< count).map { position in
            firstOffset + Int(
                (Double(position) * Double(lastOffset - firstOffset) / Double(count - 1)).rounded()
            )
        }
        return offsets.map { offset in
            TrendAxisMarkValue(x: Double(offset), date: periodDate(from: periodOriginDate, offset: offset))
        }
    }

    private func nearestAxisMark(to x: Double, in marks: [TrendAxisMarkValue]) -> TrendAxisMarkValue? {
        marks.min { abs($0.x - x) < abs($1.x - x) }
    }

    @ViewBuilder
    private func axisDateLabel(_ date: Date) -> some View {
        VStack(spacing: 0) {
            if chartMode == .actual, axisSpanDays <= 2 {
                Text(Self.axisTimeFormatter.string(from: date))
                Text(Self.axisMonthDayFormatter.string(from: date))
                    .foregroundStyle(AppColor.secondary.opacity(0.72))
            } else if axisSpanDays <= 370 {
                Text(Self.axisMonthDayFormatter.string(from: date))
                Text(Self.axisYearFormatter.string(from: date))
                    .foregroundStyle(AppColor.secondary.opacity(0.72))
            } else {
                Text(Self.axisYearFormatter.string(from: date))
                Text(Self.axisMonthFormatter.string(from: date))
                    .foregroundStyle(AppColor.secondary.opacity(0.72))
            }
        }
        .font(.caption2)
        .multilineTextAlignment(.center)
    }

    private static let axisTimeFormatter = axisFormatter("HH:mm")
    private static let axisMonthDayFormatter = axisFormatter("MM/dd")
    private static let axisYearFormatter = axisFormatter("yyyy")
    private static let axisMonthFormatter = axisFormatter("MM")

    private static func axisFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    private func alignedDate(_ date: Date) -> Date {
        switch chartAggregation {
        case .measurement: date
        case .day: calendar.startOfDay(for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month: calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }

    private func periodOffset(from start: Date, to end: Date) -> Int {
        switch chartAggregation {
        case .measurement:
            return 0
        case .day:
            return calendar.dateComponents([.day], from: start, to: alignedDate(end)).day ?? 0
        case .week:
            let days = calendar.dateComponents([.day], from: start, to: alignedDate(end)).day ?? 0
            return days / 7
        case .month:
            return calendar.dateComponents([.month], from: start, to: alignedDate(end)).month ?? 0
        }
    }

    private func periodDate(from start: Date, offset: Int) -> Date {
        switch chartAggregation {
        case .measurement: start
        case .day: calendar.date(byAdding: .day, value: offset, to: start) ?? start
        case .week: calendar.date(byAdding: .weekOfYear, value: offset, to: start) ?? start
        case .month: calendar.date(byAdding: .month, value: offset, to: start) ?? start
        }
    }

    private func normalizedDomain(_ lower: Double, _ upper: Double) -> ClosedRange<Double> {
        guard lower != upper else { return (lower - 0.5) ... (upper + 0.5) }
        return min(lower, upper) ... max(lower, upper)
    }

    private func selectedDateText(_ date: Date) -> String {
        if chartMode == .actual {
            return date.formatted(.dateTime.year().month().day().hour().minute())
        }
        return date.formatted(.dateTime.year().month().day())
    }

    private func formattedValue(_ value: Double) -> String {
        let suffix = metricUnit.isEmpty ? "" : " \(metricUnit)"
        return "\(formattedNumericValue(value))\(suffix)"
    }

    private func formattedNumericValue(_ value: Double) -> String {
        metric.displayValue(value, unit: unit).formatted(metric.displayFractionDigits)
    }
}

private struct TrendPinchGestureBridge: UIViewRepresentable {
    let onPinch: (UIGestureRecognizer.State, Double, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinch: onPinch)
    }

    func makeUIView(context: Context) -> UIView {
        let view = WindowTrackingView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.onWindowChange = { [weak view, weak coordinator = context.coordinator] window in
            coordinator?.install(on: window, tracking: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPinch = onPinch
        context.coordinator.install(on: uiView.window, tracking: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        (uiView as? WindowTrackingView)?.onWindowChange = nil
        coordinator.uninstall()
    }

    final class WindowTrackingView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPinch: (UIGestureRecognizer.State, Double, Double) -> Void

        private weak var window: UIWindow?
        private weak var trackedView: UIView?
        private lazy var recognizer: UIPinchGestureRecognizer = {
            let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        init(onPinch: @escaping (UIGestureRecognizer.State, Double, Double) -> Void) {
            self.onPinch = onPinch
        }

        func install(on window: UIWindow?, tracking trackedView: UIView?) {
            guard let window else {
                uninstall()
                return
            }
            guard self.window !== window else {
                self.trackedView = trackedView
                return
            }
            uninstall()
            self.window = window
            self.trackedView = trackedView
            window.addGestureRecognizer(recognizer)
        }

        func uninstall() {
            window?.removeGestureRecognizer(recognizer)
            window = nil
            trackedView = nil
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let trackedView else { return }
            let width = max(trackedView.bounds.width, 1)
            let anchor = min(max(recognizer.location(in: trackedView).x / width, 0), 1)
            onPinch(recognizer.state, Double(recognizer.scale), Double(anchor))
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let trackedView else { return false }
            return (0 ..< gestureRecognizer.numberOfTouches).allSatisfy { index in
                trackedView.bounds.contains(gestureRecognizer.location(ofTouch: index, in: trackedView))
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private func metricTint(_ metric: TrendMetric) -> Color {
    switch metric {
    case .weight: AppColor.trendWeight
    case .bmi: AppColor.trendBMI
    case .bodyFat: AppColor.trendBodyFat
    case .fatMass: AppColor.trendFatMass
    case .muscleMass: AppColor.trendMuscleMass
    case .musclePercent: AppColor.trendMusclePercent
    case .waterPercent: AppColor.trendWaterPercent
    case .waterMass: AppColor.trendWaterMass
    case .proteinPercent: AppColor.trendProteinPercent
    case .proteinMass: AppColor.trendProteinMass
    case .boneMass: AppColor.trendBoneMass
    case .bonePercent: AppColor.trendBonePercent
    case .visceralFat: AppColor.trendVisceralFat
    case .basalMetabolism: AppColor.trendBasalMetabolism
    }
}

@ViewBuilder
private func trendMetricIcon(_ metric: TrendMetric, size: CGFloat) -> some View {
    if metric == .bodyFat {
        BodyFatRateIcon(size: size)
    } else if metric == .visceralFat {
        VisceralFatIcon(size: size)
    } else {
        Image(systemName: metric.systemImage)
            .font(.system(size: size, weight: .semibold))
    }
}
