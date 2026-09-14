import Foundation
import SwiftUI

@MainActor
final class MeasurementStore: ObservableObject {
    private static let placeholderProfileID = UUID()
    @Published private(set) var measurements: [BodyMeasurement]
    @Published private(set) var deletedMeasurements: Set<DeletedMeasurementMarker>
    @Published private(set) var profiles: [UserProfile] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var selectedProfileID: UUID
    @Published private(set) var pairedScales: [PairedScale] { didSet { persistConfigurationIfNeeded() } }
    @Published var unit: WeightUnit { didSet { persistConfigurationIfNeeded() } }
    @Published var languageSelection: AppLanguageSelection { didSet { languageSelectionDidChange() } }
    @Published private(set) var appLanguage: AppLanguage
    @Published var visualTheme: AppVisualTheme { didSet { persistConfigurationIfNeeded() } }
    @Published var appearance: AppAppearance { didSet { persistConfigurationIfNeeded() } }
    @Published var mergeFrequentMeasurements: Bool { didSet { persistConfigurationIfNeeded() } }
    @Published var isSimulationEnabled: Bool { didSet { simulationModeDidChange() } }
    @Published var appleHealthProfileID: UUID? { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var appleHealthDeviceIDs: Set<UUID> { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var isAppleHealthImportEnabled: Bool { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var appleHealthReadTypes: Set<AppleHealthDataType> { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var customCommunicationRules: [CommunicationRule] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var dashboardMetricOrder: [DashboardMetricKind] { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var dashboardVisibleMetrics: Set<DashboardMetricKind> { didSet { persistConfigurationIfNeeded() } }
    @Published var widgetProfileID: UUID? { didSet { persistConfigurationIfNeeded() } }
    @Published var widgetTimeRange: WidgetTrendTimeRange { didSet { persistConfigurationIfNeeded() } }
    @Published var widgetDisplayStyle: WidgetTrendDisplayStyle { didSet { persistConfigurationIfNeeded() } }
    @Published private(set) var configurationStorageError: String?
    @Published private(set) var archiveStorageError: String?
    @Published private(set) var measurementSaveError: String?
    @Published private var pendingMeasurements: [PendingMeasurement] = []

    var storageError: String? {
        let errors = [configurationStorageError, archiveStorageError, measurementSaveError].compactMap { $0 }
        return errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    var hasPendingMeasurements: Bool { !pendingMeasurements.isEmpty }

    func isMeasurementPending(_ id: UUID) -> Bool {
        pendingMeasurements.contains { $0.raw.id == id }
    }

    private struct PendingMeasurement {
        let raw: BodyMeasurement
        let mergesContinuousMeasurements: Bool
    }
    @Published private(set) var latestHealthShareCandidate: BodyMeasurement?
    @Published private(set) var isSimulationDataLoading = false
    private let persistenceWriter: LocalPersistenceWriter?
    private var archiveUpdatedAt: Date
    private var isApplyingExternalState = false
    private var configurationRevision = 0
    private var archiveRevision = 0
    @Published private var simulationData: SimulationDataSnapshot
    private let simulationLaunchDay: Date
    private let simulationCalendar: Calendar
    private var simulationDataLoadTask: Task<Void, Never>?
    private var simulationDataLoadGeneration = 0
    private var isSimulationHistoryLoaded = false
    private var simulationSelectedProfileID: UUID
    @Published private var simulationAppleHealthProfileID: UUID?
    @Published private var simulationAppleHealthDeviceIDs: Set<UUID>
    @Published private var simulationIsAppleHealthImportEnabled: Bool
    @Published private var simulationAppleHealthReadTypes: Set<AppleHealthDataType>
    @Published private var simulationDeletedMeasurements: Set<DeletedMeasurementMarker>
    private var simulationArchiveUpdatedAt: Date
    private var simulationCommunicationRuleImportSequence = SimulationCommunicationRuleImportSequence()
    private var configurationBeforeSimulation: AppConfiguration?

    init(repository suppliedRepository: LocalAppRepository? = nil) {
        var loadedRepository: LocalAppRepository?
        var loadedConfiguration = AppConfiguration.standard
        var loadedArchive = MeasurementArchive.empty
        var configurationError: String?
        var archiveError: String?

        do {
            let repository = try suppliedRepository ?? LocalAppRepository()
            loadedRepository = repository

            do {
                loadedConfiguration = try repository.loadConfiguration() ?? .standard
            } catch {
                configurationError = "无法读取本地配置：\(error.localizedDescription)"
            }

            do {
                loadedArchive = try repository.loadArchive() ?? .empty
            } catch {
                archiveError = "无法读取本地数据：\(error.localizedDescription)"
            }
        } catch {
            configurationError = "无法初始化本地存储：\(error.localizedDescription)"
        }

        loadedConfiguration.profiles = Self.normalizedProfiles(loadedConfiguration.profiles)
        loadedConfiguration.appleHealthReadTypes.insert(.bodyMass)
        loadedConfiguration.appleHealthProfileID = loadedConfiguration.appleHealthProfileID.flatMap { profileID in
            loadedConfiguration.profiles.contains(where: { $0.id == profileID && $0.role == "本人" })
                ? profileID
                : nil
        }
        let resolvedLanguage = loadedConfiguration.languageSelection.resolvedLanguage
        let simulationReferenceDate = Date.now
        let simulationCalendar = Calendar.current
        let simulationLaunchDay = simulationCalendar.startOfDay(for: simulationReferenceDate)
        let simulationData = SimulationDataSnapshot.makeMetadata(
            language: resolvedLanguage,
            launchDay: simulationLaunchDay,
            calendar: simulationCalendar
        )
        persistenceWriter = loadedRepository.map(LocalPersistenceWriter.init(repository:))
        self.simulationData = simulationData
        self.simulationLaunchDay = simulationLaunchDay
        self.simulationCalendar = simulationCalendar
        simulationSelectedProfileID = simulationData.selectedProfileID
        simulationAppleHealthProfileID = nil
        simulationAppleHealthDeviceIDs = []
        simulationIsAppleHealthImportEnabled = false
        simulationAppleHealthReadTypes = Set(AppleHealthDataType.allCases)
        simulationDeletedMeasurements = []
        simulationArchiveUpdatedAt = .distantPast
        isSimulationHistoryLoaded = false
        profiles = loadedConfiguration.profiles
        selectedProfileID = Self.preferredProfileID(in: loadedConfiguration.profiles)
            ?? Self.placeholderProfileID
        pairedScales = loadedConfiguration.pairedScales
        unit = loadedConfiguration.unit
        languageSelection = loadedConfiguration.languageSelection
        appLanguage = resolvedLanguage
        visualTheme = loadedConfiguration.visualTheme
        appearance = loadedConfiguration.appearance
        mergeFrequentMeasurements = loadedConfiguration.mergeFrequentMeasurements
        isSimulationEnabled = loadedConfiguration.isSimulationEnabled
        appleHealthProfileID = loadedConfiguration.appleHealthProfileID
        appleHealthDeviceIDs = loadedConfiguration.appleHealthDeviceIDs.intersection(
            Set(loadedConfiguration.pairedScales.map(\.id))
        )
        isAppleHealthImportEnabled = loadedConfiguration.isAppleHealthImportEnabled
        appleHealthReadTypes = loadedConfiguration.appleHealthReadTypes
        customCommunicationRules = loadedConfiguration.customCommunicationRules
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(loadedConfiguration.dashboardMetricOrder)
        dashboardVisibleMetrics = loadedConfiguration.dashboardVisibleMetrics
        widgetProfileID = loadedConfiguration.widgetProfileID
        widgetTimeRange = loadedConfiguration.widgetTimeRange
        widgetDisplayStyle = loadedConfiguration.widgetDisplayStyle
        measurements = loadedArchive.measurements.sorted { $0.date > $1.date }
        deletedMeasurements = loadedArchive.deletedMeasurements
        archiveUpdatedAt = loadedArchive.updatedAt
        configurationStorageError = configurationError
        archiveStorageError = archiveError
        latestHealthShareCandidate = nil
        if isSimulationEnabled {
            var baseline = loadedConfiguration
            baseline.isSimulationEnabled = false
            configurationBeforeSimulation = baseline
            customCommunicationRules = SimulationCommunicationRuleCatalog.initialRules
        }
    }

    var configuration: AppConfiguration {
        AppConfiguration(
            profiles: profiles,
            pairedScales: pairedScales,
            unit: unit,
            languageSelection: languageSelection,
            visualTheme: visualTheme,
            appearance: appearance,
            mergeFrequentMeasurements: mergeFrequentMeasurements,
            isSimulationEnabled: isSimulationEnabled,
            appleHealthProfileID: appleHealthProfileID,
            appleHealthDeviceIDs: appleHealthDeviceIDs,
            isAppleHealthImportEnabled: isAppleHealthImportEnabled,
            appleHealthReadTypes: appleHealthReadTypes,
            customCommunicationRules: customCommunicationRules,
            dashboardMetricOrder: dashboardMetricOrder,
            dashboardVisibleMetrics: dashboardVisibleMetrics,
            widgetProfileID: widgetProfileID,
            widgetTimeRange: widgetTimeRange,
            widgetDisplayStyle: widgetDisplayStyle
        )
    }

    var archive: MeasurementArchive {
        MeasurementArchive(
            updatedAt: archiveUpdatedAt,
            measurements: measurements,
            deletedMeasurements: deletedMeasurements
        )
    }

    var currentConfiguration: AppConfiguration {
        guard isSimulationEnabled else { return configuration }
        return AppConfiguration(
            profiles: simulationData.profiles,
            pairedScales: simulationData.pairedScales,
            unit: unit,
            languageSelection: languageSelection,
            visualTheme: visualTheme,
            appearance: appearance,
            mergeFrequentMeasurements: mergeFrequentMeasurements,
            isSimulationEnabled: true,
            appleHealthProfileID: simulationAppleHealthProfileID,
            appleHealthDeviceIDs: simulationAppleHealthDeviceIDs,
            isAppleHealthImportEnabled: simulationIsAppleHealthImportEnabled,
            appleHealthReadTypes: simulationAppleHealthReadTypes,
            customCommunicationRules: customCommunicationRules,
            dashboardMetricOrder: dashboardMetricOrder,
            dashboardVisibleMetrics: dashboardVisibleMetrics,
            widgetProfileID: widgetProfileID,
            widgetTimeRange: widgetTimeRange,
            widgetDisplayStyle: widgetDisplayStyle
        )
    }

    var currentArchive: MeasurementArchive {
        guard isSimulationEnabled else { return archive }
        return MeasurementArchive(
            updatedAt: simulationArchiveUpdatedAt,
            measurements: simulationData.measurements,
            deletedMeasurements: simulationDeletedMeasurements
        )
    }

    var selectedProfile: UserProfile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? placeholderProfile
    }

    var profile: UserProfile { selectedProfile }

    var displayProfiles: [UserProfile] {
        if isSimulationEnabled { return simulationData.profiles }
        return profiles.isEmpty ? [placeholderProfile] : profiles
    }

    var managedProfiles: [UserProfile] {
        isSimulationEnabled ? simulationData.profiles : profiles
    }

    var isUsingPlaceholderData: Bool {
        !isSimulationEnabled && profiles.isEmpty
    }

    var displaySelectedProfileID: UUID {
        isSimulationEnabled ? simulationSelectedProfileID : selectedProfileID
    }

    var displaySelectedProfile: UserProfile {
        displayProfiles.first(where: { $0.id == displaySelectedProfileID }) ?? placeholderProfile
    }

    var widgetDisplayProfile: UserProfile {
        guard let widgetProfileID,
              let profile = displayProfiles.first(where: { $0.id == widgetProfileID }) else {
            return displaySelectedProfile
        }
        return profile
    }

    var displayAppleHealthProfileID: UUID? {
        isSimulationEnabled ? simulationAppleHealthProfileID : appleHealthProfileID
    }

    var displayAppleHealthDeviceIDs: Set<UUID> {
        isSimulationEnabled ? simulationAppleHealthDeviceIDs : appleHealthDeviceIDs
    }

    var displayIsAppleHealthImportEnabled: Bool {
        isSimulationEnabled ? simulationIsAppleHealthImportEnabled : isAppleHealthImportEnabled
    }

    var displayAppleHealthReadTypes: Set<AppleHealthDataType> {
        isSimulationEnabled ? simulationAppleHealthReadTypes : appleHealthReadTypes
    }

    var currentUserProfile: UserProfile? {
        managedProfiles.first(where: { $0.role == "本人" })
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
    var isShowingDemoData: Bool { isSimulationEnabled || isUsingPlaceholderData }

    func measurements(for profileID: UUID) -> [BodyMeasurement] {
        measurements.filter { $0.profileID == profileID }
    }

    func displayMeasurements(for profileID: UUID) -> [BodyMeasurement] {
        if isSimulationEnabled {
            return simulationData.measurements.filter { $0.profileID == profileID }
        }
        guard isUsingPlaceholderData, profileID == Self.placeholderProfileID else {
            return measurements(for: profileID)
        }
        return Self.demoMeasurements.map {
            var value = $0
            value.profileID = profileID
            return value
        }
    }

    func displayMeasurement(id: UUID) -> BodyMeasurement? {
        if isSimulationEnabled {
            return simulationData.measurements.first(where: { $0.id == id })
        }
        if let measurement = measurements.first(where: { $0.id == id }) {
            return measurement
        }
        guard isUsingPlaceholderData else { return nil }
        return Self.demoMeasurements.first(where: { $0.id == id })
    }

    @discardableResult
    func reassignMeasurement(_ measurementID: UUID, to profileID: UUID) -> Bool {
        if isSimulationEnabled {
            guard simulationData.profiles.contains(where: { $0.id == profileID }),
                  let index = simulationData.measurements.firstIndex(where: { $0.id == measurementID }),
                  simulationData.measurements[index].profileID != profileID else { return false }
            simulationData.measurements[index].profileID = profileID
            simulationArchiveUpdatedAt = .now
            return true
        }

        guard profiles.contains(where: { $0.id == profileID }),
              let index = measurements.firstIndex(where: { $0.id == measurementID }),
              measurements[index].profileID != profileID else { return false }
        measurements[index].profileID = profileID
        persistArchive()
        return true
    }

    @discardableResult
    func deleteMeasurement(_ measurementID: UUID) -> Bool {
        if isSimulationEnabled {
            guard let deleted = simulationData.measurements.first(where: { $0.id == measurementID }) else { return false }
            simulationDeletedMeasurements.insert(DeletedMeasurementMarker(deleted))
            simulationData.measurements.removeAll { $0.id == measurementID }
            simulationArchiveUpdatedAt = .now
            return true
        }

        guard let deleted = measurements.first(where: { $0.id == measurementID }) else { return false }
        deletedMeasurements.insert(DeletedMeasurementMarker(deleted))
        measurements.removeAll { $0.id == measurementID }
        if latestHealthShareCandidate?.id == measurementID {
            latestHealthShareCandidate = nil
        }
        persistArchive()
        return true
    }

    @discardableResult
    func add(_ measurement: BodyMeasurement, retainForRetry: Bool = true) -> Bool {
        if isSimulationEnabled {
            addSimulationMeasurement(measurement)
            return true
        }

        guard profiles.contains(where: { $0.id == selectedProfileID }) else { return false }
        var attributed = measurement
        attributed.profileID = selectedProfileID
        if let deviceID = measurement.deviceID,
           let scale = pairedScales.first(where: { $0.id == deviceID }) {
            attributed.deviceName = scale.name
        }
        let pending = PendingMeasurement(
            raw: attributed,
            mergesContinuousMeasurements: mergeFrequentMeasurements
        )
        if retainForRetry {
            pendingMeasurements.removeAll { $0.raw.id == attributed.id }
            pendingMeasurements.append(pending)
            return retryPendingMeasurements()
        }
        return saveMeasurement(pending)
    }

    @discardableResult
    func retryPendingMeasurements() -> Bool {
        guard !isSimulationEnabled else { return false }
        for pending in pendingMeasurements {
            guard saveMeasurement(pending) else { return false }
        }
        return true
    }

    private func saveMeasurement(_ pending: PendingMeasurement) -> Bool {
        var snapshot = archive
        var candidate = pending.raw
        let measurement = pending.raw
        if let index = snapshot.measurements.firstIndex(where: { $0.id == measurement.id }) {
            snapshot.measurements[index] = measurement
        } else if pending.mergesContinuousMeasurements,
                  let latest = snapshot.measurements.first,
                  latest.date <= measurement.date,
                  let merged = latest.mergingContinuousMeasurement(measurement) {
            snapshot.measurements[0] = merged
            candidate.id = merged.id
        } else {
            snapshot.measurements.append(measurement)
        }
        snapshot.measurements.sort { $0.date > $1.date }
        snapshot.deletedMeasurements = Set(snapshot.deletedMeasurements.filter {
            $0.id != measurement.id && $0.id != candidate.id
        })
        snapshot.updatedAt = .now
        do {
            try writeArchive(snapshot)
        } catch {
            measurementSaveError = error.localizedDescription
            return false
        }
        measurements = snapshot.measurements
        deletedMeasurements = snapshot.deletedMeasurements
        archiveUpdatedAt = snapshot.updatedAt
        pendingMeasurements.removeAll { $0.raw.id == pending.raw.id }
        if pendingMeasurements.isEmpty { measurementSaveError = nil }
        archiveStorageError = nil
        // Only durable measurements may be published to Apple Health.
        latestHealthShareCandidate = candidate
        return true
    }

    @discardableResult
    func importAppleHealthMeasurements(_ importedMeasurements: [BodyMeasurement]) -> Int {
        guard !isSimulationEnabled,
              isAppleHealthImportEnabled,
              let currentUser = profiles.first(where: { $0.role == "本人" }) else { return 0 }
        let existingIDs = Set(measurements.map(\.id)).union(deletedMeasurements.map(\.id))
        let newMeasurements = importedMeasurements.compactMap { measurement -> BodyMeasurement? in
            guard !existingIDs.contains(measurement.id), measurement.source == .appleHealth else { return nil }
            var attributed = measurement
            attributed.profileID = currentUser.id
            attributed.deviceID = nil
            attributed.deviceName = nil
            return attributed
        }
        guard !newMeasurements.isEmpty else { return 0 }
        measurements.append(contentsOf: newMeasurements)
        measurements.sort { $0.date > $1.date }
        persistArchive()
        return newMeasurements.count
    }

    @discardableResult
    func importDeviceHistory(_ history: [BodyMeasurement]) -> DeviceHistoryImportSummary {
        guard !isSimulationEnabled else {
            return DeviceHistoryImportSummary(importedCount: 0, duplicateCount: 0, unmatchedCount: history.count)
        }
        let plan = DeviceHistoryMatcher.plan(
            history: history,
            profiles: profiles,
            existingMeasurements: measurements,
            deletedMeasurements: deletedMeasurements
        )
        for measurement in plan.attributedMeasurements {
            var attributed = measurement
            if let deviceID = attributed.deviceID,
               let scale = pairedScales.first(where: { $0.id == deviceID }) {
                attributed.deviceName = scale.name
            }
            guard let profileID = attributed.profileID,
                  profiles.contains(where: { $0.id == profileID }) else { continue }
            measurements.append(attributed)
        }
        guard !plan.attributedMeasurements.isEmpty else { return plan.summary }
        measurements.sort { $0.date > $1.date }
        persistArchive()
        return plan.summary
    }

    @discardableResult
    func addManual(
        weightKG: Double,
        impedanceOhm: Double? = nil,
        bodyFatPercent: Double? = nil,
        muscleMassKG: Double? = nil,
        waterPercent: Double? = nil,
        visceralFat: Double? = nil,
        basalMetabolismKCal: Double? = nil,
        boneMassKG: Double? = nil
    ) -> Bool {
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
            ),
            retainForRetry: false
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
            guard id == nil || simulationData.profiles.contains(where: { $0.id == id && $0.role == "本人" }) else { return }
            simulationAppleHealthProfileID = id
        } else {
            guard id == nil || profiles.contains(where: { $0.id == id && $0.role == "本人" }) else { return }
            appleHealthProfileID = id
        }
    }

    func setDisplayAppleHealthImportEnabled(_ isEnabled: Bool) {
        if isSimulationEnabled {
            simulationIsAppleHealthImportEnabled = isEnabled
        } else {
            isAppleHealthImportEnabled = isEnabled
        }
    }

    func toggleDisplayAppleHealthReadType(_ type: AppleHealthDataType) {
        if isSimulationEnabled {
            Self.toggleAppleHealthReadType(type, in: &simulationAppleHealthReadTypes)
        } else {
            Self.toggleAppleHealthReadType(type, in: &appleHealthReadTypes)
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
            var newProfile = profile
            if simulationData.profiles.isEmpty { newProfile.role = "本人" }
            else if newProfile.role == "本人" { newProfile.role = "其他" }
            simulationData.profiles.append(newProfile)
            return
        }
        let isFirstProfile = profiles.isEmpty
        var newProfile = profile
        if isFirstProfile { newProfile.role = "本人" }
        else if newProfile.role == "本人" { newProfile.role = "其他" }
        profiles.append(newProfile)
        if isFirstProfile {
            selectedProfileID = newProfile.id
        }
    }

    func updateProfile(_ profile: UserProfile) {
        if isSimulationEnabled {
            guard let index = simulationData.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
            var updated = profile
            if simulationData.profiles[index].role == "本人" { updated.role = "本人" }
            else if updated.role == "本人" { updated.role = "其他" }
            simulationData.profiles[index] = updated
            return
        }
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        if profiles[index].role == "本人" { updated.role = "本人" }
        else if updated.role == "本人" { updated.role = "其他" }
        profiles[index] = updated
    }

    func moveProfile(_ profileID: UUID, onto targetProfileID: UUID) {
        if isSimulationEnabled {
            moveProfile(profileID, onto: targetProfileID, in: &simulationData.profiles)
            return
        }
        moveProfile(profileID, onto: targetProfileID, in: &profiles)
    }

    func setDisplayProfileOrder(_ orderedProfileIDs: [UUID]) {
        let currentProfiles = managedProfiles
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
                  let index = simulationData.profiles.firstIndex(where: { $0.id == id }),
                  simulationData.profiles[index].role != "本人" else { return }
            simulationData.profiles.remove(at: index)
            if simulationAppleHealthProfileID == id { simulationAppleHealthProfileID = nil }
            if simulationSelectedProfileID == id {
                simulationSelectedProfileID = Self.preferredProfileID(in: simulationData.profiles)
                    ?? simulationData.profiles[0].id
                simulationData.selectedProfileID = simulationSelectedProfileID
            }
            return
        }
        guard profiles.count > 1,
              let index = profiles.firstIndex(where: { $0.id == id }),
              profiles[index].role != "本人" else { return }
        profiles.remove(at: index)
        if appleHealthProfileID == id { appleHealthProfileID = nil }
        if selectedProfileID == id {
            selectedProfileID = Self.preferredProfileID(in: profiles) ?? profiles[0].id
        }
    }

    func addScale(_ scale: PairedScale) {
        if isSimulationEnabled {
            guard !simulationData.pairedScales.contains(where: { $0.id == scale.id }) else { return }
            simulationData.pairedScales.append(scale)
            return
        }
        guard !profiles.isEmpty,
              !pairedScales.contains(where: { $0.id == scale.id }) else { return }
        pairedScales.append(scale)
    }

    func setDisplayScaleOrder(_ orderedScaleIDs: [UUID]) {
        let currentScales = displayPairedScales
        guard orderedScaleIDs.count == currentScales.count,
              Set(orderedScaleIDs).count == orderedScaleIDs.count,
              Set(orderedScaleIDs) == Set(currentScales.map(\.id)) else { return }
        let scalesByID = Dictionary(
            currentScales.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        let reorderedScales = orderedScaleIDs.compactMap { scalesByID[$0] }
        guard reorderedScales != currentScales else { return }

        if isSimulationEnabled {
            simulationData.pairedScales = reorderedScales
        } else {
            pairedScales = reorderedScales
        }
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

    func setAutomaticHistoryImportEnabled(_ isEnabled: Bool, for scaleID: UUID) {
        if isSimulationEnabled {
            guard let index = simulationData.pairedScales.firstIndex(where: { $0.id == scaleID }) else { return }
            simulationData.pairedScales[index].automaticallyImportsHistory = isEnabled
            return
        }
        guard let index = pairedScales.firstIndex(where: { $0.id == scaleID }) else { return }
        pairedScales[index].automaticallyImportsHistory = isEnabled
    }

    var communicationRules: [CommunicationRule] {
        CommunicationRuleCatalog.rules(custom: customCommunicationRules)
    }

    func communicationRule(for scale: PairedScale) -> CommunicationRule? {
        guard let id = scale.communicationRuleID else { return nil }
        return communicationRules.first { $0.id == id }
    }

    func effectiveCommunicationRule(for scale: PairedScale) -> CommunicationRule? {
        if let selectedRule = communicationRule(for: scale) {
            return selectedRule.canMeasure ? selectedRule : nil
        }

        let ruleID = CommunicationRuleCatalog.automaticRuleID(for: scale.compatibility)
        guard let ruleID else { return nil }
        return communicationRules.first { $0.id == ruleID && $0.canMeasure }
    }

    func setCommunicationRule(_ ruleID: String?, for scaleID: UUID) {
        if isSimulationEnabled {
            guard ruleID == nil || communicationRules.contains(where: { $0.id == ruleID && $0.canMeasure }),
                  let index = simulationData.pairedScales.firstIndex(where: { $0.id == scaleID }) else { return }
            simulationData.pairedScales[index].communicationRuleID = ruleID
            return
        }
        guard ruleID == nil || communicationRules.contains(where: { $0.id == ruleID && $0.canMeasure }),
              let index = pairedScales.firstIndex(where: { $0.id == scaleID }) else { return }
        pairedScales[index].communicationRuleID = ruleID
    }

    @discardableResult
    func importCommunicationRules(_ data: Data) throws -> Int {
        let imported = try CommunicationRuleCodec.decode(data)
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

    func simulatedCommunicationRuleImportData(fileName: String) throws -> Data {
        guard isSimulationEnabled else {
            throw CommunicationRuleError.invalidDocument("模拟协议导入仅在模拟数据模式可用")
        }
        return try simulationCommunicationRuleImportSequence.makeImportData(fileName: fileName)
    }

    func removeCommunicationRule(_ id: String) {
        customCommunicationRules.removeAll { $0.id == id }
        if isSimulationEnabled {
            for index in simulationData.pairedScales.indices
                where simulationData.pairedScales[index].communicationRuleID == id {
                simulationData.pairedScales[index].communicationRuleID = nil
            }
        } else {
            for index in pairedScales.indices where pairedScales[index].communicationRuleID == id {
                pairedScales[index].communicationRuleID = nil
            }
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

    private static func preferredProfileID(in profiles: [UserProfile]) -> UUID? {
        profiles.first(where: { $0.role == "本人" })?.id ?? profiles.first?.id
    }

    private static func normalizedProfiles(_ profiles: [UserProfile]) -> [UserProfile] {
        guard !profiles.isEmpty else { return [] }
        let currentUserID = profiles.first(where: { $0.role == "本人" })?.id ?? profiles[0].id
        return profiles.map { profile in
            var normalized = profile
            if normalized.id == currentUserID {
                normalized.role = "本人"
            } else if normalized.role == "本人" {
                normalized.role = "其他"
            }
            return normalized
        }
    }

    private static func toggleAppleHealthReadType(
        _ type: AppleHealthDataType,
        in selection: inout Set<AppleHealthDataType>
    ) {
        if selection.contains(type) {
            selection.remove(type)
            if type == .bodyMass {
                selection.remove(.bodyFatPercentage)
            }
        } else {
            selection.insert(type)
            if type == .bodyFatPercentage {
                selection.insert(.bodyMass)
            }
        }
    }

    private var placeholderProfile: UserProfile {
        UserProfile(
            id: Self.placeholderProfileID,
            name: appLanguage.text("示例用户"),
            role: "本人",
            heightCM: 168,
            referenceWeightKG: 60,
            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now,
            biologicalSex: .female,
            avatar: .adult
        )
    }

    func delete(at offsets: IndexSet) {
        if isSimulationEnabled {
            let visibleMeasurements = displayMeasurements(for: simulationSelectedProfileID)
            let idsToDelete = Set(offsets.compactMap { offset in
                visibleMeasurements.indices.contains(offset) ? visibleMeasurements[offset].id : nil
            })
            simulationDeletedMeasurements.formUnion(
                simulationData.measurements
                    .filter { idsToDelete.contains($0.id) }
                    .map(DeletedMeasurementMarker.init)
            )
            simulationData.measurements.removeAll { idsToDelete.contains($0.id) }
            simulationArchiveUpdatedAt = .now
            return
        }
        for offset in offsets where measurements.indices.contains(offset) {
            deletedMeasurements.insert(DeletedMeasurementMarker(measurements[offset]))
        }
        measurements.remove(atOffsets: offsets)
        persistArchive()
    }

    func apply(configuration: AppConfiguration) {
        if isSimulationEnabled {
            applySimulation(configuration: configuration)
            return
        }
        var normalizedConfiguration = configuration
        normalizedConfiguration.profiles = Self.normalizedProfiles(configuration.profiles)
        normalizedConfiguration.appleHealthReadTypes.insert(.bodyMass)
        normalizedConfiguration.appleHealthProfileID = configuration.appleHealthProfileID.flatMap { profileID in
            normalizedConfiguration.profiles.contains(where: { $0.id == profileID && $0.role == "本人" })
                ? profileID
                : nil
        }
        guard normalizedConfiguration != self.configuration else { return }
        isApplyingExternalState = true
        profiles = normalizedConfiguration.profiles
        selectedProfileID = normalizedConfiguration.profiles.contains(where: { $0.id == selectedProfileID })
            ? selectedProfileID
            : Self.preferredProfileID(in: normalizedConfiguration.profiles) ?? Self.placeholderProfileID
        pairedScales = normalizedConfiguration.pairedScales
        unit = normalizedConfiguration.unit
        languageSelection = normalizedConfiguration.languageSelection
        appLanguage = normalizedConfiguration.languageSelection.resolvedLanguage
        visualTheme = normalizedConfiguration.visualTheme
        appearance = normalizedConfiguration.appearance
        mergeFrequentMeasurements = normalizedConfiguration.mergeFrequentMeasurements
        isSimulationEnabled = normalizedConfiguration.isSimulationEnabled
        appleHealthProfileID = normalizedConfiguration.appleHealthProfileID
        appleHealthDeviceIDs = normalizedConfiguration.appleHealthDeviceIDs.intersection(
            Set(normalizedConfiguration.pairedScales.map(\.id))
        )
        isAppleHealthImportEnabled = normalizedConfiguration.isAppleHealthImportEnabled
        appleHealthReadTypes = normalizedConfiguration.appleHealthReadTypes
        customCommunicationRules = normalizedConfiguration.customCommunicationRules
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(normalizedConfiguration.dashboardMetricOrder)
        dashboardVisibleMetrics = normalizedConfiguration.dashboardVisibleMetrics
        widgetProfileID = normalizedConfiguration.widgetProfileID
        widgetTimeRange = normalizedConfiguration.widgetTimeRange
        widgetDisplayStyle = normalizedConfiguration.widgetDisplayStyle
        isApplyingExternalState = false
        if isSimulationEnabled {
            simulationModeDidChange()
        } else {
            persistConfiguration()
        }
    }

    func apply(archive: MeasurementArchive) {
        if isSimulationEnabled {
            applySimulation(archive: archive)
            return
        }
        let normalized = MeasurementArchive(
            updatedAt: archive.updatedAt,
            measurements: archive.measurements
                .filter { measurement in
                    !archive.deletedMeasurements.contains(where: { $0.matches(measurement) })
                }
                .sorted { $0.date > $1.date },
            deletedMeasurements: archive.deletedMeasurements
        )
        guard normalized != self.archive else { return }
        measurements = normalized.measurements
        deletedMeasurements = normalized.deletedMeasurements
        archiveUpdatedAt = normalized.updatedAt
        persistArchive(markAsChanged: false)
    }

    @discardableResult
    func deleteLocalData(includeConfiguration: Bool) -> Bool {
        guard let persistenceWriter else {
            archiveStorageError = "无法初始化本地存储"
            return false
        }

        do {
            if includeConfiguration {
                try persistenceWriter.deleteConfigurationAndArchive()
                resetToFreshInstallState()
            } else {
                try persistenceWriter.deleteArchive()
                measurements = []
                deletedMeasurements = []
                archiveUpdatedAt = .distantPast
                latestHealthShareCandidate = nil
            }
            pendingMeasurements = []
            measurementSaveError = nil
            if includeConfiguration { configurationStorageError = nil }
            archiveStorageError = nil
            return true
        } catch {
            archiveStorageError = error.localizedDescription
            return false
        }
    }

    private func resetToFreshInstallState() {
        let defaults = AppConfiguration.standard
        isApplyingExternalState = true
        simulationDataLoadGeneration += 1
        simulationDataLoadTask?.cancel()
        simulationDataLoadTask = nil
        isSimulationDataLoading = false
        isSimulationHistoryLoaded = false
        configurationBeforeSimulation = nil

        profiles = defaults.profiles
        selectedProfileID = Self.placeholderProfileID
        pairedScales = defaults.pairedScales
        unit = defaults.unit
        languageSelection = defaults.languageSelection
        appLanguage = defaults.languageSelection.resolvedLanguage
        visualTheme = defaults.visualTheme
        appearance = defaults.appearance
        mergeFrequentMeasurements = defaults.mergeFrequentMeasurements
        isSimulationEnabled = false
        appleHealthProfileID = nil
        appleHealthDeviceIDs = []
        isAppleHealthImportEnabled = false
        appleHealthReadTypes = defaults.appleHealthReadTypes
        customCommunicationRules = []
        dashboardMetricOrder = defaults.dashboardMetricOrder
        dashboardVisibleMetrics = defaults.dashboardVisibleMetrics
        widgetProfileID = nil
        widgetTimeRange = defaults.widgetTimeRange
        widgetDisplayStyle = defaults.widgetDisplayStyle
        measurements = []
        deletedMeasurements = []
        archiveUpdatedAt = .distantPast
        latestHealthShareCandidate = nil

        simulationData = SimulationDataSnapshot.makeMetadata(
            language: appLanguage,
            launchDay: simulationLaunchDay,
            calendar: simulationCalendar
        )
        simulationSelectedProfileID = simulationData.selectedProfileID
        simulationAppleHealthProfileID = nil
        simulationAppleHealthDeviceIDs = []
        simulationIsAppleHealthImportEnabled = false
        simulationAppleHealthReadTypes = defaults.appleHealthReadTypes
        simulationDeletedMeasurements = []
        simulationArchiveUpdatedAt = .distantPast
        simulationCommunicationRuleImportSequence = SimulationCommunicationRuleImportSequence()
        isApplyingExternalState = false
    }

    private func applySimulation(configuration: AppConfiguration) {
        guard !configuration.profiles.isEmpty else { return }
        isApplyingExternalState = true
        let normalizedProfiles = Self.normalizedProfiles(configuration.profiles)
        simulationData.profiles = normalizedProfiles
        if !normalizedProfiles.contains(where: { $0.id == simulationSelectedProfileID }) {
            simulationSelectedProfileID = Self.preferredProfileID(in: normalizedProfiles)
                ?? normalizedProfiles[0].id
        }
        simulationData.selectedProfileID = simulationSelectedProfileID
        simulationData.pairedScales = configuration.pairedScales
        unit = configuration.unit
        languageSelection = configuration.languageSelection
        appLanguage = configuration.languageSelection.resolvedLanguage
        visualTheme = configuration.visualTheme
        appearance = configuration.appearance
        mergeFrequentMeasurements = configuration.mergeFrequentMeasurements
        simulationAppleHealthProfileID = configuration.appleHealthProfileID.flatMap { profileID in
            normalizedProfiles.contains(where: { $0.id == profileID && $0.role == "本人" }) ? profileID : nil
        }
        simulationAppleHealthDeviceIDs = configuration.appleHealthDeviceIDs.intersection(
            Set(configuration.pairedScales.map(\.id))
        )
        simulationIsAppleHealthImportEnabled = configuration.isAppleHealthImportEnabled
        simulationAppleHealthReadTypes = configuration.appleHealthReadTypes
        customCommunicationRules = configuration.customCommunicationRules
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(configuration.dashboardMetricOrder)
        dashboardVisibleMetrics = configuration.dashboardVisibleMetrics
        widgetProfileID = configuration.widgetProfileID
        widgetTimeRange = configuration.widgetTimeRange
        widgetDisplayStyle = configuration.widgetDisplayStyle
        isApplyingExternalState = false
    }

    private func applySimulation(archive: MeasurementArchive) {
        let normalized = MeasurementArchive(
            updatedAt: archive.updatedAt,
            measurements: archive.measurements
                .filter { measurement in
                    !archive.deletedMeasurements.contains(where: { $0.matches(measurement) })
                }
                .sorted { $0.date > $1.date },
            deletedMeasurements: archive.deletedMeasurements
        )
        guard normalized != currentArchive else { return }
        simulationData.measurements = normalized.measurements
        simulationDeletedMeasurements = normalized.deletedMeasurements
        simulationArchiveUpdatedAt = normalized.updatedAt
        isSimulationHistoryLoaded = true
        simulationDataLoadGeneration += 1
        simulationDataLoadTask?.cancel()
        simulationDataLoadTask = nil
        isSimulationDataLoading = false
    }

    private func persistConfigurationIfNeeded() {
        guard !isApplyingExternalState, !isSimulationEnabled else { return }
        persistConfiguration()
    }

    private func simulationModeDidChange() {
        guard !isApplyingExternalState else { return }
        if isSimulationEnabled {
            var baseline = configuration
            baseline.isSimulationEnabled = false
            configurationBeforeSimulation = baseline
            simulationSelectedProfileID = simulationData.selectedProfileID
            customCommunicationRules = SimulationCommunicationRuleCatalog.initialRules
            simulationCommunicationRuleImportSequence = SimulationCommunicationRuleImportSequence()
            prepareSimulationDataIfNeeded()
        } else if let baseline = configurationBeforeSimulation {
            restoreSharedConfiguration(from: baseline)
            configurationBeforeSimulation = nil
        }
        persistConfiguration()
    }

    private func restoreSharedConfiguration(from configuration: AppConfiguration) {
        isApplyingExternalState = true
        unit = configuration.unit
        languageSelection = configuration.languageSelection
        appLanguage = configuration.languageSelection.resolvedLanguage
        visualTheme = configuration.visualTheme
        appearance = configuration.appearance
        mergeFrequentMeasurements = configuration.mergeFrequentMeasurements
        customCommunicationRules = configuration.customCommunicationRules
        dashboardMetricOrder = MeasurementStore.sanitizedMetricOrder(configuration.dashboardMetricOrder)
        dashboardVisibleMetrics = configuration.dashboardVisibleMetrics
        widgetProfileID = configuration.widgetProfileID
        widgetTimeRange = configuration.widgetTimeRange
        widgetDisplayStyle = configuration.widgetDisplayStyle
        isApplyingExternalState = false
    }

    func prepareSimulationDataIfNeeded() {
        guard isSimulationEnabled,
              !isSimulationHistoryLoaded,
              simulationDataLoadTask == nil else { return }

        let metadata = simulationData
        let launchDay = simulationLaunchDay
        let calendar = simulationCalendar
        let needsRecentMeasurements = simulationData.measurements.isEmpty
        simulationDataLoadGeneration += 1
        let loadGeneration = simulationDataLoadGeneration
        isSimulationDataLoading = true
        simulationDataLoadTask = Task {
            // Let SwiftUI commit the switch state before starting any simulation work.
            await Task.yield()

            let recentMeasurements: [BodyMeasurement]
            if needsRecentMeasurements {
                recentMeasurements = await Task.detached(priority: .userInitiated) {
                    metadata.generatedMeasurements(
                        dayOffsets: 0...6,
                        launchDay: launchDay,
                        calendar: calendar
                    )
                }.value
            } else {
                recentMeasurements = []
            }

            guard !Task.isCancelled,
                  loadGeneration == simulationDataLoadGeneration else { return }

            if !recentMeasurements.isEmpty {
                let pendingMeasurements = simulationData.measurements
                simulationData.measurements = (recentMeasurements + pendingMeasurements)
                    .sorted { $0.date > $1.date }
            }

            let historicalMeasurements = await Task.detached(priority: .utility) {
                metadata.generatedMeasurements(
                    dayOffsets: 7...364,
                    launchDay: launchDay,
                    calendar: calendar
                )
            }.value

            guard !Task.isCancelled,
                  loadGeneration == simulationDataLoadGeneration else { return }

            let measurementsAwaitingHistory = simulationData.measurements
            simulationData.measurements = (historicalMeasurements + measurementsAwaitingHistory)
                .sorted { $0.date > $1.date }
            isSimulationHistoryLoaded = true
            isSimulationDataLoading = false
            simulationDataLoadTask = nil
        }
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
        let previousLanguage = appLanguage
        appLanguage = resolvedLanguage

        if simulationDataLoadTask != nil {
            simulationDataLoadGeneration += 1
            simulationDataLoadTask?.cancel()
            simulationDataLoadTask = nil
            isSimulationDataLoading = false
        }

        simulationData.relocalizeDefaults(from: previousLanguage, to: appLanguage)
        prepareSimulationDataIfNeeded()
    }

    private func addSimulationMeasurement(_ measurement: BodyMeasurement) {
        var attributed = measurement
        attributed.profileID = simulationSelectedProfileID
        if let deviceID = measurement.deviceID,
           let scale = simulationData.pairedScales.first(where: { $0.id == deviceID }) {
            attributed.deviceName = scale.name
        }
        guard simulationData.profiles.contains(where: { $0.id == simulationSelectedProfileID }) else { return }
        let measurement = attributed

        if mergeFrequentMeasurements,
           let index = simulationData.measurements.firstIndex(where: {
               $0.mergingContinuousMeasurement(measurement) != nil
           }),
           let merged = simulationData.measurements[index].mergingContinuousMeasurement(measurement) {
            simulationData.measurements[index] = merged
            attributed.id = merged.id
        } else {
            simulationData.measurements.append(measurement)
        }
        simulationDeletedMeasurements = Set(simulationDeletedMeasurements.filter { $0.id != measurement.id && $0.id != attributed.id })
        simulationData.measurements.sort { $0.date > $1.date }
        simulationArchiveUpdatedAt = .now
    }

    private func persistConfiguration() {
        guard let persistenceWriter else {
            configurationStorageError = "无法初始化本地存储"
            return
        }
        configurationRevision += 1
        var snapshot = configurationBeforeSimulation ?? configuration
        snapshot.isSimulationEnabled = isSimulationEnabled
        do {
            try persistenceWriter.saveConfiguration(snapshot, revision: configurationRevision)
            configurationStorageError = nil
        } catch {
            configurationStorageError = error.localizedDescription
        }
    }

    private func writeArchive(_ snapshot: MeasurementArchive) throws {
        guard let persistenceWriter else {
            throw CocoaError(.fileWriteUnknown)
        }
        archiveRevision += 1
        try persistenceWriter.saveArchive(snapshot, revision: archiveRevision)
    }

    private func persistArchive(markAsChanged: Bool = true) {
        if markAsChanged { archiveUpdatedAt = .now }
        do {
            try writeArchive(archive)
            archiveStorageError = nil
        } catch {
            archiveStorageError = error.localizedDescription
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
