import SwiftUI

/// Every calculation entry has a stable identity and shares the health-metric order.
struct CalculationMethod: Identifiable {
    let metric: DashboardMetricKind?
    var id: String { metric?.rawValue ?? "restingEnergy" }
    static var all: [Self] { DashboardMetricKind.allCases.map { Self(metric: $0) } + [Self(metric: nil)] }
    var title: String { metric?.title ?? "静息能量消耗" }
    var icon: String { metric?.icon ?? "MetricMetabolism" }
    var color: Color { metric?.themeColor ?? AppColor.trendBasalMetabolism }

    var explanation: String {
        guard let metric else {
            return "按体重、身高、年龄和性别使用 Mifflin–St Jeor 公式，适用于 19–78 岁。"
        }
        switch metric {
        case .bmi: return "BMI＝体重（kg）÷身高（m）的平方。"
        case .bodyFatPercent: return "按年龄选择阻抗模型估算去脂体重，再换算体脂率，适用于 3.9–94 岁。应用对设备频率和电极路径的适配仍属实验性。"
        case .fatMassKG: return "脂肪量＝体重×体脂率÷100。"
        case .muscleMassKG, .musclePercent: return "成人肌肉量按去脂体重减去骨量估算，肌肉率按肌肉量占体重的比例计算。这里采用应用的无骨瘦体重代理规则。"
        case .waterMassKG, .waterPercent: return "水分量使用 Sun 模型或成人去脂体重的 0.732 比例估算，水分率按水分量占体重的比例计算。"
        case .boneMassKG, .bonePercent: return "成人骨量＝去脂体重×0.052；骨量占比＝骨量÷体重×100。0.052 为应用经验系数。"
        case .visceralFat: return "按成人体脂率和年龄计算应用经验指数，结果限制在 1–30。"
        case .fatFreeMassKG: return "去脂体重＝体重×（1−体脂率÷100）。"
        case .subcutaneousFatMassKG, .subcutaneousFatPercent, .proteinMassKG, .proteinPercent, .skeletalMuscleMassKG, .skeletalMusclePercent:
            return "同一成分的质量与比例按体重相互换算，需要已有其中一项数值。"
        case .basalMetabolismKCal: return "使用 Schofield 公式，按年龄和性别选择系数，由体重计算每日基础代谢。"
        }
    }

    // Scientific notation is language-independent; the symbol legend is localized.
    var formulas: [String] {
        guard let metric else { return ["REE = 10W + 6.25H − 5A + 5 (♂)", "REE = 10W + 6.25H − 5A − 161 (♀)"] }
        switch metric {
        case .bmi: return ["BMI = W / (H / 100)²"]
        case .bodyFatPercent: return [
            "F = 100 × (1 − L / W)",
            "Schaefer · 3.9 ≤ A < 4.9", "L = 0.65H²/Z + 0.68A + 0.15",
            "Tyrrell · 4.9 ≤ A ≤ 10.9", "L = 0.31H²/Z + 0.17H + 0.11W + 0.942(S + 1) − 14.96",
            "Schaefer · 10.9 < A < 12", "L = 0.65H²/Z + 0.68A + 0.15",
            "Sun · 12 ≤ A < 18", "L = −10.68 + 0.65H²/Z + 0.26W + 0.02Z (♂)", "L = −9.53 + 0.69H²/Z + 0.17W + 0.02Z (♀)",
            "Wu · 18 ≤ A ≤ 75", "L = 13.055 + 0.204W + 0.394H²/Z − 0.136A + 8.125S",
            "Sun · 75 < A ≤ 94", "L = −10.68 + 0.65H²/Z + 0.26W + 0.02Z (♂)", "L = −9.53 + 0.69H²/Z + 0.17W + 0.02Z (♀)"]
        case .fatMassKG: return ["M = W × F / 100"]
        case .muscleMassKG: return ["M = L − B", "L = W × (1 − F / 100)"]
        case .musclePercent: return ["P = 100 × M / W", "M = L − B", "L = W × (1 − F / 100)"]
        case .boneMassKG: return ["B = 0.052L", "L = W × (1 − F / 100)"]
        case .bonePercent: return ["P = 100 × B / W", "B = 0.052L", "L = W × (1 − F / 100)"]
        case .waterMassKG, .waterPercent: return ["Sun · 12 ≤ A < 18", "Sun · 75 < A ≤ 94", "T = 1.203 + 0.449H²/Z + 0.176W (♂)", "T = 3.747 + 0.450H²/Z + 0.113W (♀)", "T = 0.732L", "L = W × (1 − F / 100)", "P = 100 × T / W"]
        case .visceralFat: return ["V = min(30, max(1, 0.45(F − 12) + 0.03A))"]
        case .fatFreeMassKG: return ["L = W × (1 − F / 100)", "FFMI = L / (H / 100)²"]
        case .subcutaneousFatMassKG, .proteinMassKG, .skeletalMuscleMassKG: return ["M = W × P / 100"]
        case .subcutaneousFatPercent, .proteinPercent, .skeletalMusclePercent: return ["P = 100 × M / W"]
        case .basalMetabolismKCal: return [
            "♂ · 0 ≤ A < 3: BMR = 59.512W − 30.4", "♂ · 3 ≤ A < 10: BMR = 22.706W + 504.3", "♂ · 10 ≤ A < 18: BMR = 17.686W + 658.2", "♂ · 18 ≤ A < 30: BMR = 15.057W + 692.2", "♂ · 30 ≤ A < 60: BMR = 11.472W + 873.1", "♂ · A ≥ 60: BMR = 11.711W + 587.7",
            "♀ · 0 ≤ A < 3: BMR = 58.317W − 31.1", "♀ · 3 ≤ A < 10: BMR = 20.315W + 485.9", "♀ · 10 ≤ A < 18: BMR = 13.384W + 692.6", "♀ · 18 ≤ A < 30: BMR = 14.818W + 486.6", "♀ · 30 ≤ A < 60: BMR = 8.126W + 845.6", "♀ · A ≥ 60: BMR = 9.082W + 658.5"]
        }
    }

