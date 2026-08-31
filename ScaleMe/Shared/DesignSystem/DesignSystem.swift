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
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.18)
    static let secondary = Color(red: 0.36, green: 0.47, blue: 0.45)
    static let canvas = Color(red: 0.965, green: 0.988, blue: 0.980)
    static let mint = Color(red: 0.08, green: 0.68, blue: 0.55)
    static let lime = Color(red: 0.74, green: 0.91, blue: 0.64)
    static let paleMint = Color(red: 0.90, green: 0.98, blue: 0.95)
    static let sky = Color(red: 0.43, green: 0.76, blue: 0.90)
    static let violet = Color(red: 0.58, green: 0.66, blue: 0.88)
    static let apricot = Color(red: 0.98, green: 0.67, blue: 0.43)
    static let rose = Color(red: 0.94, green: 0.55, blue: 0.61)
    static let bottomNavigationSelected = Color(red: 38 / 255, green: 155 / 255, blue: 112 / 255)
    static let bottomNavigationInactive = Color(red: 0.62, green: 0.63, blue: 0.75)
    static let bottomNavigationSurface = Color.white

    // Distinct, calm series colors keep adjacent body-metric charts easy to scan.
    static let trendWeight = mint
    static let trendBMI = sky
    static let trendBodyFat = apricot
    static let trendFatMass = Color(red: 0.91, green: 0.47, blue: 0.43)
    static let trendMuscleMass = Color(red: 0.32, green: 0.66, blue: 0.41)
    static let trendMusclePercent = Color(red: 0.12, green: 0.62, blue: 0.63)
    static let trendWaterPercent = Color(red: 0.25, green: 0.56, blue: 0.82)
    static let trendWaterMass = Color(red: 0.31, green: 0.70, blue: 0.78)
    static let trendProteinPercent = Color(red: 0.67, green: 0.70, blue: 0.29)
    static let trendProteinMass = Color(red: 0.47, green: 0.64, blue: 0.22)
    static let trendBoneMass = violet
    static let trendBonePercent = Color(red: 0.67, green: 0.52, blue: 0.79)
    static let trendVisceralFat = rose
    static let trendBasalMetabolism = Color(red: 0.86, green: 0.50, blue: 0.24)
}

struct SoftCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AppColor.mint.opacity(0.08)))
            .shadow(color: AppColor.mint.opacity(0.08), radius: 18, y: 8)
    }
}

struct StatusPill: View {
    let text: String
    var color: Color = AppColor.mint

    var body: some View {
        AppLocalizedText(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
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

extension View {
    func mainPageTopInset() -> some View {
        contentMargins(.top, MainPageLayout.topInset, for: .scrollContent)
    }

    func localizedNavigationBackButton() -> some View {
        modifier(LocalizedNavigationBackButtonModifier())
    }
}

private struct LocalizedNavigationBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label(language.text(.back), systemImage: "chevron.left")
                    }
                }
            }
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.mint)
                    .frame(width: 26, height: 26)
                    .background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                AppLocalizedText(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.94))
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

struct SettingsChoiceBar<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    AppLocalizedText(title(option))
                        .font(.subheadline.weight(selection == option ? .semibold : .medium))
                        .foregroundStyle(selection == option ? AppColor.ink : AppColor.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 38)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: AppColor.mint.opacity(0.10), radius: 6, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppColor.paleMint.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        appearance == .compact ? AppColor.paleMint : Color.white.opacity(0.88),
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

struct AppDropdownMenuLayer<Option: Hashable>: View {
    let anchorFrame: CGRect
    let availableSize: CGSize
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    var appearance: AppDropdownAppearance = .tinted
    let onSelect: (Option) -> Void
    let onDismiss: () -> Void

    var body: some View {
        let desiredHeight = CGFloat(options.count) * 48 + 8
        let menuHeight = min(desiredHeight, max(80, availableSize.height - 24))
        let opensBelow = availableSize.height - anchorFrame.maxY >= menuHeight + 10
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
                        let isSelected = option == selection

                        Button {
                            onSelect(option)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(appearance == .compact ? .subheadline : .body)
                                    .foregroundStyle(
                                        isSelected
                                            ? AppColor.mint
                                            : AppColor.secondary.opacity(0.30)
                                    )

                                AppLocalizedText(title(option))
                                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                    .foregroundStyle(appearance == .compact && !isSelected ? AppColor.secondary : AppColor.ink)

                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, appearance == .compact ? 10 : 14)
                            .frame(maxWidth: .infinity)
                            .frame(height: appearance == .compact ? 48 : 44)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: appearance == .compact ? 10 : 12, style: .continuous)
                                        .fill(
                                            appearance == .compact
                                                ? AnyShapeStyle(AppColor.paleMint.opacity(0.72))
                                                : AnyShapeStyle(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.96),
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
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                            ? AnyShapeStyle(Color.white)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.99),
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
            .background(Color.white)
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

struct ScaleAvatarIconView: View {
    var size: CGFloat = 64
    var iconSize: CGFloat = 28
    var accent: Color = AppColor.mint

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            accent.opacity(0.16),
                            AppColor.sky.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image("ScaleDeviceTabIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(accent)
                .frame(width: iconSize, height: iconSize)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(accent.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.10), radius: 8, y: 4)
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
        background(
            LinearGradient(
                colors: [AppColor.paleMint, AppColor.canvas, AppColor.sky.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
        )
    }
}

extension Double {
    func formatted(_ digits: Int = 2) -> String { formatted(.number.precision(.fractionLength(digits))) }
}
