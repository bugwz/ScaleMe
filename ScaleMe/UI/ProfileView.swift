import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var showAddMember = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MainPageTitle(text: "设置")
                    memberSection
                    settingsSection
                    privacySection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddMember) {
                MemberEditorView(profile: nil)
            }
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("成员").font(.title3.bold())
                Spacer()
                Text("\(store.displayProfiles.count) 人").font(.caption).foregroundStyle(AppColor.secondary)
            }
            VStack(spacing: 0) {
                ForEach(store.displayProfiles) { profile in
                    if store.isSimulationEnabled {
                        Button {
                            store.selectDisplayProfile(profile.id)
                        } label: {
                            memberRow(profile, showsDisclosure: false)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            MemberEditorView(profile: profile)
                        } label: {
                            memberRow(profile, showsDisclosure: true)
                        }
                        .buttonStyle(.plain)
                    }
                    if profile.id != store.displayProfiles.last?.id { Divider().padding(.leading, 62) }
                }
                Button { showAddMember = true } label: {
                    Label("添加成员", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .disabled(store.isSimulationEnabled)
            }
            .padding(.horizontal, 16)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func memberRow(_ profile: UserProfile, showsDisclosure: Bool) -> some View {
        HStack(spacing: 14) {
            MemberAvatarView(avatar: profile.avatar, width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(profile.name).font(.body.weight(.semibold)).foregroundStyle(AppColor.ink)
                    if profile.id == store.displaySelectedProfileID { StatusPill(text: "当前") }
                }
                Text("\(profile.relation) · \(profile.heightCM.formatted(2)) cm · \(profile.age) 岁")
                    .font(.caption).foregroundStyle(AppColor.secondary)
            }
            Spacer()
            Image(systemName: profile.id == store.displaySelectedProfileID ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(profile.id == store.displaySelectedProfileID ? AppColor.mint : AppColor.secondary)
                .font(.title3)
            if showsDisclosure {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColor.secondary)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name)，\(profile.relation)")
        .accessibilityValue(profile.id == store.displaySelectedProfileID ? "当前成员" : "")
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用设置")
                .font(.title3.bold())
                .foregroundStyle(AppColor.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                NavigationLink {
                    CommunicationRulesView()
                } label: {
                    settingsRow("通信协议", icon: "point.3.connected.trianglepath.dotted")
                }
                Divider().padding(.leading, 50)
                NavigationLink {
                    SettingsView()
                } label: {
                    settingsRow("偏好与同步", icon: "gearshape.fill")
                }
                Divider().padding(.leading, 50)
                NavigationLink {
                    AboutView()
                } label: {
                    settingsRow("关于观我 / ScaleMe", icon: "info.circle.fill")
                }
            }
            .padding(.horizontal, 16)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPanel(title: "人物形象", icon: "person.crop.rectangle.stack") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(MemberAvatar.allCases) { avatar in
                                    Button {
                                        draft.avatar = avatar
                                    } label: {
                                        ZStack(alignment: .topTrailing) {
                                            MemberAvatarView(
                                                avatar: avatar,
                                                width: 104,
                                                height: 142,
                                                showsLabel: true
                                            )
                                            if draft.avatar == avatar {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(.white, AppColor.mint)
                                                    .padding(7)
                                            }
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                                .stroke(
                                                    draft.avatar == avatar ? AppColor.mint : .clear,
                                                    lineWidth: 2
                                                )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("选择\(avatar.ageHint)人物形象")
                                    .accessibilityAddTraits(draft.avatar == avatar ? .isSelected : [])
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    SettingsPanel(title: "成员信息", icon: "person.text.rectangle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("姓名或昵称")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColor.secondary)
                            TextField("请输入姓名或昵称", text: $draft.name)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .height }
                        }
                        Divider()
                        HStack(spacing: 16) {
                            Text("关系")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.secondary)
                            Spacer()
                            Picker("", selection: $draft.relation) {
                                ForEach(relations, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(AppColor.ink)
                        }
                        Divider()
                        HStack(spacing: 16) {
                            Text("生理性别")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.secondary)
                            Spacer()
                            Picker("", selection: $draft.biologicalSex) {
                                ForEach(UserProfile.BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(AppColor.ink)
                        }
                        Divider()
                        DatePicker("出生日期", selection: $draft.birthDate, in: ...Date.now, displayedComponents: .date)
                        Divider()
                        HStack {
                            Text("身高")
                            Spacer()
                            TextField("cm", value: $draft.heightCM, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .height)
                                .frame(maxWidth: 100)
                            Text("cm").foregroundStyle(AppColor.secondary)
                        }
                        Divider()
                        Toggle("运动员模式", isOn: $draft.athleteMode)
                            .tint(AppColor.mint)
                    }

                    SettingsPanel(title: "资料用途", icon: "shield.lefthalf.filled") {
                        Text("资料仅用于日常指标估算。生物电阻抗与推导结果不具备医疗诊断用途。")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .lineSpacing(3)
                    }

                    if !isNew, store.profiles.count > 1 {
                        SettingsPanel(title: "成员管理", icon: "person.crop.circle.badge.minus") {
                            Button("删除成员", role: .destructive) { confirmDelete = true }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.bordered)
                            Text("删除成员不会自动删除其历史测量记录。")
                                .font(.caption)
                                .foregroundStyle(AppColor.secondary)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .pageBackground()
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
