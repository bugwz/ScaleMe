import Foundation

@main
struct BodyCompositionCalculationSmoke {
    static func main() throws {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        var profile = UserProfile(heightCM: 180,
            birthDate: calendar.date(from: DateComponents(year: 1994, month: 6, day: 15))!, biologicalSex: .male)
        let raw = BodyMeasurement(date: date, weightKG: 81, impedanceOhm: 500,
            source: .wolaiAFU, isStable: true)
        let display = BodyCompositionCalculation.applying(to: raw, profile: profile)
        precondition(abs(display.displayedBodyFatPercent! - 26.968888888888888) < 1e-9)
        precondition(abs(display.applicationEstimate!.fatFreeMassKG! - 59.1552) < 1e-9)
        precondition(display.applicationEstimate?.restingEnergyKCal == 1790)
        precondition(display.bodyFatPercent == nil && display.basalMetabolismKCal == nil)
        precondition(display.muscleMassKG == nil && display.boneMassKG == nil && display.visceralFat == nil)
        precondition(display.waterPercent == nil)
        precondition(abs(display.waterMassKG! - 43.3016064) < 1e-6)
        precondition(abs(display.displayedBoneMassKG! - 3.0760704) < 1e-9)
        precondition(abs(display.displayedMuscleMassKG! + display.displayedBoneMassKG! - 59.1552) < 1e-9)
        precondition(abs(display.displayedBasalMetabolismKCal! - 1802.332) < 1e-6)
        for kind in DashboardMetricKind.allCases {
            precondition(kind.value(in: display, profile: profile) != nil, kind.rawValue)
            precondition(kind.usesApplicationEstimate(in: display) == (kind != .bmi), kind.rawValue)
        }
        for metric in TrendMetric.allCases where metric.isEstimatedComposition {
            precondition(metric.value(for: display, profile: profile) != nil, metric.rawValue)
            precondition(metric.usesApplicationEstimate(in: display), metric.rawValue)
        }
        precondition(display.impedanceOhm == raw.impedanceOhm)
        precondition(display.applicationEstimate?.bodyFatMethod == .experimentalFootToFootImpedance)
        precondition(display.applicationEstimate?.impedanceUsedOhm == 500)
        // Synthetic input: same weight/profile, different Z must change the estimate.
        var changedImpedance = raw
        changedImpedance.impedanceOhm = 600
        let changed = BodyCompositionCalculation.applying(to: changedImpedance, profile: profile)
        precondition(abs(changed.applicationEstimate!.fatFreeMassKG! - 54.9) < 1e-9)
        precondition(changed.displayedBodyFatPercent! > display.displayedBodyFatPercent!)
        precondition(changed.waterMassKG! < display.waterMassKG!)
        precondition(changed.displayedBoneMassKG! < display.displayedBoneMassKG!)
        precondition(changed.displayedMuscleMassKG! < display.displayedMuscleMassKG!)
        precondition(changed.displayedVisceralFat! > display.displayedVisceralFat!)
        // Unknown second-channel semantics: preserve it, never average or substitute it.
        changedImpedance = raw
        changedImpedance.secondaryImpedanceOhm = 900
        let twoChannels = BodyCompositionCalculation.applying(to: changedImpedance, profile: profile)
        precondition(twoChannels.displayedBodyFatPercent == display.displayedBodyFatPercent)
        precondition(twoChannels.secondaryImpedanceOhm == 900)
        changedImpedance.impedanceOhm = nil
        precondition(BodyCompositionCalculation.applying(to: changedImpedance, profile: profile).displayedBodyFatPercent == nil)
        for impedance in [Double.nan, .infinity, 0, -1, 99, 2_001, 100] {
            // 100 ohms passes packet bounds but produces impossible FFM for this fixture.
            changedImpedance.impedanceOhm = impedance
            let invalid = BodyCompositionCalculation.applying(to: changedImpedance, profile: profile)
            precondition(invalid.displayedBodyFatPercent == nil)
            precondition(invalid.applicationEstimate?.bodyFatMethod == nil)
            precondition(invalid.displayedMuscleMassKG == nil && invalid.displayedBoneMassKG == nil)
            precondition(invalid.displayedWaterPercent == nil && invalid.displayedVisceralFat == nil)
        }
        changedImpedance = raw
        changedImpedance.source = .bluetoothSIG
        precondition(BodyCompositionCalculation.applying(to: changedImpedance, profile: profile)
            .applicationEstimate?.bodyFatMethod == .experimentalFootToFootImpedance)
        precondition(TrendMetric.bodyFat.value(for: display, profile: profile) == display.displayedBodyFatPercent)
        precondition(DashboardMetricKind.bodyFatPercent.value(in: display, profile: profile) == display.displayedBodyFatPercent)
        var supplied = raw
        supplied.bodyFatPercent = 22
        supplied.basalMetabolismKCal = 1700
        let preferred = BodyCompositionCalculation.applying(to: supplied, profile: profile)
        precondition(preferred.displayedBodyFatPercent == 22 && !preferred.usesEstimatedBodyFat)
        precondition(preferred.applicationEstimate?.restingEnergyKCal == nil)
        supplied.muscleMassKG = 55
        supplied.waterPercent = 54
        supplied.boneMassKG = 3
        supplied.visceralFat = 8
        let suppliedDisplay = BodyCompositionCalculation.applying(to: supplied, profile: profile)
        precondition(suppliedDisplay.displayedMuscleMassKG == 55 && suppliedDisplay.displayedWaterPercent == 54)
        precondition(suppliedDisplay.displayedBoneMassKG == 3 && suppliedDisplay.displayedVisceralFat == 8)
        precondition(suppliedDisplay.displayedBasalMetabolismKCal == 1700)
        precondition(!suppliedDisplay.hasApplicationEstimates)
        // A supplied bone value takes precedence when deriving missing muscle mass.
        supplied.muscleMassKG = nil
        let mixed = BodyCompositionCalculation.applying(to: supplied, profile: profile)
        precondition(abs(mixed.displayedMuscleMassKG! - 60.18) < 1e-9)
        precondition(DashboardMetricKind.musclePercent.usesApplicationEstimate(in: mixed))
        precondition(!DashboardMetricKind.bonePercent.usesApplicationEstimate(in: mixed))
        var weightOnly = raw
        weightOnly.impedanceOhm = nil
        weightOnly.source = .bluetoothSIG
        precondition(BodyCompositionCalculation.applying(to: weightOnly, profile: profile).applicationEstimate == nil)
        let decoder = CommunicationRuleDecoder(weight: CommunicationField(offset: 0, length: 2, scale: 0.01),
            impedance: CommunicationField(offset: 2, length: 2, scale: 1))
        precondition(BodyCompositionCalculation.applying(to: weightOnly, profile: profile, decoder: decoder).displayedBodyFatPercent == nil)
        var invalid = raw
        for weight in [Double.nan, .infinity, 0, -1, 501] {
            invalid.weightKG = weight
            precondition(BodyCompositionCalculation.applying(to: invalid, profile: profile).applicationEstimate == nil)
        }
        // AFU requires impedance even when the final packet contains no usable reading.
        weightOnly.source = .wolaiAFU
        precondition(BodyCompositionCalculation.applying(to: weightOnly, profile: profile).displayedBodyFatPercent == nil)
        for source in [MeasurementSource.huaweiHagrid, .xiaomi] {
            weightOnly.source = source
            precondition(BodyCompositionCalculation.applying(to: weightOnly, profile: profile).displayedBodyFatPercent == nil)
        }
        // A composition protocol without measured impedance must not estimate any missing values.
        weightOnly.source = .bluetoothSIG
        let compositionDecoder = CommunicationRuleDecoder(weight: CommunicationField(offset: 0, length: 2, scale: 0.01),
            bodyFatPercent: CommunicationField(offset: 2, length: 2, scale: 0.1))
        let fallback = BodyCompositionCalculation.applying(to: weightOnly, profile: profile, decoder: compositionDecoder)
        precondition(fallback.applicationEstimate == nil)
        // Older adults use the wide-age impedance model, never a BMI fallback.
        var olderProfile = profile
        olderProfile.birthDate = calendar.date(from: DateComponents(year: 1948, month: 6, day: 15))!
        precondition(BodyCompositionCalculation.applying(to: raw, profile: olderProfile)
            .applicationEstimate?.bodyFatMethod == .experimentalSunImpedance)
        var lowBMI = raw
        lowBMI.weightKG = 48.6
        precondition(BodyCompositionCalculation.applying(to: lowBMI, profile: profile).displayedBodyFatPercent == nil)
        for source in [MeasurementSource.manual, .appleHealth] {
            var input = raw; input.source = source
            precondition(BodyCompositionCalculation.applying(to: input, profile: profile).applicationEstimate == nil)
        }
        var simulated = raw; simulated.source = .demo
        let simulatedDisplay = BodyCompositionCalculation.applying(to: simulated, profile: profile)
        precondition(simulatedDisplay.displayedBodyFatPercent == BodyCompositionCalculation.applying(to: raw, profile: profile).displayedBodyFatPercent)
        simulated.impedanceOhm = nil
        precondition(BodyCompositionCalculation.applying(to: simulated, profile: profile).applicationEstimate == nil)
        var live = raw; live.isStable = false
        precondition(BodyCompositionCalculation.applying(to: live, profile: profile).applicationEstimate == nil)
        profile.biologicalSex = .female
        let reassigned = BodyCompositionCalculation.applying(to: display, profile: profile)
        precondition(abs(reassigned.displayedBodyFatPercent! - 36.99975308641975) < 1e-9)
        precondition(reassigned.applicationEstimate?.restingEnergyKCal == 1624)
        profile.birthDate = calendar.date(from: DateComponents(year: 2010, month: 6, day: 15))!
        let child = BodyCompositionCalculation.applying(to: display, profile: profile)
        precondition(child.applicationEstimate?.bodyFatMethod == .experimentalSunImpedance)
        precondition(child.displayedBodyFatPercent != nil)
        precondition(child.displayedBasalMetabolismKCal != nil)
        precondition(child.displayedWaterPercent != nil && child.displayedBoneMassKG == nil)
        profile.birthDate = calendar.date(from: DateComponents(year: 1994, month: 6, day: 15))!
        for height in [Double.nan, .infinity, 0, -1, 19, 1000] {
            profile.heightCM = height
            precondition(BodyCompositionCalculation.applying(to: raw, profile: profile).applicationEstimate == nil)
        }
        let archive = MeasurementArchive(updatedAt: date, measurements: [display], deletedMeasurements: [])
        let restored = try RecordFileCodec.decode(RecordFileCodec.encode(archive, prettyPrinted: true))
        precondition(restored.measurements[0].applicationEstimate == nil)
        precondition(restored.measurements[0].bodyFatPercent == nil)
        precondition(restored.measurements[0].impedanceOhm == 500)
        precondition(restored.measurements[0].muscleMassKG == nil && restored.measurements[0].waterPercent == nil)
        precondition(restored.measurements[0].boneMassKG == nil && restored.measurements[0].visceralFat == nil)
        precondition(restored.measurements[0].basalMetabolismKCal == nil)
        print("Body composition calculation smoke checks passed")
    }
}
