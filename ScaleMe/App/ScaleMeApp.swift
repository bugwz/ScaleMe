import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }
}

@MainActor
enum AppOrientation {
    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard AppDelegate.supportedOrientations != orientations else { return }
        AppDelegate.supportedOrientations = orientations
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
    }
}

@main
struct ScaleMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                    .environment(\.locale, store.appLanguage.locale)

                if isShowingLaunchScreen {
                    AnimatedLaunchView(language: store.appLanguage, isExiting: isLeavingLaunchScreen)
                        .zIndex(1)
                }

            }
            .background(AppColor.canvas.ignoresSafeArea())
            .preferredColorScheme(.light)
            .environment(\.locale, store.appLanguage.locale)
            .onReceive(bluetooth.$latestMeasurement.compactMap { $0 }) { measurement in
                store.add(measurement)
            }
            .onChange(of: store.configuration) {
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
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
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
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
