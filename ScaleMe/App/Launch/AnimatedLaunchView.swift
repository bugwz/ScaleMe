import SwiftUI

struct AnimatedLaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let language: AppLanguage
    let isExiting: Bool

    @State private var isBodyVisible = false
    @State private var isMarkVisible = false
    @State private var isWordmarkVisible = false
    @State private var isPulseExpanded = false
    @State private var isFloating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColor.canvas, AppColor.paleMint, AppColor.sky.opacity(0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                launchMark
                    .frame(width: 224, height: 224)

                VStack(spacing: 9) {
                    Text(language.text(.productName))
                        .font(.system(size: 39, weight: .semibold, design: .rounded))
                        .tracking(language == .simplifiedChinese || language == .traditionalChinese ? 9 : 1.2)
                        .foregroundStyle(AppColor.ink)

                    Text(language.text(.tagline))
                        .font(.footnote)
                        .foregroundStyle(AppColor.secondary)
                        .padding(.top, 7)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .opacity(isWordmarkVisible ? 1 : 0)
                .offset(y: isWordmarkVisible ? 0 : 16)
                .scaleEffect(isWordmarkVisible ? 1 : 0.94)
                .blur(radius: isWordmarkVisible ? 0 : 6)
                .animation(.spring(response: 0.72, dampingFraction: 0.76), value: isWordmarkVisible)
            }
            .offset(y: -18)
            .scaleEffect(isExiting ? 0.94 : 1)
            .blur(radius: isExiting ? 2 : 0)
        }
        .opacity(isExiting ? 0 : 1)
        .task { await play() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text(.productName))
    }

    private var launchMark: some View {
        ZStack {
            Circle()
                .stroke(AppColor.mint.opacity(isPulseExpanded ? 0 : 0.20), lineWidth: 2)
                .frame(width: 158, height: 158)
                .scaleEffect(isPulseExpanded ? 1.55 : 0.84)

            Circle()
                .stroke(AppColor.sky.opacity(isPulseExpanded ? 0 : 0.16), lineWidth: 10)
                .frame(width: 144, height: 144)
                .scaleEffect(isPulseExpanded ? 1.32 : 0.92)

            Circle()
                .fill(AppColor.mint)
                .overlay {
                    LaunchLogoMark()
                        .trim(from: 0, to: isMarkVisible ? 1 : 0)
                        .stroke(.white, style: StrokeStyle(lineWidth: 13.8, lineCap: .round, lineJoin: .round))
                }
                .frame(width: 172, height: 172)
                .scaleEffect(isBodyVisible ? 1 : 0.74)
                .opacity(isBodyVisible ? 1 : 0)
                .shadow(color: AppColor.mint.opacity(0.18), radius: 28, y: 15)
                .animation(.spring(response: 0.72, dampingFraction: 0.74), value: isBodyVisible)

        }
        .offset(y: isFloating ? -5 : 3)
    }

    @MainActor
    private func play() async {
        guard !reduceMotion else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isBodyVisible = true
                isMarkVisible = true
                isWordmarkVisible = true
            }
            return
        }

        try? await Task.sleep(for: .milliseconds(90))
        isBodyVisible = true
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.easeOut(duration: 0.72)) {
            isMarkVisible = true
        }
        try? await Task.sleep(for: .milliseconds(760))
        isWordmarkVisible = true
        try? await Task.sleep(for: .milliseconds(120))

        withAnimation(.easeOut(duration: 1.25).repeatForever(autoreverses: false)) {
            isPulseExpanded = true
        }
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
            isFloating = true
        }
    }
}

private struct LaunchLogoMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.273, y: rect.minY + rect.height * 0.664))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.352, y: rect.minY + rect.height * 0.352))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.586))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.648, y: rect.minY + rect.height * 0.352))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.727, y: rect.minY + rect.height * 0.664))
        return path
    }
}
