import SwiftUI

struct MeasureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @EnvironmentObject private var store: MeasurementStore
    @State private var showSafety = false
    @State private var showManualEntry = false
    @State private var isPulsing = false

    private var liveMeasurement: BodyMeasurement? {
        if store.isSimulationEnabled { return store.latest }
        return bluetooth.latestMeasurement.map {
            BodyCompositionEstimator.enriching($0, profile: store.selectedProfile)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    MainPageTitle(text: "测量")
                    scaleStage
                    manualEntryButton
                    measurementSummary
                    safetyNote
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showManualEntry) { ManualEntryView() }
            .onAppear {
                isPulsing = true
                if !store.isSimulationEnabled {
                    bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
                }
            }
            .onDisappear {
                isPulsing = false
                bluetooth.stopScanning()
            }
            .onChange(of: store.pairedScales) {
                guard !store.isSimulationEnabled else { return }
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
            }
            .onChange(of: store.isSimulationEnabled) { _, isEnabled in
                if isEnabled {
                    bluetooth.stopScanning()
                } else {
                    bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
                }
            }
            .alert("安全提醒", isPresented: $showSafety) {
                Button("知道了") {}
            } message: {
                Text("请确保地板、秤面和脚底干燥。孕期、植入心脏起搏器或其他医疗设备时，请勿依赖生物电阻抗体脂结果，并遵循设备厂商及医生建议。")
            }
        }
    }

    private var manualEntryButton: some View {
        Button { showManualEntry = true } label: {
            Label("手动录入测量数据", systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColor.mint.opacity(0.14))
                }
        }
        .disabled(store.isSimulationEnabled)
        .opacity(store.isSimulationEnabled ? 0.5 : 1)
        .accessibilityHint(store.isSimulationEnabled ? "请先关闭模拟数据模式" : "打开手动测量数据输入表单")
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
                    stageIcon
                        .foregroundStyle(AppColor.mint)
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
            Text(store.isSimulationEnabled
                 ? "当前显示最近一条模拟测量，关闭模拟数据后恢复真实设备监听"
                 : "轻踩唤醒体重秤后站稳，观我会自动接收读数")
                .font(.subheadline).foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var liveWeightText: String {
        if store.isSimulationEnabled, let weightKG = store.latest?.weightKG {
            return store.unit.value(fromKilograms: weightKG).formatted(2)
        }
        guard let weightKG = bluetooth.liveWeightKG else { return "— —" }
        return store.unit.value(fromKilograms: weightKG).formatted(2)
    }

    private var statusText: String {
        if store.isSimulationEnabled { return "模拟数据模式" }
        if store.pairedScales.isEmpty { return "请先在“设备”页添加体重秤" }
        return bluetooth.state.title
    }

    @ViewBuilder
    private var stageIcon: some View {
        if store.isSimulationEnabled {
            Image(systemName: "sparkles")
                .font(.title2)
        } else {
            switch bluetooth.state {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
            case .measuring, .stabilizing:
                Image(systemName: "waveform")
                    .font(.title2)
            default:
                Image("ScaleDeviceTabIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
    }

    private var stageLabel: String? {
        if store.isSimulationEnabled { return "模拟" }
        return switch bluetooth.state {
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
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 16) {
                        ForEach(Array(summaryMetrics(for: measurement).enumerated()), id: \.offset) { _, metric in
                            liveMetric(metric.title, metric.value)
                        }
                    }
                    if measurement.hasBodyComposition {
                        Label("身体成分由阻抗与当前成员资料估算", systemImage: "function")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }
                    ScaleDeviceLabel(
                        title: measurement.deviceName ?? bluetooth.currentScaleName ?? measurement.source.rawValue,
                        iconSize: 13
                    )
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

    private func summaryMetrics(for measurement: BodyMeasurement) -> [(title: String, value: String)] {
        var metrics = [
            ("BMI", measurement.bmi(heightCM: store.selectedProfile.heightCM).formatted(2))
        ]
        if let value = measurement.bodyFatPercent {
            metrics.append(("体脂率", "\(value.formatted(2))%"))
        }
        if let value = measurement.fatMassKG {
            metrics.append(("脂肪量", "\(value.formatted(2)) kg"))
        }
        if let value = measurement.muscleMassKG {
            metrics.append(("肌肉量", "\(value.formatted(2)) kg"))
        }
        if let value = measurement.waterPercent {
            metrics.append(("身体水分", "\(value.formatted(2))%"))
        }
        if let value = measurement.visceralFat {
            metrics.append(("内脏脂肪", value.formatted(2)))
        }
        return metrics
    }

    private var safetyNote: some View {
        VStack(spacing: 8) {
            Label("数据默认保存在本机", systemImage: "lock.shield.fill")
            Text("体脂等身体成分为消费级估算，仅用于观察长期趋势。")
            Button("查看安全提醒") { showSafety = true }
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.mint)
        }
        .font(.caption).foregroundStyle(AppColor.secondary)
        .multilineTextAlignment(.center)
    }
}

struct ManualEntryView: View {
    private enum InputField: Hashable {
        case weight
        case impedance
        case bodyFat
        case muscleMass
        case water
        case visceralFat
        case basalMetabolism
        case boneMass
    }

    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var impedance = ""
    @State private var bodyFat = ""
    @State private var muscleMass = ""
    @State private var water = ""
    @State private var visceralFat = ""
    @State private var basalMetabolism = ""
    @State private var boneMass = ""
    @FocusState private var focusedField: InputField?

    private var parsedWeight: Double? {
        guard let value = numericValue(weight), (5...350).contains(value) else { return nil }
        return value
    }

    private var canSave: Bool {
        parsedWeight != nil
            && isValidOptional(impedance, range: 50...2_000)
            && isValidOptional(bodyFat, range: 1...75)
            && isValidOptional(muscleMass, range: 1...200)
            && isValidOptional(water, range: 10...85)
            && isValidOptional(visceralFat, range: 1...60)
            && isValidOptional(basalMetabolism, range: 300...5_000)
            && isValidOptional(boneMass, range: 0.5...10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础测量") {
                    measurementField("体重（kg，必填）", text: $weight, field: .weight)
                    measurementField("阻抗（Ω，可选）", text: $impedance, field: .impedance)
                }

                Section("设备指标（均可选）") {
                    measurementField("体脂率（%）", text: $bodyFat, field: .bodyFat)
                    measurementField("肌肉量（kg）", text: $muscleMass, field: .muscleMass)
                    measurementField("身体水分（%）", text: $water, field: .water)
                    measurementField("内脏脂肪等级", text: $visceralFat, field: .visceralFat)
                    measurementField("基础代谢（kcal）", text: $basalMetabolism, field: .basalMetabolism)
                    measurementField("骨量（kg）", text: $boneMass, field: .boneMass)
                }

                Section("自动计算") {
                    Text("BMI、脂肪量、肌肉占比、水分量、骨量占比和蛋白质等指标会根据测量数据与当前人物资料自动计算，不能手动编辑。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }

                Section {
                    Text("手动记录仅保存在本机，并会明确标记为“手动记录”。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
            }
            .navigationTitle("手动录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
        }
    }

    private func measurementField(
        _ title: String,
        text: Binding<String>,
        field: InputField
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: field)
    }

    private func numericValue(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private func isValidOptional(_ text: String, range: ClosedRange<Double>) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || numericValue(value).map(range.contains) == true
    }

    private func save() {
        guard let weightKG = parsedWeight, canSave else { return }
        focusedField = nil
        store.addManual(
            weightKG: weightKG,
            impedanceOhm: numericValue(impedance),
            bodyFatPercent: numericValue(bodyFat),
            muscleMassKG: numericValue(muscleMass),
            waterPercent: numericValue(water),
            visceralFat: numericValue(visceralFat),
            basalMetabolismKCal: numericValue(basalMetabolism),
            boneMassKG: numericValue(boneMass)
        )
        dismiss()
    }
}
