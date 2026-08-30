import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MeasurementStore
    let onMeasure: () -> Void
    let onShowTrends: () -> Void

    private var latest: BodyMeasurement { store.latest ?? MeasurementStore.demoMeasurements[0] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    brandTitle
                    memberPager
                    if store.isShowingDemoData {
                        Label("模拟数据模式已开启，真实资料和记录保持不变", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if latest.hasBodyComposition {
                        metricsGrid
                    }
                    insightCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var brandTitle: some View {
        HStack(spacing: 11) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("观我")
                    .font(.title.bold())
                    .foregroundStyle(AppColor.ink)
                Text("ScaleMe")
                    .font(.caption2)
                    .foregroundStyle(AppColor.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("观我 ScaleMe")
    }

    private var memberPager: some View {
        VStack(spacing: 10) {
            TabView(
                selection: Binding(
                    get: { store.displaySelectedProfileID },
                    set: { store.selectDisplayProfile($0) }
                )
            ) {
                ForEach(store.displayProfiles) { profile in
                    memberCard(for: profile)
                        .tag(profile.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 410)

            if store.displayProfiles.count > 1 {
                HStack(spacing: 7) {
                    ForEach(store.displayProfiles) { profile in
                        let theme = memberCardTheme(for: profile.avatar)
                        Capsule()
                            .fill(
                                profile.id == store.displaySelectedProfileID
                                    ? theme.primary
                                    : theme.primary.opacity(0.22)
                            )
                            .frame(width: profile.id == store.displaySelectedProfileID ? 20 : 7, height: 7)
                            .animation(.easeOut(duration: 0.2), value: store.displaySelectedProfileID)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private func memberCard(for profile: UserProfile) -> some View {
        let measurements = store.displayMeasurements(for: profile.id)
        let current = measurements.first ?? MeasurementStore.demoMeasurements[0]
        let theme = memberCardTheme(for: profile.avatar)

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            theme.primary.opacity(0.12),
                            theme.secondary.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(alignment: .bottom, spacing: -12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(profile.name)
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.ink)
                    Text("\(profile.relation) · \(profile.age) 岁")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)

                    Text("最近体重")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .padding(.top, 18)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(store.unit.value(fromKilograms: current.weightKG).formatted(2))
                            .font(.system(size: 46, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(store.unit.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.ink)

                    VStack(alignment: .leading, spacing: 7) {
                        Label("BMI \(current.bmi(heightCM: profile.heightCM).formatted(2))", systemImage: "figure.stand")
                        if let fat = current.bodyFatPercent {
                            Label("体脂 \(fat.formatted(2))%", systemImage: "drop.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(1)

                    compactTrend(
                        measurements: measurements,
                        theme: theme
                    )
                    .padding(.top, 12)

                    Button(action: onMeasure) {
                        Label("开始测量", systemImage: "wave.3.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(theme.primary, in: Capsule())
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -78)

                MemberAvatarView(
                    avatar: profile.avatar,
                    width: 202,
                    height: 380,
                    showsBackdrop: false
                )
                .offset(x: 14)
                .accessibilityHidden(true)
            }
            .frame(height: 362)
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(theme.primary.opacity(0.10)))
        .shadow(color: theme.primary.opacity(0.12), radius: 18, y: 8)
        .padding(.vertical, 4)
    }

    private func compactTrend(
        measurements: [BodyMeasurement],
        theme: MemberCardTheme
    ) -> some View {
        let recentMeasurements = lastWeekMeasurements(from: measurements)
        let weightDomain = compactWeightDomain(for: recentMeasurements)

        return Button(action: onShowTrends) {
            Chart(recentMeasurements) { item in
                LineMark(
                    x: .value("日期", item.date),
                    y: .value("体重", store.unit.value(fromKilograms: item.weightKG))
                )
                .foregroundStyle(theme.primary)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: weightDomain)
            .frame(height: 34)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看近期趋势")
        .accessibilityHint("切换到趋势页面")
    }

    private func lastWeekMeasurements(from measurements: [BodyMeasurement]) -> [BodyMeasurement] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return measurements
            .filter { $0.date >= start && $0.date <= .now }
            .sorted { $0.date < $1.date }
    }

    private func compactWeightDomain(
        for measurements: [BodyMeasurement]
    ) -> ClosedRange<Double> {
        let values = measurements.map { store.unit.value(fromKilograms: $0.weightKG) }
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }

        let spread = maximum - minimum
        let minimumPadding = store.unit.value(fromKilograms: 0.05)
        let padding = spread > 0
            ? max(spread * 0.16, minimumPadding)
            : max(abs(minimum) * 0.002, minimumPadding)
        return (minimum - padding)...(maximum + padding)
    }

    private func memberCardTheme(for avatar: MemberAvatar) -> MemberCardTheme {
        switch avatar {
        case .child, .childDaughter:
            MemberCardTheme(primary: AppColor.apricot, secondary: AppColor.rose)
        case .youth, .teenDaughter:
            MemberCardTheme(primary: AppColor.sky, secondary: AppColor.violet)
        case .adult, .father:
            MemberCardTheme(primary: AppColor.mint, secondary: AppColor.sky)
        case .senior, .paternalGrandfather:
            MemberCardTheme(primary: AppColor.violet, secondary: AppColor.rose)
        case .maternalGrandfather:
            MemberCardTheme(primary: AppColor.sky, secondary: AppColor.mint)
        case .maternalGrandmother:
            MemberCardTheme(primary: AppColor.rose, secondary: AppColor.mint)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            if let value = latest.bodyFatPercent {
                MetricTile(title: "体脂率", value: value.formatted(2), unit: "%", source: sourceName(for: latest), icon: "drop.fill", color: AppColor.apricot)
            }
            if let value = latest.muscleMassKG {
                MetricTile(title: "肌肉量", value: value.formatted(2), unit: "kg", source: sourceName(for: latest), icon: "figure.strengthtraining.traditional", color: AppColor.violet)
            }
            if let value = latest.waterPercent {
                MetricTile(title: "身体水分", value: value.formatted(2), unit: "%", source: sourceName(for: latest), icon: "water.waves", color: AppColor.sky)
            }
            if let value = latest.basalMetabolismKCal {
                MetricTile(title: "基础代谢", value: value.formatted(2), unit: "kcal", source: sourceName(for: latest), icon: "flame.fill", color: AppColor.rose)
            }
        }
    }

    private var insightCard: some View {
        SoftCard {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: "lightbulb.max.fill").foregroundStyle(AppColor.mint).font(.title2)
                VStack(alignment: .leading, spacing: 7) {
                    Text("观我提示").font(.headline)
                    Text("尽量在每天相近时间、相同状态下称重。短期波动常来自水分，连续趋势比单次数字更值得关注。")
                        .font(.subheadline).foregroundStyle(AppColor.secondary).lineSpacing(3)
                }
            }
        }
    }

    private func sourceName(for measurement: BodyMeasurement) -> String {
        if let deviceID = measurement.deviceID,
           let scale = store.displayPairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? measurement.source.rawValue
    }
}

private struct MemberCardTheme {
    let primary: Color
    let secondary: Color
}

private struct MetricTile: View {
    let title: String, value: String, unit: String, source: String, icon: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: icon).foregroundStyle(color); Spacer(); StatusPill(text: "标准") }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title2.bold()).foregroundStyle(AppColor.ink)
                Text(unit).font(.caption).foregroundStyle(AppColor.secondary)
            }
            Text(title).font(.caption).foregroundStyle(AppColor.secondary)
            Text(source).font(.caption2).foregroundStyle(AppColor.secondary).lineLimit(1)
        }
        .padding(17).background(.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
