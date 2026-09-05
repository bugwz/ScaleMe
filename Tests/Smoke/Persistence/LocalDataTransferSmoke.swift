import Foundation

@main
struct LocalDataTransferSmoke {
    static func main() throws {
        var configuration = AppConfiguration.standard
        configuration.profiles = [UserProfile(name: "测试成员", relation: "本人")]
        guard let deviceID = UUID(uuidString: "ABBA7280-8FDE-4A55-8D87-FA9BFE003F67") else {
            preconditionFailure("invalid fixture UUID")
        }
        guard let manualRecordID = UUID(uuidString: "10000000-0000-4000-8000-000000000002") else {
            preconditionFailure("invalid manual record fixture UUID")
        }
        configuration.pairedScales = [PairedScale(
            id: deviceID,
            name: "浴室秤",
            modelName: "Fixture",
            compatibility: "fixture validated",
            communicationRuleID: "protocol.builtin.sig-weight"
        )]
        configuration.unit = .jin
        configuration.languageSelection = .english
        configuration.appearance = .dark
        configuration.mergeFrequentMeasurements = true
        configuration.isSimulationEnabled = true
        configuration.appleHealthProfileID = configuration.profiles[0].id
        configuration.appleHealthDeviceIDs = [deviceID]
        guard let communicationRule = CommunicationRuleCatalog.builtIn.first else {
            preconditionFailure("missing communication rule fixture")
        }
        configuration.customCommunicationRules = [communicationRule]
        configuration.dashboardVisibleMetrics = [.bodyFatPercent, .waterPercent]
        configuration.widgetProfileID = configuration.profiles[0].id
        configuration.widgetTimeRange = .quarter
        configuration.widgetDisplayStyle = .actualFullRange
        configuration.profiles[0].referenceWeightKG = 63.4
        let service = LocalDataTransferService()

        let emptyConfigurationData = try service.exportConfiguration(.standard)
        let importedEmptyConfiguration = try service.importConfiguration(from: emptyConfigurationData)
        precondition(importedEmptyConfiguration.profiles.isEmpty, "an empty member list must remain valid configuration")

        let configurationData = try service.exportConfiguration(configuration)
        let configurationJSON = String(decoding: configurationData, as: UTF8.self)
        assertOrderedKeys(
            in: configurationJSON,
            keys: ["schemaVersion", "members", "devices", "communication", "general", "measurement", "appleHealth", "dashboard", "widget"]
        )
        assertOrderedKeys(in: configurationJSON, after: "\"members\"", keys: ["profiles"])
        assertOrderedKeys(
            in: configurationJSON,
            after: "\"profiles\"",
            keys: ["id", "name", "relation", "heightCM", "referenceWeightKG", "birthDate", "biologicalSex", "avatar"]
        )
        assertOrderedKeys(
            in: configurationJSON,
            after: "\"pairedScales\"",
            keys: ["id", "name", "modelName", "compatibility", "communicationRuleID", "addedAt"]
        )
        let storedConfigurationJSON = String(
            decoding: try ConfigurationFileCodec.encode(configuration, prettyPrinted: false),
            as: UTF8.self
        )
        assertOrderedKeys(
            in: storedConfigurationJSON,
            keys: ["schemaVersion", "members", "devices", "communication", "general", "measurement", "appleHealth", "dashboard", "widget"]
        )
        let configurationObject = try JSONSerialization.jsonObject(with: configurationData) as? [String: Any]
        precondition(configurationObject?["schemaVersion"] as? Int == 1)
        precondition(configurationObject?["members"] is [String: Any])
        precondition(configurationObject?["devices"] is [String: Any])
        precondition(configurationObject?["communication"] is [String: Any])
        precondition(configurationObject?["general"] is [String: Any])
        precondition(configurationObject?["measurement"] is [String: Any])
        precondition(configurationObject?["appleHealth"] is [String: Any])
        precondition(configurationObject?["dashboard"] is [String: Any])
        precondition(configurationObject?["widget"] is [String: Any])
        precondition(configurationObject?["profiles"] == nil, "configuration fields must not remain flat")
        let members = configurationObject?["members"] as? [String: Any]
        let profiles = members?["profiles"] as? [[String: Any]]
        precondition(members?["selectedProfileID"] == nil)
        precondition(isHyphenatedUUID(profiles?.first?["id"] as? String))
        precondition(profiles?.first?["biologicalSex"] as? String == "female")
        precondition(profiles?.first?["referenceWeightKG"] as? Double == 63.4)
        let devices = configurationObject?["devices"] as? [String: Any]
        let pairedScales = devices?["pairedScales"] as? [[String: Any]]
        precondition(isHyphenatedUUID(pairedScales?.first?["id"] as? String))
        let measurementSettings = configurationObject?["measurement"] as? [String: Any]
        precondition(measurementSettings?["unit"] as? String == "jin")
        let importedConfiguration = try service.importConfiguration(from: configurationData)
        precondition(importedConfiguration == configuration)

        let measurement = BodyMeasurement(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            weightKG: 62.4,
            impedanceOhm: 510,
            secondaryImpedanceOhm: 498,
            bodyFatPercent: 21.3,
            muscleMassKG: 45.2,
            waterPercent: 54.6,
            visceralFat: 7,
            basalMetabolismKCal: 1_420,
            boneMassKG: 2.5,
            source: .bluetoothSIG,
            isStable: true,
            profileID: configuration.profiles[0].id,
            deviceID: deviceID,
            deviceName: "浴室秤"
        )
        let manualRecord = BodyMeasurement(
            id: manualRecordID,
            date: measurement.date.addingTimeInterval(86_400),
            weightKG: 62.1,
            source: .manual,
            isStable: true,
            profileID: configuration.profiles[0].id
        )
        let archive = MeasurementArchive(
            updatedAt: manualRecord.date,
            measurements: [measurement, manualRecord],
            deletedMeasurementIDs: []
        )
        let recordFile = try service.exportRecords(archive)
        let recordJSON = String(decoding: recordFile, as: UTF8.self)
        assertOrderedKeys(
            in: recordJSON,
            keys: ["schemaVersion", "updatedAt", "references", "columns", "records", "deletedRecordIDs"]
        )
        let exportedObject = try JSONSerialization.jsonObject(with: recordFile) as? [String: Any]
        precondition(exportedObject?["schemaVersion"] as? Int == 1)
        let references = exportedObject?["references"] as? [String: Any]
        let recordProfiles = references?["profiles"] as? [String]
        let recordDevices = references?["devices"] as? [[String: Any]]
        let recordSources = references?["sources"] as? [String]
        precondition(recordProfiles == [configuration.profiles[0].id.uuidString])
        precondition(recordDevices?.first?["id"] as? String == deviceID.uuidString)
        precondition(recordDevices?.first?["name"] as? String == "浴室秤")
        precondition(recordSources == ["bluetoothSIG", "manual"])
        let columns = exportedObject?["columns"] as? [String]
        precondition(columns?.first == "id")
        precondition(columns?.last == "boneMassKG")
        let exportedRecords = exportedObject?["records"] as? [[Any]]
        precondition(isHyphenatedUUID(exportedRecords?.first?[0] as? String))
        precondition(exportedRecords?.first?[3] as? Int == 0)
        precondition(exportedRecords?.first?[4] as? Int == 0)
        precondition(exportedRecords?.first?[5] as? Int == 0)
        let recordLines = recordJSON.split(separator: "\n").filter {
            $0.contains(measurement.id.uuidString) || $0.contains(manualRecord.id.uuidString)
        }
        precondition(recordLines.count == 2)
        precondition(recordLines.allSatisfy { $0.contains("[") && $0.contains("]") })
        precondition(exportedObject?["measurements"] == nil)
        let importedArchive = try service.importRecords(from: recordFile)
        precondition(importedArchive == archive)

        let combinedFile = try service.exportCombined(configuration: configuration, archive: archive)
        let combinedJSON = String(decoding: combinedFile, as: UTF8.self)
        assertOrderedKeys(in: combinedJSON, keys: ["config", "data"])
        let combinedObject = try JSONSerialization.jsonObject(with: combinedFile) as? [String: Any]
        precondition(combinedObject.map { Set($0.keys) } == ["config", "data"])
        precondition(combinedObject?["config"] is [String: Any])
        precondition(combinedObject?["data"] is [String: Any])
        let importedBundle = try service.importCombined(from: combinedFile)
        precondition(importedBundle.configuration == configuration)
        precondition(importedBundle.archive == archive)

        do {
            _ = try service.importConfiguration(from: Data("{}".utf8))
            preconditionFailure("invalid configuration must be rejected")
        } catch LocalDataTransferError.invalidConfiguration {
        }

        do {
            _ = try service.importConfiguration(from: JSONEncoder().encode(configuration))
            preconditionFailure("flat configuration format must be rejected")
        } catch LocalDataTransferError.invalidConfiguration {
        }

        do {
            _ = try service.importRecords(from: Data("invalid".utf8))
            preconditionFailure("invalid data file must be rejected")
        } catch LocalDataTransferError.invalidRecordFile {
        }

        do {
            _ = try service.importRecords(from: JSONEncoder().encode(archive))
            preconditionFailure("unversioned data files must be rejected")
        } catch LocalDataTransferError.invalidRecordFile {
        }

        do {
            _ = try service.importCombined(from: Data("{}".utf8))
            preconditionFailure("combined file without config and data must be rejected")
        } catch LocalDataTransferError.invalidCombinedFile {
        }

        do {
            let invalidCombined = Data("{\"config\":{},\"data\":{}}".utf8)
            _ = try service.importCombined(from: invalidCombined)
            preconditionFailure("combined file with invalid nested documents must be rejected")
        } catch LocalDataTransferError.invalidCombinedFile {
        }

        print("Local data transfer smoke tests passed")
    }

    private static func isHyphenatedUUID(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.count == 36
            && value.filter { $0 == "-" }.count == 4
            && UUID(uuidString: value) != nil
    }

    private static func assertOrderedKeys(
        in json: String,
        after marker: String? = nil,
        keys: [String]
    ) {
        var searchStart = marker.flatMap { json.range(of: $0)?.upperBound } ?? json.startIndex
        for key in keys {
            guard let range = json.range(of: "\"\(key)\"", range: searchStart..<json.endIndex) else {
                preconditionFailure("missing or out-of-order configuration key: \(key)")
            }
            searchStart = range.upperBound
        }
    }
}
