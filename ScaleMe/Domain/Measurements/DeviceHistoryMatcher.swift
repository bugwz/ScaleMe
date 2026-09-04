import Foundation

struct DeviceHistoryImportSummary: Equatable {
    var importedCount: Int
    var duplicateCount: Int
    var unmatchedCount: Int
}

struct DeviceHistoryImportPlan: Equatable {
    var attributedMeasurements: [BodyMeasurement]
    var duplicateCount: Int
    var unmatchedMeasurements: [BodyMeasurement]

    var summary: DeviceHistoryImportSummary {
        DeviceHistoryImportSummary(
            importedCount: attributedMeasurements.count,
            duplicateCount: duplicateCount,
            unmatchedCount: unmatchedMeasurements.count
        )
    }
}

/// Assigns device history to members using nearby personal trends first and the
/// member's approximate reference weight as a fallback. Ambiguous records stay
/// unmatched instead of being silently assigned to the selected member.
struct DeviceHistoryMatcher {
    private struct Candidate {
        let profileID: UUID
        let score: Double
        let weightDeltaKG: Double
        let allowedWeightDeltaKG: Double
    }

    static func plan(
        history: [BodyMeasurement],
        profiles: [UserProfile],
        existingMeasurements: [BodyMeasurement]
    ) -> DeviceHistoryImportPlan {
        guard !profiles.isEmpty else {
            return DeviceHistoryImportPlan(
                attributedMeasurements: [],
                duplicateCount: 0,
                unmatchedMeasurements: history
            )
        }

        var knownMeasurements = existingMeasurements
        var knownByProfile = Dictionary(grouping: existingMeasurements.compactMap { measurement in
            measurement.profileID.map { ($0, measurement) }
        }, by: \.0).mapValues { $0.map(\.1) }
        var attributed: [BodyMeasurement] = []
        var pending: [BodyMeasurement] = []
        var duplicateCount = 0

        // Remove duplicates before matching so repeated imports are idempotent
        // even when a protocol creates a fresh UUID for every decoded record.
        for measurement in history.sorted(by: { $0.date > $1.date }) {
            if knownMeasurements.contains(where: { isDuplicate(measurement, of: $0) })
                || pending.contains(where: { isDuplicate(measurement, of: $0) }) {
                duplicateCount += 1
                continue
            }
            pending.append(measurement)
        }

        // Repeat after every set of confident assignments. This lets an older
        // overlap with app history become an anchor for newer device-only data.
        while !pending.isEmpty {
            var remaining: [BodyMeasurement] = []
            var matchedInPass = 0
            for measurement in pending {
                let candidates = profiles
                    .compactMap {
                        candidate(
                            for: measurement,
                            profile: $0,
                            profileHistory: knownByProfile[$0.id] ?? []
                        )
                    }
                    .sorted { $0.score < $1.score }

                guard let best = candidates.first,
                      best.weightDeltaKG <= best.allowedWeightDeltaKG,
                      isUnambiguous(best: best, runnerUp: candidates.dropFirst().first) else {
                    remaining.append(measurement)
                    continue
                }

                var assigned = measurement
                assigned.profileID = best.profileID
                attributed.append(assigned)
                knownMeasurements.append(assigned)
                knownByProfile[best.profileID, default: []].append(assigned)
                matchedInPass += 1
            }
            pending = remaining
            if matchedInPass == 0 { break }
        }

        return DeviceHistoryImportPlan(
            attributedMeasurements: attributed,
            duplicateCount: duplicateCount,
            unmatchedMeasurements: pending
        )
    }

    static func isDuplicate(_ candidate: BodyMeasurement, of existing: BodyMeasurement) -> Bool {
        guard abs(candidate.date.timeIntervalSince(existing.date)) < 2,
              abs(candidate.weightKG - existing.weightKG) < 0.02 else { return false }

        if let candidateDeviceID = candidate.deviceID, let existingDeviceID = existing.deviceID {
            return candidateDeviceID == existingDeviceID
        }
        return candidate.source == existing.source
    }

    private static func candidate(
        for measurement: BodyMeasurement,
        profile: UserProfile,
        profileHistory: [BodyMeasurement]
    ) -> Candidate? {
        guard profile.referenceWeightKG.isFinite,
              (5...350).contains(profile.referenceWeightKG) else { return nil }

        let nearest = profileHistory.min {
            abs($0.date.timeIntervalSince(measurement.date)) < abs($1.date.timeIntervalSince(measurement.date))
        }
        let nearestAgeDays = nearest.map { abs($0.date.timeIntervalSince(measurement.date)) / 86_400 }
        let usesTrend = nearestAgeDays.map { $0 <= 180 } == true
        let expectedWeightKG = usesTrend ? nearest?.weightKG ?? profile.referenceWeightKG : profile.referenceWeightKG
        let weightDeltaKG = abs(measurement.weightKG - expectedWeightKG)
        let allowedWeightDeltaKG = usesTrend
            ? max(2.5, expectedWeightKG * 0.05)
            : max(4, expectedWeightKG * 0.08)

        var score = weightDeltaKG / allowedWeightDeltaKG
        if usesTrend, let nearest {
            score += metricPenalty(measurement.bodyFatPercent, nearest.bodyFatPercent, tolerance: 4) * 0.20
            score += metricPenalty(measurement.impedanceOhm, nearest.impedanceOhm, tolerance: 120) * 0.12
            score += metricPenalty(measurement.muscleMassKG, nearest.muscleMassKG, tolerance: 4) * 0.10
        }

        return Candidate(
            profileID: profile.id,
            score: score,
            weightDeltaKG: weightDeltaKG,
            allowedWeightDeltaKG: allowedWeightDeltaKG
        )
    }

    private static func metricPenalty(_ lhs: Double?, _ rhs: Double?, tolerance: Double) -> Double {
        guard let lhs, let rhs, lhs.isFinite, rhs.isFinite else { return 0 }
        return min(abs(lhs - rhs) / tolerance, 2)
    }

    private static func isUnambiguous(best: Candidate, runnerUp: Candidate?) -> Bool {
        guard let runnerUp else { return true }
        guard runnerUp.weightDeltaKG <= runnerUp.allowedWeightDeltaKG else { return true }
        return runnerUp.score - best.score >= 0.30
    }
}
