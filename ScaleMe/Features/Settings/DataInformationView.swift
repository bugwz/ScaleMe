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
                    informationText("测量记录可能来自已连接的蓝牙体重秤、手动录入，或在授权后从 Apple 健康导入；模拟模式只使用示例数据。手机本身不能测量体重或身体成分。")
                    Divider()
                    informationText("应用只保存设备实际提供或你输入的字段；缺少的身体成分不会补算或伪造。")
                }

                SettingsPanel(title: "计算方法", icon: "function") {
                    informationText("BMI＝体重（kg）÷身高（m）的平方；质量＝体重×比例，比例＝质量÷体重。缺少输入时不计算，结果依赖原始数据的准确性。")
                    Divider()
                    informationText("界面中的“计算值”表示结果由已保存的体重、身高或比例换算，不是体重秤直接提供。")
                }

                SettingsPanel(title: "身体成分估算", icon: "waveform.path.ecg") {
                    informationText("消费级体脂秤通常通过生物电阻抗和设备算法估算身体成分。水分、进食、运动、接触状态及不同设备算法都可能影响结果。")
                    Divider()
                    informationText("身体成分仅供趋势参考，不用于诊断或治疗。在作出医疗决定前，请咨询医生。")
                }

                SettingsPanel(title: "参考来源", icon: "books.vertical.fill") {
                    informationText("以下资料说明通用计算方法和测量局限；具体字段和值仍以体重秤实际提供的数据为准。")
                    Divider()
                    referenceLink(
                        "BMI 公式 · CDC",
                        destination: "https://www.cdc.gov/growth-chart-training/hcp/using-bmi/calculating-bmi.html"
                    )
                    Divider()
                    referenceLink(
                        "生物电阻抗 · NCBI",
                        destination: "https://www.ncbi.nlm.nih.gov/books/NBK233766/"
                    )
                    Divider()
                    referenceLink(
                        "水分影响 · PubMed",
                        destination: "https://pubmed.ncbi.nlm.nih.gov/32182203/"
                    )
                }
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

    private func informationText(_ key: String) -> some View {
        AppLocalizedText(key)
            .font(.subheadline)
            .foregroundStyle(AppColor.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func referenceLink(_ key: String, destination: String) -> some View {
        if let destinationURL = URL(string: destination) {
            Link(destination: destinationURL) {
                HStack(spacing: 10) {
                    AppLocalizedText(key)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .contentShape(Rectangle())
            }
        }
    }
}
