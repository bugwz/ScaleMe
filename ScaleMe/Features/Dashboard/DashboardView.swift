import Charts
import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var store: MeasurementStore
    let onMeasure: (UUID) -> Void
    let onShowTrends: () -> Void

    private static let localMeasurementDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    @State private var selectedProfileID: UUID?
    @State private var isEditingMetrics = false

    private var latest: BodyMeasurement { store.latest ?? MeasurementStore.demoMeasurements[0] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    brandTitle
                        .padding(.horizontal, 18)
                    memberPager
                    metricsSection
                        .padding(.horizontal, 18)
                }
                .padding(.bottom, 28)
            }
            .onAppear {
                if selectedProfileID == nil {
                    selectedProfileID = store.displaySelectedProfileID
                }
            }
            .onChange(of: store.displaySelectedProfileID) { _, newID in
                if selectedProfileID != newID {
                    selectedProfileID = newID
                }
            }
            .onChange(of: selectedProfileID) { _, newID in
                guard let newID, newID != store.displaySelectedProfileID else { return }
                store.selectDisplayProfile(newID)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var brandTitle: some View {
        HStack(spacing: 11) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(store.appLanguage.text(.productName))
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.ink)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.appLanguage.text(.productName))
    }

    private var memberPager: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(store.displayProfiles) { profile in
                        memberCard(for: profile)
                            .padding(.horizontal, 18)
                            .containerRelativeFrame(.horizontal)
                            .id(profile.id)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.97)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedProfileID)
            .frame(height: 410)
            .clipped()

            if store.displayProfiles.count > 1 {
                HStack(spacing: 7) {
                    ForEach(store.displayProfiles) { profile in
                        let theme = AppColor.memberTheme(for: profile.avatar)
                        let isSelected = profile.id == (selectedProfileID ?? store.displaySelectedProfileID)
                        Capsule()
                            .fill(
                                isSelected
                                    ? theme.primary
                                    : theme.primary.opacity(0.22)
                            )
                            .frame(width: isSelected ? 20 : 7, height: 7)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedProfileID)
                .accessibilityHidden(true)
            }
        }
    }

    private func memberCard(for profile: UserProfile) -> some View {
        let measurements = cardMeasurements(for: profile.id)
        let current = measurements.first
        let theme = AppColor.memberTheme(for: profile.avatar)
        let informationColumnWidth: CGFloat = 176

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            theme.primary.opacity(0.12),
                            theme.secondary.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ZStack(alignment: .trailing) {
                MemberAvatarView(
                    avatar: profile.avatar,
                    width: 224,
                    height: 396,
                    showsBackdrop: false
                )
                .frame(width: 224, height: 396)
                .offset(x: 52, y: 10)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(profile.name)
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                    Text(
                        store.appLanguage.format(
                            "%@ · %lld 岁",
                            store.appLanguage.text(profile.relation),
                            profile.age
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)

                    Text("最近体重")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .padding(.top, 18)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(current.map { store.unit.value(fromKilograms: $0.weightKG).formatted(2) } ?? "--")
                            .font(.system(size: 46, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .contentTransition(.numericText())
                        Text(store.unit.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize()
                    }
                    .foregroundStyle(AppColor.ink)
                    .layoutPriority(1)
                    .frame(height: 56, alignment: .leading)

                    VStack(alignment: .leading, spacing: 7) {
                        memberInfoRow(
                            "BMI \(current.map { $0.bmi(heightCM: profile.heightCM).formatted(2) } ?? "--")",
                            systemImage: "figure.stand"
                        )
                        memberInfoRow(
                            "\(store.appLanguage.text("体脂率")) \(current?.bodyFatPercent.map { "\($0.formatted(2))%" } ?? "--")",
                            systemImage: "drop.fill",
                            usesBodyFatRateIcon: true
                        )
                        memberInfoRow(
                            current.map { Self.localMeasurementDateFormatter.string(from: $0.date) } ?? "--",
                            systemImage: "clock"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 62, alignment: .topLeading)

                    compactTrend(
                        measurements: measurements,
                        theme: theme
                    )
                    .padding(.top, 12)

                    Button { onMeasure(profile.id) } label: {
                        Label("开始测量", systemImage: "wave.3.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(theme.primary, in: Capsule())
                    }
                    .padding(.top, 4)
                }
                .frame(width: informationColumnWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .zIndex(1)
            }
            .frame(height: 362)
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(theme.primary.opacity(0.10)))
        .shadow(color: theme.primary.opacity(0.12), radius: 18, y: 8)
        .padding(.vertical, 4)
    }

    private func memberInfoRow(
        _ text: String,
        systemImage: String,
        usesBodyFatRateIcon: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Group {
                if usesBodyFatRateIcon {
                    BodyFatRateIcon(size: 14)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .regular))
                }
            }
            .frame(width: 14, height: 14, alignment: .center)
            AppLocalizedText(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 14)
    }

    private func cardMeasurements(for profileID: UUID) -> [BodyMeasurement] {
        store.isShowingDemoData
            ? store.displayMeasurements(for: profileID)
            : store.measurements(for: profileID)
    }

    private func compactTrend(
        measurements: [BodyMeasurement],
        theme: MemberVisualTheme
    ) -> some View {
        let recentMeasurements = lastWeekMeasurements(from: measurements)
        let weightDomain = compactWeightDomain(for: recentMeasurements)
        let placeholderValue = recentMeasurements.first
            .map { store.unit.value(fromKilograms: $0.weightKG) }
            ?? 0.5

        return Button(action: onShowTrends) {
            Chart {
                if recentMeasurements.count >= 2 {
                    ForEach(recentMeasurements) { item in
                        LineMark(
                            x: .value("日期", item.date),
                            y: .value("体重", store.unit.value(fromKilograms: item.weightKG))
                        )
                        .foregroundStyle(theme.primary)
                        .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                } else {
                    RuleMark(y: .value("暂无完整趋势", placeholderValue))
                        .foregroundStyle(theme.primary.opacity(0.32))
                        .lineStyle(.init(lineWidth: 2, dash: [5, 5]))

                    if let item = recentMeasurements.first {
                        PointMark(
                            x: .value("日期", item.date),
                            y: .value("体重", store.unit.value(fromKilograms: item.weightKG))
                        )
                        .foregroundStyle(theme.primary)
                        .symbolSize(24)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: weightDomain)
            .frame(height: 34)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看近期趋势")
        .accessibilityValue(
            store.appLanguage.text(
                recentMeasurements.count >= 2 ? "近一周体重趋势" : "近一周趋势数据不足"
            )
        )
        .accessibilityHint("切换到趋势页面")
    }

    private func lastWeekMeasurements(from measurements: [BodyMeasurement]) -> [BodyMeasurement] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return measurements
            .filter { $0.date >= start && $0.date <= .now }
            .sorted { $0.date < $1.date }
    }

    private func compactWeightDomain(
        for measurements: [BodyMeasurement]
    ) -> ClosedRange<Double> {
        let values = measurements.map { store.unit.value(fromKilograms: $0.weightKG) }
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }

        let spread = maximum - minimum
        let minimumPadding = store.unit.value(fromKilograms: 0.05)
        let padding = spread > 0
            ? max(spread * 0.16, minimumPadding)
            : max(abs(minimum) * 0.002, minimumPadding)
        return (minimum - padding)...(maximum + padding)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("健康指标")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Button {
                    isEditingMetrics = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.secondary)
                        .padding(8)
                        .background(AppColor.paleMint, in: Circle())
                }
                .accessibilityLabel("编辑健康指标显示与排序")
            }
            metricsGrid
        }
        .sheet(isPresented: $isEditingMetrics) {
            DashboardMetricsEditorView(
                order: store.dashboardMetricOrder,
                visible: store.dashboardVisibleMetrics,
                measurement: latest,
                source: sourceName(for: latest)
            ) { newOrder, newVisible in
                store.updateDashboardMetrics(order: newOrder, visible: newVisible)
            }
        }
    }

    private var metricsGrid: some View {
        let visibleMetrics = store.dashboardMetricOrder.filter { store.dashboardVisibleMetrics.contains($0) }
        return LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            ForEach(visibleMetrics) { kind in
                MetricTile(
                    title: kind.title,
                    value: kind.value(in: latest).map { $0.formatted(2) } ?? "--",
                    unit: kind.unit,
                    source: sourceName(for: latest),
                    icon: kind.icon,
                    color: kind.themeColor,
                    usesBodyFatRateIcon: kind == .bodyFatPercent,
                    usesVisceralFatIcon: kind == .visceralFat
                )
            }
        }
    }

    private func sourceName(for measurement: BodyMeasurement) -> String {
        if let deviceID = measurement.deviceID,
           let scale = store.displayPairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? store.appLanguage.text(measurement.source.rawValue)
    }
}

