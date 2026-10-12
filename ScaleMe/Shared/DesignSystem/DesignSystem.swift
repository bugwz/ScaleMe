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

@MainActor
enum AppAccessibility {
    /// Announces short, meaningful state transitions without making rapidly
    /// changing measurement values into an always-chatty live region.
    static func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning, !message.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

struct AppVisualThemeTrait: UITraitDefinition {
    static let defaultValue = AppVisualTheme.standard
    // Invalidate dynamic colors throughout existing SwiftUI and UIKit views,
    // including cached tab content, presented sheets, and input accessories.
    static let affectsColorAppearance = true
}

enum AppColor {
    // The accessible palette is blue/orange-led, raises contrast, and avoids
    // red/green pairs for adjacent semantic accents.
    static let ink = adaptive(light: 0x12332E, dark: 0xE7F5F1, accessibleLight: 0x17202A, accessibleDark: 0xF4F7FA)
    static let secondary = adaptive(light: 0x5C7873, dark: 0x9BB8B2, accessibleLight: 0x44515E, accessibleDark: 0xBCC6CF)
    static let canvas = adaptive(light: 0xF6FCFA, dark: 0x0C1715, accessibleLight: 0xF8FAFC, accessibleDark: 0x101419)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x142522, accessibleLight: 0xFFFFFF, accessibleDark: 0x1A2027)
    static let mint = adaptive(light: 0x14AD8C, dark: 0x14AD8C, accessibleLight: 0x0067A5, accessibleDark: 0x56B4E9)
    static let lime = adaptive(light: 0xBDE8A3, dark: 0xBDE8A3, accessibleLight: 0xE69F00, accessibleDark: 0xF4C95D)
    static let paleMint = adaptive(light: 0xE6FAF2, dark: 0x173A32, accessibleLight: 0xE3F2FA, accessibleDark: 0x153348)
    static let sky = adaptive(light: 0x6DC2E6, dark: 0x6DC2E6, accessibleLight: 0xD55E00, accessibleDark: 0xF28E5B)
    static let violet = adaptive(light: 0x94A8E0, dark: 0x94A8E0, accessibleLight: 0x8A4C8B, accessibleDark: 0xCC79A7)
    static let apricot = adaptive(light: 0xFAAB6E, dark: 0xFAAB6E, accessibleLight: 0x9A6500, accessibleDark: 0xF0C04A)
    static let rose = adaptive(light: 0xF08C9C, dark: 0xF08C9C, accessibleLight: 0xB43B32, accessibleDark: 0xFF806B)
    static let bottomNavigationSelected = adaptive(light: 0x269B70, dark: 0x269B70, accessibleLight: 0x0067A5, accessibleDark: 0x56B4E9)
    static let bottomNavigationInactive = adaptive(light: 0x9EA1BF, dark: 0x9EA1BF, accessibleLight: 0x596674, accessibleDark: 0xAAB4BE)
    static let bottomNavigationSurface = surface
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0xFFFFFF, accessibleLight: 0xFFFFFF, accessibleDark: 0x101419)

    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        accessibleLight: UInt32,
        accessibleDark: UInt32
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let usesAccessiblePalette = traits[AppVisualThemeTrait.self] == .colorVisionAccessible
            let value = switch (usesAccessiblePalette, traits.userInterfaceStyle) {
            case (true, .dark): accessibleDark
            case (true, _): accessibleLight
            case (false, .dark): dark
            case (false, _): light
            }
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    // Metric colors switch to a color-vision-safe sequence in the accessible theme.
    static let trendWeight = adaptive(light: 0x14AD8C, dark: 0x14AD8C, accessibleLight: 0x0067A5, accessibleDark: 0x56B4E9)
    static let trendBMI = adaptive(light: 0x6DC2E6, dark: 0x6DC2E6, accessibleLight: 0xA55A00, accessibleDark: 0xE69F00)
    static let trendBodyFat = adaptive(light: 0xFAAB6E, dark: 0xFAAB6E, accessibleLight: 0x7A5195, accessibleDark: 0xCC79A7)
    static let trendFatMass = adaptive(light: 0xE8786E, dark: 0xE8786E, accessibleLight: 0xB43B32, accessibleDark: 0xFF806B)
    static let trendMuscleMass = adaptive(light: 0x52A869, dark: 0x52A869, accessibleLight: 0x3B5B92, accessibleDark: 0x8DA0CB)
    static let trendMusclePercent = adaptive(light: 0x1F9E9F, dark: 0x1F9E9F, accessibleLight: 0x8A6300, accessibleDark: 0xF0C04A)
    static let trendWaterPercent = adaptive(light: 0x408FD1, dark: 0x408FD1, accessibleLight: 0x007C91, accessibleDark: 0x66C2D0)
    static let trendWaterMass = adaptive(light: 0x4FB3C7, dark: 0x4FB3C7, accessibleLight: 0x9B4F96, accessibleDark: 0xD89BD3)
    static let trendBoneMass = adaptive(light: 0x94A8E0, dark: 0x94A8E0, accessibleLight: 0x2F6F4E, accessibleDark: 0x74C69D)
    static let trendBonePercent = adaptive(light: 0xAB85C9, dark: 0xAB85C9, accessibleLight: 0x6B5B00, accessibleDark: 0xCDBE63)
    static let trendVisceralFat = adaptive(light: 0xF08C9C, dark: 0xF08C9C, accessibleLight: 0x8B3F63, accessibleDark: 0xD989B0)
    static let trendBasalMetabolism = adaptive(light: 0xDB803D, dark: 0xDB803D, accessibleLight: 0x374C80, accessibleDark: 0x7E9BD3)

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
                .accessibilityHidden(true)
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
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isExpanded: Binding<Bool>?
    let title: String
    let icon: SettingsPanelIcon
    let iconColor: Color
    let iconBackgroundColor: Color
    let headerValue: String?
    let headerActionTitle: String?
    let headerAction: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        icon: String,
        iconColor: Color = AppColor.mint,
        iconBackgroundColor: Color = AppColor.paleMint,
        isExpanded: Binding<Bool>? = nil,
        headerValue: String? = nil,
        headerActionTitle: String? = nil,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isExpanded = isExpanded
        self.title = title
        self.icon = .system(icon)
        self.iconColor = iconColor
        self.iconBackgroundColor = iconBackgroundColor
        self.headerValue = headerValue
        self.headerActionTitle = headerActionTitle
        self.headerAction = headerAction
        self.content = content()
    }

    init(
        title: String,
        assetIcon: String,
        iconColor: Color = AppColor.mint,
        iconBackgroundColor: Color = AppColor.paleMint,
        isExpanded: Binding<Bool>? = nil,
        headerValue: String? = nil,
        headerActionTitle: String? = nil,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isExpanded = isExpanded
        self.title = title
        self.icon = .asset(assetIcon)
        self.iconColor = iconColor
        self.iconBackgroundColor = iconBackgroundColor
        self.headerValue = headerValue
        self.headerActionTitle = headerActionTitle
        self.headerAction = headerAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let isExpanded {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    header
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text(title))
                .accessibilityValue(language.text(isExpanded.wrappedValue ? "已展开" : "已收起"))
            } else {
                header
            }
            if isExpanded?.wrappedValue ?? true {
                content
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
        .shadow(color: AppColor.mint.opacity(0.06), radius: 16, y: 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            switch icon {
            case let .system(systemIcon):
                Image(systemName: systemIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconBackgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
            case let .asset(assetName):
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconBackgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
            }
            AppLocalizedText(title)
                .font(.headline)
                .foregroundStyle(AppColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let headerValue {
                Text(headerValue)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppColor.canvas, in: Capsule())
            }
            if let isExpanded {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                    .accessibilityHidden(true)
            }
            if isExpanded == nil, let headerActionTitle, let headerAction {
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
                        .fill(isOn ? AppColor.onAccent : AppColor.surface)
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
        .accessibilityRepresentation {
            Toggle(language.text(title), isOn: $isOn)
                .accessibilityHint(detail.map(language.text) ?? "")
        }
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
    case pill
}

struct AppDropdownField: View {
    @AccessibilityFocusState private var isAccessibilityFocused: Bool
    @Environment(\.appLanguage) private var language
    let value: String
    let icon: String
    let accessibilityLabel: String
    let isExpanded: Bool
    var appearance: AppDropdownAppearance = .tinted
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            if appearance == .pill {
                HStack(spacing: 5) {
                    AppLocalizedText(value)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(AppColor.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColor.mint.opacity(isExpanded ? 0.17 : 0.11), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppColor.mint.opacity(isExpanded ? 0.32 : 0), lineWidth: 1)
                }
                .contentShape(Capsule())
            } else {
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
        }
        .buttonStyle(.plain)
        .anchorPreference(key: AppDropdownAnchorPreferenceKey.self, value: .bounds) {
            isExpanded ? $0 : nil
        }
        .accessibilityLabel(language.text(accessibilityLabel))
        .accessibilityValue(language.text(value))
        .accessibilityHint(language.text(isExpanded ? "点击收起选项" : "点击展开选项"))
        .accessibilityFocused($isAccessibilityFocused)
        .onChange(of: isExpanded) { wasExpanded, expanded in
            if wasExpanded && !expanded { isAccessibilityFocused = true }
        }
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
            .accessibilityReturnFocus(when: isExpanded)
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
    @Environment(\.appLanguage) private var language
    @ScaledMetric(relativeTo: .body) private var rowScale: CGFloat = 1
    let anchorFrame: CGRect
    let availableSize: CGSize
    let options: [Option]
    let isSelected: (Option) -> Bool
    let title: (Option) -> String
    var detail: ((Option) -> String?)? = nil
    var preferredWidth: CGFloat? = nil
    var appearance: AppDropdownAppearance = .tinted
    let onSelect: (Option) -> Void
    let onDismiss: () -> Void

    @AccessibilityFocusState private var focusedOption: Option?

    var body: some View {
        let rowHeight: CGFloat = (detail == nil ? (appearance == .compact ? 48 : 44) : 58) * rowScale
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
        let requestedWidth = max(anchorFrame.width, preferredWidth ?? anchorFrame.width)
        let menuWidth = min(requestedWidth, availableSize.width - 16)
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
                            .frame(minHeight: rowHeight)
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
                        .accessibilityFocused($focusedOption, equals: option)
                        // Keep dismissal available from every option, including multi-select
                        // menus, without adding a visible control or changing menu geometry.
                        .accessibilityAction(named: Text(language.text("收起选项")), onDismiss)
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
        .accessibilityAction(.escape, onDismiss)
        .task {
            await Task.yield()
            focusedOption = options.first
        }
    }
}

struct MintActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isDestructive ? AppColor.rose : AppColor.onAccent)
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
            .opacity(isEnabled ? 1 : 0.48)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DestructiveConfirmationOverlay: View {
    @Environment(\.appLanguage) private var language
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    let countdownSeconds: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var remainingSeconds: Int
    @AccessibilityFocusState private var isTitleFocused: Bool

    init(
        icon: String,
        title: String,
        message: String,
        confirmTitle: String,
        countdownSeconds: Int = 0,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.countdownSeconds = countdownSeconds
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _remainingSeconds = State(initialValue: countdownSeconds)
    }

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
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)

                    AppLocalizedText(message)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button(role: .destructive, action: onConfirm) {
                        Group {
                            if remainingSeconds > 0 {
                                HStack(spacing: 6) {
                                    AppLocalizedText(confirmTitle)
                                    Text(language.format("剩余 %lld 秒", Int64(remainingSeconds)))
                                }
                            } else {
                                AppLocalizedText(confirmTitle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MintActionButtonStyle(isDestructive: true))
                    .disabled(remainingSeconds > 0)

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
        .onAppear {
            isTitleFocused = true
        }
        .accessibilityAction(.escape, onCancel)
        .task(id: countdownSeconds) {
            remainingSeconds = countdownSeconds
            while remainingSeconds > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                remainingSeconds -= 1
            }
        }
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
            .accessibilityHidden(true)
    }
}

struct PulsingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseStartedAt = Date()

    let diameter: CGFloat
    let lineWidth: CGFloat
    let isActive: Bool

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .overlay {
                TimelineView(.animation(paused: !isActive || reduceMotion)) { timeline in
                    Canvas { context, size in
                        let progress = pulseProgress(at: timeline.date)
                        let renderedDiameter = diameter * (0.98 + 0.08 * progress)
                        let origin = CGPoint(
                            x: (size.width - renderedDiameter) / 2,
                            y: (size.height - renderedDiameter) / 2
                        )
                        let ringRect = CGRect(
                            origin: origin,
                            size: CGSize(width: renderedDiameter, height: renderedDiameter)
                        )
                        let opacity = 0.6 - 0.32 * progress

                        context.stroke(
                            Path(ellipseIn: ringRect),
                            with: .color(AppColor.mint.opacity(0.08 * opacity)),
                            lineWidth: lineWidth
                        )
                    }
                    .frame(width: drawingSize, height: drawingSize)
                }
            }
            .accessibilityHidden(true)
            .onChange(of: isActive) { _, isNowActive in
                if isNowActive {
                    pulseStartedAt = Date()
                }
            }
    }

    private var drawingSize: CGFloat {
        diameter * 1.06 + lineWidth
    }

    private func pulseProgress(at date: Date) -> CGFloat {
        guard isActive, !reduceMotion else { return 0 }

        let cycleDuration = 2.8
        let phase = date.timeIntervalSince(pulseStartedAt)
            .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        return CGFloat((1 - cos(phase * 2 * .pi)) / 2)
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

            Text(verbatim: "%")
                .font(.system(size: max(5, size * 0.30), weight: .black, design: .rounded))
                .foregroundStyle(AppColor.onAccent)
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
        .accessibilityElement(children: .combine)
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
