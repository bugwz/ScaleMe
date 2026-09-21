import Foundation

/// The sync entry requests both directions; individual switches only configure data flow.
struct AppleHealthAccessRequest {
    let readTypes: Set<AppleHealthDataType> = [.bodyMass, .bodyFatPercentage]
    let writeTypes: Set<AppleHealthDataType> = [.bodyMass, .bodyFatPercentage]
}
