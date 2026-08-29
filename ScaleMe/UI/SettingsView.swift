import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var cloudSync: ICloudSyncManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "通信协议", icon: "point.3.connected.trianglepath.dotted") {
                    NavigationLink {
                        CommunicationRulesView()
                    } label: {
                        HStack(spacing: 10) {
                            Text("协议库与社区规则")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.ink)
                            Spacer()
                            Text("\(store.communicationRules.count) 条")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(AppColor.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                SettingsPanel(title: "通用", icon: "slider.horizontal.3") {
                    HStack(spacing: 16) {
                        Text("显示单位")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.secondary)
                        Spacer()
                        Picker("", selection: $store.unit) {
                            ForEach(WeightUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(AppColor.ink)
                    }
                }

                SettingsPanel(title: "记录", icon: "list.bullet.clipboard") {
                    Toggle("合并频繁称重记录", isOn: $store.mergeFrequentMeasurements)
                        .tint(AppColor.mint)
                    Divider()
                    SettingsValueRow(title: "小物称重", value: "尚未实现独立记录模式")
                    Text("开启后，同一成员和设备在 30 秒内连续完成的称重只保留后一条。小物称重不会保存为人体测量。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }

                SettingsPanel(title: "iCloud 同步", icon: "icloud") {
                    Toggle("同步应用配置", isOn: $cloudSync.isConfigurationSyncEnabled)
                        .tint(AppColor.mint)

                    if cloudSync.isConfigurationSyncEnabled {
                        Divider()
                        Text("配置策略")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.secondary)
                        Picker("配置策略", selection: $cloudSync.configurationStrategy) {
                            ForEach(ConfigurationSyncStrategy.allCases) { strategy in
                                Text(strategy.title).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)

                        Label(cloudSync.configurationStrategy.detail, systemImage: strategyIcon)
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }

                    Divider()
                    Toggle("同步测量数据", isOn: $cloudSync.isDataSyncEnabled)
                        .tint(AppColor.mint)
                    Text("配置和测量数据可分别控制。推送会将本地配置写入 iCloud；拉取始终以 iCloud 配置替换本机配置。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }

                if cloudSync.isEnabled {
                    SettingsPanel(title: "同步状态", icon: statusIcon) {
                        HStack(spacing: 12) {
                            Image(systemName: statusIcon)
                                .foregroundStyle(statusColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(cloudSync.state.title)
                                    .font(.subheadline.weight(.semibold))
                                if let detail = cloudSync.state.detail {
                                    Text(detail).font(.caption).foregroundStyle(AppColor.secondary)
                                }
                            }
                            Spacer()
                            if cloudSync.state == .syncing {
                                ProgressView().tint(AppColor.mint)
                            }
                        }

                        Button {
                            cloudSync.syncNow()
                        } label: {
                            Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.mint)
                        .disabled(cloudSync.state == .syncing)
                    }
                }

                SettingsPanel(title: "文件与安全", icon: "lock.shield.fill") {
                    SettingsValueRow(title: "iCloud 目录", value: "ScaleMe/")
                    Divider()
                    SettingsValueRow(title: "配置文件", value: AppStorageLayout.configurationFileName)
                    Divider()
                    SettingsValueRow(title: "数据文件", value: AppStorageLayout.measurementsFileName)
                    Divider()
                    Label("测量数据使用 AES-GCM 加密", systemImage: "checkmark.shield.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                }

                if let storageError = store.storageError {
                    SettingsPanel(title: "本地存储", icon: "exclamationmark.triangle.fill") {
                        Text(storageError)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.rose)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var strategyIcon: String {
        cloudSync.configurationStrategy == .push ? "icloud.and.arrow.up" : "icloud.and.arrow.down"
    }

    private var statusIcon: String {
        switch cloudSync.state {
        case .idle: "icloud"
        case .syncing: "icloud.and.arrow.up"
        case .success: "checkmark.icloud.fill"
        case .unavailable, .failed: "exclamationmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        switch cloudSync.state {
        case .success: AppColor.mint
        case .unavailable, .failed: AppColor.apricot
        case .idle, .syncing: AppColor.sky
        }
    }
}
