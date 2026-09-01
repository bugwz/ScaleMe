import SwiftUI

struct CommunicationRulesView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.appLanguage) private var language
    @State private var remoteURL = ""
    @State private var isRemoteURLFocused = false
    @State private var isImportingRemote = false
    @State private var showsJSONImporter = false
    @State private var message: ImportMessage?

    private struct ImportMessage: Identifiable {
        let id = UUID()
        var title: String
        var detail: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "内置协议", icon: "checkmark.seal.fill") {
                    ForEach(CommunicationRuleCatalog.builtIn) { rule in
                        ruleLink(rule)
                        if rule.id != CommunicationRuleCatalog.builtIn.last?.id { SettingsSeparator() }
                    }
                    Text("“内置”表示解析器已实现；具体设备是否可用仍以实机、固件和已捕获数据验证为准。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }

                SettingsPanel(title: "外部协议", icon: "person.2.wave.2") {
                    if store.customCommunicationRules.isEmpty {
                        ContentUnavailableView(
                            "尚无外部规则",
                            systemImage: "doc.badge.plus",
                            description: Text("可粘贴 JSON，或从可信的 HTTPS 地址拉取。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        ForEach(store.customCommunicationRules) { rule in
                            HStack(spacing: 12) {
                                ruleLink(rule)
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

                SettingsPanel(title: "在线导入", icon: "link.badge.plus") {
                    ResponsiveTextField(
                        text: $remoteURL,
                        isFocused: $isRemoteURLFocused,
                        placeholder: "https://example.com/scaleme-rules.json",
                        keyboardType: .URL,
                        returnKeyType: .done,
                        autocapitalizationType: .none,
                        autocorrectionType: .no,
                        spellCheckingType: .no,
                        onSubmit: { isRemoteURLFocused = false }
                    )
                        .padding(12)
                        .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColor.mint.opacity(0.18))
                                .allowsHitTesting(false)
                        )

                    Button {
                        importRemoteRules()
                    } label: {
                        HStack {
                            Label("拉取并校验规则", systemImage: "arrow.down.doc")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                            if isImportingRemote { ProgressView().tint(.white) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImportingRemote)
                }

                SettingsPanel(title: "开发工具", icon: "wrench.and.screwdriver.fill") {
                    Button { showsJSONImporter = true } label: {
                        Label("粘贴 JSON 规则", systemImage: "curlybraces")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    SettingsSeparator()
                    NavigationLink {
                        CommunicationRuleFormatView()
                    } label: {
                        HStack {
                            Label("查看配置格式与示例", systemImage: "doc.text.magnifyingglass")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }
                    }
                    Text("外部规则是受限的声明式协议：不能执行脚本；GATT 写入只能访问规则声明且设备实际公开的特征。破坏性操作必须单独声明并由用户确认。单个文件最大 512 KB。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle("通信规则")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showsJSONImporter) {
            CommunicationRuleJSONImporter()
        }
        .alert(item: $message) { item in
            Alert(
                title: Text(language.text(item.title)),
                message: Text(language.text(item.detail)),
                dismissButton: .default(Text(language.text("好")))
            )
        }
    }

    private func ruleLink(_ rule: CommunicationRule) -> some View {
        NavigationLink {
            CommunicationRuleDetailView(rule: rule)
        } label: {
            HStack(spacing: 10) {
                ruleRow(rule)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func ruleRow(_ rule: CommunicationRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rule.origin == .builtIn ? language.text(rule.name) : rule.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                protocolTag(
                    rule.origin.title,
                    color: rule.origin == .builtIn ? AppColor.mint : AppColor.apricot
                )
                protocolTag(
                    rule.effectiveVerification.title,
                    color: verificationColor(rule.effectiveVerification)
                )
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

    private func importRemoteRules() {
        let text = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), url.scheme?.lowercased() == "https" else {
            message = .init(title: "地址不可用", detail: CommunicationRuleError.unsupportedRemoteURL.localizedDescription)
            return
        }
        isImportingRemote = true
        Task {
            defer { isImportingRemote = false }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      http.url?.scheme?.lowercased() == "https" else {
                    throw URLError(.badServerResponse)
                }
                let count = try store.importCommunicationRules(data, sourceURL: url)
                remoteURL = ""
                message = .init(
                    title: "导入完成",
                    detail: language.format(
                        "已校验并保存 %lld 条社区规则。请在具体设备的“协议匹配”中选择。",
                        Int64(count)
                    )
                )
            } catch {
                message = .init(title: "导入失败", detail: error.localizedDescription)
            }
        }
    }
}

private struct CommunicationRuleJSONImporter: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var json = CommunicationRuleFormatView.exampleJSON
    @State private var errorMessage: String?
    @State private var isJSONFocused = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("粘贴完整的 ScaleMe 通信规则文件。示例可直接修改。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                ResponsiveTextEditor(
                    text: $json,
                    isFocused: $isJSONFocused,
                    autocapitalizationType: .none,
                    autocorrectionType: .no,
                    spellCheckingType: .no,
                    usesMonospacedFont: true,
                    showsDoneAccessory: true
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 280)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColor.mint.opacity(0.18))
                            .allowsHitTesting(false)
                    )
                if let errorMessage {
                    Label {
                        Text(language.text(errorMessage))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                        .font(.caption)
                        .foregroundStyle(AppColor.rose)
                }
            }
            .padding()
            .pageBackground()
            .navigationTitle("导入 JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        do {
                            _ = try store.importCommunicationRules(Data(json.utf8))
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
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

private struct CommunicationRuleFormatView: View {
    static let exampleJSON = #"""
    {
      "schemaVersion" : 2,
      "rules" : [
        {
          "id" : "protocol.custom.example",
          "name" : "示例非标准体重秤",
          "version" : 1,
          "summary" : "示例：FFB0 服务的 FFB2 通知，体重位于第 3、4 字节。",
          "author" : "Community",
          "origin" : "custom",
          "match" : {
            "transport" : "characteristicNotification",
            "serviceUUID" : "FFB0",
            "characteristicUUID" : "FFB2",
            "minimumLength" : 5,
            "maximumLength" : 20,
            "prefixHex" : "AC29"
          },
          "decoder" : {
            "weight" : {
              "offset" : 2,
              "length" : 2,
              "byteOrder" : "bigEndian",
              "scale" : 0.01,
              "add" : 0
            },
            "weightUnit" : "kilograms",
            "stableWhen" : {
              "offset" : 4,
              "mask" : 1,
              "equals" : 1
            }
          },
          "operations" : {
            "historyRead" : {
              "capability" : "historyRead",
              "destructive" : false,
              "subscriptions" : [
                { "serviceUUID" : "FFB0", "characteristicUUID" : "FFB3" }
              ],
              "commands" : [
                {
                  "target" : { "serviceUUID" : "FFB0", "characteristicUUID" : "FFB1" },
                  "payloadHexTemplate" : "F200",
                  "writeMode" : "withResponse"
                }
              ],
              "completionCommands" : [],
              "acknowledgementCommands" : [],
              "historyResponse" : {
                "recordMatcher" : {
                  "target" : { "serviceUUID" : "FFB0", "characteristicUUID" : "FFB3" },
                  "minimumLength" : 1,
                  "maximumLength" : 100
                },
                "completionMatcher" : {
                  "target" : { "serviceUUID" : "FFB0", "characteristicUUID" : "FFB3" },
                  "minimumLength" : 2,
                  "maximumLength" : 2,
                  "exactHex" : "F200"
                },
                "framing" : "fixedLength",
                "recordLength" : 10,
                "decoder" : {
                  "weight" : { "offset" : 0, "length" : 2, "byteOrder" : "bigEndian", "scale" : 0.01 },
                  "weightUnit" : "kilograms",
                  "date" : {
                    "year" : { "offset" : 2, "length" : 2, "byteOrder" : "bigEndian", "scale" : 1 },
                    "month" : { "offset" : 4, "length" : 1, "byteOrder" : "bigEndian", "scale" : 1 },
                    "day" : { "offset" : 5, "length" : 1, "byteOrder" : "bigEndian", "scale" : 1 },
                    "hour" : { "offset" : 6, "length" : 1, "byteOrder" : "bigEndian", "scale" : 1 },
                    "minute" : { "offset" : 7, "length" : 1, "byteOrder" : "bigEndian", "scale" : 1 },
                    "second" : { "offset" : 8, "length" : 1, "byteOrder" : "bigEndian", "scale" : 1 }
                  }
                }
              },
              "timeoutSeconds" : 15,
              "maximumResponseBytes" : 65536,
              "maximumRecords" : 512
            }
          }
        }
      ]
    }
    """#

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("格式版本 2")
                    .font(.title3.bold())
                Text("规则先匹配传输方式、服务/特征 UUID、长度和可选帧前缀，再按无符号整数字段读取测量值。operations 可声明历史读取或清除：命令只能写入声明的 GATT 目标，支持受限时间/会话字段，并强制设置超时、最大响应字节数和记录数。historyClear 必须标记 destructive，应用不会自动运行。")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.secondary)
                    .lineSpacing(3)
                Text(Self.exampleJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                ShareLink(item: Self.exampleJSON) {
                    Label("分享示例 JSON", systemImage: "square.and.arrow.up")
                }
            }
            .padding()
        }
        .pageBackground()
        .navigationTitle("规则配置格式")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }
}

private func transportTitle(_ transport: CommunicationTransport) -> String {
    switch transport {
    case .advertisementServiceData: "服务广播数据"
    case .advertisementManufacturerData: "厂商广播数据"
    case .characteristicNotification: "GATT 特征通知"
    }
}
