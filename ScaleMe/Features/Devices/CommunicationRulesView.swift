import SwiftUI

struct CommunicationRulesView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.appLanguage) private var language
    @State private var showsAddExternalProtocol = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NavigationLink {
                    BuiltInProtocolsView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.mint)
                            .frame(width: 40, height: 40)
                            .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(language.text("内置协议"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppColor.secondary.opacity(0.7))
                    }
                    .padding(14)
                    .background(AppColor.surface.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SettingsPanel(
                    title: "外部协议",
                    icon: "person.2.wave.2",
                    headerActionTitle: "添加",
                    headerAction: { showsAddExternalProtocol = true }
                ) {
                    if store.customCommunicationRules.isEmpty {
                        ContentUnavailableView(
                            language.text("外部协议"),
                            systemImage: "doc.badge.plus",
                            description: Text(language.text("点击“添加”并输入 HTTPS 地址导入。"))
                        )
                        .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        ForEach(store.customCommunicationRules) { rule in
                            HStack(spacing: 12) {
                                ProtocolRuleLink(rule: rule)
                                Button(role: .destructive) {
                                    store.removeCommunicationRule(rule.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(language.format("删除%@", rule.name))
                            }
                            if rule.id != store.customCommunicationRules.last?.id { SettingsSeparator() }
                        }
                    }
                    Text("删除正在使用的规则后，相关设备会恢复为自动识别。社区规则不是官方兼容性承诺。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }

            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(language.text(.communicationProtocol))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .sheet(isPresented: $showsAddExternalProtocol) {
            AddExternalProtocolView()
        }
    }

}

private struct BuiltInProtocolsView: View {
    @Environment(\.appLanguage) private var language
    @State private var searchText = ""
    @State private var isSearchFocused = false

    private var filteredRules: [CommunicationRule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return CommunicationRuleCatalog.builtIn }
        return CommunicationRuleCatalog.builtIn.filter { rule in
            [
                language.text(rule.name),
                language.text(rule.summary),
                language.text(transportTitle(rule.match.transport)),
                rule.id
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppColor.secondary)
                    ResponsiveTextField(
                        text: $searchText,
                        isFocused: $isSearchFocused,
                        placeholder: "搜索内置协议",
                        returnKeyType: .search,
                        autocorrectionType: .no,
                        onSubmit: { isSearchFocused = false }
                    )
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppColor.secondary.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.text("清除搜索"))
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(AppColor.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColor.mint.opacity(0.10)))

                SettingsPanel(title: "内置协议", icon: "checkmark.seal.fill") {
                    if filteredRules.isEmpty {
                        Label("未找到匹配的内置协议", systemImage: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        ForEach(filteredRules) { rule in
                            ProtocolRuleLink(rule: rule)
                            if rule.id != filteredRules.last?.id { SettingsSeparator() }
                        }
                    }
                    Text("“内置”表示解析器已实现；具体设备是否可用仍以实机、固件和已捕获数据验证为准。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .navigationTitle("内置协议")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }
}

private struct ProtocolRuleLink: View {
    let rule: CommunicationRule

    var body: some View {
        NavigationLink {
            CommunicationRuleDetailView(rule: rule)
        } label: {
            HStack(spacing: 10) {
                ProtocolRuleRow(rule: rule)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProtocolRuleRow: View {
    @Environment(\.appLanguage) private var language
    let rule: CommunicationRule

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rule.origin == .builtIn ? language.text(rule.name) : rule.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                protocolTag(rule.origin.title, color: rule.origin == .builtIn ? AppColor.mint : AppColor.apricot)
                protocolTag(rule.effectiveVerification.title, color: verificationColor(rule.effectiveVerification))
                Spacer(minLength: 0)
            }
            Text(language.format("v%lld · %@", Int64(rule.version), language.text(transportTitle(rule.match.transport))))
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
        }
    }

    private func protocolTag(_ title: String, color: Color) -> some View {
        AppLocalizedText(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.11), in: Capsule())
    }

    private func verificationColor(_ level: ProtocolVerificationLevel) -> Color {
        switch level {
        case .standardSpecification, .hardwareSample: AppColor.mint
        case .fixtureValidated: AppColor.sky
        case .unverified: AppColor.apricot
        }
    }
}

private struct AddExternalProtocolView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var remoteURL = ""
    @State private var isRemoteURLFocused = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPanel(title: "在线导入", icon: "link.badge.plus") {
                        Text("点击导入后会检查地址、网络资源与协议格式；校验通过才会保存。")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ResponsiveTextField(
                            text: $remoteURL,
                            isFocused: $isRemoteURLFocused,
                            placeholder: "https://example.com/scaleme-protocols.json",
                            keyboardType: .URL,
                            returnKeyType: .go,
                            autocapitalizationType: .none,
                            autocorrectionType: .no,
                            spellCheckingType: .no,
                            onSubmit: importProtocol
                        )
                        .padding(12)
                        .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(errorMessage == nil ? AppColor.mint.opacity(0.18) : AppColor.rose, lineWidth: errorMessage == nil ? 1 : 1.5)
                                .allowsHitTesting(false)
                        )

                        if let errorMessage {
                            Label {
                                Text(language.text(errorMessage))
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .font(.caption)
                            .foregroundStyle(AppColor.rose)
                        }

                        Button(action: importProtocol) {
                            HStack {
                                Label("导入", systemImage: "arrow.down.doc.fill")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if isImporting {
                                    ProgressView().tint(.white)
                                }
                            }
                            .foregroundStyle(hasImportAddress ? Color.white : AppColor.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .background(
                                hasImportAddress ? AppColor.mint : AppColor.paleMint,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(hasImportAddress ? Color.clear : AppColor.secondary.opacity(0.18))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasImportAddress || isImporting)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .pageBackground()
            .navigationTitle("外部协议")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isImporting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isImporting)
                }
            }
        }
    }

    private var trimmedURL: String {
        remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasImportAddress: Bool {
        !trimmedURL.isEmpty
    }

    private func importProtocol() {
        KeyboardFocus.dismiss()
        errorMessage = nil
        guard let url = URL(string: trimmedURL), url.scheme?.lowercased() == "https" else {
            errorMessage = CommunicationRuleError.unsupportedRemoteURL.localizedDescription
            return
        }

        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let resolvedURL = http.url,
                      resolvedURL.scheme?.lowercased() == "https" else {
                    throw URLError(.badServerResponse)
                }
                var data = Data()
                data.reserveCapacity(max(0, min(Int(http.expectedContentLength), 512 * 1024)))
                for try await byte in bytes {
                    guard data.count < 512 * 1024 else {
                        throw CommunicationRuleError.responseTooLarge
                    }
                    data.append(byte)
                }
                _ = try store.importCommunicationRules(data, sourceURL: resolvedURL)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct CommunicationRuleDetailView: View {
    @Environment(\.appLanguage) private var language
    let rule: CommunicationRule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "规则", icon: "doc.text.fill") {
                    SettingsValueRow(title: "名称", value: rule.name)
                    Divider()
                    SettingsValueRow(title: "ID", value: rule.id)
                    Divider()
                    SettingsValueRow(title: "版本", value: String(rule.version))
                    Divider()
                    SettingsValueRow(title: "来源", value: language.text(rule.origin.title))
                    Divider()
                    SettingsValueRow(
                        title: "验证状态",
                        value: language.text(rule.effectiveVerification.title)
                    )
                    if let author = rule.author {
                        Divider()
                        SettingsValueRow(title: "作者", value: author)
                    }
                    if let sourceURL = rule.sourceURL {
                        Divider()
                        Link(destination: sourceURL) {
                            Label("打开来源地址", systemImage: "arrow.up.right.square")
                        }
                    }
                }

                SettingsPanel(title: "传输匹配", icon: "antenna.radiowaves.left.and.right") {
                    SettingsValueRow(title: "方式", value: language.text(transportTitle(rule.match.transport)))
                    Divider()
                    SettingsValueRow(title: "服务 UUID", value: rule.match.serviceUUID)
                    if let characteristic = rule.match.characteristicUUID {
                        Divider()
                        SettingsValueRow(title: "特征 UUID", value: characteristic)
                    }
                    Divider()
                    SettingsValueRow(title: "长度", value: lengthDescription(rule.match))
                    if let prefix = rule.match.prefixHex {
                        Divider()
                        SettingsValueRow(title: "帧前缀", value: prefix)
                    }
                }

                SettingsPanel(title: "说明", icon: "info.circle.fill") {
                    Text(rule.origin == .builtIn ? language.text(rule.summary) : rule.summary)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.ink)
                        .lineSpacing(3)
                    if rule.origin != .builtIn {
                        Label("该规则未经观我硬件验证，结果仅供协议调试和趋势参考。", systemImage: "exclamationmark.shield")
                            .font(.caption)
                            .foregroundStyle(AppColor.apricot)
                    }
                }

                if !rule.capabilities.isEmpty {
                    SettingsPanel(title: "设备操作", icon: "arrow.left.arrow.right") {
                        if rule.capabilities.contains(.historyRead) {
                            SettingsValueRow(title: "历史记录", value: "支持读取")
                        }
                        if rule.capabilities.contains(.historyClear) {
                            if rule.capabilities.contains(.historyRead) { Divider() }
                            SettingsValueRow(title: "清除设备历史", value: "破坏性操作")
                        }
                        Text("操作受超时、响应字节数和最大记录数限制；清除命令不会自动运行。")
                            .font(.caption2)
                            .foregroundStyle(AppColor.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("协议详情")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }

    private func lengthDescription(_ match: CommunicationRuleMatch) -> String {
        match.maximumLength.map {
            language.format("%lld…%lld 字节", Int64(match.minimumLength), Int64($0))
        } ?? language.format("至少 %lld 字节", Int64(match.minimumLength))
    }
}


private func transportTitle(_ transport: CommunicationTransport) -> String {
    switch transport {
    case .advertisementServiceData: "服务广播数据"
    case .advertisementManufacturerData: "厂商广播数据"
    case .characteristicNotification: "GATT 特征通知"
    }
}
