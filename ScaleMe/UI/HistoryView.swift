import Charts
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var range = TimeRange.month
    @State private var selectedDeviceID: UUID?
    @State private var selectedDate: Date?

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "周", month = "月", year = "年", all = "全部"
        var id: String { rawValue }
        var days: Int? { switch self { case .week: 7; case .month: 31; case .year: 365; case .all: nil } }
    }

    private var filtered: [BodyMeasurement] {
        var result = store.displayMeasurements
        if let days = range.days, let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) {
            result = result.filter { $0.date >= cutoff }
        }
        if let selectedDeviceID {
            result = result.filter { $0.deviceID == selectedDeviceID }
        }
        return result
    }

    private var selectedMeasurement: BodyMeasurement? {
        guard let selectedDate else { return nil }
        return filtered.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var chronologicalMeasurements: [BodyMeasurement] {
        Array(filtered.reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MainPageTitle(text: "趋势")
                    Picker("时间范围", selection: $range) {
                        ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    deviceFilter
                    chart
                    records
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: store.selectedProfileID) {
                selectedDate = nil
                selectedDeviceID = nil
            }
        }
    }

    private var deviceFilter: some View {
        HStack {
            Label("数据来源", systemImage: "scalemass")
                .font(.subheadline).foregroundStyle(AppColor.secondary)
            Spacer()
            Picker("设备", selection: $selectedDeviceID) {
                Text("全部设备").tag(UUID?.none)
                ForEach(store.pairedScales) { scale in
                    Text(scale.name).tag(Optional(scale.id))
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 4)
    }

    private var chart: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("体重变化").font(.headline)
                        Text(selectedDeviceID == nil ? "聚合展示所有已关联设备" : "仅展示所选设备")
                            .font(.caption).foregroundStyle(AppColor.secondary)
                    }
                    Spacer()
                    Text("\(filtered.count) 次").font(.caption).foregroundStyle(AppColor.secondary)
                }
                if let first = filtered.last, let last = filtered.first {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(store.unit.value(fromKilograms: last.weightKG - first.weightKG).formatted(2))
                            .font(.title.bold()).foregroundStyle(AppColor.ink)
                        Text(store.unit.rawValue).font(.caption).foregroundStyle(AppColor.secondary)
                    }
                }
                if filtered.isEmpty {
                    ContentUnavailableView("暂无记录", systemImage: "chart.xyaxis.line")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Chart(chronologicalMeasurements) { item in
                        LineMark(
                            x: .value("日期", item.date),
                            y: .value("体重", store.unit.value(fromKilograms: item.weightKG))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppColor.mint)
                        .lineStyle(.init(lineWidth: 3))
                        PointMark(
                            x: .value("日期", item.date),
                            y: .value("体重", store.unit.value(fromKilograms: item.weightKG))
                        )
                        .foregroundStyle(AppColor.mint)
                        .symbolSize(selectedMeasurement?.id == item.id ? 70 : 24)

                        if selectedMeasurement?.id == item.id {
                            RuleMark(x: .value("选中日期", item.date))
                                .foregroundStyle(AppColor.secondary.opacity(0.45))
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(store.unit.value(fromKilograms: item.weightKG).formatted(2)) \(store.unit.rawValue)")
                                            .font(.caption.bold())
                                        Text(item.date, format: .dateTime.year().month().day().hour().minute())
                                            .font(.caption2)
                                        Text(sourceName(for: item)).font(.caption2).foregroundStyle(AppColor.secondary)
                                    }
                                    .padding(8)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 7))
                                }
                        }
                    }
                    .chartXSelection(value: $selectedDate)
                    .chartYAxis {
                        AxisMarks(position: .trailing) {
                            AxisGridLine()
                            AxisValueLabel(
                                format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
                            )
                        }
                    }
                    .frame(height: 245)
                }
            }
        }
    }

    private var records: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("测量记录").font(.headline).padding(.bottom, 12)
                if filtered.isEmpty {
                    Text("当前筛选条件下没有记录")
                        .font(.subheadline).foregroundStyle(AppColor.secondary).padding(.vertical, 18)
                }
                ForEach(filtered) { item in
                    NavigationLink { MeasurementDetailView(measurement: item) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(store.unit.value(fromKilograms: item.weightKG).formatted(2)) \(store.unit.rawValue)")
                                    .font(.body.bold()).foregroundStyle(AppColor.ink)
                                Label(sourceName(for: item), systemImage: "scalemass")
                                    .font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(item.date, format: .dateTime.month().day()).foregroundStyle(AppColor.ink)
                                Text(item.date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 13)
                    }
                    if item.id != filtered.last?.id { Divider() }
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

struct MeasurementDetailView: View {
    @EnvironmentObject private var store: MeasurementStore
    let measurement: BodyMeasurement

    private var profile: UserProfile {
        store.profiles.first(where: { $0.id == measurement.profileID }) ?? store.selectedProfile
    }

    private var sourceName: String {
        if let deviceID = measurement.deviceID,
           let scale = store.pairedScales.first(where: { $0.id == deviceID }) {
            return scale.name
        }
        return measurement.deviceName ?? measurement.source.rawValue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(measurement.date, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline).foregroundStyle(AppColor.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.unit.value(fromKilograms: measurement.weightKG).formatted(2))
                            .font(.system(size: 58, weight: .medium, design: .rounded))
                        Text(store.unit.rawValue).font(.headline)
                    }
                    Label(sourceName, systemImage: "scalemass")
                        .font(.caption).foregroundStyle(AppColor.secondary)
                    StatusPill(text: profile.name)
                }
                .padding(.vertical, 28)
                metricCard(title: "基础指标", metrics: basicMetrics)
                if measurement.hasBodyComposition {
                    metricCard(title: "身体成分估算", metrics: compositionMetrics)
                    Text("体脂及相关指标是基于生物电阻抗和个人资料的消费级估算值，仅用于日常趋势参考，不构成医疗诊断。")
                        .font(.caption).foregroundStyle(AppColor.secondary).padding(.horizontal)
                }
                if !rawMetrics.isEmpty {
                    metricCard(title: "设备原始数据", metrics: rawMetrics)
                    Text("阻抗通道名称和频率尚未获得厂商定义，因此仅保留原始读数，不据此声称具体频率。")
                        .font(.caption).foregroundStyle(AppColor.secondary).padding(.horizontal)
                }
            }
            .padding(18)
        }
        .pageBackground()
        .navigationTitle("测量详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var basicMetrics: [(String, String)] {
        [("BMI", measurement.bmi(heightCM: profile.heightCM).formatted(2))]
    }

    private var compositionMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        append(measurement.bodyFatPercent, name: "体脂率", suffix: "%", to: &metrics)
        append(measurement.fatMassKG, name: "脂肪量", suffix: " kg", to: &metrics)
        append(measurement.musclePercent, name: "肌肉率", suffix: "%", to: &metrics)
        append(measurement.muscleMassKG, name: "肌肉量", suffix: " kg", to: &metrics)
        append(measurement.waterPercent, name: "身体水分", suffix: "%", to: &metrics)
        append(measurement.waterMassKG, name: "水分量", suffix: " kg", to: &metrics)
        append(measurement.proteinPercent, name: "蛋白质占比", suffix: "%", to: &metrics)
        append(measurement.proteinMassKG, name: "蛋白质量", suffix: " kg", to: &metrics)
        append(measurement.bonePercent, name: "骨量占比", suffix: "%", to: &metrics)
        append(measurement.boneMassKG, name: "骨量", suffix: " kg", to: &metrics)
        append(measurement.visceralFat, name: "内脏脂肪", suffix: "", to: &metrics)
        if let value = measurement.basalMetabolismKCal {
            metrics.append(("基础代谢", "\(value.formatted(2)) kcal"))
        }
        return metrics
    }

    private var rawMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        if let value = measurement.impedanceOhm {
            metrics.append(("阻抗通道 1", "\(value.formatted(2)) Ω"))
        }
        if let value = measurement.secondaryImpedanceOhm {
            metrics.append(("阻抗通道 2", "\(value.formatted(2)) Ω"))
        }
        return metrics
    }

    private func append(
        _ value: Double?,
        name: String,
        suffix: String,
        to metrics: inout [(String, String)]
    ) {
        guard let value else { return }
        metrics.append((name, "\(value.formatted(2))\(suffix)"))
    }

    private func metricCard(title: String, metrics: [(String, String)]) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline).padding(.bottom, 4)
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    DetailRow(name: metric.0, value: metric.1, divider: index < metrics.count - 1)
                }
            }
        }
    }
}

private struct DetailRow: View {
    let name: String, value: String
    var divider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(name).foregroundStyle(AppColor.secondary)
                Spacer()
                Text(value).fontWeight(.semibold)
            }
            .padding(.vertical, 15)
            if divider { Divider() }
        }
    }
}
