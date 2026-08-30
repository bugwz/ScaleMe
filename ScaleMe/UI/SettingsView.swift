import CoreTransferable
import SwiftUI

struct DisplaySettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var isWeightUnitDropdownExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preferencesPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("显示设置")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityHidden(isWeightUnitDropdownExpanded)
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, isWeightUnitDropdownExpanded {
                    AppDropdownMenuLayer(
                        anchorFrame: proxy[anchor],
                        availableSize: proxy.size,
                        options: WeightUnit.allCases,
                        selection: store.unit,
                        title: { $0.settingsTitle },
                        appearance: .compact,
                        onSelect: { unit in
                            store.unit = unit
                            dismissWeightUnitDropdown()
                        },
                        onDismiss: dismissWeightUnitDropdown
                    )
                }
            }
        }
        .onDisappear { isWeightUnitDropdownExpanded = false }
    }

    private var preferencesPanel: some View {
        SettingsPanel(title: "显示与记录", icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 10) {
                Text("体重单位")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppDropdownField(
                    value: store.unit.settingsTitle,
                    icon: "scalemass.fill",
                    accessibilityLabel: "体重单位",
                    isExpanded: isWeightUnitDropdownExpanded,
                    appearance: .compact,
                    onToggle: toggleWeightUnitDropdown
                )
            }

            SettingsSeparator()

            SettingsToggleRow(
                title: "合并连续称重",
                detail: "同一成员和设备在 30 秒内连续完成的称重，只保留最新一条。",
                isOn: $store.mergeFrequentMeasurements
            )

            SettingsSeparator()

            SettingsToggleRow(
                title: "启用模拟数据",
                detail: "全界面展示模拟成员、设备和近一年记录；真实资料与测量数据不会被删除或替换。",
                isOn: $store.isSimulationEnabled
            )

            if store.isSimulationEnabled {
                Label("模拟数据不会写入本机档案或同步到 iCloud。", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func toggleWeightUnitDropdown() {
        KeyboardFocus.dismiss()
        withAnimation(.easeInOut(duration: 0.18)) {
            isWeightUnitDropdownExpanded.toggle()
        }
    }

    private func dismissWeightUnitDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isWeightUnitDropdownExpanded = false
        }
    }
}

private extension WeightUnit {
    var settingsTitle: String {
        switch self {
        case .kilograms: "千克（kg）"
        case .jin: "市斤（斤）"
        case .pounds: "磅（lb）"
        }
    }
}

