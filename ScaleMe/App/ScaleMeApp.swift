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
    @StateObject private var appleHealth = AppleHealthManager()
    @State private var isShowingLaunchScreen = true
    @State private var isLeavingLaunchScreen = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(store)
                    .environmentObject(bluetooth)
                    .environmentObject(cloudSync)
                    .environmentObject(appleHealth)
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
            .preferredColorScheme(store.appearance.colorScheme)
            .environment(\.locale, store.appLanguage.locale)
            .environment(\.appLanguage, store.appLanguage)
            .onReceive(bluetooth.$latestMeasurement.compactMap { $0 }) { measurement in
                store.add(measurement)
            }
            .onChange(of: store.configuration) {
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                cloudSync.configurationDidChange()
                exportWidgetSnapshot()
            }
            .onChange(of: store.archive) {
                cloudSync.measurementsDidChange()
                exportWidgetSnapshot()
            }
            .onChange(of: store.displayMeasurements) {
                exportWidgetSnapshot()
            }
            .onChange(of: store.displaySelectedProfileID) {
                exportWidgetSnapshot()
            }
            .onReceive(store.$latestHealthShareCandidate.compactMap { $0 }) { measurement in
                guard !store.isSimulationEnabled,
                      measurement.profileID == store.appleHealthProfileID,
                      let deviceID = measurement.deviceID,
                      store.appleHealthDeviceIDs.contains(deviceID) else { return }
                appleHealth.share(measurement)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    store.refreshSystemLanguage()
                    cloudSync.syncWhenAppBecomesActive()
                    appleHealth.refreshAuthorizationState()
                }
            }
            .task {
                store.prepareSimulationDataIfNeeded()
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                cloudSync.attach(to: store)
                appleHealth.refreshAuthorizationState()
                exportWidgetSnapshot()
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

    private func exportWidgetSnapshot() {
        let snapshot = store.makeWidgetTrendSnapshot()
        Task {
            await WidgetTrendSnapshotExporter.shared.export(snapshot)
        }
    }
}

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
