import SwiftUI
import UniformTypeIdentifiers

private enum DisplaySettingsDropdown: Equatable {
    case visualTheme
    case appearance
    case language
    case weightUnit
}

struct DisplaySettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var expandedDropdown: DisplaySettingsDropdown?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                interfaceDisplayPanel
                dataDisplayPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.displaySettings))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .accessibilityHidden(expandedDropdown != nil)
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    switch expandedDropdown {
                    case .visualTheme:
                        AppDropdownMenuLayer(
                            anchorFrame: proxy[anchor],
                            availableSize: proxy.size,
                            options: AppVisualTheme.allCases,
                            isSelected: { $0 == store.visualTheme },
                            title: { title(for: $0) },
                            appearance: .compact,
                            onSelect: { theme in
                                store.visualTheme = theme
                                dismissDropdown()
                            },
                            onDismiss: dismissDropdown
                        )
                    case .appearance:
                        AppDropdownMenuLayer(
                            anchorFrame: proxy[anchor],
                            availableSize: proxy.size,
                            options: AppAppearance.allCases,
                            isSelected: { $0 == store.appearance },
                            title: { title(for: $0) },
                            appearance: .compact,
                            onSelect: { appearance in
                                store.appearance = appearance
                                dismissDropdown()
                            },
                            onDismiss: dismissDropdown
                        )
                    case .language:
                        AppDropdownMenuLayer(
                            anchorFrame: proxy[anchor],
                            availableSize: proxy.size,
                            options: AppLanguageSelection.allCases,
                            isSelected: { $0 == store.languageSelection },
                            title: { title(for: $0) },
                            appearance: .compact,
                            onSelect: { selection in
                                store.languageSelection = selection
                                dismissDropdown()
                            },
                            onDismiss: dismissDropdown
                        )
                    case .weightUnit:
                        AppDropdownMenuLayer(
                            anchorFrame: proxy[anchor],
                            availableSize: proxy.size,
                            options: WeightUnit.allCases,
                            isSelected: { $0 == store.unit },
                            title: { $0.settingsTitle },
                            appearance: .compact,
                            onSelect: { unit in
                                store.unit = unit
                                dismissDropdown()
                            },
                            onDismiss: dismissDropdown
                        )
                    case nil:
                        EmptyView()
                    }
                }
            }
        }
        .onDisappear { expandedDropdown = nil }
    }

    private var interfaceDisplayPanel: some View {
        SettingsPanel(title: "界面显示", icon: "paintpalette.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.appLanguage.text(.visualTheme))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppDropdownField(
                    value: visualThemeTitle,
                    icon: "eye.fill",
                    accessibilityLabel: store.appLanguage.text(.visualTheme),
                    isExpanded: expandedDropdown == .visualTheme,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.visualTheme) }
                )
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 10) {
                Text(store.appLanguage.text(.appearance))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppDropdownField(
                    value: appearanceTitle,
                    icon: "circle.lefthalf.filled",
                    accessibilityLabel: store.appLanguage.text(.appearance),
                    isExpanded: expandedDropdown == .appearance,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.appearance) }
                )
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 10) {
                Text(store.appLanguage.text(.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppDropdownField(
                    value: languageSelectionTitle,
                    icon: "globe",
                    accessibilityLabel: store.appLanguage.text(.language),
                    isExpanded: expandedDropdown == .language,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.language) }
                )
            }
        }
    }

    private var dataDisplayPanel: some View {
        SettingsPanel(title: "数据显示", icon: "textformat.123") {
            VStack(alignment: .leading, spacing: 10) {
                Text("体重单位")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppDropdownField(
                    value: store.unit.settingsTitle,
                    icon: "scalemass.fill",
                    accessibilityLabel: "体重单位",
                    isExpanded: expandedDropdown == .weightUnit,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.weightUnit) }
                )
            }

            SettingsSeparator()

            SettingsToggleRow(
                title: "合并连续称重",
                detail: "同一成员和设备在 30 秒内连续完成的称重，只保留最新一条。",
                isOn: $store.mergeFrequentMeasurements
            )
        }
    }

    private var languageSelectionTitle: String {
        title(for: store.languageSelection)
    }

    private var appearanceTitle: String {
        title(for: store.appearance)
    }

    private var visualThemeTitle: String {
        title(for: store.visualTheme)
    }

    private func title(for theme: AppVisualTheme) -> String {
        switch theme {
        case .standard: store.appLanguage.text(.standardTheme)
        case .colorVisionAccessible: store.appLanguage.text(.colorVisionAccessibleTheme)
        }
    }

    private func title(for selection: AppLanguageSelection) -> String {
        if selection == .system {
            return store.appLanguage.text(.followSystem)
        }
        return selection.explicitLanguage?.nativeName ?? AppLanguage.english.nativeName
    }

    private func title(for appearance: AppAppearance) -> String {
        switch appearance {
        case .system: store.appLanguage.text(.followSystem)
        case .light: store.appLanguage.text(.lightAppearance)
        case .dark: store.appLanguage.text(.darkAppearance)
        }
    }

    private func toggleDropdown(_ dropdown: DisplaySettingsDropdown) {
        KeyboardFocus.dismiss()
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedDropdown = expandedDropdown == dropdown ? nil : dropdown
        }
    }

    private func dismissDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            expandedDropdown = nil
        }
    }
}

