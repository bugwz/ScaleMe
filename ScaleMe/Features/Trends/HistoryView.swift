import SwiftUI

private enum TrendFilterIcon {
    case system(String)
    case asset(String)
}

struct HistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: MeasurementStore
    @Binding var expandedTrend: ExpandedTrendPresentation?
    let scrollToTopRequest: Int
    @State private var selectedMetrics: Set<TrendMetric> = [.weight, .bmi, .bodyFat]
    @State private var range = TrendTimeRange.week
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -6, to: Date.now) ?? .now
    @State private var customEndDate = Date.now
    @State private var displayScope = TrendDisplayScope.availableData
    @State private var chartMode = TrendChartMode.period
    @State private var selectedDeviceID: UUID?
    @State private var selectedTrendProfileID: UUID?
    @State private var activeFilterPopover: TrendFilterPopover?

    private var trendProfile: UserProfile {
        guard let selectedTrendProfileID,
              let profile = store.displayProfiles.first(where: { $0.id == selectedTrendProfileID }) else {
            return store.displaySelectedProfile
        }
        return profile
    }

    private var profileMeasurements: [BodyMeasurement] {
        store.displayMeasurements(for: trendProfile.id)
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
            RootPageScrollView(scrollToTopRequest: scrollToTopRequest) {
                VStack(spacing: 18) {
                    MainPageTitle(text: store.appLanguage.text(.trends))
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
                            onExpand: presentExpandedTrend,
                            isExpanded: expandedTrend?.context.metric == metric
                        )
                    }
                    if orderedMetrics.contains(where: \.isEstimatedComposition) {
                        Text("身体成分指标为消费级估算值，仅用于长期趋势参考，不构成医疗诊断。")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .padding(.horizontal, 4)
                    }
                    HealthSafetyNotice()
                    records
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: store.displayProfiles) {
                if let profileID = selectedTrendProfileID,
                   !store.displayProfiles.contains(where: { $0.id == profileID }) {
                    selectedTrendProfileID = nil
                }
            }
        }
        .accessibilityHidden(activeFilterPopover != nil)
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
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 2 : 5), spacing: 8) {
            filterButton(
                popover: .metrics,
                title: "类别",
                value: store.appLanguage.format("已选 %lld 项", Int64(selectedMetrics.count)),
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
                value: store.appLanguage.format(
                    "%@，%@",
                    store.appLanguage.text(chartMode.title),
                    store.appLanguage.text(displayScope.title)
                ),
                icon: .system("eye")
            )
        }
        .padding(6)
        .background(AppColor.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                AppLocalizedText(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isActive ? AppColor.onAccent : AppColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(
                isActive ? AppColor.mint : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: TrendFilterAnchorKey.self, value: .bounds) { [popover: $0] }
        .accessibilityLabel(store.appLanguage.text(title))
        .accessibilityValue(value)
        .accessibilityReturnFocus(when: activeFilterPopover == popover)
        .help(store.appLanguage.format("%@：%@", store.appLanguage.text(title), value))
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
        return [allDevices] + store.displayPairedScales.map { scale in
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
        store.displayProfiles.map { profile in
            TrendDropdownOption(
                id: profile.id.uuidString,
                value: profile.id,
                title: profile.name,
                subtitle: profile.role,
                icon: .avatar(profile.avatar)
            )
        }
    }

    private var trendProfileSelection: Binding<UUID> {
        Binding(
            get: { trendProfile.id },
            set: { selectedTrendProfileID = $0 }
        )
    }

    private var selectedSourceTitle: String {
        guard let selectedDeviceID else { return "全部设备" }
        return store.displayPairedScales.first(where: { $0.id == selectedDeviceID })?.name ?? "所选设备"
    }

    private func dismissFilterPopover() {
        withAnimation(.easeOut(duration: 0.16)) {
            activeFilterPopover = nil
        }
    }

    private func presentExpandedTrend(_ context: ExpandedTrendContext) {
        guard expandedTrend == nil else { return }
        activeFilterPopover = nil
        expandedTrend = ExpandedTrendPresentation(
            context: context,
            unit: store.unit,
            range: range,
            rangeTitle: selectedRangeTitle,
            dateInterval: selectedDateInterval,
            displayScope: displayScope
        )
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
           let scale = store.displayPairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? store.appLanguage.text(measurement.source.localizationKey)
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
                    Text(
                        verbatim: "\(store.unit.value(fromKilograms: measurement.weightKG).formatted(2)) \(store.unit.symbol)"
                    )
                        .font(.body.bold())
                        .foregroundStyle(AppColor.ink)
                    ScaleDeviceLabel(title: sourceName, iconSize: 13)
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(measurement.date, format: .dateTime.year().month().day())
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
    @State private var visibleMeasurementCount = 50

    private static let measurementPageSize = 50

    let range: TrendTimeRange
    let rangeTitle: String
    let dateInterval: ClosedRange<Date>?
    let selectedDeviceID: UUID?
    let selectedProfileID: UUID
    let sourceTitle: String

    private var profile: UserProfile {
        store.displayProfiles.first(where: { $0.id == selectedProfileID }) ?? store.displaySelectedProfile
    }

    private var measurements: [BodyMeasurement] {
        let profileMeasurements: [BodyMeasurement]
        profileMeasurements = store.displayMeasurements(for: selectedProfileID)
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
        let allMeasurements = measurements
        let visibleMeasurements = Array(allMeasurements.prefix(visibleMeasurementCount))

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
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if allMeasurements.isEmpty {
                            Text("当前筛选条件下没有记录")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.secondary)
                                .padding(.vertical, 18)
                        }
                        ForEach(Array(visibleMeasurements.enumerated()), id: \.element.id) { index, item in
                            MeasurementRecordLink(measurement: item, sourceName: sourceName(for: item))
                                .onAppear {
                                    loadMoreIfNeeded(
                                        visibleIndex: index,
                                        visibleCount: visibleMeasurements.count,
                                        totalCount: allMeasurements.count
                                    )
                                }
                            if index < visibleMeasurements.count - 1 { Divider() }
                        }
                    }
                }
            }
            .padding(18)
        }
        .pageBackground()
        .navigationTitle("全部测量记录")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }

    private func loadMoreIfNeeded(visibleIndex: Int, visibleCount: Int, totalCount: Int) {
        guard visibleIndex == visibleCount - 1, visibleCount < totalCount else { return }
        visibleMeasurementCount = min(totalCount, visibleCount + Self.measurementPageSize)
    }

    private func sourceName(for measurement: BodyMeasurement) -> String {
        if let deviceID = measurement.deviceID,
           let scale = store.displayPairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? store.appLanguage.text(measurement.source.localizationKey)
    }
}

