import SwiftUI

struct PrivacyPolicyView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                policyHeader

                SoftCard {
                    VStack(alignment: .leading, spacing: 16) {
                        AppLocalizedText("小组件会在本机与主应用共享成员名称、设备名称和趋势记录的加密副本，用于显示趋势。移除小组件不会删除主应用中的记录；删除记录后，小组件会在系统刷新时更新。")
                        ForEach(Array(store.appLanguage.text(.privacyPolicyBody).components(separatedBy: "\n").filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, paragraph in
                            Text((try? AttributedString(markdown: paragraph, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(paragraph))
                                .accessibilityAddTraits(paragraph.hasPrefix("#") || (paragraph.hasPrefix("**") && !paragraph.contains("\n")) ? .isHeader : [])
                        }
                    }
                        .font(.subheadline)
                        .foregroundStyle(AppColor.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.privacyPolicy))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }

    private var policyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(width: 48, height: 48)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)

            Text(store.appLanguage.text(.privacyPolicy))
                .font(.title2.bold())
                .foregroundStyle(AppColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text(store.appLanguage.text(.privacyPolicySummary))
                .font(.subheadline)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(4)

            Text(store.appLanguage.text(.privacyPolicyRevision))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

}
