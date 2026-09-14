import Foundation
import HealthKit

@MainActor
final class AppleHealthManager: ObservableObject {
    enum WeightWriteAuthorizationState: Equatable {
        case unavailable
        case notDetermined
        case authorized
        case denied
    }

    @Published private(set) var weightWriteAuthorizationState: WeightWriteAuthorizationState = .notDetermined
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var isImporting = false
    @Published private(set) var lastAuthorizationError: String?
    @Published private(set) var lastShareError: String?
    @Published private(set) var lastImportError: String?

    private let healthStore = HKHealthStore()
    private static let measurementIDMetadataKey = "com.bugwz.scaleme.measurement-id"

    private var bodyMassType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .bodyMass)
    }

    private var bodyFatType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)
    }

    func refreshWeightWriteAuthorizationState() {
        guard HKHealthStore.isHealthDataAvailable(), let bodyMassType else {
            weightWriteAuthorizationState = .unavailable
            return
        }

        weightWriteAuthorizationState = switch healthStore.authorizationStatus(for: bodyMassType) {
        case .notDetermined: .notDetermined
        case .sharingAuthorized: .authorized
        case .sharingDenied: .denied
        @unknown default: .notDetermined
        }
    }

    /// A completed request does not reveal whether read access was granted.
    @discardableResult
    func requestAuthorization(for request: AppleHealthAccessRequest) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), !isRequestingAuthorization else { return false }
        let readTypes = Set<HKObjectType>(request.readTypes.compactMap { healthKitType(for: $0) })
        let writeTypes = Set<HKSampleType>(request.writeTypes.compactMap { healthKitType(for: $0) })
        guard !readTypes.isEmpty || !writeTypes.isEmpty else { return false }
        isRequestingAuthorization = true
        lastAuthorizationError = nil
        defer {
            isRequestingAuthorization = false
            refreshWeightWriteAuthorizationState()
        }
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            lastAuthorizationError = error.localizedDescription
            return false
        }
    }

    func readMeasurements(
        dataTypes: Set<AppleHealthDataType>,
        profileID: UUID
    ) async -> [BodyMeasurement] {
        guard dataTypes.contains(.bodyMass), let bodyMassType else { return [] }
        isImporting = true
        defer { isImporting = false }

        do {
            let bodyMassSamples = try await samples(for: bodyMassType)
            let bodyFatSamples: [HKQuantitySample]
            if dataTypes.contains(.bodyFatPercentage), let bodyFatType {
                bodyFatSamples = try await samples(for: bodyFatType)
            } else {
                bodyFatSamples = []
            }

            let measurements = bodyMassSamples.compactMap { sample -> BodyMeasurement? in
                guard sample.metadata?[Self.measurementIDMetadataKey] == nil else { return nil }
                let weightKG = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                guard (2...500).contains(weightKG) else { return nil }
                return BodyMeasurement(
                    id: sample.uuid,
                    date: sample.startDate,
                    weightKG: weightKG,
                    bodyFatPercent: matchingBodyFatPercent(for: sample, in: bodyFatSamples),
                    source: .appleHealth,
                    isStable: true,
                    profileID: profileID
                )
            }
            lastImportError = nil
            return measurements
        } catch {
            lastImportError = error.localizedDescription
            return []
        }
    }

    func share(_ measurement: BodyMeasurement) {
        guard measurement.isStable,
              measurement.deviceID != nil,
              weightWriteAuthorizationState == .authorized else { return }
        let samples = samples(for: measurement)
        guard !samples.isEmpty else { return }

        Task {
            do {
                try await healthStore.save(samples)
                lastShareError = nil
            } catch {
                lastShareError = error.localizedDescription
                refreshWeightWriteAuthorizationState()
            }
        }
    }

    private func samples(for measurement: BodyMeasurement) -> [HKQuantitySample] {
        guard let bodyMassType, (2...500).contains(measurement.weightKG) else { return [] }
        let metadata: [String: Any] = [
            Self.measurementIDMetadataKey: measurement.id.uuidString,
            HKMetadataKeyWasUserEntered: measurement.source == .manual
        ]
        var samples = [
            HKQuantitySample(
                type: bodyMassType,
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: measurement.weightKG),
                start: measurement.date,
                end: measurement.date,
                metadata: metadata
            )
        ]

        if let bodyFatType,
           let bodyFatPercent = measurement.bodyFatPercent,
           (1...75).contains(bodyFatPercent),
           healthStore.authorizationStatus(for: bodyFatType) == .sharingAuthorized {
            samples.append(
                HKQuantitySample(
                    type: bodyFatType,
                    quantity: HKQuantity(unit: .percent(), doubleValue: bodyFatPercent / 100),
                    start: measurement.date,
                    end: measurement.date,
                    metadata: metadata
                )
            )
        }
        return samples
    }

    private func healthKitType(for dataType: AppleHealthDataType) -> HKQuantityType? {
        switch dataType {
        case .bodyMass: bodyMassType
        case .bodyFatPercentage: bodyFatType
        }
    }

    private func samples(for type: HKQuantityType) async throws -> [HKQuantitySample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await descriptor.result(for: healthStore)
    }

    private func matchingBodyFatPercent(
        for bodyMassSample: HKQuantitySample,
        in samples: [HKQuantitySample]
    ) -> Double? {
        let sourceIdentifier = bodyMassSample.sourceRevision.source.bundleIdentifier
        guard let sample = (samples
            .filter {
                $0.metadata?[Self.measurementIDMetadataKey] == nil
                    && $0.sourceRevision.source.bundleIdentifier == sourceIdentifier
                    && abs($0.startDate.timeIntervalSince(bodyMassSample.startDate)) <= 60
            }
            .min(by: {
                abs($0.startDate.timeIntervalSince(bodyMassSample.startDate))
                    < abs($1.startDate.timeIntervalSince(bodyMassSample.startDate))
            })) else { return nil }
        let percent = sample.quantity.doubleValue(for: .percent()) * 100
        return (1...75).contains(percent) ? percent : nil
    }
}
