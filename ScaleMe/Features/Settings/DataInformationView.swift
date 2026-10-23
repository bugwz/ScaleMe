import SwiftUI

struct DataInformationLink: View {
    var body: some View {
        NavigationLink {
            DataInformationView()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .accessibilityHidden(true)
                AppLocalizedText("数据说明")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(AppColor.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct DataInformationView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPanel(title: "数据来源", icon: "externaldrive.connected.to.line.below") {
                    CalculationText("测量记录可能来自已连接的蓝牙体重秤、手动录入，或在授权后从 Apple 健康导入；模拟模式只使用示例数据。手机本身不能测量体重或身体成分。")
                }
                SettingsPanel(title: "计算方法", icon: "function") {
                    CalculationText("优先展示设备经通信协议解析的数据，以及手动录入或导入的原始值；同一成分的质量与比例可按体重换算。")
                    CalculationText("仍缺少的指标，仅在体脂秤提供有效主阻抗且满足年龄、资料条件时按应用规则补算。普通体重秤或无主阻抗时不补算身体成分；BMI 单独按体重和身高计算。")
                    CalculationText("测量保存时计算并保存指标，导出 JSON 包含计算结果。修改成员资料不会自动重算历史结果；估算不作为设备体脂率同步到 Apple 健康。")
                    ForEach(CalculationMethod.all) { method in
                        Divider()
                        NavigationLink {
                            CalculationMethodView(method: method)
                        } label: {
                            HStack(spacing: 12) {
                                HealthMetricIcon(asset: method.icon, size: 20)
                                    .foregroundStyle(method.color)
                                AppLocalizedText(method.title)
                                    .foregroundStyle(AppColor.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.secondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                CalculationText("身体成分仅供趋势参考，不用于诊断或治疗。在作出医疗决定前，请咨询医生。")
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text("数据说明"))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }
}

struct CalculationText: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View {
        AppLocalizedText(key)
            .font(.subheadline)
            .foregroundStyle(AppColor.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}