private extension WeightUnit {
    var settingsTitle: String {
        switch self {
        case .kilograms: "千克（kg）"
        case .jin: "市斤（斤）"
        case .pounds: "磅（lb）"
        }
    }
}

private struct LocalTransferDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataManagementSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var activeAlert: DataManagementAlert?
    @State private var pendingConfiguration: AppConfiguration?
    @State private var pendingRecords: MeasurementArchive?
    @State private var selectedTransferFileKind: TransferFileKind = .combined
    @State private var selectedDeletionFileKind: DeletionFileKind? = .records
    @State private var expandedDropdown: ExpandedDropdown?
    @State private var pendingDeletionFileKind: DeletionFileKind?
    @State private var showsImporter = false
    @State private var showsExporter = false
    @State private var exportDocument = LocalTransferDocument()
    @State private var exportContentType = UTType.json
    @State private var exportFilename = "ScaleMe-Configuration.json"

    private let transferService = LocalDataTransferService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let storageError = store.storageError {
                    storageErrorBanner(storageError)
                }

                localTransferPanel
                simulationPanel
                deletionPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.dataManagement))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .accessibilityHidden(expandedDropdown != nil || pendingDeletionFileKind != nil)
        .accessibilityAnnounceChanges(store.storageError)
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.json]
        ) { result in
            importFile(result)
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                store.showOperationFeedback("文件已导出")
            case .failure(let error):
                guard !isUserCancellation(error) else { return }
                activeAlert = .message(title: "导出失败", message: error.localizedDescription)
            }
        }
        .alert(item: $activeAlert) { alert in
            alertContent(for: alert)
        }
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    switch expandedDropdown {
                    case .transfer:
                        AppDropdownMenuLayer(
                            anchorFrame: proxy[anchor],
                            availableSize: proxy.size,
                            options: TransferFileKind.allCases,
                            isSelected: { $0 == selectedTransferFileKind },
                            title: { $0.title },
                            appearance: .compact,
                            onSelect: { fileKind in
                                selectedTransferFileKind = fileKind
                                dismissDropdown()
                            },
                            onDismiss: dismissDropdown
                        )
                    case .deletion:
                        AppDropdownMenuLayer(
                            anchorFrame: proxy[anchor],
                            availableSize: proxy.size,
                            options: DeletionFileKind.allCases,
                            isSelected: { $0 == selectedDeletionFileKind },
                            title: { $0.title },
                            appearance: .compact,
                            onSelect: { fileKind in
                                selectedDeletionFileKind = fileKind
                                dismissDropdown()
                            },
                            onDismiss: dismissDropdown
                        )
                    case nil:
                        EmptyView()
                    }
                }
            }
        }
        .overlay {
            if let pendingDeletionFileKind {
                DestructiveConfirmationOverlay(
                    icon: "trash.fill",
                    title: pendingDeletionFileKind.confirmationTitle,
                    message: pendingDeletionFileKind.confirmationMessage,
                    confirmTitle: "确认删除",
                    countdownSeconds: 10,
                    onCancel: { self.pendingDeletionFileKind = nil },
                    onConfirm: { delete(pendingDeletionFileKind) }
                )
                .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(pendingDeletionFileKind != nil)
        .onDisappear { expandedDropdown = nil }
    }

    private var localTransferPanel: some View {
        SettingsPanel(title: "导入/导出", icon: "arrow.up.arrow.down.square") {
            AppDropdownField(
                value: selectedTransferFileKind.title,
                icon: selectedTransferFileKind.icon,
                accessibilityLabel: "导入/导出",
                isExpanded: expandedDropdown == .transfer,
                appearance: .compact,
                onToggle: toggleTransferDropdown
            )

            Label(selectedTransferFileKind.detail, systemImage: selectedTransferFileKind.icon)
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 10) {
                transferButton(title: "导入", icon: "square.and.arrow.down", action: importFile)
                transferButton(title: "导出", icon: "square.and.arrow.up", action: exportFile)
            }
        }
    }

    private func transferButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                AppLocalizedText(title)
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.mint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var simulationPanel: some View {
        SettingsPanel(title: "数据模拟", icon: "sparkles") {
            SettingsToggleRow(
                title: "启用模拟数据",
                detail: "在整个应用中使用模拟成员、设备和近一年记录，不影响真实数据。",
                isOn: $store.isSimulationEnabled
            )

            if store.isSimulationEnabled {
                Label("模拟模式下的修改仅保留到本次运行结束；下次启动会恢复预设数据。", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isSimulationEnabled)
    }

    private var deletionPanel: some View {
        SettingsPanel(title: "数据删除", icon: "trash.fill") {
            AppDropdownField(
                value: selectedDeletionFileKind?.title ?? "请选择要删除的内容",
                icon: selectedDeletionFileKind?.icon ?? "doc.badge.minus",
                accessibilityLabel: "数据删除",
                isExpanded: expandedDropdown == .deletion,
                appearance: .compact,
                onToggle: toggleDeletionDropdown
            )

            Label(
                selectedDeletionFileKind?.detail ?? "选择要永久删除的本地文件。",
                systemImage: selectedDeletionFileKind?.icon ?? "info.circle.fill"
            )
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.rose.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            Button {
                guard let selectedDeletionFileKind else { return }
                dismissDropdown()
                pendingDeletionFileKind = selectedDeletionFileKind
            } label: {
                Label {
                    AppLocalizedText("删除所选内容")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(MintActionButtonStyle(isDestructive: true))
            .disabled(selectedDeletionFileKind == nil)
            .accessibilityReturnFocus(when: pendingDeletionFileKind != nil)
        }
    }

    private func storageErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.rose)
            VStack(alignment: .leading, spacing: 4) {
                Text("本地存储异常")
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
        .accessibilityElement(children: .combine)
    }

    private func exportConfiguration() {
        do {
            exportDocument = LocalTransferDocument(data: try transferService.exportConfiguration(store.currentConfiguration))
            exportContentType = .json
            let kind = store.isSimulationEnabled ? "Simulation-Configuration" : "Configuration"
            exportFilename = "ScaleMe-\(kind)-\(Int(Date.now.timeIntervalSince1970)).json"
            showsExporter = true
        } catch {
            activeAlert = .message(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func exportRecords() {
        do {
            exportDocument = LocalTransferDocument(data: try transferService.exportRecords(store.currentArchive))
            exportContentType = .json
            let kind = store.isSimulationEnabled ? "Simulation-Records" : "Records"
            exportFilename = "ScaleMe-\(kind)-\(Int(Date.now.timeIntervalSince1970)).json"
            showsExporter = true
        } catch {
            activeAlert = .message(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func exportCombined() {
        do {
            exportDocument = LocalTransferDocument(data: try transferService.exportCombined(
                configuration: store.currentConfiguration,
                archive: store.currentArchive
            ))
            exportContentType = .json
            let kind = store.isSimulationEnabled ? "Simulation-Configuration-And-Data" : "Configuration-And-Data"
            exportFilename = "ScaleMe-\(kind)-\(Int(Date.now.timeIntervalSince1970)).json"
            showsExporter = true
        } catch {
            activeAlert = .message(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func importFile() {
        showsImporter = true
    }

    private func exportFile() {
        switch selectedTransferFileKind {
        case .configuration:
            exportConfiguration()
        case .records:
            exportRecords()
        case .combined:
            exportCombined()
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == CocoaError.userCancelled.rawValue
    }

    private func importFile(_ result: Result<URL, Error>) {
        if case .failure(let error) = result, isUserCancellation(error) { return }
        switch selectedTransferFileKind {
        case .configuration:
            importConfiguration(result)
        case .records:
            importRecords(result)
        case .combined:
            importCombined(result)
        }
    }

    private func toggleTransferDropdown() {
        KeyboardFocus.dismiss()
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedDropdown = expandedDropdown == .transfer ? nil : .transfer
        }
    }

    private func toggleDeletionDropdown() {
        KeyboardFocus.dismiss()
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedDropdown = expandedDropdown == .deletion ? nil : .deletion
        }
    }

    private func dismissDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            expandedDropdown = nil
        }
    }

    private func delete(_ fileKind: DeletionFileKind) {
        pendingDeletionFileKind = nil
        store.deleteLocalData(includeConfiguration: fileKind == .configurationAndRecords)
        selectedDeletionFileKind = .records
    }

    private func importConfiguration(_ result: Result<URL, Error>) {
        do {
            pendingConfiguration = try transferService.importConfiguration(from: importedData(from: result))
            activeAlert = .configurationImport
        } catch {
            activeAlert = .message(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func importRecords(_ result: Result<URL, Error>) {
        do {
            let archive = try transferService.importRecords(from: importedData(from: result))
            pendingRecords = archive
            activeAlert = .recordImport(count: archive.measurements.count)
        } catch {
            activeAlert = .message(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func importCombined(_ result: Result<URL, Error>) {
        do {
            let bundle = try transferService.importCombined(from: importedData(from: result))
            pendingConfiguration = bundle.configuration
            pendingRecords = bundle.archive
            activeAlert = .combinedImport(count: bundle.archive.measurements.count)
        } catch {
            activeAlert = .message(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func importedData(from result: Result<URL, Error>) throws -> Data {
        let url = try result.get()
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
        }
        return try Data(contentsOf: url)
    }

    private func alertContent(for alert: DataManagementAlert) -> Alert {
        switch alert {
        case .configurationImport:
            Alert(
                title: Text("导入配置？"),
                message: Text("导入的成员、设备、显示单位和通信协议将替换本机配置。测量记录不受影响。"),
                primaryButton: .destructive(Text("导入并替换")) {
                    if let pendingConfiguration {
                        store.apply(configuration: pendingConfiguration)
                        store.showOperationFeedback("导入已完成", error: store.configurationStorageError)
                    }
                    self.pendingConfiguration = nil
                },
                secondaryButton: .cancel {
                    pendingConfiguration = nil
                }
            )
        case .recordImport(let count):
            Alert(
                title: Text("导入数据文件？"),
                message: Text(store.appLanguage.format(
                    "将把文件中的 %lld 条记录与本机记录合并，重复记录不会重复保存。",
                    Int64(count)
                )),
                primaryButton: .default(Text("合并导入")) {
                    if let pendingRecords {
                        store.apply(archive: store.currentArchive.merging(pendingRecords))
                        store.showOperationFeedback("导入已完成", error: store.archiveStorageError)
                    }
                    self.pendingRecords = nil
                },
                secondaryButton: .cancel {
                    pendingRecords = nil
                }
            )
        case .combinedImport(let count):
            Alert(
                title: Text("导入配置和数据文件？"),
                message: Text(store.appLanguage.format(
                    "配置将替换本机配置，并把文件中的 %lld 条记录与本机记录合并。重复记录不会重复保存。",
                    Int64(count)
                )),
                primaryButton: .destructive(Text("导入")) {
                    guard let pendingConfiguration, let pendingRecords else { return }
                    let mergedArchive = store.currentArchive.merging(pendingRecords)
                    store.apply(configuration: pendingConfiguration)
                    store.apply(archive: mergedArchive)
                    store.showOperationFeedback("导入已完成", error: store.storageError)
                    self.pendingConfiguration = nil
                    self.pendingRecords = nil
                },
                secondaryButton: .cancel {
                    pendingConfiguration = nil
                    pendingRecords = nil
                }
            )
        case .message(let title, let message):
            Alert(
                title: Text(store.appLanguage.text(title)),
                message: Text(store.appLanguage.text(message)),
                dismissButton: .default(Text(store.appLanguage.text("完成")))
            )
        }
    }

    private enum DataManagementAlert: Identifiable {
        case configurationImport
        case recordImport(count: Int)
        case combinedImport(count: Int)
        case message(title: String, message: String)

        var id: String {
            switch self {
            case .configurationImport: "configuration-import"
            case .recordImport: "record-import"
            case .combinedImport: "combined-import"
            case .message(let title, let message): "message-\(title)-\(message)"
            }
        }
    }

    private enum TransferFileKind: CaseIterable, Hashable {
        case configuration
        case records
        case combined

        var title: String {
            switch self {
            case .configuration: "配置文件"
            case .records: "数据文件"
            case .combined: "配置和数据文件"
            }
        }

        var detail: String {
            switch self {
            case .configuration: "成员、设备、显示单位和通信协议。"
            case .records: "包含称重和身体成分记录的版本化 JSON 文件。"
            case .combined: "一个 JSON 文件同时包含完整配置和测量记录。"
            }
        }

        var icon: String {
            switch self {
            case .configuration: "gearshape.2.fill"
            case .records: "waveform.path.ecg"
            case .combined: "archivebox.fill"
            }
        }
    }

    private enum ExpandedDropdown {
        case transfer
        case deletion
    }

    private enum DeletionFileKind: CaseIterable, Hashable {
        case records
        case configurationAndRecords

        var title: String {
            switch self {
            case .records: "数据文件"
            case .configurationAndRecords: "配置和数据文件"
            }
        }

        var detail: String {
            switch self {
            case .records: "删除本机保存的所有真实测量记录，保留成员、设备和设置。"
            case .configurationAndRecords: "删除所有真实测量记录、成员、设备和设置，并恢复初始状态。"
            }
        }

        var confirmationTitle: String {
            switch self {
            case .records: "删除数据文件？"
            case .configurationAndRecords: "删除配置和数据文件？"
            }
        }

        var confirmationMessage: String {
            switch self {
            case .records: "所有真实测量记录将被永久删除，且无法恢复。成员、设备和设置不受影响。"
            case .configurationAndRecords: "所有真实测量记录、成员、设备和设置将被永久删除，且无法恢复。应用会退出模拟模式并恢复初始状态。"
            }
        }

        var icon: String {
            switch self {
            case .records: "waveform.path.ecg"
            case .configurationAndRecords: "archivebox.fill"
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsSwitch(title: title, detail: detail, isOn: $isOn)
    }
}
