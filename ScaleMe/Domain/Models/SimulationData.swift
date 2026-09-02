import Foundation

struct SimulationDataSnapshot {
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
        let pairedScales = [
            PairedScale(
                id: primaryScaleID,
                name: copy.primaryScaleName,
                modelName: "ScaleMe Body Pro",
                compatibility: copy.simulatedDevice,
                addedAt: calendar.date(byAdding: .day, value: -420, to: today) ?? today
            ),
            PairedScale(
                id: secondaryScaleID,
                name: copy.secondaryScaleName,
                modelName: "ScaleMe Weight Mini",
                compatibility: copy.simulatedDevice,
                addedAt: calendar.date(byAdding: .day, value: -210, to: today) ?? today
            )
        ]

        let memberSeeds = [
            SimulationMemberSeed(
                heightCM: 178, age: 45,
                sex: .male, avatar: .father
            ),
            SimulationMemberSeed(
                heightCM: 165, age: 42,
                sex: .female,
                avatar: .adult
            ),
            SimulationMemberSeed(
                heightCM: 128, age: 8,
                sex: .male, avatar: .child
            ),
            SimulationMemberSeed(
                heightCM: 116, age: 6,
                sex: .female, avatar: .childDaughter
            ),
            SimulationMemberSeed(
                heightCM: 168, age: 15,
                sex: .male, avatar: .youth
            ),
            SimulationMemberSeed(
                heightCM: 162, age: 16,
                sex: .female, avatar: .teenDaughter
            ),
            SimulationMemberSeed(
                heightCM: 158, age: 72,
                sex: .female, avatar: .senior
            ),
            SimulationMemberSeed(
                heightCM: 170, age: 74,
                sex: .male, avatar: .paternalGrandfather
            ),
            SimulationMemberSeed(
                heightCM: 168, age: 71,
                sex: .male, avatar: .maternalGrandfather
            ),
            SimulationMemberSeed(
                heightCM: 157, age: 69,
                sex: .female, avatar: .maternalGrandmother
            )
        ]

