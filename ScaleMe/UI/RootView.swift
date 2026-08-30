import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var selection = RootTab.home

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(
                onMeasure: { profileID in
                    store.selectDisplayProfile(profileID)
                    selection = .measure
                },
                onShowTrends: { selection = .trends }
            )
            .tabItem { Label(RootTab.home.title, systemImage: RootTab.home.systemImage) }
            .tag(RootTab.home)

            MeasureView()
                .tabItem { Label(RootTab.measure.title, systemImage: RootTab.measure.systemImage) }
                .tag(RootTab.measure)

            HistoryView()
                .tabItem { Label(RootTab.trends.title, systemImage: RootTab.trends.systemImage) }
                .tag(RootTab.trends)

            DevicesView()
                .tabItem { Label(RootTab.devices.title, image: "ScaleDeviceTabIcon") }
                .tag(RootTab.devices)

            ProfileView()
                .tabItem { Label(RootTab.settings.title, systemImage: RootTab.settings.systemImage) }
                .tag(RootTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppBottomNavigation(selection: $selection)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .tint(AppColor.mint)
    }
}

private enum RootTab: Int, CaseIterable, Identifiable {
    case home
    case measure
    case trends
    case devices
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "首页"
        case .measure: "测量"
        case .trends: "趋势"
        case .devices: "设备"
        case .settings: "设置"
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

private struct AppBottomNavigation: View {
    @Binding var selection: RootTab
    @Namespace private var selectionHighlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .frame(height: 72)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            AppColor.paleMint.opacity(0.96),
                            AppColor.sky.opacity(0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColor.mint.opacity(0.12))
                .allowsHitTesting(false)
        }
        .shadow(color: AppColor.mint.opacity(0.13), radius: 18, y: 8)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            LinearGradient(
                colors: [Color.clear, AppColor.canvas.opacity(0.98)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: RootTab) -> some View {
        let isSelected = selection == tab

        return Button {
            KeyboardFocus.dismiss()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                tabIcon(tab)
                    .frame(width: 23, height: 23)

                Text(tab.title)
                    .font(.caption2.weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppColor.ink : AppColor.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.94),
                                    AppColor.mint.opacity(0.14),
                                    AppColor.sky.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppColor.mint.opacity(0.14))
                        }
                        .shadow(color: AppColor.mint.opacity(0.11), radius: 7, y: 3)
                        .matchedGeometryEffect(id: "selected-tab", in: selectionHighlight)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "当前页面" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
