import SwiftUI

struct MeasureView: View {
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @EnvironmentObject private var store: MeasurementStore
    @State private var showSafety = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    liveScale
                    instructionCard
                    if !bluetooth.devices.isEmpty { nearbyDevices }
                    privacyNote
                }
                .padding(.horizontal, 18).padding(.bottom, 28)
            }
            .pageBackground()
            .navigationTitle("称重")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSafety = true } label: { Image(systemName: "info.circle") }
                }
            }
            .alert("安全提醒", isPresented: $showSafety) {
                Button("知道了") {}
            } message: {
                Text("请确保地板、秤面和脚底干燥。孕期、植入心脏起搏器或其他医疗设备时，请勿依赖生物电阻抗体脂结果，并遵循设备厂商及医生建议。")
            }
        }
    }

    private var liveScale: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(colors: [.white, AppColor.paleMint], startPoint: .top, endPoint: .bottom))
            Circle().stroke(AppColor.mint.opacity(0.12), lineWidth: 24).frame(width: 230)
            Circle().stroke(AppColor.mint.opacity(0.25), lineWidth: 2).frame(width: 175)
            VStack(spacing: 11) {
                Image(systemName: "scalemass.fill").font(.title2).foregroundStyle(AppColor.mint)
                if let kg = bluetooth.liveWeightKG {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(store.unit.value(fromKilograms: kg).formatted(1)).font(.system(size: 52, weight: .medium, design: .rounded))
                        Text(store.unit.rawValue).font(.headline)
                    }
                } else {
                    Text("— —").font(.system(size: 52, weight: .medium, design: .rounded))
                }
                Text(bluetooth.state.title).font(.subheadline).foregroundStyle(AppColor.secondary).multilineTextAlignment(.center)
                Button {
                    switch bluetooth.state {
                    case .scanning: bluetooth.stopScanning()
                    default: bluetooth.startScanning()
                    }
                } label: {
                    Label(buttonTitle, systemImage: bluetooth.state == .scanning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12).background(AppColor.mint, in: Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(height: 370)
    }

    private var buttonTitle: String { bluetooth.state == .scanning ? "停止搜索" : "搜索体重秤" }

    private var instructionCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("获得稳定读数").font(.headline)
                InstructionRow(number: "1", text: "将秤放在坚硬、水平、干燥的地面")
                InstructionRow(number: "2", text: "轻踩唤醒设备，再赤脚站上电极")
                InstructionRow(number: "3", text: "数字闪烁结束前保持身体稳定")
            }
        }
    }

    private var nearbyDevices: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("附近设备").font(.headline)
                ForEach(bluetooth.devices) { device in
                    Button { bluetooth.connect(device) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass").frame(width: 38, height: 38).background(AppColor.paleMint, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(device.name).foregroundStyle(AppColor.ink).lineLimit(1)
                                Text(device.compatibility).font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            Spacer()
                            Image(systemName: device.rssi > -65 ? "wifi" : "wifi.exclamationmark").foregroundStyle(AppColor.mint)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if device.id != bluetooth.devices.last?.id { Divider() }
                }
            }
        }
    }

    private var privacyNote: some View {
        Label("蓝牙数据默认只保存在本机；未连接账户，也不会上传云端。", systemImage: "lock.shield.fill")
            .font(.caption).foregroundStyle(AppColor.secondary).padding(.horizontal, 8)
    }
}

private struct InstructionRow: View {
    let number: String, text: String
    var body: some View {
        HStack(spacing: 12) {
            Text(number).font(.caption.bold()).foregroundStyle(AppColor.ink).frame(width: 27, height: 27).background(AppColor.lime, in: Circle())
            Text(text).font(.subheadline).foregroundStyle(AppColor.secondary)
        }
    }
}
