import SwiftUI

private enum AppleHealthDropdown: Equatable {
    case devices
    case readTypes
}

struct AppleHealthSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var appleHealth: AppleHealthManager
    @State private var expandedDropdown: AppleHealthDropdown?

    var body: some View {
        ScrollView {
            SettingsPanel(title: "Apple 健康", icon: "heart.fill") {
                notice(
                    "开启后申请体重与体脂率的读写权限，不影响本地测量。",
                    icon: "hand.raised"
                )
                SettingsSeparator()
                authorizationStatusRow
                SettingsSeparator()
                SettingsSwitch(title: "与 Apple 健康同步数据", isOn: syncBinding)
                    .disabled(isSyncControlUnavailable)
                if store.displayIsAppleHealthSyncEnabled {
                    sharingSection
                    importSection
                }

                if store.isSimulationEnabled {
                    notice(
                        "模拟数据不会写入 Apple 健康。",
                        icon: "sparkles"
                    )
                }
                if let error = appleHealth.lastAuthorizationError {
                    errorBanner(title: "授权请求失败", message: error)
                }
                if let error = appleHealth.lastShareError {
                    errorBanner(title: "最近一次共享失败", message: error)
                }
                if let error = appleHealth.lastImportError {
                    errorBanner(title: "最近一次获取失败", message: error)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.appleHealthSync))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .accessibilityHidden(expandedDropdown != nil)
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    dropdownLayer(anchorFrame: proxy[anchor], availableSize: proxy.size)
                }
            }
        }
        .onAppear { appleHealth.refreshWriteAuthorizationStates() }
        .accessibilityAnnounceChanges(authorizationTitle)
        .accessibilityAnnounceChanges(appleHealth.lastImportError)
        .accessibilityAnnounceChanges(appleHealth.lastShareError)
        .accessibilityAnnounceChanges(appleHealth.isImporting ? store.appLanguage.text("正在从 Apple 健康获取数据") : nil)
        .onChange(of: appleHealth.isImporting) { wasImporting, importing in
            if wasImporting && !importing && appleHealth.lastImportError == nil {
                AppAccessibility.announce(store.appLanguage.format("%@，%@", store.appLanguage.text("从 Apple 健康获取数据"), store.appLanguage.text("完成")))
            }
        }
        .onDisappear { expandedDropdown = nil }
    }

    private var sharingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSwitch(
                title: "共享数据给 Apple 健康",
                isOn: sharingBinding
            )
            .disabled(isSharingControlDisabled)
            .opacity(isSharingControlDisabled ? 0.55 : 1)

            if store.displayAppleHealthProfileID != nil {
                SettingsSeparator()
                fixedField(
                    title: "选择用户",
                    value: sharedProfile?.name ?? store.appLanguage.text("请选择成员"),
                    icon: "person.crop.circle"
                )
                SettingsSeparator()
                dropdownField(
                    title: "选择设备",
                    value: deviceSelectionTitle,
                    icon: "externaldrive.connected.to.line.below",
                    dropdown: .devices,
                    isEnabled: !store.displayPairedScales.isEmpty
                )
                if store.displayPairedScales.isEmpty {
                    notice("请先在设备页关联体重秤，再选择允许同步的来源。", icon: "scalemass")
                } else if store.displayAppleHealthDeviceIDs.isEmpty {
                    notice(
                        "开启同步后仍需至少选择一台设备，新的测量才会写入 Apple 健康。",
                        icon: "exclamationmark.circle.fill",
                        color: AppColor.rose
                    )
                }
                notice(
                    "共享到 Apple 健康的记录仅包含所选用户由所选设备产生的新稳定测量。",
                    icon: "checkmark.shield"
                )
            }
        }
        .padding(14)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.mint.opacity(0.10))
        }
    }

    private func fixedField(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AppLocalizedText(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 34, height: 34)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 10))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColor.mint.opacity(0.18))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSwitch(
                title: "从 Apple 健康获取数据",
                isOn: importBinding
            )
            .disabled(isImportControlDisabled)
            .opacity(isImportControlDisabled ? 0.55 : 1)

            if store.displayIsAppleHealthImportEnabled {
                SettingsSeparator()
                dropdownField(
                    title: "选择数据类型",
                    value: readTypeSelectionTitle,
                    icon: "square.and.arrow.down",
                    dropdown: .readTypes
                )
                if appleHealth.isImporting {
                    HStack(spacing: 8) {
                        ProgressView().tint(AppColor.mint)
                        AppLocalizedText("正在从 Apple 健康获取数据")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }
                }
            }
        }
        .padding(14)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.mint.opacity(0.10))
        }
    }

    private func dropdownField(
        title: String,
        value: String,
        icon: String,
        dropdown: AppleHealthDropdown,
        isEnabled: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AppLocalizedText(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
            AppDropdownField(
                value: value,
                icon: icon,
                accessibilityLabel: title,
                isExpanded: expandedDropdown == dropdown,
                appearance: .compact,
                onToggle: { toggleDropdown(dropdown, isEnabled: isEnabled) }
            )
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.55)
        }
    }

    @ViewBuilder
    private func dropdownLayer(anchorFrame: CGRect, availableSize: CGSize) -> some View {
        switch expandedDropdown {
        case .devices:
            AppDropdownMenuLayer(
                anchorFrame: anchorFrame,
                availableSize: availableSize,
                options: store.displayPairedScales,
                isSelected: { store.displayAppleHealthDeviceIDs.contains($0.id) },
                title: { $0.name },
                detail: { $0.modelName },
                appearance: .compact,
                onSelect: { scale in
                    store.toggleDisplayAppleHealthDevice(scale.id)
                },
                onDismiss: dismissDropdown
            )
        case .readTypes:
            AppDropdownMenuLayer(
                anchorFrame: anchorFrame,
                availableSize: availableSize,
                options: AppleHealthDataType.allCases,
                isSelected: { store.displayAppleHealthReadTypes.contains($0) },
                title: { $0.title },
                detail: { $0 == .bodyMass ? store.appLanguage.text("必填") : nil },
                appearance: .compact,
                onSelect: { dataType in
                    guard !appleHealth.isRequestingAuthorization else { return }
                    store.toggleDisplayAppleHealthReadType(dataType)
                    if store.displayIsAppleHealthSyncEnabled && store.displayIsAppleHealthImportEnabled {
                        Task { await importAppleHealthData() }
                    }
                },
                onDismiss: dismissDropdown
            )
        case nil:
            EmptyView()
        }
    }

    private var sharedProfile: UserProfile? {
        guard let id = store.displayAppleHealthProfileID else { return nil }
        return store.managedProfiles.first { $0.id == id }
    }

    private var isSharingControlDisabled: Bool { isSyncControlUnavailable }

    private var isImportControlDisabled: Bool {
        isSyncControlUnavailable || (!store.displayIsAppleHealthImportEnabled && store.displayAppleHealthReadTypes.isEmpty)
    }

    private var isSyncControlUnavailable: Bool {
        guard store.currentUserProfile != nil else { return true }
        if store.isSimulationEnabled { return false }
        return appleHealth.isRequestingAuthorization || appleHealth.isImporting
            || appleHealth.weightWriteAuthorizationState == .unavailable
    }

    private var syncBinding: Binding<Bool> {
        Binding(
            get: { store.displayIsAppleHealthSyncEnabled },
            set: { isEnabled in
                expandedDropdown = nil
                guard isEnabled else {
                    store.setDisplayAppleHealthSyncEnabled(false)
                    return
                }
                if store.isSimulationEnabled {
                    store.setDisplayAppleHealthSyncEnabled(true)
                    return
                }
                Task {
                    guard await appleHealth.requestAuthorization() else { return }
                    store.setDisplayAppleHealthSyncEnabled(true)
                    await importAppleHealthData()
                }
            }
        )
    }

    private var sharingBinding: Binding<Bool> {
        Binding(
            get: { store.displayAppleHealthProfileID != nil },
            set: { isEnabled in
                expandedDropdown = nil
                store.setDisplayAppleHealthProfileID(isEnabled ? store.currentUserProfile?.id : nil)
            }
        )
    }

    private var importBinding: Binding<Bool> {
        Binding(
            get: { store.displayIsAppleHealthImportEnabled },
            set: { isEnabled in
                expandedDropdown = nil
                store.setDisplayAppleHealthImportEnabled(isEnabled)
                if isEnabled { Task { await importAppleHealthData() } }
            }
        )
    }

    private var deviceSelectionTitle: String {
        let count = store.displayAppleHealthDeviceIDs.count
        return count == 0
            ? store.appLanguage.text("请选择设备")
            : store.appLanguage.format("已选择 %lld 台设备", count)
    }

    private var readTypeSelectionTitle: String {
        store.appLanguage.format("已选择 %lld 项", store.displayAppleHealthReadTypes.count)
    }

    private var authorizationStatusRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appleHealth.weightWriteAuthorizationState == appleHealth.bodyFatWriteAuthorizationState {
                permissionRow("体重与体脂率", state: appleHealth.weightWriteAuthorizationState)
            } else {
                permissionRow("体重", state: appleHealth.weightWriteAuthorizationState)
                permissionRow("体脂率", state: appleHealth.bodyFatWriteAuthorizationState)
            }
            if appleHealth.weightWriteAuthorizationState == .denied
                || appleHealth.bodyFatWriteAuthorizationState == .denied
                || appleHealth.lastAuthorizationError != nil
                || appleHealth.lastShareError != nil
                || appleHealth.lastImportError != nil {
                notice("请前往“健康”App → 个人头像 → App → 观我调整权限。", icon: "info.circle")
            }
        }
    }

    private func permissionRow(_ title: String, state: AppleHealthManager.WriteAuthorizationState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: state == .authorized ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(state == .authorized ? AppColor.mint : AppColor.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                AppLocalizedText(title).font(.caption).foregroundStyle(AppColor.secondary)
                AppLocalizedText(authorizationTitle(for: state))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppColor.ink)
            }
            Spacer()
            if appleHealth.isRequestingAuthorization { ProgressView().tint(AppColor.mint) }
        }
        .accessibilityElement(children: .combine)
    }

    private func notice(_ text: String, icon: String, color: Color = AppColor.secondary) -> some View {
        Label { AppLocalizedText(text) } icon: { Image(systemName: icon) }
            .font(.caption)
            .foregroundStyle(color)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func errorBanner(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(AppColor.rose)
            VStack(alignment: .leading, spacing: 4) {
                AppLocalizedText(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppColor.ink)
                Text(message).font(.caption).foregroundStyle(AppColor.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.rose.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var authorizationTitle: String {
        authorizationTitle(for: appleHealth.weightWriteAuthorizationState)
    }

    private func authorizationTitle(for state: AppleHealthManager.WriteAuthorizationState) -> String {
        if appleHealth.isRequestingAuthorization { return "正在请求授权" }
        return switch state {
        case .unavailable: "Apple 健康不可用"
        case .notDetermined: "尚未授权"
        case .authorized: "已获写入权限"
        case .denied: "写入权限已关闭"
        }
    }

    private func toggleDropdown(_ dropdown: AppleHealthDropdown, isEnabled: Bool) {
        guard isEnabled else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedDropdown = expandedDropdown == dropdown ? nil : dropdown
        }
    }

    private func dismissDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) { expandedDropdown = nil }
    }

    private func importAppleHealthData() async {
        guard !store.isSimulationEnabled,
              store.isAppleHealthSyncEnabled,
              !appleHealth.isRequestingAuthorization,
              !appleHealth.isImporting,
              store.isAppleHealthImportEnabled,
              let currentUser = store.currentUserProfile else { return }
        let imported = await appleHealth.readMeasurements(
            dataTypes: store.appleHealthReadTypes,
            profileID: currentUser.id
        )
        store.importAppleHealthMeasurements(imported)
    }
}
