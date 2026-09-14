import SwiftUI

struct HealthSafetyNotice: View {
    var showsCalculationMethod = false
    var showsScaleRequirement = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                AppLocalizedText("身体成分仅供趋势参考，不用于诊断或治疗。在作出医疗决定前，请咨询医生。")
            } icon: {
                Image(systemName: "info.circle")
            }
            if showsScaleRequirement {
                AppLocalizedText("测量需要连接兼容的蓝牙体重秤。手机本身不能测量体重或身体成分。")
            }
            if showsCalculationMethod {
                AppLocalizedText("BMI＝体重（kg）÷身高（m）的平方；质量＝体重×比例，比例＝质量÷体重。蛋白质量为去脂质量减去水分量和骨量的残差估算，不能替代检测。缺少输入时不计算，结果依赖原始数据的准确性。")
            }
        }
        .font(.caption)
        .foregroundStyle(AppColor.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
