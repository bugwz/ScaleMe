import SwiftUI

struct MemberAvatarView: View {
    let avatar: MemberAvatar
    var width: CGFloat = 128
    var height: CGFloat = 190
    var showsLabel = false
    var showsBackdrop = true

    private var assetName: String {
        switch avatar {
        case .child: "MemberAvatarChild"
        case .childDaughter: "MemberAvatarChildDaughter"
        case .youth: "MemberAvatarYouth"
        case .teenDaughter: "MemberAvatarTeenDaughter"
        case .adult: "MemberAvatarAdult"
        case .father: "MemberAvatarFather"
        case .senior: "MemberAvatarSenior"
        case .paternalGrandfather: "MemberAvatarPaternalGrandfather"
        case .maternalGrandfather: "MemberAvatarMaternalGrandfather"
        case .maternalGrandmother: "MemberAvatarMaternalGrandmother"
        }
    }

    private var isCompact: Bool { min(width, height) < 80 }

    private var accent: Color {
        switch avatar {
        case .child: AppColor.apricot
        case .childDaughter: AppColor.apricot
        case .youth: AppColor.sky
        case .teenDaughter: AppColor.sky
        case .adult: AppColor.mint
        case .father: AppColor.mint
        case .senior: AppColor.violet
        case .paternalGrandfather: AppColor.violet
        case .maternalGrandfather, .maternalGrandmother: AppColor.rose
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showsBackdrop {
                RoundedRectangle(cornerRadius: min(width, height) * 0.18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.82), accent.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: width * 0.9)
                    .offset(x: width * 0.18, y: -height * 0.18)
            }

            if !isCompact {
                Ellipse()
                    .fill(AppColor.ink.opacity(0.07))
                    .frame(width: width * 0.58, height: height * 0.055)
                    .offset(y: showsLabel ? -height * 0.18 : -height * 0.07)
            }

            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(
                    width: isCompact ? width * 1.08 : width * 0.92,
                    height: isCompact ? height * 1.72 : height * (showsLabel ? 0.76 : 0.94)
                )
                .offset(y: isCompact ? height * 0.37 : (showsLabel ? -height * 0.12 : height * 0.01))

            if showsLabel {
                VStack(spacing: 1) {
                    Text(avatar.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.ink)
                    Text(avatar.ageHint)
                        .font(.caption2)
                        .foregroundStyle(AppColor.secondary)
                }
                .padding(.bottom, height * 0.05)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: min(width, height) * 0.18, style: .continuous))
        .overlay {
            if showsBackdrop {
                RoundedRectangle(cornerRadius: min(width, height) * 0.18, style: .continuous)
                    .stroke(accent.opacity(0.12))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(avatar.ageHint)人物形象，\(avatar.title)")
    }
}
