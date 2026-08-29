import Foundation

@main
enum StorageSmoke {
    static func main() throws {
        let cipher = MeasurementFileCipher(keyData: Data(repeating: 0x5A, count: 32))
        let plaintext = Data("private measurement payload".utf8)
        let encrypted = try cipher.encrypt(plaintext)
        let decrypted = try cipher.decrypt(encrypted)

        precondition(encrypted != plaintext, "encrypted data must not expose plaintext")
        precondition(decrypted == plaintext, "AES-GCM round trip failed")

        let retained = BodyMeasurement(
            id: UUID(),
            date: .now,
            weightKG: 58,
            source: .manual,
            isStable: true
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
        let cloud = MeasurementArchive(
            updatedAt: .now.addingTimeInterval(-30),
            measurements: [removed],
            deletedMeasurementIDs: []
        )
        let merged = local.merging(cloud)

        precondition(merged.measurements == [retained], "deleted records must not be resurrected")
        print("Storage smoke tests passed")
    }
}
