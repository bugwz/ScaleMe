import Foundation

@main
enum SimulationDataSmoke {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current
        let referenceDate = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 30, hour: 15
        )) ?? .now
        let first = progressiveSnapshot(
            language: .simplifiedChinese,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let second = progressiveSnapshot(
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
        precondition(first.profiles.first?.avatar == .father, "爸爸必须是首位模拟成员")
        precondition(first.profiles.first?.relation == "本人", "默认中年男性必须使用本人关系选项")
        precondition(first.selectedProfileID == first.profiles.first?.id, "默认应选中中年男性本人")
        precondition(first.pairedScales.count == 2, "simulation should include multiple scales")
        precondition(first.measurements == second.measurements, "simulation must be deterministic for a reference date")
        precondition(first.measurements.count == 4_096,
                     "simulation should provide exactly 4,096 records")
        let generated = SimulationDataSnapshot.make(
            language: .simplifiedChinese,
            referenceDate: referenceDate,
            calendar: calendar
        )
        precondition(first.measurements == generated.measurements,
                     "progressive simulation generation must match a complete generation")

        let launchDay = calendar.startOfDay(for: referenceDate)
        let metadata = SimulationDataSnapshot.makeMetadata(
            language: .simplifiedChinese,
            launchDay: launchDay,
            calendar: calendar
        )
        let recentMeasurements = metadata.generatedMeasurements(
            dayOffsets: 0...6,
            launchDay: launchDay,
            calendar: calendar
        )
        let historicalMeasurements = metadata.generatedMeasurements(
            dayOffsets: 7...364,
            launchDay: launchDay,
            calendar: calendar
        )
        precondition(Set(recentMeasurements.map(\.id)).isDisjoint(with: historicalMeasurements.map(\.id)),
                     "recent and historical simulation chunks must not overlap")
        precondition(Set(recentMeasurements.compactMap(\.profileID)) == Set(metadata.profiles.map(\.id)),
                     "the fast recent chunk must include every simulated member")

        for profile in metadata.profiles {
            let profileRecent = recentMeasurements
                .filter { $0.profileID == profile.id }
                .max { $0.date < $1.date }
            let profileBodyCompositionRecent = recentMeasurements
                .filter { $0.profileID == profile.id && $0.hasBodyComposition }
                .max { $0.date < $1.date }
            let interactive = SimulationMeasurementGenerator.make(
                profile: profile,
                recentMeasurement: profileBodyCompositionRecent,
                device: metadata.pairedScales.first,
                date: referenceDate,
                calendar: calendar
            )
            precondition(interactive.profileID == profile.id,
                         "interactive simulation must remain attributed to its selected member")
            precondition(interactive.deviceID == metadata.pairedScales.first?.id,
                         "interactive simulation must remain attributed to its selected scale")
            precondition(interactive.date == referenceDate && interactive.source == .demo && interactive.isStable,
                         "interactive simulation must create a new completed demo measurement")
            if let profileBodyCompositionRecent {
                precondition(abs(interactive.weightKG - profileBodyCompositionRecent.weightKG) <= 0.19,
                             "interactive simulation must follow the selected member's recent weight trend")
                precondition(abs((interactive.bodyFatPercent ?? 0) - (profileBodyCompositionRecent.bodyFatPercent ?? 0)) <= 0.1,
                             "interactive simulation must follow the selected member's recent body-fat trend")
            }
            precondition(DashboardMetricKind.allCases.allSatisfy { $0.value(in: interactive) != nil },
                         "interactive simulation must produce a complete, internally consistent result")

            let weightOnlyInteractive = SimulationMeasurementGenerator.make(
                profile: profile,
                recentMeasurement: profileRecent,
                device: metadata.pairedScales.last,
                date: referenceDate,
                calendar: calendar
            )
            precondition(!weightOnlyInteractive.hasBodyComposition,
                         "interactive weight-only scale measurements must not contain body composition")
            precondition(weightOnlyInteractive.impedanceOhm == nil
                            && DashboardMetricKind.allCases.allSatisfy { $0.value(in: weightOnlyInteractive) == nil },
                         "interactive weight-only scale measurements must contain weight only")
        }

        let sameDayMorning = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 30, hour: 1
        )) ?? .now
        let sameDayEvening = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 30, hour: 23
        )) ?? .now
        let morningSnapshot = progressiveSnapshot(
            language: .simplifiedChinese,
            referenceDate: sameDayMorning,
            calendar: calendar
        )
        let eveningSnapshot = progressiveSnapshot(
            language: .simplifiedChinese,
            referenceDate: sameDayEvening,
            calendar: calendar
        )
        precondition(
            morningSnapshot.measurements == eveningSnapshot.measurements,
            "simulation timestamps must remain stable throughout the same calendar day"
        )

        let nextReferenceDate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        let nextDaySnapshot = progressiveSnapshot(
            language: .simplifiedChinese,
            referenceDate: nextReferenceDate,
            calendar: calendar
        )
        precondition(first.measurements.count == nextDaySnapshot.measurements.count,
                     "daily rolling must preserve the simulated data shape")
        precondition(zip(first.measurements, nextDaySnapshot.measurements).allSatisfy { current, next in
            current.id == next.id
                && current.weightKG == next.weightKG
                && next.date.timeIntervalSince(current.date) == 86_400
        }, "the same simulated values should roll forward exactly one day")

        let father = first.profiles.first(where: { $0.avatar == .father })
        let children = first.profiles.filter {
            [.child, .childDaughter, .youth, .teenDaughter].contains($0.avatar)
        }
        precondition(father?.name.hasPrefix("林") == true,
                     "the simulated father should use the Lin family name")
        precondition(children.count == 4 && children.allSatisfy { $0.name.hasPrefix("林") },
                     "all simulated children should share their father's family name")

        let expectedRelations: [MemberAvatar: String] = [
            .adult: "伴侣", .father: "本人",
            .child: "子女", .childDaughter: "子女",
            .youth: "子女", .teenDaughter: "子女",
            .senior: "父母", .paternalGrandfather: "父母",
            .maternalGrandfather: "父母", .maternalGrandmother: "父母"
        ]
        precondition(first.profiles.allSatisfy { expectedRelations[$0.avatar] == $0.relation },
                     "simulated names, relations, and character roles should agree")

        let ages = Dictionary(uniqueKeysWithValues: first.profiles.map { profile in
            let age = calendar.dateComponents([.year], from: profile.birthDate, to: referenceDate).year ?? 0
            return (profile.avatar, age)
        })
        precondition(ages[.father] == 45, "爸爸的模拟年龄应为 45 岁")
        precondition(ages[.adult] == 42, "妈妈的模拟年龄应为 42 岁")
        let oldestChildAge = max(ages[.youth] ?? 0, ages[.teenDaughter] ?? 0)
        precondition((ages[.father] ?? 0) - oldestChildAge >= 18, "爸爸与最年长孩子的年龄差必须合理")
        precondition((ages[.adult] ?? 0) - oldestChildAge >= 18, "妈妈与最年长孩子的年龄差必须合理")
        precondition((ages[.paternalGrandfather] ?? 0) - (ages[.father] ?? 0) >= 18, "爷爷与爸爸的年龄差必须合理")
        precondition((ages[.senior] ?? 0) - (ages[.father] ?? 0) >= 18, "奶奶与爸爸的年龄差必须合理")
        precondition((ages[.maternalGrandfather] ?? 0) - (ages[.adult] ?? 0) >= 18, "外公与妈妈的年龄差必须合理")
        precondition((ages[.maternalGrandmother] ?? 0) - (ages[.adult] ?? 0) >= 18, "外婆与妈妈的年龄差必须合理")

        let youngAvatars: Set<MemberAvatar> = [.child, .childDaughter, .youth, .teenDaughter]
        for profile in first.profiles {
            let weights = first.measurements
                .filter { $0.profileID == profile.id }
                .map(\.weightKG)
            let bmiValues = weights.map { weightKG in
                weightKG / pow(profile.heightCM / 100, 2)
            }
            let expectedRange = youngAvatars.contains(profile.avatar) ? 14.0...23.0 : 18.5...28.0
            precondition(
                bmiValues.allSatisfy(expectedRange.contains),
                "模拟成员的身高和体重组合必须合理：\(profile.name)"
            )
        }

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
            let measuredDays = Set(measurements.map { calendar.startOfDay(for: $0.date) })
            precondition(measuredDays.count == 365, "每位模拟成员过去 365 天必须每天都有记录：\(profile.name)")
            for dayOffset in 0...6 {
                let expectedDay = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: referenceDate))
                precondition(
                    expectedDay.map(measuredDays.contains) == true,
                    "每位模拟成员最近七天必须每天都有记录：\(profile.name)"
                )
            }
            for measurement in measurements {
                if measurement.deviceID == first.pairedScales.first?.id {
                    for metric in DashboardMetricKind.allCases {
                        precondition(
                            metric.value(in: measurement) != nil,
                            "模拟体脂秤记录缺少 \(metric.title)：\(profile.name)"
                        )
                    }
                    precondition(measurement.impedanceOhm != nil,
                                 "模拟体脂秤记录缺少生物电阻抗：\(profile.name)")
                } else {
                    precondition(!measurement.hasBodyComposition && measurement.impedanceOhm == nil,
                                 "模拟体重秤记录只能包含体重：\(profile.name)")
                    precondition(DashboardMetricKind.allCases.allSatisfy { $0.value(in: measurement) == nil },
                                 "模拟体重秤记录不能包含衍生身体成分：\(profile.name)")
                }
            }
        }

        let minutes = Set(first.measurements.map {
            let components = calendar.dateComponents([.hour, .minute], from: $0.date)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        })
        precondition(minutes.count > 80, "measurement times should not repeat a fixed schedule")
        precondition(minutes.allSatisfy {
            $0 == 0
                || ((6 * 60 + 18)...(8 * 60 + 30)).contains($0)
                || ((19 * 60 + 5)...(22 * 60 + 20)).contains($0)
        },
                     "measurements should cluster in realistic morning and evening windows")

        let intervals = zip(first.measurements, first.measurements.dropFirst()).map {
            Int(abs($0.date.timeIntervalSince($1.date)))
        }
        precondition(Set(intervals).count > 50, "measurement intervals should vary")

        for language in AppLanguage.allCases {
            let localized = progressiveSnapshot(
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

        let japanese = progressiveSnapshot(
            language: .japanese,
            referenceDate: referenceDate,
            calendar: calendar
        )
        precondition(japanese.profiles.first?.name == "佐藤健一",
                     "Japanese data should use a natural Japanese family name")
        precondition(japanese.profiles.first?.relation == "本人",
                     "simulation relationships must use an available relationship option")
        precondition(japanese.pairedScales.first?.name == "体組成計",
                     "simulated device cards should switch language")
        precondition(japanese.measurements.allSatisfy { measurement in
            measurement.deviceName == "体組成計" || measurement.deviceName == "体重計"
        }, "measurement device names should switch with simulated device cards")

        print("Simulation data smoke tests passed (\(first.measurements.count) records)")
    }

    private static func progressiveSnapshot(
        language: AppLanguage,
        referenceDate: Date,
        calendar: Calendar
    ) -> SimulationDataSnapshot {
        let launchDay = calendar.startOfDay(for: referenceDate)
        var snapshot = SimulationDataSnapshot.makeMetadata(
            language: language,
            launchDay: launchDay,
            calendar: calendar
        )
        let recentMeasurements = snapshot.generatedMeasurements(
            dayOffsets: 0...6,
            launchDay: launchDay,
            calendar: calendar
        )
        let historicalMeasurements = snapshot.generatedMeasurements(
            dayOffsets: 7...364,
            launchDay: launchDay,
            calendar: calendar
        )
        snapshot.measurements = (recentMeasurements + historicalMeasurements).sorted { $0.date > $1.date }
        return snapshot
    }
}
