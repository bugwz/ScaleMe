import Foundation

@main
struct AppleHealthAccessSmoke {
    static func main() {
        let sharing = AppleHealthAccessRequest.sharing
        precondition(sharing.readTypes.isEmpty)
        precondition(sharing.writeTypes == [.bodyMass, .bodyFatPercentage])
        for types: Set<AppleHealthDataType> in [[], [.bodyMass], [.bodyMass, .bodyFatPercentage]] {
            let importing = AppleHealthAccessRequest.importing(types)
            precondition(importing.readTypes == types)
            precondition(importing.writeTypes.isEmpty)
        }
        print("Apple Health access smoke tests passed")
    }
}
