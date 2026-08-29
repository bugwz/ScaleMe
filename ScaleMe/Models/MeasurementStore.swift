import Foundation

@MainActor
final class MeasurementStore: ObservableObject {
    @Published private(set) var measurements: [BodyMeasurement]
    @Published private(set) var deletedMeasurementIDs: Set<UUID>
    @Published private(set) var profiles: [UserProfile] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var selectedProfileID: UUID { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var pairedScales: [PairedScale] { didSet { persistConfigurationIfNeeded() } }
    @Published var unit: WeightUnit { didSet { persistConfigurationIfNeeded() } }
    @Published var mergeFrequentMeasurements: Bool { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var customCommunicationRules: [CommunicationRule] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var storageError: String?

    private let repository: LocalAppRepository?
    private var archiveUpdatedAt: Date
    private var isApplyingExternalState = false

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

        repository = loadedRepository
        profiles = loadedConfiguration.profiles
        selectedProfileID = loadedConfiguration.selectedProfileID
        pairedScales = loadedConfiguration.pairedScales
        unit = loadedConfiguration.unit
        mergeFrequentMeasurements = loadedConfiguration.mergeFrequentMeasurements
        customCommunicationRules = loadedConfiguration.customCommunicationRules
        measurements = loadedArchive.measurements.sorted { $0.date > $1.date }
        deletedMeasurementIDs = loadedArchive.deletedMeasurementIDs
        archiveUpdatedAt = loadedArchive.updatedAt
        storageError = initialError
    }

    var configuration: AppConfiguration {
        AppConfiguration(
            profiles: profiles,
            selectedProfileID: selectedProfileID,
            pairedScales: pairedScales,
            unit: unit,
            mergeFrequentMeasurements: mergeFrequentMeasurements,
            customCommunicationRules: customCommunicationRules
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

    var selectedMeasurements: [BodyMeasurement] {
        measurements.filter { $0.profileID == selectedProfileID }
    }

    var displayMeasurements: [BodyMeasurement] {
        selectedMeasurements.isEmpty ? Self.demoMeasurements.map {
            var value = $0
            value.profileID = selectedProfileID
            return value
        } : selectedMeasurements
    }
    var latest: BodyMeasurement? { displayMeasurements.first }
    var isShowingDemoData: Bool { selectedMeasurements.isEmpty }

    func add(_ measurement: BodyMeasurement) {
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
    }

    func addManual(weightKG: Double, bodyFat: Double? = nil) {
        add(BodyMeasurement(date: .now, weightKG: weightKG, bodyFatPercent: bodyFat, source: .manual, isStable: true))
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
    }

    func addProfile(_ profile: UserProfile) {
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func updateProfile(_ profile: UserProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
    }

    func deleteProfile(_ id: UUID) {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: index)
        if selectedProfileID == id { selectedProfileID = profiles[0].id }
    }

    func addScale(_ scale: PairedScale) {
        guard !pairedScales.contains(where: { $0.id == scale.id }) else { return }
        pairedScales.append(scale)
    }

    func renameScale(_ id: UUID, name: String) {
        guard let index = pairedScales.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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
        pairedScales.removeAll { $0.id == id }
    }

    func delete(at offsets: IndexSet) {
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
        mergeFrequentMeasurements = configuration.mergeFrequentMeasurements
        customCommunicationRules = configuration.customCommunicationRules
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

    private func persistConfiguration() {
        guard let repository else {
            storageError = "无法初始化本地加密存储"
            return
        }
        do {
            try repository.saveConfiguration(configuration)
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }

    private func persistArchive(markAsChanged: Bool = true) {
        if markAsChanged { archiveUpdatedAt = .now }
        guard let repository else {
            storageError = "无法初始化本地加密存储"
            return
        }
        do {
            try repository.saveArchive(archive)
            storageError = nil
        } catch {
            storageError = error.localizedDescription
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
