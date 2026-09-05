import SwiftUI
import UIKit

@MainActor
enum KeyboardFocus {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

enum AppColor {
    // Fresh health palette: soft natural surfaces with clear, accessible accents.
    static let ink = adaptive(light: 0x12332E, dark: 0xE7F5F1)
    static let secondary = adaptive(light: 0x5C7873, dark: 0x9BB8B2)
    static let canvas = adaptive(light: 0xF6FCFA, dark: 0x0C1715)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x142522)
    static let mint = Color(red: 0.08, green: 0.68, blue: 0.55)
    static let lime = Color(red: 0.74, green: 0.91, blue: 0.64)
    static let paleMint = adaptive(light: 0xE6FAF2, dark: 0x173A32)
    static let sky = Color(red: 0.43, green: 0.76, blue: 0.90)
    static let violet = Color(red: 0.58, green: 0.66, blue: 0.88)
    static let apricot = Color(red: 0.98, green: 0.67, blue: 0.43)
    static let rose = Color(red: 0.94, green: 0.55, blue: 0.61)
    static let bottomNavigationSelected = Color(red: 38 / 255, green: 155 / 255, blue: 112 / 255)
    static let bottomNavigationInactive = Color(red: 0.62, green: 0.63, blue: 0.75)
    static let bottomNavigationSurface = surface

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    // Distinct, calm series colors keep adjacent body-metric charts easy to scan.
    static let trendWeight = TrendMetricPalette.weight
    static let trendBMI = TrendMetricPalette.bmi
    static let trendBodyFat = TrendMetricPalette.bodyFat
    static let trendFatMass = TrendMetricPalette.fatMass
    static let trendMuscleMass = TrendMetricPalette.muscleMass
    static let trendMusclePercent = TrendMetricPalette.musclePercent
    static let trendWaterPercent = TrendMetricPalette.waterPercent
    static let trendWaterMass = TrendMetricPalette.waterMass
    static let trendProteinPercent = TrendMetricPalette.proteinPercent
    static let trendProteinMass = TrendMetricPalette.proteinMass
    static let trendBoneMass = TrendMetricPalette.boneMass
    static let trendBonePercent = TrendMetricPalette.bonePercent
    static let trendVisceralFat = TrendMetricPalette.visceralFat
    static let trendBasalMetabolism = TrendMetricPalette.basalMetabolism

    static func memberTheme(for avatar: MemberAvatar) -> MemberVisualTheme {
        switch avatar {
        case .child, .childDaughter:
            MemberVisualTheme(primary: apricot, secondary: rose)
        case .youth, .teenDaughter:
            MemberVisualTheme(primary: sky, secondary: violet)
        case .adult, .father:
            MemberVisualTheme(primary: mint, secondary: sky)
        case .senior, .paternalGrandfather:
            MemberVisualTheme(primary: violet, secondary: rose)
        case .maternalGrandfather, .maternalGrandmother:
            MemberVisualTheme(primary: rose, secondary: mint)
        }
    }
}

struct MemberVisualTheme {
    let primary: Color
    let secondary: Color
}

struct AppPageBackground: View {
    let avatar: MemberAvatar

