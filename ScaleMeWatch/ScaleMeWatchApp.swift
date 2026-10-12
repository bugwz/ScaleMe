import SwiftUI

@main
struct ScaleMeWatchApp: App {
    @StateObject private var session = WatchSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(session)
                .environment(\.locale, Locale(identifier: session.snapshot?.language ?? Locale.current.identifier))
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, session.reachable { session.request(.refresh) }
                }
        }
    }
}
