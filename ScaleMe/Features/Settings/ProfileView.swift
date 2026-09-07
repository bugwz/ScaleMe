import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MeasurementStore
    let scrollToTopRequest: Int

    private var firstSelfProfile: UserProfile? {
        store.managedProfiles.first(where: { $0.role == "本人" })
            ?? store.managedProfiles.first
    }

    var body: some View {
        NavigationStack {
            RootPageScrollView(scrollToTopRequest: scrollToTopRequest) {
                VStack(alignment: .leading, spacing: 24) {
                    MainPageTitle(text: store.appLanguage.text(.settings))
                    memberSection
                    settingsSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .mainPageTopInset()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.appLanguage.text(.userInformation))
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.ink)
                Spacer()
                StatusPill(
                    text: store.appLanguage.format("%lld 人", store.managedProfiles.count),
                    color: AppColor.secondary,
                    backgroundColor: AppColor.surface
                )
            }

            NavigationLink {
                MemberManagementView(initialProfiles: store.managedProfiles)
            } label: {
                VStack(spacing: 0) {
                    memberSummary
                }
                .background(AppColor.surface.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.10)))
                .shadow(color: AppColor.mint.opacity(0.07), radius: 15, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(memberSectionAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var memberSummary: some View {
        HStack(spacing: 16) {
            if let firstSelfProfile {
                MemberAvatarView(avatar: firstSelfProfile.avatar, width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text(firstSelfProfile.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.ink)
                    Text(memberRoleAndAge(firstSelfProfile))
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                    Text(memberHeightAndWeight(firstSelfProfile))
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 64, height: 64)
                    .background(AppColor.paleMint, in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    AppLocalizedText("添加成员")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.ink)
                    AppLocalizedText("需要成员资料")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(width: 36, height: 36)
                .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
    }

    private var memberSectionAccessibilityLabel: String {
        guard let firstSelfProfile else {
            return store.appLanguage.text("添加成员")
        }
        return "\(firstSelfProfile.name)，\(store.appLanguage.text("成员管理"))"
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.appLanguage.text(.appSettings))
                .font(.title3.bold())
                .foregroundStyle(AppColor.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                NavigationLink {
                    DisplaySettingsView()
                } label: {
                    settingsRow(store.appLanguage.text(.displaySettings), icon: "display", color: AppColor.mint)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    DataManagementSettingsView()
                } label: {
                    settingsRow(store.appLanguage.text(.dataManagement), icon: "externaldrive.fill", color: AppColor.sky)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    AppleHealthSettingsView()
                } label: {
                    settingsRow(store.appLanguage.text(.dataSharing), icon: "heart.fill", color: AppColor.rose)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    CommunicationRulesView()
                } label: {
                    settingsRow(store.appLanguage.text(.communicationProtocol), icon: "point.3.connected.trianglepath.dotted", color: AppColor.violet)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    AboutView()
                } label: {
                    settingsRow(store.appLanguage.text(.about), icon: "info.circle.fill", color: AppColor.mint)
                }
            }
            .padding(.horizontal, 14)
            .background(AppColor.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
        }
    }

    private func settingsRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppColor.secondary.opacity(0.7))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func memberRoleAndAge(_ profile: UserProfile) -> String {
        store.appLanguage.format(
            "%@ · %lld 岁",
            store.appLanguage.text(profile.role),
            profile.age
        )
    }

    private func memberHeightAndWeight(_ profile: UserProfile) -> String {
        store.appLanguage.format(
            "%@ cm · %@ kg",
            profile.heightCM.formatted(2),
            profile.referenceWeightKG.formatted(2)
        )
    }
}

private struct MemberDragState {
    let profile: UserProfile
    var location: CGPoint
    var hitTestLocation: CGPoint
    var grabOffset: CGSize
    let rowSize: CGSize
    let horizontalCenter: CGFloat
    var pendingRelocationTargetID: UUID?
    var hasResolvedDragTouch = false
    var hasStartedMoving = false
    var isLifted = false
    var isSettling = false
}

private struct MemberManagementView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var memberOrderAnimation
    @StateObject private var autoScroller = VerticalDragAutoScroller()
    @State private var searchText = ""
    @State private var showAddMember = false
    @State private var editingProfile: UserProfile?
    @State private var profileOrder: [UUID]
    @State private var memberFrames: [UUID: CGRect] = [:]
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var dragState: MemberDragState?
    @State private var dragActivationFeedback = 0

    private static let coordinateSpaceName = "memberManagement"

    init(initialProfiles: [UserProfile]) {
        _profileOrder = State(initialValue: initialProfiles.map(\.id))
    }

    private var draggingProfileID: UUID? {
        dragState?.profile.id
    }

    private var orderedProfiles: [UserProfile] {
        let profiles = store.managedProfiles
        guard profileOrder.count == profiles.count,
              Set(profileOrder) == Set(profiles.map(\.id)) else { return profiles }
        let profilesByID = Dictionary(
            profiles.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        return profileOrder.compactMap { profilesByID[$0] }
    }

    private var filteredProfiles: [UserProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return orderedProfiles }
        return orderedProfiles.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.role.localizedCaseInsensitiveContains(query)
        }
    }

    private var canReorder: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && orderedProfiles.count > 1
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                searchField

                HStack {
                    AppLocalizedText(listTitle)
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                    Spacer()
                    Button {
                        showAddMember = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColor.onAccent)
                            .frame(width: 38, height: 38)
                            .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("添加家庭成员")
                }

                if filteredProfiles.isEmpty {
                    emptyMemberState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredProfiles) { profile in
                            memberRow(profile)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .background(VerticalDragScrollViewResolver(autoScroller: autoScroller))
        }
        .scrollDisabled(draggingProfileID != nil)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MemberScrollViewportHeightPreferenceKey.self,
                    value: geo.size.height
                )
            }
        )
        .onPreferenceChange(MemberRowFramePreferenceKey.self) { frames in
            memberFrames = frames
            if var state = dragState,
               frames[state.profile.id]?.contains(state.hitTestLocation) == true,
               state.pendingRelocationTargetID != nil {
                state.pendingRelocationTargetID = nil
                dragState = state
            }
            if let state = dragState {
                relocate(state.profile.id, to: state.hitTestLocation, using: frames)
            }
        }
        .onPreferenceChange(MemberScrollViewportHeightPreferenceKey.self) { scrollViewportHeight = $0 }
        .overlay(alignment: .topLeading) {
            dragPreview
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: dragActivationFeedback)
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .navigationTitle("成员管理")
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
        .onChange(of: store.managedProfiles.map(\.id)) { _, _ in
            guard draggingProfileID == nil else { return }
            synchronizeProfileOrder()
        }
        .onDisappear {
            autoScroller.stop()
        }
        .sheet(isPresented: $showAddMember) {
            MemberEditorView(profile: nil, isFirstMember: store.managedProfiles.isEmpty)
        }
        .sheet(item: $editingProfile) { profile in
            MemberEditorView(profile: profile, isFirstMember: false)
        }
    }

    private var listTitle: String {
        if searchText.isEmpty {
            return store.appLanguage.format("全部成员（%lld 人）", filteredProfiles.count)
        }
        return store.appLanguage.format("搜索结果（%lld 人）", filteredProfiles.count)
    }

    private func memberDetail(_ profile: UserProfile) -> String {
        [
            store.appLanguage.format(
                "%@ · %lld 岁",
            store.appLanguage.text(profile.role),
                profile.age
            ),
            "\(profile.heightCM.formatted(2)) cm"
        ].joined(separator: " · ")
    }

    private var searchField: some View {
        MemberSearchField(text: $searchText)
    }

    @ViewBuilder
    private func memberRow(_ profile: UserProfile) -> some View {
        let isDragging = draggingProfileID == profile.id
        let isLiftedInPlace = isDragging
            && dragState?.hasStartedMoving == false
            && dragState?.isLifted == true
            && dragState?.isSettling == false

        let row = memberRowVisual(profile, showsActions: true)
            .overlay {
                memberRowActions(profile)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(
                        AppColor.mint.opacity(isLiftedInPlace ? 0.9 : 0),
                        lineWidth: 2.5
                    )
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: MemberRowFramePreferenceKey.self,
                        value: [profile.id: geo.frame(in: .named(Self.coordinateSpaceName))]
                    )
                }
            )
            .scaleEffect(reduceMotion || !isLiftedInPlace ? 1 : 1.06)
            .shadow(
                color: AppColor.mint.opacity(isLiftedInPlace ? 0.32 : 0),
                radius: isLiftedInPlace ? 18 : 0,
                y: isLiftedInPlace ? 10 : 0
            )
            .opacity(isDragging && dragState?.hasStartedMoving == true ? 0 : 1)
            .matchedGeometryEffect(id: profile.id, in: memberOrderAnimation)
            .transition(.identity)
            .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))

        if canReorder {
            row
                .simultaneousGesture(reorderGesture(for: profile.id), including: .all)
                .accessibilityHint("长按后上下拖动可调整顺序")
                .accessibilityAction(named: "上移") {
                    moveProfile(profile.id, by: -1)
                }
                .accessibilityAction(named: "下移") {
                    moveProfile(profile.id, by: 1)
                }
        } else {
            row
        }
    }

    private func memberRowVisual(
        _ profile: UserProfile,
        showsActions: Bool
    ) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 14) {
                MemberAvatarView(avatar: profile.avatar, width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                    Text(memberDetail(profile))
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
            }

            if showsActions {
                SettingsSeparator()
                    .frame(width: 1, height: 32)
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 38, height: 38)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(AppColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(AppColor.mint.opacity(0.07))
        )
    }

    private func memberRowActions(_ profile: UserProfile) -> some View {
        HStack {
            Spacer()
            Button {
                editingProfile = profile
            } label: {
                Color.clear
                    .frame(width: 38, height: 38)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(draggingProfileID != nil)
            .accessibilityLabel(store.appLanguage.format("编辑%@的资料", profile.name))
        }
        .padding(14)
    }

    @ViewBuilder
    private var dragPreview: some View {
        if let state = dragState, state.hasStartedMoving {
            memberRowVisual(
                state.profile,
                showsActions: false
            )
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(AppColor.mint.opacity(state.isLifted ? 0.9 : 0.35), lineWidth: 2.5)
                )
                .frame(width: state.rowSize.width, height: state.rowSize.height)
                .scaleEffect(reduceMotion || state.isSettling || !state.isLifted ? 1 : 1.06)
                .shadow(
                    color: AppColor.mint.opacity(state.isLifted && !state.isSettling ? 0.32 : 0),
                    radius: state.isLifted && !state.isSettling ? 18 : 0,
                    y: state.isLifted && !state.isSettling ? 10 : 0
                )
                .position(
                    x: state.horizontalCenter,
                    y: state.location.y - state.grabOffset.height + state.rowSize.height / 2
                )
                .allowsHitTesting(false)
                .zIndex(10)
        }
    }

    private func reorderGesture(for profileID: UUID) -> some Gesture {
        LongPressGesture(minimumDuration: 0.55, maximumDistance: 8)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(Self.coordinateSpaceName)
                )
            )
            .onChanged { value in
                guard canReorder,
                      case .second(true, let drag) = value else { return }
                activateDragging(profileID)
                if let drag {
                    updateDragging(profileID, with: drag)
                }
            }
            .onEnded { _ in
                if draggingProfileID == profileID {
                    finishDragging()
                }
            }
    }

    private func activateDragging(_ profileID: UUID) {
        guard dragState == nil,
              let profile = orderedProfiles.first(where: { $0.id == profileID }),
              let frame = memberFrames[profileID] else { return }
        dragState = MemberDragState(
            profile: profile,
            location: CGPoint(x: frame.midX, y: frame.midY),
            hitTestLocation: CGPoint(x: frame.midX, y: frame.midY),
            grabOffset: CGSize(width: frame.width / 2, height: frame.height / 2),
            rowSize: frame.size,
            horizontalCenter: frame.midX
        )
        dragActivationFeedback += 1
        DispatchQueue.main.async {
            guard var state = dragState, state.profile.id == profileID else { return }
            state.isLifted = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.78)) {
                dragState = state
            }
        }
    }

    private func updateDragging(_ profileID: UUID, with drag: DragGesture.Value) {
        guard var state = dragState, state.profile.id == profileID else { return }
        if !state.hasResolvedDragTouch, let frame = memberFrames[profileID] {
            state.grabOffset = CGSize(
                width: drag.location.x - frame.minX,
                height: drag.location.y - frame.minY
            )
            state.hasResolvedDragTouch = true
        }
        state.location = drag.location
        state.hitTestLocation = drag.location
        if !state.hasStartedMoving,
           hypot(drag.translation.width, drag.translation.height) > 0.5 {
            state.hasStartedMoving = true
        }
        dragState = state
        relocate(profileID, to: state.hitTestLocation, using: memberFrames)
        autoScroller.update(fingerY: drag.location.y, viewportHeight: scrollViewportHeight)
    }

    private func relocate(_ profileID: UUID, to location: CGPoint, using frames: [UUID: CGRect]) {
        if frames[profileID]?.contains(location) == true { return }
        guard let targetID = orderedProfiles.first(where: {
            $0.id != profileID && frames[$0.id]?.contains(location) == true
        })?.id, targetID != dragState?.pendingRelocationTargetID else { return }
        guard var state = dragState, state.profile.id == profileID else { return }
        state.pendingRelocationTargetID = targetID
        dragState = state
        moveProfileLocally(profileID, onto: targetID)
    }

    private func moveProfile(_ profileID: UUID, by offset: Int) {
        let profiles = orderedProfiles
        guard let sourceIndex = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        let targetIndex = sourceIndex + offset
        guard profiles.indices.contains(targetIndex) else { return }
        moveProfileLocally(profileID, onto: profiles[targetIndex].id)
        commitProfileOrder()
    }

    private func moveProfileLocally(_ profileID: UUID, onto targetProfileID: UUID) {
        var newOrder = orderedProfiles.map(\.id)
        guard profileID != targetProfileID,
              let targetIndex = newOrder.firstIndex(of: targetProfileID) else { return }
        newOrder.removeAll { $0 == profileID }
        newOrder.insert(profileID, at: min(targetIndex, newOrder.endIndex))
        guard newOrder != profileOrder else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22)) {
            profileOrder = newOrder
        }
    }

    private func synchronizeProfileOrder() {
        let currentOrder = store.managedProfiles.map(\.id)
        guard profileOrder != currentOrder else { return }
        profileOrder = currentOrder
    }

    private func commitProfileOrder() {
        store.setDisplayProfileOrder(orderedProfiles.map(\.id))
    }

    private func finishDragging() {
        autoScroller.stop()
        commitProfileOrder()
        guard !reduceMotion,
              var state = dragState,
              let destination = memberFrames[state.profile.id] else {
            resetDragState()
            return
        }
        state.isSettling = true
        state.location = CGPoint(
            x: destination.minX + state.grabOffset.width,
            y: destination.minY + state.grabOffset.height
        )
        withAnimation(.snappy(duration: 0.18), completionCriteria: .logicallyComplete) {
            dragState = state
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        dragState = nil
    }

    private var emptyMemberState: some View {
        VStack(spacing: 10) {
            Image(systemName: orderedProfiles.isEmpty
                ? "person.crop.circle.badge.plus"
                : "person.crop.circle.badge.questionmark")
                .font(.title2)
                .foregroundStyle(AppColor.sky)
            AppLocalizedText(orderedProfiles.isEmpty ? "添加成员" : "没有找到匹配的成员")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
            AppLocalizedText(orderedProfiles.isEmpty ? "需要成员资料" : "可以换一个姓名或角色关键词。")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(AppColor.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MemberRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct MemberScrollViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum MemberEditorDropdown: Equatable {
    case role
    case biologicalSex
}

private struct MemberEditorView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    private let isNew: Bool
    private let isOwner: Bool
    @State private var draft: UserProfile
    @State private var heightText: String
    @State private var weightText: String
    @State private var selectedAvatar: MemberAvatar?
    @State private var selectedSex: UserProfile.BiologicalSex?
    @State private var selectedBirthDate: Date?
    @State private var pendingBirthDate: Date
    @State private var isSelectingBirthDate = false
    @State private var usesCustomRole: Bool
    @State private var isRoleFocused = false
    @State private var confirmDelete = false
    @State private var expandedDropdown: MemberEditorDropdown?

    private static let standardRoles = ["伴侣", "父母", "子女"]
    private var roles: [String] { Self.standardRoles + ["其他"] }
    init(profile: UserProfile?, isFirstMember: Bool) {
        isNew = profile == nil
        isOwner = profile?.role == "本人" || (profile == nil && isFirstMember)
        let initialDraft = profile ?? UserProfile(
            name: "",
            role: isFirstMember ? "本人" : ""
        )
        _draft = State(initialValue: initialDraft)
        _heightText = State(initialValue: profile == nil ? "" : initialDraft.heightCM.formatted(.number.precision(.fractionLength(0...2))))
        _weightText = State(initialValue: profile == nil ? "" : initialDraft.referenceWeightKG.formatted(.number.precision(.fractionLength(0...2))))
        _selectedAvatar = State(initialValue: profile?.avatar)
        _selectedSex = State(initialValue: profile?.biologicalSex)
        _selectedBirthDate = State(initialValue: profile?.birthDate)
        _pendingBirthDate = State(initialValue: profile?.birthDate
            ?? Calendar.current.date(byAdding: .year, value: -30, to: .now)
            ?? .now)
        _usesCustomRole = State(
            initialValue: !initialDraft.role.isEmpty
                && initialDraft.role != "本人"
                && !Self.standardRoles.contains(initialDraft.role)
        )
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        avatarPanel
                        informationPanel
                        usagePanel
                        deletePanel
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
                .pageBackground()
                .navigationTitle(store.appLanguage.text(isNew ? "添加成员" : "编辑成员"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            KeyboardFocus.dismiss()
                            draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            draft.role = draft.role.trimmingCharacters(in: .whitespacesAndNewlines)
                            if isOwner { draft.role = "本人" }
                            guard let heightCM = parsedHeight else { return }
                            guard let referenceWeightKG = parsedWeight else { return }
                            guard let selectedAvatar, let selectedSex, let selectedBirthDate else { return }
                            draft.heightCM = heightCM
                            draft.referenceWeightKG = referenceWeightKG
                            draft.avatar = selectedAvatar
                            draft.biologicalSex = selectedSex
                            draft.birthDate = selectedBirthDate
                            if isNew { store.addProfile(draft) } else { store.updateProfile(draft) }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .tint(AppColor.mint)
                        .disabled(!canSave)
                    }
                }
                .accessibilityHidden(confirmDelete || expandedDropdown != nil)
                .overlayPreferenceValue(AppDropdownAnchorPreferenceKey.self) { anchor in
                    GeometryReader { proxy in
                        if let anchor, let expandedDropdown {
                            switch expandedDropdown {
                            case .role:
                                AppDropdownMenuLayer(
                                    anchorFrame: proxy[anchor],
                                    availableSize: proxy.size,
                                    options: roles,
                                    isSelected: { $0 == "其他" ? usesCustomRole : !usesCustomRole && $0 == draft.role },
                                    title: { $0 },
                                    appearance: .compact,
                                    onSelect: { relation in
                                        if relation == "其他" {
                                            usesCustomRole = true
                                            draft.role = ""
                                            isRoleFocused = true
                                        } else {
                                            usesCustomRole = false
                                            draft.role = relation
                                            isRoleFocused = false
                                        }
                                        dismissDropdown()
                                    },
                                    onDismiss: dismissDropdown
                                )
                            case .biologicalSex:
                                AppDropdownMenuLayer(
                                    anchorFrame: proxy[anchor],
                                    availableSize: proxy.size,
                                    options: UserProfile.BiologicalSex.allCases,
                                    isSelected: { $0 == selectedSex },
                                    title: { $0.displayName },
                                    appearance: .compact,
                                    onSelect: { biologicalSex in
                                        selectedSex = biologicalSex
                                        dismissDropdown()
                                    },
                                    onDismiss: dismissDropdown
                                )
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isSelectingBirthDate) {
                birthDatePickerSheet
            }

            if confirmDelete {
                DestructiveConfirmationOverlay(
                    icon: "person.crop.circle.badge.minus",
                    title: "删除成员？",
                    message: store.appLanguage.format(
                        "将删除“%@”的成员资料，已有测量记录仍会保留。",
                        memberDisplayName
                    ),
                    confirmTitle: "删除成员",
                    onCancel: hideDeleteConfirmation,
                    onConfirm: {
                        confirmDelete = false
                        store.deleteProfile(draft.id)
                        dismiss()
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .interactiveDismissDisabled(confirmDelete || expandedDropdown != nil)
    }

    private func hideDeleteConfirmation() {
        confirmDelete = false
    }

    private func showDeleteConfirmation() {
        KeyboardFocus.dismiss()
        expandedDropdown = nil
        withAnimation(.easeOut(duration: 0.12)) {
            confirmDelete = true
        }
    }

    private func toggleDropdown(_ dropdown: MemberEditorDropdown) {
        KeyboardFocus.dismiss()
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedDropdown = expandedDropdown == dropdown ? nil : dropdown
        }
    }

    private func dismissDropdown() {
        withAnimation(.easeInOut(duration: 0.16)) {
            expandedDropdown = nil
        }
    }

    private var avatarPanel: some View {
        SettingsPanel(title: "人物形象", icon: "person.crop.rectangle.stack") {
            MemberAvatarPicker(selection: selectedAvatar) { selectedAvatar = $0 }
                .equatable()
        }
    }

    private var informationPanel: some View {
        SettingsPanel(title: "成员信息", icon: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("名称")
                MemberNameInput(text: $draft.name)
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("角色")
                if isOwner {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(AppColor.mint)
                        AppLocalizedText("本人")
                            .foregroundStyle(AppColor.ink)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                    }
                    .settingsInputSurface()
                    AppLocalizedText("首位成员固定为本人，只能通过清除全部数据移除。")
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if usesCustomRole {
                    AppEditableDropdownField(
                        text: $draft.role,
                        isFocused: $isRoleFocused,
                        placeholder: "输入角色",
                        icon: "person.2.fill",
                        accessibilityLabel: "角色",
                        isExpanded: expandedDropdown == .role,
                        appearance: .compact,
                        onToggle: { toggleDropdown(.role) }
                    )
                } else {
                    AppDropdownField(
                        value: draft.role,
                        icon: "person.2.fill",
                        accessibilityLabel: "角色",
                        isExpanded: expandedDropdown == .role,
                        appearance: .compact,
                        onToggle: { toggleDropdown(.role) }
                    )
                }
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("性别")
                AppDropdownField(
                    value: selectedSex.map(\.displayName) ?? store.appLanguage.text("未选择"),
                    icon: "person.crop.circle",
                    accessibilityLabel: "性别",
                    isExpanded: expandedDropdown == .biologicalSex,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.biologicalSex) }
                )
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("出生日期")
                Button {
                    pendingBirthDate = selectedBirthDate
                        ?? Calendar.current.date(byAdding: .year, value: -30, to: .now)
                        ?? .now
                    isSelectingBirthDate = true
                } label: {
                    HStack {
                        Image(systemName: "calendar").foregroundStyle(AppColor.sky)
                        Text(selectedBirthDate?.formatted(.dateTime.year().month().day())
                            ?? store.appLanguage.text("未选择"))
                            .foregroundStyle(selectedBirthDate == nil ? AppColor.secondary : AppColor.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppColor.secondary)
                    }
                    .settingsInputSurface()
                }
                .buttonStyle(.plain)
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("身高")
                MemberHeightInput(text: $heightText)
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("参考体重")
                MemberWeightInput(text: $weightText)
            }
        }
    }

    private var usagePanel: some View {
        SettingsPanel(title: "资料用途", icon: "shield.lefthalf.filled") {
            Text("资料仅用于日常指标估算。生物电阻抗与推导结果不具备医疗诊断用途。")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
                .lineSpacing(3)
        }
    }

    private var birthDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "出生日期",
                selection: $pendingBirthDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppColor.mint)
            .padding(18)
            .navigationTitle(store.appLanguage.text("出生日期"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isSelectingBirthDate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        selectedBirthDate = pendingBirthDate
                        isSelectingBirthDate = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var deletePanel: some View {
        if !isNew, draft.role != "本人", store.managedProfiles.count > 1 {
            Button(role: .destructive, action: showDeleteConfirmation) {
                Label("删除成员", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.rose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.rose.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("删除成员不会自动删除其历史测量记录。")
                .font(.caption2)
                .foregroundStyle(AppColor.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (isOwner || draft.role != "本人")
            && selectedAvatar != nil
            && selectedSex != nil
            && selectedBirthDate != nil
            && parsedHeight.map { (50...250).contains($0) } == true
            && parsedWeight.map { (5...350).contains($0) } == true
    }

    private var parsedHeight: Double? {
        let normalized = heightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var parsedWeight: Double? {
        let normalized = weightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var memberDisplayName: String {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "该成员" : trimmedName
    }

    private func fieldLabel(_ title: String) -> some View {
        AppLocalizedText(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.secondary)
    }
}

private struct MemberSearchField: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.secondary)
            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: "搜索姓名或角色",
                returnKeyType: .search,
                autocorrectionType: .no
            )
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.secondary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(AppColor.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColor.mint.opacity(0.10)))
    }
}

private struct MemberAvatarPicker: View, Equatable {
    @Environment(\.appLanguage) private var language
    let selection: MemberAvatar?
    let onSelect: (MemberAvatar) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selection == rhs.selection
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(MemberAvatar.allCases) { avatar in
                    Button {
                        onSelect(avatar)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            MemberAvatarView(avatar: avatar, width: 104, height: 142)
                            if selection == avatar {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(AppColor.onAccent, AppColor.mint)
                                    .padding(7)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .stroke(selection == avatar ? AppColor.mint : .clear, lineWidth: 2)
                                .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.format(
                        "选择%@人物形象",
                        language.text(avatar.ageHint)
                    ))
                    .accessibilityAddTraits(selection == avatar ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct MemberNameInput: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill").foregroundStyle(AppColor.mint)
            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: "名称",
                returnKeyType: .done
            )
            .frame(minHeight: 24)
        }
        .settingsInputSurface(isFocused: isFocused)
    }
}

private struct MemberHeightInput: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ruler.fill").foregroundStyle(AppColor.sky)
            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: "50–250",
                keyboardType: .decimalPad,
                returnKeyType: .done,
                showsDoneAccessory: true
            )
            .frame(minHeight: 24)
            Text(verbatim: "cm")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.secondary)
        }
        .settingsInputSurface(isFocused: isFocused)
    }
}

private struct MemberWeightInput: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "scalemass.fill").foregroundStyle(AppColor.mint)
            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: "5–350",
                keyboardType: .decimalPad,
                returnKeyType: .done,
                showsDoneAccessory: true
            )
            .frame(minHeight: 24)
            Text(verbatim: "kg")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.secondary)
        }
        .settingsInputSurface(isFocused: isFocused)
    }
}

private extension View {
    func settingsInputSurface(isFocused: Bool = false) -> some View {
        padding(.horizontal, 13)
            .frame(minHeight: 46)
            .background(AppColor.paleMint.opacity(0.58), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isFocused ? AppColor.mint.opacity(0.55) : AppColor.mint.opacity(0.10), lineWidth: isFocused ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
    }
}
