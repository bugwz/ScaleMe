import Foundation

@main
struct AdditionalCompositionSmoke {
    static func main() throws {
        // Synthetic profile and payload; never copied from a user's capture.
        let fields = ["subcutaneousFatPercent", "subcutaneousFatMassKG", "proteinPercent", "proteinMassKG", "skeletalMusclePercent", "skeletalMuscleMassKG"]
        var decoder: [String: Any] = ["weight": ["offset": 0, "length": 2, "scale": 0.01, "byteOrder": "littleEndian", "add": 0]]
        decoder["weightUnit"] = "kilograms"
        for (index, name) in fields.enumerated() {
            decoder[name] = ["offset": (index + 1) * 2, "length": 2, "scale": 0.01, "byteOrder": "littleEndian", "add": 0]
        }
        let document: [String: Any] = ["schemaVersion": 3, "rules": [[
            "id": "protocol.custom.composition-fixture", "name": "Synthetic Composition", "version": 1,
            "summary": "Synthetic extended fields", "match": ["transport": "characteristicNotification", "serviceUUID": "FFF0", "characteristicUUID": "FFF1", "minimumLength": 14, "maximumLength": 14], "decoder": decoder
        ]]]
        let rule = try CommunicationRuleCodec.decode(JSONSerialization.data(withJSONObject: document))[0]
        let payload = Data([8000, 1500, 1200, 1600, 1280, 3500, 2800].flatMap { value in
            [UInt8(value & 255), UInt8(value >> 8)]
        })
        guard case .measurement(var record) = try DeclarativeCommunicationRuleParser.parse(payload, rule: rule) else {
            preconditionFailure("Expected composition record")
        }
        precondition(record.displayedSubcutaneousFatPercent == 15 && record.displayedSubcutaneousFatMassKG == 12)
        precondition(record.displayedProteinPercent == 16 && record.displayedProteinMassKG == 12.8)
        precondition(record.displayedSkeletalMusclePercent == 35 && record.displayedSkeletalMuscleMassKG == 28)
        let archive = MeasurementArchive(updatedAt: record.date, measurements: [record], deletedMeasurements: [])
        let encoded = try RecordFileCodec.encode(archive, prettyPrinted: false)
        let restored = try RecordFileCodec.decode(encoded)
        precondition(restored.measurements == [record])
        // Released records had exactly 15 columns. Keep them readable without resetting data.
        var old = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        old["columns"] = Array((old["columns"] as! [String]).prefix(15))
        old["records"] = (old["records"] as! [[Any]]).map { Array($0.prefix(15)) }
        let oldRecord = try RecordFileCodec.decode(JSONSerialization.data(withJSONObject: old)).measurements[0]
        precondition(oldRecord.weightKG == 80 && oldRecord.proteinPercent == nil)
        record.subcutaneousFatMassKG = nil; record.proteinMassKG = nil; record.skeletalMusclePercent = nil
        precondition(record.displayedSubcutaneousFatMassKG == 12)
        precondition(record.displayedProteinMassKG == 12.8)
        precondition(record.displayedSkeletalMusclePercent == 35)
        for offset in [2, 4, 6, 8, 10, 12] {
            var invalid = payload
            let value = offset == 2 || offset == 6 || offset == 10 ? 10001 : 8001
            invalid[offset] = UInt8(value & 255); invalid[offset + 1] = UInt8(value >> 8)
            do {
                _ = try DeclarativeCommunicationRuleParser.parse(invalid, rule: rule)
                preconditionFailure("Invalid new field accepted")
            } catch ScalePayloadError.unsupported { }
        }
        print("Additional composition smoke checks passed")
    }
}
