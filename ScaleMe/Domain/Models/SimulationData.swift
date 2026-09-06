import Foundation

struct SimulationDataSnapshot {
    static let bodyCompositionScaleModelName = "ScaleMe Body Pro"
    static let weightOnlyScaleModelName = "ScaleMe Weight Mini"
    static let bodyCompositionScaleRuleID = "protocol.custom.simulated-body-pro"
    static let weightOnlyScaleRuleID = "protocol.custom.simulated-weight-mini"

    var profiles: [UserProfile]
    var selectedProfileID: UUID
    var pairedScales: [PairedScale]
    var measurements: [BodyMeasurement]

    static func make(
        language: AppLanguage = .systemDefault,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Self {
        make(
            language: language,
            referenceDate: referenceDate,
            calendar: calendar,
            includesMeasurements: true
        )
    }

    static func makeMetadata(
        language: AppLanguage = .systemDefault,
        launchDay: Date,
        calendar: Calendar = .current
    ) -> Self {
        make(
            language: language,
            referenceDate: launchDay,
            calendar: calendar,
            includesMeasurements: false
        )
    }

    private static func make(
        language: AppLanguage,
        referenceDate: Date,
        calendar: Calendar,
        includesMeasurements: Bool
    ) -> Self {
        var random = SeededSimulationRandom(seed: 0x5CA1_E5E5_2026_0830)
        let copy = SimulationCopy(language: language)
        let today = calendar.startOfDay(for: referenceDate)
        let primaryScaleID = random.uuid()
        let secondaryScaleID = random.uuid()
        let unmatchedScaleID = random.uuid()
        let pairedScales = [
            PairedScale(
                id: primaryScaleID,
                name: copy.primaryScaleName,
                modelName: bodyCompositionScaleModelName,
                compatibility: copy.simulatedDevice,
                communicationRuleID: bodyCompositionScaleRuleID,
                addedAt: calendar.date(byAdding: .day, value: -420, to: today) ?? today
            ),
            PairedScale(
                id: secondaryScaleID,
                name: copy.secondaryScaleName,
                modelName: weightOnlyScaleModelName,
                compatibility: copy.simulatedDevice,
                communicationRuleID: weightOnlyScaleRuleID,
                addedAt: calendar.date(byAdding: .day, value: -210, to: today) ?? today
            ),
            PairedScale(
                id: unmatchedScaleID,
                name: copy.unmatchedScaleName,
                modelName: "Demo BLE Device",
                compatibility: copy.pendingProtocol,
                addedAt: calendar.date(byAdding: .day, value: -3, to: today) ?? today
            )
        ]

        var profiles: [UserProfile] = []
        for specification in SimulationProfileSpecification.all {
            let localizedMember = copy.member(for: specification.avatar)
            profiles.append(simulationProfile(
                id: random.uuid(), name: localizedMember.name, role: localizedMember.role,
                heightCM: specification.heightCM, referenceWeightKG: specification.endWeightKG,
                age: specification.age, sex: specification.sex,
                avatar: specification.avatar,
                today: today, calendar: calendar
            ))
        }
        var snapshot = SimulationDataSnapshot(
            profiles: profiles,
            selectedProfileID: profiles[0].id,
            pairedScales: pairedScales,
            measurements: []
        )
        if includesMeasurements {
            snapshot.measurements = snapshot.generatedMeasurements(
                dayOffsets: 0...364,
                launchDay: today,
                calendar: calendar
            )
        }
        return snapshot
    }

    static func supportsBodyComposition(on device: PairedScale?) -> Bool {
        device?.modelName == bodyCompositionScaleModelName
    }

    mutating func relocalizeDefaults(from previousLanguage: AppLanguage, to language: AppLanguage) {
        guard previousLanguage != language else { return }
        let previousCopy = SimulationCopy(language: previousLanguage)
        let copy = SimulationCopy(language: language)

        for index in profiles.indices {
            let avatar = profiles[index].avatar
            guard profiles[index].name == previousCopy.member(for: avatar).name else { continue }
            profiles[index].name = copy.member(for: avatar).name
        }

        var localizedScaleNames: [UUID: (previous: String, current: String)] = [:]
        for index in pairedScales.indices {
            let modelName = pairedScales[index].modelName
            guard let previousName = previousCopy.scaleName(for: modelName),
                  let currentName = copy.scaleName(for: modelName) else { continue }

            if pairedScales[index].name == previousName {
                pairedScales[index].name = currentName
                localizedScaleNames[pairedScales[index].id] = (previousName, currentName)
            }
            if let previousCompatibility = previousCopy.compatibility(for: modelName),
               let currentCompatibility = copy.compatibility(for: modelName),
               pairedScales[index].compatibility == previousCompatibility {
                pairedScales[index].compatibility = currentCompatibility
            }
        }

        for index in measurements.indices {
            guard let deviceID = measurements[index].deviceID,
                  let localizedName = localizedScaleNames[deviceID],
                  measurements[index].deviceName == localizedName.previous else { continue }
            measurements[index].deviceName = localizedName.current
        }
    }

    private static func simulationProfile(
        id: UUID,
        name: String,
        role: String,
        heightCM: Double,
        referenceWeightKG: Double,
        age: Int,
        sex: UserProfile.BiologicalSex,
        avatar: MemberAvatar,
        today: Date,
        calendar: Calendar
    ) -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            role: role,
            heightCM: heightCM,
            referenceWeightKG: referenceWeightKG,
            birthDate: calendar.date(byAdding: .year, value: -age, to: today) ?? today,
            biologicalSex: sex,
            avatar: avatar
        )
    }

    func generatedMeasurements(
        dayOffsets: ClosedRange<Int>,
        launchDay: Date,
        calendar: Calendar = .current
    ) -> [BodyMeasurement] {
        guard dayOffsets.lowerBound >= 0,
              dayOffsets.upperBound <= 364,
              pairedScales.count >= 2 else { return [] }

        var result: [BodyMeasurement] = []
        for (profileIndex, profile) in profiles.enumerated() {
            let specification = SimulationProfileSpecification.specification(for: profile.avatar)
            for dayOffset in stride(
                from: dayOffsets.upperBound,
                through: dayOffsets.lowerBound,
                by: -1
            ) {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: launchDay) else { continue }
                var random = SeededSimulationRandom(seed: Self.measurementSeed(
                    profileIndex: profileIndex,
                    dayOffset: dayOffset
                ))
                let firstPeriodIsMorning = random.nextUnit() < 0.61
                let firstMinute = dayOffset == 0
                    ? 0
                    : Self.measurementMinute(isMorning: firstPeriodIsMorning, random: &random)
                Self.appendMeasurement(
                    to: &result,
                    profile: profile,
                    day: day,
                    minuteOfDay: firstMinute,
                    dayOffset: dayOffset,
                    specification: specification,
                    primaryScaleID: pairedScales[0].id,
                    secondaryScaleID: pairedScales[1].id,
                    primaryScaleName: pairedScales[0].name,
                    secondaryScaleName: pairedScales[1].name,
                    referenceDate: launchDay,
                    calendar: calendar,
                    random: &random
                )

                if Self.shouldGenerateRepeatMeasurement(
                    profileIndex: profileIndex,
                    dayOffset: dayOffset
                ) {
                    let isQuickRepeat = random.nextUnit() < 0.45
                    let secondMinute = isQuickRepeat
                        ? firstMinute + random.nextInt(in: 3...16)
                        : Self.measurementMinute(isMorning: !firstPeriodIsMorning, random: &random)
                    Self.appendMeasurement(
                        to: &result,
                        profile: profile,
                        day: day,
                        minuteOfDay: secondMinute,
                        dayOffset: dayOffset,
                        specification: specification,
                        primaryScaleID: pairedScales[0].id,
                        secondaryScaleID: pairedScales[1].id,
                        primaryScaleName: pairedScales[0].name,
                        secondaryScaleName: pairedScales[1].name,
                        referenceDate: launchDay,
                        calendar: calendar,
                        random: &random
                    )
                }
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private static func measurementSeed(profileIndex: Int, dayOffset: Int) -> UInt64 {
        0x5CA1_E5E5_2026_0830
            ^ (UInt64(profileIndex + 1) &* 0x9E37_79B9_7F4A_7C15)
            ^ (UInt64(dayOffset + 1) &* 0xD1B5_4A32_D192_ED03)
    }

    private static func shouldGenerateRepeatMeasurement(
        profileIndex: Int,
        dayOffset: Int
    ) -> Bool {
        guard dayOffset > 0 else { return false }
        let candidateIndex = profileIndex * 364 + dayOffset - 1
        let permutedIndex = (candidateIndex * 1_597 + 811) % 3_640
        return permutedIndex < 446
    }

    private static func appendMeasurement(
        to result: inout [BodyMeasurement],
        profile: UserProfile,
        day: Date,
        minuteOfDay: Int,
        dayOffset: Int,
        specification: SimulationProfileSpecification,
        primaryScaleID: UUID,
        secondaryScaleID: UUID,
        primaryScaleName: String,
        secondaryScaleName: String,
        referenceDate: Date,
        calendar: Calendar,
        random: inout SeededSimulationRandom
    ) {
        guard let date = calendar.date(byAdding: .minute, value: minuteOfDay, to: day),
              date <= referenceDate else { return }
        let progress = 1 - Double(dayOffset) / 364
        let longTermWeight = specification.startWeightKG
            + (specification.endWeightKG - specification.startWeightKG) * progress
        let seasonalVariation = sin(progress * .pi * 5.2) * 0.35
        let weightKG = max(15, longTermWeight + seasonalVariation + random.nextGaussianish() * 0.28)
        let fatTrend = specification.bodyFatPercent + (weightKG - specification.endWeightKG) * 0.34
        let bodyFatPercent = fatTrend + random.nextGaussianish() * 0.22
        let waterPercent = 66.2 - bodyFatPercent * 0.48 + random.nextGaussianish() * 0.18
        let fatFreeMassKG = weightKG * (1 - bodyFatPercent / 100)
        let muscleMassKG = fatFreeMassKG * (profile.biologicalSex == .male ? 0.94 : 0.91)
        let deviceID = random.nextUnit() < 0.84 ? primaryScaleID : secondaryScaleID

        let supportsBodyComposition = deviceID == primaryScaleID
        result.append(BodyMeasurement(
            id: random.uuid(),
            date: date,
            weightKG: weightKG,
            impedanceOhm: supportsBodyComposition ? 485 + random.nextGaussianish() * 22 : nil,
            bodyFatPercent: supportsBodyComposition ? bodyFatPercent : nil,
            muscleMassKG: supportsBodyComposition ? muscleMassKG : nil,
            waterPercent: supportsBodyComposition ? waterPercent : nil,
            visceralFat: supportsBodyComposition ? max(1, (bodyFatPercent - 12) * 0.42) : nil,
            basalMetabolismKCal: supportsBodyComposition
                ? 10 * weightKG
                    + 6.25 * profile.heightCM
                    - 5 * Double(profile.age)
                    + (profile.biologicalSex == .male ? 5 : -161)
                : nil,
            boneMassKG: supportsBodyComposition ? max(0.5, fatFreeMassKG * 0.052) : nil,
            source: .demo,
            isStable: true,
            profileID: profile.id,
            deviceID: deviceID,
            deviceName: deviceID == primaryScaleID ? primaryScaleName : secondaryScaleName
        ))
    }

    private static func measurementMinute(
        isMorning: Bool,
        random: inout SeededSimulationRandom
    ) -> Int {
        if isMorning {
            return 6 * 60 + 18 + random.nextInt(in: 0...116)
        }
        return 19 * 60 + 5 + random.nextInt(in: 0...178)
    }
}

enum SimulationMeasurementGenerator {
    static func make(
        profile: UserProfile,
        recentMeasurement: BodyMeasurement?,
        device: PairedScale?,
        date: Date = .now,
        calendar: Calendar = .current
    ) -> BodyMeasurement {
        let age = max(5, calendar.dateComponents([.year], from: profile.birthDate, to: date).year ?? 30)
        let heightMeters = profile.heightCM / 100
        let fallbackBMI = age < 18 ? 18.0 : 22.0
        let baselineWeightKG = recentMeasurement?.weightKG ?? max(15, fallbackBMI * heightMeters * heightMeters)
        let phase = date.timeIntervalSinceReferenceDate / 43
        let weightDeltaKG = sin(phase) * 0.18
        let weightKG = max(5, min(350, baselineWeightKG + weightDeltaKG))

        let fallbackBodyFat = profile.biologicalSex == .male
            ? 16 + max(0, Double(age - 30)) * 0.08
            : 24 + max(0, Double(age - 30)) * 0.10
        let baselineBodyFat = recentMeasurement?.bodyFatPercent ?? fallbackBodyFat
        let bodyFatPercent = max(3, min(60, baselineBodyFat + weightDeltaKG * 0.25 + cos(phase) * 0.04))
        let fatFreeMassKG = weightKG * (1 - bodyFatPercent / 100)
        let muscleRatio = profile.biologicalSex == .male ? 0.94 : 0.91
        let impedanceOhm = max(100, min(2_000, (recentMeasurement?.impedanceOhm ?? 485) + cos(phase) * 4))
        let supportsBodyComposition = SimulationDataSnapshot.supportsBodyComposition(on: device)

        return BodyMeasurement(
            date: date,
            weightKG: weightKG,
            impedanceOhm: supportsBodyComposition ? impedanceOhm : nil,
            secondaryImpedanceOhm: supportsBodyComposition ? recentMeasurement?.secondaryImpedanceOhm : nil,
            bodyFatPercent: supportsBodyComposition ? bodyFatPercent : nil,
            muscleMassKG: supportsBodyComposition ? fatFreeMassKG * muscleRatio : nil,
            waterPercent: supportsBodyComposition ? max(30, min(75, (100 - bodyFatPercent) * 0.732)) : nil,
            visceralFat: supportsBodyComposition
                ? max(1, min(30, (bodyFatPercent - 12) * 0.45 + Double(age) * 0.03))
                : nil,
            basalMetabolismKCal: supportsBodyComposition
                ? 10 * weightKG
                    + 6.25 * profile.heightCM
                    - 5 * Double(age)
                    + (profile.biologicalSex == .male ? 5 : -161)
                : nil,
            boneMassKG: supportsBodyComposition ? max(0.5, min(5, fatFreeMassKG * 0.052)) : nil,
            source: .demo,
            isStable: true,
            profileID: profile.id,
            deviceID: device?.id,
            deviceName: device?.name
        )
    }
}

private struct SimulationProfileSpecification {
    let avatar: MemberAvatar
    let heightCM: Double
    let age: Int
    let sex: UserProfile.BiologicalSex
    let startWeightKG: Double
    let endWeightKG: Double
    let bodyFatPercent: Double

    static let all: [Self] = [
        Self(avatar: .father, heightCM: 178, age: 45, sex: .male,
             startWeightKG: 78.5, endWeightKG: 76.8, bodyFatPercent: 20.1),
        Self(avatar: .adult, heightCM: 165, age: 42, sex: .female,
             startWeightKG: 61.8, endWeightKG: 59.2, bodyFatPercent: 26.1),
        Self(avatar: .child, heightCM: 128, age: 8, sex: .male,
             startWeightKG: 26.4, endWeightKG: 28.7, bodyFatPercent: 17.5),
        Self(avatar: .childDaughter, heightCM: 116, age: 6, sex: .female,
             startWeightKG: 20.8, endWeightKG: 22.6, bodyFatPercent: 18.7),
        Self(avatar: .youth, heightCM: 168, age: 15, sex: .male,
             startWeightKG: 56.8, endWeightKG: 60.2, bodyFatPercent: 15.8),
        Self(avatar: .teenDaughter, heightCM: 162, age: 16, sex: .female,
             startWeightKG: 49.4, endWeightKG: 51.2, bodyFatPercent: 22.3),
        Self(avatar: .senior, heightCM: 158, age: 72, sex: .female,
             startWeightKG: 61.8, endWeightKG: 61.2, bodyFatPercent: 31.8),
        Self(avatar: .paternalGrandfather, heightCM: 170, age: 74, sex: .male,
             startWeightKG: 69.8, endWeightKG: 68.9, bodyFatPercent: 24.1),
        Self(avatar: .maternalGrandfather, heightCM: 168, age: 71, sex: .male,
             startWeightKG: 72.2, endWeightKG: 71.1, bodyFatPercent: 23.3),
        Self(avatar: .maternalGrandmother, heightCM: 157, age: 69, sex: .female,
             startWeightKG: 59.5, endWeightKG: 58.9, bodyFatPercent: 32.2)
    ]

    static func specification(for avatar: MemberAvatar) -> Self {
        guard let specification = all.first(where: { $0.avatar == avatar }) else {
            preconditionFailure("Missing simulation profile specification for \(avatar.rawValue)")
        }
        return specification
    }
}

private struct SimulationMemberCopy {
    let name: String
    let role: String
}

private struct SimulationCopy {
    let members: [MemberAvatar: SimulationMemberCopy]
    let primaryScaleName: String
    let secondaryScaleName: String
    let unmatchedScaleName: String
    let simulatedDevice: String
    let pendingProtocol: String

    private static let roles: [MemberAvatar] = [
        .father, .adult, .child, .childDaughter, .youth,
        .teenDaughter, .senior, .paternalGrandfather,
        .maternalGrandfather, .maternalGrandmother
    ]

    init(language: AppLanguage) {
        unmatchedScaleName = language.text("附近的健康设备")
        pendingProtocol = language.text("协议待验证")
        let names: [String]
        switch language {
        case .simplifiedChinese:
            names = [
                "林远舟", "沈知夏", "林予安", "林予宁", "林清越",
                "林语桐", "周秀琴", "林国安", "沈明德", "唐兰芳"
            ]
            primaryScaleName = "浴室体脂秤"
            secondaryScaleName = "卧室体重秤"
            simulatedDevice = "模拟设备"
        case .traditionalChinese:
            names = [
                "林承遠", "陳雅雯", "林昱辰", "林語晴", "林柏翰",
                "林欣妤", "王美玲", "林志明", "陳建國", "李秀蘭"
            ]
            primaryScaleName = "浴室體脂計"
            secondaryScaleName = "臥室體重計"
            simulatedDevice = "模擬裝置"
        case .english:
            names = [
                "Daniel", "Emily", "Noah", "Lily", "Ethan",
                "Chloe", "Margaret", "George", "Robert", "Helen"
            ]
            primaryScaleName = "Body Scale"
            secondaryScaleName = "Weight Scale"
            simulatedDevice = "Simulated device"
        case .japanese:
            names = [
                "佐藤健一", "佐藤美咲", "佐藤悠真", "佐藤結衣", "佐藤陽翔",
                "佐藤葵", "佐藤和子", "佐藤正雄", "鈴木博", "鈴木幸子"
            ]
            primaryScaleName = "体組成計"
            secondaryScaleName = "体重計"
            simulatedDevice = "シミュレーション機器"
        case .french:
            names = [
                "Julien", "Claire", "Lucas", "Emma", "Hugo",
                "Léa", "Monique", "Bernard", "Michel", "Françoise"
            ]
            primaryScaleName = "Balance santé"
            secondaryScaleName = "Balance poids"
            simulatedDevice = "Appareil simulé"
        case .german:
            names = [
                "Thomas", "Anna", "Lukas", "Mia", "Jonas",
                "Sophie", "Helga", "Hans", "Klaus", "Ingrid"
            ]
            primaryScaleName = "Körperwaage"
            secondaryScaleName = "Zimmerwaage"
            simulatedDevice = "Simuliertes Gerät"
        case .spanish:
            names = [
                "Carlos", "Lucía", "Mateo", "Sofía", "Diego",
                "Valeria", "Carmen", "José", "Manuel", "Isabel"
            ]
            primaryScaleName = "Báscula corporal"
            secondaryScaleName = "Báscula peso"
            simulatedDevice = "Dispositivo simulado"
        case .portuguese:
            names = [
                "João", "Mariana", "Tiago", "Beatriz", "Miguel",
                "Inês", "Teresa", "António", "Manuel", "Maria"
            ]
            primaryScaleName = "Balança corporal"
            secondaryScaleName = "Balança peso"
            simulatedDevice = "Dispositivo simulado"
        case .russian:
            names = [
                "Алексей", "Елена", "Михаил", "Анна", "Дмитрий",
                "София", "Нина", "Виктор", "Сергей", "Людмила"
            ]
            primaryScaleName = "Умные весы"
            secondaryScaleName = "Весы"
            simulatedDevice = "Симулируемое устройство"
        case .korean:
            names = [
                "김민준", "이서연", "김도윤", "김하윤", "김준서",
                "김지우", "박영숙", "김영수", "이정호", "최순자"
            ]
            primaryScaleName = "욕실 체성분 체중계"
            secondaryScaleName = "침실 체중계"
            simulatedDevice = "시뮬레이션 기기"
        }

        members = Dictionary(uniqueKeysWithValues: zip(Self.roles, names).map { role, name in
            (role, SimulationMemberCopy(name: name, role: Self.role(for: role)))
        })
    }

    private static func role(for role: MemberAvatar) -> String {
        switch role {
        case .father:
            "本人"
        case .adult:
            "伴侣"
        case .child, .childDaughter, .youth, .teenDaughter:
            "子女"
        case .senior, .paternalGrandfather, .maternalGrandfather, .maternalGrandmother:
            "父母"
        }
    }

    func member(for avatar: MemberAvatar) -> SimulationMemberCopy {
        guard let member = members[avatar] else {
            preconditionFailure("Missing simulation copy for \(avatar.rawValue)")
        }
        return member
    }

    func scaleName(for modelName: String) -> String? {
        switch modelName {
        case SimulationDataSnapshot.bodyCompositionScaleModelName:
            primaryScaleName
        case SimulationDataSnapshot.weightOnlyScaleModelName:
            secondaryScaleName
        case "Demo BLE Device":
            unmatchedScaleName
        default:
            nil
        }
    }

    func compatibility(for modelName: String) -> String? {
        switch modelName {
        case SimulationDataSnapshot.bodyCompositionScaleModelName,
             SimulationDataSnapshot.weightOnlyScaleModelName:
            simulatedDevice
        case "Demo BLE Device":
            pendingProtocol
        default:
            nil
        }
    }
}

private struct SeededSimulationRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let count = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(next() % UInt64(count))
    }

    mutating func nextGaussianish() -> Double {
        (nextUnit() + nextUnit() + nextUnit() + nextUnit() - 2) / 0.58
    }

    mutating func uuid() -> UUID {
        let high = next()
        let low = next()
        return UUID(uuid: (
            UInt8(truncatingIfNeeded: high >> 56), UInt8(truncatingIfNeeded: high >> 48),
            UInt8(truncatingIfNeeded: high >> 40), UInt8(truncatingIfNeeded: high >> 32),
            UInt8(truncatingIfNeeded: high >> 24), UInt8(truncatingIfNeeded: high >> 16),
            UInt8(truncatingIfNeeded: high >> 8), UInt8(truncatingIfNeeded: high),
            UInt8(truncatingIfNeeded: low >> 56), UInt8(truncatingIfNeeded: low >> 48),
            UInt8(truncatingIfNeeded: low >> 40), UInt8(truncatingIfNeeded: low >> 32),
            UInt8(truncatingIfNeeded: low >> 24), UInt8(truncatingIfNeeded: low >> 16),
            UInt8(truncatingIfNeeded: low >> 8), UInt8(truncatingIfNeeded: low)
        ))
    }
}
