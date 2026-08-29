import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MainPageTitle(text: "设备")
                    addDevice
                    deviceList
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var addDevice: some View {
        NavigationLink {
            DeviceScannerView()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("添加设备").font(.headline).foregroundStyle(AppColor.ink)
                    Text("扫描并关联附近的体重秤或体脂秤")
                        .font(.subheadline).foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(AppColor.secondary)
            }
            .padding(18)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的设备").font(.title3.bold())
                Spacer()
                Text("\(store.pairedScales.count) 台").font(.caption).foregroundStyle(AppColor.secondary)
            }
            if store.pairedScales.isEmpty {
                ContentUnavailableView {
                    VStack(spacing: 8) {
                        Image("ScaleDeviceTabIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                        Text("还没有设备")
                            .font(.title3.weight(.semibold))
                    }
                } description: {
                    Text("添加后，测量页会自动等待这些设备的数据。")
                }
                .frame(maxWidth: .infinity, minHeight: 230)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.pairedScales) { scale in
                        NavigationLink {
                            ScaleSettingsView(scaleID: scale.id)
                        } label: {
                            HStack(spacing: 14) {
                                Image("ScaleDeviceTabIcon")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(14)
                                    .foregroundStyle(AppColor.mint)
                                    .frame(width: 46, height: 46)
                                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scale.name).font(.body.weight(.semibold)).foregroundStyle(AppColor.ink)
                                    Text(scale.modelName).font(.caption).foregroundStyle(AppColor.secondary).lineLimit(1)
                                }
                                Spacer()
                                StatusPill(
                                    text: scale.compatibility == "协议待验证" ? "待验证" : "已关联",
                                    color: scale.compatibility == "协议待验证" ? AppColor.apricot : AppColor.mint
                                )
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        if scale.id != store.pairedScales.last?.id { Divider().padding(.leading, 60) }
                    }
                }
                .padding(.horizontal, 16)
                .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

