import Foundation

@main
enum SimulationDataSmoke {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        let referenceDate = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 30, hour: 15
        )) ?? .now
        let first = SimulationDataSnapshot.make(referenceDate: referenceDate, calendar: calendar)
        let second = SimulationDataSnapshot.make(referenceDate: referenceDate, calendar: calendar)

        precondition(first.profiles.count == MemberAvatar.allCases.count,
                     "simulation should include every available family character")
        precondition(Set(first.profiles.map(\.avatar)) == Set(MemberAvatar.allCases),
                     "every family character should appear exactly once in simulation")
        precondition(Set(first.profiles.map(\.name)).count == first.profiles.count,
                     "simulated family members should have distinct names")
        precondition(first.pairedScales.count == 2, "simulation should include multiple scales")
        precondition(first.measurements == second.measurements, "simulation must be deterministic for a reference date")
        precondition(first.measurements.count > 1_300, "simulation should provide dense year-long history")

        let father = first.profiles.first(where: { $0.avatar == .father })
        let children = first.profiles.filter {
            [.child, .childDaughter, .youth, .teenDaughter].contains($0.avatar)
        }
        precondition(father?.name.hasPrefix("林") == true,
                     "the simulated father should use the Lin family name")
        precondition(children.count == 4 && children.allSatisfy { $0.name.hasPrefix("林") },
                     "all simulated children should share their father's family name")

        let expectedRelations: [MemberAvatar: String] = [
            .adult: "妈妈", .father: "爸爸",
            .child: "儿童儿子", .childDaughter: "儿童女儿",
            .youth: "青少年儿子", .teenDaughter: "青少年女儿",
            .senior: "奶奶", .paternalGrandfather: "爷爷",
            .maternalGrandfather: "外公", .maternalGrandmother: "外婆"
        ]
        precondition(first.profiles.allSatisfy { expectedRelations[$0.avatar] == $0.relation },
                     "simulated names, relations, and character roles should agree")

        let start = calendar.date(byAdding: .day, value: -365, to: referenceDate) ?? .distantPast
        precondition(first.measurements.allSatisfy { $0.date >= start && $0.date <= referenceDate },
                     "all simulated records must stay within the previous year")
        precondition(Set(first.measurements.compactMap(\.profileID)) == Set(first.profiles.map(\.id)),
                     "every simulated member should have measurements")
        precondition(Set(first.measurements.compactMap(\.deviceID)) == Set(first.pairedScales.map(\.id)),
                     "every simulated scale should appear in measurement history")

        let minutes = Set(first.measurements.map {
            let components = calendar.dateComponents([.hour, .minute], from: $0.date)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        })
        precondition(minutes.count > 80, "measurement times should not repeat a fixed schedule")
        precondition(minutes.allSatisfy {
            ((6 * 60 + 18)...(8 * 60 + 30)).contains($0)
                || ((19 * 60 + 5)...(22 * 60 + 20)).contains($0)
        },
                     "measurements should cluster in realistic morning and evening windows")

        let intervals = zip(first.measurements, first.measurements.dropFirst()).map {
            Int(abs($0.date.timeIntervalSince($1.date)))
        }
        precondition(Set(intervals).count > 50, "measurement intervals should vary")

        let realProfile = UserProfile(
            name: "真实姓名", relation: "本人", heightCM: 181,
            biologicalSex: .male
        )
        let realMeasurement = BodyMeasurement(
            date: referenceDate.addingTimeInterval(-3_600),
            weightKG: 82.4,
            bodyFatPercent: 21.3,
            source: .manual,
            isStable: true,
            profileID: realProfile.id
        )
        let calibrated = SimulationDataSnapshot.make(
            referenceDate: referenceDate,
            calendar: calendar,
            calibrationProfile: realProfile,
            calibrationMeasurement: realMeasurement
        )
        let simulatedProfile = calibrated.profiles[0]
        let latestSimulatedWeight = calibrated.measurements
            .first(where: { $0.profileID == simulatedProfile.id })?.weightKG ?? 0
        precondition(simulatedProfile.name != realProfile.name && simulatedProfile.id != realProfile.id,
                     "calibration must not copy real identity")
        precondition(simulatedProfile.heightCM == realProfile.heightCM,
                     "primary simulated member should use the real profile's body baseline")
        precondition(abs(latestSimulatedWeight - realMeasurement.weightKG) < 1.5,
                     "simulated recent weight should stay close to the user's real baseline")
        print("Simulation data smoke tests passed (\(first.measurements.count) records)")
    }
}
