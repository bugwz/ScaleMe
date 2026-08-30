import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MeasurementStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MainPageTitle(text: "设置")
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
                Text("用户信息")
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.ink)
                Spacer()
                StatusPill(text: "\(store.displayProfiles.count) 人", color: AppColor.sky)
            }

            NavigationLink {
                MemberManagementView()
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
            .accessibilityLabel("当前成员，\(store.displaySelectedProfile.name)，管理全部成员")
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用设置")
                .font(.title3.bold())
                .foregroundStyle(AppColor.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                NavigationLink {
                    DisplaySettingsView()
                } label: {
                    settingsRow("显示设置", detail: "体重单位、连续称重与模拟数据", icon: "slider.horizontal.3", color: AppColor.mint)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    DataSyncSettingsView()
                } label: {
                    settingsRow("数据同步", detail: "iCloud 配置与测量数据", icon: "icloud.fill", color: AppColor.sky)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    CommunicationRulesView()
                } label: {
                    settingsRow("通信协议", detail: "设备识别与数据解析", icon: "point.3.connected.trianglepath.dotted", color: AppColor.violet)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    DeveloperDiagnosticsView()
                } label: {
                    settingsRow("开发诊断", detail: "输入响应计时与日志导出", icon: "wrench.and.screwdriver.fill", color: AppColor.apricot)
                }
                SettingsSeparator().padding(.leading, 68)
                NavigationLink {
                    AboutView()
                } label: {
                    settingsRow("关于观我", detail: "产品原则与版本信息", icon: "leaf.fill", color: AppColor.violet)
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
        "\(profile.relation) · \(profile.heightCM.formatted(2)) cm · \(profile.age) 岁"
    }
}

private struct MemberManagementView: View {
    @EnvironmentObject private var store: MeasurementStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var memberOrderAnimation
    @StateObject private var autoScroller = MemberListAutoScroller()
    @State private var searchText = ""
    @State private var showAddMember = false
    @State private var editingProfile: UserProfile?
    @State private var memberFrames: [UUID: CGRect] = [:]
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var draggingProfileID: UUID?
    @State private var dragLocation: CGPoint?
    @State private var dragGrabOffset: CGSize = .zero
    @State private var dragRowSize: CGSize = .zero
    @State private var hasResolvedDragTouch = false
    @State private var pendingRelocationTargetID: UUID?
    @State private var dragActivationFeedback = 0
    @State private var isDragLifted = false
    @State private var isSettlingDrag = false

    private static let coordinateSpaceName = "memberManagement"

    private var filteredProfiles: [UserProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.displayProfiles }
        return store.displayProfiles.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.relation.localizedCaseInsensitiveContains(query)
        }
    }

    private var canReorder: Bool {
        !store.isSimulationEnabled
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && store.profiles.count > 1
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                searchField

                if store.isSimulationEnabled {
                    simulationNotice
                }

                HStack {
                    Text(listTitle)
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
                    .disabled(store.isSimulationEnabled)
                    .opacity(store.isSimulationEnabled ? 0.45 : 1)
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
            if let draggedID = draggingProfileID,
               let location = dragLocation,
               frames[draggedID]?.contains(location) == true {
                pendingRelocationTargetID = nil
            }
            if let draggedID = draggingProfileID, let location = dragLocation {
                relocate(draggedID, to: location, using: frames)
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
            return "全部成员（\(filteredProfiles.count) 人）"
        }
        return "搜索结果（\(filteredProfiles.count) 人）"
    }

    private var searchField: some View {
        MemberSearchField(text: $searchText)
    }

    private var simulationNotice: some View {
        Label("模拟数据模式下可切换成员，但不能编辑或新增资料。", systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(AppColor.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.sky.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func memberRow(_ profile: UserProfile) -> some View {
        let isSelected = profile.id == store.displaySelectedProfileID
        let isDragging = draggingProfileID == profile.id

        let row = memberRowSurface(profile, isSelected: isSelected)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: MemberRowFramePreferenceKey.self,
                        value: [profile.id: geo.frame(in: .named(Self.coordinateSpaceName))]
                    )
                }
            )
            .opacity(isDragging && isDragLifted ? 0.14 : 1)
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

    private func memberRowSurface(_ profile: UserProfile, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                store.selectDisplayProfile(profile.id)
            } label: {
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
                        Text("\(profile.relation) · \(profile.heightCM.formatted(2)) cm · \(profile.age) 岁")
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AppColor.mint : AppColor.secondary.opacity(0.38))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择\(profile.name)")
            .accessibilityValue(isSelected ? "当前成员" : "")

            if !store.isSimulationEnabled {
                SettingsSeparator()
                    .frame(width: 1, height: 32)
                Button {
                    editingProfile = profile
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .frame(width: 38, height: 38)
                        .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑\(profile.name)的资料")
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

    @ViewBuilder
    private var dragPreview: some View {
        if let profileID = draggingProfileID,
           let profile = store.profiles.first(where: { $0.id == profileID }),
           let location = dragLocation {
            memberRowSurface(profile, isSelected: profile.id == store.selectedProfileID)
                .frame(width: dragRowSize.width, height: dragRowSize.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(AppColor.mint.opacity(isDragLifted ? 0.8 : 0.3), lineWidth: 2)
                )
                .scaleEffect(reduceMotion || isSettlingDrag || !isDragLifted ? 1 : 1.025)
                .shadow(
                    color: AppColor.mint.opacity(isDragLifted && !isSettlingDrag ? 0.24 : 0),
                    radius: isDragLifted && !isSettlingDrag ? 16 : 0,
                    y: isDragLifted && !isSettlingDrag ? 8 : 0
                )
                .position(
                    x: location.x - dragGrabOffset.width + dragRowSize.width / 2,
                    y: location.y - dragGrabOffset.height + dragRowSize.height / 2
                )
                .allowsHitTesting(false)
                .zIndex(10)
        }
    }

    private func reorderGesture(for profileID: UUID) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5, maximumDistance: 8)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(Self.coordinateSpaceName)
                )
            )
            .onChanged { value in
                guard canReorder, case .second(true, let drag) = value else { return }
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
        guard draggingProfileID == nil, let frame = memberFrames[profileID] else { return }
        KeyboardFocus.dismiss()
        draggingProfileID = profileID
        dragRowSize = frame.size
        dragLocation = CGPoint(x: frame.midX, y: frame.midY)
        dragGrabOffset = CGSize(width: frame.width / 2, height: frame.height / 2)
        hasResolvedDragTouch = false
        dragActivationFeedback += 1
        DispatchQueue.main.async {
            guard draggingProfileID == profileID else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.78)) {
                isDragLifted = true
            }
        }
    }

    private func updateDragging(_ profileID: UUID, with drag: DragGesture.Value) {
        guard draggingProfileID == profileID else { return }
        if !hasResolvedDragTouch, let frame = memberFrames[profileID] {
            dragGrabOffset = CGSize(
                width: drag.location.x - frame.minX,
                height: drag.location.y - frame.minY
            )
            hasResolvedDragTouch = true
        }
        dragLocation = drag.location
        relocate(profileID, to: drag.location, using: memberFrames)
        autoScroller.update(fingerY: drag.location.y, viewportHeight: scrollViewportHeight)
    }

    private func relocate(_ profileID: UUID, to location: CGPoint, using frames: [UUID: CGRect]) {
        if frames[profileID]?.contains(location) == true { return }
        let targetID = store.profiles
            .compactMap { profile -> (id: UUID, distance: CGFloat)? in
                guard profile.id != profileID, let frame = frames[profile.id] else { return nil }
                return (profile.id, abs(frame.midY - location.y))
            }
            .min { $0.distance < $1.distance }?
            .id
        guard let targetID, targetID != pendingRelocationTargetID else { return }
        pendingRelocationTargetID = targetID
        withAnimation(.snappy(duration: 0.16)) {
            store.moveProfile(profileID, onto: targetID)
        }
    }

    private func moveProfile(_ profileID: UUID, by offset: Int) {
        guard let sourceIndex = store.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        let targetIndex = sourceIndex + offset
        guard store.profiles.indices.contains(targetIndex) else { return }
        withAnimation(.snappy(duration: 0.16)) {
            store.moveProfile(profileID, onto: store.profiles[targetIndex].id)
        }
    }

    private func finishDragging() {
        autoScroller.stop()
        guard !reduceMotion,
              let profileID = draggingProfileID,
              let destination = memberFrames[profileID] else {
            resetDragState()
            return
        }
        withAnimation(.snappy(duration: 0.18), completionCriteria: .logicallyComplete) {
            isSettlingDrag = true
            dragLocation = CGPoint(
                x: destination.minX + dragGrabOffset.width,
                y: destination.minY + dragGrabOffset.height
            )
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        draggingProfileID = nil
        dragLocation = nil
        dragGrabOffset = .zero
        dragRowSize = .zero
        hasResolvedDragTouch = false
        pendingRelocationTargetID = nil
        isDragLifted = false
        isSettlingDrag = false
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
                .navigationTitle(isNew ? "添加成员" : "编辑成员")
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
                    message: "将删除“\(memberDisplayName)”的成员资料，已有测量记录仍会保留。",
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
        if !isNew, store.profiles.count > 1 {
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
        Text(title)
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
                    .accessibilityLabel("选择\(avatar.ageHint)人物形象")
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
