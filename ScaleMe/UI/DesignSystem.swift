import SwiftUI

enum AppColor {
    // Fresh health palette: soft natural surfaces with clear, accessible accents.
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.18)
    static let secondary = Color(red: 0.36, green: 0.47, blue: 0.45)
    static let canvas = Color(red: 0.965, green: 0.988, blue: 0.980)
    static let mint = Color(red: 0.08, green: 0.68, blue: 0.55)
    static let lime = Color(red: 0.74, green: 0.91, blue: 0.64)
    static let paleMint = Color(red: 0.90, green: 0.98, blue: 0.95)
    static let sky = Color(red: 0.43, green: 0.76, blue: 0.90)
    static let logoMint = Color(red: 40 / 255, green: 203 / 255, blue: 168 / 255)
    static let logoAqua = Color(red: 54 / 255, green: 204 / 255, blue: 183 / 255)
    static let logoTeal = Color(red: 85 / 255, green: 201 / 255, blue: 207 / 255)
    static let logoSky = Color(red: 120 / 255, green: 203 / 255, blue: 234 / 255)
    static let violet = Color(red: 0.58, green: 0.66, blue: 0.88)
    static let apricot = Color(red: 0.98, green: 0.67, blue: 0.43)
    static let rose = Color(red: 0.94, green: 0.55, blue: 0.61)
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
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
    }
}

struct MainPageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.largeTitle.bold())
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppColor.ink)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColor.mint.opacity(0.08)))
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
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