struct DataSyncSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var cloudSync: ICloudSyncManager
    @State private var pendingCloudAction: PendingCloudAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let storageError = store.storageError {
                    storageErrorBanner(storageError)
                }

                cloudPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("数据同步")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $pendingCloudAction) { action in
            Alert(
                title: Text("从 iCloud 拉取配置？"),
                message: Text("iCloud 中的成员、设备、显示单位和通信规则将替换本机配置。测量记录不受影响。"),
                primaryButton: .destructive(Text("拉取并替换")) {
                    cloudSync.configurationStrategy = .pull
                    if action == .enableConfigurationSync {
                        cloudSync.isConfigurationSyncEnabled = true
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var cloudPanel: some View {
        SettingsPanel(title: "iCloud", icon: "icloud") {
            cloudStatusRow

            SettingsSeparator()

            SettingsToggleRow(
                title: "同步应用配置",
                detail: "成员、设备、显示单位和通信规则。",
                isOn: configurationSyncBinding
            )

            if cloudSync.isConfigurationSyncEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("配置同步方向")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.secondary)
                    SettingsChoiceBar(
                        options: ConfigurationSyncStrategy.allCases,
                        selection: configurationStrategyBinding,
                        title: { $0.title }
                    )

                    Label(cloudSync.configurationStrategy.detail, systemImage: strategyIcon)
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                .padding(12)
                .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SettingsSeparator()

            SettingsToggleRow(
                title: "同步测量数据",
                detail: "加密同步称重和身体成分记录，可与配置同步分开关闭。",
                isOn: $cloudSync.isDataSyncEnabled
            )

            if cloudSync.isEnabled {
                Button {
                    cloudSync.syncNow()
                } label: {
                    Label(
                        cloudSync.state == .syncing ? "正在同步" : "立即同步",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(MintActionButtonStyle())
                .disabled(cloudSync.state == .syncing)
                .opacity(cloudSync.state == .syncing ? 0.65 : 1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cloudSync.isConfigurationSyncEnabled)
        .animation(.easeInOut(duration: 0.2), value: cloudSync.isEnabled)
    }

    private var cloudStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(cloudSync.isEnabled ? cloudSync.state.title : "未开启同步")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(cloudStatusDetail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if cloudSync.state == .syncing {
                ProgressView()
                    .tint(AppColor.mint)
            }
        }
    }

    private func storageErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.rose)
            VStack(alignment: .leading, spacing: 4) {
                Text("本地存储异常")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.rose.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var configurationSyncBinding: Binding<Bool> {
        Binding(
            get: { cloudSync.isConfigurationSyncEnabled },
            set: { isEnabled in
                if isEnabled, cloudSync.configurationStrategy == .pull {
                    pendingCloudAction = .enableConfigurationSync
                } else {
                    cloudSync.isConfigurationSyncEnabled = isEnabled
                }
            }
        )
    }

    private var configurationStrategyBinding: Binding<ConfigurationSyncStrategy> {
        Binding(
            get: { cloudSync.configurationStrategy },
            set: { strategy in
                if strategy == .pull {
                    pendingCloudAction = .selectPull
                } else {
                    cloudSync.configurationStrategy = strategy
                }
            }
        )
    }

    private var cloudStatusDetail: String {
        if !cloudSync.isEnabled {
            return "数据默认只保存在本机，按需开启下方项目。"
        }
        return cloudSync.state.detail ?? "配置与测量数据可独立同步。"
    }

    private var strategyIcon: String {
        cloudSync.configurationStrategy == .push ? "icloud.and.arrow.up" : "icloud.and.arrow.down"
    }

    private var statusIcon: String {
        guard cloudSync.isEnabled else { return "icloud.slash" }
        return switch cloudSync.state {
        case .idle: "icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .success: "checkmark.icloud.fill"
        case .unavailable, .failed: "exclamationmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        guard cloudSync.isEnabled else { return AppColor.secondary }
        return switch cloudSync.state {
        case .success: AppColor.mint
        case .unavailable, .failed: AppColor.apricot
        case .idle, .syncing: AppColor.sky
        }
    }

    private enum PendingCloudAction: String, Identifiable {
        case selectPull
        case enableConfigurationSync

        var id: String { rawValue }
    }
}

struct DeveloperDiagnosticsView: View {
    private let inputDiagnostics = InputDiagnosticsRecorder.shared
    @State private var isDiagnosticsEnabled = false
    @State private var displayedEventCount = 0
    @State private var displayedLatestAttempt: InputDiagnosticAttemptSummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                diagnosticsPanel
                if let summary = displayedLatestAttempt {
                    latestAttemptPanel(summary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("开发诊断")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshSnapshot)
    }

    private var diagnosticsPanel: some View {
        SettingsPanel(title: "输入响应记录", icon: "stopwatch.fill") {
            SettingsToggleRow(
                title: "开启开发诊断",
                detail: "记录手动录入输入框和系统键盘的响应时间。每次开启都会开始新的诊断会话。",
                isOn: diagnosticsEnabledBinding
            )

            SettingsSeparator()

            HStack(spacing: 12) {
                Image(systemName: isDiagnosticsEnabled ? "record.circle.fill" : "pause.circle")
                    .font(.title3)
                    .foregroundStyle(isDiagnosticsEnabled ? AppColor.mint : AppColor.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isDiagnosticsEnabled ? "正在记录" : "记录已暂停")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    Text("当前会话 \(displayedEventCount) 个事件")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                ShareLink(
                    item: inputDiagnostics.export,
                    preview: SharePreview("观我输入响应诊断")
                ) {
                    Label("导出 JSON", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MintActionButtonStyle())
                .disabled(displayedEventCount == 0)

                Button {
                    inputDiagnostics.clear()
                    refreshSnapshot()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.rose)
                .background(AppColor.rose.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .disabled(displayedEventCount == 0)
                .accessibilityLabel("清空诊断记录")
            }

            Label(
                "日志不包含输入内容、体重、成员资料或设备标识。",
                systemImage: "hand.raised.fill"
            )
            .font(.caption)
            .foregroundStyle(AppColor.secondary)
        }
    }

    private func latestAttemptPanel(_ summary: InputDiagnosticAttemptSummary) -> some View {
        SettingsPanel(title: "最近一次输入", icon: "timer") {
            SettingsValueRow(title: "字段", value: summary.fieldID)
            SettingsSeparator()
            timingRow("触摸 → 准备编辑", milliseconds: summary.touchToWillBeginEditingMilliseconds)
            SettingsSeparator()
            timingRow("触摸 → 开始编辑", milliseconds: summary.touchToDidBeginEditingMilliseconds)
            SettingsSeparator()
            timingRow("触摸 → 键盘准备显示", milliseconds: summary.touchToKeyboardWillShowMilliseconds)
            SettingsSeparator()
            timingRow("触摸 → 键盘显示完成", milliseconds: summary.touchToKeyboardDidShowMilliseconds)
            SettingsSeparator()
            timingRow("键盘显示过程", milliseconds: summary.keyboardPresentationMilliseconds)
            SettingsSeparator()
            timingRow("触摸 → 首次输入变化", milliseconds: summary.touchToFirstTextChangeMilliseconds)
        }
    }

    private func timingRow(_ title: String, milliseconds: Double?) -> some View {
        SettingsValueRow(
            title: title,
            value: milliseconds.map { "\($0.formatted(.number.precision(.fractionLength(1)))) ms" } ?? "未发生"
        )
    }

    private var diagnosticsEnabledBinding: Binding<Bool> {
        Binding(
            get: { isDiagnosticsEnabled },
            set: { isEnabled in
                inputDiagnostics.isEnabled = isEnabled
                refreshSnapshot()
            }
        )
    }

    private func refreshSnapshot() {
        isDiagnosticsEnabled = inputDiagnostics.isEnabled
        displayedEventCount = inputDiagnostics.eventCount
        displayedLatestAttempt = inputDiagnostics.latestAttemptSummary
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsSwitch(title: title, detail: detail, isOn: $isOn)
    }
}
