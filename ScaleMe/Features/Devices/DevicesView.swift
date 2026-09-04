import SwiftUI
import UniformTypeIdentifiers

private enum DiagnosticExportState {
    case exporting
    case ready(String)
}

private struct DiagnosticReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var report = ""

    init(report: String = "") {
        self.report = report
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let report = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.report = report
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(report.utf8))
    }
}

private struct ScaleProtocolMenuAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct ScannerDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let modelName: String
    let rssi: Int
    let compatibility: String
    let discoveryPriority: Int
    let isVerifiedCompatible: Bool

    init(
        id: UUID,
        name: String,
        modelName: String,
        rssi: Int,
        compatibility: String,
        discoveryPriority: Int,
        isVerifiedCompatible: Bool
    ) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.rssi = rssi
        self.compatibility = compatibility
        self.discoveryPriority = discoveryPriority
        self.isVerifiedCompatible = isVerifiedCompatible
    }

    init(discoveredScale: DiscoveredScale) {
        id = discoveredScale.id
        name = discoveredScale.name
        modelName = discoveredScale.name
        rssi = discoveredScale.rssi
        compatibility = discoveredScale.compatibility
        discoveryPriority = discoveredScale.discoveryPriority
        isVerifiedCompatible = discoveredScale.isVerifiedCompatible
    }
}

private struct ScaleDragState {
    let scale: PairedScale
    var location: CGPoint
    var hitTestLocation: CGPoint
    var grabOffset: CGSize
    let rowSize: CGSize
    let horizontalCenter: CGFloat
    var pendingRelocationTargetID: UUID?
    var hasResolvedDragTouch = false
    var hasStartedMoving = false
    var isLifted = false
    var isSettling = false
}

