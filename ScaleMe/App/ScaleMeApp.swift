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
    @StateObject private var appleHealth = AppleHealthManager()
    @State private var isShowingLaunchScreen = true
    @State private var isLeavingLaunchScreen = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(store)
                    .environmentObject(bluetooth)
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
            .background(AppAppearanceTransitionView(appearance: store.appearance))
            .environment(\.locale, store.appLanguage.locale)
            .environment(\.appLanguage, store.appLanguage)
            .onReceive(bluetooth.$latestMeasurement.compactMap { $0 }) { measurement in
                store.add(measurement)
            }
            .onReceive(bluetooth.$automaticallyRetrievedHistory.compactMap { $0 }) { batch in
                let summary = store.importDeviceHistory(batch.measurements)
                bluetooth.finishAutomaticHistoryImport(batch.id, summary: summary)
            }
            .onChange(of: store.configuration) {
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                exportWidgetSnapshot()
            }
            .onChange(of: store.archive) {
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
                    appleHealth.refreshAuthorizationState()
                    Task { await syncAppleHealthIfNeeded() }
                }
            }
            .task {
                store.prepareSimulationDataIfNeeded()
                bluetooth.updatePairedScales(store.pairedScales, communicationRules: store.communicationRules)
                appleHealth.refreshAuthorizationState()
                await syncAppleHealthIfNeeded()
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

    private func syncAppleHealthIfNeeded() async {
        guard !store.isSimulationEnabled,
              store.isAppleHealthImportEnabled,
              !appleHealth.isImporting,
              let currentUser = store.currentUserProfile else { return }
        let imported = await appleHealth.readMeasurements(
            dataTypes: store.appleHealthReadTypes,
            profileID: currentUser.id
        )
        store.importAppleHealthMeasurements(imported)
    }
}

private struct AppAppearanceTransitionView: UIViewControllerRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let appearance: AppAppearance

    func makeUIViewController(context: Context) -> AppearanceController {
        let controller = AppearanceController()
        controller.requestedStyle = appearance.interfaceStyle
        return controller
    }

    func updateUIViewController(_ controller: AppearanceController, context: Context) {
        controller.apply(appearance.interfaceStyle, animated: !reduceMotion)
    }

    final class AppearanceController: UIViewController {
        var requestedStyle: UIUserInterfaceStyle = .unspecified
        private var hasAppliedInitialStyle = false

        override func loadView() {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply(requestedStyle, animated: false)
        }

        func apply(_ style: UIUserInterfaceStyle, animated: Bool) {
            requestedStyle = style
            guard let window = viewIfLoaded?.window else { return }
            guard window.overrideUserInterfaceStyle != style else {
                hasAppliedInitialStyle = true
                return
            }

            let shouldAnimate = animated && hasAppliedInitialStyle
            hasAppliedInitialStyle = true

            guard shouldAnimate else {
                window.overrideUserInterfaceStyle = style
                return
            }

            UIView.transition(
                with: window,
                duration: 0.32,
                options: [.transitionCrossDissolve, .beginFromCurrentState, .allowAnimatedContent]
            ) {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

private extension AppAppearance {
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}
