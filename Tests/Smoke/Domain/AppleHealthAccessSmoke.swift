import Foundation

@main
struct AppleHealthAccessSmoke {
    static func main() {
        let request = AppleHealthAccessRequest()
        precondition(request.readTypes == [.bodyMass, .bodyFatPercentage])
        precondition(request.writeTypes == request.readTypes)
        precondition(!AppConfiguration.standard.isAppleHealthSyncEnabled)
        precondition(!AppConfiguration.standard.isAppleHealthImportEnabled)
        precondition(AppConfiguration.standard.appleHealthProfileID == nil)
        print("Apple Health access smoke tests passed")
    }
}
