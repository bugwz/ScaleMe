import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = RootTab.home
    @State private var navigationStore = RootNavigationControllerStore()
    @State private var scrollToTopRequests: [RootTab: Int] = [:]
    @State private var expandedTrend: ExpandedTrendPresentation?
    @State private var isOrientationTransitioning = false
    @State private var orientationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppPageBackground(avatar: store.displaySelectedProfile.avatar)
                .ignoresSafeArea()

            rootTabs
                .opacity(expandedTrend == nil ? 1 : 0)
                .allowsHitTesting(expandedTrend == nil)
                .accessibilityHidden(expandedTrend != nil)
                .transaction { transaction in
                    if expandedTrend != nil {
                        transaction.animation = nil
                    }
                }

            if let expandedTrend {
                ExpandedTrendChartView(
                    presentation: expandedTrend,
                    onClose: dismissExpandedTrend
                )
                .transition(expandedTrendTransition)
                .zIndex(1)
            }
        }
        .statusBarHidden(expandedTrend != nil || isOrientationTransitioning)
        .onDisappear {
            orientationTask?.cancel()
        }
    }

    private var rootTabs: some View {
        TabView(selection: $selection) {
            // Each tab supplies visibility to its enclosing TabView; placing
            // this preference on TabView itself leaves the system bar visible.
            DashboardView(
                scrollToTopRequest: scrollToTopRequests[.home, default: 0],
                onMeasure: { profileID in
                    guard !store.isUsingPlaceholderData else {
                        selection = .settings
                        return
                    }
                    store.selectDisplayProfile(profileID)
                    selection = .measure
                },
                onShowTrends: { selection = .trends }
            )
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .home) }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label(RootTab.home.title(in: store.appLanguage), systemImage: RootTab.home.systemImage) }
            .tag(RootTab.home)

            MeasureView(scrollToTopRequest: scrollToTopRequests[.measure, default: 0])
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .measure) }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label(RootTab.measure.title(in: store.appLanguage), systemImage: RootTab.measure.systemImage) }
            .tag(RootTab.measure)

            HistoryView(
                expandedTrend: expandedTrendBinding,
                scrollToTopRequest: scrollToTopRequests[.trends, default: 0]
            )
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .trends) }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label(RootTab.trends.title(in: store.appLanguage), systemImage: RootTab.trends.systemImage) }
            .tag(RootTab.trends)

            DevicesView(scrollToTopRequest: scrollToTopRequests[.devices, default: 0])
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .devices) }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label(RootTab.devices.title(in: store.appLanguage), image: "ScaleDeviceTabIcon") }
            .tag(RootTab.devices)

            ProfileView(scrollToTopRequest: scrollToTopRequests[.settings, default: 0])
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .settings) }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label(RootTab.settings.title(in: store.appLanguage), systemImage: RootTab.settings.systemImage) }
            .tag(RootTab.settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if expandedTrend == nil {
                AppBottomNavigation(
                    selection: $selection,
                    language: store.appLanguage,
                    onDoubleTap: resetTabToRoot
                )
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(AppColor.mint)
        .onOpenURL(perform: openDeepLink)
    }

    private var expandedTrendTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 0.985).combined(with: .opacity)
        )
    }

    private var expandedTrendBinding: Binding<ExpandedTrendPresentation?> {
        Binding(
            get: { expandedTrend },
            set: { presentation in
                guard let presentation else {
                    dismissExpandedTrend()
                    return
                }
                presentExpandedTrend(presentation)
            }
        )
    }

    private func presentExpandedTrend(_ presentation: ExpandedTrendPresentation) {
        guard expandedTrend == nil else { return }
        orientationTask?.cancel()
        withTransaction(Transaction(animation: nil)) {
            isOrientationTransitioning = true
        }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.34)) {
            expandedTrend = presentation
        }
        orientationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            AppOrientation.request(.landscape)
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 500))
            guard !Task.isCancelled else { return }
            isOrientationTransitioning = false
        }
    }

    private func dismissExpandedTrend() {
        guard expandedTrend != nil else { return }
        orientationTask?.cancel()
        isOrientationTransitioning = true
        AppOrientation.request(.portrait)

        orientationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 420))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                expandedTrend = nil
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 30 : 220))
            guard !Task.isCancelled else { return }
            isOrientationTransitioning = false
        }
    }

    private func resetTabToRoot(_ tab: RootTab) {
        navigationStore.popToRoot(for: tab)
        scrollToTopRequests[tab, default: 0] += 1
    }

    private func openDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "scaleme",
              url.host?.lowercased() == "trends" else {
            return
        }
        orientationTask?.cancel()
        if expandedTrend != nil {
            AppOrientation.request(.portrait)
            isOrientationTransitioning = false
        }
        expandedTrend = nil
        selection = .trends
    }
}

private enum RootTab: Int, CaseIterable, Identifiable {
    case home
    case measure
    case trends
    case devices
    case settings

    var id: Self { self }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .home: language.text(.home)
        case .measure: language.text(.measure)
        case .trends: language.text(.trends)
        case .devices: language.text(.devices)
        case .settings: language.text(.settings)
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .measure: "wave.3.right"
        case .trends: "chart.xyaxis.line"
        case .devices: "scalemass.fill"
        case .settings: "gearshape.fill"
        }
    }
}

@MainActor
private final class RootNavigationControllerStore {
    private var navigationControllers: [RootTab: WeakNavigationController] = [:]

    func register(_ navigationController: UINavigationController, for tab: RootTab) {
        navigationControllers[tab] = WeakNavigationController(navigationController)
    }

    func popToRoot(for tab: RootTab) {
        navigationControllers[tab]?.value?.popToRootViewController(animated: true)
    }
}

private final class WeakNavigationController {
    weak var value: UINavigationController?

    init(_ value: UINavigationController) {
        self.value = value
    }
}

private struct AppBottomNavigation: View {
    @Binding var selection: RootTab
    let language: AppLanguage
    let onDoubleTap: (RootTab) -> Void

    @State private var previousTap: (tab: RootTab, time: Date)?

    private let doubleTapInterval: TimeInterval = 0.35

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 58)
        .background {
            AppColor.bottomNavigationSurface
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.bottomNavigationInactive.opacity(0.16))
                .frame(height: 0.5)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: RootTab) -> some View {
        let isSelected = selection == tab

        return Button {
            KeyboardFocus.dismiss()
            handleTap(on: tab)
            withAnimation(.easeOut(duration: 0.18)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                tabIcon(tab)
                    .frame(width: 23, height: 23)

                Text(tab.title(in: language))
                    .font(.caption2.weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(
                isSelected ? AppColor.bottomNavigationSelected : AppColor.bottomNavigationInactive
            )
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title(in: language))
        .accessibilityValue(isSelected ? language.text(.currentPage) : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleTap(on tab: RootTab) {
        let now = Date()
        if let previousTap,
           previousTap.tab == tab,
           now.timeIntervalSince(previousTap.time) <= doubleTapInterval {
            self.previousTap = nil
            onDoubleTap(tab)
        } else {
            previousTap = (tab, now)
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: RootTab) -> some View {
        if tab == .devices {
            Image("ScaleDeviceTabIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(1)
        } else {
            Image(systemName: tab.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.monochrome)
        }
    }
}
