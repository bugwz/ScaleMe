import Foundation

@MainActor
final class MeasurementStore: ObservableObject {
    @Published private(set) var measurements: [BodyMeasurement]
    @Published private(set) var deletedMeasurementIDs: Set<UUID>
    @Published private(set) var profiles: [UserProfile] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var selectedProfileID: UUID { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var pairedScales: [PairedScale] { didSet { persistConfigurationIfNeeded() } }
    @Published var unit: WeightUnit { didSet { persistConfigurationIfNeeded() } }
    @Published var languageSelection: AppLanguageSelection { didSet { languageSelectionDidChange() } }
    @Published private(set) var appLanguage: AppLanguage
    @Published var appearance: AppAppearance { didSet { persistConfigurationIfNeeded() } }
    @Published var mergeFrequentMeasurements: Bool { didSet { persistConfigurationIfNeeded() } }
    @Published var isSimulationEnabled: Bool { didSet { simulationModeDidChange() } }
    @Published var appleHealthProfileID: UUID? { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var appleHealthDeviceIDs: Set<UUID> { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var customCommunicationRules: [CommunicationRule] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var dashboardMetricOrder: [DashboardMetricKind] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var dashboardVisibleMetrics: Set<DashboardMetricKind> { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var storageError: String?
    @Published private(set) var latestHealthShareCandidate: BodyMeasurement?

    private let persistenceWriter: LocalPersistenceWriter?
    private var archiveUpdatedAt: Date
    private var isApplyingExternalState = false
    private var configurationRevision = 0
    private var archiveRevision = 0
    @Published private var simulationData: SimulationDataSnapshot
    private var simulationSelectedProfileID: UUID
    @Published private var simulationAppleHealthProfileID: UUID?
    @Published private var simulationAppleHealthDeviceIDs: Set<UUID>

    init() {
        var loadedRepository: LocalAppRepository?
        var loadedConfiguration = AppConfiguration.standard
        var loadedArchive = MeasurementArchive.empty
        var initialError: String?

        do {
            let repository = try LocalAppRepository()
            loadedRepository = repository

            do {
                loadedConfiguration = try repository.loadConfiguration() ?? .standard
            } catch {
                initialError = "无法读取本地配置：\(error.localizedDescription)"
            }

            do {
                loadedArchive = try repository.loadArchive() ?? .empty
            } catch {
                initialError = "无法读取本地加密数据：\(error.localizedDescription)"
            }
        } catch {
            initialError = "无法初始化本地加密存储：\(error.localizedDescription)"
        }

        let resolvedLanguage = loadedConfiguration.languageSelection.resolvedLanguage
        let simulationData = SimulationDataSnapshot.make(language: resolvedLanguage)
        persistenceWriter = loadedRepository.map(LocalPersistenceWriter.init(repository:))
        self.simulationData = simulationData
        simulationSelectedProfileID = simulationData.selectedProfileID
        simulationAppleHealthProfileID = nil
        simulationAppleHealthDeviceIDs = []
        profiles = loadedConfiguration.profiles
        selectedProfileID = loadedConfiguration.selectedProfileID
        pairedScales = loadedConfiguration.pairedScales
        unit = loadedConfiguration.unit
        languageSelection = loadedConfiguration.languageSelection
        appLanguage = resolvedLanguage
        appearance = loadedConfiguration.appearance
        mergeFrequentMeasurements = loadedConfiguration.mergeFrequentMeasurements
        isSimulationEnabled = loadedConfiguration.isSimulationEnabled
        appleHealthProfileID = loadedConfiguration.appleHealthProfileID
        appleHealthDeviceIDs = loadedConfiguration.appleHealthDeviceIDs.intersection(
            Set(loadedConfiguration.pairedScales.map(\.id))
        )
        customCommunicationRules = loadedConfiguration.customCommunicationRules
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(loadedConfiguration.dashboardMetricOrder)
        dashboardVisibleMetrics = loadedConfiguration.dashboardVisibleMetrics
        measurements = loadedArchive.measurements.sorted { $0.date > $1.date }
        deletedMeasurementIDs = loadedArchive.deletedMeasurementIDs
        archiveUpdatedAt = loadedArchive.updatedAt
        storageError = initialError
        latestHealthShareCandidate = nil
    }

    var configuration: AppConfiguration {
        AppConfiguration(
            profiles: profiles,
            selectedProfileID: selectedProfileID,
            pairedScales: pairedScales,
            unit: unit,
            languageSelection: languageSelection,
            appearance: appearance,
            mergeFrequentMeasurements: mergeFrequentMeasurements,
            isSimulationEnabled: isSimulationEnabled,
            appleHealthProfileID: appleHealthProfileID,
            appleHealthDeviceIDs: appleHealthDeviceIDs,
            customCommunicationRules: customCommunicationRules,
            dashboardMetricOrder: dashboardMetricOrder,
            dashboardVisibleMetrics: dashboardVisibleMetrics
        )
    }

    var archive: MeasurementArchive {
        MeasurementArchive(
            updatedAt: archiveUpdatedAt,
            measurements: measurements,
            deletedMeasurementIDs: deletedMeasurementIDs
        )
    }

    var selectedProfile: UserProfile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? profiles[0]
    }

    var profile: UserProfile { selectedProfile }

    var displayProfiles: [UserProfile] {
        isSimulationEnabled ? simulationData.profiles : profiles
    }

    var displaySelectedProfileID: UUID {
        isSimulationEnabled ? simulationSelectedProfileID : selectedProfileID
    }

    var displaySelectedProfile: UserProfile {
        displayProfiles.first(where: { $0.id == displaySelectedProfileID }) ?? displayProfiles[0]
    }

    var displayAppleHealthProfileID: UUID? {
        isSimulationEnabled ? simulationAppleHealthProfileID : appleHealthProfileID
    }

    var displayAppleHealthDeviceIDs: Set<UUID> {
        isSimulationEnabled ? simulationAppleHealthDeviceIDs : appleHealthDeviceIDs
    }

    var displayPairedScales: [PairedScale] {
        isSimulationEnabled ? simulationData.pairedScales : pairedScales
    }

    var selectedMeasurements: [BodyMeasurement] {
        displayMeasurements(for: displaySelectedProfileID)
    }

    var displayMeasurements: [BodyMeasurement] {
        displayMeasurements(for: displaySelectedProfileID)
    }
    var latest: BodyMeasurement? { displayMeasurements.first }
    var isShowingDemoData: Bool { isSimulationEnabled }

    func measurements(for profileID: UUID) -> [BodyMeasurement] {
        measurements.filter { $0.profileID == profileID }
    }

    func displayMeasurements(for profileID: UUID) -> [BodyMeasurement] {
        if isSimulationEnabled {
            return simulationData.measurements.filter { $0.profileID == profileID }
        }
        let profileMeasurements = measurements(for: profileID)
        return profileMeasurements.isEmpty ? Self.demoMeasurements.map {
            var value = $0
            value.profileID = profileID
            return value
        } : profileMeasurements
    }

    func add(_ measurement: BodyMeasurement) {
        if isSimulationEnabled {
            addSimulationMeasurement(measurement)
            return
        }

        var attributed = measurement
        attributed.profileID = selectedProfileID
        if let deviceID = measurement.deviceID,
           let scale = pairedScales.first(where: { $0.id == deviceID }) {
            attributed.deviceName = scale.name
        }
        let enriched = BodyCompositionEstimator.enriching(attributed, profile: selectedProfile)
        if mergeFrequentMeasurements,
           let first = measurements.first,
           first.profileID == enriched.profileID,
           first.deviceID == enriched.deviceID,
           first.source == enriched.source,
           abs(first.date.timeIntervalSince(enriched.date)) < 30 {
            deletedMeasurementIDs.insert(first.id)
            measurements[0] = enriched
        } else {
            measurements.insert(enriched, at: 0)
        }
        deletedMeasurementIDs.remove(enriched.id)
        persistArchive()
        latestHealthShareCandidate = attributed
    }

    @discardableResult
    func importDeviceHistory(_ history: [BodyMeasurement]) -> Int {
        guard !isSimulationEnabled else { return 0 }
        var imported = 0
        for measurement in history.sorted(by: { $0.date > $1.date }) {
            let isDuplicate = measurements.contains { existing in
                existing.profileID == selectedProfileID
                    && existing.deviceID == measurement.deviceID
                    && abs(existing.date.timeIntervalSince(measurement.date)) < 1
                    && abs(existing.weightKG - measurement.weightKG) < 0.005
            }
            guard !isDuplicate else { continue }
            var attributed = measurement
            attributed.profileID = selectedProfileID
            if let deviceID = attributed.deviceID,
               let scale = pairedScales.first(where: { $0.id == deviceID }) {
                attributed.deviceName = scale.name
            }
            measurements.append(BodyCompositionEstimator.enriching(attributed, profile: selectedProfile))
            imported += 1
        }
        guard imported > 0 else { return 0 }
        measurements.sort { $0.date > $1.date }
        persistArchive()
        return imported
    }

    func addManual(
        weightKG: Double,
        impedanceOhm: Double? = nil,
        bodyFatPercent: Double? = nil,
        muscleMassKG: Double? = nil,
        waterPercent: Double? = nil,
        visceralFat: Double? = nil,
        basalMetabolismKCal: Double? = nil,
        boneMassKG: Double? = nil
    ) {
        add(
            BodyMeasurement(
                date: .now,
                weightKG: weightKG,
                impedanceOhm: impedanceOhm,
                bodyFatPercent: bodyFatPercent,
                muscleMassKG: muscleMassKG,
                waterPercent: waterPercent,
                visceralFat: visceralFat,
                basalMetabolismKCal: basalMetabolismKCal,
                boneMassKG: boneMassKG,
                source: .manual,
                isStable: true
            )
        )
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
    }

    func selectDisplayProfile(_ id: UUID) {
        if isSimulationEnabled {
            guard simulationData.profiles.contains(where: { $0.id == id }) else { return }
            simulationSelectedProfileID = id
            simulationData.selectedProfileID = id
        } else {
            selectProfile(id)
        }
    }

    func setDisplayAppleHealthProfileID(_ id: UUID?) {
        if isSimulationEnabled {
            guard id == nil || simulationData.profiles.contains(where: { $0.id == id }) else { return }
            simulationAppleHealthProfileID = id
        } else {
            guard id == nil || profiles.contains(where: { $0.id == id }) else { return }
            appleHealthProfileID = id
        }
    }

    func toggleDisplayAppleHealthDevice(_ id: UUID) {
        guard displayPairedScales.contains(where: { $0.id == id }) else { return }
        if isSimulationEnabled {
            if simulationAppleHealthDeviceIDs.remove(id) == nil {
                simulationAppleHealthDeviceIDs.insert(id)
            }
        } else if appleHealthDeviceIDs.remove(id) == nil {
            appleHealthDeviceIDs.insert(id)
        }
    }

    func addProfile(_ profile: UserProfile) {
        if isSimulationEnabled {
            simulationData.profiles.append(profile)
            simulationSelectedProfileID = profile.id
            simulationData.selectedProfileID = profile.id
            return
        }
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func updateProfile(_ profile: UserProfile) {
        if isSimulationEnabled {
            guard let index = simulationData.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
            simulationData.profiles[index] = profile
            return
        }
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
    }

    func moveProfile(_ profileID: UUID, onto targetProfileID: UUID) {
        if isSimulationEnabled {
            moveProfile(profileID, onto: targetProfileID, in: &simulationData.profiles)
            return
        }
        moveProfile(profileID, onto: targetProfileID, in: &profiles)
    }

    func setDisplayProfileOrder(_ orderedProfileIDs: [UUID]) {
        let currentProfiles = displayProfiles
        guard orderedProfileIDs.count == currentProfiles.count,
              Set(orderedProfileIDs).count == orderedProfileIDs.count,
              Set(orderedProfileIDs) == Set(currentProfiles.map(\.id)) else { return }
        let profilesByID = Dictionary(
            currentProfiles.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        let reorderedProfiles = orderedProfileIDs.compactMap { profilesByID[$0] }
        guard reorderedProfiles != currentProfiles else { return }

        if isSimulationEnabled {
            simulationData.profiles = reorderedProfiles
        } else {
            profiles = reorderedProfiles
        }
    }

    private func moveProfile(_ profileID: UUID, onto targetProfileID: UUID, in profiles: inout [UserProfile]) {
        guard profileID != targetProfileID,
              let sourceIndex = profiles.firstIndex(where: { $0.id == profileID }),
              let targetIndex = profiles.firstIndex(where: { $0.id == targetProfileID }) else { return }
        profiles.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        )
    }

    func deleteProfile(_ id: UUID) {
        if isSimulationEnabled {
            guard simulationData.profiles.count > 1,
                  let index = simulationData.profiles.firstIndex(where: { $0.id == id }) else { return }
            simulationData.profiles.remove(at: index)
            if simulationAppleHealthProfileID == id { simulationAppleHealthProfileID = nil }
            if simulationSelectedProfileID == id {
                simulationSelectedProfileID = simulationData.profiles[0].id
                simulationData.selectedProfileID = simulationSelectedProfileID
            }
            return
        }
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: index)
        if appleHealthProfileID == id { appleHealthProfileID = nil }
        if selectedProfileID == id { selectedProfileID = profiles[0].id }
    }

    func addScale(_ scale: PairedScale) {
        if isSimulationEnabled {
            guard !simulationData.pairedScales.contains(where: { $0.id == scale.id }) else { return }
            simulationData.pairedScales.append(scale)
            return
        }
        guard !pairedScales.contains(where: { $0.id == scale.id }) else { return }
        pairedScales.append(scale)
    }

    func renameScale(_ id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isSimulationEnabled {
            guard let index = simulationData.pairedScales.firstIndex(where: { $0.id == id }) else { return }
            simulationData.pairedScales[index].name = trimmed
            return
        }
        guard let index = pairedScales.firstIndex(where: { $0.id == id }) else { return }
        pairedScales[index].name = trimmed
    }

    var communicationRules: [CommunicationRule] {
        CommunicationRuleCatalog.rules(custom: customCommunicationRules)
    }

    func communicationRule(for scale: PairedScale) -> CommunicationRule? {
        guard let id = scale.communicationRuleID else { return nil }
        return communicationRules.first { $0.id == id }
    }

    func setCommunicationRule(_ ruleID: String?, for scaleID: UUID) {
        if isSimulationEnabled {
            guard ruleID == nil || communicationRules.contains(where: { $0.id == ruleID }),
                  let index = simulationData.pairedScales.firstIndex(where: { $0.id == scaleID }) else { return }
            simulationData.pairedScales[index].communicationRuleID = ruleID
            return
        }
        guard ruleID == nil || communicationRules.contains(where: { $0.id == ruleID }),
              let index = pairedScales.firstIndex(where: { $0.id == scaleID }) else { return }
        pairedScales[index].communicationRuleID = ruleID
    }

    @discardableResult
    func importCommunicationRules(_ data: Data, sourceURL: URL? = nil) throws -> Int {
        let imported = try CommunicationRuleCodec.decode(data, importedFrom: sourceURL)
        var updated = customCommunicationRules
        for rule in imported {
            if let index = updated.firstIndex(where: { $0.id == rule.id }) {
                updated[index] = rule
            } else {
                updated.append(rule)
            }
        }
        customCommunicationRules = updated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return imported.count
    }

    func removeCommunicationRule(_ id: String) {
        customCommunicationRules.removeAll { $0.id == id }
        for index in pairedScales.indices where pairedScales[index].communicationRuleID == id {
            pairedScales[index].communicationRuleID = nil
        }
    }

    func removeScale(_ id: UUID) {
        if isSimulationEnabled {
            simulationData.pairedScales.removeAll { $0.id == id }
            simulationAppleHealthDeviceIDs.remove(id)
            return
        }
        pairedScales.removeAll { $0.id == id }
        appleHealthDeviceIDs.remove(id)
    }

    func updateDashboardMetrics(order: [DashboardMetricKind], visible: Set<DashboardMetricKind>) {
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(order)
        dashboardVisibleMetrics = visible
    }

    private static func sanitizedMetricOrder(_ order: [DashboardMetricKind]) -> [DashboardMetricKind] {
        var seen = Set<DashboardMetricKind>()
        var sanitized = order.filter { seen.insert($0).inserted }
        for kind in DashboardMetricKind.allCases where !seen.contains(kind) {
            sanitized.append(kind)
        }
        return sanitized
    }

    func delete(at offsets: IndexSet) {
        if isSimulationEnabled {
            let visibleMeasurements = displayMeasurements(for: simulationSelectedProfileID)
            let idsToDelete = Set(offsets.compactMap { offset in
                visibleMeasurements.indices.contains(offset) ? visibleMeasurements[offset].id : nil
            })
            simulationData.measurements.removeAll { idsToDelete.contains($0.id) }
            return
        }
        for offset in offsets where measurements.indices.contains(offset) {
            deletedMeasurementIDs.insert(measurements[offset].id)
        }
        measurements.remove(atOffsets: offsets)
        persistArchive()
    }

    func apply(configuration: AppConfiguration) {
        guard configuration != self.configuration else { return }
        guard !configuration.profiles.isEmpty else { return }
        isApplyingExternalState = true
        profiles = configuration.profiles
        selectedProfileID = configuration.profiles.contains(where: { $0.id == configuration.selectedProfileID })
            ? configuration.selectedProfileID
            : configuration.profiles[0].id
        pairedScales = configuration.pairedScales
        unit = configuration.unit
        languageSelection = configuration.languageSelection
        appLanguage = configuration.languageSelection.resolvedLanguage
        appearance = configuration.appearance
        mergeFrequentMeasurements = configuration.mergeFrequentMeasurements
        isSimulationEnabled = configuration.isSimulationEnabled
        appleHealthProfileID = configuration.appleHealthProfileID.flatMap { profileID in
            configuration.profiles.contains(where: { $0.id == profileID }) ? profileID : nil
        }
        appleHealthDeviceIDs = configuration.appleHealthDeviceIDs.intersection(
            Set(configuration.pairedScales.map(\.id))
        )
        customCommunicationRules = configuration.customCommunicationRules
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(configuration.dashboardMetricOrder)
        dashboardVisibleMetrics = configuration.dashboardVisibleMetrics
        isApplyingExternalState = false
        persistConfiguration()
    }

    func apply(archive: MeasurementArchive) {
        let normalized = MeasurementArchive(
            updatedAt: archive.updatedAt,
            measurements: archive.measurements
                .filter { !archive.deletedMeasurementIDs.contains($0.id) }
                .sorted { $0.date > $1.date },
            deletedMeasurementIDs: archive.deletedMeasurementIDs
        )
        guard normalized != self.archive else { return }
        measurements = normalized.measurements
        deletedMeasurementIDs = normalized.deletedMeasurementIDs
        archiveUpdatedAt = normalized.updatedAt
        persistArchive(markAsChanged: false)
    }

    private func persistConfigurationIfNeeded() {
        guard !isApplyingExternalState else { return }
        persistConfiguration()
    }

    private func simulationModeDidChange() {
        guard !isApplyingExternalState else { return }
        if isSimulationEnabled {
            simulationSelectedProfileID = simulationData.selectedProfileID
        }
        persistConfiguration()
    }

    func refreshSystemLanguage() {
        guard languageSelection == .system else { return }
        updateResolvedLanguage()
    }

    private func languageSelectionDidChange() {
        updateResolvedLanguage()
        persistConfigurationIfNeeded()
    }

    private func updateResolvedLanguage() {
        let resolvedLanguage = languageSelection.resolvedLanguage
        guard appLanguage != resolvedLanguage else { return }
        appLanguage = resolvedLanguage
        simulationData = SimulationDataSnapshot.make(language: appLanguage)
        simulationSelectedProfileID = simulationData.selectedProfileID
        simulationAppleHealthDeviceIDs.formIntersection(Set(simulationData.pairedScales.map(\.id)))
        if let simulationAppleHealthProfileID,
           !simulationData.profiles.contains(where: { $0.id == simulationAppleHealthProfileID }) {
            self.simulationAppleHealthProfileID = nil
        }
    }

    private func addSimulationMeasurement(_ measurement: BodyMeasurement) {
        var attributed = measurement
        attributed.profileID = simulationSelectedProfileID
        if let deviceID = measurement.deviceID,
           let scale = simulationData.pairedScales.first(where: { $0.id == deviceID }) {
            attributed.deviceName = scale.name
        }
        guard let profile = simulationData.profiles.first(where: { $0.id == simulationSelectedProfileID }) else { return }
        let enriched = BodyCompositionEstimator.enriching(attributed, profile: profile)

        if mergeFrequentMeasurements,
           let index = simulationData.measurements.firstIndex(where: {
               $0.profileID == enriched.profileID
                   && $0.deviceID == enriched.deviceID
                   && $0.source == enriched.source
                   && abs($0.date.timeIntervalSince(enriched.date)) < 30
           }) {
            simulationData.measurements[index] = enriched
        } else {
            simulationData.measurements.append(enriched)
        }
        simulationData.measurements.sort { $0.date > $1.date }
    }

    private func persistConfiguration() {
        guard let persistenceWriter else {
            storageError = "无法初始化本地加密存储"
            return
        }
        configurationRevision += 1
        let revision = configurationRevision
        let snapshot = configuration
        Task {
            do {
                try await persistenceWriter.saveConfiguration(snapshot, revision: revision)
                guard revision == configurationRevision else { return }
                storageError = nil
            } catch {
                guard revision == configurationRevision else { return }
                storageError = error.localizedDescription
            }
        }
    }

    private func persistArchive(markAsChanged: Bool = true) {
        if markAsChanged { archiveUpdatedAt = .now }
        guard let persistenceWriter else {
            storageError = "无法初始化本地加密存储"
            return
        }
        archiveRevision += 1
        let revision = archiveRevision
        let snapshot = archive
        Task {
            do {
                try await persistenceWriter.saveArchive(snapshot, revision: revision)
                guard revision == archiveRevision else { return }
                storageError = nil
            } catch {
                guard revision == archiveRevision else { return }
                storageError = error.localizedDescription
            }
        }
    }

    static let demoMeasurements: [BodyMeasurement] = (0..<18).map { index in
        let base = 58.7 + sin(Double(index) * 0.72) * 0.45 + Double(index) * 0.035
        return BodyMeasurement(
            date: Calendar.current.date(byAdding: .day, value: -index * 4, to: .now) ?? .now,
            weightKG: base,
            impedanceOhm: 510,
            bodyFatPercent: 24.3 + sin(Double(index) * 0.4) * 0.8,
            muscleMassKG: 41.1,
            waterPercent: 53.6,
            visceralFat: 6,
            basalMetabolismKCal: 1326,
            boneMassKG: 2.7,
            source: .demo,
            isStable: true
        )
    }
}