        var profiles: [UserProfile] = []
        for seed in memberSeeds {
            let localizedMember = copy.member(for: seed.avatar)
            profiles.append(simulationProfile(
                id: random.uuid(), name: localizedMember.name, relation: localizedMember.relation,
                heightCM: seed.heightCM, age: seed.age, sex: seed.sex,
                avatar: seed.avatar, today: today, calendar: calendar
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

    private static func simulationProfile(
        id: UUID,
        name: String,
        relation: String,
        heightCM: Double,
        age: Int,
        sex: UserProfile.BiologicalSex,
        avatar: MemberAvatar,
        today: Date,
        calendar: Calendar
    ) -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            relation: relation,
            heightCM: heightCM,
            birthDate: calendar.date(byAdding: .year, value: -age, to: today) ?? today,
            biologicalSex: sex,
            athleteMode: false,
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

        result.append(BodyMeasurement(
            id: random.uuid(),
            date: date,
            weightKG: weightKG,
            impedanceOhm: 485 + random.nextGaussianish() * 22,
            bodyFatPercent: bodyFatPercent,
            muscleMassKG: muscleMassKG,
            waterPercent: waterPercent,
            visceralFat: max(3, (bodyFatPercent - 12) * 0.42),
            basalMetabolismKCal: 10 * weightKG
                + 6.25 * profile.heightCM
                - 5 * Double(profile.age)
                + (profile.biologicalSex == .male ? 5 : -161),
            boneMassKG: max(2, fatFreeMassKG * 0.052),
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

private struct SimulationProfileSpecification {
    let startWeightKG: Double
    let endWeightKG: Double
    let bodyFatPercent: Double

    static func specification(for avatar: MemberAvatar) -> Self {
        switch avatar {
        case .father: Self(startWeightKG: 78.5, endWeightKG: 76.8, bodyFatPercent: 20.1)
        case .adult: Self(startWeightKG: 61.8, endWeightKG: 59.2, bodyFatPercent: 26.1)
        case .child: Self(startWeightKG: 26.4, endWeightKG: 28.7, bodyFatPercent: 17.5)
        case .childDaughter: Self(startWeightKG: 20.8, endWeightKG: 22.6, bodyFatPercent: 18.7)
        case .youth: Self(startWeightKG: 56.8, endWeightKG: 60.2, bodyFatPercent: 15.8)
        case .teenDaughter: Self(startWeightKG: 49.4, endWeightKG: 51.2, bodyFatPercent: 22.3)
        case .senior: Self(startWeightKG: 61.8, endWeightKG: 61.2, bodyFatPercent: 31.8)
        case .paternalGrandfather: Self(startWeightKG: 69.8, endWeightKG: 68.9, bodyFatPercent: 24.1)
        case .maternalGrandfather: Self(startWeightKG: 72.2, endWeightKG: 71.1, bodyFatPercent: 23.3)
        case .maternalGrandmother: Self(startWeightKG: 59.5, endWeightKG: 58.9, bodyFatPercent: 32.2)
        }
    }
}

private struct SimulationMemberSeed {
    let heightCM: Double
    let age: Int
    let sex: UserProfile.BiologicalSex
    let avatar: MemberAvatar
}

private struct SimulationMemberCopy {
    let name: String
    let relation: String
}

private struct SimulationCopy {
    let members: [MemberAvatar: SimulationMemberCopy]
    let primaryScaleName: String
    let secondaryScaleName: String
    let simulatedDevice: String

    private static let roles: [MemberAvatar] = [
        .father, .adult, .child, .childDaughter, .youth,
        .teenDaughter, .senior, .paternalGrandfather,
        .maternalGrandfather, .maternalGrandmother
    ]

    init(language: AppLanguage) {
        let values: [(name: String, relation: String)]
        switch language {
        case .simplifiedChinese:
            values = [
                ("林远舟", "爸爸"), ("沈知夏", "妈妈"),
                ("林予安", "儿童儿子"), ("林予宁", "儿童女儿"),
                ("林清越", "青少年儿子"), ("林语桐", "青少年女儿"),
                ("周秀琴", "奶奶"), ("林国安", "爷爷"),
                ("沈明德", "外公"), ("唐兰芳", "外婆")
            ]
            primaryScaleName = "浴室体脂秤"
            secondaryScaleName = "卧室体重秤"
            simulatedDevice = "模拟设备"
        case .traditionalChinese:
            values = [
                ("林承遠", "爸爸"), ("陳雅雯", "媽媽"),
                ("林昱辰", "年幼兒子"), ("林語晴", "年幼女兒"),
                ("林柏翰", "青少年兒子"), ("林欣妤", "青少年女兒"),
                ("王美玲", "奶奶"), ("林志明", "爺爺"),
                ("陳建國", "外公"), ("李秀蘭", "外婆")
            ]
            primaryScaleName = "浴室體脂計"
            secondaryScaleName = "臥室體重計"
            simulatedDevice = "模擬裝置"
        case .english:
            values = [
                ("Daniel", "Father"), ("Emily", "Mother"),
                ("Noah", "Young son"), ("Lily", "Young daughter"),
                ("Ethan", "Teenage son"), ("Chloe", "Teenage daughter"),
                ("Margaret", "Paternal grandmother"), ("George", "Paternal grandfather"),
                ("Robert", "Maternal grandfather"), ("Helen", "Maternal grandmother")
            ]
            primaryScaleName = "Body Scale"
            secondaryScaleName = "Weight Scale"
            simulatedDevice = "Simulated device"
        case .japanese:
            values = [
                ("佐藤健一", "父"), ("佐藤美咲", "母"),
                ("佐藤悠真", "幼い息子"), ("佐藤結衣", "幼い娘"),
                ("佐藤陽翔", "10代の息子"), ("佐藤葵", "10代の娘"),
                ("佐藤和子", "父方の祖母"), ("佐藤正雄", "父方の祖父"),
                ("鈴木博", "母方の祖父"), ("鈴木幸子", "母方の祖母")
            ]
            primaryScaleName = "体組成計"
            secondaryScaleName = "体重計"
            simulatedDevice = "シミュレーション機器"
        case .french:
            values = [
                ("Julien", "Père"), ("Claire", "Mère"),
                ("Lucas", "Jeune fils"), ("Emma", "Jeune fille"),
                ("Hugo", "Fils adolescent"), ("Léa", "Fille adolescente"),
                ("Monique", "Grand-mère paternelle"), ("Bernard", "Grand-père paternel"),
                ("Michel", "Grand-père maternel"), ("Françoise", "Grand-mère maternelle")
            ]
            primaryScaleName = "Balance santé"
            secondaryScaleName = "Balance poids"
            simulatedDevice = "Appareil simulé"
        case .german:
            values = [
                ("Thomas", "Vater"), ("Anna", "Mutter"),
                ("Lukas", "Junger Sohn"), ("Mia", "Junge Tochter"),
                ("Jonas", "Sohn im Teenageralter"), ("Sophie", "Tochter im Teenageralter"),
                ("Helga", "Großmutter väterlicherseits"), ("Hans", "Großvater väterlicherseits"),
                ("Klaus", "Großvater mütterlicherseits"), ("Ingrid", "Großmutter mütterlicherseits")
            ]
            primaryScaleName = "Körperwaage"
            secondaryScaleName = "Zimmerwaage"
            simulatedDevice = "Simuliertes Gerät"
        case .spanish:
            values = [
                ("Carlos", "Padre"), ("Lucía", "Madre"),
                ("Mateo", "Hijo pequeño"), ("Sofía", "Hija pequeña"),
                ("Diego", "Hijo adolescente"), ("Valeria", "Hija adolescente"),
                ("Carmen", "Abuela paterna"), ("José", "Abuelo paterno"),
                ("Manuel", "Abuelo materno"), ("Isabel", "Abuela materna")
            ]
            primaryScaleName = "Báscula corporal"
            secondaryScaleName = "Báscula peso"
            simulatedDevice = "Dispositivo simulado"
        case .portuguese:
            values = [
                ("João", "Pai"), ("Mariana", "Mãe"),
                ("Tiago", "Filho mais novo"), ("Beatriz", "Filha mais nova"),
                ("Miguel", "Filho adolescente"), ("Inês", "Filha adolescente"),
                ("Teresa", "Avó paterna"), ("António", "Avô paterno"),
                ("Manuel", "Avô materno"), ("Maria", "Avó materna")
            ]
            primaryScaleName = "Balança corporal"
            secondaryScaleName = "Balança peso"
            simulatedDevice = "Dispositivo simulado"
        case .russian:
            values = [
                ("Алексей", "Отец"), ("Елена", "Мать"),
                ("Михаил", "Младший сын"), ("Анна", "Младшая дочь"),
                ("Дмитрий", "Сын-подросток"), ("София", "Дочь-подросток"),
                ("Нина", "Бабушка по отцу"), ("Виктор", "Дедушка по отцу"),
                ("Сергей", "Дедушка по матери"), ("Людмила", "Бабушка по матери")
            ]
            primaryScaleName = "Умные весы"
            secondaryScaleName = "Весы"
            simulatedDevice = "Симулируемое устройство"
        case .korean:
            values = [
                ("김민준", "아빠"), ("이서연", "엄마"),
                ("김도윤", "어린 아들"), ("김하윤", "어린 딸"),
                ("김준서", "십 대 아들"), ("김지우", "십 대 딸"),
                ("박영숙", "친할머니"), ("김영수", "친할아버지"),
                ("이정호", "외할아버지"), ("최순자", "외할머니")
            ]
            primaryScaleName = "욕실 체성분 체중계"
            secondaryScaleName = "침실 체중계"
            simulatedDevice = "시뮬레이션 기기"
        }

        members = Dictionary(uniqueKeysWithValues: zip(Self.roles, values).map { role, value in
            (role, SimulationMemberCopy(name: value.name, relation: value.relation))
        })
    }

    func member(for avatar: MemberAvatar) -> SimulationMemberCopy {
        guard let member = members[avatar] else {
            preconditionFailure("Missing simulation copy for \(avatar.rawValue)")
        }
        return member
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
