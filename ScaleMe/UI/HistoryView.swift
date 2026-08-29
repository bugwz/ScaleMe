import SwiftUI

private enum TrendFilterIcon {
    case system(String)
    case asset(String)
}

struct HistoryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var selectedMetrics: Set<TrendMetric> = [.weight, .bmi, .bodyFat]
    @State private var range = TrendTimeRange.week
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -6, to: Date.now) ?? .now
    @State private var customEndDate = Date.now
    @State private var displayScope = TrendDisplayScope.availableData
    @State private var chartMode = TrendChartMode.period
    @State private var selectedDeviceID: UUID?
    @State private var selectedTrendProfileID: UUID?
    @State private var activeFilterPopover: TrendFilterPopover?
    @State private var expandedTrend: ExpandedTrendContext?

    private var trendProfile: UserProfile {
        guard let selectedTrendProfileID,
              let profile = store.profiles.first(where: { $0.id == selectedTrendProfileID }) else {
            return store.selectedProfile
        }
        return profile
    }

    private var profileMeasurements: [BodyMeasurement] {
        if trendProfile.id == store.selectedProfileID {
            return store.displayMeasurements
        }
        return store.measurements.filter { $0.profileID == trendProfile.id }
    }

    private var deviceMeasurements: [BodyMeasurement] {
        var result = profileMeasurements
        if let selectedDeviceID {
            result = result.filter { $0.deviceID == selectedDeviceID }
        }
        return result
    }

    private var rangeMeasurements: [BodyMeasurement] {
        TrendAnalysis.measurements(
            from: deviceMeasurements,
            metric: .weight,
            profile: trendProfile,
            range: range,
            dateInterval: selectedDateInterval
        )
        .sorted { $0.date > $1.date }
    }

    private var selectedDateInterval: ClosedRange<Date>? {
        let now = Date.now
        if range == .all { return nil }
        if range == .custom {
            let calendar = Calendar.current
            let firstDay = min(customStartDate, customEndDate)
            let lastDay = max(customStartDate, customEndDate)
            let start = calendar.startOfDay(for: firstDay)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay)) ?? lastDay
            return start ... nextDay.addingTimeInterval(-1)
        }
        guard let start = range.startDate(endingAt: now) else { return nil }
        return start ... now
    }

    private var selectedRangeTitle: String {
        guard range == .custom, let selectedDateInterval else { return range.title }
        let start = selectedDateInterval.lowerBound.formatted(.dateTime.year().month().day())
        let end = selectedDateInterval.upperBound.formatted(.dateTime.year().month().day())
        return "\(start) – \(end)"
    }

    private var orderedMetrics: [TrendMetric] {
        TrendMetric.allCases.filter { selectedMetrics.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MainPageTitle(text: "趋势")
                    filters
                    ForEach(orderedMetrics) { metric in
                        TrendChartCard(
                            metric: metric,
                            measurements: deviceMeasurements,
                            profile: trendProfile,
                            unit: store.unit,
                            range: range,
                            dateInterval: selectedDateInterval,
                            displayScope: displayScope,
                            chartMode: chartMode,
                            onExpand: presentExpandedTrend
                        )
                    }
                    if orderedMetrics.contains(where: \.isEstimatedComposition) {
                        Text("身体成分指标为消费级估算值，仅用于长期趋势参考，不构成医疗诊断。")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .padding(.horizontal, 4)
                    }
                    records
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: store.selectedProfileID) {
                selectedDeviceID = nil
            }
            .onChange(of: store.profiles) {
                if let profileID = selectedTrendProfileID,
                   !store.profiles.contains(where: { $0.id == profileID }) {
                    selectedTrendProfileID = nil
                }
            }
            .fullScreenCover(item: $expandedTrend) { context in
                ExpandedTrendChartView(
                    context: context,
                    unit: store.unit,
                    range: range,
                    rangeTitle: selectedRangeTitle,
                    dateInterval: selectedDateInterval,
                    displayScope: displayScope
                )
            }
        }
        .overlayPreferenceValue(TrendFilterAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let activeFilterPopover,
                   let anchor = anchors[activeFilterPopover] {
                    let buttonFrame = proxy[anchor]
                    let preferredWidth: CGFloat = activeFilterPopover == .timeRange ? 340 : 300
                    let dropdownWidth = min(preferredWidth, proxy.size.width - 36)
                    let dropdownX = min(
                        max(buttonFrame.minX, 18),
                        proxy.size.width - dropdownWidth - 18
                    )

                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissFilterPopover()
                            }

                        activeFilterDropdown
                            .frame(width: dropdownWidth)
                            .offset(x: dropdownX, y: buttonFrame.maxY + 8)
                            .transition(.scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            filterButton(
                popover: .metrics,
                title: "类别",
                value: "已选 \(selectedMetrics.count) 项",
                icon: .system("checklist")
            )
            filterButton(
                popover: .timeRange,
                title: "时间",
                value: selectedRangeTitle,
                icon: .system("calendar")
            )
            filterButton(
                popover: .source,
                title: "设备",
                value: selectedSourceTitle,
                icon: .asset("ScaleDeviceTabIcon")
            )
            filterButton(
                popover: .profile,
                title: "用户",
                value: trendProfile.name,
                icon: .system("person.crop.circle")
            )
            filterButton(
                popover: .displayScope,
                title: "显示",
                value: "\(chartMode.title)，\(displayScope.title)",
                icon: .system("eye")
            )
        }
        .padding(6)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColor.mint.opacity(0.08))
        )
    }

    private func filterButton(
        popover: TrendFilterPopover,
        title: String,
        value: String,
        icon: TrendFilterIcon
    ) -> some View {
        let isActive = activeFilterPopover == popover
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                activeFilterPopover = isActive ? nil : popover
            }
        } label: {
            VStack(spacing: 3) {
                filterIcon(icon)
                    .frame(width: 24, height: 21)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isActive ? .white : AppColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isActive ? AppColor.mint : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: TrendFilterAnchorKey.self, value: .bounds) { [popover: $0] }
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .help("\(title)：\(value)")
    }

    @ViewBuilder
    private func filterIcon(_ icon: TrendFilterIcon) -> some View {
        switch icon {
        case let .system(name):
            Image(systemName: name)
                .font(.body.weight(.semibold))
        case let .asset(name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(2)
        }
    }

    @ViewBuilder
    private var activeFilterDropdown: some View {
        switch activeFilterPopover {
        case .metrics:
            TrendMetricDropdown(selection: $selectedMetrics, onDismiss: dismissFilterPopover)
        case .timeRange:
            TrendTimeRangeDropdown(
                selection: $range,
                customStartDate: $customStartDate,
                customEndDate: $customEndDate,
                onDismiss: dismissFilterPopover
            )
        case .source:
            TrendSingleChoiceDropdown(
                title: "来源设备",
                options: sourceOptions,
                selection: $selectedDeviceID,
                onDismiss: dismissFilterPopover
            )
        case .profile:
            TrendSingleChoiceDropdown(
                title: "选择用户",
                options: profileOptions,
                selection: trendProfileSelection,
                onDismiss: dismissFilterPopover
            )
        case .displayScope:
            TrendDisplayDropdown(
                scope: $displayScope,
                chartMode: $chartMode,
                onDismiss: dismissFilterPopover
            )
        case nil:
            EmptyView()
        }
    }

    private var sourceOptions: [TrendDropdownOption<UUID?>] {
        let allDevices = TrendDropdownOption<UUID?>(
            id: "all",
            value: nil,
            title: "全部设备",
            icon: .asset("ScaleDeviceTabIcon")
        )
        return [allDevices] + store.pairedScales.map { scale in
            TrendDropdownOption(
                id: scale.id.uuidString,
                value: Optional(scale.id),
                title: scale.name,
                subtitle: scale.modelName,
                icon: .asset("ScaleDeviceTabIcon")
            )
        }
    }

    private var profileOptions: [TrendDropdownOption<UUID>] {
        store.profiles.map { profile in
            TrendDropdownOption(
                id: profile.id.uuidString,
                value: profile.id,
                title: profile.name,
                subtitle: profile.relation,
                icon: .system("person.crop.circle")
            )
        }
    }

    private var trendProfileSelection: Binding<UUID> {
        Binding(
            get: { trendProfile.id },
            set: {
                selectedTrendProfileID = $0
                selectedDeviceID = nil
            }
        )
    }

    private var selectedSourceTitle: String {
        guard let selectedDeviceID else { return "全部设备" }
        return store.pairedScales.first(where: { $0.id == selectedDeviceID })?.name ?? "所选设备"
    }

    private func dismissFilterPopover() {
        withAnimation(.easeOut(duration: 0.16)) {
            activeFilterPopover = nil
        }
    }

    private func presentExpandedTrend(_ context: ExpandedTrendContext) {
        guard expandedTrend == nil else { return }
        activeFilterPopover = nil
        AppOrientation.request(.landscape)
        Task { @MainActor in
            await Task.yield()
            expandedTrend = context
        }
    }

    private var records: some View {
        let previewMeasurements = Array(rangeMeasurements.prefix(5))
        return SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("测量记录")
                        .font(.headline)
                    Spacer()
                    NavigationLink {
                        FilteredMeasurementRecordsView(
                            range: range,
                            rangeTitle: selectedRangeTitle,
                            dateInterval: selectedDateInterval,
                            selectedDeviceID: selectedDeviceID,
                            selectedProfileID: trendProfile.id,
                            sourceTitle: selectedSourceTitle
                        )
                    } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.caption.weight(.semibold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.secondary)
                    .accessibilityLabel("查看全部测量记录")
                }
                .padding(.bottom, 8)
                if rangeMeasurements.isEmpty {
                    Text("当前筛选条件下没有记录")
                        .font(.subheadline).foregroundStyle(AppColor.secondary).padding(.vertical, 18)
                }
                ForEach(Array(previewMeasurements.enumerated()), id: \.element.id) { index, item in
                    MeasurementRecordLink(measurement: item, sourceName: sourceName(for: item))
                    if index < previewMeasurements.count - 1 { Divider() }
                }
            }
        }
    }

    private func sourceName(for measurement: BodyMeasurement) -> String {
        if let deviceID = measurement.deviceID,
           let scale = store.pairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? measurement.source.rawValue
    }
}