private struct DeviceScannerView: View {
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsOtherDevices = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    scanArea.frame(minHeight: max(390, geometry.size.height * 0.58))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .pageBackground()
        .navigationTitle("添加设备")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { bluetooth.startScanning() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("重新扫描")
                .help("重新扫描")
            }
        }
        .onAppear { bluetooth.startScanning() }
        .onDisappear { bluetooth.stopScanning() }
    }

    private var scanArea: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(AppColor.mint.opacity(0.12), lineWidth: 18).frame(width: 138, height: 138)
                Circle().stroke(AppColor.mint.opacity(0.25), lineWidth: 2).frame(width: 104, height: 104)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 38)).foregroundStyle(AppColor.mint)
            }
            Text(scanTitle).font(.title3.bold())
            Text("正在搜索附近的低功耗蓝牙设备。部分体重秤只有被踩亮或站上去后才会广播。")
                .font(.subheadline).foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)

            Label {
                Text("符合标准协议的设备和已实现解析的小米体重秤广播会优先显示；其余设备不代表已兼容。")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(AppColor.secondary)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

            if bluetooth.devices.isEmpty {
                if case .unavailable = bluetooth.state {
                    Button { bluetooth.startScanning() } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.mint)
                    .padding(.top, 8)
                } else {
                    ProgressView().tint(AppColor.mint).padding(.top, 12)
                    Text("暂未发现设备，请唤醒体重秤并靠近手机")
                        .font(.caption).foregroundStyle(AppColor.secondary)
                }
            } else {
                discoveryResults
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 24))
    }

    private var scanTitle: String {
        if case .unavailable(let reason) = bluetooth.state { return reason }
        return "正在扫描周围设备"
    }

    private var likelyScaleDevices: [DiscoveredScale] {
        bluetooth.devices.filter { $0.discoveryPriority < 2 }
    }

    private var otherDevices: [DiscoveredScale] {
        bluetooth.devices.filter { $0.discoveryPriority == 2 }
    }

    private var discoveryResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            if likelyScaleDevices.isEmpty {
                Text("暂未识别到体重秤")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text("请先唤醒体重秤；如果设备名称较为普通，可在其他附近设备中查找。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            } else {
                Text("优先查看")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                deviceRows(likelyScaleDevices)
            }

            if !otherDevices.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsOtherDevices.toggle()
                    }
                } label: {
                    HStack {
                        Text("其他附近设备（\(otherDevices.count)）")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: showsOtherDevices ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(AppColor.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(showsOtherDevices ? "已展开" : "已折叠")

                deviceRows(otherDevices)
                    .frame(height: showsOtherDevices ? nil : 0, alignment: .top)
                    .clipped()
                    .opacity(showsOtherDevices ? 1 : 0)
                    .allowsHitTesting(showsOtherDevices)
                    .accessibilityHidden(!showsOtherDevices)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deviceRows(_ devices: [DiscoveredScale]) -> some View {
        VStack(spacing: 0) {
            ForEach(devices) { device in
                discoveredRow(device)
                if device.id != devices.last?.id { Divider().padding(.leading, 52) }
            }
        }
        .padding(.horizontal, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private func discoveredRow(_ device: DiscoveredScale) -> some View {
        let existing = store.pairedScales.contains { $0.id == device.id }
        return Button {
            guard !existing else { return }
            store.addScale(PairedScale(
                id: device.id,
                name: device.name,
                modelName: device.name,
                compatibility: device.compatibility
            ))
            bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image("ScaleDeviceTabIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(10.5)
                    .foregroundStyle(device.isVerifiedCompatible ? AppColor.mint : AppColor.secondary)
                    .frame(width: 38, height: 38)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name).foregroundStyle(AppColor.ink).lineLimit(1)
                    Text(device.compatibility).font(.caption).foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Image(systemName: signalSymbol(for: device.rssi))
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .accessibilityLabel(signalDescription(for: device.rssi))
                Text(existing ? "已添加" : "添加")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(existing ? AppColor.secondary : AppColor.mint)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(existing)
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

}

private struct ScaleSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @Environment(\.dismiss) private var dismiss
    let scaleID: UUID
    @State private var name = ""
    @State private var confirmDelete = false
    @State private var selectedHardwareUnit = XiaomiScaleHardwareUnit.kilograms
    @FocusState private var isNameFocused: Bool

    private var scale: PairedScale? { store.pairedScales.first { $0.id == scaleID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                connectionPanel
                namePanel
                informationPanel
                hardwarePanel
                protocolPanel
                capturePanel
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("删除设备", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.rose)
                Text("删除设备不会删除它过去产生的测量记录。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("设备设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isNameFocused = false }
            }
        }
        .onAppear {
            name = scale?.name ?? ""
            if let scale { bluetooth.inspectSettings(for: scale) }
        }
        .onDisappear { bluetooth.endSettingsInspection() }
        .onChange(of: bluetooth.settingsSnapshot.hardwareUnit) { _, unit in
            if let unit { selectedHardwareUnit = unit }
        }
        .confirmationDialog("确定删除这个设备？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除设备", role: .destructive) {
                store.removeScale(scaleID)
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                dismiss()
            }
        }
    }

    private var connectionPanel: some View {
        SettingsPanel(title: "连接", icon: "dot.radiowaves.left.and.right") {
            HStack(spacing: 14) {
                Image(systemName: settingsStatusIcon)
                    .font(.title3)
                    .foregroundStyle(settingsStatusColor)
                    .frame(width: 44, height: 44)
                    .background(settingsStatusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetooth.settingsState.title).font(.body.weight(.semibold))
                    Text("唤醒体重秤并让手机保持在附近")
                        .font(.caption).foregroundStyle(AppColor.secondary)
                }
                Spacer()
                if bluetooth.settingsState.isBusy { ProgressView().tint(AppColor.mint) }
            }
            Button {
                if let scale { bluetooth.inspectSettings(for: scale) }
            } label: {
                Label("重新检测", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppColor.mint)
            .disabled(bluetooth.settingsState.isBusy)
        }
    }

    private var hardwarePanel: some View {
        SettingsPanel(title: "硬件设置", icon: "slider.horizontal.3") {
            if bluetooth.settingsSnapshot.canConfigureXiaomiUnit {
                HStack(spacing: 16) {
                    Text("秤端显示单位")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                    Spacer()
                    Picker("", selection: $selectedHardwareUnit) {
                        ForEach(XiaomiScaleHardwareUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(AppColor.ink)
                }

                Button {
                    bluetooth.configureHardwareUnit(selectedHardwareUnit)
                } label: {
                    ScaleDeviceLabel(title: "写入体重秤", iconSize: 17)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.mint)
            } else {
                SettingsValueRow(title: "秤端显示单位", value: "未发现可写特征")
            }

            Divider()

            if bluetooth.settingsSnapshot.canSynchronizeTime {
                Button {
                    bluetooth.synchronizeScaleTime()
                } label: {
                    Label("同步当前时间", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.mint)
            } else {
                SettingsValueRow(title: "秤端时间", value: "未发现可写特征")
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

            Text("单位写入仅在检测到小米二代 0x1542 可写特征后开放。ATT 回执和读回内容会记录在下方抓取结果中。")
                .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(3)

            Divider()
            SettingsValueRow(
                title: "历史记录通道",
                value: bluetooth.settingsSnapshot.hasHistoryChannel ? "已发现，暂不导入" : "未发现"
            )
            Divider()
            SettingsValueRow(title: "清空秤内数据", value: "无可信命令，未开放")
        }
    }

    @ViewBuilder
    private var protocolPanel: some View {
        if let scale {
            SettingsPanel(title: "协议匹配", icon: "point.3.connected.trianglepath.dotted") {
                HStack(spacing: 16) {
                    Text("通信规则")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { scale.communicationRuleID },
                        set: { ruleID in
                            store.setCommunicationRule(ruleID, for: scaleID)
                            bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                        }
                    )) {
                        Text("自动识别（推荐）").tag(String?.none)
                        ForEach(store.communicationRules) { rule in
                            Text(rule.name).tag(Optional(rule.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(AppColor.ink)
                }

                if let selected = store.communicationRule(for: scale) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(selected.origin.title, systemImage: selected.origin == .builtIn ? "checkmark.shield.fill" : "person.2.wave.2")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected.origin == .builtIn ? AppColor.mint : AppColor.apricot)
                        Text(selected.summary)
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("自动识别会使用观我已有的标准与已实现解析器。固定规则后，只使用该规则处理此设备的广播或通知。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }

                Divider()
                NavigationLink {
                    CommunicationRulesView()
                } label: {
                    Label("查看与导入通信规则", systemImage: "books.vertical")
                }
                .tint(AppColor.mint)
            }
        }
    }

    @ViewBuilder
    private var informationPanel: some View {
        if let scale {
            SettingsPanel(title: "设备信息", icon: "info.circle") {
                SettingsValueRow(title: "设备型号", value: scale.modelName)
                Divider()
                SettingsValueRow(title: "兼容状态", value: scale.compatibility)
                Divider()
                SettingsValueRow(title: "固件版本", value: bluetooth.settingsSnapshot.firmwareRevision ?? "未读取")
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
        SettingsPanel(title: "设备诊断采集", icon: "waveform.path.ecg") {
            Toggle("开启采集", isOn: Binding(
                get: { bluetooth.isDeviceDiagnosticCaptureEnabled },
                set: { isEnabled in
                    if isEnabled, let scale {
                        bluetooth.startDeviceDiagnosticCapture(for: scale)
                    } else {
                        bluetooth.stopDeviceDiagnosticCapture()
                    }
                }
            ))
            .tint(AppColor.mint)

            Text("开启后请唤醒并使用体重秤。观我会重新检测该设备，并记录原始广播、厂商数据、服务、特征、读写与通知，便于分析尚未支持的协议。数据仅保留在当前内存中。")
                .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(3)

            Divider()

            HStack {
                Text("最近 \(bluetooth.deviceDiagnosticEvents.count) 条")
                    .font(.caption).foregroundStyle(AppColor.secondary)
                Spacer()
                ShareLink(item: bluetooth.deviceDiagnosticReport) {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .disabled(bluetooth.deviceDiagnosticEvents.isEmpty)
            }

            if !bluetooth.isDeviceDiagnosticCaptureEnabled, bluetooth.deviceDiagnosticEvents.isEmpty {
                Text("采集已关闭")
                    .font(.caption).foregroundStyle(AppColor.secondary)
            } else if bluetooth.deviceDiagnosticEvents.isEmpty {
                Text("等待设备广播或返回数据。")
                    .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(3)
            } else {
                ForEach(Array(bluetooth.deviceDiagnosticEvents.suffix(16))) { event in
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            StatusPill(text: event.kind.rawValue, color: diagnosticEventColor(event.kind))
                            Text(shortUUID(event.source))
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text("\(event.elapsedSeconds.formatted(3))s")
                                .font(.caption2).foregroundStyle(AppColor.secondary)
                        }
                        if let payload = event.payloadHex {
                            Text(payload)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppColor.ink)
                                .textSelection(.enabled)
                        }
                        Text(event.summary)
                            .font(.caption).foregroundStyle(AppColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var namePanel: some View {
        SettingsPanel(title: "设备名称", icon: "pencil") {
            TextField("设备名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { isNameFocused = false }
            Button {
                isNameFocused = false
                store.renameScale(scaleID, name: name)
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
            } label: {
                Label("保存名称", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppColor.mint)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
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

private struct CompatibilityRow: View {
    let title, detail, state: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(AppColor.secondary)
            }
            Spacer()
            StatusPill(text: state, color: color)
        }
    }
}