private extension DashboardMetricKind {
    var themeColor: Color {
        switch self {
        case .bodyFatPercent: AppColor.trendBodyFat
        case .fatMassKG: AppColor.trendFatMass
        case .muscleMassKG: AppColor.trendMuscleMass
        case .musclePercent: AppColor.trendMusclePercent
        case .waterPercent: AppColor.trendWaterPercent
        case .waterMassKG: AppColor.trendWaterMass
        case .proteinPercent: AppColor.trendProteinPercent
        case .proteinMassKG: AppColor.trendProteinMass
        case .boneMassKG: AppColor.trendBoneMass
        case .bonePercent: AppColor.trendBonePercent
        case .visceralFat: AppColor.trendVisceralFat
        case .basalMetabolismKCal: AppColor.trendBasalMetabolism
        }
    }
}

private struct MetricFramePreferenceKey: PreferenceKey {
    static var defaultValue: [DashboardMetricKind: CGRect] = [:]
    static func reduce(value: inout [DashboardMetricKind: CGRect], nextValue: () -> [DashboardMetricKind: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct ScrollViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DashboardMetricGridLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? naturalWidth(for: subviews)
        let cellWidth = max(0, (width - spacing) / 2)
        let rowHeights = measuredRowHeights(subviews: subviews, cellWidth: cellWidth)
        return CGSize(
            width: width,
            height: rowHeights.reduce(0, +) + spacing * CGFloat(max(0, rowHeights.count - 1))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let cellWidth = max(0, (bounds.width - spacing) / 2)
        let rowHeights = measuredRowHeights(subviews: subviews, cellWidth: cellWidth)
        var rowY = bounds.minY

        for index in subviews.indices {
            let row = index / 2
            let column = index % 2
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (cellWidth + spacing),
                    y: rowY
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: cellWidth, height: rowHeights[row])
            )
            if column == 1 || index == subviews.count - 1 {
                rowY += rowHeights[row] + spacing
            }
        }
    }

