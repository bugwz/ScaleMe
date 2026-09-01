import Foundation

@main
struct LocalDataTransferSmoke {
    static func main() throws {
        let configuration = AppConfiguration.standard
        let cipher = MeasurementFileCipher(keyData: Data(repeating: 0x4A, count: 32))
        let service = LocalDataTransferService(measurementCipher: cipher)

        let configurationData = try service.exportConfiguration(configuration)
        let importedConfiguration = try service.importConfiguration(from: configurationData)
        precondition(importedConfiguration == configuration)

        let measurement = BodyMeasurement(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            weightKG: 62.4,
            impedanceOhm: 510,
            bodyFatPercent: 21.3,
            source: .bluetoothSIG,
            isStable: true,
            profileID: configuration.selectedProfileID,
            deviceID: UUID(uuidString: "ABBA7280-8FDE-4A55-8D87-FA9BFE003F67")
        )
        let archive = MeasurementArchive(
            updatedAt: measurement.date,
            measurements: [measurement],
            deletedMeasurementIDs: []
        )
        let encryptedArchive = try service.exportMeasurements(archive)
        let plaintextArchive = try JSONEncoder().encode(archive)
        let importedArchive = try service.importMeasurements(from: encryptedArchive)
        precondition(encryptedArchive != plaintextArchive)
        precondition(importedArchive == archive)

        do {
            _ = try service.importConfiguration(from: Data("{}".utf8))
            preconditionFailure("invalid configuration must be rejected")
        } catch LocalDataTransferError.invalidConfiguration {
        }

        do {
            _ = try service.importMeasurements(from: Data("invalid".utf8))
            preconditionFailure("invalid measurement archive must be rejected")
        } catch LocalDataTransferError.invalidMeasurementArchive {
        }

        print("Local data transfer smoke tests passed")
    }
}
