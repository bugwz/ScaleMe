import Foundation

@main
enum StorageSmoke {
    static func main() throws {
        let profileID = UUID()
        let scaleID = UUID()
        let retained = BodyMeasurement(
            id: UUID(),
            date: .now,
            weightKG: 58,
            source: .manual,
            isStable: true,
            profileID: profileID,
            deviceID: scaleID,
            deviceName: "浴室秤"
        )
        let removed = BodyMeasurement(
            id: UUID(),
            date: .now.addingTimeInterval(-60),
            weightKG: 59,
            source: .manual,
            isStable: true
        )
        let local = MeasurementArchive(
            updatedAt: .now,
            measurements: [retained],
            deletedMeasurementIDs: [removed.id]
        )
        let incomingArchive = MeasurementArchive(
            updatedAt: .now.addingTimeInterval(-30),
            measurements: [removed],
            deletedMeasurementIDs: []
        )
        let merged = local.merging(incomingArchive)

        precondition(merged.measurements == [retained], "deleted records must not be resurrected")
        precondition(merged.measurements[0].deviceName == "浴室秤", "measurement source attribution must survive archive merge")

        let conflictRecord = BodyMeasurement(
            id: UUID(),
            date: .now.addingTimeInterval(-120),
            weightKG: 57.5,
            source: .manual,
            isStable: true,
            profileID: profileID
        )
        let conflictVersion = MeasurementArchive(
            updatedAt: .now.addingTimeInterval(-10),
            measurements: [conflictRecord, retained],
            deletedMeasurementIDs: [retained.id]
        )
        let conflictMerged = merged.merging(conflictVersion)

        precondition(conflictMerged.measurements == [conflictRecord], "conflict tombstones must win across all archive versions")
        precondition(conflictMerged.merging(conflictVersion) == conflictMerged, "archive merging must be idempotent")

        let profile = UserProfile(name: "测试成员", relation: "本人", avatar: .senior)
        let scale = PairedScale(
            id: scaleID,
            name: "浴室秤",
            modelName: "Test Scale",
            compatibility: "Bluetooth SIG 标准"
        )
        let configuration = AppConfiguration(
            profiles: [profile],
            pairedScales: [scale],
            unit: .kilograms,
            mergeFrequentMeasurements: true,
            isSimulationEnabled: true,
            customCommunicationRules: []
        )
        let configurationData = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: configurationData)
        precondition(decoded == configuration, "multi-profile and paired-device configuration round trip failed")
        precondition(decoded.profiles[0].avatar == .senior, "member avatar selection must survive configuration round trip")
        precondition(decoded.isSimulationEnabled, "simulation preference must survive configuration round trip")
        precondition(decoded.languageSelection == .system, "language should follow the system by default")
        precondition(decoded.appearance == .system, "appearance should follow the system by default")
        precondition(AppConfiguration.standard.profiles.isEmpty, "a fresh install must not create a preset member")

        let storageDirectory = FileManager.default.temporaryDirectory
            .appending(path: "ScaleMe-StorageSmoke-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: storageDirectory) }
        let repository = try LocalAppRepository(directoryURL: storageDirectory)
        var persistedConfiguration = configuration
        persistedConfiguration.profiles = [
            UserProfile(name: "甲", relation: "本人", referenceWeightKG: 61.2),
            UserProfile(name: "乙", relation: "本人", referenceWeightKG: 78.6)
        ]
        persistedConfiguration.isSimulationEnabled = false
        try repository.saveConfiguration(persistedConfiguration)
        let reloadedConfiguration = try repository.loadConfiguration()
        precondition(
            reloadedConfiguration == persistedConfiguration,
            "member edits, ordering, duplicate self roles, and device settings must survive repository reload"
        )

        let manualMeasurement = BodyMeasurement(
            date: .now,
            weightKG: 63.8,
            impedanceOhm: 512,
            secondaryImpedanceOhm: 498,
            bodyFatPercent: 22.1,
            muscleMassKG: 46.4,
            waterPercent: 54.2,
            visceralFat: 7,
            basalMetabolismKCal: 1_430,
            boneMassKG: 2.6,
            source: .manual,
            isStable: true,
            profileID: persistedConfiguration.profiles[1].id
        )
        let persistedArchive = MeasurementArchive(
            updatedAt: .now,
            measurements: [manualMeasurement, retained],
            deletedMeasurementIDs: [removed.id]
        )
        try repository.saveArchive(persistedArchive)
        let storedRecordData = try Data(
            contentsOf: storageDirectory.appending(path: AppStorageLayout.dataFileName)
        )
        let storedRecordObject = try JSONSerialization.jsonObject(with: storedRecordData) as? [String: Any]
        precondition(
            storedRecordObject?["schemaVersion"] as? Int == RecordFileCodec.currentSchemaVersion,
            "local records must use the versioned JSON format"
        )
        precondition(
            storedRecordObject?["records"] is [[Any]],
            "local records must remain directly decodable after backup restoration"
        )
        let reloadedArchive = try repository.loadArchive()
        precondition(
            reloadedArchive == persistedArchive,
            "weight, body-composition, manual, device-attributed, and deleted records must survive repository reload"
        )
        print("Storage smoke tests passed")
    }
}
