import SwiftUI

struct HuaweiHagridCredentialsPanel: View {
    let scaleID: UUID

    @Environment(\.appLanguage) private var language
    @State private var bluetoothAddress = ""
    @State private var cak = ""
    @State private var c1 = ""
    @State private var c2 = ""
    @State private var isConfigured = false
    @State private var message: String?
    @State private var messageIsError = false

    private let credentialStore = HuaweiHagridCredentialStore()

    var body: some View {
        SettingsPanel(title: "华为 Hagrid 认证材料", icon: "key.horizontal.fill") {
            Text("需提供秤的蓝牙地址，以及各 32 位十六进制的 CAK、C1 和 C2。认证材料仅保存到本机 Keychain，不写入配置文件或诊断日志。")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(2)

            HuaweiHagridCredentialField(
                title: language.text("蓝牙地址"),
                text: $bluetoothAddress,
                maximumLength: 17,
                placeholder: "AA:BB:CC:DD:EE:FF"
            )
            HuaweiHagridCredentialField(title: "CAK", text: $cak, maximumLength: 32)
            HuaweiHagridCredentialField(title: "C1", text: $c1, maximumLength: 32)
            HuaweiHagridCredentialField(title: "C2", text: $c2, maximumLength: 32)

            Button(action: save) {
                Label("保存", systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        canSave ? AppColor.mint : AppColor.secondary.opacity(0.32),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            if isConfigured {
                Label("认证材料已在本机安全保存", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
            }

            if let message {
                Label(message, systemImage: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(messageIsError ? AppColor.rose : AppColor.mint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("iOS 不提供外设的真实蓝牙地址；该地址用于生成 C3。协议解析已通过抓包夹具验证，仍需在真实设备上验证完整测量会话。")
                .font(.caption2)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(2)
        }
        .task { loadStatus() }
    }

    private var canSave: Bool {
        (try? HuaweiHagridProtocol.Credentials(
            bluetoothAddress: bluetoothAddress,
            cakHex: cak,
            c1Hex: c1,
            c2Hex: c2
        )) != nil
    }

    private func loadStatus() {
        do {
            isConfigured = try credentialStore.load(for: scaleID) != nil
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
    }

    private func save() {
        do {
            let credentials = try HuaweiHagridProtocol.Credentials(
                bluetoothAddress: bluetoothAddress,
                cakHex: cak,
                c1Hex: c1,
                c2Hex: c2
            )
            try credentialStore.save(credentials, for: scaleID)
            KeyboardFocus.dismiss()
            bluetoothAddress = ""
            cak = ""
            c1 = ""
            c2 = ""
            isConfigured = true
            message = language.text("认证材料保存成功")
            messageIsError = false
        } catch ScalePayloadError.unsupported {
            message = language.text("请填写蓝牙地址，并确保 CAK、C1 和 C2 各为 32 位十六进制")
            messageIsError = true
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
    }
}

private struct HuaweiHagridCredentialField: View {
    let title: String
    @Binding var text: String
    let maximumLength: Int
    var placeholder = ""
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text(verbatim: "\(text.count)/\(maximumLength)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppColor.secondary)
            }

            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder,
                keyboardType: .asciiCapable,
                returnKeyType: .done,
                autocapitalizationType: .allCharacters,
                autocorrectionType: .no,
                spellCheckingType: .no,
                smartDashesType: .no,
                smartQuotesType: .no,
                smartInsertDeleteType: .no,
                synchronizesFocusFromBinding: false,
                showsDoneAccessory: true
            )
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFocused ? AppColor.mint.opacity(0.7) : AppColor.mint.opacity(0.18),
                        lineWidth: isFocused ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            )
            .accessibilityLabel(title)
        }
    }
}
