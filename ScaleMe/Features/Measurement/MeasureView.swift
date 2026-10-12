import SwiftUI

private struct MeasureProfileAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct MeasureScaleAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct MeasureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var bluetooth: BluetoothScaleCoordinator
    @EnvironmentObject private var store: MeasurementStore
    @State private var showManualEntry = false
    @State private var isPulsing = false
    @State private var isMeasurementViewActive = false
    @State private var showProfileDropdown = false
    @State private var showScaleDropdown = false
    @State private var selectedScaleID: UUID?
    @State private var simulationState: BluetoothScaleState = .completed
    @State private var simulatedWeightKG: Double?
    @State private var simulationMeasurementTask: Task<Void, Never>?
    @State private var detailMeasurement: BodyMeasurement?
    let scrollToTopRequest: Int

    private var liveMeasurement: BodyMeasurement? {
        if store.isSimulationEnabled {
            guard simulationState == .completed else { return nil }
            return store.latest
        }
        guard isMeasurementViewActive, !store.isUsingPlaceholderData,
              bluetooth.state == .completed else { return nil }
        return bluetooth.latestMeasurement
    }

    private var profileOptions: [TrendDropdownOption<UUID>] {
        store.managedProfiles.map { profile in
            TrendDropdownOption(
                id: profile.id.uuidString,
                value: profile.id,
                title: profile.name,
                subtitle: "\(store.appLanguage.text(profile.role)) · \(profile.heightCM.formatted(2)) cm",
                icon: .avatar(profile.avatar)
            )
        }
    }

    private var scaleOptions: [TrendDropdownOption<UUID?>] {
        store.displayPairedScales.map { scale in
            TrendDropdownOption(
                id: scale.id.uuidString,
                value: Optional(scale.id),
                title: scale.name,
                subtitle: scale.modelName,
                icon: .asset("ScaleDeviceTabIcon")
            )
        }
    }

    private var selectedScaleName: String {
        guard let selectedScaleID,
              let scale = store.displayPairedScales.first(where: { $0.id == selectedScaleID }) else {
            return store.appLanguage.text("请先在“设备”页添加体重秤")
        }
        return scale.name
    }

    var body: some View {
        NavigationStack {
            RootPageScrollView(scrollToTopRequest: scrollToTopRequest) {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        MainPageTitle(text: store.appLanguage.text(.measure))
                        HStack(spacing: 8) {
                            scaleSwitchButton
                            Spacer(minLength: 8)
                            userSwitchButton
                        }
                    }
                    if !store.isSimulationEnabled, store.hasPendingMeasurements {
                        MeasurementSaveFailureCard(error: store.measurementSaveError) {
                            store.retryPendingMeasurements()
                        }
                    }
                    VStack(spacing: 12) {
                        scaleStage
                        manualEntryButton
                    }
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
            .navigationDestination(item: $detailMeasurement) { measurement in
                MeasurementDetailView(measurement: measurement)
            }
            .onAppear {
                isPulsing = true
                selectFirstScaleIfNeeded()
                isMeasurementViewActive = true
                if store.isSimulationEnabled {
                    resetSimulatedMeasurement()
                } else {
                    startMeasurementMonitoring()
                }
            }
            .onDisappear {
                isMeasurementViewActive = false
                isPulsing = false
                simulationMeasurementTask?.cancel()
                bluetooth.stopMeasurementMonitoring()
            }
            .onChange(of: store.pairedScales) {
                guard !store.isSimulationEnabled else { return }
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                selectFirstScaleIfNeeded()
                startMeasurementMonitoring()
            }
            .onChange(of: store.isSimulationEnabled) { _, isEnabled in
                selectFirstScaleIfNeeded()
                if isEnabled {
                    bluetooth.stopMeasurementMonitoring()
                    resetSimulatedMeasurement()
                } else {
                    simulationMeasurementTask?.cancel()
                    simulatedWeightKG = nil
                    startMeasurementMonitoring()
                }
            }
            .onChange(of: store.displaySelectedProfileID) {
                guard isMeasurementViewActive else { return }
                if store.isSimulationEnabled {
                    resetSimulatedMeasurement()
                } else {
                    startMeasurementMonitoring()
                }
            }
            .onChange(of: selectedScaleID) {
                guard isMeasurementViewActive else { return }
                if store.isSimulationEnabled {
                    resetSimulatedMeasurement()
                } else {
                    startMeasurementMonitoring()
                }
            }
            .onChange(of: displayedMeasurementState) { _, state in
                announceMeasurementState(state)
            }
            .accessibilityAnnounceChanges(store.storageError)
        }
        .accessibilityHidden(showProfileDropdown || showScaleDropdown)
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
        .overlayPreferenceValue(MeasureScaleAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showScaleDropdown, let anchor {
                    let buttonFrame = proxy[anchor]
                    let dropdownWidth: CGFloat = min(320, proxy.size.width - 36)
                    let dropdownX = min(
                        max(buttonFrame.minX, 18),
                        proxy.size.width - dropdownWidth - 18
                    )

                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showScaleDropdown = false
                                }
                            }

                        TrendSingleChoiceDropdown(
                            title: "选择测量设备",
                            options: scaleOptions,
                            selection: $selectedScaleID,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showScaleDropdown = false
                                }
                            }
                        )
                        .frame(width: dropdownWidth)
                        .offset(x: dropdownX, y: buttonFrame.maxY + 8)
                        .transition(.scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var manualEntryButton: some View {
        Button {
            showManualEntry = true
        } label: {
            Label("手动录入数据", systemImage: "square.and.pencil")
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
        .disabled(store.isUsingPlaceholderData)
        .opacity(store.isUsingPlaceholderData ? 0.55 : 1)
    }

    private var scaleStage: some View {
        VStack(spacing: 18) {
            ZStack {
                PulsingRing(diameter: 276, lineWidth: 28, isActive: isPulsing)
                Circle()
                    .fill(LinearGradient(colors: [AppColor.surface, AppColor.paleMint], startPoint: .top, endPoint: .bottom))
                    .frame(width: 230, height: 230)
                    .shadow(color: AppColor.mint.opacity(0.12), radius: 24, y: 10)
                VStack(spacing: 12) {
                    stageIcon
                        .foregroundStyle(AppColor.mint)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44, alignment: .center)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(liveWeightText)
                            .font(.system(size: 54, weight: .medium, design: .rounded))
                            .contentTransition(store.isSimulationEnabled ? .numericText() : .identity)
                        if hasLiveWeight {
                            Text(store.unit.symbol).font(.headline)
                        }
                    }
                    .frame(height: 64, alignment: .center)
                    ZStack {
                        if let stageLabel {
                            StatusPill(text: stageLabel, color: stageColor)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .frame(height: 26, alignment: .center)
                }
                .offset(y: -8)
            }
            .frame(maxWidth: .infinity)

            AppLocalizedText(statusText)
                .font(.subheadline)
                .foregroundStyle(AppColor.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340, minHeight: 44)
        }
        .frame(maxWidth: .infinity, minHeight: 330)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.appLanguage.text(.measure))
        .accessibilityValue(measurementStageAccessibilityValue)
        .accessibilityActions {
            if store.isSimulationEnabled {
                Button(store.appLanguage.text("模拟一次测量"), action: runSimulatedMeasurement)
            }
        }
    }

    private var userSwitchButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                showScaleDropdown = false
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
        .disabled(store.isUsingPlaceholderData)
        .anchorPreference(key: MeasureProfileAnchorKey.self, value: .bounds) { $0 }
        .accessibilityLabel(store.appLanguage.format("切换测量成员，当前为 %@", store.displaySelectedProfile.name))
        .accessibilityHint(store.appLanguage.text("点击选择本次测量数据所属的成员"))
        .accessibilityReturnFocus(when: showProfileDropdown)
    }

    private var scaleSwitchButton: some View {
        Button {
            guard !scaleOptions.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                showProfileDropdown = false
                showScaleDropdown.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image("ScaleDeviceTabIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 24, height: 24)
                    .background(AppColor.paleMint, in: Circle())

                Text(selectedScaleName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.82)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(
                showScaleDropdown ? AppColor.paleMint : AppColor.surface.opacity(0.92),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(AppColor.mint.opacity(showScaleDropdown ? 0.35 : 0.16), lineWidth: 1)
            )
            .shadow(color: AppColor.mint.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(scaleOptions.isEmpty)
        .frame(maxWidth: 156, alignment: .leading)
        .anchorPreference(key: MeasureScaleAnchorKey.self, value: .bounds) { $0 }
        .accessibilityLabel(store.appLanguage.format("切换测量设备，当前为 %@", selectedScaleName))
        .accessibilityHint(store.appLanguage.text("点击选择本次测量使用的体重秤或体脂秤"))
        .accessibilityReturnFocus(when: showScaleDropdown)
    }

    private func startMeasurementMonitoring() {
        guard !store.isUsingPlaceholderData,
              let selectedScaleID,
              store.pairedScales.contains(where: { $0.id == selectedScaleID }) else {
            bluetooth.stopMeasurementMonitoring()
            return
        }
        bluetooth.startMeasurementMonitoring(
            scales: store.pairedScales,
            selectedScaleID: selectedScaleID,
            profile: store.displaySelectedProfile
        )
    }

    private func selectFirstScaleIfNeeded() {
        let scales = store.displayPairedScales
        guard selectedScaleID == nil
                || !scales.contains(where: { $0.id == selectedScaleID }) else { return }
        selectedScaleID = scales.first?.id
    }

    private var displayedWeightKG: Double? {
        if store.isSimulationEnabled { return simulatedDisplayWeightKG }
        guard isMeasurementViewActive, !store.isUsingPlaceholderData else { return nil }
        return bluetooth.liveWeightKG
    }

    private var liveWeightText: String {
        guard let weightKG = displayedWeightKG else { return "— —" }
        return store.unit.value(fromKilograms: weightKG).formatted(2)
    }

    private var isCurrentMeasurementPending: Bool {
        guard !store.isSimulationEnabled, let measurement = bluetooth.latestMeasurement else { return false }
        return store.isMeasurementPending(measurement.id)
    }

    private var statusText: String {
        if isCurrentMeasurementPending { return "未保存" }
        if store.isSimulationEnabled { return simulationState.title(in: store.appLanguage) }
        if store.isUsingPlaceholderData { return "需要成员资料" }
        if store.pairedScales.isEmpty { return "请先在“设备”页添加体重秤" }
        return bluetooth.state.title(in: store.appLanguage)
    }

    private var displayedMeasurementState: BluetoothScaleState {
        if store.isSimulationEnabled { return simulationState }
        guard isMeasurementViewActive, !store.isUsingPlaceholderData else { return .idle }
        return bluetooth.state
    }

    private var simulatedDisplayWeightKG: Double? {
        switch simulationState {
        case .measuringWeight, .measuringBodyComposition, .confirmingMeasurement, .completed:
            simulatedWeightKG ?? store.latest?.weightKG
        default:
            nil
        }
    }

    private var hasLiveWeight: Bool {
        displayedWeightKG != nil
    }

    private var measurementStageAccessibilityValue: String {
        guard hasLiveWeight else { return store.appLanguage.text(statusText) }
        let weight = "\(liveWeightText) \(store.unit.symbol)"
        return store.appLanguage.format(
            "%@，%@",
            store.appLanguage.text(statusText),
            weight
        )
    }

    private func announceMeasurementState(_ state: BluetoothScaleState) {
        guard isMeasurementViewActive else { return }
        let stateText = state == .completed && isCurrentMeasurementPending
            ? store.appLanguage.text("未保存")
            : state.title(in: store.appLanguage)
        let finalWeight = store.isSimulationEnabled ? simulatedWeightKG : bluetooth.latestMeasurement?.weightKG
        if state == .completed, let finalWeight {
            AppAccessibility.announce(
                store.appLanguage.format(
                    "%@，%@",
                    stateText,
                    "\(store.unit.value(fromKilograms: finalWeight).formatted(2)) \(store.unit.symbol)"
                )
            )
        } else {
            AppAccessibility.announce(stateText)
        }
    }

    @ViewBuilder
    private var stageIcon: some View {
        if store.isSimulationEnabled {
            Button(action: runSimulatedMeasurement) {
                stageIconContent
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.appLanguage.text("模拟一次测量"))
        } else {
            stageIconContent
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var stageIconContent: some View {
        switch displayedMeasurementState {
        case .measuringWeight, .measuringBodyComposition, .confirmingMeasurement:
            Image(systemName: "waveform")
                .font(.title2)
        default:
            scaleDeviceStageIcon
        }
    }

    private var scaleDeviceStageIcon: some View {
        Image("ScaleDeviceTabIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
    }

    private var stageLabel: String? {
        if isCurrentMeasurementPending { return "未保存" }
        return switch displayedMeasurementState {
        case .measuringWeight, .measuringBodyComposition, .confirmingMeasurement: "测量中"
        case .completed: "测量完成"
        default: nil
        }
    }

    private var stageColor: Color {
        if isCurrentMeasurementPending { return AppColor.rose }
        return switch displayedMeasurementState {
        case .measuringWeight, .measuringBodyComposition, .confirmingMeasurement: AppColor.sky
        default: AppColor.mint
        }
    }

    private var simulationScaleName: String {
        simulationScale?.name ?? store.appLanguage.text("模拟设备")
    }

    private var simulationScale: PairedScale? {
        if let selectedScaleID,
           let scale = store.displayPairedScales.first(where: { $0.id == selectedScaleID }) {
            return scale
        }
        return store.displayPairedScales.first
    }

    private func runSimulatedMeasurement() {
        guard store.isSimulationEnabled else { return }
        simulationMeasurementTask?.cancel()
        let selectedSimulationScale = simulationScale
        let scaleName = selectedSimulationScale?.name ?? simulationScaleName
        let supportsBodyComposition = SimulationDataSnapshot.supportsBodyComposition(on: selectedSimulationScale)
        let recentMeasurement = supportsBodyComposition
            ? store.displayMeasurements.first(where: \.hasBodyComposition) ?? store.latest
            : store.latest
        let completedMeasurement = SimulationMeasurementGenerator.make(
            profile: store.displaySelectedProfile,
            recentMeasurement: recentMeasurement,
            device: selectedSimulationScale
        )
        let finalWeightKG = completedMeasurement.weightKG
        simulationMeasurementTask = Task { @MainActor in
            updateSimulation(state: .scanning, weightKG: nil)
            guard await waitForSimulation(milliseconds: 1_000) else { return }
            updateSimulation(state: .connecting(scaleName), weightKG: nil)
            guard await waitForSimulation(milliseconds: 1_100) else { return }
            updateSimulation(state: .connected(scaleName), weightKG: nil)
            guard await waitForSimulation(milliseconds: 700) else { return }

            for factor in [0.62, 0.74, 0.85, 0.93, 0.98, 1.0] {
                updateSimulation(state: .measuringWeight, weightKG: finalWeightKG * factor)
                guard await waitForSimulation(milliseconds: 450) else { return }
            }

            if supportsBodyComposition {
                updateSimulation(state: .measuringBodyComposition, weightKG: finalWeightKG)
                guard await waitForSimulation(milliseconds: 1_500) else { return }
            }
            updateSimulation(state: .confirmingMeasurement, weightKG: finalWeightKG)
            guard await waitForSimulation(milliseconds: supportsBodyComposition ? 1_000 : 2_500) else { return }
            store.add(completedMeasurement)
            updateSimulation(state: .completed, weightKG: finalWeightKG)
        }
    }

    private func resetSimulatedMeasurement() {
        simulationMeasurementTask?.cancel()
        simulationState = .completed
        simulatedWeightKG = store.latest?.weightKG
    }

    @MainActor
    private func updateSimulation(state: BluetoothScaleState, weightKG: Double?) {
        if reduceMotion {
            simulationState = state
            simulatedWeightKG = weightKG
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                simulationState = state
                simulatedWeightKG = weightKG
            }
        }
    }

    private func waitForSimulation(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return !Task.isCancelled && store.isSimulationEnabled && isMeasurementViewActive
        } catch {
            return false
        }
    }

    @ViewBuilder
    private var measurementSummary: some View {
        Button {
            if let liveMeasurement {
                detailMeasurement = liveMeasurement
            }
        } label: {
            measurementSummaryCard(liveMeasurement)
        }
        .buttonStyle(.plain)
        .disabled(liveMeasurement == nil || isCurrentMeasurementPending)
    }

    private func measurementSummaryCard(_ measurement: BodyMeasurement?) -> some View {
        let measurementProfile = measurementProfile(for: measurement)
        return SoftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本次测量").font(.headline)
                        if let measurement {
                            Text(measurement.date, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption).foregroundStyle(AppColor.secondary)
                        } else {
                            Text(verbatim: "--")
                                .font(.caption).foregroundStyle(AppColor.secondary)
                        }
                    }
                    Spacer()
                    if measurement != nil, !isCurrentMeasurementPending {
                        AppLocalizedText("详情")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.mint)
                    }
                }
                VStack(spacing: 0) {
                    measurementSummaryRow(
                        "体重",
                        value: measurement.map {
                            "\(store.unit.value(fromKilograms: $0.weightKG).formatted(2)) \(store.unit.symbol)"
                        } ?? "--"
                    )
                    measurementSummaryRow(
                        "BMI",
                        value: measurement.map { $0.bmi(heightCM: measurementProfile.heightCM).formatted(2) } ?? "--"
                    )
                    measurementSummaryRow(
                        "体脂率",
                        value: measurement?.bodyFatPercent.map { "\($0.formatted(2))%" } ?? "--",
                        showsDivider: false
                    )
                }
                HStack(spacing: 12) {
                    ScaleDeviceLabel(title: summaryDeviceName(for: measurement), iconSize: 13)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(measurementProfile.name)
                            .lineLimit(1)
                        MemberAvatarView(
                            avatar: measurementProfile.avatar,
                            width: 22,
                            height: 22,
                            showsBackdrop: false
                        )
                        .clipShape(Circle())
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
            }
        }
    }

    private func measurementProfile(for measurement: BodyMeasurement?) -> UserProfile {
        guard let profileID = measurement?.profileID else { return store.displaySelectedProfile }
        return store.displayProfiles.first(where: { $0.id == profileID }) ?? store.displaySelectedProfile
    }

    private func summaryDeviceName(for measurement: BodyMeasurement?) -> String {
        if let measurement {
            return measurement.deviceName
                ?? bluetooth.currentScaleName
                ?? store.appLanguage.text(measurement.source.localizationKey)
        }
        if store.isSimulationEnabled { return simulationScaleName }
        return bluetooth.currentScaleName ?? selectedScaleName
    }

    private func measurementSummaryRow(
        _ title: String,
        value: String,
        showsDivider: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                AppLocalizedText(title)
                    .foregroundStyle(AppColor.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.ink)
            }
            .font(.subheadline)
            .padding(.vertical, 12)
            if showsDivider { Divider() }
        }
    }

    private var safetyNote: some View {
        DataInformationLink()
    }
}

