import Foundation

@main
struct AFUMeasurementSaveSmoke {
    @MainActor
    static func main() throws {
        // Synthetic protocol frames, dates, and profile; no personal capture data.
        let directory = FileManager.default.temporaryDirectory.appending(path: "ScaleMe-AFU-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try LocalAppRepository(directoryURL: directory)
        let store = MeasurementStore(repository: repository)
        store.addProfile(UserProfile(heightCM: 170,
            birthDate: Date(timeIntervalSince1970: 631152000), biologicalSex: .male))
        store.mergeFrequentMeasurements = false
        let session = WolaiAFUProtocolSession()
        let date = Date(timeIntervalSince1970: 1700000000)
        let completeBytes = bytes("AC29020001F40258018068EA600000000029D603")
        var incompleteBytes = completeBytes
        for index in 4...7 { incompleteBytes[index] = 0 }
        incompleteBytes[19] = UInt8(incompleteBytes[2...18].reduce(0) { $0 + UInt32($1) } & 0x1F)
        let incomplete = try result(session, bytes: incompleteBytes, date: date)
        precondition(store.add(incomplete))
        precondition(store.latest?.displayedBodyFatPercent == nil)
        // The same final result can supply previously missing impedance channels.
        let complete = try result(session, bytes: completeBytes, date: date.addingTimeInterval(1))
        precondition(complete.id == incomplete.id && complete.date == incomplete.date,
                     "enrichment must update the same measurement even when merging is disabled")
        precondition(store.add(complete))
        precondition(store.measurements.count == 1)
        let displayed = store.displayMeasurement(id: incomplete.id)!
        precondition(displayed.impedanceOhm == 500 && displayed.secondaryImpedanceOhm == 600)
        precondition(displayed.displayedBodyFatPercent != nil)
        precondition(displayed.displayedWaterPercent != nil && displayed.displayedBasalMetabolismKCal != nil)
        precondition(displayed.calculatedMetrics?.values["bodyFatPercent"] == displayed.displayedBodyFatPercent)
        precondition(displayed.bodyFatPercent == nil, "keep estimates separate from device fields")
        let duplicate = try session.handle(event(bytes: completeBytes, date: date.addingTimeInterval(2)))
        precondition(duplicate.isEmpty)
        let degraded = try session.handle(event(bytes: incompleteBytes, date: date.addingTimeInterval(3)))
        precondition(degraded.isEmpty, "incomplete repeats must not erase received impedance")
        let reopened = MeasurementStore(repository: repository)
        precondition(reopened.latest == displayed)
        let service = LocalDataTransferService()
        let exported = try service.exportRecords(store.archive)
        let imported = try service.importRecords(from: exported)
        precondition(imported.measurements == [displayed])
        // Do not attach a delayed result or a different weight to the finished record.
        let lateSession = WolaiAFUProtocolSession()
        _ = try result(lateSession, bytes: incompleteBytes, date: date)
        let late = try lateSession.handle(event(bytes: completeBytes, date: date.addingTimeInterval(21)))
        precondition(late.isEmpty)
        let differentWeight = try lateSession.handle(event(
            bytes: bytes("AC2902000226028A018068FDE80000000029D603"), date: date.addingTimeInterval(1)))
        precondition(differentWeight.isEmpty)
        let newCycle = try session.handle(event(bytes: bytes("AC2900684E20020005400064000000000029D51F"),
                                                date: date.addingTimeInterval(4)))
        precondition(!newCycle.isEmpty)
        let next = try result(session, bytes: incompleteBytes, date: date.addingTimeInterval(5))
        precondition(next.id != incomplete.id && next.impedanceOhm == nil && next.secondaryImpedanceOhm == nil,
                     "a new load must never inherit the previous load's impedance")
        // Existing raw-only records must gain durable results when reopened/imported.
        let historicalDirectory = directory.appending(path: "historical")
        let historicalRepository = try LocalAppRepository(directoryURL: historicalDirectory)
        var historical = complete
        historical.id = UUID()
        historical.profileID = store.selectedProfileID
        try historicalRepository.saveConfiguration(store.configuration)
        let rawArchive = MeasurementArchive(updatedAt: date, measurements: [historical], deletedMeasurements: [])
        try historicalRepository.saveArchive(rawArchive)
        let recovered = MeasurementStore(repository: historicalRepository)
        precondition(recovered.latest?.displayedBodyFatPercent != nil)
        precondition(recovered.latest?.impedanceOhm == historical.impedanceOhm)
        let durable = try historicalRepository.loadArchive()!
        precondition(durable.measurements == recovered.measurements)
        let stableResults = recovered.latest!.calculatedMetrics
        var editedProfile = recovered.selectedProfile
        editedProfile.heightCM += 10
        recovered.updateProfile(editedProfile)
        let reopenedHistorical = MeasurementStore(repository: historicalRepository)
        precondition(reopenedHistorical.latest?.calculatedMetrics == stableResults,
                     "existing snapshots must not change when profiles change")
        recovered.apply(archive: rawArchive)
        precondition(recovered.latest?.displayedBodyFatPercent != nil)
        precondition(recovered.latest?.calculatedMetrics != nil)
        print("AFU measurement save smoke checks passed")
    }

    private static func event(bytes: [UInt8], date: Date) -> ScaleProtocolEvent {
        .notification(serviceUUID: WolaiAFUScaleAdapter.serviceUUID,
                      characteristicUUID: WolaiAFUScaleAdapter.measurementCharacteristicUUID,
                      payload: Data(bytes), receivedAt: date)
    }

    private static func result(_ session: WolaiAFUProtocolSession, bytes: [UInt8], date: Date) throws -> BodyMeasurement {
        for action in try session.handle(event(bytes: bytes, date: date)) {
            if case .emit(.measurement(let measurement), .protocolFinal) = action { return measurement }
        }
        preconditionFailure("AFU dropped the completed result with newly available impedance")
    }

    private static func bytes(_ hex: String) -> [UInt8] {
        stride(from: 0, to: hex.count, by: 2).map { index in
            let start = hex.index(hex.startIndex, offsetBy: index)
            return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
        }
    }
}
