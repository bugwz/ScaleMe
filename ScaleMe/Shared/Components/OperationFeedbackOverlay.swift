import SwiftUI
import UIKit

extension View {
    func operationFeedbackOverlay(_ feedback: Binding<MeasurementStore.OperationFeedback?>) -> some View {
        modifier(OperationFeedbackOverlay(feedback: feedback))
    }
}

private struct OperationFeedbackOverlay: ViewModifier {
    @Binding var feedback: MeasurementStore.OperationFeedback?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let feedback {
                HStack(spacing: 12) {
                    Image(systemName: feedback.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(feedback.isError ? AppColor.rose : AppColor.mint)
                        .accessibilityHidden(true)
                    Text(feedback.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        self.feedback = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(language.text("完成"))
                }
                .padding(.leading, 16)
                .padding(.vertical, 4)
                .background(AppColor.canvas, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColor.mint.opacity(0.18)))
                .shadow(color: AppColor.ink.opacity(0.12), radius: 12, y: 5)
                .frame(maxWidth: 520)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .id(feedback.id)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .task(id: feedback.id) {
                    // Allow the initiating sheet or file picker to finish dismissing.
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    AppAccessibility.announce(feedback.message)
                    // Errors remain readable until explicitly dismissed.
                    guard !feedback.isError else { return }
                    try? await Task.sleep(for: .seconds(UIAccessibility.isVoiceOverRunning ? 6 : 3))
                    guard !Task.isCancelled, self.feedback?.id == feedback.id else { return }
                    self.feedback = nil
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: feedback?.id)
    }
}
