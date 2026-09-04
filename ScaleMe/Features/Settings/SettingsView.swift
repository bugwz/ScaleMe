import SwiftUI
import UniformTypeIdentifiers

struct DisplaySettingsView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var isWeightUnitDropdownExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                displayPanel
                measurementHistoryPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.displaySettings))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .accessibilityHidden(isWeightUnitDropdownExpanded)
        .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, isWeightUnitDropdownExpanded {
                    AppDropdownMenuLayer(
                        anchorFrame: proxy[anchor],
                        availableSize: proxy.size,
                        options: WeightUnit.allCases,
                        isSelected: { $0 == store.unit },
                        title: { $0.settingsTitle },
                        appearance: .compact,
                        onSelect: { unit in
                            store.unit = unit
                            dismissWeightUnitDropdown()
                        },
                        onDismiss: dismissWeightUnitDropdown
                    )
                }
            }
        }
        .onDisappear { isWeightUnitDropdownExpanded = false }
    }

    private var displayPanel: some View {
        SettingsPanel(title: "显示", icon: "textformat.size") {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                navigationRow(
                    title: store.appLanguage.text(.appearance),
                    detail: appearanceTitle,
                    icon: "circle.lefthalf.filled"
                )
            }
            .buttonStyle(.plain)

            SettingsSeparator()

            NavigationLink {
                LanguageSettingsView()
            } label: {
                navigationRow(
                    title: store.appLanguage.text(.language),
                    detail: languageSelectionTitle,
                    icon: "globe"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var measurementHistoryPanel: some View {
        SettingsPanel(title: "测量记录", icon: "clock.arrow.2.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
                Text("体重单位")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppDropdownField(
                    value: store.unit.settingsTitle,
                    icon: "scalemass.fill",
                    accessibilityLabel: "体重单位",
                    isExpanded: isWeightUnitDropdownExpanded,
                    appearance: .compact,
                    onToggle: toggleWeightUnitDropdown
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
        if store.languageSelection == .system {
            return store.appLanguage.text(.followSystem)
        }
        return store.languageSelection.explicitLanguage?.nativeName ?? AppLanguage.english.nativeName
    }

    private var appearanceTitle: String {
        switch store.appearance {
        case .system: store.appLanguage.text(.followSystem)
        case .light: store.appLanguage.text(.lightAppearance)
        case .dark: store.appLanguage.text(.darkAppearance)
        }
    }

    private func navigationRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(width: 36, height: 36)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppColor.secondary.opacity(0.7))
        }
        .contentShape(Rectangle())
    }

    private func toggleWeightUnitDropdown() {
        KeyboardFocus.dismiss()
        withAnimation(.easeInOut(duration: 0.18)) {
            isWeightUnitDropdownExpanded.toggle()
        }
    }

    private func dismissWeightUnitDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isWeightUnitDropdownExpanded = false
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
    @State private var showsConfigurationImporter = false
    @State private var showsRecordImporter = false
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
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.dataManagement))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .fileImporter(
            isPresented: $showsConfigurationImporter,
            allowedContentTypes: [.json]
        ) { result in
            importConfiguration(result)
        }
        .fileImporter(
            isPresented: $showsRecordImporter,
            allowedContentTypes: [.json]
        ) { result in
            importRecords(result)
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                activeAlert = .message(title: "导出失败", message: error.localizedDescription)
            }
        }
        .alert(item: $activeAlert) { alert in
            alertContent(for: alert)
        }
    }

    private var localTransferPanel: some View {
        SettingsPanel(title: "记录文件导入/导出", icon: "arrow.up.arrow.down.square") {
            transferSection(
                title: "配置",
                detail: "成员、设备、显示单位和通信协议。",
                importAction: { showsConfigurationImporter = true },
                exportAction: { exportConfiguration() }
            )

            SettingsSeparator()

            transferSection(
                title: "记录文件",
                detail: "包含称重和身体成分记录的版本化 JSON 文件。",
                importAction: { showsRecordImporter = true },
                exportAction: { exportRecords() }
            )

            Label("配置与健康记录均以版本化 JSON 文件导入导出，可跨设备分享。", systemImage: "doc.text.fill")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func transferSection(
        title: String,
        detail: String,
        importAction: @escaping () -> Void,
        exportAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: title == "配置" ? "gearshape.2.fill" : "waveform.path.ecg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(title == "配置" ? AppColor.sky : AppColor.mint)
                    .frame(width: 36, height: 36)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    AppLocalizedText(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    AppLocalizedText(detail)
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                transferButton(title: "导入", icon: "square.and.arrow.down", action: importAction)
                transferButton(title: "导出", icon: "square.and.arrow.up", action: exportAction)
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
                detail: "全界面展示可操作的模拟成员、设备和近一年记录；真实资料与测量数据不会被删除或替换。",
                isOn: $store.isSimulationEnabled
            )

            if store.isSimulationEnabled {
                Label("模拟模式下的修改可通过独立命名的模拟文件导入导出；真实配置和记录不会被替换。", systemImage: "sparkles")
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
                    }
                    self.pendingConfiguration = nil
                },
                secondaryButton: .cancel {
                    pendingConfiguration = nil
                }
            )
        case .recordImport(let count):
            Alert(
                title: Text("导入记录文件？"),
                message: Text(store.appLanguage.format(
                    "将把文件中的 %lld 条记录与本机记录合并，重复记录不会重复保存。",
                    Int64(count)
                )),
                primaryButton: .default(Text("合并导入")) {
                    if let pendingRecords {
                        store.apply(archive: store.currentArchive.merging(pendingRecords))
                    }
                    self.pendingRecords = nil
                },
                secondaryButton: .cancel {
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
        case message(title: String, message: String)

        var id: String {
            switch self {
            case .configurationImport: "configuration-import"
            case .recordImport: "record-import"
            case .message(let title, let message): "message-\(title)-\(message)"
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