struct MeasurementDetailView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var isOwnerDropdownExpanded = false
    @State private var confirmsDeletion = false
    let measurement: BodyMeasurement

    private var currentMeasurement: BodyMeasurement {
        store.displayMeasurement(id: measurement.id) ?? measurement
    }

    private var profile: UserProfile {
        store.displayProfiles.first(where: { $0.id == currentMeasurement.profileID }) ?? store.displaySelectedProfile
    }

    private var sourceName: String {
        if let deviceID = currentMeasurement.deviceID,
           let scale = store.displayPairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return currentMeasurement.deviceName ?? store.appLanguage.text(currentMeasurement.source.localizationKey)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(currentMeasurement.date, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline).foregroundStyle(AppColor.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.unit.value(fromKilograms: currentMeasurement.weightKG).formatted(2))
                            .font(.system(size: 58, weight: .medium, design: .rounded))
                        Text(store.unit.symbol).font(.headline)
                    }
                    ScaleDeviceLabel(title: sourceName, iconSize: 13)
                        .font(.caption).foregroundStyle(AppColor.secondary)
                    AppDropdownField(
                        value: profile.name,
                        icon: "person.crop.circle",
                        accessibilityLabel: "修改记录归属",
                        isExpanded: isOwnerDropdownExpanded,
                        appearance: .pill,
                        onToggle: toggleOwnerDropdown
                    )
                    .disabled(store.isUsingPlaceholderData)
                }
                .padding(.vertical, 28)
                HealthSafetyNotice(showsCalculationMethod: true)
                    .padding(.horizontal)
                metricCard(title: "基础指标", metrics: basicMetrics)
                if currentMeasurement.hasBodyComposition {
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
        .localizedNavigationBackButton()
        .toolbar {
            if !store.isUsingPlaceholderData {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive, action: showDeleteConfirmation) {
                        Image(systemName: "trash")
                            .foregroundStyle(AppColor.rose)
                    }
                    .accessibilityLabel(Text(store.appLanguage.text("删除测量记录")))
                    .accessibilityReturnFocus(when: confirmsDeletion)
                }
            }
        }
        .accessibilityHidden(isOwnerDropdownExpanded || confirmsDeletion)
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if isOwnerDropdownExpanded, let anchor {
                    AppDropdownMenuLayer(
                        anchorFrame: proxy[anchor],
                        availableSize: proxy.size,
                        options: store.displayProfiles.map(\.id),
                        isSelected: { $0 == currentMeasurement.profileID },
                        title: { profileName(for: $0) },
                        preferredWidth: ownerMenuWidth,
                        appearance: .compact,
                        onSelect: reassignMeasurement,
                        onDismiss: hideOwnerDropdown
                    )
                }
            }
        }
        .overlay {
            if confirmsDeletion {
                DestructiveConfirmationOverlay(
                    icon: "trash.fill",
                    title: "删除这条测量记录？",
                    message: "这条测量记录将被永久删除，且无法恢复。",
                    confirmTitle: "删除测量记录",
                    onCancel: hideDeleteConfirmation,
                    onConfirm: deleteMeasurement
                )
                .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(isOwnerDropdownExpanded || confirmsDeletion)
    }

    private var basicMetrics: [(String, String)] {
        [("BMI", currentMeasurement.bmi(heightCM: profile.heightCM).formatted(2))]
    }

    private var compositionMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        append(currentMeasurement.bodyFatPercent, name: "体脂率", suffix: "%", to: &metrics)
        append(currentMeasurement.fatMassKG, name: "脂肪量", suffix: " kg", to: &metrics)
        append(currentMeasurement.musclePercent, name: "肌肉率", suffix: "%", to: &metrics)
        append(currentMeasurement.muscleMassKG, name: "肌肉量", suffix: " kg", to: &metrics)
        append(currentMeasurement.waterPercent, name: "身体水分", suffix: "%", to: &metrics)
        append(currentMeasurement.waterMassKG, name: "水分量", suffix: " kg", to: &metrics)
        append(currentMeasurement.bonePercent, name: "骨量占比", suffix: "%", to: &metrics)
        append(currentMeasurement.boneMassKG, name: "骨量", suffix: " kg", to: &metrics)
        append(currentMeasurement.visceralFat, name: "内脏脂肪", suffix: "", to: &metrics)
        if let value = currentMeasurement.basalMetabolismKCal {
            metrics.append(("基础代谢", "\(value.formatted(2)) kcal"))
        }
        return metrics
    }

    private var rawMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        if let value = currentMeasurement.impedanceOhm {
            metrics.append(("阻抗通道 1", "\(value.formatted(2)) Ω"))
        }
        if let value = currentMeasurement.secondaryImpedanceOhm {
            metrics.append(("阻抗通道 2", "\(value.formatted(2)) Ω"))
        }
        return metrics
    }

    private func toggleOwnerDropdown() {
        withAnimation(.easeOut(duration: 0.18)) {
            isOwnerDropdownExpanded.toggle()
        }
    }

    private func hideOwnerDropdown() {
        withAnimation(.easeOut(duration: 0.16)) {
            isOwnerDropdownExpanded = false
        }
    }

    private func profileName(for profileID: UUID) -> String {
        store.displayProfiles.first(where: { $0.id == profileID })?.name ?? ""
    }

    private var ownerMenuWidth: CGFloat {
        let longestNameLength = store.displayProfiles.map(\.name.count).max() ?? 0
        return min(260, max(132, CGFloat(longestNameLength) * 14 + 68))
    }

    private func reassignMeasurement(to profileID: UUID) {
        _ = store.reassignMeasurement(measurement.id, to: profileID)
        hideOwnerDropdown()
    }

    private func showDeleteConfirmation() {
        isOwnerDropdownExpanded = false
        withAnimation(.easeOut(duration: 0.12)) {
            confirmsDeletion = true
        }
    }

    private func hideDeleteConfirmation() {
        withAnimation(.easeOut(duration: 0.12)) {
            confirmsDeletion = false
        }
    }

    private func deleteMeasurement() {
        confirmsDeletion = false
        if store.deleteMeasurement(measurement.id) {
            dismiss()
        }
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
                AppLocalizedText(title).font(.headline).padding(.bottom, 4)
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    DetailRow(
                        name: metric.0,
                        value: metric.1,
                        divider: index < metrics.count - 1,
                        isCalculated: metric.0 == "BMI" || DashboardMetricKind.allCases.contains {
                            $0.title == metric.0 && $0.isCalculated
                        }
                    )
                }
            }
        }
    }
}

private struct DetailRow: View {
    @Environment(\.appLanguage) private var language

    let name: String, value: String
    var divider = true
    var isCalculated = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text(name)).foregroundStyle(AppColor.secondary)
                    if isCalculated {
                        Text(language.text("计算值"))
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }
                }
                Spacer()
                Text(value).fontWeight(.semibold)
            }
            .padding(.vertical, 15)
            .accessibilityElement(children: .combine)
            if divider { Divider() }
        }
    }
}
