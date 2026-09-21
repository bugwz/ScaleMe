import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                brandHeader

                SettingsPanel(title: "关于应用", icon: "info.circle.fill") {
                    Text("本应用是一款注重隐私的原生 iOS 体重与身体趋势应用，帮助你连接蓝牙体脂秤、管理个人记录，并从长期变化中理解身体的方向。")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(4)
                }

                SettingsPanel(title: "设计原则", icon: "checkmark.seal.fill") {
                    aboutRow(
                        icon: "lock.shield.fill",
                        title: "本地优先",
                        detail: "成员资料和测量数据默认保存在本机。"
                    )
                    Divider()
                    aboutRow(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "标准优先",
                        detail: "优先支持公开的蓝牙标准，并谨慎验证不同设备协议。"
                    )
                    Divider()
                    aboutRow(
                        icon: "chart.xyaxis.line",
                        title: "关注长期趋势",
                        detail: "减少对单次波动的焦虑，更清晰地观察持续变化。"
                    )
                }

                NavigationLink {
                    DataInformationView()
                } label: {
                    SettingsPanel(title: "数据说明", icon: "heart.text.clipboard") {
                        HStack(alignment: .center, spacing: 12) {
                            AppLocalizedText("查看数据来源、计算方法、使用边界和参考依据。")
                                .font(.caption)
                                .foregroundStyle(AppColor.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(AppColor.mint)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    SettingsPanel(title: store.appLanguage.text(.privacyPolicy), icon: "hand.raised.fill") {
                        HStack(alignment: .center, spacing: 12) {
                            Text(store.appLanguage.text(.privacyPolicyDetail))
                                .font(.caption)
                                .foregroundStyle(AppColor.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(AppColor.mint)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.about))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: AppColor.mint.opacity(0.16), radius: 18, y: 8)
                .accessibilityHidden(true)

            Text(store.appLanguage.text(.productName))
                .font(.title.bold())
                .foregroundStyle(AppColor.ink)

            Text(store.appLanguage.text(.tagline))
                .font(.subheadline)
                .foregroundStyle(AppColor.ink)
                .multilineTextAlignment(.center)

            Text(versionDescription)
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func aboutRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.mint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                AppLocalizedText(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                AppLocalizedText(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        return switch (version, build) {
        case let (.some(version), .some(build)):
            store.appLanguage.format("版本 %@（%@）", version, build)
        case let (.some(version), .none):
            store.appLanguage.format("版本 %@", version)
        default:
            store.appLanguage.text("版本信息暂不可用")
        }
    }
}