private struct ManualEntryProfileAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct ManualEntryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var saveFailed = false
    @State private var measurementDate = Date.now
    @State private var pendingMeasurementDate = Date.now
    @State private var isSelectingMeasurementDate = false
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var muscleMass = ""
    @State private var water = ""
    @State private var visceralFat = ""
    @State private var basalMetabolism = ""
    @State private var boneMass = ""
    @State private var isDetailDataExpanded = false
    @State private var showProfileDropdown = false

    private var profileOptions: [TrendDropdownOption<UUID>] {
        store.displayProfiles.map { profile in
            TrendDropdownOption(
                id: profile.id.uuidString,
                value: profile.id,
                title: profile.name,
                subtitle: "\(store.appLanguage.text(profile.role)) · \(profile.heightCM.formatted(2)) cm",
                icon: .avatar(profile.avatar)
            )
        }
    }

    private var parsedWeight: Double? {
        guard let value = numericValue(weight), MeasurementLimits.weightKG.contains(value) else { return nil }
        return value
    }

    private var canSave: Bool {
        parsedWeight != nil
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
                    measurementTimePanel
                    basicDataPanel
                    detailDataPanel
                    calculationNoticePanel
                    if saveFailed {
                        MeasurementSaveFailureCard(error: store.measurementSaveError, onRetry: save)
                    }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .tint(AppColor.mint)
                        .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $isSelectingMeasurementDate) {
            measurementDatePickerSheet
        }
        .accessibilityAnnounceChanges(saveFailed ? store.appLanguage.text("未保存") : nil)
        .accessibilityHidden(showProfileDropdown)
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

                    StatusPill(text: store.displaySelectedProfile.role)

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
                store.appLanguage.text(store.displaySelectedProfile.role)
            ))
            .accessibilityHint(store.appLanguage.text("点击展开选择记录成员"))
            .accessibilityReturnFocus(when: showProfileDropdown)
        }
    }

    private var measurementTimePanel: some View {
        SettingsPanel(title: "测量时间", icon: "calendar") {
            Button {
                KeyboardFocus.dismiss()
                showProfileDropdown = false
                pendingMeasurementDate = measurementDate
                isSelectingMeasurementDate = true
            } label: {
                HStack(spacing: 8) {
                    Text(measurementDate.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                            .locale(store.appLanguage.locale)
                    ))
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.secondary)
                }
                .frame(minHeight: 24)
                .modifier(ManualInputSurface(isFocused: isSelectingMeasurementDate))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.appLanguage.text("测量时间"))
            .accessibilityValue(measurementDate.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened)
                    .locale(store.appLanguage.locale)
            ))
            .accessibilityReturnFocus(when: isSelectingMeasurementDate)
        }
    }

    private var measurementDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                selection: $pendingMeasurementDate,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            ) {
                AppLocalizedText("测量时间")
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, store.appLanguage.locale)
            .tint(AppColor.mint)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pageBackground()
            .navigationTitle(store.appLanguage.text("测量时间"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isSelectingMeasurementDate = false }
                        .foregroundStyle(AppColor.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        measurementDate = min(pendingMeasurementDate, .now)
                        isSelectingMeasurementDate = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.mint)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var basicDataPanel: some View {
        SettingsPanel(title: "基础数据", icon: "scalemass.fill") {
            manualInputField(
                title: "体重",
                unit: "kg",
                placeholder: "必填，0.00 ~ 500.00",
                text: $weight,
                isRequired: true,
                isValid: isOptionalValid(weight, range: MeasurementLimits.weightKG)
            )
        }
    }

    private var detailDataPanel: some View {
        SettingsPanel(
            title: "详细数据（可选）",
            icon: "waveform.path.ecg",
            isExpanded: Binding(
                get: { isDetailDataExpanded },
                set: { expanded in
                    if !expanded { KeyboardFocus.dismiss() }
                    isDetailDataExpanded = expanded
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("若体重秤或第三方设备显示了具体数据，可在此补充录入：")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
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
            DataInformationLink()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.mint)
                AppLocalizedText(store.isSimulationEnabled
                    ? "当前为模拟数据模式，本次记录仅在本次运行中保留。"
                    : "手动记录仅保存在本机，并会清晰标记为“手动记录”来源。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        let saved = store.addManual(
            date: measurementDate,
            weightKG: weightKG,
            bodyFatPercent: numericValue(bodyFat),
            muscleMassKG: numericValue(muscleMass),
            waterPercent: numericValue(water),
            visceralFat: numericValue(visceralFat),
            basalMetabolismKCal: numericValue(basalMetabolism),
            boneMassKG: numericValue(boneMass)
        )
        saveFailed = !saved
        if saved { dismiss() }
    }
}

private struct MeasurementSaveFailureCard: View {
    let error: String?
    let onRetry: () -> Void

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    AppLocalizedText("未保存")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                    .font(.headline)
                    .foregroundStyle(AppColor.rose)
                AppLocalizedText("保存失败，数据尚未写入本机。请重试；退出应用后未保存的数据可能丢失。")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.ink)
                if let error {
                    Text(verbatim: error)
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                }
                Button(action: onRetry) {
                    Label {
                        AppLocalizedText("重试保存")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                        .font(.headline)
                        .foregroundStyle(AppColor.mint)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityAnnounceChanges(error)
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
                    Text(verbatim: "*")
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
                .accessibilityLabel(language.format("%@，%@", language.text(title), unit))
                .accessibilityHint(language.text(isRequired ? "必填" : "选填"))

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
            .modifier(ManualInputSurface(
                isFocused: isFocused,
                isValid: isValid,
                isCompact: layout == .grid
            ))
            if !isValid {
                Text(language.format("请检查输入：%@", language.text(placeholder)))
                    .font(.caption)
                    .foregroundStyle(AppColor.rose)
            }
        }
        .accessibilityAnnounceChanges(isValid ? nil : language.format("请检查输入：%@", language.text(title)))
    }
}

private struct ManualInputSurface: ViewModifier {
    var isFocused: Bool
    var isValid = true
    var isCompact = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, isCompact ? 10 : 14)
            .padding(.vertical, isCompact ? 9 : 11)
            .background(
                AppColor.surface,
                in: RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                    .stroke(
                        !isValid ? AppColor.rose : (isFocused ? AppColor.mint : AppColor.mint.opacity(0.14)),
                        lineWidth: isFocused || !isValid ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            }
    }
}
