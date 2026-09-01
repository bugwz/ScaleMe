import SwiftUI

private struct MeasureProfileAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct MeasureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @EnvironmentObject private var store: MeasurementStore
    @State private var showSafety = false
    @State private var showManualEntry = false
    @State private var isPulsing = false
    @State private var isMeasurementViewActive = false
    @State private var showProfileDropdown = false

    private var liveMeasurement: BodyMeasurement? {
        if store.isSimulationEnabled { return store.latest }
        return bluetooth.latestMeasurement.map {
            BodyCompositionEstimator.enriching($0, profile: store.displaySelectedProfile)
        }
    }

    private var profileOptions: [TrendDropdownOption<UUID>] {
        store.displayProfiles.map { profile in
            TrendDropdownOption(
                id: profile.id.uuidString,
                value: profile.id,
                title: profile.name,
                subtitle: "\(profile.relation) · \(profile.heightCM.formatted(2)) cm",
                icon: .avatar(profile.avatar)
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        MainPageTitle(text: store.appLanguage.text(.measure))
                        HStack {
                            Spacer()
                            userSwitchButton
                        }
                    }
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
                isMeasurementViewActive = true
                isPulsing = true
                if !store.isSimulationEnabled {
                    bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
                }
            }
            .onDisappear {
                isMeasurementViewActive = false
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
            .onChange(of: store.selectedProfileID) {
                guard isMeasurementViewActive, !store.isSimulationEnabled else { return }
                bluetooth.startMeasurementMonitoring(scales: store.pairedScales)
            }
            .alert("安全提醒", isPresented: $showSafety) {
                Button("知道了") {}
            } message: {
                Text("请确保地板、秤面和脚底干燥。孕期、植入心脏起搏器或其他医疗设备时，请勿依赖生物电阻抗体脂结果，并遵循设备厂商及医生建议。")
            }
        }
        .overlayPreferenceValue(MeasureProfileAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showProfileDropdown, let anchor {
                    let buttonFrame = proxy[anchor]
                    let dropdownWidth: CGFloat = min(300, proxy.size.width - 36)
                    let dropdownX = min(
                        max(buttonFrame.maxX - dropdownWidth, 18),
                        proxy.size.width - dropdownWidth - 18
                    )

                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showProfileDropdown = false
                                }
                            }

                        TrendSingleChoiceDropdown(
                            title: "选择测量成员",
                            options: profileOptions,
                            selection: Binding(
                                get: { store.displaySelectedProfileID },
                                set: { store.selectDisplayProfile($0) }
                            ),
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showProfileDropdown = false
                                }
                            }
                        )
                        .frame(width: dropdownWidth)
                        .offset(x: dropdownX, y: buttonFrame.maxY + 8)
                        .transition(.scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var manualEntryButton: some View {
        Button {
            showManualEntry = true
        } label: {
            Label("手动录入测量数据", systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppColor.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColor.mint.opacity(0.14))
                }
        }
        .accessibilityHint("打开手动测量数据输入表单")
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
                    .fill(LinearGradient(colors: [AppColor.surface, AppColor.paleMint], startPoint: .top, endPoint: .bottom))
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
                    AppLocalizedText(statusText)
                        .font(.subheadline).foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.center)
                    if let stageLabel {
                        StatusPill(text: stageLabel, color: stageColor)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            AppLocalizedText(store.isSimulationEnabled
                ? "当前显示最近一条模拟测量，关闭模拟数据后恢复真实设备监听"
                : "轻踩唤醒体重秤后站稳，观我会自动接收读数")
                .font(.subheadline).foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 330)
    }

    private var userSwitchButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                showProfileDropdown.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(store.displaySelectedProfile.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)

                MemberAvatarView(
                    avatar: store.displaySelectedProfile.avatar,
                    width: 24,
                    height: 24,
                    showsBackdrop: false
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.mint.opacity(0.25), lineWidth: 1))
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 5)
            .background(
                showProfileDropdown ? AppColor.paleMint : AppColor.surface.opacity(0.92),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(AppColor.mint.opacity(showProfileDropdown ? 0.35 : 0.16), lineWidth: 1)
            )
            .shadow(color: AppColor.mint.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .anchorPreference(key: MeasureProfileAnchorKey.self, value: .bounds) { $0 }
        .accessibilityLabel(store.appLanguage.format("切换测量成员，当前为 %@", store.displaySelectedProfile.name))
        .accessibilityHint(store.appLanguage.text("点击选择本次测量数据所属的成员"))
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
        return bluetooth.state.title(in: store.appLanguage)
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
                        title: measurement.deviceName
                            ?? bluetooth.currentScaleName
                            ?? store.appLanguage.text(measurement.source.rawValue),
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
            AppLocalizedText(title).font(.caption2).foregroundStyle(AppColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryMetrics(for measurement: BodyMeasurement) -> [(title: String, value: String)] {
        var metrics = [
            ("BMI", measurement.bmi(heightCM: store.displaySelectedProfile.heightCM).formatted(2))
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

private struct ManualEntryProfileAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct ManualEntryView: View {
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
    @State private var showProfileDropdown = false

    private var profileOptions: [TrendDropdownOption<UUID>] {
        store.displayProfiles.map { profile in
            TrendDropdownOption(
                id: profile.id.uuidString,
                value: profile.id,
                title: profile.name,
                subtitle: "\(profile.relation) · \(profile.heightCM.formatted(2)) cm",
                icon: .avatar(profile.avatar)
            )
        }
    }

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
            ScrollView {
                VStack(spacing: 18) {
                    memberCard
                    basicMeasurementPanel
                    bodyCompositionPanel
                    calculationNoticePanel
                    saveActionButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .pageBackground()
            .navigationTitle("手动录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColor.secondary)
                }
            }
        }
        .overlayPreferenceValue(ManualEntryProfileAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showProfileDropdown, let anchor {
                    let buttonFrame = proxy[anchor]
                    let dropdownWidth = buttonFrame.width
                    let dropdownX = buttonFrame.minX

                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showProfileDropdown = false
                                }
                            }

                        TrendSingleChoiceDropdown(
                            title: "选择记录成员",
                            options: profileOptions,
                            selection: Binding(
                                get: { store.displaySelectedProfileID },
                                set: { store.selectDisplayProfile($0) }
                            ),
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showProfileDropdown = false
                                }
                            }
                        )
                        .frame(width: dropdownWidth)
                        .offset(x: dropdownX, y: buttonFrame.maxY + 6)
                        .transition(.scale(scale: 0.98, anchor: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var memberCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("记录成员")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.ink)

            Button {
                KeyboardFocus.dismiss()
                withAnimation(.easeOut(duration: 0.18)) {
                    showProfileDropdown.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    MemberAvatarView(
                        avatar: store.displaySelectedProfile.avatar,
                        width: 28,
                        height: 28,
                        showsBackdrop: false
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColor.mint.opacity(0.25), lineWidth: 1))

                    Text(store.displaySelectedProfile.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColor.ink)

                    StatusPill(text: store.displaySelectedProfile.relation)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(showProfileDropdown ? AppColor.mint : AppColor.secondary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            showProfileDropdown ? AppColor.mint : AppColor.mint.opacity(0.14),
                            lineWidth: showProfileDropdown ? 1.5 : 1
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .anchorPreference(key: ManualEntryProfileAnchorKey.self, value: .bounds) { $0 }
            .accessibilityLabel(store.appLanguage.format(
                "记录成员，当前为 %@，%@",
                store.displaySelectedProfile.name,
                store.appLanguage.text(store.displaySelectedProfile.relation)
            ))
            .accessibilityHint(store.appLanguage.text("点击展开选择记录成员"))
        }
    }

    private var basicMeasurementPanel: some View {
        SettingsPanel(title: "基础测量", icon: "scalemass.fill") {
            VStack(spacing: 14) {
                manualInputField(
                    title: "体重",
                    unit: "kg",
                    placeholder: "必填，5.00 ~ 350.00",
                    text: $weight,
                    isRequired: true,
                    isValid: isOptionalValid(weight, range: 5...350)
                )

                manualInputField(
                    title: "生物电阻抗",
                    unit: "Ω",
                    placeholder: "可选，50 ~ 2000",
                    text: $impedance,
                    isRequired: false,
                    isValid: isOptionalValid(impedance, range: 50...2_000)
                )
            }
        }
    }

    private var bodyCompositionPanel: some View {
        SettingsPanel(title: "身体成分指标（可选）", icon: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 14) {
                Text("若体重秤或第三方设备显示了具体数据，可在此补充录入：")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    manualGridField(
                        title: "体脂率",
                        unit: "%",
                        placeholder: "1 ~ 75",
                        text: $bodyFat,
                        isValid: isOptionalValid(bodyFat, range: 1...75)
                    )

                    manualGridField(
                        title: "肌肉量",
                        unit: "kg",
                        placeholder: "1 ~ 200",
                        text: $muscleMass,
                        isValid: isOptionalValid(muscleMass, range: 1...200)
                    )

                    manualGridField(
                        title: "身体水分",
                        unit: "%",
                        placeholder: "10 ~ 85",
                        text: $water,
                        isValid: isOptionalValid(water, range: 10...85)
                    )

                    manualGridField(
                        title: "内脏脂肪",
                        unit: "级",
                        placeholder: "1 ~ 60",
                        text: $visceralFat,
                        isValid: isOptionalValid(visceralFat, range: 1...60)
                    )

                    manualGridField(
                        title: "基础代谢",
                        unit: "kcal",
                        placeholder: "300 ~ 5000",
                        text: $basalMetabolism,
                        isValid: isOptionalValid(basalMetabolism, range: 300...5_000)
                    )

                    manualGridField(
                        title: "骨量",
                        unit: "kg",
                        placeholder: "0.5 ~ 10",
                        text: $boneMass,
                        isValid: isOptionalValid(boneMass, range: 0.5...10)
                    )
                }
            }
        }
    }

    private var calculationNoticePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("自动计算与隐私说明", systemImage: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "function")
                        .font(.caption)
                        .foregroundStyle(AppColor.mint)
                    Text(store.appLanguage.format(
                        "BMI、脂肪量、肌肉占比、水分量、骨量占比和蛋白质等指标，将根据测量值与当前成员 %@ 的身体资料自动计算。",
                        store.displaySelectedProfile.name
                    ))
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.mint)
                    AppLocalizedText(store.isSimulationEnabled
                        ? "当前为模拟数据模式，本次记录只保存在内存中，重新打开应用后会消失。"
                        : "手动记录仅保存在本机，并会清晰标记为“手动记录”来源。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.paleMint.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColor.mint.opacity(0.12))
        )
    }

    private var saveActionButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("保存测量数据")
            }
            .font(.headline)
            .foregroundStyle(canSave ? .white : AppColor.secondary.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                canSave ? AppColor.mint : AppColor.secondary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: canSave ? AppColor.mint.opacity(0.24) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func manualInputField(
        title: String,
        unit: String,
        placeholder: String,
        text: Binding<String>,
        isRequired: Bool,
        isValid: Bool
    ) -> some View {
        ManualNumericInputField(
            title: title,
            unit: unit,
            placeholder: placeholder,
            text: text,
            isRequired: isRequired,
            isValid: isValid,
            layout: .regular
        )
    }

    private func manualGridField(
        title: String,
        unit: String,
        placeholder: String,
        text: Binding<String>,
        isValid: Bool
    ) -> some View {
        ManualNumericInputField(
            title: title,
            unit: unit,
            placeholder: placeholder,
            text: text,
            isRequired: false,
            isValid: isValid,
            layout: .grid
        )
    }

    private func numericValue(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private func isOptionalValid(_ text: String, range: ClosedRange<Double>) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || numericValue(value).map(range.contains) == true
    }

    private func isValidOptional(_ text: String, range: ClosedRange<Double>) -> Bool {
        isOptionalValid(text, range: range)
    }

    private func save() {
        guard let weightKG = parsedWeight, canSave else { return }
        KeyboardFocus.dismiss()
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

private struct ManualNumericInputField: View {
    @Environment(\.appLanguage) private var language
    enum Layout {
        case regular
        case grid
    }

    let title: String
    let unit: String
    let placeholder: String
    @Binding var text: String
    let isRequired: Bool
    let isValid: Bool
    let layout: Layout
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: layout == .regular ? 6 : 5) {
            HStack {
                AppLocalizedText(title)
                    .font(layout == .regular ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                if isRequired {
                    Text("*")
                        .font(.caption.bold())
                        .foregroundStyle(AppColor.rose)
                }
                Spacer(minLength: 2)
                Text(unit)
                    .font(layout == .regular ? .caption2.weight(.medium) : .caption2)
                    .foregroundStyle(AppColor.secondary)
            }

            HStack(spacing: layout == .regular ? 8 : 4) {
                ResponsiveTextField(
                    text: $text,
                    isFocused: $isFocused,
                    placeholder: placeholder,
                    keyboardType: .decimalPad,
                    returnKeyType: .done,
                    textStyle: layout == .regular ? .body : .subheadline,
                    fontWeight: .medium,
                    autocapitalizationType: .none,
                    autocorrectionType: .no,
                    spellCheckingType: .no,
                    textContentType: .none,
                    smartDashesType: .no,
                    smartQuotesType: .no,
                    smartInsertDeleteType: .no,
                    synchronizesFocusFromBinding: false,
                    showsDoneAccessory: true
                )
                .frame(minHeight: layout == .regular ? 24 : 21)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(layout == .regular ? .caption : .caption2)
                            .foregroundStyle(AppColor.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.format("清除%@", language.text(title)))
                }

            }
            .padding(.horizontal, layout == .regular ? 14 : 10)
            .padding(.vertical, layout == .regular ? 11 : 9)
            .background(
                AppColor.surface,
                in: RoundedRectangle(cornerRadius: layout == .regular ? 12 : 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: layout == .regular ? 12 : 10, style: .continuous)
                    .stroke(
                        !isValid ? AppColor.rose : (isFocused ? AppColor.mint : AppColor.mint.opacity(0.14)),
                        lineWidth: isFocused || !isValid ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}
