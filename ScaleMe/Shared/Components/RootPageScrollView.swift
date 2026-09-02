import SwiftUI

struct RootPageScrollView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let scrollToTopRequest: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollAnchor.top)

                content()
            }
            .onChange(of: scrollToTopRequest) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
    }
}

private enum ScrollAnchor: Hashable {
    case top
}
