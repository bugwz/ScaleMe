import Foundation

@main
struct AppleHealthSyncSmoke {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ScaleMe-HealthSync-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try LocalAppRepository(directoryURL: directory)
        let store = MeasurementStore(repository: repository)
        let owner = UserProfile(name: "Owner", role: "本人")
        store.addProfile(owner)
        store.setDisplayAppleHealthProfileID(owner.id)
        store.setDisplayAppleHealthImportEnabled(true)
        let sample = BodyMeasurement(date: .now, weightKG: 65, source: .appleHealth, isStable: true)
        precondition(store.importAppleHealthMeasurements([sample]) == 0)
        store.setDisplayAppleHealthSyncEnabled(true)
        precondition(store.importAppleHealthMeasurements([sample]) == 1)
        store.setDisplayAppleHealthSyncEnabled(false)
        let nextSample = BodyMeasurement(date: .now, weightKG: 66, source: .appleHealth, isStable: true)
        precondition(store.importAppleHealthMeasurements([nextSample]) == 0,
                     "a query completing after sync stops must not import data")
        precondition(store.displayAppleHealthProfileID == owner.id)
        precondition(store.displayIsAppleHealthImportEnabled)
        let restored = try ConfigurationFileCodec.decode(ConfigurationFileCodec.encode(store.configuration, prettyPrinted: false))
        precondition(!restored.isAppleHealthSyncEnabled)
        precondition(restored.isAppleHealthImportEnabled && restored.appleHealthProfileID == owner.id)
        store.setDisplayAppleHealthSyncEnabled(true)
        store.setDisplayAppleHealthImportEnabled(false)
        precondition(store.importAppleHealthMeasurements([nextSample]) == 0)
        store.isSimulationEnabled = true
        precondition(!store.displayIsAppleHealthSyncEnabled)
        store.setDisplayAppleHealthSyncEnabled(true)
        store.setDisplayAppleHealthSyncEnabled(false)
        store.isSimulationEnabled = false
        precondition(store.displayIsAppleHealthSyncEnabled, "simulation must not change real sync settings")
        print("Apple Health sync smoke tests passed")
    }
}
