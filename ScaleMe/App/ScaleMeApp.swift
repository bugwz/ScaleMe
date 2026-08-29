import SwiftUI

@main
struct ScaleMeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = MeasurementStore()
    @StateObject private var bluetooth = BLEScaleManager()
    @StateObject private var cloudSync = ICloudSyncManager()
    @State private var isShowingLaunchScreen = true
    @State private var isLeavingLaunchScreen = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(store)
                    .environmentObject(bluetooth)
                    .environmentObject(cloudSync)
                    .opacity(isShowingLaunchScreen && !isLeavingLaunchScreen ? 0 : 1)
                    .scaleEffect(isShowingLaunchScreen && !isLeavingLaunchScreen ? 1.012 : 1)
                    .allowsHitTesting(!isShowingLaunchScreen)
                    .accessibilityHidden(isShowingLaunchScreen)

                if isShowingLaunchScreen {
                    AnimatedLaunchView(isExiting: isLeavingLaunchScreen)
                        .zIndex(1)
                }

            }
            .background(AppColor.canvas.ignoresSafeArea())
            .preferredColorScheme(.light)
            .onReceive(bluetooth.$latestMeasurement.compactMap { $0 }) { measurement in
                store.add(measurement)
            }
            .onChange(of: store.configuration) {
                bluetooth.updatePairedScales(store.pairedScales)
                cloudSync.configurationDidChange()
            }
            .onChange(of: store.archive) {
                cloudSync.measurementsDidChange()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    cloudSync.syncWhenAppBecomesActive()
                }
            }
            .task {
                bluetooth.updatePairedScales(store.pairedScales)
                cloudSync.attach(to: store)
                guard isShowingLaunchScreen else { return }
                try? await Task.sleep(for: .seconds(2.75))
                withAnimation(.easeInOut(duration: 0.55)) {
                    isLeavingLaunchScreen = true
                }
                try? await Task.sleep(for: .seconds(0.55))
                isShowingLaunchScreen = false
            }
        }
    }
}