    var body: some View {
        let theme = AppColor.memberTheme(for: avatar)

        ZStack {
            LinearGradient(
                colors: [AppColor.paleMint, AppColor.canvas, AppColor.sky.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    theme.primary.opacity(0.22),
                    theme.secondary.opacity(0.10),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SoftCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(AppColor.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
            .shadow(color: AppColor.mint.opacity(0.08), radius: 18, y: 8)
    }
}

struct StatusPill: View {
    let text: String
    var color: Color = AppColor.mint
    var backgroundColor: Color? = nil

    var body: some View {
        AppLocalizedText(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor ?? color.opacity(0.11), in: Capsule())
    }
}

struct ScaleDeviceLabel: View {
    let title: String
    var iconSize: CGFloat = 13

    var body: some View {
        Label {
            AppLocalizedText(title)
        } icon: {
            Image("ScaleDeviceTabIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
        }
    }
}

struct MainPageTitle: View {
    let text: String

    var body: some View {
        AppLocalizedText(text)
            .font(.largeTitle.bold())
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private enum MainPageLayout {
    static let topInset: CGFloat = 8
}

private struct RootNavigationControllerHandlerKey: EnvironmentKey {
    static let defaultValue: (UINavigationController) -> Void = { _ in }
}

private extension EnvironmentValues {
    var rootNavigationControllerHandler: (UINavigationController) -> Void {
        get { self[RootNavigationControllerHandlerKey.self] }
        set { self[RootNavigationControllerHandlerKey.self] = newValue }
    }
}

extension View {
    func mainPageTopInset() -> some View {
        modifier(MainPageTopInsetModifier())
    }

    func onRootNavigationControllerResolved(
        _ handler: @escaping (UINavigationController) -> Void
    ) -> some View {
        environment(\.rootNavigationControllerHandler, handler)
    }

    func localizedNavigationBackButton() -> some View {
        modifier(LocalizedNavigationBackButtonModifier())
    }
}

private struct MainPageTopInsetModifier: ViewModifier {
    @Environment(\.rootNavigationControllerHandler) private var navigationControllerHandler

    func body(content: Content) -> some View {
        content
            .contentMargins(.top, MainPageLayout.topInset, for: .scrollContent)
            .background(NavigationControllerObserver(onResolve: navigationControllerHandler))
    }
}

private struct NavigationControllerObserver: UIViewControllerRepresentable {
    let onResolve: (UINavigationController) -> Void

    func makeUIViewController(context: Context) -> NavigationControllerResolver {
        let resolver = NavigationControllerResolver()
        resolver.onResolve = onResolve
        return resolver
    }

    func updateUIViewController(_ controller: NavigationControllerResolver, context: Context) {
        controller.onResolve = onResolve
        controller.resolveNavigationController()
    }

    static func dismantleUIViewController(
        _ controller: NavigationControllerResolver,
        coordinator: Void
    ) {
        controller.onResolve = nil
    }
}

private struct LocalizedNavigationBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .background(InteractivePopGestureEnabler())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label(language.text(.back), systemImage: "chevron.left")
                    }
                }
            }
    }
}

/// Keeping a custom back button hidden disables UIKit's interactive pop gesture.
/// Resolve the enclosing navigation controller and restore the native edge swipe
/// while the destination is visible.
private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> NavigationControllerResolver {
        let resolver = NavigationControllerResolver()
        resolver.onResolve = context.coordinator.attach(to:)
        return resolver
    }

    func updateUIViewController(_ controller: NavigationControllerResolver, context: Context) {
        controller.onResolve = context.coordinator.attach(to:)
        controller.resolveNavigationController()
    }

    static func dismantleUIViewController(
        _ controller: NavigationControllerResolver,
        coordinator: Coordinator
    ) {
        controller.onResolve = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var navigationController: UINavigationController?
        private weak var originalDelegate: UIGestureRecognizerDelegate?

        func attach(to navigationController: UINavigationController) {
            guard self.navigationController !== navigationController else {
                navigationController.interactivePopGestureRecognizer?.isEnabled =
                    navigationController.viewControllers.count > 1
                return
            }

            detach()
            self.navigationController = navigationController

            guard let gestureRecognizer = navigationController.interactivePopGestureRecognizer else {
                return
            }
            originalDelegate = gestureRecognizer.delegate
            gestureRecognizer.delegate = self
            gestureRecognizer.isEnabled = navigationController.viewControllers.count > 1
        }

        func detach() {
            guard let gestureRecognizer = navigationController?.interactivePopGestureRecognizer else {
                navigationController = nil
                originalDelegate = nil
                return
            }
            if gestureRecognizer.delegate === self {
                gestureRecognizer.delegate = originalDelegate
            }
            navigationController = nil
            originalDelegate = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
                && navigationController.transitionCoordinator == nil
        }
    }
}

@MainActor
private final class NavigationControllerResolver: UIViewController {
    var onResolve: ((UINavigationController) -> Void)?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resolveNavigationController()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resolveNavigationController()
    }

    func resolveNavigationController() {
        guard let navigationController else { return }
        onResolve?(navigationController)
    }
}

enum SettingsPanelIcon {
    case system(String)
    case asset(String)
}

