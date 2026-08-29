import SwiftUI

struct MeasureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @EnvironmentObject private var store: MeasurementStore
    @State private var showSafety = false
    @State private var isPulsing = false

    private var liveMeasurement: BodyMeasurement? { bluetooth.latestMeasurement }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    scaleStage
                    measurementSummary
                    safetyNote
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .navigationTitle("称重")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileSwitcher() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSafety = true } label: { Image(systemName: "info.circle") }
                }
            }
            .onAppear {
                isPulsing = true
                bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
            }
            .onDisappear {
                isPulsing = false
                bluetooth.stopScanning()
            }
            .onChange(of: store.pairedScales) {
                bluetooth.updatePairedScales(store.pairedScales)
                bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
            }
            .alert("安全提醒", isPresented: $showSafety) {
                Button("知道了") {}
            } message: {
                Text("请确保地板、秤面和脚底干燥。孕期、植入心脏起搏器或其他医疗设备时，请勿依赖生物电阻抗体脂结果，并遵循设备厂商及医生建议。")
            }
        }
    }

    private var scaleStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppColor.mint.opacity(0.08), lineWidth: 28)
                    .frame(width: 276, height: 276)
                    .scaleEffect(isPulsing && !reduceMotion ? 1.06 : 0.98)
                    .opacity(isPulsing && !reduceMotion ? 0.28 : 0.6)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)
                Circle()
                    .fill(LinearGradient(colors: [.white, AppColor.paleMint], startPoint: .top, endPoint: .bottom))
                    .frame(width: 230, height: 230)
                    .shadow(color: AppColor.mint.opacity(0.12), radius: 24, y: 10)
                VStack(spacing: 10) {
                    Image(systemName: stageSymbol)
                        .font(.title2).foregroundStyle(AppColor.mint)
                        .contentTransition(.symbolEffect(.replace))
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(liveWeightText)
                            .font(.system(size: 54, weight: .medium, design: .rounded))
                            .contentTransition(.numericText())
                        if bluetooth.liveWeightKG != nil {
                            Text(store.unit.rawValue).font(.headline)
                        }
                    }
                    Text(statusText)
                        .font(.subheadline).foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.center)
                    if let stageLabel {
                        StatusPill(text: stageLabel, color: stageColor)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            Text("轻踩唤醒秤后站稳，观我会自动接收读数")
                .font(.subheadline).foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 430)
    }

    private var liveWeightText: String {
        guard let weightKG = bluetooth.liveWeightKG else { return "— —" }
        return store.unit.value(fromKilograms: weightKG).formatted(1)
    }

    private var statusText: String {
        if store.pairedScales.isEmpty { return "请先在“设备”中添加体重秤" }
        return bluetooth.state.title
    }

    private var stageSymbol: String {
        switch bluetooth.state {
        case .completed: "checkmark.circle.fill"
        case .measuring, .stabilizing: "waveform"
        default: "scalemass"
        }
    }

    private var stageLabel: String? {
        switch bluetooth.state {
        case .measuring: "已感知"
        case .stabilizing: "稳定中"
        case .completed: "已完成"
        default: nil
        }
    }

    private var stageColor: Color {
        switch bluetooth.state {
        case .measuring: AppColor.sky
        case .stabilizing: AppColor.apricot
        default: AppColor.mint
        }
    }

    @ViewBuilder
    private var measurementSummary: some View {
        if let measurement = liveMeasurement {
            SoftCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本次测量").font(.headline)
                            Text(measurement.date, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(AppColor.secondary)
                        }
                        Spacer()
                        StatusPill(text: "最终值")
                    }
                    HStack(spacing: 20) {
                        liveMetric("BMI", measurement.bmi(heightCM: store.selectedProfile.heightCM).formatted(1))
                        liveMetric("体脂率", measurement.bodyFatPercent.map { "\($0.formatted(1))%" } ?? "—")
                        liveMetric("身体水分", measurement.waterPercent.map { "\($0.formatted(1))%" } ?? "—")
                    }
                    Label(measurement.deviceName ?? bluetooth.currentScaleName ?? measurement.source.rawValue, systemImage: "scalemass")
                        .font(.caption).foregroundStyle(AppColor.secondary)
                }
            }
        }
    }

    private func liveMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.headline).foregroundStyle(AppColor.ink)
            Text(title).font(.caption2).foregroundStyle(AppColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var safetyNote: some View {
        VStack(spacing: 8) {
            Label("数据默认保存在本机", systemImage: "lock.shield.fill")
            Text("体脂等身体成分为消费级估算，仅用于观察长期趋势。")
        }
        .font(.caption).foregroundStyle(AppColor.secondary)
        .multilineTextAlignment(.center)
    }
}
