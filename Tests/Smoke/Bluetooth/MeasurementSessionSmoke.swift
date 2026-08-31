import Foundation

@main
enum MeasurementSessionSmoke {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = MeasurementSession()

        let first = session.ingest(sample(59.2), reliability: .requiresStability, receivedAt: start)
        precondition(first.phase == .measuring)
        precondition(first.completedMeasurement == nil)

        _ = session.ingest(sample(60.0), reliability: .requiresStability, receivedAt: start.addingTimeInterval(1.0))
        _ = session.ingest(sample(60.05), reliability: .requiresStability, receivedAt: start.addingTimeInterval(1.4))
        let completed = session.ingest(sample(60.0), reliability: .requiresStability, receivedAt: start.addingTimeInterval(1.9))
        precondition(completed.phase == .completed)
        precondition(abs((completed.completedMeasurement?.weightKG ?? 0) - 60) < 0.001)

        let descending = session.ingest(sample(52), reliability: .requiresStability, receivedAt: start.addingTimeInterval(2.2))
        precondition(descending.phase == .ignored)
        precondition(descending.liveMeasurement == nil)

        _ = session.ingest(sample(60), reliability: .requiresStability, receivedAt: start.addingTimeInterval(7))
        let stillStanding = session.ingest(sample(60), reliability: .requiresStability, receivedAt: start.addingTimeInterval(12))
        precondition(stillStanding.phase == .ignored)

        var indicatedSession = MeasurementSession()
        let indicated = indicatedSession.ingest(sample(61.25), reliability: .protocolFinal, receivedAt: start)
        precondition(indicated.phase == .completed)
        precondition(indicated.completedMeasurement?.isStable == true)
        let nextIndication = indicatedSession.ingest(
            sample(62),
            reliability: .protocolFinal,
            receivedAt: start.addingTimeInterval(1)
        )
        precondition(nextIndication.phase == .completed)
        precondition(abs((nextIndication.completedMeasurement?.weightKG ?? 0) - 62) < 0.001)

        var xiaomiSession = MeasurementSession()
        let partialStart = xiaomiSession.ingest(
            xiaomiSample(11.9, isStable: true),
            reliability: .protocolStable,
            receivedAt: start
        )
        _ = xiaomiSession.ingest(
            xiaomiSample(11.9, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(0.4)
        )
        let partialPlateau = xiaomiSession.ingest(
            xiaomiSample(11.9, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(0.9)
        )
        precondition(partialStart.completedMeasurement == nil)
        precondition(partialPlateau.completedMeasurement == nil)

        _ = xiaomiSession.ingest(
            xiaomiSample(42, isStable: false),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(1.1)
        )
        _ = xiaomiSession.ingest(
            xiaomiSample(80, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(1.4)
        )
        _ = xiaomiSession.ingest(
            xiaomiSample(80.05, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(1.9)
        )
        let xiaomiCompleted = xiaomiSession.ingest(
            xiaomiSample(80, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(2.3)
        )
        precondition(xiaomiCompleted.phase == .completed)
        precondition(abs((xiaomiCompleted.completedMeasurement?.weightKG ?? 0) - 80) < 0.001)

        let xiaomiDescent = xiaomiSession.ingest(
            xiaomiSample(11.9, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(2.6)
        )
        precondition(xiaomiDescent.phase == .ignored)

        var capturedGATTSession = MeasurementSession()
        let capturedWeights: [(TimeInterval, Double, Bool)] = [
            (3.840, 83.1, false),
            (4.169, 83.2, false),
            (4.500, 82.55, false),
            (4.829, 83.1, false),
            (5.159, 82.9, false),
            (5.489, 83.2, false),
            (5.819, 83.2, false),
            (6.148, 83.1, false),
            (6.479, 83.1, false),
            (6.808, 83.1, false),
            (7.140, 83.1, false)
        ]
        for (offset, weight, isStable) in capturedWeights {
            let update = capturedGATTSession.ingest(
                xiaomiSample(weight, isStable: isStable),
                reliability: .protocolStable,
                receivedAt: start.addingTimeInterval(offset)
            )
            precondition(update.completedMeasurement == nil)
        }
        let capturedStable = capturedGATTSession.ingest(
            xiaomiSample(83.1, isStable: true),
            reliability: .protocolStable,
            receivedAt: start.addingTimeInterval(7.469)
        )
        precondition(capturedStable.phase == .completed)
        precondition(abs((capturedStable.completedMeasurement?.weightKG ?? 0) - 83.1) < 0.001)

        print("Measurement session smoke tests passed")
    }

    private static func sample(_ weightKG: Double) -> BodyMeasurement {
        BodyMeasurement(date: .now, weightKG: weightKG, source: .bluetoothSIG, isStable: false)
    }

    private static func xiaomiSample(_ weightKG: Double, isStable: Bool) -> BodyMeasurement {
        BodyMeasurement(date: .now, weightKG: weightKG, source: .xiaomi, isStable: isStable)
    }
}
