import Foundation

@main
struct MeasurementSnapshotSmoke {
    static func main() throws {
        // Deterministic synthetic data, unrelated to any personal measurement.
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let profile = UserProfile(heightCM: 180,
            birthDate: calendar.date(from: DateComponents(year: 1994, month: 6, day: 15))!, biologicalSex: .male)
        var raw = BodyMeasurement(date: date, weightKG: 81, impedanceOhm: 500,
            source: .wolaiAFU, isStable: true, profileID: profile.id)
        raw.proteinPercent = 16
        raw.skeletalMuscleMassKG = 30
        raw.subcutaneousFatPercent = 18
        let record = BodyCompositionCalculation.recording(raw, profile: profile)
        precondition(record.bodyFatPercent == nil) // Estimates never overwrite hardware fields.
        precondition(record.applicationEstimate != nil)
        precondition(record.calculatedMetrics?.values.count == 13)
        precondition(record.calculatedMetrics?.values["bmi"] == 25)
        precondition(record.proteinPercent == 16)
        let archive = MeasurementArchive(updatedAt: date, measurements: [record], deletedMeasurements: [])
        let service = LocalDataTransferService()
        for pretty in [false, true] {
            let data = try RecordFileCodec.encode(archive, prettyPrinted: pretty)
            let restored = try RecordFileCodec.decode(data)
            precondition(restored.measurements == [record])
            let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let columns = object["columns"] as! [String]
            let rows = object["records"] as! [[Any]]
            let snapshot = rows[0][columns.firstIndex(of: "calculatedMetrics")!] as! [String: Any]
            precondition((snapshot["values"] as! [String: Double])["bmi"] == 25)
        }
        let imported = try service.importRecords(from: service.exportRecords(archive))
        precondition(imported.measurements == [record])
        var configuration = AppConfiguration.standard
        configuration.profiles = [profile]
        let combined = try service.importCombined(from: service.exportCombined(configuration: configuration, archive: archive))
        precondition(combined.archive.measurements == [record])
        var changedProfile = profile
        changedProfile.heightCM = 160
        changedProfile.biologicalSex = .female
        changedProfile.birthDate = calendar.date(from: DateComponents(year: 2010, month: 6, day: 15))!
        for metric in DashboardMetricKind.allCases {
            precondition(metric.value(in: record, profile: changedProfile) == metric.value(in: record, profile: profile))
            precondition(metric.assessment(in: record, profile: changedProfile) == metric.assessment(in: record, profile: profile))
        }
        precondition(record.bmi(heightCM: changedProfile.heightCM) == 25)
        let reassigned = BodyCompositionCalculation.recording(record, profile: changedProfile)
        precondition(reassigned.calculatedMetrics != record.calculatedMetrics)
        precondition(reassigned.applicationEstimate?.sex == .female)
        var supplied = raw
        supplied.bodyFatPercent = 22
        let suppliedRecord = BodyCompositionCalculation.recording(supplied, profile: profile)
        precondition(suppliedRecord.displayedBodyFatPercent == 22 && !suppliedRecord.usesEstimatedBodyFat)
        raw.impedanceOhm = nil
        let noImpedance = BodyCompositionCalculation.recording(raw, profile: profile)
        precondition(noImpedance.calculatedMetrics?.values["bmi"] == 25)
        precondition(noImpedance.displayedBodyFatPercent == nil)
        precondition(noImpedance.calculatedMetrics?.values["bodyFatPercent"] == nil)
        raw.source = .manual
        precondition(BodyCompositionCalculation.recording(raw, profile: profile).calculatedMetrics?.values["bmi"] == 25)
        raw.isStable = false
        precondition(BodyCompositionCalculation.recording(raw, profile: profile).calculatedMetrics == nil)
        print("Measurement snapshot smoke checks passed")
    }
}
