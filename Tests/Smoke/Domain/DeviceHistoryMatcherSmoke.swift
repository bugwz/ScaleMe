import Foundation

@main
enum DeviceHistoryMatcherSmoke {
    static func main() {
        guard let lightID = UUID(uuidString: "10000000-0000-0000-0000-000000000001"),
              let heavyID = UUID(uuidString: "10000000-0000-0000-0000-000000000002"),
              let deviceID = UUID(uuidString: "20000000-0000-0000-0000-000000000001") else {
            preconditionFailure("固定测试 UUID 无效")
        }
        let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)
        let profiles = [
            UserProfile(id: lightID, name: "甲", referenceWeightKG: 61),
            UserProfile(id: heavyID, name: "乙", referenceWeightKG: 82)
        ]
        let existing = [
            measurement(date: referenceDate.addingTimeInterval(-86_400), weightKG: 60.8, profileID: lightID, deviceID: deviceID),
            measurement(date: referenceDate.addingTimeInterval(-86_400), weightKG: 81.7, profileID: heavyID, deviceID: deviceID)
        ]
        let history = [
            measurement(date: referenceDate.addingTimeInterval(-172_800), weightKG: 60.6, deviceID: deviceID),
            measurement(date: referenceDate.addingTimeInterval(-259_200), weightKG: 81.5, deviceID: deviceID),
            measurement(date: referenceDate.addingTimeInterval(-86_400), weightKG: 60.8, deviceID: deviceID)
        ]

        let plan = DeviceHistoryMatcher.plan(
            history: history,
            profiles: profiles,
            existingMeasurements: existing
        )
        precondition(plan.summary.importedCount == 2)
        precondition(plan.summary.duplicateCount == 1)
        precondition(plan.summary.unmatchedCount == 0)
        precondition(plan.attributedMeasurements.first(where: { $0.weightKG < 70 })?.profileID == lightID)
        precondition(plan.attributedMeasurements.first(where: { $0.weightKG > 70 })?.profileID == heavyID)

        let closeProfiles = [
            UserProfile(name: "丙", referenceWeightKG: 69.5),
            UserProfile(name: "丁", referenceWeightKG: 70.5)
        ]
        let ambiguous = DeviceHistoryMatcher.plan(
            history: [measurement(date: referenceDate, weightKG: 70, deviceID: deviceID)],
            profiles: closeProfiles,
            existingMeasurements: []
        )
        precondition(ambiguous.summary.unmatchedCount == 1, "相近候选不应被静默错配")

        let fallback = DeviceHistoryMatcher.plan(
            history: [measurement(date: referenceDate, weightKG: 82.3, deviceID: deviceID)],
            profiles: profiles,
            existingMeasurements: []
        )
        precondition(fallback.attributedMeasurements.first?.profileID == heavyID,
                     "没有历史轨迹时应使用成员参考体重")
    }

    private static func measurement(
        date: Date,
        weightKG: Double,
        profileID: UUID? = nil,
        deviceID: UUID
    ) -> BodyMeasurement {
        BodyMeasurement(
            date: date,
            weightKG: weightKG,
            impedanceOhm: nil,
            bodyFatPercent: nil,
            muscleMassKG: nil,
            waterPercent: nil,
            visceralFat: nil,
            basalMetabolismKCal: nil,
            boneMassKG: nil,
            source: .xiaomi,
            isStable: true,
            profileID: profileID,
            deviceID: deviceID
        )
    }
}
