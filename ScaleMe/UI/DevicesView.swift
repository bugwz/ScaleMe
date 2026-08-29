import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    addDevice
                    deviceList
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .navigationTitle("设备")
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
                ContentUnavailableView(
                    "还没有设备",
                    systemImage: "scalemass",
                    description: Text("添加后，称重页会自动等待这些设备的数据。")
                )
                .frame(maxWidth: .infinity, minHeight: 230)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.pairedScales) { scale in
                        NavigationLink {
                            ScaleSettingsView(scaleID: scale.id)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "scalemass.fill")
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

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    scanArea.frame(minHeight: max(390, geometry.size.height * 0.58))
                    compatibilityArea
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .pageBackground()
        .navigationTitle("添加设备")
        .navigationBarTitleDisplayMode(.inline)
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
            Text("正在扫描周围设备").font(.title3.bold())
            Text("部分秤只有被踩亮或站上去后才会广播。请唤醒秤，并将手机靠近设备。")
                .font(.subheadline).foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)

            if bluetooth.devices.isEmpty {
                ProgressView().tint(AppColor.mint).padding(.top, 12)
                Text("暂未发现设备").font(.caption).foregroundStyle(AppColor.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(bluetooth.devices) { device in
                        discoveredRow(device)
                        if device.id != bluetooth.devices.last?.id { Divider().padding(.leading, 52) }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 24))
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
            bluetooth.updatePairedScales(store.pairedScales)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scalemass").foregroundStyle(AppColor.mint).frame(width: 38, height: 38)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name).foregroundStyle(AppColor.ink).lineLimit(1)
                    Text(device.compatibility).font(.caption).foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Text(existing ? "已添加" : "添加")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(existing ? AppColor.secondary : AppColor.mint)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(existing)
    }

    private var compatibilityArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("兼容性").font(.headline)
            CompatibilityRow(title: "Bluetooth SIG 标准秤", detail: "标准体重与身体成分服务", state: "已实现", color: AppColor.mint)
            CompatibilityRow(title: "小米旧款体重秤 / 体脂秤", detail: "公开 0x181B 广播格式", state: "已实现", color: AppColor.mint)
            CompatibilityRow(title: "其他私有或加密型号", detail: "可以发现，但需协议与实机验证", state: "待验证", color: AppColor.apricot)
            Text("发现设备不代表已经兼容。待验证设备可以保存名称，但在完成协议适配前可能无法读取数据。")
                .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(3)
        }
        .padding(18)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ScaleSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @Environment(\.dismiss) private var dismiss
    let scaleID: UUID
    @State private var name = ""
    @State private var confirmDelete = false

    private var scale: PairedScale? { store.pairedScales.first { $0.id == scaleID } }

    var body: some View {
        Form {
            Section("设备名称") {
                TextField("设备名称", text: $name)
                Button("保存名称") {
                    store.renameScale(scaleID, name: name)
                    bluetooth.updatePairedScales(store.pairedScales)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let scale {
                Section("设备信息") {
                    LabeledContent("设备型号", value: scale.modelName)
                    LabeledContent("兼容状态", value: scale.compatibility)
                }
            }
            Section {
                Button("删除设备", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("删除设备不会删除它过去产生的测量记录。")
            }
        }
        .navigationTitle("设备设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = scale?.name ?? "" }
        .confirmationDialog("确定删除这个设备？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除设备", role: .destructive) {
                store.removeScale(scaleID)
                bluetooth.updatePairedScales(store.pairedScales)
                dismiss()
            }
        }
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