    private func naturalWidth(for subviews: Subviews) -> CGFloat {
        let maximumWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return maximumWidth * 2 + spacing
    }

    private func measuredRowHeights(subviews: Subviews, cellWidth: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: 2).map { rowStart in
            let firstHeight = subviews[rowStart]
                .sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            guard rowStart + 1 < subviews.count else { return firstHeight }
            let secondHeight = subviews[rowStart + 1]
                .sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            return max(firstHeight, secondHeight)
        }
    }
}

private final class DashboardMetricsAutoScroller: ObservableObject {
    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    private var velocity: CGFloat = 0
    private var previousTimestamp: CFTimeInterval?

    func attach(toAncestorOf view: UIView) {
        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                self.scrollView = scrollView
                return
            }
            ancestor = current.superview
        }
    }

    func update(fingerY: CGFloat, viewportHeight: CGFloat) {
        guard viewportHeight > 0 else {
            stop()
            return
        }

        let edgeSize = min(88, viewportHeight * 0.22)
        let maximumSpeed: CGFloat = 460
        if fingerY < edgeSize {
            let intensity = min(1, max(0, (edgeSize - fingerY) / edgeSize))
            setVelocity(-maximumSpeed * intensity * intensity)
        } else if fingerY > viewportHeight - edgeSize {
            let intensity = min(1, max(0, (fingerY - viewportHeight + edgeSize) / edgeSize))
            setVelocity(maximumSpeed * intensity * intensity)
        } else {
            stop()
        }
    }

    func stop() {
        velocity = 0
        previousTimestamp = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    private func setVelocity(_ velocity: CGFloat) {
        self.velocity = velocity
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let scrollView else {
            stop()
            return
        }
        let elapsed = previousTimestamp.map { min(link.timestamp - $0, 1.0 / 30.0) } ?? 0
        previousTimestamp = link.timestamp
        guard elapsed > 0 else { return }

        let minimumY = -scrollView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let proposedY = scrollView.contentOffset.y + velocity * elapsed
        let clampedY = min(maximumY, max(minimumY, proposedY))
        guard abs(clampedY - scrollView.contentOffset.y) > 0.1 else {
            stop()
            return
        }
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: clampedY),
            animated: false
        )
    }
}