struct DevicesView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var scaleOrderAnimation
    @StateObject private var autoScroller = VerticalDragAutoScroller()
    @State private var scaleOrder: [UUID] = []
    @State private var scaleFrames: [UUID: CGRect] = [:]
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var dragState: ScaleDragState?
    @State private var dragActivationFeedback = 0
    let scrollToTopRequest: Int

    private static let coordinateSpaceName = "deviceManagement"

    private var draggingScaleID: UUID? {
        dragState?.scale.id
    }

    private var orderedScales: [PairedScale] {
        let scales = store.displayPairedScales
        guard scaleOrder.count == scales.count,
              Set(scaleOrder) == Set(scales.map(\.id)) else { return scales }
        let scalesByID = Dictionary(
            scales.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        return scaleOrder.compactMap { scalesByID[$0] }
    }

    private var canReorder: Bool {
        orderedScales.count > 1
    }

    var body: some View {
        NavigationStack {
            RootPageScrollView(scrollToTopRequest: scrollToTopRequest) {
                VStack(alignment: .leading, spacing: 24) {
                    MainPageTitle(text: store.appLanguage.text(.devices))
                    addDeviceCard
                    deviceSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                .background(VerticalDragScrollViewResolver(autoScroller: autoScroller))
            }
            .scrollDisabled(draggingScaleID != nil)
            .coordinateSpace(name: Self.coordinateSpaceName)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScaleScrollViewportHeightPreferenceKey.self,
                        value: geo.size.height
                    )
                }
            )
            .onPreferenceChange(ScaleRowFramePreferenceKey.self) { frames in
                scaleFrames = frames
                if var state = dragState,
                   frames[state.scale.id]?.contains(state.hitTestLocation) == true,
                   state.pendingRelocationTargetID != nil {
                    state.pendingRelocationTargetID = nil
                    dragState = state
                }
                if let state = dragState {
                    relocate(state.scale.id, to: state.hitTestLocation, using: frames)
                }
            }
            .onPreferenceChange(ScaleScrollViewportHeightPreferenceKey.self) { scrollViewportHeight = $0 }
            .overlay(alignment: .topLeading) {
                dragPreview
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: dragActivationFeedback)
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                synchronizeScaleOrder()
            }
            .onChange(of: store.displayPairedScales.map(\.id)) { _, _ in
                guard draggingScaleID == nil else { return }
                synchronizeScaleOrder()
            }
            .onDisappear {
                autoScroller.stop()
            }
        }
    }

    private var addDeviceCard: some View {
        NavigationLink {
            DeviceScannerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 40, height: 40)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("添加设备")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    AppLocalizedText(store.isSimulationEnabled
                        ? "演示扫描并关联预设模拟设备"
                        : "扫描并关联附近的体重秤或体脂秤")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColor.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("我的设备")
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.ink)
                Spacer()
                StatusPill(
                    text: store.appLanguage.format("%lld 台", orderedScales.count),
                    color: AppColor.sky
                )
            }

            if orderedScales.isEmpty {
                emptyDevicesCard
            } else {
                VStack(spacing: 10) {
                    ForEach(orderedScales) { scale in
                        singleDeviceRow(for: scale)
                    }
                }
            }
        }
    }

    private var emptyDevicesCard: some View {
        VStack(spacing: 14) {
            ScaleAvatarIconView(size: 52, iconSize: 24, accent: AppColor.mint)

            VStack(spacing: 6) {
                Text("还没有绑定设备")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text("添加设备后，测量页会自动接收并关联这些设备上报的健康数据。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
    }

    @ViewBuilder
    private func singleDeviceRow(for scale: PairedScale) -> some View {
        let isDragging = draggingScaleID == scale.id
        let isLiftedInPlace = isDragging
            && dragState?.hasStartedMoving == false
            && dragState?.isLifted == true
            && dragState?.isSettling == false

        let row = NavigationLink {
            ScaleSettingsView(scaleID: scale.id)
        } label: {
            deviceRowVisual(scale)
        }
        .buttonStyle(.plain)
        .disabled(draggingScaleID != nil)
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(
                    AppColor.mint.opacity(isLiftedInPlace ? 0.9 : 0),
                    lineWidth: 2.5
                )
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScaleRowFramePreferenceKey.self,
                    value: [scale.id: geo.frame(in: .named(Self.coordinateSpaceName))]
                )
            }
        )
        .scaleEffect(reduceMotion || !isLiftedInPlace ? 1 : 1.06)
        .shadow(
            color: AppColor.mint.opacity(isLiftedInPlace ? 0.32 : 0),
            radius: isLiftedInPlace ? 18 : 0,
            y: isLiftedInPlace ? 10 : 0
        )
        .opacity(isDragging && dragState?.hasStartedMoving == true ? 0 : 1)
        .matchedGeometryEffect(id: scale.id, in: scaleOrderAnimation)
        .transition(.identity)
        .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))

        if canReorder {
            row
                .simultaneousGesture(reorderGesture(for: scale.id), including: .all)
                .accessibilityHint("长按后上下拖动可调整顺序")
                .accessibilityAction(named: "上移") {
                    moveScale(scale.id, by: -1)
                }
                .accessibilityAction(named: "下移") {
                    moveScale(scale.id, by: 1)
                }
        } else {
            row
        }
    }

    private func deviceRowVisual(_ scale: PairedScale) -> some View {
        let isUnverified = ScaleDiscoveryCompatibility(rawValue: scale.compatibility)?.isVerified != true
        let accentColor = isUnverified ? AppColor.apricot : AppColor.mint

        return HStack(spacing: 14) {
            Image("ScaleDeviceTabIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
                .frame(width: 19, height: 19)
                .frame(width: 40, height: 40)
                .background(
                    accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(scale.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(scale.modelName)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(
                text: isUnverified ? "待验证" : "已关联",
                color: accentColor
            )

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppColor.secondary.opacity(0.7))
        }
        .padding(14)
        .background(AppColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(AppColor.mint.opacity(0.07))
        )
        .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    @ViewBuilder
    private var dragPreview: some View {
        if let state = dragState, state.hasStartedMoving {
            deviceRowVisual(state.scale)
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(AppColor.mint.opacity(state.isLifted ? 0.9 : 0.35), lineWidth: 2.5)
                )
                .frame(width: state.rowSize.width, height: state.rowSize.height)
                .scaleEffect(reduceMotion || state.isSettling || !state.isLifted ? 1 : 1.06)
                .shadow(
                    color: AppColor.mint.opacity(state.isLifted && !state.isSettling ? 0.32 : 0),
                    radius: state.isLifted && !state.isSettling ? 18 : 0,
                    y: state.isLifted && !state.isSettling ? 10 : 0
                )
                .position(
                    x: state.horizontalCenter,
                    y: state.location.y - state.grabOffset.height + state.rowSize.height / 2
                )
                .allowsHitTesting(false)
                .zIndex(10)
        }
    }

    private func reorderGesture(for scaleID: UUID) -> some Gesture {
        LongPressGesture(minimumDuration: 0.55, maximumDistance: 8)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(Self.coordinateSpaceName)
                )
            )
            .onChanged { value in
                guard canReorder,
                      case .second(true, let drag) = value else { return }
                activateDragging(scaleID)
                if let drag {
                    updateDragging(scaleID, with: drag)
                }
            }
            .onEnded { _ in
                if draggingScaleID == scaleID {
                    finishDragging()
                }
            }
    }

    private func activateDragging(_ scaleID: UUID) {
        guard dragState == nil,
              let scale = orderedScales.first(where: { $0.id == scaleID }),
              let frame = scaleFrames[scaleID] else { return }
        dragState = ScaleDragState(
            scale: scale,
            location: CGPoint(x: frame.midX, y: frame.midY),
            hitTestLocation: CGPoint(x: frame.midX, y: frame.midY),
            grabOffset: CGSize(width: frame.width / 2, height: frame.height / 2),
            rowSize: frame.size,
            horizontalCenter: frame.midX
        )
        dragActivationFeedback += 1
        DispatchQueue.main.async {
            guard var state = dragState, state.scale.id == scaleID else { return }
            state.isLifted = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.78)) {
                dragState = state
            }
        }
    }

    private func updateDragging(_ scaleID: UUID, with drag: DragGesture.Value) {
        guard var state = dragState, state.scale.id == scaleID else { return }
        if !state.hasResolvedDragTouch, let frame = scaleFrames[scaleID] {
            state.grabOffset = CGSize(
                width: drag.location.x - frame.minX,
                height: drag.location.y - frame.minY
            )
            state.hasResolvedDragTouch = true
        }
        state.location = drag.location
        state.hitTestLocation = drag.location
        if !state.hasStartedMoving,
           hypot(drag.translation.width, drag.translation.height) > 0.5 {
            state.hasStartedMoving = true
        }
        dragState = state
        relocate(scaleID, to: state.hitTestLocation, using: scaleFrames)
        autoScroller.update(fingerY: drag.location.y, viewportHeight: scrollViewportHeight)
    }

    private func relocate(_ scaleID: UUID, to location: CGPoint, using frames: [UUID: CGRect]) {
        if frames[scaleID]?.contains(location) == true { return }
        guard let targetID = orderedScales.first(where: {
            $0.id != scaleID && frames[$0.id]?.contains(location) == true
        })?.id, targetID != dragState?.pendingRelocationTargetID else { return }
        guard var state = dragState, state.scale.id == scaleID else { return }
        state.pendingRelocationTargetID = targetID
        dragState = state
        moveScaleLocally(scaleID, onto: targetID)
    }

    private func moveScale(_ scaleID: UUID, by offset: Int) {
        let scales = orderedScales
        guard let sourceIndex = scales.firstIndex(where: { $0.id == scaleID }) else { return }
        let targetIndex = sourceIndex + offset
        guard scales.indices.contains(targetIndex) else { return }
        moveScaleLocally(scaleID, onto: scales[targetIndex].id)
        commitScaleOrder()
    }

    private func moveScaleLocally(_ scaleID: UUID, onto targetScaleID: UUID) {
        var newOrder = orderedScales.map(\.id)
        guard scaleID != targetScaleID,
              let targetIndex = newOrder.firstIndex(of: targetScaleID) else { return }
        newOrder.removeAll { $0 == scaleID }
        newOrder.insert(scaleID, at: min(targetIndex, newOrder.endIndex))
        guard newOrder != scaleOrder else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22)) {
            scaleOrder = newOrder
        }
    }

    private func synchronizeScaleOrder() {
        let currentOrder = store.displayPairedScales.map(\.id)
        guard scaleOrder != currentOrder else { return }
        scaleOrder = currentOrder
    }

    private func commitScaleOrder() {
        store.setDisplayScaleOrder(orderedScales.map(\.id))
    }

    private func finishDragging() {
        autoScroller.stop()
        commitScaleOrder()
        guard !reduceMotion,
              var state = dragState,
              let destination = scaleFrames[state.scale.id] else {
            resetDragState()
            return
        }
        state.isSettling = true
        state.location = CGPoint(
            x: destination.minX + state.grabOffset.width,
            y: destination.minY + state.grabOffset.height
        )
        withAnimation(.snappy(duration: 0.18), completionCriteria: .logicallyComplete) {
            dragState = state
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        dragState = nil
    }
}

