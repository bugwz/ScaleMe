import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                brandHeader

                SettingsPanel(title: "关于观我", icon: "sparkles") {
                    Text("观我是一款注重隐私的原生 iOS 体重与身体趋势应用，帮助你连接蓝牙体脂秤、管理个人记录，并从长期变化中理解身体的方向。")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(4)
                }

                SettingsPanel(title: "我们的原则", icon: "leaf.fill") {
                    aboutRow(
                        icon: "lock.shield.fill",
                        title: "本地优先",
                        detail: "不开启同步时，成员资料和测量数据只保存在本机。"
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

                SettingsPanel(title: "重要说明", icon: "info.circle.fill") {
                    Text("消费级体脂秤的身体成分结果是估算值，会受到水分、进食、运动和接触状态影响，仅用于日常趋势参考，不构成医疗诊断、治疗建议或临床结论。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineSpacing(4)
                }
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
        HStack(alignment: .top, spacing: 12) {
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
