import Foundation

@MainActor
final class MeasurementStore: ObservableObject {
    @Published private(set) var measurements: [BodyMeasurement]
    @Published private(set) var deletedMeasurementIDs: Set<UUID>
    @Published var profile: UserProfile { didSet { persistConfigurationIfNeeded() } }
    @Published var unit: WeightUnit { didSet { persistConfigurationIfNeeded() } }
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
        profile = loadedConfiguration.profile
        unit = loadedConfiguration.unit
        measurements = loadedArchive.measurements.sorted { $0.date > $1.date }
        deletedMeasurementIDs = loadedArchive.deletedMeasurementIDs
        archiveUpdatedAt = loadedArchive.updatedAt
        storageError = initialError
    }

    var configuration: AppConfiguration {
        AppConfiguration(profile: profile, unit: unit)
    }

    var archive: MeasurementArchive {
        MeasurementArchive(
            updatedAt: archiveUpdatedAt,
            measurements: measurements,
            deletedMeasurementIDs: deletedMeasurementIDs
        )
    }

    var displayMeasurements: [BodyMeasurement] { measurements.isEmpty ? Self.demoMeasurements : measurements }
    var latest: BodyMeasurement? { displayMeasurements.first }
    var isShowingDemoData: Bool { measurements.isEmpty }

    func add(_ measurement: BodyMeasurement) {
        let enriched = BodyCompositionEstimator.enriching(measurement, profile: profile)
        if let first = measurements.first,
           first.source == enriched.source,
           abs(first.date.timeIntervalSince(enriched.date)) < 30,
           abs(first.weightKG - enriched.weightKG) < 0.05 {
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

    func delete(at offsets: IndexSet) {
        for offset in offsets where measurements.indices.contains(offset) {
            deletedMeasurementIDs.insert(measurements[offset].id)
        }
        measurements.remove(atOffsets: offsets)
        persistArchive()
    }

    func apply(configuration: AppConfiguration) {
        guard configuration != self.configuration else { return }
        isApplyingExternalState = true
        profile = configuration.profile
        unit = configuration.unit
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
