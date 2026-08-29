import SwiftUI

struct CommunicationRulesView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var remoteURL = ""
    @State private var isImportingRemote = false
    @State private var showsJSONImporter = false
    @State private var message: ImportMessage?

    private struct ImportMessage: Identifiable {
        let id = UUID()
        var title: String
        var detail: String
    }

    var body: some View {
        Form {
            Section {
                ForEach(CommunicationRuleCatalog.builtIn) { rule in
                    NavigationLink {
                        CommunicationRuleDetailView(rule: rule)
                    } label: {
                        ruleRow(rule)
                    }
                }
            } header: {
                Text("应用已支持")
            } footer: {
                Text("“应用内置”表示解析器已经实现；具体设备是否可用仍以实机、固件和已捕获数据验证为准。")
            }

            Section {
                if store.customCommunicationRules.isEmpty {
                    ContentUnavailableView(
                        "尚无外部规则",
                        systemImage: "doc.badge.plus",
                        description: Text("可粘贴 JSON，或从可信的 HTTPS 地址拉取社区规则。")
                    )
                } else {
                    ForEach(store.customCommunicationRules) { rule in
                        NavigationLink {
                            CommunicationRuleDetailView(rule: rule)
                        } label: {
                            ruleRow(rule)
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                store.removeCommunicationRule(rule.id)
                            }
                        }
                    }
                }
            } header: {
                Text("自定义与社区规则")
            } footer: {
                Text("删除正在使用的规则后，相关设备会恢复为自动识别。社区规则不是官方兼容性承诺。")
            }

            Section("从远程地址导入") {
                TextField("https://example.com/scaleme-rules.json", text: $remoteURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                Button {
                    importRemoteRules()
                } label: {
                    HStack {
                        Label("拉取并校验规则", systemImage: "arrow.down.doc")
                        Spacer()
                        if isImportingRemote { ProgressView().tint(AppColor.mint) }
                    }
                }
                .disabled(remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImportingRemote)
            }

            Section {
                Button { showsJSONImporter = true } label: {
                    Label("粘贴 JSON 规则", systemImage: "curlybraces")
                }
                NavigationLink {
                    CommunicationRuleFormatView()
                } label: {
                    Label("查看配置格式与示例", systemImage: "doc.text.magnifyingglass")
                }
            } header: {
                Text("开发与调试")
            } footer: {
                Text("外部规则是受限的声明式字节映射，不能执行脚本，也不能主动写入体重秤。单个文件最大 512 KB。")
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("通信协议")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsJSONImporter) {
            CommunicationRuleJSONImporter()
        }
        .alert(item: $message) { item in
            Alert(title: Text(item.title), message: Text(item.detail), dismissButton: .default(Text("好")))
        }
    }

    private func ruleRow(_ rule: CommunicationRule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rule.name)
                Spacer()
                Text(rule.origin.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(rule.origin == .builtIn ? AppColor.mint : AppColor.apricot)
            }
            Text("v\(rule.version) · \(transportTitle(rule.match.transport))")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
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
                message = .init(title: "导入完成", detail: "已校验并保存 \(count) 条社区规则。请在具体设备的“协议匹配”中选择。")
            } catch {
                message = .init(title: "导入失败", detail: error.localizedDescription)
            }
        }
    }
}

private struct CommunicationRuleJSONImporter: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var json = CommunicationRuleFormatView.exampleJSON
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("粘贴完整的 ScaleMe 通信规则文件。示例可直接修改。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                TextEditor(text: $json)
                    .font(.system(.caption, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.mint.opacity(0.18)))
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
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
    let rule: CommunicationRule

    var body: some View {
        Form {
            Section("规则") {
                LabeledContent("名称", value: rule.name)
                LabeledContent("ID", value: rule.id)
                LabeledContent("版本", value: String(rule.version))
                LabeledContent("来源", value: rule.origin.title)
                if let author = rule.author { LabeledContent("作者", value: author) }
                if let sourceURL = rule.sourceURL {
                    Link("打开来源地址", destination: sourceURL)
                }
            }
            Section("传输匹配") {
                LabeledContent("方式", value: transportTitle(rule.match.transport))
                LabeledContent("服务 UUID", value: rule.match.serviceUUID)
                if let characteristic = rule.match.characteristicUUID {
                    LabeledContent("特征 UUID", value: characteristic)
                }
                LabeledContent("长度", value: lengthDescription(rule.match))
                if let prefix = rule.match.prefixHex { LabeledContent("帧前缀", value: prefix) }
            }
            Section("说明") {
                Text(rule.summary)
                if rule.origin != .builtIn {
                    Label("该规则未经观我硬件验证，结果仅供协议调试和趋势参考。", systemImage: "exclamationmark.shield")
                        .font(.caption)
                        .foregroundStyle(AppColor.apricot)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("协议详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lengthDescription(_ match: CommunicationRuleMatch) -> String {
        match.maximumLength.map { "\(match.minimumLength)…\($0) 字节" } ?? "至少 \(match.minimumLength) 字节"
    }
}

private struct CommunicationRuleFormatView: View {
    static let exampleJSON = #"""
    {
      "schemaVersion" : 1,
      "rules" : [
        {
          "id" : "community.example.scale-v1",
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
          }
        }
      ]
    }
    """#

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("格式版本 1")
                    .font(.title3.bold())
                Text("规则先匹配传输方式、服务/特征 UUID、长度和可选帧前缀，再按无符号整数字段读取体重及可选身体成分。offset 从 0 开始，length 支持 1 至 8 字节。scale 和 add 的计算顺序为 raw × scale + add。")
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
    }
}

private func transportTitle(_ transport: CommunicationTransport) -> String {
    switch transport {
    case .advertisementServiceData: "服务广播数据"
    case .characteristicNotification: "GATT 特征通知"
    }
}
