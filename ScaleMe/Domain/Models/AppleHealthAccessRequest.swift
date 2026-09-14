import Foundation

/// Read and write permissions are requested only for the selected operation.
enum AppleHealthAccessRequest {
    case sharing
    case importing(Set<AppleHealthDataType>)

    var readTypes: Set<AppleHealthDataType> {
        switch self {
        case .sharing: []
        case let .importing(types): types
        }
    }

    var writeTypes: Set<AppleHealthDataType> {
        switch self {
        case .sharing: [.bodyMass, .bodyFatPercentage]
        case .importing: []
        }
    }
}
