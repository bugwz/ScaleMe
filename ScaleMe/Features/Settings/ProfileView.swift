import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        NavigationStack {
            ScrollView {
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
                    text: store.appLanguage.format("%lld 人", store.displayProfiles.count),
                    color: AppColor.sky
                )
            }

            NavigationLink {
                MemberManagementView(initialProfiles: store.displayProfiles)
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        MemberAvatarView(avatar: store.displaySelectedProfile.avatar, width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(store.displaySelectedProfile.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppColor.ink)
                                StatusPill(text: "当前")
                            }
                            Text(memberDetail(store.displaySelectedProfile))
                                .font(.caption)
                                .foregroundStyle(AppColor.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "person.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.mint)
                            .frame(width: 36, height: 36)
                            .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(18)

                    SettingsSeparator()

                    HStack {
                        Text("管理全部成员")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.ink)
                        Spacer()
                        Text("搜索、切换或编辑资料")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppColor.mint)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                }
                .background(.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.10)))
                .shadow(color: AppColor.mint.opacity(0.07), radius: 15, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                store.appLanguage.format(
                    "当前成员，%@，管理全部成员",
                    store.displaySelectedProfile.name
                )
            )
        }
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
                    settingsRow(store.appLanguage.text(.displaySettings), detail: store.appLanguage.text(.displaySettingsDetail), icon: "slider.horizontal.3", color: AppColor.mint)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    settingsRow(store.appLanguage.text(.language), detail: store.appLanguage.nativeName, icon: "globe", color: AppColor.mint)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    DataSyncSettingsView()
                } label: {
                    settingsRow(store.appLanguage.text(.dataSync), detail: store.appLanguage.text(.dataSyncDetail), icon: "icloud.fill", color: AppColor.sky)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    CommunicationRulesView()
                } label: {
                    settingsRow(store.appLanguage.text(.communicationProtocol), detail: store.appLanguage.text(.communicationProtocolDetail), icon: "point.3.connected.trianglepath.dotted", color: AppColor.violet)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    DeveloperDiagnosticsView()
                } label: {
                    settingsRow(store.appLanguage.text(.developerDiagnostics), detail: store.appLanguage.text(.developerDiagnosticsDetail), icon: "wrench.and.screwdriver.fill", color: AppColor.apricot)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    AboutView()
                } label: {
                    settingsRow(store.appLanguage.text(.about), detail: store.appLanguage.text(.aboutDetail), icon: "leaf.fill", color: AppColor.violet)
                }
            }
            .padding(.horizontal, 14)
            .background(.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
        }
    }

    private func settingsRow(_ title: String, detail: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(AppColor.secondary.opacity(0.7))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func memberDetail(_ profile: UserProfile) -> String {
        store.appLanguage.format(
            "%@ · %@ cm · %lld 岁",
            store.appLanguage.text(profile.relation),
            profile.heightCM.formatted(2),
            profile.age
        )
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.appLanguage.text(.languageHint))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)

                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                        languageButton(language)
                        if index < AppLanguage.allCases.count - 1 {
                            SettingsSeparator().padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .pageBackground()
        .navigationTitle(store.appLanguage.text(.languageSettings))
        .navigationBarTitleDisplayMode(.inline)
        .localizedNavigationBackButton()
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let isSelected = store.appLanguage == language
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                store.appLanguage = language
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "character.bubble.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? AppColor.mint : AppColor.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? AppColor.paleMint : AppColor.canvas,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                Text(language.nativeName)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(AppColor.ink)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColor.mint : AppColor.secondary.opacity(0.35))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.nativeName)
        .accessibilityValue(isSelected ? store.appLanguage.text(.selected) : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MemberDragState {
    let profile: UserProfile
    var location: CGPoint
    let layoutStartCenter: CGPoint
    var hitTestLocation: CGPoint
    var grabOffset: CGSize
    let rowSize: CGSize
    let horizontalCenter: CGFloat
    var pendingRelocationTargetID: UUID?
    var isLifted = false
    var isSettling = false
}

private struct MemberManagementView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var memberOrderAnimation
    @StateObject private var autoScroller = MemberListAutoScroller()
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
        let profiles = store.displayProfiles
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
                || $0.relation.localizedCaseInsensitiveContains(query)
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
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(AppColor.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("添加家庭成员")
                }

                if filteredProfiles.isEmpty {
                    emptySearchState
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
            .background(MemberScrollViewResolver(autoScroller: autoScroller))
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
        .onChange(of: store.displayProfiles.map(\.id)) { _, _ in
            guard draggingProfileID == nil else { return }
            synchronizeProfileOrder()
        }
        .onDisappear {
            autoScroller.stop()
        }
        .sheet(isPresented: $showAddMember) {
            MemberEditorView(profile: nil)
        }
        .sheet(item: $editingProfile) { profile in
            MemberEditorView(profile: profile)
        }
    }

    private var listTitle: String {
        if searchText.isEmpty {
            return store.appLanguage.format("全部成员（%lld 人）", filteredProfiles.count)
        }
        return store.appLanguage.format("搜索结果（%lld 人）", filteredProfiles.count)
    }

    private func memberDetail(_ profile: UserProfile) -> String {
        store.appLanguage.format(
            "%@ · %@ cm · %lld 岁",
            store.appLanguage.text(profile.relation),
            profile.heightCM.formatted(2),
            profile.age
        )
    }

    private var searchField: some View {
        MemberSearchField(text: $searchText)
    }

    @ViewBuilder
    private func memberRow(_ profile: UserProfile) -> some View {
        let isSelected = profile.id == store.displaySelectedProfileID
        let isDragging = draggingProfileID == profile.id

        let row = memberRowVisual(profile, isSelected: isSelected, showsActions: true)
            .overlay {
                memberRowActions(profile, isSelected: isSelected)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: MemberRowFramePreferenceKey.self,
                        value: [profile.id: geo.frame(in: .named(Self.coordinateSpaceName))]
                    )
                }
            )
            .opacity(isDragging ? 0 : 1)
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
        isSelected: Bool,
        showsActions: Bool
    ) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 14) {
                MemberAvatarView(avatar: profile.avatar, width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(profile.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColor.ink)
                            .lineLimit(1)
                        if isSelected { StatusPill(text: "当前") }
                    }
                    Text(memberDetail(profile))
                        .font(.caption)
                        .foregroundStyle(AppColor.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if showsActions {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AppColor.mint : AppColor.secondary.opacity(0.38))
                }
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
        .background(isSelected ? AppColor.paleMint.opacity(0.72) : Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(isSelected ? AppColor.mint.opacity(0.25) : AppColor.mint.opacity(0.07))
        )
    }

    private func memberRowActions(_ profile: UserProfile, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                store.selectDisplayProfile(profile.id)
            } label: {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(draggingProfileID != nil)
            .accessibilityLabel(store.appLanguage.format("选择%@", profile.name))
            .accessibilityValue(isSelected ? store.appLanguage.text("当前成员") : "")

            Color.clear
                .frame(width: 1, height: 32)

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
        if let state = dragState {
            memberRowVisual(
                state.profile,
                isSelected: state.profile.id == store.displaySelectedProfileID,
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
                      case .second(true, let drag) = value,
                      let drag else { return }
                activateDragging(profileID, with: drag)
                updateDragging(profileID, with: drag)
            }
            .onEnded { _ in
                if draggingProfileID == profileID {
                    finishDragging()
                }
            }
    }

    private func activateDragging(_ profileID: UUID, with drag: DragGesture.Value) {
        guard dragState == nil,
              let profile = orderedProfiles.first(where: { $0.id == profileID }),
              let frame = memberFrames[profileID] else { return }
        dragState = MemberDragState(
            profile: profile,
            location: drag.location,
            layoutStartCenter: CGPoint(x: frame.midX, y: frame.midY),
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
        state.location = drag.location
        state.hitTestLocation = CGPoint(
            x: state.layoutStartCenter.x + drag.translation.width,
            y: state.layoutStartCenter.y + drag.translation.height
        )
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
        let currentOrder = store.displayProfiles.map(\.id)
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

    private var emptySearchState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title2)
                .foregroundStyle(AppColor.sky)
            Text("没有找到匹配的成员")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.ink)
            Text("可以换一个姓名或关系关键词。")
                .font(.caption)
                .foregroundStyle(AppColor.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

private final class MemberListAutoScroller: ObservableObject {
    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    private var velocity: CGFloat = 0
    private var previousTimestamp: CFTimeInterval?

    func attach(toAncestorOf view: UIView) {
        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                self.scrollView = scrollView
                return
            }
            ancestor = current.superview
        }
    }

    func update(fingerY: CGFloat, viewportHeight: CGFloat) {
        guard viewportHeight > 0 else {
            stop()
            return
        }
        let edgeSize = min(96, viewportHeight * 0.22)
        let maximumSpeed: CGFloat = 520
        if fingerY < edgeSize {
            let intensity = min(1, max(0, (edgeSize - fingerY) / edgeSize))
            setVelocity(-maximumSpeed * intensity * intensity)
        } else if fingerY > viewportHeight - edgeSize {
            let intensity = min(1, max(0, (fingerY - viewportHeight + edgeSize) / edgeSize))
            setVelocity(maximumSpeed * intensity * intensity)
        } else {
            stop()
        }
    }

    func stop() {
        velocity = 0
        previousTimestamp = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    private func setVelocity(_ velocity: CGFloat) {
        self.velocity = velocity
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let scrollView else {
            stop()
            return
        }
        let elapsed = previousTimestamp.map { min(link.timestamp - $0, 1.0 / 30.0) } ?? 0
        previousTimestamp = link.timestamp
        guard elapsed > 0 else { return }

        let minimumY = -scrollView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let proposedY = scrollView.contentOffset.y + velocity * elapsed
        let clampedY = min(maximumY, max(minimumY, proposedY))
        guard abs(clampedY - scrollView.contentOffset.y) > 0.1 else {
            stop()
            return
        }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: clampedY), animated: false)
    }
}

