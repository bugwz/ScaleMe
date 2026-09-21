import SwiftUI

struct HealthInformationView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            SettingsPanel(title: "健康说明与来源", icon: "heart.text.clipboard") {
                HealthSafetyNotice(
                    showsCalculationMethod: true,
                    showsScaleRequirement: true
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text("健康说明与来源"))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }
}
