import SwiftUI

struct AppleHealthSettingsView: View {
    private struct ProfileOption: Hashable {
        let id: UUID
        let name: String
    }

    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var appleHealth: AppleHealthManager
    @State private var isProfileDropdownExpanded = false
    @State private var isDeviceDropdownExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "Apple 健康", icon: "heart.fill") {
                    authorizationStatusRow

                    SettingsSeparator()

                    SettingsSwitch(
                        title: "同步到 Apple 健康",
                        detail: "开启时会请求 Apple 健康写入权限；关闭后本应用不会继续写入新数据。",
                        isOn: sharingBinding
                    )
                    .disabled(appleHealth.isRequestingAuthorization || appleHealth.authorizationState == .unavailable)
                    .opacity(appleHealth.authorizationState == .unavailable ? 0.55 : 1)

                    if store.displayAppleHealthProfileID != nil {
                        SettingsSeparator()

                        VStack(alignment: .leading, spacing: 10) {
                            AppLocalizedText("同步用户")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.ink)
                            AppDropdownField(
                                value: sharedProfile?.name ?? store.appLanguage.text("请选择成员"),
                                icon: "person.crop.circle",
                                accessibilityLabel: "同步用户",
                                isExpanded: isProfileDropdownExpanded,
                                appearance: .compact,
                                onToggle: toggleProfileDropdown
                            )
                        }

                        SettingsSeparator()

                        VStack(alignment: .leading, spacing: 10) {
                            AppLocalizedText("同步设备")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.ink)
                            AppDropdownField(
                                value: deviceSelectionTitle,
                                icon: "externaldrive.connected.to.line.below",
                                accessibilityLabel: "同步设备",
                                isExpanded: isDeviceDropdownExpanded,
                                appearance: .compact,
                                onToggle: toggleDeviceDropdown
                            )
                            .disabled(store.displayPairedScales.isEmpty)
                            .opacity(store.displayPairedScales.isEmpty ? 0.55 : 1)

                            AppLocalizedText("仅勾选你确认数据可靠的设备。未选择的设备、无法关联设备的数据和手动记录不会写入 Apple 健康。")
                                .font(.caption)
                                .foregroundStyle(AppColor.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)

                            if store.displayPairedScales.isEmpty {
                                Label("请先在设备页关联体重秤，再选择允许同步的来源。", systemImage: "scalemass")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if store.displayAppleHealthDeviceIDs.isEmpty {
                                Label("开启同步后仍需至少选择一台设备，新的测量才会写入 Apple 健康。", systemImage: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.rose)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                SettingsPanel(title: "数据同步范围", icon: "square.and.arrow.up") {
                    sharedTypeRow(icon: "scalemass.fill", title: "体重", detail: "每次稳定称重的千克值")
                    SettingsSeparator()
                    sharedTypeRow(icon: "percent", title: "体脂率", detail: "仅共享所选设备明确提供的数值")
                }

                Label(
                    "本应用不会读取 Apple 健康数据。开启后仅共享所选成员的新测量，不补传历史记录；估算的身体成分不会写入。",
                    systemImage: "hand.raised.fill"
                )
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(3)
                .padding(.horizontal, 2)

                if store.isSimulationEnabled {
                    Label(
                        "模拟数据不会写入 Apple 健康；这里的同步设置仅用于本次运行中的预览。",
                        systemImage: "sparkles"
                    )
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 2)
                }

                if let lastShareError = appleHealth.lastShareError {
                    errorBanner(lastShareError)
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
        .accessibilityHidden(isProfileDropdownExpanded || isDeviceDropdownExpanded)
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, isProfileDropdownExpanded {
                    AppDropdownMenuLayer(
                        anchorFrame: proxy[anchor],
                        availableSize: proxy.size,
                        options: profileOptions,
                        isSelected: { $0 == selectedProfileOption },
                        title: { $0.name },
                        appearance: .compact,
                        onSelect: { option in
                            store.setDisplayAppleHealthProfileID(option.id)
                            dismissProfileDropdown()
                        },
                        onDismiss: dismissProfileDropdown
                    )
                } else if let anchor, isDeviceDropdownExpanded {
                    AppDropdownMenuLayer(
                        anchorFrame: proxy[anchor],
                        availableSize: proxy.size,
                        options: store.displayPairedScales,
                        isSelected: { store.displayAppleHealthDeviceIDs.contains($0.id) },
                        title: { $0.name },
                        detail: { $0.modelName },
                        appearance: .compact,
                        onSelect: { scale in
                            withAnimation(.easeInOut(duration: 0.16)) {
                                store.toggleDisplayAppleHealthDevice(scale.id)
                            }
                        },
                        onDismiss: dismissDeviceDropdown
                    )
                }
            }
        }
        .onAppear { appleHealth.refreshAuthorizationState() }
        .onDisappear {
            isProfileDropdownExpanded = false
            isDeviceDropdownExpanded = false
        }
    }

    private var sharedProfile: UserProfile? {
        guard let profileID = store.displayAppleHealthProfileID else { return nil }
        return store.displayProfiles.first { $0.id == profileID }
    }

    private var profileOptions: [ProfileOption] {
        store.displayProfiles.map { ProfileOption(id: $0.id, name: $0.name) }
    }

    private var selectedProfileOption: ProfileOption {
        if let sharedProfile {
            return ProfileOption(id: sharedProfile.id, name: sharedProfile.name)
        }
        let fallback = store.displayProfiles[0]
        return ProfileOption(id: fallback.id, name: fallback.name)
    }

    private var sharingBinding: Binding<Bool> {
        Binding(
            get: { store.displayAppleHealthProfileID != nil },
            set: { isEnabled in
                if isEnabled {
                    Task {
                        guard await appleHealth.requestSharingAuthorization() else { return }
                        store.setDisplayAppleHealthProfileID(store.displaySelectedProfileID)
                    }
                } else {
                    isDeviceDropdownExpanded = false
                    store.setDisplayAppleHealthProfileID(nil)
                }
            }
        )
    }

    private var deviceSelectionTitle: String {
        let count = store.displayAppleHealthDeviceIDs.count
        return count == 0
            ? store.appLanguage.text("请选择设备")
            : store.appLanguage.format("已选择 %lld 台设备", count)
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
            if appleHealth.isRequestingAuthorization {
                ProgressView().tint(AppColor.mint)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sharedTypeRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.mint)
                .frame(width: 32, height: 32)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                AppLocalizedText(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppLocalizedText(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.rose)
            VStack(alignment: .leading, spacing: 4) {
                AppLocalizedText("最近一次共享失败")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.rose.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
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
        case .notDetermined: "开启同步后，由系统显示权限确认。"
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

    private func toggleProfileDropdown() {
        isDeviceDropdownExpanded = false
        withAnimation(.easeInOut(duration: 0.18)) {
            isProfileDropdownExpanded.toggle()
        }
    }

    private func dismissProfileDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isProfileDropdownExpanded = false
        }
    }

    private func toggleDeviceDropdown() {
        isProfileDropdownExpanded = false
        guard !store.displayPairedScales.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isDeviceDropdownExpanded.toggle()
        }
    }

    private func dismissDeviceDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isDeviceDropdownExpanded = false
        }
    }
}