struct SettingsPanel<Content: View>: View {
    let title: String
    let icon: SettingsPanelIcon
    let headerValue: String?
    let headerActionTitle: String?
    let headerAction: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        icon: String,
        headerValue: String? = nil,
        headerActionTitle: String? = nil,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = .system(icon)
        self.headerValue = headerValue
        self.headerActionTitle = headerActionTitle
        self.headerAction = headerAction
        self.content = content()
    }

    init(
        title: String,
        assetIcon: String,
        headerValue: String? = nil,
        headerActionTitle: String? = nil,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = .asset(assetIcon)
        self.headerValue = headerValue
        self.headerActionTitle = headerActionTitle
        self.headerAction = headerAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                switch icon {
                case let .system(systemIcon):
                    Image(systemName: systemIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .frame(width: 26, height: 26)
                        .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                case let .asset(assetName):
                    Image(assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .foregroundStyle(AppColor.mint)
                        .frame(width: 26, height: 26)
                        .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                AppLocalizedText(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Spacer()
                if let headerValue {
                    Text(headerValue)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppColor.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppColor.canvas, in: Capsule())
                }
                if let headerActionTitle, let headerAction {
                    Button(action: headerAction) {
                        Label {
                            AppLocalizedText(headerActionTitle)
                        } icon: {
                            Image(systemName: "plus")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.mint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppColor.paleMint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
        .shadow(color: AppColor.mint.opacity(0.06), radius: 16, y: 6)
    }
}

struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(AppColor.mint.opacity(0.10))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct SettingsSwitch: View {
    @Environment(\.appLanguage) private var language
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    init(title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    AppLocalizedText(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    if let detail {
                        AppLocalizedText(detail)
                            .font(.caption)
                            .foregroundStyle(AppColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? AppColor.mint : AppColor.secondary.opacity(0.18))
                    Circle()
                        .fill(.white)
                        .padding(3)
                        .shadow(color: AppColor.ink.opacity(0.12), radius: 3, y: 1)
                }
                .frame(width: 48, height: 28)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.text(title))
        .accessibilityValue(language.text(isOn ? "已开启" : "已关闭"))
        .accessibilityHint(detail.map(language.text) ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

struct AppDropdownAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

enum AppDropdownAppearance {
    case tinted
    case compact
}

struct AppDropdownField: View {
    @Environment(\.appLanguage) private var language
    let value: String
    let icon: String
    let accessibilityLabel: String
    let isExpanded: Bool
    var appearance: AppDropdownAppearance = .tinted
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 34, height: 34)
                    .background(
                        appearance == .compact ? AppColor.paleMint : AppColor.surface.opacity(0.88),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                AppLocalizedText(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.ink)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.mint)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                appearance == .compact
                    ? AppColor.canvas
                    : AppColor.paleMint.opacity(isExpanded ? 0.90 : 0.72),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isExpanded
                            ? AppColor.mint.opacity(appearance == .compact ? 1 : 0.60)
                            : AppColor.mint.opacity(appearance == .compact ? 0.18 : 0.14),
                        lineWidth: isExpanded ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .anchorPreference(key: AppDropdownAnchorPreferenceKey.self, value: .bounds) {
            isExpanded ? $0 : nil
        }
        .accessibilityLabel(language.text(accessibilityLabel))
        .accessibilityValue(language.text(value))
        .accessibilityHint(language.text(isExpanded ? "点击收起选项" : "点击展开选项"))
    }
}

struct AppEditableDropdownField: View {
    @Environment(\.appLanguage) private var language
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let icon: String
    let accessibilityLabel: String
    let isExpanded: Bool
    var appearance: AppDropdownAppearance = .tinted
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.mint)
                .frame(width: 34, height: 34)
                .background(
                    appearance == .compact ? AppColor.paleMint : AppColor.surface.opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            ResponsiveTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder,
                returnKeyType: .done,
                autocorrectionType: .no
            )
            .frame(minHeight: 24)

            Button(action: onToggle) {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.mint)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(accessibilityLabel))
            .accessibilityHint(language.text(isExpanded ? "点击收起选项" : "点击展开选项"))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .background(
            appearance == .compact
                ? AppColor.canvas
                : AppColor.paleMint.opacity(isExpanded ? 0.90 : 0.72),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isExpanded
                        ? AppColor.mint.opacity(appearance == .compact ? 1 : 0.60)
                        : AppColor.mint.opacity(appearance == .compact ? 0.18 : 0.14),
                    lineWidth: isExpanded ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .anchorPreference(key: AppDropdownAnchorPreferenceKey.self, value: .bounds) {
            isExpanded ? $0 : nil
        }
    }
}

struct AppDropdownMenuLayer<Option: Hashable>: View {
    let anchorFrame: CGRect
    let availableSize: CGSize
    let options: [Option]
    let isSelected: (Option) -> Bool
    let title: (Option) -> String
    var detail: ((Option) -> String?)? = nil
    var appearance: AppDropdownAppearance = .tinted
    let onSelect: (Option) -> Void
    let onDismiss: () -> Void

    var body: some View {
        let rowHeight: CGFloat = detail == nil ? (appearance == .compact ? 48 : 44) : 58
        let rowSpacing: CGFloat = 4
        let listPadding: CGFloat = 12 // matches the `.padding(6)` applied around the option list
        // Cap visible rows so long option lists (e.g. languages) scroll instead of forcing the menu to the top of the screen.
        let maxVisibleRows: CGFloat = 6
        let visibleRows = min(CGFloat(options.count), maxVisibleRows)
        let desiredHeight = visibleRows * rowHeight + max(0, visibleRows - 1) * rowSpacing + listPadding
        let spaceBelow = availableSize.height - anchorFrame.maxY - 10
        let spaceAbove = anchorFrame.minY - 10
        let opensBelow = spaceBelow >= desiredHeight || spaceBelow >= spaceAbove
        let menuHeight = min(desiredHeight, max(80, opensBelow ? spaceBelow : spaceAbove))
        let menuY = opensBelow
            ? anchorFrame.maxY + 7
            : max(8, anchorFrame.minY - menuHeight - 7)
        let menuWidth = min(anchorFrame.width, availableSize.width - 16)
        let menuX = min(
            max(anchorFrame.minX, 8),
            max(8, availableSize.width - menuWidth - 8)
        )

        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(options, id: \.self) { option in
                        let optionIsSelected = isSelected(option)

                        Button {
                            onSelect(option)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: optionIsSelected ? "checkmark.circle.fill" : "circle")
                                    .font(appearance == .compact ? .subheadline : .body)
                                    .foregroundStyle(
                                        optionIsSelected
                                            ? AppColor.mint
                                            : AppColor.secondary.opacity(0.30)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    AppLocalizedText(title(option))
                                        .font(.subheadline.weight(optionIsSelected ? .semibold : .medium))
                                        .foregroundStyle(
                                            appearance == .compact && !optionIsSelected
                                                ? AppColor.secondary
                                                : AppColor.ink
                                        )

                                    if let optionDetail = detail?(option) {
                                        AppLocalizedText(optionDetail)
                                            .font(.caption)
                                            .foregroundStyle(AppColor.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, appearance == .compact ? 10 : 14)
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                            .background {
                                if optionIsSelected {
                                    RoundedRectangle(cornerRadius: appearance == .compact ? 10 : 12, style: .continuous)
                                        .fill(
                                            appearance == .compact
                                                ? AnyShapeStyle(AppColor.paleMint.opacity(0.72))
                                                : AnyShapeStyle(
                                                    LinearGradient(
                                                        colors: [
                                                            AppColor.surface.opacity(0.96),
                                                            AppColor.mint.opacity(0.13),
                                                            AppColor.sky.opacity(0.12)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        )
                                        .overlay {
                                            if appearance == .tinted {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(AppColor.mint.opacity(0.12))
                                            }
                                        }
                                }
                            }
                            .contentShape(
                                RoundedRectangle(cornerRadius: appearance == .compact ? 10 : 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(optionIsSelected ? .isSelected : [])
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.hidden)
            .frame(width: menuWidth, height: menuHeight)
            .background {
                RoundedRectangle(cornerRadius: appearance == .compact ? 14 : 16, style: .continuous)
                    .fill(
                        appearance == .compact
                            ? AnyShapeStyle(AppColor.surface)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        AppColor.surface.opacity(0.99),
                                        AppColor.paleMint.opacity(0.97)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: appearance == .compact ? 14 : 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: appearance == .compact ? 14 : 16, style: .continuous)
                    .stroke(AppColor.mint.opacity(appearance == .compact ? 0.14 : 0.18))
                    .allowsHitTesting(false)
            }
            .shadow(
                color: AppColor.ink.opacity(appearance == .compact ? 0.12 : 0.10),
                radius: appearance == .compact ? 16 : 18,
                y: appearance == .compact ? 6 : 8
            )
            .offset(x: menuX, y: menuY)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: opensBelow ? .top : .bottom)))
        }
        .frame(width: availableSize.width, height: availableSize.height)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

struct MintActionButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isDestructive ? AppColor.rose : .white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(
                isDestructive ? AppColor.rose.opacity(0.10) : AppColor.mint.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                if isDestructive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColor.rose.opacity(0.20))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DestructiveConfirmationOverlay: View {
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            VStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(AppColor.rose)
                    .frame(width: 58, height: 58)
                    .background(
                        AppColor.rose.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                VStack(spacing: 8) {
                    AppLocalizedText(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColor.ink)

                    AppLocalizedText(message)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button(role: .destructive, action: onConfirm) {
                        AppLocalizedText(confirmTitle)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MintActionButtonStyle(isDestructive: true))

                    Button(action: onCancel) {
                        Text("取消")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .background(
                                AppColor.paleMint.opacity(0.82),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColor.mint.opacity(0.10))
            )
            .shadow(color: AppColor.ink.opacity(0.16), radius: 28, y: 12)
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

struct ScaleDeviceIconView: View {
    var size: CGFloat = 64
    var iconSize: CGFloat = 28
    var accent: Color = AppColor.mint

    var body: some View {
        Image("ScaleDeviceTabIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(accent)
            .frame(width: iconSize, height: iconSize)
            .frame(width: size, height: size)
            .background(
                accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            )
    }
}

struct BodyFatRateIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.78, height: size)

            Text("%")
                .font(.system(size: max(5, size * 0.30), weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct VisceralFatIcon: View {
    var size: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill()
                    .frame(width: side * 0.20, height: side * 0.20)
                    .position(x: side * 0.50, y: side * 0.13)

                Path { path in
                    path.move(to: CGPoint(x: side * 0.24, y: side * 0.34))
                    path.addQuadCurve(
                        to: CGPoint(x: side * 0.35, y: side * 0.92),
                        control: CGPoint(x: side * 0.27, y: side * 0.64)
                    )
                    path.move(to: CGPoint(x: side * 0.76, y: side * 0.34))
                    path.addQuadCurve(
                        to: CGPoint(x: side * 0.65, y: side * 0.92),
                        control: CGPoint(x: side * 0.73, y: side * 0.64)
                    )
                    path.move(to: CGPoint(x: side * 0.24, y: side * 0.34))
                    path.addQuadCurve(
                        to: CGPoint(x: side * 0.76, y: side * 0.34),
                        control: CGPoint(x: side * 0.50, y: side * 0.24)
                    )
                }
                .stroke(
                    style: StrokeStyle(
                        lineWidth: max(1, side * 0.075),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                Circle()
                    .strokeBorder(lineWidth: max(1, side * 0.065))
                    .frame(width: side * 0.31, height: side * 0.31)
                    .position(x: side * 0.50, y: side * 0.62)

                Circle()
                    .fill()
                    .frame(width: side * 0.09, height: side * 0.09)
                    .position(x: side * 0.50, y: side * 0.62)
            }
            .frame(width: side, height: side)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            AppLocalizedText(title)
                .font(.subheadline)
                .foregroundStyle(AppColor.secondary)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppColor.ink)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    func pageBackground() -> some View {
        modifier(AppPageBackgroundModifier())
    }
}

private struct AppPageBackgroundModifier: ViewModifier {
    @EnvironmentObject private var store: MeasurementStore

    func body(content: Content) -> some View {
        content.background(
            AppPageBackground(avatar: store.displaySelectedProfile.avatar)
                .ignoresSafeArea()
        )
    }
}

extension Double {
    func formatted(_ digits: Int = 2) -> String { formatted(.number.precision(.fractionLength(digits))) }
}