private struct MeasurementRecordLink: View {
    @EnvironmentObject private var store: MeasurementStore

    let measurement: BodyMeasurement
    let sourceName: String

    var body: some View {
        NavigationLink { MeasurementDetailView(measurement: measurement) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.unit.value(fromKilograms: measurement.weightKG).formatted(2)) \(store.unit.rawValue)")
                        .font(.body.bold())
                        .foregroundStyle(AppColor.ink)
                    ScaleDeviceLabel(title: sourceName, iconSize: 13)
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(measurement.date, format: .dateTime.month().day())
                        .foregroundStyle(AppColor.ink)
                    Text(measurement.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 13)
        }
    }
}

private struct FilteredMeasurementRecordsView: View {
    @EnvironmentObject private var store: MeasurementStore

    let range: TrendTimeRange
    let rangeTitle: String
    let dateInterval: ClosedRange<Date>?
    let selectedDeviceID: UUID?
    let selectedProfileID: UUID
    let sourceTitle: String

    private var profile: UserProfile {
        store.profiles.first(where: { $0.id == selectedProfileID }) ?? store.selectedProfile
    }

    private var measurements: [BodyMeasurement] {
        let profileMeasurements: [BodyMeasurement]
        if selectedProfileID == store.selectedProfileID {
            profileMeasurements = store.displayMeasurements
        } else {
            profileMeasurements = store.measurements.filter { $0.profileID == selectedProfileID }
        }
        let deviceMeasurements = profileMeasurements.filter { measurement in
            guard let selectedDeviceID else { return true }
            return measurement.deviceID == selectedDeviceID
        }
        return TrendAnalysis.measurements(
            from: deviceMeasurements,
            metric: .weight,
            profile: profile,
            range: range,
            dateInterval: dateInterval
        )
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        Label(rangeTitle, systemImage: "calendar")
                            .fixedSize(horizontal: true, vertical: false)
                        ScaleDeviceLabel(title: sourceTitle, iconSize: 13)
                            .fixedSize(horizontal: true, vertical: false)
                        Label(profile.name, systemImage: "person.crop.circle")
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                SoftCard {
                    VStack(alignment: .leading, spacing: 0) {
                        if measurements.isEmpty {
                            Text("当前筛选条件下没有记录")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.secondary)
                                .padding(.vertical, 18)
                        }
                        ForEach(Array(measurements.enumerated()), id: \.element.id) { index, item in
                            MeasurementRecordLink(measurement: item, sourceName: sourceName(for: item))
                            if index < measurements.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(18)
        }
        .pageBackground()
        .navigationTitle("全部测量记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceName(for measurement: BodyMeasurement) -> String {
        if let deviceID = measurement.deviceID,
           let scale = store.pairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? measurement.source.rawValue
    }
}

struct MeasurementDetailView: View {
    @EnvironmentObject private var store: MeasurementStore
    let measurement: BodyMeasurement

    private var profile: UserProfile {
        store.profiles.first(where: { $0.id == measurement.profileID }) ?? store.selectedProfile
    }

    private var sourceName: String {
        if let deviceID = measurement.deviceID,
           let scale = store.pairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? measurement.source.rawValue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(measurement.date, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline).foregroundStyle(AppColor.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.unit.value(fromKilograms: measurement.weightKG).formatted(2))
                            .font(.system(size: 58, weight: .medium, design: .rounded))
                        Text(store.unit.rawValue).font(.headline)
                    }
                    ScaleDeviceLabel(title: sourceName, iconSize: 13)
                        .font(.caption).foregroundStyle(AppColor.secondary)
                    StatusPill(text: profile.name)
                }
                .padding(.vertical, 28)
                metricCard(title: "基础指标", metrics: basicMetrics)
                if measurement.hasBodyComposition {
                    metricCard(title: "身体成分估算", metrics: compositionMetrics)
                    Text("体脂及相关指标是基于生物电阻抗和个人资料的消费级估算值，仅用于日常趋势参考，不构成医疗诊断。")
                        .font(.caption).foregroundStyle(AppColor.secondary).padding(.horizontal)
                }
                if !rawMetrics.isEmpty {
                    metricCard(title: "设备原始数据", metrics: rawMetrics)
                    Text("阻抗通道名称和频率尚未获得厂商定义，因此仅保留原始读数，不据此声称具体频率。")
                        .font(.caption).foregroundStyle(AppColor.secondary).padding(.horizontal)
                }
            }
            .padding(18)
        }
        .pageBackground()
        .navigationTitle("测量详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var basicMetrics: [(String, String)] {
        [("BMI", measurement.bmi(heightCM: profile.heightCM).formatted(2))]
    }

    private var compositionMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        append(measurement.bodyFatPercent, name: "体脂率", suffix: "%", to: &metrics)
        append(measurement.fatMassKG, name: "脂肪量", suffix: " kg", to: &metrics)
        append(measurement.musclePercent, name: "肌肉率", suffix: "%", to: &metrics)
        append(measurement.muscleMassKG, name: "肌肉量", suffix: " kg", to: &metrics)
        append(measurement.waterPercent, name: "身体水分", suffix: "%", to: &metrics)
        append(measurement.waterMassKG, name: "水分量", suffix: " kg", to: &metrics)
        append(measurement.proteinPercent, name: "蛋白质占比", suffix: "%", to: &metrics)
        append(measurement.proteinMassKG, name: "蛋白质量", suffix: " kg", to: &metrics)
        append(measurement.bonePercent, name: "骨量占比", suffix: "%", to: &metrics)
        append(measurement.boneMassKG, name: "骨量", suffix: " kg", to: &metrics)
        append(measurement.visceralFat, name: "内脏脂肪", suffix: "", to: &metrics)
        if let value = measurement.basalMetabolismKCal {
            metrics.append(("基础代谢", "\(value.formatted(2)) kcal"))
        }
        return metrics
    }

    private var rawMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        if let value = measurement.impedanceOhm {
            metrics.append(("阻抗通道 1", "\(value.formatted(2)) Ω"))
        }
        if let value = measurement.secondaryImpedanceOhm {
            metrics.append(("阻抗通道 2", "\(value.formatted(2)) Ω"))
        }
        return metrics
    }

    private func append(
        _ value: Double?,
        name: String,
        suffix: String,
        to metrics: inout [(String, String)]
    ) {
        guard let value else { return }
        metrics.append((name, "\(value.formatted(2))\(suffix)"))
    }

    private func metricCard(title: String, metrics: [(String, String)]) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline).padding(.bottom, 4)
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    DetailRow(name: metric.0, value: metric.1, divider: index < metrics.count - 1)
                }
            }
        }
    }
}

private struct DetailRow: View {
    let name: String, value: String
    var divider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(name).foregroundStyle(AppColor.secondary)
                Spacer()
                Text(value).fontWeight(.semibold)
            }
            .padding(.vertical, 15)
            if divider { Divider() }
        }
    }
}
