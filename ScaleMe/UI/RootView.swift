import SwiftUI

struct RootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(onMeasure: { selection = 1 })
                .tabItem { Label("概览", systemImage: "circle.grid.2x2.fill") }
                .tag(0)
            MeasureView()
                .tabItem { Label("测量", systemImage: "dot.radiowaves.left.and.right") }
                .tag(1)
            HistoryView()
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }
                .tag(2)
            DevicesView()
                .tabItem { Label("设备", systemImage: "scalemass.fill") }
                .tag(3)
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .tint(AppColor.mint)
    }
}
