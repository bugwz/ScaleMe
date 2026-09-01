import Foundation
import HealthKit

@MainActor
final class AppleHealthManager: ObservableObject {
    enum AuthorizationState: Equatable {
        case unavailable
        case notDetermined
        case authorized
        case denied
        case failed(String)
    }

    @Published private(set) var authorizationState: AuthorizationState = .notDetermined
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var lastShareError: String?

    private let healthStore = HKHealthStore()

    private var bodyMassType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .bodyMass)
    }

    private var bodyFatType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)
    }

    func refreshAuthorizationState() {
        guard HKHealthStore.isHealthDataAvailable(), let bodyMassType else {
            authorizationState = .unavailable
            return
        }

        authorizationState = switch healthStore.authorizationStatus(for: bodyMassType) {
        case .notDetermined: .notDetermined
        case .sharingAuthorized: .authorized
        case .sharingDenied: .denied
        @unknown default: .notDetermined
        }
    }

    @discardableResult
    func requestSharingAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let bodyMassType,
              let bodyFatType else {
            authorizationState = .unavailable
            return false
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        do {
            try await healthStore.requestAuthorization(
                toShare: [bodyMassType, bodyFatType],
                read: []
            )
            refreshAuthorizationState()
            return authorizationState == .authorized
        } catch {
            authorizationState = .failed(error.localizedDescription)
            return false
        }
    }

    func share(_ measurement: BodyMeasurement) {
        guard measurement.isStable,
              measurement.deviceID != nil,
              authorizationState == .authorized else { return }
        let samples = samples(for: measurement)
        guard !samples.isEmpty else { return }

        Task {
            do {
                try await healthStore.save(samples)
                lastShareError = nil
            } catch {
                lastShareError = error.localizedDescription
                refreshAuthorizationState()
            }
        }
    }

    private func samples(for measurement: BodyMeasurement) -> [HKQuantitySample] {
        guard let bodyMassType, (2...500).contains(measurement.weightKG) else { return [] }
        let metadata: [String: Any] = [
            "com.scaleme.measurement-id": measurement.id.uuidString,
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
}
