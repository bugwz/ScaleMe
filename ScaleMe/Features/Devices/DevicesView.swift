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

struct DevicesView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MainPageTitle(text: store.appLanguage.text(.devices))
                    addDeviceCard
                    deviceSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
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
            .background(Color.white.opacity(0.94))
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
                    text: store.appLanguage.format("%lld 台", store.displayPairedScales.count),
                    color: AppColor.sky
                )
            }

            if store.displayPairedScales.isEmpty {
                emptyDevicesCard
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.displayPairedScales.enumerated()), id: \.element.id) { index, scale in
                        singleDeviceRow(for: scale)
                        if index < store.displayPairedScales.count - 1 {
                            SettingsSeparator().padding(.leading, 68)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
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
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
    }

    private func singleDeviceRow(for scale: PairedScale) -> some View {
        let isUnverified = scale.compatibility == "协议待验证"
        let accentColor = isUnverified ? AppColor.apricot : AppColor.mint

        return NavigationLink {
            ScaleSettingsView(scaleID: scale.id)
        } label: {
            HStack(spacing: 14) {
                ScaleAvatarIconView(size: 40, iconSize: 19, accent: accentColor)

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
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                            colors: [.white, AppColor.paleMint],
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
            ? "关联后的模拟设备只保存在应用内存中，重新打开应用后会恢复初始模拟设备。"
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                scaleHeroCard
                connectionPanel
                namePanel
                informationPanel
                hardwarePanel
                historyPanel
                protocolPanel
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
        .navigationTitle("设备设置")
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
        store.removeScale(scaleID)
        if !store.isSimulationEnabled {
            bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
        }
        dismiss()
    }

    private var scaleHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            settingsStatusColor.opacity(0.12),
                            AppColor.sky.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 16) {
                ScaleAvatarIconView(size: 68, iconSize: 32, accent: settingsStatusColor)

                VStack(alignment: .leading, spacing: 6) {
                    AppLocalizedText(scale?.name ?? "蓝牙秤")
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.ink)
                    Text(scale?.modelName ?? "")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)

                    StatusPill(
                        text: bluetooth.settingsState.title(in: store.appLanguage),
                        color: settingsStatusColor
                    )
                }
                Spacer()
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(settingsStatusColor.opacity(0.12)))
        .shadow(color: settingsStatusColor.opacity(0.08), radius: 14, y: 6)
    }

    private var connectionPanel: some View {
        SettingsPanel(title: "连接状态", icon: "dot.radiowaves.left.and.right") {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetooth.settingsState.title(in: store.appLanguage))
                        .font(.body.weight(.bold))
                        .foregroundStyle(AppColor.ink)
                    Text("请踩亮或唤醒体重秤，并保持手机处于蓝牙接收范围内。")
                        .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(2)
                }
                Spacer()
                if bluetooth.settingsState.isBusy {
                    ProgressView().tint(AppColor.mint)
                }
            }

            Button {
                if let scale { bluetooth.inspectSettings(for: scale) }
            } label: {
                Label("重新连接检测", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(bluetooth.settingsState.isBusy)
        }
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
                    Text("绑定通信规则")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)

                    protocolMenu(for: scale)

                    if let selected = store.communicationRule(for: scale) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                AppLocalizedText(selected.origin.title)
                            } icon: {
                                Image(systemName: selected.origin == .builtIn ? "checkmark.shield.fill" : "person.2.wave.2")
                            }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selected.origin == .builtIn ? AppColor.mint : AppColor.apricot)
                            Text(selected.origin == .builtIn
                                ? store.appLanguage.text(selected.summary)
                                : selected.summary)
                                .font(.caption2)
                                .foregroundStyle(AppColor.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
                            Label("通信规则库", systemImage: "books.vertical")
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
                    AppLocalizedText(selectedRule?.origin.title ?? "推荐")
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
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
        .accessibilityLabel("通信规则")
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

                ForEach(store.communicationRules) { rule in
                    protocolDropdownRow(
                        title: rule.name,
                        detail: rule.origin.title,
                        isSelected: scale.communicationRuleID == rule.id
                    ) {
                        selectCommunicationRule(rule.id)
                    }
                }
            }
            .padding(6)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColor.mint.opacity(0.14)))
        .shadow(color: AppColor.ink.opacity(0.12), radius: 16, y: 6)
    }

    private func protocolDropdownRow(
        title: String,
        detail: String,
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
                    AppLocalizedText(detail)
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
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
            SettingsPanel(title: "设备详细参数", icon: "info.circle") {
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
                    Label("导出诊断报告", systemImage: "square.and.arrow.up")
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
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private var settingsStatusIcon: String {
        switch bluetooth.settingsState {
        case .ready: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "dot.radiowaves.left.and.right"
        }
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
                    colors: [.white, AppColor.canvas],
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
                    returnKeyType: .done,
                    onSubmit: save
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
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
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
