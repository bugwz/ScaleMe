import Foundation

enum MeasurementSampleReliability: Equatable {
    case protocolFinal
    case protocolLocked
    case protocolStable
    case requiresStability
}

struct MeasurementSessionUpdate {
    enum Phase: Equatable {
        case measuring
        case stabilizing
        case completed
        case ignored
    }

    var phase: Phase
    var liveMeasurement: BodyMeasurement?
    var completedMeasurement: BodyMeasurement?
}

struct MeasurementSession {
    private struct TimedSample {
        var receivedAt: Date
        var measurement: BodyMeasurement
    }

    private static let stabilityWindow: TimeInterval = 0.8
    private static let maximumWindow: TimeInterval = 2.5
    private static let minimumProtocolSession: TimeInterval = 1.8
    private static let stableRangeKG = 0.15
    private static let newSessionInterval: TimeInterval = 8

    private var samples: [TimedSample] = []
    private var completedAt: Date?
    private var completedWeightKG: Double?
    private var newLoadMinimumKG: Double?
    private var lastReceivedAt: Date?
    private var sessionStartedAt: Date?

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        completedAt = nil
        completedWeightKG = nil
        newLoadMinimumKG = nil
        lastReceivedAt = nil
        sessionStartedAt = nil
    }

    mutating func ingest(
        _ measurement: BodyMeasurement,
        reliability: MeasurementSampleReliability,
        receivedAt: Date = .now
    ) -> MeasurementSessionUpdate {
        if completedAt != nil {
            if reliability == .protocolFinal {
                reset()
            } else if let newLoadMinimumKG {
                let minimum = min(newLoadMinimumKG, measurement.weightKG)
                self.newLoadMinimumKG = minimum
                guard measurement.weightKG >= minimum + 2 else {
                    lastReceivedAt = receivedAt
                    return MeasurementSessionUpdate(phase: .ignored)
                }
                reset()
            } else if let completedWeightKG,
                      measurement.weightKG <= completedWeightKG - 2 {
                newLoadMinimumKG = measurement.weightKG
                lastReceivedAt = receivedAt
                return MeasurementSessionUpdate(phase: .ignored)
            } else {
                guard let lastReceivedAt,
                      receivedAt.timeIntervalSince(lastReceivedAt) >= Self.newSessionInterval else {
                    self.lastReceivedAt = receivedAt
                    return MeasurementSessionUpdate(phase: .ignored)
                }
                reset()
            }
        }
        lastReceivedAt = receivedAt
        if sessionStartedAt == nil { sessionStartedAt = receivedAt }

        if reliability == .protocolFinal || reliability == .protocolLocked {
            return complete(measurement, receivedAt: receivedAt)
        }

        if let last = samples.last,
           abs(last.measurement.weightKG - measurement.weightKG) > Self.stableRangeKG {
            samples.removeAll(keepingCapacity: true)
        }

        samples.append(TimedSample(receivedAt: receivedAt, measurement: measurement))
        samples.removeAll { receivedAt.timeIntervalSince($0.receivedAt) > Self.maximumWindow }

        let hasMinimumProtocolDuration = reliability != .protocolStable
            || receivedAt.timeIntervalSince(sessionStartedAt ?? receivedAt) >= Self.minimumProtocolSession
        let hasProtocolFinality = reliability != .protocolStable || measurement.isStable
        let requiredSampleCount = reliability == .protocolStable ? 2 : 3
        guard hasMinimumProtocolDuration,
              hasProtocolFinality,
              samples.count >= requiredSampleCount,
              let first = samples.first,
              receivedAt.timeIntervalSince(first.receivedAt) >= Self.stabilityWindow else {
            return MeasurementSessionUpdate(
                phase: samples.count >= 2 ? .stabilizing : .measuring,
                liveMeasurement: measurement
            )
        }

        let weights = samples.map(\.measurement.weightKG)
        guard let minimum = weights.min(), let maximum = weights.max(),
              maximum - minimum <= Self.stableRangeKG else {
            return MeasurementSessionUpdate(phase: .stabilizing, liveMeasurement: measurement)
        }

        return complete(measurement, receivedAt: receivedAt)
    }

    private mutating func complete(
        _ measurement: BodyMeasurement,
        receivedAt: Date
    ) -> MeasurementSessionUpdate {
        completedAt = receivedAt
        completedWeightKG = measurement.weightKG
        newLoadMinimumKG = nil
        samples.removeAll(keepingCapacity: true)
        var completed = measurement
        completed.isStable = true
        return MeasurementSessionUpdate(
            phase: .completed,
            liveMeasurement: completed,
            completedMeasurement: completed
        )
    }
}
