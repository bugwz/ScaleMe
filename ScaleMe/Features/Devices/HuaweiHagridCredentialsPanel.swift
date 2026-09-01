import SwiftUI

struct HuaweiHagridCredentialsPanel: View {
    let scaleID: UUID

    @State private var cak = ""
    @State private var c1 = ""
    @State private var c2 = ""
    @State private var isConfigured = false
    @State private var message: String?
    @State private var messageIsError = false

    private let credentialStore = HuaweiHagridCredentialStore()

    var body: some View {
        SettingsPanel(title: "华为 Hagrid 认证材料", icon: "key.horizontal.fill") {
            Text("CAK、C1 和 C2 各需 32 位十六进制。密钥仅保存到本机 Keychain，不写入配置文件、诊断日志或 iCloud。")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(2)

            HuaweiHagridCredentialField(title: "CAK", text: $cak)
            HuaweiHagridCredentialField(title: "C1", text: $c1)
            HuaweiHagridCredentialField(title: "C2", text: $c2)

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

            Text("当前仅完成认证材料的安全配置；C3 来源、认证令牌和工作密钥交换仍在适配，暂不会把该设备标记为已支持。")
                .font(.caption2)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(2)
        }
        .task { loadStatus() }
    }

    private var canSave: Bool {
        cak.count == 32 && c1.count == 32 && c2.count == 32
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
                cakHex: cak,
                c1Hex: c1,
                c2Hex: c2
            )
            try credentialStore.save(credentials, for: scaleID)
            KeyboardFocus.dismiss()
            cak = ""
            c1 = ""
            c2 = ""
            isConfigured = true
            message = "认证材料保存成功"
            messageIsError = false
        } catch ScalePayloadError.unsupported {
            message = "CAK、C1 和 C2 各需 32 位十六进制"
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
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                Text(verbatim: "\(text.count)/32")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppColor.secondary)
            }

            ResponsiveTextField(
                text: normalizedText,
                isFocused: $isFocused,
                placeholder: "",
                keyboardType: .asciiCapable,
                returnKeyType: .done,
                autocapitalizationType: .allCharacters,
                autocorrectionType: .no,
                spellCheckingType: .no,
                smartDashesType: .no,
                smartQuotesType: .no,
                smartInsertDeleteType: .no,
                isSecureTextEntry: true,
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
            .privacySensitive()
        }
    }

    private var normalizedText: Binding<String> {
        Binding(
            get: { text },
            set: { text = HuaweiHagridProtocol.normalizedCredentialInput($0) }
        )
    }
}
