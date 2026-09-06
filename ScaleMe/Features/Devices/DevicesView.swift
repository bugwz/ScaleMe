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

private struct ScaleUnitMenuAnchorKey: PreferenceKey {
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

    var isUnnamed: Bool {
        name.hasPrefix("未命名设备 ")
    }

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
                    AppLocalizedText(addDeviceDescription)
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
        .disabled(store.isUsingPlaceholderData)
        .opacity(store.isUsingPlaceholderData ? 0.55 : 1)
    }

    private var addDeviceDescription: String {
        if store.isUsingPlaceholderData { return "请先添加成员，再添加设备" }
        return store.isSimulationEnabled
            ? "演示扫描并关联预设模拟设备"
            : "扫描并关联附近的体重秤或体脂秤"
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
                    color: AppColor.secondary,
                    backgroundColor: AppColor.surface
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
            ScaleDeviceIconView(size: 52, iconSize: 24, accent: AppColor.mint)

            VStack(spacing: 6) {
                Text("还没有绑定设备")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppLocalizedText(store.isUsingPlaceholderData
                    ? "请先添加成员，再添加设备"
                    : "添加设备后，测量页会自动接收并关联这些设备上报的健康数据。")
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
        let hasMatchedProtocol = store.effectiveCommunicationRule(for: scale) != nil
        let accentColor = hasMatchedProtocol ? AppColor.mint : AppColor.apricot

        return HStack(spacing: 14) {
            ScaleDeviceIconView(size: 40, iconSize: 19, accent: accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(scale.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(scale.modelName)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(
                text: hasMatchedProtocol ? "已匹配" : "未匹配",
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
    @State private var isScanRunning = false
    @State private var simulatedDevices: [ScannerDevice] = []
    @State private var scanTask: Task<Void, Never>?

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
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("添加设备")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .onAppear {
            startScan()
        }
        .onDisappear {
            scanTask?.cancel()
            if !store.isSimulationEnabled {
                bluetooth.stopScanning()
            }
        }
    }

    private var scanArea: some View {
        VStack(spacing: 24) {
            scanStage

            if !scannerDevices.isEmpty {
                discoveryResults
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var scanStage: some View {
        VStack(spacing: 18) {
            ZStack {
                PulsingRing(diameter: 250, lineWidth: 28, isActive: isScanRunning)

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

                Button(action: startScan) {
                    ScaleDeviceIconView(size: 78, iconSize: 36, accent: scanStageColor)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .accessibilityLabel("重新扫描")
                .disabled(store.isUsingPlaceholderData)
            }
            .frame(maxWidth: .infinity)

            Text(scanDescription)
                .font(.subheadline)
                .foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var scanStageColor: Color {
        if !store.isSimulationEnabled, case .unavailable = bluetooth.state {
            return AppColor.apricot
        }
        return isScanRunning ? AppColor.sky : AppColor.mint
    }

    private var scanDescription: String {
        if !store.isSimulationEnabled, case .unavailable(let reason) = bluetooth.state {
            return store.appLanguage.text(reason)
        }
        if isScanRunning {
            return store.appLanguage.text(store.isSimulationEnabled ? "正在扫描模拟设备…" : "正在扫描附近的设备…")
        }
        return store.appLanguage.format("扫描完成，发现 %lld 台设备。", Int64(scannerDevices.count))
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
        let nearbyDevices = scannerDevices.filter { $0.discoveryPriority == 2 }
        return nearbyDevices.filter { !$0.isUnnamed } + nearbyDevices.filter(\.isUnnamed)
    }

    private var discoveryResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsPanel(title: "推荐识别", icon: "checkmark.seal.fill") {
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
                    deviceRows(likelyScaleDevices)
                }
            }

            if !otherDevices.isEmpty {
                SoftCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            showsOtherDevices.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.mint)
                                    .frame(width: 26, height: 26)
                                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                Text(store.appLanguage.format("其他附近蓝牙设备（%lld）", Int64(otherDevices.count)))
                                    .font(.headline)
                                    .foregroundStyle(AppColor.ink)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppColor.secondary)
                                    .rotationEffect(.degrees(showsOtherDevices ? 180 : 0))
                                    .animation(.easeInOut(duration: 0.18), value: showsOtherDevices)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if showsOtherDevices {
                            deviceRows(otherDevices)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deviceRows(_ devices: [ScannerDevice]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(devices) { device in
                discoveredRow(device)
                if device.id != devices.last?.id {
                    SettingsSeparator()
                }
            }
        }
    }

    private func discoveredRow(_ device: ScannerDevice) -> some View {
        let existing = store.displayPairedScales.contains { $0.id == device.id }
        let accent = device.isVerifiedCompatible ? AppColor.mint : AppColor.sky

        return HStack(spacing: 12) {
            ScaleDeviceIconView(size: 44, iconSize: 20, accent: accent)

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
                guard !existing, !store.isUsingPlaceholderData else { return }
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
            .disabled(existing || store.isUsingPlaceholderData)
        }
        .padding(.vertical, 8)
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
        guard !store.isUsingPlaceholderData else {
            scanTask?.cancel()
            bluetooth.stopScanning()
            isScanRunning = false
            return
        }
        scanTask?.cancel()
        showsOtherDevices = false
        isScanRunning = true
        let isSimulation = store.isSimulationEnabled

        if isSimulation {
            simulatedDevices = []
        } else {
            bluetooth.startScanning()
        }

        scanTask = Task { @MainActor in
            if isSimulation {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                simulatedDevices = simulatedCandidates
                try? await Task.sleep(for: .milliseconds(5_100))
            } else {
                try? await Task.sleep(for: .seconds(6))
            }
            guard !Task.isCancelled else { return }
            if !isSimulation {
                bluetooth.stopScanning()
            }
            isScanRunning = false
        }
    }
}

private struct ScaleSettingsView: View {
    private enum SettingsOperationMessagePlacement {
        case hardwareUnit
        case currentTime
    }

    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @Environment(\.dismiss) private var dismiss
    let scaleID: UUID
    @State private var confirmDelete = false
    @State private var confirmClearHistory = false
    @State private var selectedHardwareUnit = XiaomiScaleHardwareUnit.kilograms
    @State private var showsHardwareUnitMenu = false
    @State private var showsProtocolMenu = false
    @State private var diagnosticExportState: DiagnosticExportState?
    @State private var diagnosticReportDocument = DiagnosticReportDocument()
    @State private var showsDiagnosticFileExporter = false
    @State private var diagnosticExportTask: Task<Void, Never>?
    @State private var nameDraft = ""
    @State private var isEditingName = false
    @State private var isNameFocused = false
    @State private var settingsOperationMessagePlacement: SettingsOperationMessagePlacement?

    private var scale: PairedScale? { store.displayPairedScales.first { $0.id == scaleID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                deviceSummaryCard
                informationPanel
                deviceOperationsPanel
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
        .overlayPreferenceValue(ScaleUnitMenuAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showsHardwareUnitMenu, let anchor {
                    AppDropdownMenuLayer(
                        anchorFrame: proxy[anchor],
                        availableSize: proxy.size,
                        options: XiaomiScaleHardwareUnit.allCases,
                        isSelected: { $0 == selectedHardwareUnit },
                        title: { $0.title },
                        appearance: .compact,
                        onSelect: {
                            selectedHardwareUnit = $0
                            showsHardwareUnitMenu = false
                        },
                        onDismiss: { showsHardwareUnitMenu = false }
                    )
                }
            }
        }
        .pageBackground()
        .navigationTitle("设备管理")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .onAppear {
            nameDraft = scale?.name ?? ""
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
                ScaleDeviceIconView(size: 52, iconSize: 24, accent: settingsStatusColor)

                VStack(alignment: .leading, spacing: 4) {
                    if isEditingName {
                        ResponsiveTextField(
                            text: $nameDraft,
                            isFocused: $isNameFocused,
                            placeholder: "设备自定义名称",
                            returnKeyType: .done,
                            textStyle: .headline,
                            fontWeight: .semibold
                        )
                        .frame(minHeight: 34)
                        .padding(.horizontal, 10)
                        .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColor.mint, lineWidth: 1.5)
                                .allowsHitTesting(false)
                        )
                    } else {
                        AppLocalizedText(scale?.name ?? "蓝牙秤")
                            .font(.headline)
                            .foregroundStyle(AppColor.ink)
                            .lineLimit(2)
                    }
                    Text(scale?.modelName ?? "")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: toggleNameEditing) {
                    Image(systemName: isEditingName ? "checkmark" : "pencil")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isNameConfirmationEnabled ? AppColor.mint : AppColor.secondary)
                        .frame(width: 36, height: 36)
                        .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isNameConfirmationEnabled)
                .accessibilityLabel(store.appLanguage.text(isEditingName ? "保存设备名称" : "设备重命名"))
            }

            SettingsSeparator()

            HStack(spacing: 10) {
                Text("连接状态")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                StatusPill(
                    text: store.appLanguage.text(settingsConnectionStatusText),
                    color: settingsStatusColor
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                Spacer(minLength: 8)
                Button {
                    if let scale { bluetooth.reconnectSettings(for: scale) }
                } label: {
                    HStack(spacing: 6) {
                        if bluetooth.settingsState.isBusy {
                            ProgressView()
                                .tint(AppColor.mint)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColor.mint)
                        }

                        AppLocalizedText("刷新")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.mint)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(bluetooth.settingsState.isBusy || scale == nil)
                .accessibilityLabel(store.appLanguage.text("刷新"))
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

    private var isNameConfirmationEnabled: Bool {
        scale != nil && (!isEditingName || !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func toggleNameEditing() {
        guard isEditingName else {
            nameDraft = scale?.name ?? ""
            isEditingName = true
            isNameFocused = true
            return
        }

        let trimmedName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        nameDraft = trimmedName
        isNameFocused = false
        isEditingName = false
        if trimmedName != scale?.name {
            store.renameScale(scaleID, name: trimmedName)
            if !store.isSimulationEnabled {
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
            }
        }
    }

    private var deviceOperationsPanel: some View {
        SettingsPanel(title: "设备操作", icon: "slider.horizontal.3") {
            if bluetooth.settingsSnapshot.canConfigureXiaomiUnit {
                VStack(alignment: .leading, spacing: 10) {
                    Text("设备显示单位")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)

                    AppDropdownField(
                        value: selectedHardwareUnit.title,
                        icon: "scalemass",
                        accessibilityLabel: "设备显示单位",
                        isExpanded: showsHardwareUnitMenu,
                        appearance: .compact,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showsHardwareUnitMenu.toggle()
                            }
                        }
                    )
                    .anchorPreference(key: ScaleUnitMenuAnchorKey.self, value: .bounds) { $0 }
                    .disabled(bluetooth.settingsState != .ready)

                    Button {
                        settingsOperationMessagePlacement = .hardwareUnit
                        bluetooth.configureHardwareUnit(selectedHardwareUnit)
                    } label: {
                        AppLocalizedText("设置")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.mint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(bluetooth.settingsState != .ready)

                    settingsOperationMessage(for: .hardwareUnit)
                }
            } else {
                SettingsValueRow(title: "设备显示单位", value: "未发现可写特征")
            }

            Divider()

            if bluetooth.settingsSnapshot.canSynchronizeTime {
                VStack(alignment: .leading, spacing: 10) {
                    AppLocalizedText("更新设备时间")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    Button {
                        settingsOperationMessagePlacement = .currentTime
                        bluetooth.synchronizeScaleTime()
                    } label: {
                        AppLocalizedText("更新")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(bluetooth.settingsState != .ready)

                    settingsOperationMessage(for: .currentTime)
                }
            } else {
                SettingsValueRow(title: "秤端时间同步", value: "未发现可写特征")
            }

            if canReadDeviceHistory {
                Divider()
                AppLocalizedText("拉取设备历史数据")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)

                SettingsSwitch(
                    title: "自动拉取历史数据",
                    detail: "设备连接后自动读取并合并秤端历史记录。",
                    isOn: Binding(
                        get: { scale?.isAutomaticHistoryImportEnabled == true },
                        set: { isEnabled in
                            store.setAutomaticHistoryImportEnabled(isEnabled, for: scaleID)
                            if !store.isSimulationEnabled {
                                bluetooth.updatePairedScales(
                                    store.pairedScales,
                                    communicationRules: store.communicationRules
                                )
                            }
                        }
                    )
                )

                historyActionButton

                switch bluetooth.historyState {
                case .reading(let received, let announced):
                    HStack(spacing: 10) {
                        ProgressView().tint(AppColor.mint)
                        Text(historyProgressText(received: received, announced: announced))
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }
                case .empty:
                    Label("设备中没有待同步的历史记录", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                case .awaitingImport(let measurements):
                    Text(store.appLanguage.format("已读取 %lld 条记录，确认后将根据参考体重与已有趋势自动匹配成员。", Int64(measurements.count)))
                        .font(.caption)
                        .foregroundStyle(AppColor.ink)
                case .imported(let summary):
                    Label(
                        store.appLanguage.format(
                            "已新增 %lld 条，跳过 %lld 条重复记录，%lld 条无法可靠识别",
                            Int64(summary.importedCount),
                            Int64(summary.duplicateCount),
                            Int64(summary.unmatchedCount)
                        ),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                case .clearCommandSent:
                    Label("清除命令已发送；请重新读取设备历史确认结果。", systemImage: "paperplane.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.apricot)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.apricot)
                case .ready, .unavailable:
                    EmptyView()
                }

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

    @ViewBuilder
    private func settingsOperationMessage(for placement: SettingsOperationMessagePlacement) -> some View {
        if settingsOperationMessagePlacement == placement,
           let message = bluetooth.settingsOperationMessage {
            Label(
                message,
                systemImage: bluetooth.settingsOperationSucceeded ? "checkmark.circle.fill" : "info.circle"
            )
            .font(.caption)
            .foregroundStyle(bluetooth.settingsOperationSucceeded ? AppColor.mint : AppColor.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var historyActionButton: some View {
        Button {
            if case .awaitingImport = bluetooth.historyState {
                bluetooth.importPendingHistory(into: store)
            } else {
                bluetooth.readDeviceHistory()
            }
        } label: {
            AppLocalizedText(historyActionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(historyActionForegroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(historyActionBackgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(bluetooth.settingsState != .ready || isReadingDeviceHistory)
    }

    private var historyActionTitle: String {
        switch bluetooth.historyState {
        case .reading: "拉取中"
        case .awaitingImport: "导入本应用"
        default: "拉取"
        }
    }

    private var historyActionForegroundColor: Color {
        if case .awaitingImport = bluetooth.historyState { return .white }
        return AppColor.mint
    }

    private var historyActionBackgroundColor: Color {
        if case .awaitingImport = bluetooth.historyState { return AppColor.mint }
        return AppColor.paleMint
    }

    private var isReadingDeviceHistory: Bool {
        if case .reading = bluetooth.historyState { return true }
        return false
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
            || store.effectiveCommunicationRule(for: scale)?.capabilities.contains(.historyRead) == true
    }

    private var canClearDeviceHistory: Bool {
        guard let scale else { return false }
        return store.effectiveCommunicationRule(for: scale)?.operations?.historyClear?.destructive == true
    }

    @ViewBuilder
    private var protocolPanel: some View {
        if let scale {
            SettingsPanel(title: "通信设置", icon: "point.3.connected.trianglepath.dotted") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.appLanguage.text(.communicationProtocol))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)

                    protocolMenu(for: scale)

                    Text(store.appLanguage.format(
                        "当前匹配协议：%@",
                        store.effectiveCommunicationRule(for: scale)?.name ?? store.appLanguage.text("自动识别")
                    ))
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)

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
        case .idle: AppColor.secondary
        case .locating, .connecting, .discovering: AppColor.sky
        }
    }

    private var settingsConnectionStatusText: String {
        switch bluetooth.settingsState {
        case .idle, .failed: "未连接"
        case .locating, .connecting, .discovering: "连接中"
        case .ready: "已连接"
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
