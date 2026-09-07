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
                authorizationStatusRow
                if shouldShowAuthorizationRequestAction {
                    authorizationRequestAction
                }
                SettingsSeparator()
                sharingSection
                importSection

                if store.isSimulationEnabled {
                    notice(
                        "模拟数据不会写入 Apple 健康；这里的同步设置仅用于本次运行中的预览。",
                        icon: "sparkles"
                    )
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
        .navigationTitle(store.appLanguage.text(.dataSharing))
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
        .onAppear { appleHealth.refreshAuthorizationState() }
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
                notice(
                    "从 Apple 健康获取的记录会标记为 Apple 健康，并归入本人档案。",
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
                appearance: .compact,
                onSelect: { dataType in
                    store.toggleDisplayAppleHealthReadType(dataType)
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

    private var isSharingControlDisabled: Bool {
        guard !store.isSimulationEnabled else { return store.currentUserProfile == nil }
        if store.displayAppleHealthProfileID != nil {
            return appleHealth.isRequestingAuthorization
        }
        return isSyncControlUnavailable || appleHealth.authorizationState != .authorized
    }

    private var isImportControlDisabled: Bool {
        guard !store.isSimulationEnabled else { return store.currentUserProfile == nil }
        return isSyncControlUnavailable
    }

    private var isSyncControlUnavailable: Bool {
        guard store.currentUserProfile != nil,
              !appleHealth.isRequestingAuthorization else { return true }
        return switch appleHealth.authorizationState {
        case .authorized, .denied: false
        case .unavailable, .notDetermined, .failed: true
        }
    }

    private var sharingBinding: Binding<Bool> {
        Binding(
            get: { store.displayAppleHealthProfileID != nil },
            set: { isEnabled in
                guard isEnabled else {
                    expandedDropdown = nil
                    store.setDisplayAppleHealthProfileID(nil)
                    return
                }
                guard let currentUser = store.currentUserProfile else { return }
                if store.isSimulationEnabled {
                    store.setDisplayAppleHealthProfileID(currentUser.id)
                    return
                }
                store.setDisplayAppleHealthProfileID(currentUser.id)
            }
        )
    }

    private var importBinding: Binding<Bool> {
        Binding(
            get: { store.displayIsAppleHealthImportEnabled },
            set: { isEnabled in
                guard isEnabled else {
                    if expandedDropdown == .readTypes { expandedDropdown = nil }
                    store.setDisplayAppleHealthImportEnabled(false)
                    return
                }
                if store.displayAppleHealthReadTypes.isEmpty {
                    store.toggleDisplayAppleHealthReadType(.bodyMass)
                }
                if store.isSimulationEnabled {
                    store.setDisplayAppleHealthImportEnabled(true)
                    return
                }
                store.setDisplayAppleHealthImportEnabled(true)
                Task { await importAppleHealthData() }
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
        HStack(spacing: 12) {
            Image(systemName: authorizationIcon)
                .font(.title3)
                .foregroundStyle(authorizationColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                AppLocalizedText(authorizationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppLocalizedText(authorizationDetail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if appleHealth.isRequestingAuthorization { ProgressView().tint(AppColor.mint) }
        }
        .accessibilityElement(children: .combine)
    }

    private var shouldShowAuthorizationRequestAction: Bool {
        switch appleHealth.authorizationState {
        case .notDetermined, .failed: true
        case .unavailable, .authorized, .denied: false
        }
    }

    private var authorizationRequestAction: some View {
        Button {
            Task { await appleHealth.requestAuthorization() }
        } label: {
            Label("请求 Apple 健康权限", systemImage: "heart.text.clipboard")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(
            store.isSimulationEnabled
                || appleHealth.isRequestingAuthorization
                || appleHealth.authorizationState == .unavailable
        )
        .opacity(store.isSimulationEnabled ? 0.55 : 1)
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
        if appleHealth.isRequestingAuthorization { return "正在请求授权" }
        return switch appleHealth.authorizationState {
        case .unavailable: "Apple 健康不可用"
        case .notDetermined: "尚未授权"
        case .authorized: "已获写入权限"
        case .denied: "写入权限已关闭"
        case .failed: "授权请求失败"
        }
    }

    private var authorizationDetail: String {
        switch appleHealth.authorizationState {
        case .unavailable: "当前设备不支持健康数据。"
        case .notDetermined: "点击下方按钮，由系统显示读写权限确认。"
        case .authorized: "本应用可以写入您允许的健康数据类型。"
        case .denied: "请在系统的健康权限设置中允许本应用写入。"
        case let .failed(message): message
        }
    }

    private var authorizationIcon: String {
        switch appleHealth.authorizationState {
        case .authorized: "checkmark.circle.fill"
        case .unavailable, .denied, .failed: "exclamationmark.triangle.fill"
        case .notDetermined: "heart.circle"
        }
    }

    private var authorizationColor: Color {
        switch appleHealth.authorizationState {
        case .authorized: AppColor.mint
        case .unavailable, .denied, .failed: AppColor.rose
        case .notDetermined: AppColor.sky
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
              store.isAppleHealthImportEnabled,
              let currentUser = store.currentUserProfile else { return }
        let imported = await appleHealth.readMeasurements(
            dataTypes: store.appleHealthReadTypes,
            profileID: currentUser.id
        )
        store.importAppleHealthMeasurements(imported)
    }
}
