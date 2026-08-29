import Charts
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var range = TimeRange.month

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "周", month = "月", year = "年", all = "全部"
        var id: String { rawValue }
        var days: Int? { switch self { case .week: 7; case .month: 31; case .year: 365; case .all: nil } }
    }

    private var filtered: [BodyMeasurement] {
        guard let days = range.days, let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return store.displayMeasurements }
        return store.displayMeasurements.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("时间范围", selection: $range) { ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                    chart
                    records
                }
                .padding(.horizontal, 18).padding(.bottom, 28)
            }
            .pageBackground().navigationTitle("身体趋势")
        }
    }

    private var chart: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("体重变化").font(.headline)
                if let first = filtered.last, let last = filtered.first {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(store.unit.value(fromKilograms: last.weightKG - first.weightKG).formatted(1))
                            .font(.title.bold()).foregroundStyle(AppColor.ink)
                        Text(store.unit.rawValue).font(.caption).foregroundStyle(AppColor.secondary)
                        Spacer()
                        Text("\(filtered.count) 次记录").font(.caption).foregroundStyle(AppColor.secondary)
                    }
                }
                Chart(filtered.reversed()) { item in
                    LineMark(x: .value("日期", item.date), y: .value("体重", store.unit.value(fromKilograms: item.weightKG)))
                        .interpolationMethod(.catmullRom).foregroundStyle(AppColor.mint).lineStyle(.init(lineWidth: 3))
                    PointMark(x: .value("日期", item.date), y: .value("体重", store.unit.value(fromKilograms: item.weightKG)))
                        .foregroundStyle(AppColor.mint).symbolSize(28)
                }
                .chartYAxis { AxisMarks(position: .trailing) }
                .frame(height: 225)
            }
        }
    }

    private var records: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("测量记录").font(.headline).padding(.bottom, 12)
                ForEach(filtered) { item in
                    NavigationLink { MeasurementDetailView(measurement: item) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(store.unit.value(fromKilograms: item.weightKG).formatted(1)) \(store.unit.rawValue)").font(.body.bold()).foregroundStyle(AppColor.ink)
                                Text(item.source.rawValue).font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(item.date, format: .dateTime.month().day()).foregroundStyle(AppColor.ink)
                                Text(item.date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 13)
                    }
                    if item.id != filtered.last?.id { Divider() }
                }
            }
        }
    }
}

struct MeasurementDetailView: View {
    @EnvironmentObject private var store: MeasurementStore
    let measurement: BodyMeasurement

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(measurement.date, format: .dateTime.year().month().day().hour().minute()).font(.subheadline).foregroundStyle(AppColor.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.unit.value(fromKilograms: measurement.weightKG).formatted(1)).font(.system(size: 58, weight: .medium, design: .rounded))
                        Text(store.unit.rawValue).font(.headline)
                    }
                    StatusPill(text: measurement.source.rawValue)
                }.padding(.vertical, 28)
                SoftCard {
                    VStack(spacing: 0) {
                        DetailRow(name: "BMI", value: measurement.bmi(heightCM: store.profile.heightCM).formatted(1))
                        DetailRow(name: "体脂率", value: measurement.bodyFatPercent.map { "\($0.formatted(1))%" } ?? "—")
                        DetailRow(name: "肌肉量", value: measurement.muscleMassKG.map { "\($0.formatted(1)) kg" } ?? "—")
                        DetailRow(name: "身体水分", value: measurement.waterPercent.map { "\($0.formatted(1))%" } ?? "—")
                        DetailRow(name: "内脏脂肪", value: measurement.visceralFat?.formatted(1) ?? "—")
                        DetailRow(name: "基础代谢", value: measurement.basalMetabolismKCal.map { "\($0.formatted(0)) kcal" } ?? "—", divider: false)
                    }
                }
                Text("体脂及相关指标是基于生物电阻抗和个人资料的估算值，仅用于日常趋势参考，不构成医疗诊断。")
                    .font(.caption).foregroundStyle(AppColor.secondary).padding(.horizontal)
            }.padding(18)
        }.pageBackground().navigationTitle("测量详情").navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailRow: View {
    let name: String, value: String
    var divider = true
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(name).foregroundStyle(AppColor.secondary); Spacer(); Text(value).fontWeight(.semibold) }.padding(.vertical, 15)
            if divider { Divider() }
        }
    }
}
