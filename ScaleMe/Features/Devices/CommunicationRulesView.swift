import SwiftUI
import UniformTypeIdentifiers

struct CommunicationRulesView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.appLanguage) private var language
    @State private var showsAddExternalProtocol = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "内置协议", icon: "checkmark.seal.fill") {
                    builtInGroupLink(
                        title: "可执行协议",
                        detail: "已实现并验证",
                        icon: "checkmark.circle.fill",
                        color: AppColor.mint,
                        rules: CommunicationRuleCatalog.confirmedExecutableBuiltIn
                    )
                    SettingsSeparator()
                    builtInGroupLink(
                        title: "待完善协议",
                        detail: "待完善或验证",
                        icon: "wrench.and.screwdriver.fill",
                        color: AppColor.apricot,
                        rules: CommunicationRuleCatalog.pendingBuiltIn
                    )
                }

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
                            description: Text(language.text("点击“添加”并选择本地协议文件导入。"))
                        )
                        .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        ForEach(store.customCommunicationRules) { rule in
                            ProtocolRuleLink(rule: rule)
                            if rule.id != store.customCommunicationRules.last?.id { SettingsSeparator() }
                        }
                    }
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

    private func builtInGroupLink(
        title: String,
        detail: String,
        icon: String,
        color: Color,
        rules: [CommunicationRule]
    ) -> some View {
        NavigationLink {
            BuiltInProtocolsView(title: title, icon: icon, iconColor: color, rules: rules)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text(title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    Text(language.text(detail))
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(String(rules.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColor.canvas, in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.secondary.opacity(0.7))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BuiltInProtocolsView: View {
    @Environment(\.appLanguage) private var language
    @State private var searchText = ""
    @State private var isSearchFocused = false
    let title: String
    let icon: String
    let iconColor: Color
    let rules: [CommunicationRule]

    private var filteredRules: [CommunicationRule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rules }
        return rules.filter { rule in
            [
                rule.name,
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
                        autocorrectionType: .no
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

                SettingsPanel(
                    title: title,
                    icon: icon,
                    iconColor: iconColor,
                    iconBackgroundColor: iconColor.opacity(0.11),
                    headerValue: String(rules.count)
                ) {
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
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .navigationTitle(language.text(title))
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
            Text(rule.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            CommunicationRuleTags(rule: rule)
        }
    }
}

struct CommunicationRuleTags: View {
    let rule: CommunicationRule

    var body: some View {
        HStack(spacing: 6) {
            protocolTag(transportTitle(rule.match.transport), color: transportColor(rule.match.transport))
            protocolTag(rule.effectiveImplementation.title, color: implementationColor(rule.effectiveImplementation))
            protocolTag(rule.effectiveVerification.title, color: verificationColor(rule.effectiveVerification))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
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
        case .standardSpecification: AppColor.mint
        case .fixtureValidated: AppColor.sky
        case .unverified: AppColor.apricot
        }
    }

    private func implementationColor(_ level: ProtocolImplementationLevel) -> Color {
        switch level {
        case .executable: AppColor.mint
        case .experimental: AppColor.sky
        case .protocolSkeleton: AppColor.apricot
        }
    }

    private func transportColor(_ transport: CommunicationTransport) -> Color {
        switch transport {
        case .characteristicNotification: AppColor.mint
        case .advertisementServiceData: AppColor.sky
        case .advertisementManufacturerData: AppColor.violet
        }
    }
}

private struct AddExternalProtocolView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsFileImporter = false
    @State private var selectedFileName: String?
    @State private var selectedData: Data?
    @State private var parsedRules: [CommunicationRule] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    selectFileButton
                    parsedContentBox
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .navigationTitle("外部协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                importFooter
            }
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: store.isSimulationEnabled ? [.item] : [.json],
                allowsMultipleSelection: false,
                onCompletion: selectFile
            )
        }
    }

    private var selectFileButton: some View {
        Button {
            showsFileImporter = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 3) {
                    AppLocalizedText("选择文件")
                        .font(.subheadline.weight(.semibold))
                    if let selectedFileName {
                        Text(selectedFileName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .foregroundStyle(AppColor.mint)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(AppColor.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppColor.mint.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }

    private var parsedContentBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                AppLocalizedText("解析后的协议内容")
            } icon: {
                Image(systemName: "doc.text.magnifyingglass")
            }
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            if parsedRules.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(AppColor.secondary.opacity(0.7))
                    AppLocalizedText("选择文件后，这里会显示校验通过的协议名称、标识和通信特征。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ForEach(Array(parsedRules.enumerated()), id: \.element.id) { index, rule in
                    if index > 0 { SettingsSeparator() }
                    parsedRuleSummary(rule)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(errorMessage == nil ? AppColor.mint.opacity(0.10) : AppColor.rose.opacity(0.7), lineWidth: errorMessage == nil ? 1 : 1.5)
        )
    }

    private func parsedRuleSummary(_ rule: CommunicationRule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rule.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
            CommunicationRuleTags(rule: rule)
            SettingsValueRow(title: "ID", value: rule.id)
            SettingsSeparator()
            SettingsValueRow(title: "版本", value: String(rule.version))
            SettingsSeparator()
            SettingsValueRow(title: "服务 UUID", value: rule.match.serviceUUID)
            if let characteristicUUID = rule.match.characteristicUUID {
                SettingsSeparator()
                SettingsValueRow(title: "特征 UUID", value: characteristicUUID)
            }
            SettingsSeparator()
            SettingsValueRow(title: "解析字段", value: decodedFieldDescription(rule.decoder))
        }
        .accessibilityElement(children: .contain)
    }

    private var importFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage {
                Label {
                    Text(language.text(errorMessage))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(AppColor.rose)
            } else if parsedRules.isEmpty {
                AppLocalizedText("请先选择并校验本地协议文件。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }

            Button(action: importProtocol) {
                Label {
                    AppLocalizedText("导入")
                } icon: {
                    Image(systemName: "square.and.arrow.down.fill")
                }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canImport ? AppColor.onAccent : AppColor.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        canImport ? AppColor.mint : AppColor.paleMint,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(canImport ? Color.clear : AppColor.secondary.opacity(0.18))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canImport)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var canImport: Bool {
        selectedData != nil && !parsedRules.isEmpty && errorMessage == nil
    }

    private func selectFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            selectedFileName = url.lastPathComponent
            if store.isSimulationEnabled {
                let data = try store.simulatedCommunicationRuleImportData(fileName: url.lastPathComponent)
                let rules = try CommunicationRuleCodec.decode(data)
                selectedData = data
                parsedRules = rules
                errorMessage = nil
                return
            }
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
            }
            if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               fileSize > CommunicationRuleCodec.maximumDocumentBytes {
                throw CommunicationRuleError.responseTooLarge
            }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: CommunicationRuleCodec.maximumDocumentBytes + 1) ?? Data()
            let rules = try CommunicationRuleCodec.decode(data)
            selectedData = data
            parsedRules = rules
            errorMessage = nil
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            selectedData = nil
            parsedRules = []
            errorMessage = error.localizedDescription
        }
    }

    private func importProtocol() {
        guard let selectedData else { return }
        do {
            _ = try store.importCommunicationRules(selectedData)
            dismiss()
        } catch {
            self.selectedData = nil
            parsedRules = []
            errorMessage = error.localizedDescription
        }
    }

    private func decodedFieldDescription(_ decoder: CommunicationRuleDecoder?) -> String {
        guard let decoder else { return language.text("设备操作") }
        var fields = [language.text("体重")]
        let optionalFields: [(CommunicationField?, String)] = [
            (decoder.impedance, "阻抗"),
            (decoder.bodyFatPercent, "体脂率"),
            (decoder.muscleMassKG, "肌肉量"),
            (decoder.waterPercent, "身体水分"),
            (decoder.visceralFat, "内脏脂肪"),
            (decoder.basalMetabolismKCal, "基础代谢"),
            (decoder.boneMassKG, "骨量")
        ]
        for (field, title) in optionalFields where field != nil {
            fields.append(language.text(title))
        }
        if decoder.date != nil {
            fields.append(language.text("时间"))
        }
        return fields.joined(separator: " · ")
    }
}

private struct CommunicationRuleDetailView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion = false
    let rule: CommunicationRule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "协议信息", icon: "doc.text.fill") {
                    ProtocolDetailValueRow(title: "名称", value: rule.name)
                    Divider()
                    ProtocolDetailValueRow(title: "ID", value: rule.id)
                    Divider()
                    ProtocolDetailValueRow(title: "版本", value: String(rule.version))
                    Divider()
                    ProtocolDetailValueRow(title: "来源", value: language.text(rule.origin.title))
                    Divider()
                    ProtocolDetailValueRow(
                        title: "实现状态",
                        value: language.text(rule.effectiveImplementation.title)
                    )
                    Divider()
                    ProtocolDetailValueRow(
                        title: "验证状态",
                        value: language.text(rule.effectiveVerification.title)
                    )
                    if let models = rule.supportedModels, !models.isEmpty {
                        Divider()
                        ProtocolDetailValueRow(title: "支持型号", value: models.joined(separator: " · "))
                    }
                }

                SettingsPanel(title: "协议特征", icon: "antenna.radiowaves.left.and.right") {
                    featureSection(
                        title: "传输特征",
                        showsSeparator: false
                    ) {
                        matchRows(rule.match)
                    }

                    if let alternates = rule.alternateMatches, !alternates.isEmpty {
                        featureSection(title: "备用特征") {
                            ForEach(Array(alternates.enumerated()), id: \.offset) { index, match in
                                if index > 0 { SettingsSeparator() }
                                matchRows(match)
                            }
                        }
                    }

                    if let notifyTargets = rule.notifyTargets, !notifyTargets.isEmpty {
                        featureSection(title: "订阅特征") {
                            targetRows(notifyTargets)
                        }
                    }

                    if let writeTargets = rule.writeTargets, !writeTargets.isEmpty {
                        featureSection(title: "写入特征") {
                            targetRows(writeTargets)
                        }
                    }

                    if let requirements = rule.requirements, !requirements.isEmpty {
                        featureSection(title: "运行要求") {
                            ForEach(Array(requirements.enumerated()), id: \.offset) { index, requirement in
                                if index > 0 { SettingsSeparator() }
                                Text(language.text(requirement.title))
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.ink)
                            }
                        }
                    }

                    if !rule.capabilities.isEmpty {
                        featureSection(title: "设备操作") {
                            if rule.capabilities.contains(.historyRead) {
                                ProtocolDetailValueRow(title: "历史记录", value: language.text("支持读取"))
                            }
                            if rule.capabilities.contains(.historyClear) {
                                if rule.capabilities.contains(.historyRead) { SettingsSeparator() }
                                ProtocolDetailValueRow(title: "清除设备历史", value: language.text("破坏性操作"))
                            }
                            AppLocalizedText("操作受超时、响应字节数和最大记录数限制；清除命令不会自动运行。")
                                .font(.caption2)
                                .foregroundStyle(AppColor.secondary)
                        }
                    }
                }

                SettingsPanel(title: "说明", icon: "info.circle.fill") {
                    Text(explanationText)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.ink)
                        .lineSpacing(3)
                    if rule.origin != .builtIn {
                        Label {
                            AppLocalizedText("该规则尚未通过硬件验证，结果仅供协议调试和趋势参考。")
                        } icon: {
                            Image(systemName: "exclamationmark.shield")
                        }
                            .font(.caption)
                            .foregroundStyle(AppColor.apricot)
                    }
                    if !rule.canMeasure {
                        Label {
                            Text(language.text("该项已纳入内置协议目录，但运行时解析或会话状态机尚未完整移植，暂不可用于测量。"))
                        } icon: {
                            Image(systemName: "hammer.fill")
                        }
                            .font(.caption)
                            .foregroundStyle(AppColor.apricot)
                    }
                }

                if rule.origin == .custom {
                    Button(role: .destructive, action: showDeleteConfirmation) {
                        Label {
                            AppLocalizedText("删除协议")
                        } icon: {
                            Image(systemName: "trash")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.rose)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            AppColor.rose.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    AppLocalizedText("删除后，使用该协议的设备会恢复为自动识别。")
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(language.text("协议详情"))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .accessibilityHidden(confirmsDeletion)
        .overlay {
            if confirmsDeletion {
                DestructiveConfirmationOverlay(
                    icon: "doc.badge.minus",
                    title: "删除外部协议？",
                    message: language.format(
                        "将删除“%@”。使用该协议的设备会恢复为自动识别。",
                        rule.name
                    ),
                    confirmTitle: "删除协议",
                    onCancel: hideDeleteConfirmation,
                    onConfirm: deleteRule
                )
                .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(confirmsDeletion)
    }

    private func showDeleteConfirmation() {
        withAnimation(.easeOut(duration: 0.12)) {
            confirmsDeletion = true
        }
    }

    private func hideDeleteConfirmation() {
        withAnimation(.easeOut(duration: 0.12)) {
            confirmsDeletion = false
        }
    }

    private func deleteRule() {
        confirmsDeletion = false
        store.removeCommunicationRule(rule.id)
        dismiss()
    }

    private func lengthDescription(_ match: CommunicationRuleMatch) -> String {
        match.maximumLength.map {
            language.format("%lld…%lld 字节", Int64(match.minimumLength), Int64($0))
        } ?? language.format("至少 %lld 字节", Int64(match.minimumLength))
    }

    private var repositoryNames: [String]? {
        if let sourceLinks = rule.sourceLinks, !sourceLinks.isEmpty {
            return Array(Set(sourceLinks.map(\.project))).sorted()
        }
        guard
            let sourceURL = rule.sourceURL,
            sourceURL.host?.lowercased() == "github.com",
            sourceURL.pathComponents.count > 2
        else {
            return nil
        }
        return [sourceURL.pathComponents[2]]
    }

    private var explanationText: String {
        let summary = rule.origin == .builtIn ? language.text(rule.summary) : rule.summary
        guard let repositoryNames, !repositoryNames.isEmpty else { return summary }
        let reference = language.format(
            "该协议资料参考 %@ 项目。",
            repositoryNames.joined(separator: ", ")
        )
        return "\(summary) \(reference)"
    }

    private func featureSection<Content: View>(
        title: String,
        showsSeparator: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSeparator {
                SettingsSeparator()
                    .padding(.vertical, 2)
            }

            AppLocalizedText(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }

    private func matchRows(_ match: CommunicationRuleMatch) -> some View {
        Group {
            ProtocolDetailValueRow(title: "方式", value: language.text(transportTitle(match.transport)))
            SettingsSeparator()
            uuidRow(title: "服务 UUID", value: match.serviceUUID)
            if let characteristic = match.characteristicUUID {
                SettingsSeparator()
                uuidRow(title: "特征 UUID", value: characteristic)
            }
            SettingsSeparator()
            ProtocolDetailValueRow(title: "长度", value: lengthDescription(match))
            if let prefix = match.prefixHex {
                SettingsSeparator()
                ProtocolDetailValueRow(title: "帧前缀", value: prefix, usesMonospacedFont: true)
            }
        }
    }

    private func targetRows(_ targets: [CommunicationGATTTarget]) -> some View {
        ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
            if index > 0 { SettingsSeparator() }
            VStack(alignment: .leading, spacing: 10) {
                uuidRow(title: "特征 UUID", value: target.characteristicUUID)
                SettingsSeparator()
                uuidRow(title: "服务 UUID", value: target.serviceUUID)
            }
        }
    }

    private func uuidRow(title: String, value: String) -> some View {
        ProtocolDetailValueRow(title: title, value: value, usesMonospacedFont: true)
    }
}

private struct ProtocolDetailValueRow: View {
    let title: String
    let value: String
    var usesMonospacedFont = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AppLocalizedText(title)
                .font(.caption)
                .foregroundStyle(AppColor.secondary)

            Text(value)
                .font(usesMonospacedFont ? .subheadline.monospaced() : .subheadline)
                .foregroundStyle(AppColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private func transportTitle(_ transport: CommunicationTransport) -> String {
    switch transport {
    case .advertisementServiceData: "服务广播数据"
    case .advertisementManufacturerData: "厂商广播数据"
    case .characteristicNotification: "GATT特征通知"
    }
}
