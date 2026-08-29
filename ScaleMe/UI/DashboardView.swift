import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MeasurementStore
    let onMeasure: () -> Void
    @State private var showAdd = false
    @State private var selectedTrendDate: Date?

    private var latest: BodyMeasurement { store.latest ?? MeasurementStore.demoMeasurements[0] }
    private var previous: BodyMeasurement? { store.displayMeasurements.dropFirst().first }
    private var selectedTrend: BodyMeasurement? {
        guard let selectedTrendDate else { return nil }
        return store.displayMeasurements.prefix(12).min {
            abs($0.date.timeIntervalSince(selectedTrendDate)) < abs($1.date.timeIntervalSince(selectedTrendDate))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if store.isShowingDemoData {
                        Label("当前展示示例数据，首次测量后自动替换", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    trendCard
                    if latest.hasBodyComposition {
                        metricsGrid
                    }
                    insightCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdd) { ManualEntryView() }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [.white, AppColor.paleMint, AppColor.sky.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(AppColor.sky.opacity(0.16)).frame(width: 190).offset(x: 65, y: 80)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("观我").font(.headline)
                        Text("ScaleMe").font(.caption2).foregroundStyle(AppColor.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("观我 ScaleMe")
                HStack {
                    Text("今天的身体状态").font(.subheadline).foregroundStyle(AppColor.secondary)
                    Spacer()
                    StatusPill(text: "稳定", color: AppColor.mint)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.unit.value(fromKilograms: latest.weightKG).formatted(2))
                        .font(.system(size: 58, weight: .medium, design: .rounded))
                    Text(store.unit.rawValue).font(.title3)
                }
                .foregroundStyle(AppColor.ink)
                HStack(spacing: 16) {
                    Label("BMI \(latest.bmi(heightCM: store.profile.heightCM).formatted(2))", systemImage: "figure.stand")
                    if let fat = latest.bodyFatPercent { Label("体脂 \(fat.formatted(2))%", systemImage: "drop.fill") }
                }
                .font(.caption).foregroundStyle(AppColor.secondary)
                Label(sourceName(for: latest), systemImage: "scalemass")
                    .font(.caption2).foregroundStyle(AppColor.secondary)
                HStack(spacing: 14) {
                    Button(action: onMeasure) {
                        Label("开始测量", systemImage: "wave.3.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(AppColor.mint, in: Capsule())
                    }
                    Button("手动记录") { showAdd = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 295, alignment: .topLeading)
        }
    }

    private var trendCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("近期趋势").font(.title3.bold()).foregroundStyle(AppColor.ink)
                        if let previous {
                            let delta = latest.weightKG - previous.weightKG
                            Text("较上次 \(delta >= 0 ? "+" : "")\(store.unit.value(fromKilograms: delta).formatted(2)) \(store.unit.rawValue)")
                                .font(.caption).foregroundStyle(AppColor.secondary)
                        }
                    }
                    Spacer()
                    NavigationLink("全部") { HistoryView() }.font(.subheadline.weight(.semibold))
                }
                Chart(Array(store.displayMeasurements.prefix(12).reversed())) { item in
                    AreaMark(x: .value("日期", item.date), y: .value("体重", store.unit.value(fromKilograms: item.weightKG)))
                        .foregroundStyle(LinearGradient(colors: [AppColor.mint.opacity(0.26), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("日期", item.date), y: .value("体重", store.unit.value(fromKilograms: item.weightKG)))
                        .foregroundStyle(AppColor.mint).lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    if selectedTrend?.id == item.id {
                        RuleMark(x: .value("选中日期", item.date))
                            .foregroundStyle(AppColor.secondary.opacity(0.45))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(store.unit.value(fromKilograms: item.weightKG).formatted(2)) \(store.unit.rawValue)").font(.caption.bold())
                                    Text(item.date, format: .dateTime.month().day()).font(.caption2)
                                    Text(sourceName(for: item)).font(.caption2).foregroundStyle(AppColor.secondary)
                                }
                                .padding(7).background(.white, in: RoundedRectangle(cornerRadius: 7))
                            }
                        PointMark(x: .value("日期", item.date), y: .value("体重", store.unit.value(fromKilograms: item.weightKG)))
                            .foregroundStyle(AppColor.mint).symbolSize(60)
                    }
                }
                .chartXSelection(value: $selectedTrendDate)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.12))
                        AxisValueLabel(
                            format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
                        )
                    }
                }
                .frame(height: 145)
            }
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
           let scale = store.pairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? measurement.source.rawValue
    }
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

struct ManualEntryView: View {
    private enum InputField: Hashable {
        case weight
        case bodyFat
    }

    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var bodyFat = ""
    @FocusState private var focusedField: InputField?

    var body: some View {
        NavigationStack {
            Form {
                Section("测量结果") {
                    TextField("体重（kg）", text: $weight)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight)
                    TextField("体脂率（可选）", text: $bodyFat)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .bodyFat)
                }
                Section { Text("手动记录会保存在本机，不会伪装成蓝牙秤数据。") }.font(.caption)
            }
            .navigationTitle("添加记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let kg = Double(weight), (5...350).contains(kg) {
                            focusedField = nil
                            store.addManual(weightKG: kg, bodyFat: Double(bodyFat)); dismiss()
                        }
                    }.disabled(Double(weight) == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
        }
    }
}
