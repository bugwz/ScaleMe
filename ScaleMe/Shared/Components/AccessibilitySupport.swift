import SwiftUI

extension View {
    func accessibilityReturnFocus(when presentationIsVisible: Bool) -> some View {
        modifier(AccessibilityReturnFocusModifier(isPresented: presentationIsVisible))
    }

    func accessibilityAnnounceChanges(_ message: String?) -> some View {
        onChange(of: message) { _, message in
            if let message { AppAccessibility.announce(message) }
        }
    }
}

private struct AccessibilityReturnFocusModifier: ViewModifier {
    let isPresented: Bool
    @AccessibilityFocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onChange(of: isPresented) { wasPresented, presented in
                if wasPresented && !presented { isFocused = true }
            }
    }
}