private struct MemberScrollViewResolver: UIViewRepresentable {
    let autoScroller: MemberListAutoScroller

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        resolve(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        resolve(from: uiView)
    }

    private func resolve(from view: UIView) {
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            autoScroller.attach(toAncestorOf: view)
        }
    }
}

private enum MemberEditorDropdown: Equatable {
    case relation
    case biologicalSex
}

private struct MemberEditorView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.dismiss) private var dismiss
    private let isNew: Bool
    @State private var draft: UserProfile
    @State private var heightText: String
    @State private var confirmDelete = false
    @State private var expandedDropdown: MemberEditorDropdown?

    private let relations = ["本人", "伴侣", "父母", "子女", "其他"]

    init(profile: UserProfile?) {
        isNew = profile == nil
        let initialDraft = profile ?? UserProfile(name: "", relation: "其他")
        _draft = State(initialValue: initialDraft)
        _heightText = State(initialValue: initialDraft.heightCM.formatted(.number.precision(.fractionLength(0...2))))
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
                            guard let heightCM = parsedHeight else { return }
                            draft.heightCM = heightCM
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
                            case .relation:
                                AppDropdownMenuLayer(
                                    anchorFrame: proxy[anchor],
                                    availableSize: proxy.size,
                                    options: relations,
                                    selection: draft.relation,
                                    title: { $0 },
                                    appearance: .compact,
                                    onSelect: { relation in
                                        draft.relation = relation
                                        dismissDropdown()
                                    },
                                    onDismiss: dismissDropdown
                                )
                            case .biologicalSex:
                                AppDropdownMenuLayer(
                                    anchorFrame: proxy[anchor],
                                    availableSize: proxy.size,
                                    options: UserProfile.BiologicalSex.allCases,
                                    selection: draft.biologicalSex,
                                    title: { $0.rawValue },
                                    appearance: .compact,
                                    onSelect: { biologicalSex in
                                        draft.biologicalSex = biologicalSex
                                        dismissDropdown()
                                    },
                                    onDismiss: dismissDropdown
                                )
                            }
                        }
                    }
                }
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
            MemberAvatarPicker(selection: draft.avatar) { draft.avatar = $0 }
                .equatable()
        }
    }

    private var informationPanel: some View {
        SettingsPanel(title: "成员信息", icon: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("姓名或昵称")
                MemberNameInput(text: $draft.name)
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("与我的关系")
                AppDropdownField(
                    value: draft.relation,
                    icon: "person.2.fill",
                    accessibilityLabel: "与我的关系",
                    isExpanded: expandedDropdown == .relation,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.relation) }
                )
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("生理性别")
                AppDropdownField(
                    value: draft.biologicalSex.rawValue,
                    icon: "person.crop.circle",
                    accessibilityLabel: "生理性别",
                    isExpanded: expandedDropdown == .biologicalSex,
                    appearance: .compact,
                    onToggle: { toggleDropdown(.biologicalSex) }
                )
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("出生日期")
                HStack {
                    Image(systemName: "calendar").foregroundStyle(AppColor.sky)
                    DatePicker("出生日期", selection: $draft.birthDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AppColor.mint)
                    Spacer()
                }
                .settingsInputSurface()
            }

            SettingsSeparator()

            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("身高")
                MemberHeightInput(text: $heightText)
            }

            SettingsSeparator()

            SettingsSwitch(
                title: "运动员模式",
                detail: "仅在长期高强度训练时开启，用于调整身体成分估算参数。",
                isOn: $draft.athleteMode
            )
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

    @ViewBuilder
    private var deletePanel: some View {
        if !isNew, store.displayProfiles.count > 1 {
            SettingsPanel(title: "成员管理", icon: "person.crop.circle.badge.minus") {
                Button {
                    showDeleteConfirmation()
                } label: {
                    Label("删除成员", systemImage: "trash")
                }
                .buttonStyle(MintActionButtonStyle(isDestructive: true))
                Text("删除成员不会自动删除其历史测量记录。")
                    .font(.caption)
                    .foregroundStyle(AppColor.secondary)
            }
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedHeight.map { (50...250).contains($0) } == true
    }

    private var parsedHeight: Double? {
        let normalized = heightText
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
                .foregroundStyle(AppColor.mint)
            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: "搜索姓名或关系",
                returnKeyType: .done,
                onSubmit: { isFocused = false }
            )
            .frame(minHeight: 24)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.secondary.opacity(0.65))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(AppColor.paleMint.opacity(0.68), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isFocused ? AppColor.mint.opacity(0.55) : AppColor.mint.opacity(0.10), lineWidth: isFocused ? 1.5 : 1)
                .allowsHitTesting(false)
        }
    }
}

private struct MemberAvatarPicker: View, Equatable {
    @Environment(\.appLanguage) private var language
    let selection: MemberAvatar
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
                                    .foregroundStyle(.white, AppColor.mint)
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
                placeholder: "请输入姓名或昵称",
                returnKeyType: .done,
                onSubmit: { isFocused = false }
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
            Text("cm")
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
