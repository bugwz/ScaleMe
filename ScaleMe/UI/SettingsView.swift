import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var cloudSync: ICloudSyncManager

    var body: some View {
        Form {
            Section("通信协议") {
                NavigationLink {
                    CommunicationRulesView()
                } label: {
                    Label("协议库与社区规则", systemImage: "point.3.connected.trianglepath.dotted")
                }
                LabeledContent("可用规则", value: "\(store.communicationRules.count) 条")
            }

            Section("通用") {
                Picker("显示单位", selection: $store.unit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            }

            Section {
                Toggle("合并频繁称重记录", isOn: $store.mergeFrequentMeasurements)
                    .tint(AppColor.mint)
                LabeledContent("小物称重", value: "尚未实现独立记录模式")
            } header: {
                Text("记录")
            } footer: {
                Text("开启后，同一成员和设备在 30 秒内连续完成的称重只保留后一条。小物称重需要独立的数据类型，不会保存为人体测量。")
            }

            Section {
                Toggle("同步应用配置", isOn: $cloudSync.isConfigurationSyncEnabled)
                    .tint(AppColor.mint)

                if cloudSync.isConfigurationSyncEnabled {
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

                Toggle("同步测量数据", isOn: $cloudSync.isDataSyncEnabled)
                    .tint(AppColor.mint)
            } header: {
                Text("iCloud 同步")
            } footer: {
                Text("配置和测量数据可分别控制。推送会在本地配置变更后写入 iCloud；拉取始终以 iCloud 配置替换本机配置。同步在后台异步完成，不会阻塞测量和浏览。")
            }

            if cloudSync.isEnabled {
                Section("同步状态") {
                    HStack(spacing: 12) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(cloudSync.state.title)
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
                    }
                    .disabled(cloudSync.state == .syncing)
                }
            }

            Section("文件与安全") {
                LabeledContent("iCloud 目录", value: "ScaleMe/")
                LabeledContent("配置文件", value: AppStorageLayout.configurationFileName)
                LabeledContent("数据文件", value: AppStorageLayout.measurementsFileName)
                Label("测量数据使用 AES-GCM 加密", systemImage: "lock.shield.fill")
                    .foregroundStyle(AppColor.ink)
            }

            if let storageError = store.storageError {
                Section("本地存储") {
                    Label(storageError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColor.rose)
                }
            }
        }
        .scrollContentBackground(.hidden)
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
