import Foundation
import Combine

@main
struct MeasurementSaveSmoke {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ScaleMe-MeasurementSave-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try LocalAppRepository(directoryURL: directory)
        let store = MeasurementStore(repository: repository)
        let first = UserProfile(name: "First", role: "本人")
        let second = UserProfile(name: "Second", role: "其他")
        store.addProfile(first)
        store.addProfile(second)
        store.mergeFrequentMeasurements = false
        let original = store.archive
        let archiveURL = directory.appending(path: AppStorageLayout.dataFileName)
        // A directory in place of the file deterministically rejects atomic writes.
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: false)
        var published: [BodyMeasurement] = []
        let subscription = store.$latestHealthShareCandidate.compactMap { $0 }.sink { published.append($0) }
        defer { subscription.cancel() }
        let measurement = BodyMeasurement(
            date: .now, weightKG: 65, impedanceOhm: 500,
            source: .manual, isStable: true, deviceID: UUID()
        )
        precondition(!store.add(measurement))
        precondition(store.archive == original, "failed writes must not publish provisional records")
        precondition(store.isMeasurementPending(measurement.id))
        precondition(published.isEmpty, "failed saves must not trigger HealthKit")
        let failure = store.measurementSaveError
        precondition(failure != nil)
        store.unit = .jin
        precondition(store.measurementSaveError == failure && store.storageError != nil,
                     "configuration success must not hide a measurement failure")
        precondition(!store.retryPendingMeasurements())
        precondition(store.archive == original && published.isEmpty)
        store.selectProfile(second.id)
        try FileManager.default.removeItem(at: archiveURL)
        precondition(store.retryPendingMeasurements())
        precondition(!store.hasPendingMeasurements && store.measurementSaveError == nil)
        precondition(store.measurements.count == 1)
        precondition(store.measurements[0].bodyFatPercent == nil)
        precondition(store.measurements[0].visceralFat == nil)
        precondition(store.measurements[0].basalMetabolismKCal == nil)
        precondition(store.measurements[0].id == measurement.id)
        precondition(store.measurements[0].date == measurement.date)
        precondition(store.measurements[0].profileID == first.id, "retry must retain original owner")
        precondition(published.count == 1 && published[0].profileID == first.id)
        precondition(tryArchive(repository) == store.archive)
        precondition(store.retryPendingMeasurements())
        precondition(published.count == 1 && store.measurements.count == 1, "retry must be idempotent")

        let manualDate = Date(timeIntervalSince1970: 1_700_000_000)
        let persisted = store.archive
        try FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: false)
        precondition(!store.addManual(date: manualDate, weightKG: 72))
        precondition(store.archive == persisted && !store.hasPendingMeasurements,
                     "manual failures retain the editable form, not an additional queued copy")
        precondition(published.count == 1)
        try FileManager.default.removeItem(at: archiveURL)
        precondition(store.addManual(date: manualDate, weightKG: 72))
        precondition(store.measurements.count == 2 && published.count == 2)
        precondition(store.measurements.last?.date == manualDate, "backdated manual entries retain the selected time and sort chronologically")
        precondition(tryArchive(repository) == store.archive)

        let configurationURL = directory.appending(path: AppStorageLayout.configurationFileName)
        try FileManager.default.removeItem(at: configurationURL)
        try FileManager.default.createDirectory(at: configurationURL, withIntermediateDirectories: false)
        store.unit = .kilograms
        precondition(store.configurationStorageError != nil)
        precondition(store.addManual(date: manualDate.addingTimeInterval(60), weightKG: 73))
        precondition(store.configurationStorageError != nil && store.storageError != nil,
                     "archive success must not clear configuration errors")
        try FileManager.default.removeItem(at: configurationURL)
        store.unit = .jin
        precondition(store.storageError == nil)

        store.mergeFrequentMeasurements = true
        let baseline = BodyMeasurement(
            date: .now.addingTimeInterval(120), weightKG: 66,
            source: .manual, isStable: true, deviceID: UUID()
        )
        precondition(store.add(baseline))
        let beforeMerge = store.archive
        let beforeShareCount = published.count
        var next = baseline
        next.id = UUID()
        next.date = baseline.date.addingTimeInterval(5)
        next.weightKG = 66.2
        try FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: false)
        precondition(!store.add(next))
        var later = baseline
        later.id = UUID()
        later.date = baseline.date.addingTimeInterval(60)
        precondition(!store.add(later))
        precondition(store.archive == beforeMerge && published.count == beforeShareCount,
                     "a failed merge must preserve the prior measurement")
        try FileManager.default.removeItem(at: archiveURL)
        precondition(store.retryPendingMeasurements())
        precondition(!store.hasPendingMeasurements)
        precondition(store.measurements.count == beforeMerge.measurements.count + 1)
        precondition(store.measurements.first(where: { $0.id == baseline.id })?.weightKG == 66.2)
        precondition(published.count == beforeShareCount + 2)
        precondition(tryArchive(repository) == store.archive)

        // Revision tracking only advances after a successful write.
        let writer = LocalPersistenceWriter(repository: repository)
        try FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: false)
        do {
            try writer.saveArchive(store.archive, revision: 1)
            preconditionFailure("expected write failure")
        } catch {}
        try FileManager.default.removeItem(at: archiveURL)
        try writer.saveArchive(store.archive, revision: 1)
        precondition(tryArchive(repository) == store.archive)
        print("Measurement save smoke tests passed")
    }

    private static func tryArchive(_ repository: LocalAppRepository) -> MeasurementArchive? {
        try? repository.loadArchive()
    }
}
