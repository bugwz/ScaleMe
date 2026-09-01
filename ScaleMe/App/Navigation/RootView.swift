import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var selection = RootTab.home
    @State private var navigationStore = RootNavigationControllerStore()

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(
                onMeasure: { profileID in
                    store.selectDisplayProfile(profileID)
                    selection = .measure
                },
                onShowTrends: { selection = .trends }
            )
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .home) }
            .tabItem { Label(RootTab.home.title(in: store.appLanguage), systemImage: RootTab.home.systemImage) }
            .tag(RootTab.home)

            MeasureView()
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .measure) }
            .tabItem { Label(RootTab.measure.title(in: store.appLanguage), systemImage: RootTab.measure.systemImage) }
            .tag(RootTab.measure)

            HistoryView()
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .trends) }
            .tabItem { Label(RootTab.trends.title(in: store.appLanguage), systemImage: RootTab.trends.systemImage) }
            .tag(RootTab.trends)

            DevicesView()
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .devices) }
            .tabItem { Label(RootTab.devices.title(in: store.appLanguage), image: "ScaleDeviceTabIcon") }
            .tag(RootTab.devices)

            ProfileView()
            .onRootNavigationControllerResolved { navigationStore.register($0, for: .settings) }
            .tabItem { Label(RootTab.settings.title(in: store.appLanguage), systemImage: RootTab.settings.systemImage) }
            .tag(RootTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .background(
            AppPageBackground(avatar: store.displaySelectedProfile.avatar)
                .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppBottomNavigation(
                selection: $selection,
                language: store.appLanguage,
                onDoubleTap: resetTabToRoot
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(AppColor.mint)
    }

    private func resetTabToRoot(_ tab: RootTab) {
        navigationStore.popToRoot(for: tab)
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