private struct ScaleRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ScaleScrollViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DeviceScannerView: View {
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsOtherDevices = false
    @State private var isPulsing = false
    @State private var simulatedDevices: [ScannerDevice] = []
    @State private var isSimulatedScanRunning = false
    @State private var simulatedScanTask: Task<Void, Never>?

    private var simulatedCandidates: [ScannerDevice] { [
        ScannerDevice(
            id: UUID(uuidString: "A37A9793-8B8A-4E8F-A1CA-A926D2D7D101") ?? UUID(),
            name: store.appLanguage.text("客厅智能体脂秤"),
            modelName: "ScaleMe Demo Fit S1",
            rssi: -47,
            compatibility: store.appLanguage.text("模拟设备"),
            discoveryPriority: 0,
            isVerifiedCompatible: true
        ),
        ScannerDevice(
            id: UUID(uuidString: "A37A9793-8B8A-4E8F-A1CA-A926D2D7D102") ?? UUID(),
            name: store.appLanguage.text("旅行便携体重秤"),
            modelName: "ScaleMe Demo Mini",
            rssi: -63,
            compatibility: store.appLanguage.text("模拟设备"),
            discoveryPriority: 1,
            isVerifiedCompatible: true
        ),
        ScannerDevice(
            id: UUID(uuidString: "A37A9793-8B8A-4E8F-A1CA-A926D2D7D103") ?? UUID(),
            name: store.appLanguage.text("附近的健康设备"),
            modelName: "Demo BLE Device",
            rssi: -79,
            compatibility: store.appLanguage.text("协议待验证"),
            discoveryPriority: 2,
            isVerifiedCompatible: false
        )
    ] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scanArea
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("添加设备")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: startScan) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                }
                .accessibilityLabel("重新扫描")
            }
        }
        .onAppear {
            isPulsing = true
            startScan()
        }
        .onDisappear {
            simulatedScanTask?.cancel()
            if !store.isSimulationEnabled {
                bluetooth.stopScanning()
            }
        }
    }

    private var scanArea: some View {
        VStack(spacing: 24) {
            scanStage

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppColor.mint)
                    .font(.caption)
                AppLocalizedText(scanInformation)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)

            if scannerDevices.isEmpty {
                emptyScanState
            } else {
                discoveryResults
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var scanStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppColor.mint.opacity(0.08), lineWidth: 28)
                    .frame(width: 250, height: 250)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.06 : 0.98)
                    .opacity(isPulsing && !reduceMotion ? 0.28 : 0.6)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColor.surface, AppColor.paleMint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 204, height: 204)
                    .shadow(color: AppColor.mint.opacity(0.12), radius: 24, y: 10)

                VStack(spacing: 13) {
                    ScaleAvatarIconView(size: 78, iconSize: 36, accent: scanStageColor)

                    StatusPill(text: scanStageLabel, color: scanStageColor)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 7) {
                AppLocalizedText(scanTitle)
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.ink)

                AppLocalizedText(scanDescription)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 330)
    }

    @ViewBuilder
    private var emptyScanState: some View {
        if !store.isSimulationEnabled, case .unavailable = bluetooth.state {
            Button(action: startScan) {
                Label("重试扫描", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MintActionButtonStyle())
        } else {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(AppColor.mint)
                AppLocalizedText(store.isSimulationEnabled ? "正在载入预设模拟设备" : "暂未发现设备，请唤醒体重秤并靠近手机")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var scanStageLabel: String {
        if !store.isSimulationEnabled, case .unavailable = bluetooth.state {
            return "扫描不可用"
        }
        if scannerDevices.isEmpty {
            return "搜索中"
        }
        return store.appLanguage.format("已发现 %lld 台", Int64(scannerDevices.count))
    }

    private var scanStageColor: Color {
        if !store.isSimulationEnabled, case .unavailable = bluetooth.state {
            return AppColor.apricot
        }
        return scannerDevices.isEmpty ? AppColor.sky : AppColor.mint
    }

    private var scanTitle: String {
        if store.isSimulationEnabled {
            return isSimulatedScanRunning ? "正在扫描模拟设备" : "已发现模拟设备"
        }
        if case .unavailable(let reason) = bluetooth.state { return reason }
        return "正在扫描周围设备"
    }

    private var scanDescription: String {
        if store.isSimulationEnabled {
            return "正在演示设备发现流程。这里显示的都是预设内容，不会搜索、连接或操作附近的真实设备。"
        }
        return "正在搜索附近的低功耗蓝牙设备。部分体重秤只有踩亮屏幕或站上去后才会广播。"
    }

    private var scanInformation: String {
        store.isSimulationEnabled
            ? "关联后的模拟设备仅在本次运行中保留。"
            : "标准 BLE Weight 协议及已知的小米广播设备会优先置顶，其余设备需验证兼容性。"
    }

    private var scannerDevices: [ScannerDevice] {
        if store.isSimulationEnabled {
            return simulatedDevices
        }
        return bluetooth.devices.map(ScannerDevice.init(discoveredScale:))
    }

    private var likelyScaleDevices: [ScannerDevice] {
        scannerDevices.filter { $0.discoveryPriority < 2 }
    }

    private var otherDevices: [ScannerDevice] {
        scannerDevices.filter { $0.discoveryPriority == 2 }
    }

    private var discoveryResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            if likelyScaleDevices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("暂未识别到体重秤")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    Text("请先踩亮体重秤。如果名称较普通，可在下方展开附近设备查找。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
            } else {
                Text("推荐识别")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.mint)
                deviceRows(likelyScaleDevices)
            }

            if !otherDevices.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        showsOtherDevices.toggle()
                    } label: {
                        HStack {
                            Text(store.appLanguage.format("其他附近蓝牙设备（%lld）", Int64(otherDevices.count)))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: showsOtherDevices ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(AppColor.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showsOtherDevices {
                        deviceRows(otherDevices)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }
                }
                .animation(.smooth(duration: 0.25), value: showsOtherDevices)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deviceRows(_ devices: [ScannerDevice]) -> some View {
        VStack(spacing: 10) {
            ForEach(devices) { device in
                discoveredRow(device)
            }
        }
    }

    private func discoveredRow(_ device: ScannerDevice) -> some View {
        let existing = store.displayPairedScales.contains { $0.id == device.id }
        let accent = device.isVerifiedCompatible ? AppColor.mint : AppColor.sky

        return HStack(spacing: 12) {
            ScaleAvatarIconView(size: 44, iconSize: 20, accent: accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                Text(store.appLanguage.text(device.compatibility))
                    .font(.caption2)
                    .foregroundStyle(AppColor.secondary)
            }

            Spacer()

            Image(systemName: signalSymbol(for: device.rssi))
                .font(.caption)
                .foregroundStyle(AppColor.secondary)

            Button {
                guard !existing else { return }
                store.addScale(PairedScale(
                    id: device.id,
                    name: device.name,
                    modelName: device.modelName,
                    compatibility: device.compatibility
                ))
                if !store.isSimulationEnabled {
                    bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                }
                dismiss()
            } label: {
                AppLocalizedText(existing ? "已绑定" : "关联")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(existing ? AppColor.secondary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(existing ? AppColor.paleMint : AppColor.mint, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(existing)
        }
        .padding(12)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accent.opacity(0.12)))
    }

    private func signalSymbol(for rssi: Int) -> String {
        if rssi == 127 { return "wifi.slash" }
        if rssi >= -60 { return "wifi" }
        if rssi >= -78 { return "wifi.exclamationmark" }
        return "wifi.slash"
    }

    private func signalDescription(for rssi: Int) -> String {
        if rssi == 127 { return "信号未知" }
        if rssi >= -60 { return "信号强" }
        if rssi >= -78 { return "信号中等" }
        return "信号较弱"
    }

    private func startScan() {
        showsOtherDevices = false
        if store.isSimulationEnabled {
            simulatedScanTask?.cancel()
            simulatedDevices = []
            isSimulatedScanRunning = true
            simulatedScanTask = Task { @MainActor in
                try? await Task.sleep(for: reduceMotion ? .milliseconds(180) : .milliseconds(1_100))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.24)) {
                    simulatedDevices = simulatedCandidates
                    isSimulatedScanRunning = false
                }
            }
        } else {
            bluetooth.startScanning()
        }
    }
}

private struct ScaleSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @Environment(\.dismiss) private var dismiss
    let scaleID: UUID
    @State private var confirmDelete = false
    @State private var confirmClearHistory = false
    @State private var selectedHardwareUnit = XiaomiScaleHardwareUnit.kilograms
    @State private var showsProtocolMenu = false
    @State private var diagnosticExportState: DiagnosticExportState?
    @State private var diagnosticReportDocument = DiagnosticReportDocument()
    @State private var showsDiagnosticFileExporter = false
    @State private var diagnosticExportTask: Task<Void, Never>?

    private var scale: PairedScale? { store.displayPairedScales.first { $0.id == scaleID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                deviceSummaryCard
                namePanel
                informationPanel
                hardwarePanel
                historyPanel
                protocolPanel
                if showsHuaweiHagridCredentials {
                    HuaweiHagridCredentialsPanel(scaleID: scaleID)
                }
                capturePanel

                Button(role: .destructive, action: showDeleteConfirmation) {
                    Label("删除设备", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.rose)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.rose.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("删除设备不会删除该设备历史记录的健康测量数据。")
                    .font(.caption2)
                    .foregroundStyle(AppColor.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlayPreferenceValue(ScaleProtocolMenuAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showsProtocolMenu, let anchor, let scale {
                    let buttonFrame = proxy[anchor]
                    let menuHeight = min(260, max(120, proxy.size.height - 32))
                    let opensBelow = proxy.size.height - buttonFrame.maxY >= min(menuHeight, 220) + 12
                    let menuY = opensBelow
                        ? buttonFrame.maxY + 8
                        : max(8, buttonFrame.minY - menuHeight - 8)

                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    showsProtocolMenu = false
                                }
                            }

                        protocolDropdown(for: scale)
                            .frame(width: buttonFrame.width)
                            .frame(maxHeight: menuHeight)
                            .offset(x: buttonFrame.minX, y: menuY)
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: opensBelow ? .top : .bottom)))
                    }
                }
            }
        }
        .pageBackground()
        .navigationTitle("设备管理")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .onAppear {
            if let scale, !store.isSimulationEnabled { bluetooth.inspectSettings(for: scale) }
        }
        .onDisappear {
            diagnosticExportTask?.cancel()
            bluetooth.endSettingsInspection()
        }
        .onChange(of: bluetooth.settingsSnapshot.hardwareUnit) { _, unit in
            if let unit { selectedHardwareUnit = unit }
        }
        .accessibilityHidden(confirmDelete || confirmClearHistory || diagnosticExportState != nil)
        .overlay {
            if confirmDelete {
                DestructiveConfirmationOverlay(
                    icon: "scalemass.fill",
                    title: "删除设备？",
                    message: store.appLanguage.format(
                        "将解除“%@”的设备关联，已有健康测量记录仍会保留。",
                        scaleDisplayName
                    ),
                    confirmTitle: "删除设备",
                    onCancel: hideDeleteConfirmation,
                    onConfirm: deleteScale
                )
                .transition(.opacity)
            } else if confirmClearHistory {
                DestructiveConfirmationOverlay(
                    icon: "trash.slash.fill",
                    title: "清除设备历史",
                    message: "将按当前外部协议向体重秤发送破坏性清除命令。设备内记录可能无法恢复，发送后仍需重新读取确认结果。",
                    confirmTitle: "发送清除命令",
                    onCancel: { confirmClearHistory = false },
                    onConfirm: {
                        confirmClearHistory = false
                        bluetooth.clearDeviceHistory()
                    }
                )
                .transition(.opacity)
            } else if let diagnosticExportState {
                DiagnosticExportOverlay(
                    state: diagnosticExportState,
                    onSave: saveDiagnosticReport,
                    onDismiss: dismissDiagnosticExport
                )
                .transition(.opacity)
            }
        }
        .fileExporter(
            isPresented: $showsDiagnosticFileExporter,
            document: diagnosticReportDocument,
            contentType: .plainText,
            defaultFilename: diagnosticReportFilename
        ) { _ in }
        .interactiveDismissDisabled(confirmDelete || confirmClearHistory || diagnosticExportState != nil)
    }

    private var scaleDisplayName: String {
        let trimmedName = scale?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "该设备" : trimmedName
    }

    private var showsHuaweiHagridCredentials: Bool {
        guard let scale else { return false }
        if scale.communicationRuleID == CommunicationRuleCatalog.huaweiHagridID
            || scale.compatibility == ScaleDiscoveryCompatibility.huaweiHagridAuthorizationRequired.rawValue {
            return true
        }
        return bluetooth.settingsSnapshot.writableCharacteristicUUIDs.contains {
            HuaweiHagridProtocol.isRequestAuthenticationCharacteristic($0)
        }
    }

    private func showDeleteConfirmation() {
        KeyboardFocus.dismiss()
        showsProtocolMenu = false
        withAnimation(.easeOut(duration: 0.12)) {
            confirmDelete = true
        }
    }

    private func hideDeleteConfirmation() {
        withAnimation(.easeOut(duration: 0.12)) {
            confirmDelete = false
        }
    }

    private func deleteScale() {
        confirmDelete = false
        try? HuaweiHagridCredentialStore().delete(for: scaleID)
        store.removeScale(scaleID)
        if !store.isSimulationEnabled {
            bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
        }
        dismiss()
    }

    private var deviceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ScaleAvatarIconView(size: 52, iconSize: 24, accent: settingsStatusColor)

                VStack(alignment: .leading, spacing: 4) {
                    AppLocalizedText(scale?.name ?? "蓝牙秤")
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(2)
                    Text(scale?.modelName ?? "")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }

            if !store.isSimulationEnabled {
                SettingsSeparator()

                HStack(spacing: 10) {
                    Label {
                        AppLocalizedText(scale?.compatibility ?? "协议待验证")
                    } icon: {
                        Image(systemName: "checkmark.shield")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(1)
                }
            }

            SettingsSeparator()

            HStack(spacing: 10) {
                Text("连接状态")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                StatusPill(
                    text: bluetooth.settingsState.title(in: store.appLanguage),
                    color: settingsStatusColor
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                Spacer(minLength: 8)
                Button {
                    if let scale { bluetooth.reconnectSettings(for: scale) }
                } label: {
                    Group {
                        if bluetooth.settingsState.isBusy {
                            ProgressView()
                                .tint(AppColor.mint)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColor.mint)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(bluetooth.settingsState.isBusy || scale == nil)
                .accessibilityLabel(store.appLanguage.text("重新连接检测"))
            }
        }
        .padding(16)
        .background(AppColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColor.mint.opacity(0.08))
        )
    }

    private var namePanel: some View {
        Group {
            if let scale {
                ScaleNameEditor(scaleID: scaleID, initialName: scale.name) { updatedName in
                    store.renameScale(scaleID, name: updatedName)
                    if !store.isSimulationEnabled {
                        bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                    }
                }
                .equatable()
            }
        }
    }

    private var hardwarePanel: some View {
        SettingsPanel(title: "秤端设置", icon: "slider.horizontal.3") {
            if bluetooth.settingsSnapshot.canConfigureXiaomiUnit {
                VStack(alignment: .leading, spacing: 10) {
                    Text("秤端显示单位")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)

                    HStack(spacing: 8) {
                        ForEach(XiaomiScaleHardwareUnit.allCases) { unit in
                            let isSelected = selectedHardwareUnit == unit
                            Button {
                                selectedHardwareUnit = unit
                            } label: {
                                AppLocalizedText(unit.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isSelected ? .white : AppColor.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? AppColor.mint : AppColor.canvas, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        bluetooth.configureHardwareUnit(selectedHardwareUnit)
                    } label: {
                        ScaleDeviceLabel(title: "写入秤端单位", iconSize: 16)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                SettingsValueRow(title: "秤端显示单位", value: "未发现可写特征")
            }

            Divider()

            if bluetooth.settingsSnapshot.canSynchronizeTime {
                Button {
                    bluetooth.synchronizeScaleTime()
                } label: {
                    Label("同步当前手机时间到秤端", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                SettingsValueRow(title: "秤端时间同步", value: "未发现可写特征")
            }

            if let message = bluetooth.settingsOperationMessage {
                Label(
                    message,
                    systemImage: bluetooth.settingsOperationSucceeded ? "checkmark.circle.fill" : "info.circle"
                )
                .font(.caption)
                .foregroundStyle(bluetooth.settingsOperationSucceeded ? AppColor.mint : AppColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text("单位写入支持小米二代 0x1542 可写特征。ATT 交互响应会实时记录在下方诊断日志中。")
                .font(.caption2).foregroundStyle(AppColor.secondary).lineSpacing(3)
        }
    }

    @ViewBuilder
    private var historyPanel: some View {
        if canReadDeviceHistory {
            SettingsPanel(title: "设备历史", icon: "clock.arrow.2.circlepath") {
                switch bluetooth.historyState {
                case .reading(let received, let announced):
                    HStack(spacing: 10) {
                        ProgressView().tint(AppColor.mint)
                        Text(historyProgressText(received: received, announced: announced))
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }
                case .awaitingImport(let measurements):
                    Text(store.appLanguage.format("已读取 %lld 条记录，确认后导入当前成员。", Int64(measurements.count)))
                        .font(.caption)
                        .foregroundStyle(AppColor.ink)
                    Button {
                        bluetooth.importPendingHistory(into: store)
                    } label: {
                        Label("确认导入", systemImage: "square.and.arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                case .imported(let count):
                    Label(
                        store.appLanguage.format("已导入 %lld 条新记录", Int64(count)),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    historyReadButton
                case .clearCommandSent:
                    Label("清除命令已发送；请重新读取设备历史确认结果。", systemImage: "paperplane.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.apricot)
                    historyReadButton
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.apricot)
                    historyReadButton
                case .ready, .unavailable:
                    historyReadButton
                }

                Text(canClearDeviceHistory
                    ? "读取完成前不会保存数据。清除操作只会在二次确认后发送，结果需通过重新读取验证。"
                    : "读取完成前不会保存数据；确认导入后会向设备回执“最近历史已收到”。当前没有经过验证的清空全部历史命令。")
                    .font(.caption2)
                    .foregroundStyle(AppColor.secondary)
                    .lineSpacing(3)

                if canClearDeviceHistory {
                    Button(role: .destructive) {
                        confirmClearHistory = true
                    } label: {
                        Label("清除设备历史", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.rose)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColor.rose.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(bluetooth.settingsState != .ready)
                }
            }
        }
    }

    private var historyReadButton: some View {
        Button {
            bluetooth.readDeviceHistory()
        } label: {
            Label("读取秤内历史", systemImage: "arrow.down.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(bluetooth.settingsState != .ready)
    }

    private func historyProgressText(received: Int, announced: Int?) -> String {
        if let announced {
            return store.appLanguage.format("正在读取：%lld / %lld 条", Int64(received), Int64(announced))
        }
        return store.appLanguage.format("正在读取：已收到 %lld 条", Int64(received))
    }

    private var canReadDeviceHistory: Bool {
        guard let scale else { return false }
        return bluetooth.settingsSnapshot.hasHistoryChannel
            || store.communicationRule(for: scale)?.capabilities.contains(.historyRead) == true
    }

    private var canClearDeviceHistory: Bool {
        guard let scale else { return false }
        return store.communicationRule(for: scale)?.operations?.historyClear?.destructive == true
    }

    @ViewBuilder
    private var protocolPanel: some View {
        if let scale {
            SettingsPanel(title: "settings.communication.title", icon: "point.3.connected.trianglepath.dotted") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.appLanguage.text(.communicationProtocol))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)

                    protocolMenu(for: scale)

                    if let selected = store.communicationRule(for: scale) {
                        Text(selected.origin == .builtIn
                            ? store.appLanguage.text(selected.summary)
                            : selected.summary)
                            .font(.caption2)
                            .foregroundStyle(AppColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .background(AppColor.paleMint.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Text("自动识别模式优先遵循 Bluetooth SIG 标准服务及已知小米通信规范。")
                            .font(.caption2)
                            .foregroundStyle(AppColor.secondary)
                            .lineSpacing(2)
                    }

                    SettingsSeparator()

                    NavigationLink {
                        CommunicationRulesView()
                    } label: {
                        HStack {
                            Label(store.appLanguage.text(.communicationProtocol), systemImage: "books.vertical")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }
                        .foregroundStyle(AppColor.mint)
                    }
                }
            }
        }
    }

    private func protocolMenu(for scale: PairedScale) -> some View {
        let selectedRule = store.communicationRule(for: scale)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showsProtocolMenu.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedRule == nil ? "wand.and.stars" : "checkmark.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 34, height: 34)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    AppLocalizedText(selectedRule?.name ?? "自动识别")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    if let selectedRule {
                        CommunicationRuleTags(rule: selectedRule)
                    } else {
                        AppLocalizedText("推荐")
                            .font(.caption2)
                            .foregroundStyle(AppColor.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.mint)
                    .rotationEffect(.degrees(showsProtocolMenu ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(showsProtocolMenu ? AppColor.mint : AppColor.mint.opacity(0.18), lineWidth: showsProtocolMenu ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: ScaleProtocolMenuAnchorKey.self, value: .bounds) { $0 }
        .accessibilityLabel(store.appLanguage.text(.communicationProtocol))
        .accessibilityValue(store.appLanguage.text(selectedRule?.name ?? "自动识别"))
        .accessibilityHint(store.appLanguage.text(showsProtocolMenu ? "收起选项" : "展开选项"))
    }

    private func protocolDropdown(for scale: PairedScale) -> some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                protocolDropdownRow(
                    title: "自动识别",
                    detail: "推荐",
                    isSelected: scale.communicationRuleID == nil
                ) {
                    selectCommunicationRule(nil)
                }

                SettingsSeparator().padding(.vertical, 3)

                ForEach(CommunicationRuleCatalog.rulesForSelection(custom: store.customCommunicationRules)) { rule in
                    protocolDropdownRow(
                        title: rule.name,
                        rule: rule,
                        isSelected: scale.communicationRuleID == rule.id
                    ) {
                        selectCommunicationRule(rule.id)
                    }
                }
            }
            .padding(6)
        }
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColor.mint.opacity(0.14)))
        .shadow(color: AppColor.ink.opacity(0.12), radius: 16, y: 6)
    }

    private func protocolDropdownRow(
        title: String,
        detail: String? = nil,
        rule: CommunicationRule? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? AppColor.mint : AppColor.secondary.opacity(0.35))
                VStack(alignment: .leading, spacing: 2) {
                    AppLocalizedText(title)
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(AppColor.ink)
                    if let rule {
                        CommunicationRuleTags(rule: rule)
                    } else if let detail {
                        AppLocalizedText(detail)
                            .font(.caption2)
                            .foregroundStyle(AppColor.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .background(
                isSelected ? AppColor.paleMint.opacity(0.72) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(store.appLanguage.text(isSelected ? "已选择" : "未选择"))
    }

    private func selectCommunicationRule(_ ruleID: String?) {
        withAnimation(.easeInOut(duration: 0.18)) {
            showsProtocolMenu = false
        }
        store.setCommunicationRule(ruleID, for: scaleID)
        if !store.isSimulationEnabled {
            bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
        }
    }

    @ViewBuilder
    private var informationPanel: some View {
        if let scale {
            SettingsPanel(title: "设备信息", icon: "info.circle") {
                SettingsValueRow(title: "设备型号", value: scale.modelName)
                Divider()
                SettingsValueRow(
                    title: "兼容性评估",
                    value: store.appLanguage.text(scale.compatibility)
                )
                Divider()
                SettingsValueRow(
                    title: "固件版本",
                    value: bluetooth.settingsSnapshot.firmwareRevision ?? store.appLanguage.text("未读取")
                )
                if let hardware = bluetooth.settingsSnapshot.hardwareRevision {
                    Divider()
                    SettingsValueRow(title: "硬件版本", value: hardware)
                }
                if let serial = bluetooth.settingsSnapshot.serialNumber {
                    Divider()
                    SettingsValueRow(title: "序列号", value: serial)
                }
            }
        }
    }

    private var capturePanel: some View {
        SettingsPanel(title: "数据抓包", icon: "waveform.path.ecg") {
            Toggle(isOn: Binding(
                get: { bluetooth.isDeviceDiagnosticCaptureEnabled },
                set: { isEnabled in
                    if isEnabled, let scale {
                        bluetooth.startDeviceDiagnosticCapture(for: scale)
                    } else {
                        bluetooth.stopDeviceDiagnosticCapture()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("开启实时数据抓包")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    Text("记录原始广播与 ATT 读写明文")
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
                }
            }
            .tint(AppColor.mint)

            Divider()

            HStack {
                Text(store.appLanguage.format("实时捕获 (%lld 条)", Int64(bluetooth.deviceDiagnosticEvents.count)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                Spacer()
                Button(action: beginDiagnosticExport) {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                }
                .buttonStyle(.plain)
                .disabled(bluetooth.deviceDiagnosticEvents.isEmpty)
            }

            if !bluetooth.isDeviceDiagnosticCaptureEnabled, bluetooth.deviceDiagnosticEvents.isEmpty {
                Text("采集未开启。开关开启后使用称重，将记录底层交互数据。")
                    .font(.caption2).foregroundStyle(AppColor.secondary)
            } else if bluetooth.deviceDiagnosticEvents.isEmpty {
                Text("等待广播包或交互事件...")
                    .font(.caption2).foregroundStyle(AppColor.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(bluetooth.deviceDiagnosticEvents.suffix(3))) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                StatusPill(text: event.kind.rawValue, color: diagnosticEventColor(event.kind))
                                Text(shortUUID(event.source))
                                    .font(.system(.caption2, design: .monospaced))
                                Spacer()
                                Text("\(event.elapsedSeconds.formatted(2))s")
                                    .font(.caption2).foregroundStyle(AppColor.secondary)
                            }
                            if let payload = event.payloadHex {
                                Text(payload)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(AppColor.ink)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .textSelection(.enabled)
                            }
                            Text(store.appLanguage.text(event.summary))
                                .font(.caption2).foregroundStyle(AppColor.secondary)
                        }
                        .padding(8)
                        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func beginDiagnosticExport() {
        guard !bluetooth.deviceDiagnosticEvents.isEmpty else { return }
        diagnosticExportTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            diagnosticExportState = .exporting
        }
        diagnosticExportTask = Task {
            await Task.yield()
            let report = await bluetooth.makeDeviceDiagnosticReport()
            guard !Task.isCancelled else { return }
            diagnosticReportDocument = DiagnosticReportDocument(report: report)
            withAnimation(.easeInOut(duration: 0.2)) {
                diagnosticExportState = .ready(report)
            }
        }
    }

    private func saveDiagnosticReport() {
        showsDiagnosticFileExporter = true
    }

    private func dismissDiagnosticExport() {
        diagnosticExportTask?.cancel()
        diagnosticExportTask = nil
        withAnimation(.easeOut(duration: 0.16)) {
            diagnosticExportState = nil
        }
    }

    private var diagnosticReportFilename: String {
        "ScaleMe-DataCapture-\(Int(Date.now.timeIntervalSince1970))"
    }

    private var settingsStatusColor: Color {
        switch bluetooth.settingsState {
        case .ready: AppColor.mint
        case .failed: AppColor.apricot
        default: AppColor.sky
        }
    }

    private func diagnosticEventColor(_ kind: DeviceDiagnosticEvent.Kind) -> Color {
        switch kind {
        case .advertisement: AppColor.apricot
        case .service, .characteristic: AppColor.violet
        case .write: AppColor.sky
        case .acknowledgement, .notification, .received: AppColor.mint
        case .read: AppColor.violet
        case .error: AppColor.rose
        }
    }

    private func shortUUID(_ uuid: String) -> String {
        let normalized = uuid.uppercased()
        if normalized.hasPrefix("0000"), normalized.contains("-0000-1000-") {
            return "0x" + normalized.dropFirst(4).prefix(4)
        }
        if normalized.hasPrefix("0000"), normalized.contains("-0000-3512-") {
            return "0x" + normalized.dropFirst(4).prefix(4)
        }
        return normalized
    }

}

private struct DiagnosticExportOverlay: View {
    let state: DiagnosticExportState
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            VStack(spacing: 18) {
                statusIcon

                VStack(spacing: 8) {
                    AppLocalizedText(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColor.ink)

                    AppLocalizedText(message)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if case .ready(let report) = state {
                    HStack(spacing: 10) {
                        Button(action: onSave) {
                            Label {
                                AppLocalizedText("保存数据")
                            } icon: {
                                Image(systemName: "folder.badge.plus")
                            }
                        }
                        .buttonStyle(DiagnosticExportActionButtonStyle())

                        ShareLink(item: report) {
                            Label {
                                AppLocalizedText("分享")
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .buttonStyle(DiagnosticExportActionButtonStyle(isProminent: true))
                    }

                    Button(action: onDismiss) {
                        AppLocalizedText("完成")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(
                LinearGradient(
                    colors: [AppColor.surface, AppColor.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColor.mint.opacity(0.12))
            )
            .shadow(color: AppColor.ink.opacity(0.16), radius: 28, y: 12)
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .exporting:
            ProgressView()
                .controlSize(.large)
                .tint(AppColor.mint)
                .frame(width: 58, height: 58)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppColor.mint)
                .frame(width: 58, height: 58)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var title: String {
        switch state {
        case .exporting: "正在导出"
        case .ready: "导出完成"
        }
    }

    private var message: String {
        switch state {
        case .exporting: "正在整理抓包数据，请稍候。"
        case .ready: "报告已准备完成，可以保存到文件或通过其他应用分享。"
        }
    }
}

private struct DiagnosticExportActionButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? Color.white : AppColor.mint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(
                isProminent ? AppColor.mint : AppColor.paleMint,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ScaleNameEditor: View, Equatable {
    let scaleID: UUID
    let initialName: String
    let onSave: (String) -> Void

    @State private var name: String
    @State private var isNameFocused = false

    init(scaleID: UUID, initialName: String, onSave: @escaping (String) -> Void) {
        self.scaleID = scaleID
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    static func == (lhs: ScaleNameEditor, rhs: ScaleNameEditor) -> Bool {
        lhs.scaleID == rhs.scaleID && lhs.initialName == rhs.initialName
    }

    var body: some View {
        SettingsPanel(title: "设备重命名", icon: "pencil") {
            HStack(spacing: 10) {
                ResponsiveTextField(
                    text: $name,
                    isFocused: $isNameFocused,
                    placeholder: "设备自定义名称",
                    returnKeyType: .done
                )
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isNameFocused ? AppColor.mint : AppColor.mint.opacity(0.18), lineWidth: isNameFocused ? 1.5 : 1)
                            .allowsHitTesting(false)
                    )

                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canSave ? Color.white : AppColor.secondary)
                        .frame(width: 44, height: 44)
                        .background(
                            canSave ? AppColor.mint : AppColor.paleMint,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(canSave ? Color.clear : AppColor.secondary.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityLabel("保存设备名称")
            }
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != initialName
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        name = trimmed
        isNameFocused = false
        if trimmed != initialName { onSave(trimmed) }
    }
}

private struct CompatibilityRow: View {
    let title, detail, state: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                AppLocalizedText(title).font(.subheadline.weight(.medium))
                AppLocalizedText(detail).font(.caption).foregroundStyle(AppColor.secondary)
            }
            Spacer()
            StatusPill(text: state, color: color)
        }
    }
}