    struct Symbol: Identifiable {
        let id: String
        let title: String
        let unit: String
    }

    var symbols: [Symbol] {
        let massTitle: String
        let percentTitle: String
        switch metric {
        case .muscleMassKG, .musclePercent: (massTitle, percentTitle) = ("肌肉量", "肌肉率")
        case .waterMassKG, .waterPercent: (massTitle, percentTitle) = ("体水分量", "体水分率")
        case .boneMassKG, .bonePercent: (massTitle, percentTitle) = ("骨量", "骨量占比")
        case .subcutaneousFatMassKG, .subcutaneousFatPercent: (massTitle, percentTitle) = ("皮下脂肪量", "皮下脂肪率")
        case .proteinMassKG, .proteinPercent: (massTitle, percentTitle) = ("蛋白质含量", "蛋白质占比")
        case .skeletalMuscleMassKG, .skeletalMusclePercent: (massTitle, percentTitle) = ("骨骼肌量", "骨骼肌率")
        default: (massTitle, percentTitle) = ("脂肪量", "体脂率")
        }
        let definitions: [Symbol] = [
            .init(id: "BMI", title: "BMI", unit: "kg/m²"),
            .init(id: "W", title: "体重", unit: "kg"),
            .init(id: "H", title: "身高", unit: "cm"),
            .init(id: "A", title: metric == .bodyFatPercent || metric == .waterMassKG || metric == .waterPercent ? "测量时年龄（含小数）" : "测量时周岁", unit: ""),
            .init(id: "Z", title: "阻抗通道 1", unit: "Ω"),
            .init(id: "S", title: "性别编码：男 1，女 0", unit: ""),
            .init(id: "♂ / ♀", title: "男性 / 女性", unit: ""),
            .init(id: "L", title: "去脂体重", unit: "kg"),
            .init(id: "B", title: "骨量", unit: "kg"),
            .init(id: "T", title: "体水分量", unit: "kg"),
            .init(id: "M", title: massTitle, unit: "kg"),
            .init(id: "F", title: "体脂率", unit: "%"),
            .init(id: "P", title: percentTitle, unit: "%"),
            .init(id: "V", title: "内脏脂肪等级", unit: ""),
            .init(id: "BMR", title: "基础代谢", unit: "kcal/d"),
            .init(id: "REE", title: "静息能量消耗", unit: "kcal/d"),
            .init(id: "FFMI", title: "去脂体重指数", unit: "kg/m²")
        ]
        let tokens = Set(formulas.joined(separator: " ").components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        return definitions.filter { $0.id == "♂ / ♀" ? formulas.contains(where: { $0.contains("♂") }) : tokens.contains($0.id) }
    }

    var assessmentText: String? {
        switch metric {
        case .muscleMassKG, .musclePercent: "肌肉采用 Withings 的 20–79 岁年龄与性别参考范围；质量区间按体重换算。偏高不代表更健康。"
        case .boneMassKG, .bonePercent: "骨量参考 Withings：男性占体重 3%–5%，女性 2.5%–4%。本应用仅用于成人；不是骨密度分级。"
        case .proteinMassKG, .proteinPercent: "蛋白质参考 PHICOMM S7 的 16%–20% 区间，本应用仅用于成人；不代表饮食摄入或血液蛋白水平。"
        case .fatFreeMassKG: "去脂体重采用成人 FFMI 低值参考：男性 17、女性 15 kg/m²，乘以身高平方换算质量。未偏低不代表营养正常。"
        case .skeletalMuscleMassKG, .skeletalMusclePercent: "骨骼肌是参与身体运动的肌肉，与总肌肉量不同。采用 OMRON 的 18–80 岁性别和年龄参考表，按一位小数分级；其他年龄保留数值供参考。偏高不等同于优，也不是诊断结论。"
        default: nil
        }
    }

    var references: [CalculationReference] {
        switch metric {
        case .bmi: [.bmiFormula, .childBMI, .youthBMI, .adultBMI]
        case .bodyFatPercent: [.schaefer, .tyrrell, .sun, .wu, .fatTable, .fatStudy, .biaGuide, .bia]
        case .fatMassKG: [.fatTable, .fatStudy, .wu, .biaGuide]
        case .muscleMassKG, .musclePercent: [.withings, .muscleConsensus]
        case .boneMassKG, .bonePercent: [.withings, .boneDensity]
        case .waterMassKG, .waterPercent: [.sun, .hydration, .water, .waterEffects]
        case .visceralFat: [.biaGuide]
        case .fatFreeMassKG: [.ffmi, .schaefer, .tyrrell, .sun, .wu]
        case .subcutaneousFatMassKG, .subcutaneousFatPercent: [.biaGuide, .bia]
        case .proteinMassKG, .proteinPercent: [.protein]
        case .skeletalMuscleMassKG, .skeletalMusclePercent: [.skeletal, .muscleConsensus]
        case .basalMetabolismKCal: [.basal]
        case nil: [.resting]
        }
    }
}

struct CalculationReference: Identifiable {
    let title: String
    let destination: String
    var id: String { destination }
    static let withings = Self(title: "肌肉与骨量参考 · Withings", destination: "https://support.withings.com/hc/en-us/articles/218500778-Body-What-are-the-normal-ranges-for-body-composition")
    static let protein = Self(title: "蛋白质参考 · PHICOMM S7 说明书镜像", destination: "https://manualsplanet.com/manualPdf/phicomm-s7-smart-scale.pdf")
    static let ffmi = Self(title: "去脂体重低值参考 · ESPEN", destination: "https://www.clinicalnutritionjournal.com/article/S0261-5614%2815%2900075-8/fulltext")
    static let childBMI = Self(title: "儿童 BMI 标准 · WHO", destination: "https://www.who.int/toolkits/child-growth-standards/standards/body-mass-index-for-age-bmi-for-age")
    static let youthBMI = Self(title: "青少年 BMI 参考 · WHO", destination: "https://www.who.int/tools/growth-reference-data-for-5to19-years/indicators/bmi-for-age")
    static let adultBMI = Self(title: "BMI 分级 · WHO", destination: "https://www.who.int/data/nutrition/nlis/info/malnutrition-in-women")
    static let fatTable = Self(title: "体脂参考表 · OMRON", destination: "https://www.omron-healthcare.com/storage/im-hbf-508-e-en-06-02-2017.pdf")
    static let fatStudy = Self(title: "体脂参考研究 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/10966886/")
    static let water = Self(title: "水分参考范围 · TANITA", destination: "https://tanita.co.uk/understanding-your-measurements")
    static let skeletal = Self(title: "骨骼肌参考表 · OMRON", destination: "https://www.omron-healthcare.co.uk/storage/files/manuals/hbf-222t-ebk/3135909-5g_web_im-hbf-222t-e-en-09-06-2022.pdf")
    static let muscleConsensus = Self(title: "肌肉评估共识 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/30312372/")
    static let boneDensity = Self(title: "骨密度说明 · NIH", destination: "https://www.niams.nih.gov/health-topics/bone-mineral-density-tests-what-numbers-mean")
    static let hydration = Self(title: "去脂体重水合研究 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/10232621/")
    static let basal = Self(title: "分年龄基础代谢 · FAO", destination: "https://www.fao.org/4/y5686e/y5686e07.htm")
    static let schaefer = Self(title: "儿童阻抗研究 · Schaefer", destination: "https://pubmed.ncbi.nlm.nih.gov/8065848/")
    static let tyrrell = Self(title: "儿童足间阻抗研究 · Tyrrell", destination: "https://www.nature.com/articles/0801531")
    static let sun = Self(title: "宽年龄阻抗研究 · Sun", destination: "https://pubmed.ncbi.nlm.nih.gov/12540391/")
    static let wu = Self(title: "足间生物电阻抗研究 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/25986468/")
    static let resting = Self(title: "成人静息能量研究 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/2305711/")
    static let biaGuide = Self(title: "生物电阻抗应用指南 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/15380917/")
    static let bmiFormula = Self(title: "BMI 公式 · CDC", destination: "https://www.cdc.gov/growth-chart-training/hcp/using-bmi/calculating-bmi.html")
    static let bia = Self(title: "生物电阻抗 · NCBI", destination: "https://www.ncbi.nlm.nih.gov/books/NBK233766/")
    static let waterEffects = Self(title: "水分影响 · PubMed", destination: "https://pubmed.ncbi.nlm.nih.gov/32182203/")
}

struct CalculationMethodView: View {
    @EnvironmentObject private var store: MeasurementStore
    let method: CalculationMethod

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SoftCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            HealthMetricIcon(asset: method.icon, size: 22)
                            AppLocalizedText(method.title).font(.headline)
                        }
                        .foregroundStyle(method.color)
                        CalculationText(method.explanation)
                        AppLocalizedText("计算方法").font(.headline)
                        if method.metric == .waterMassKG || method.metric == .waterPercent {
                            CalculationText("先使用 Sun 分支；0.732 仅用于有去脂体重、已满 18 岁且未选中 Sun 分支的记录。Sun 结果无效时不改用固定比例。水分量按 1 L ≈ 1 kg 换算。")
                        }
                        ForEach(Array(method.formulas.enumerated()), id: \.offset) { _, formula in
                            Text(verbatim: formula)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(AppColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        ForEach(method.symbols) { symbol in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(verbatim: symbol.id)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .frame(minWidth: 50, alignment: .leading)
                                AppLocalizedText(symbol.title)
                                if !symbol.unit.isEmpty { Text(verbatim: "(\(symbol.unit))") }
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppColor.secondary)
                        }
                        if let text = method.assessmentText {
                            Divider()
                            AppLocalizedText("指标状态").font(.headline)
                            CalculationText(text)
                        }
                        if [.boneMassKG, .bonePercent, .proteinMassKG, .proteinPercent].contains(method.metric) {
                            CalculationText("分级采用文献或厂商参考，不是统一医学标准。骨量和蛋白质原表未分年龄，成人限制由本应用设定，不代表已验证所有成人年龄。")
                        }
                        CalculationText("参考资料包含计算依据、指标定义或分级参考；不代表所有应用经验系数均得到文献验证。")
                    }
                }
                SettingsPanel(title: "参考资料", icon: "books.vertical.fill") {
                    VStack(spacing: 0) {
                        ForEach(Array(method.references.enumerated()), id: \.element.id) { index, reference in
                            if index > 0 { Divider() }
                            if let url = URL(string: reference.destination) {
                                Link(destination: url) {
                                    HStack(spacing: 10) {
                                        AppLocalizedText(reference.title)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 8)
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption.bold())
                                            .accessibilityHidden(true)
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.mint)
                                    .frame(minHeight: 44)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(method.title))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }
}
