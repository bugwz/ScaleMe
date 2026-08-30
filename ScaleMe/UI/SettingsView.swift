import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var cloudSync: ICloudSyncManager
    @State private var pendingCloudAction: PendingCloudAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let storageError = store.storageError {
                    storageErrorBanner(storageError)
                }

                preferencesPanel
                cloudPanel
                dataAndPrivacyLink
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("偏好与同步")
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

    private var preferencesPanel: some View {
        SettingsPanel(title: "显示与记录", icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 10) {
                Text("体重单位")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Picker("体重单位", selection: $store.unit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            SettingsToggleRow(
                title: "合并连续称重",
                detail: "同一成员和设备在 30 秒内连续完成的称重，只保留最新一条。",
                isOn: $store.mergeFrequentMeasurements
            )

            Divider()

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

    private var cloudPanel: some View {
        SettingsPanel(title: "iCloud", icon: "icloud") {
            cloudStatusRow

            Divider()

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
                    Picker("配置同步方向", selection: configurationStrategyBinding) {
                        ForEach(ConfigurationSyncStrategy.allCases) { strategy in
                            Text(strategy.title).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)

                    Label(cloudSync.configurationStrategy.detail, systemImage: strategyIcon)
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                .padding(12)
                .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

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
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.mint)
                .disabled(cloudSync.state == .syncing)
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

    private var dataAndPrivacyLink: some View {
        NavigationLink {
            DataAndPrivacySettingsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据与隐私")
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                    Text("了解本地存储、加密和文件位置")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.secondary)
            }
            .padding(18)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColor.mint.opacity(0.08)))
        }
        .buttonStyle(.plain)
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

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppColor.mint)
    }
}

private struct DataAndPrivacySettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "隐私保护", icon: "hand.raised.fill") {
                    privacyRow(
                        icon: "iphone",
                        title: "本地优先",
                        detail: "不开启 iCloud 同步时，成员资料和测量数据只保存在本机。"
                    )
                    Divider()
                    privacyRow(
                        icon: "checkmark.shield.fill",
                        title: "测量数据已加密",
                        detail: "测量文件使用 AES-GCM 认证加密，密钥单独保存在钥匙串中。"
                    )
                    Divider()
                    privacyRow(
                        icon: "heart.text.square",
                        title: "仅作趋势参考",
                        detail: "身体成分结果会受水分、进食和接触状态影响，不构成医疗诊断。"
                    )
                }

                SettingsPanel(title: "存储位置", icon: "folder.fill") {
                    SettingsValueRow(title: "目录", value: "ScaleMe/")
                    Divider()
                    SettingsValueRow(title: "应用配置", value: AppStorageLayout.configurationFileName)
                    Divider()
                    SettingsValueRow(title: "测量数据", value: AppStorageLayout.measurementsFileName)
                    Text("开启相应同步项目后，同名文件会存放在观我的 iCloud 容器中。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("数据与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.mint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
