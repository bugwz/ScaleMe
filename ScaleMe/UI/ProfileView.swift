import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 15) {
                        Text(String(store.profile.name.prefix(1)))
                            .font(.title.bold()).foregroundStyle(.white).frame(width: 58, height: 58)
                            .background(LinearGradient(colors: [AppColor.mint, AppColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("昵称", text: $store.profile.name).font(.headline)
                            Text("资料用于计算 BMI 与体成分估算").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 5)
                }
                Section("基础资料") {
                    HStack { Text("身高"); Spacer(); TextField("cm", value: $store.profile.heightCM, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("cm").foregroundStyle(.secondary) }
                    DatePicker("出生日期", selection: $store.profile.birthDate, in: ...Date.now, displayedComponents: .date)
                    Picker("生理性别", selection: $store.profile.biologicalSex) { ForEach(UserProfile.BiologicalSex.allCases) { Text($0.rawValue).tag($0) } }
                    Toggle("运动员模式", isOn: $store.profile.athleteMode).tint(AppColor.mint)
                }
                Section {
                    HStack {
                        Label("Apple 健康同步", systemImage: "heart.fill")
                        Spacer()
                        StatusPill(text: "接入中", color: AppColor.violet)
                    }
                    Label("数据默认保存在本机", systemImage: "iphone.and.arrow.forward")
                    Label("不需要注册账户", systemImage: "person.crop.circle.badge.checkmark")
                } header: {
                    Text("数据与隐私")
                } footer: {
                    Text("Apple 健康授权接入界面已预留；正式发布前需在开发者账号启用 HealthKit capability 并完成隐私审查。")
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    Button("关于观我 / ScaleMe") { showAbout = true }
                }
                Section {
                    Text("体脂秤数据会受到水分、进食、运动和接触状态影响。应用仅用于健康趋势管理，不替代医疗器械或专业诊断。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).pageBackground().navigationTitle("我的")
            .alert("观我 · ScaleMe", isPresented: $showAbout) {
                Button("好") {}
            } message: {
                Text("从微小变化里，看见身体长期的方向。\n\n版本 0.1.0")
            }
        }
    }
}
