import Foundation

@main
enum SimulationDataSmoke {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        let referenceDate = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 30, hour: 15
        )) ?? .now
        let first = SimulationDataSnapshot.make(
            language: .simplifiedChinese,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let second = SimulationDataSnapshot.make(
            language: .simplifiedChinese,
            referenceDate: referenceDate,
            calendar: calendar
        )

        precondition(first.profiles.count == MemberAvatar.allCases.count,
                     "simulation should include every available family character")
        precondition(Set(first.profiles.map(\.avatar)) == Set(MemberAvatar.allCases),
                     "every family character should appear exactly once in simulation")
        precondition(Set(first.profiles.map(\.name)).count == first.profiles.count,
                     "simulated family members should have distinct names")
        precondition(first.profiles.first?.relation == "爸爸", "爸爸必须是首位模拟成员")
        precondition(first.selectedProfileID == first.profiles.first?.id, "默认应选中爸爸")
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

        let ages = Dictionary(uniqueKeysWithValues: first.profiles.map { profile in
            let age = calendar.dateComponents([.year], from: profile.birthDate, to: referenceDate).year ?? 0
            return (profile.relation, age)
        })
        precondition(ages["爸爸"] == 45, "爸爸的模拟年龄应为 45 岁")
        precondition(ages["妈妈"] == 42, "妈妈的模拟年龄应为 42 岁")
        let oldestChildAge = max(ages["青少年儿子"] ?? 0, ages["青少年女儿"] ?? 0)
        precondition((ages["爸爸"] ?? 0) - oldestChildAge >= 18, "爸爸与最年长孩子的年龄差必须合理")
        precondition((ages["妈妈"] ?? 0) - oldestChildAge >= 18, "妈妈与最年长孩子的年龄差必须合理")
        precondition((ages["爷爷"] ?? 0) - (ages["爸爸"] ?? 0) >= 18, "爷爷与爸爸的年龄差必须合理")
        precondition((ages["奶奶"] ?? 0) - (ages["爸爸"] ?? 0) >= 18, "奶奶与爸爸的年龄差必须合理")
        precondition((ages["外公"] ?? 0) - (ages["妈妈"] ?? 0) >= 18, "外公与妈妈的年龄差必须合理")
        precondition((ages["外婆"] ?? 0) - (ages["妈妈"] ?? 0) >= 18, "外婆与妈妈的年龄差必须合理")

        let start = calendar.date(byAdding: .day, value: -365, to: referenceDate) ?? .distantPast
        precondition(first.measurements.allSatisfy { $0.date >= start && $0.date <= referenceDate },
                     "all simulated records must stay within the previous year")
        precondition(Set(first.measurements.compactMap(\.profileID)) == Set(first.profiles.map(\.id)),
                     "every simulated member should have measurements")
        precondition(Set(first.measurements.compactMap(\.deviceID)) == Set(first.pairedScales.map(\.id)),
                     "every simulated scale should appear in measurement history")

        for profile in first.profiles {
            let measurements = first.measurements.filter { $0.profileID == profile.id }
            precondition(!measurements.isEmpty, "每位模拟成员都必须有测量记录：\(profile.name)")
            for measurement in measurements {
                for metric in DashboardMetricKind.allCases {
                    precondition(
                        metric.value(in: measurement) != nil,
                        "模拟记录缺少 \(metric.title)：\(profile.name)"
                    )
                }
                precondition(measurement.impedanceOhm != nil, "模拟记录缺少生物电阻抗：\(profile.name)")
            }
        }

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

        for language in AppLanguage.allCases {
            let localized = SimulationDataSnapshot.make(
                language: language,
                referenceDate: referenceDate,
                calendar: calendar
            )
            precondition(Set(localized.profiles.map(\.name)).count == MemberAvatar.allCases.count,
                         "each language must provide distinct natural member names")
            precondition(localized.profiles.allSatisfy { $0.name.count <= 9 },
                         "simulated names must fit every single-line member presentation")
            precondition(localized.profiles.allSatisfy { !$0.name.isEmpty && !$0.relation.isEmpty },
                         "each localized member needs a name and family relation")
            precondition(localized.pairedScales.allSatisfy { !$0.name.isEmpty && !$0.compatibility.isEmpty },
                         "simulated device cards must be localized")
            precondition(localized.pairedScales.allSatisfy { $0.name.count <= 16 },
                         "simulated device names must fit device and history cards")
        }

        let japanese = SimulationDataSnapshot.make(
            language: .japanese,
            referenceDate: referenceDate,
            calendar: calendar
        )
        precondition(japanese.profiles.first?.name == "佐藤健一",
                     "Japanese data should use a natural Japanese family name")
        precondition(japanese.profiles.first?.relation == "父",
                     "Japanese family relations should be localized")
        precondition(japanese.pairedScales.first?.name == "体組成計",
                     "simulated device cards should switch language")
        precondition(japanese.measurements.allSatisfy { measurement in
            measurement.deviceName == "体組成計" || measurement.deviceName == "体重計"
        }, "measurement device names should switch with simulated device cards")

        print("Simulation data smoke tests passed (\(first.measurements.count) records)")
    }
}
