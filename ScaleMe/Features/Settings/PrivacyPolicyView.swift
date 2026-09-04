import SwiftUI

struct PrivacyPolicyView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                policyHeader

                SoftCard {
                    Text(policyBody)
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

    private var policyBody: AttributedString {
        let source = store.appLanguage.text(.privacyPolicyBody)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}
