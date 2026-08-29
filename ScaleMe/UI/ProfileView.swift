import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var showAbout = false
    @State private var showAddMember = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    memberSection
                    settingsSection
                    privacySection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .pageBackground()
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddMember = true } label: { Image(systemName: "person.badge.plus") }
                        .accessibilityLabel("添加成员")
                }
            }
            .sheet(isPresented: $showAddMember) {
                MemberEditorView(profile: nil)
            }
            .alert("观我 · ScaleMe", isPresented: $showAbout) {
                Button("好") {}
            } message: {
                Text("从细微变化里，看见身体长期的方向。\n\n版本 0.1.0")
            }
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("成员").font(.title3.bold())
                Spacer()
                Text("\(store.profiles.count) 人").font(.caption).foregroundStyle(AppColor.secondary)
            }
            VStack(spacing: 0) {
                ForEach(store.profiles) { profile in
                    NavigationLink {
                        MemberEditorView(profile: profile)
                    } label: {
                        HStack(spacing: 14) {
                            Text(String(profile.name.prefix(1)))
                                .font(.headline).foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(profile.id == store.selectedProfileID ? AppColor.mint : AppColor.violet, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Text(profile.name).font(.body.weight(.semibold)).foregroundStyle(AppColor.ink)
                                    if profile.id == store.selectedProfileID { StatusPill(text: "当前") }
                                }
                                Text("\(profile.relation) · \(profile.heightCM.formatted(0)) cm · \(profile.age) 岁")
                                    .font(.caption).foregroundStyle(AppColor.secondary)
                            }
                            Spacer()
                            Button {
                                store.selectProfile(profile.id)
                            } label: {
                                Image(systemName: profile.id == store.selectedProfileID ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(profile.id == store.selectedProfileID ? AppColor.mint : AppColor.secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("切换到\(profile.name)")
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColor.secondary)
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    if profile.id != store.profiles.last?.id { Divider().padding(.leading, 62) }
                }
                Button { showAddMember = true } label: {
                    Label("添加成员", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsView()
            } label: {
                settingsRow("设置", icon: "gearshape.fill")
            }
            Divider().padding(.leading, 50)
            Button { showAbout = true } label: {
                settingsRow("关于观我 / ScaleMe", icon: "info.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
    }

    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(AppColor.mint).frame(width: 34)
            Text(title).foregroundStyle(AppColor.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColor.secondary)
        }
        .padding(.vertical, 15)
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("本地优先", systemImage: "lock.shield.fill").font(.headline)
            Text("成员资料用于 BMI 和身体成分估算。体脂秤结果会受到水分、进食、运动和接触状态影响，仅用于趋势参考，不构成医疗诊断。")
                .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(3)
        }
        .padding(.horizontal, 8)
    }
}

private struct MemberEditorView: View {
    private enum InputField: Hashable {
        case name
        case height
    }

    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    private let isNew: Bool
    @State private var draft: UserProfile
    @State private var confirmDelete = false
    @FocusState private var focusedField: InputField?

    private let relations = ["本人", "伴侣", "父母", "子女", "其他"]

    init(profile: UserProfile?) {
        isNew = profile == nil
        _draft = State(initialValue: profile ?? UserProfile(name: "", relation: "家人"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("成员信息") {
                    TextField("姓名或昵称", text: $draft.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .height }
                    Picker("关系", selection: $draft.relation) {
                        ForEach(relations, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("生理性别", selection: $draft.biologicalSex) {
                        ForEach(UserProfile.BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("出生日期", selection: $draft.birthDate, in: ...Date.now, displayedComponents: .date)
                    HStack {
                        Text("身高")
                        Spacer()
                        TextField("cm", value: $draft.heightCM, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .height)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    Toggle("运动员模式", isOn: $draft.athleteMode).tint(AppColor.mint)
                }
                Section {
                    Text("资料仅用于日常指标估算。生物电阻抗与推导结果不具备医疗诊断用途。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !isNew, store.profiles.count > 1 {
                    Section {
                        Button("删除成员", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("删除成员不会自动删除其历史测量记录。")
                    }
                }
            }
            .navigationTitle(isNew ? "添加成员" : "成员资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        focusedField = nil
                        if isNew { store.addProfile(draft) } else { store.updateProfile(draft) }
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(50...250).contains(draft.heightCM))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .confirmationDialog("确定删除这个成员？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除成员", role: .destructive) {
                    store.deleteProfile(draft.id)
                    dismiss()
                }
            }
        }
    }
}