private struct DashboardScrollViewResolver: UIViewRepresentable {
    let autoScroller: DashboardMetricsAutoScroller

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        resolve(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        resolve(from: uiView)
    }

    private func resolve(from view: UIView) {
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            autoScroller.attach(toAncestorOf: view)
        }
    }
}

private struct DashboardMetricsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language
    @Namespace private var metricAnimation
    @StateObject private var autoScroller = DashboardMetricsAutoScroller()
    @State private var shown: [DashboardMetricKind]
    @State private var hidden: [DashboardMetricKind]
    @State private var itemFrames: [DashboardMetricKind: CGRect] = [:]
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var draggingKind: DashboardMetricKind?
    @State private var draggingIsShown: Bool?
    @State private var dragLocation: CGPoint?
    @State private var dragGrabOffset: CGSize = .zero
    @State private var dragCardSize: CGSize = .zero
    @State private var hasResolvedDragTouch = false
    @State private var pendingRelocationTarget: DashboardMetricKind?
    @State private var dragActivationFeedback = 0
    @State private var isDragLifted = false
    @State private var isSettlingDrag = false
    let measurement: BodyMeasurement
    let source: String
    let onSave: ([DashboardMetricKind], Set<DashboardMetricKind>) -> Void

    init(
        order: [DashboardMetricKind],
        visible: Set<DashboardMetricKind>,
        measurement: BodyMeasurement,
        source: String,
        onSave: @escaping ([DashboardMetricKind], Set<DashboardMetricKind>) -> Void
    ) {
        _shown = State(initialValue: order.filter { visible.contains($0) })
        _hidden = State(initialValue: order.filter { !visible.contains($0) })
        self.measurement = measurement
        self.source = source
        self.onSave = onSave
    }

    private static let coordinateSpaceName = "dashboardMetricsEditor"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPanel(title: "展示中", icon: "eye") {
                        metricGrid(shown, isShown: true)
                    }
                    SettingsPanel(title: "已隐藏", icon: "eye.slash") {
                        metricGrid(hidden, isShown: false)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                .background(DashboardScrollViewResolver(autoScroller: autoScroller))
            }
            .scrollDisabled(draggingKind != nil)
            .coordinateSpace(name: Self.coordinateSpaceName)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollViewportHeightPreferenceKey.self,
                        value: geo.size.height
                    )
                }
            )
            .onPreferenceChange(MetricFramePreferenceKey.self) { frames in
                itemFrames = frames
                if let dragged = draggingKind,
                   let location = dragLocation,
                   frames[dragged]?.contains(location) == true {
                    pendingRelocationTarget = nil
                }
                if let dragged = draggingKind, let location = dragLocation {
                    relocate(dragged, to: location, using: frames)
                }
            }
            .onPreferenceChange(ScrollViewportHeightPreferenceKey.self) { scrollViewportHeight = $0 }
            .overlay(alignment: .topLeading) {
                dragPreview
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: dragActivationFeedback)
            .pageBackground()
            .navigationTitle("健康指标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave(shown + hidden, Set(shown))
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(draggingKind != nil)
        .onDisappear { autoScroller.stop() }
    }

    @ViewBuilder
    private var dragPreview: some View {
        if let kind = draggingKind,
           let isShown = draggingIsShown,
           let location = dragLocation {
            MetricTile(
                title: kind.title,
                value: kind.value(in: measurement).map { $0.formatted(2) } ?? "--",
                unit: kind.unit,
                source: source,
                icon: kind.icon,
                color: kind.themeColor,
                usesBodyFatRateIcon: kind == .bodyFatPercent,
                usesVisceralFatIcon: kind == .visceralFat
            )
            .opacity(isShown ? 1 : 0.55)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColor.mint.opacity(isDragLifted ? 0.9 : 0.35), lineWidth: 2.5)
            )
            .frame(width: dragCardSize.width, height: dragCardSize.height)
            .scaleEffect(reduceMotion || isSettlingDrag || !isDragLifted ? 1 : 1.06)
            .shadow(
                color: AppColor.mint.opacity(isDragLifted && !isSettlingDrag ? 0.32 : 0),
                radius: isDragLifted && !isSettlingDrag ? 18 : 0,
                y: isDragLifted && !isSettlingDrag ? 10 : 0
            )
            .position(
                x: location.x - dragGrabOffset.width + dragCardSize.width / 2,
                y: location.y - dragGrabOffset.height + dragCardSize.height / 2
            )
            .allowsHitTesting(false)
            .zIndex(10)
        }
    }

    @ViewBuilder
    private func metricGrid(_ kinds: [DashboardMetricKind], isShown: Bool) -> some View {
        Group {
            if kinds.isEmpty {
                AppLocalizedText(isShown ? "暂无展示指标" : "暂无隐藏指标")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(AppColor.paleMint.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                DashboardMetricGridLayout(spacing: 12) {
                    ForEach(kinds) { kind in
                        metricCard(kind, isShown: isShown)
                    }
                }
            }
        }
    }

    private func metricCard(_ kind: DashboardMetricKind, isShown: Bool) -> some View {
        let isDragging = draggingKind == kind

        return MetricTile(
            title: kind.title,
            value: kind.value(in: measurement).map { $0.formatted(2) } ?? "--",
            unit: kind.unit,
            source: source,
            icon: kind.icon,
            color: kind.themeColor,
            usesBodyFatRateIcon: kind == .bodyFatPercent,
            usesVisceralFatIcon: kind == .visceralFat
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColor.mint.opacity(isDragging ? 0.45 : 0.16), lineWidth: isDragging ? 2 : 1)
        )
        .overlay(alignment: .bottomTrailing) {
            Button {
                toggle(kind, isShown: isShown)
            } label: {
                Image(systemName: isShown ? "eye.slash.fill" : "eye.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(AppColor.ink.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(draggingKind != nil)
            .accessibilityLabel(
                language.format(
                    isShown ? "隐藏%@" : "展示%@",
                    language.text(kind.title)
                )
            )
            .padding(8)
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MetricFramePreferenceKey.self,
                    value: [kind: geo.frame(in: .named(Self.coordinateSpaceName))]
                )
            }
        )
        .opacity(isDragging ? 0 : (isShown ? 1 : 0.55))
        .matchedGeometryEffect(id: kind, in: metricAnimation)
        .transition(.identity)
        // Reordering is a strict long-press-then-drag sequence. Ordinary vertical movement
        // exceeds the long press tolerance first and remains a ScrollView gesture.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.55, maximumDistance: 8)
                .sequenced(
                    before: DragGesture(
                        minimumDistance: 0,
                        coordinateSpace: .named(Self.coordinateSpaceName)
                    )
                )
                .onChanged { value in
                    guard case .second(true, let drag) = value else { return }
                    activateDragging(kind)
                    if let drag {
                        updateDragging(kind, with: drag)
                    }
                }
                .onEnded { _ in
                    if draggingKind == kind {
                        finishDragging()
                    }
                }
        )
    }

    private func activateDragging(_ kind: DashboardMetricKind) {
        guard draggingKind == nil, let frame = itemFrames[kind] else { return }
        draggingKind = kind
        draggingIsShown = shown.contains(kind)
        dragCardSize = frame.size
        dragLocation = CGPoint(x: frame.midX, y: frame.midY)
        dragGrabOffset = CGSize(
            width: frame.width / 2,
            height: frame.height / 2
        )
        hasResolvedDragTouch = false
        dragActivationFeedback += 1
        DispatchQueue.main.async {
            guard draggingKind == kind else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.78)) {
                isDragLifted = true
            }
        }
    }

    private func updateDragging(_ kind: DashboardMetricKind, with drag: DragGesture.Value) {
        guard draggingKind == kind else { return }
        if !hasResolvedDragTouch, let frame = itemFrames[kind] {
            dragGrabOffset = CGSize(
                width: drag.location.x - frame.minX,
                height: drag.location.y - frame.minY
            )
            hasResolvedDragTouch = true
        }
        dragLocation = drag.location
        relocate(kind, to: drag.location, using: itemFrames)
        autoScroller.update(
            fingerY: drag.location.y,
            viewportHeight: scrollViewportHeight
        )
    }

    private func finishDragging() {
        autoScroller.stop()
        guard !reduceMotion,
              let dragged = draggingKind,
              let destination = itemFrames[dragged] else {
            resetDragState()
            return
        }

        withAnimation(.snappy(duration: 0.18), completionCriteria: .logicallyComplete) {
            isSettlingDrag = true
            dragLocation = CGPoint(
                x: destination.minX + dragGrabOffset.width,
                y: destination.minY + dragGrabOffset.height
            )
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        draggingKind = nil
        draggingIsShown = nil
        dragLocation = nil
        dragGrabOffset = .zero
        dragCardSize = .zero
        hasResolvedDragTouch = false
        pendingRelocationTarget = nil
        isDragLifted = false
        isSettlingDrag = false
    }

    private func relocate(
        _ dragged: DashboardMetricKind,
        to location: CGPoint,
        using frames: [DashboardMetricKind: CGRect]
    ) {
        guard let draggingIsShown else { return }
        // Once the dragged card occupies the slot under the finger, keep the current order.
        // Treating that point as empty space would immediately send it to the section's end.
        if frames[dragged]?.contains(location) == true { return }

        let currentSection = draggingIsShown ? shown : hidden
        guard let target = currentSection.first(where: {
            $0 != dragged && frames[$0]?.contains(location) == true
        }), target != pendingRelocationTarget else { return }
        pendingRelocationTarget = target
        move(dragged, ontoTarget: target, isShown: draggingIsShown)
    }

    private func toggle(_ kind: DashboardMetricKind, isShown: Bool) {
        var newShown = shown
        var newHidden = hidden
        if isShown {
            newShown.removeAll { $0 == kind }
            newHidden.insert(kind, at: 0)
        } else {
            newHidden.removeAll { $0 == kind }
            newShown.append(kind)
        }
        applyOrder(newShown: newShown, newHidden: newHidden)
    }

    private func move(_ dragged: DashboardMetricKind, ontoTarget target: DashboardMetricKind, isShown: Bool) {
        var newShown = shown
        var newHidden = hidden
        let targetIndex = (isShown ? shown : hidden).firstIndex(of: target)
        newShown.removeAll { $0 == dragged }
        newHidden.removeAll { $0 == dragged }
        var destination = isShown ? newShown : newHidden
        guard let targetIndex else { return }
        destination.insert(dragged, at: min(targetIndex, destination.endIndex))
        if isShown {
            newShown = destination
        } else {
            newHidden = destination
        }
        applyOrder(newShown: newShown, newHidden: newHidden)
    }

    private func applyOrder(newShown: [DashboardMetricKind], newHidden: [DashboardMetricKind]) {
        guard newShown != shown || newHidden != hidden else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22)) {
            shown = newShown
            hidden = newHidden
        }
    }
}

private struct MetricTile: View {
    let title: String, value: String, unit: String, source: String, icon: String
    let color: Color
    var usesBodyFatRateIcon = false
    var usesVisceralFatIcon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Group {
                    if usesBodyFatRateIcon {
                        BodyFatRateIcon(size: 17)
                    } else if usesVisceralFatIcon {
                        VisceralFatIcon(size: 17)
                    } else {
                        Image(systemName: icon)
                    }
                }
                .foregroundStyle(color)
                Spacer()
                StatusPill(text: "标准")
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title2.bold()).foregroundStyle(AppColor.ink)
                Text(unit).font(.caption).foregroundStyle(AppColor.secondary)
            }
            AppLocalizedText(title).font(.caption).foregroundStyle(AppColor.secondary)
            Text(source).font(.caption2).foregroundStyle(AppColor.secondary).lineLimit(1)
        }
        .padding(17).background(.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
