import SwiftUI

struct MetricInformationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    let kind: DashboardMetricKind
    let measurement: BodyMeasurement?
    let profile: UserProfile

    private var value: Double? {
        measurement.flatMap { kind.value(in: $0, profile: profile) }.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SoftCard {
                        VStack(alignment: .leading, spacing: 24) {
                            Label {
                                AppLocalizedText(kind.title)
                            } icon: {
                                HealthMetricIcon(asset: kind.icon, size: 22)
                            }
                            .font(.headline).foregroundStyle(kind.themeColor)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(value.map { $0.formatted(2) } ?? "--")
                                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                                    .minimumScaleFactor(0.6).lineLimit(1)
                                Text(language.text(kind.unit)).font(.subheadline)
                                    .foregroundStyle(AppColor.secondary)
                            }
                            let bands = kind.referenceBands(in: measurement, profile: profile)
                            if !bands.isEmpty {
                                MetricRangeGraphic(bands: bands, value: value,
                                    assessment: kind.assessment(in: measurement, profile: profile), unit: kind.unit)
                            } else if kind.assessment(in: measurement, profile: profile) != .noReference {
                                Label(language.text(kind.assessment(in: measurement, profile: profile).rawValue),
                                      systemImage: "info.circle")
                                    .font(.subheadline).foregroundStyle(AppColor.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    SettingsPanel(title: "数据说明", icon: "info.circle") {
                        AppLocalizedText(explanation)
                    }
                }
                .padding(18)
            }
            .pageBackground()
            .navigationTitle(language.text(kind.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.tint(AppColor.mint)
                }
            }
        }
    }

    private var explanation: String {
        switch kind {
        case .fatFreeMassKG: "去脂体重采用成人 FFMI 低值参考：男性 17、女性 15 kg/m²，乘以身高平方换算质量。未偏低不代表营养正常。"
        case .bmi: "BMI 是体重与身高平方的比值，用于描述体重相对身高的水平，不能直接区分脂肪和肌肉。"
        case .bodyFatPercent, .fatMassKG: "体脂率是脂肪占体重的比例；脂肪量是对应的质量。质量范围随体重变化，状态按同次体脂率判断。"
        case .muscleMassKG, .musclePercent: "肌肉采用 Withings 的 20–79 岁年龄与性别参考范围；质量区间按体重换算。偏高不代表更健康。"
        case .waterPercent, .waterMassKG: "身体水分是水分占体重的比例；水分量是对应的质量。质量范围随体重变化，状态按同次水分率判断。"
        case .boneMassKG, .bonePercent: "骨量参考 Withings：男性占体重 3%–5%，女性 2.5%–4%。本应用仅用于成人；不是骨密度分级。"
        case .visceralFat: "内脏脂肪反映腹腔内脂肪相关水平。这里的数值是指数，不是质量或百分比；不同算法的范围不能直接通用。"
        case .basalMetabolismKCal: "基础代谢描述静息状态下维持基本生命活动的每日能量需求，不是全天总消耗。它受年龄、性别及体型影响，没有统一的高低范围。"
        }
    }

}

private struct MetricRangeGraphic: View {
    @Environment(\.appLanguage) private var language
    let bands: [MetricReferenceBand]
    let value: Double?
    let assessment: MetricAssessment
    let unit: String

    private func color(_ status: MetricAssessment) -> Color {
        switch status {
        case .normal: AppColor.mint
        case .low: AppColor.sky
        case .severelyLow: AppColor.rose
        case .high, .overweight, .overweightRisk: AppColor.apricot
        case .veryHigh, .obesity: AppColor.rose
        default: AppColor.secondary
        }
    }

    // Each category has equal visual width. Position within it follows its numeric range.
    private var marker: CGFloat? {
        guard let value, let index = bands.firstIndex(where: { $0.status == assessment }) else { return nil }
        let band = bands[index]
        let neighboringWidth = bands.compactMap { item -> Double? in
            guard let lower = item.lower, let upper = item.upper else { return nil }
            return upper - lower
        }.first ?? 1
        let lower = band.lower ?? max(0, (band.upper ?? 1) - neighboringWidth)
        let upper = band.upper ?? (lower + neighboringWidth)
        let fraction = min(1, max(0, (value - lower) / max(upper - lower, 0.001)))
        return (CGFloat(index) + CGFloat(fraction)) / CGFloat(bands.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GeometryReader { geometry in
                VStack(spacing: 5) {
                    ZStack(alignment: .leading) {
                        Color.clear
                        if let marker {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(color(assessment))
                                .offset(x: min(max(0, geometry.size.width * marker - 6), geometry.size.width - 12))
                        }
                    }.frame(height: 14)
                    HStack(spacing: 4) {
                        ForEach(bands.indices, id: \.self) { index in
                            Capsule().fill(color(bands[index].status).opacity(bands[index].status == assessment ? 1 : 0.38))
                                .frame(maxWidth: .infinity)
                        }
                    }.frame(height: 10)
                }
            }
            .frame(height: 29)
            .accessibilityHidden(true)

            ForEach(bands.indices, id: \.self) { index in
                let band = bands[index]
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        rangeLabel(band)
                        Spacer(minLength: 8)
                        Text(rangeText(band)).monospacedDigit().fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        rangeLabel(band)
                        Text(rangeText(band)).monospacedDigit()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(band.status == assessment ? AppColor.ink : AppColor.secondary)
                .padding(12)
                .background(color(band.status).opacity(band.status == assessment ? 0.12 : 0.04),
                            in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func rangeLabel(_ band: MetricReferenceBand) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color(band.status)).frame(width: 7, height: 7)
            AppLocalizedText(band.status.rawValue)
            if band.status == assessment {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(color(band.status))
            }
        }
    }

    private func rangeText(_ band: MetricReferenceBand) -> String {
        let suffix = language.text(unit)
        switch (band.lower, band.upper) {
        case (nil, let upper?):
            return language.format(band.includesUpper ? "%@ 及以下" : "低于 %@", "\(upper.formatted(2)) \(suffix)")
        case (let lower?, nil):
            return language.format(band.includesLower ? "%@ 及以上" : "高于 %@", "\(lower.formatted(2)) \(suffix)")
        case (let lower?, let upper?):
            return "\(lower.formatted(2))–\(upper.formatted(2)) \(suffix)"
        default: return "--"
        }
    }
}
