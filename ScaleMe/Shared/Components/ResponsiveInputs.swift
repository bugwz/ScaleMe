import SwiftUI
import UIKit

/// UIKit-backed inputs keep first-responder changes local to the control. This
/// avoids rebuilding a SwiftUI navigation toolbar before the keyboard can be
/// presented, which is particularly expensive in the app's nested sheets and
/// navigation stacks.
struct ResponsiveTextField: UIViewRepresentable {
    @Environment(\.appLanguage) private var appLanguage
    @Binding var text: String
    @Binding var isFocused: Bool

    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .done
    var textStyle: UIFont.TextStyle = .body
    var fontWeight: UIFont.Weight = .regular
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var autocorrectionType: UITextAutocorrectionType = .default
    var spellCheckingType: UITextSpellCheckingType = .default
    var textContentType: UITextContentType?
    var smartDashesType: UITextSmartDashesType = .default
    var smartQuotesType: UITextSmartQuotesType = .default
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    var isSecureTextEntry = false
    var synchronizesFocusFromBinding = true
    var showsDoneAccessory = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.clearsOnBeginEditing = false
        textField.adjustsFontForContentSizeCategory = true
        textField.textColor = UIColor(AppColor.ink)
        textField.tintColor = UIColor(AppColor.mint)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.textField = textField
        context.coordinator.installSecureEntryButton(on: textField)
        configure(textField, coordinator: context.coordinator)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        // Keep the SwiftUI binding authoritative before changing secure-entry
        // state. UIKit may redraw (and, on some iOS versions, temporarily clear)
        // a secure field when that flag changes.
        if textField.text != text {
            textField.text = text
        }
        configure(textField, coordinator: context.coordinator)

        if synchronizesFocusFromBinding {
            if isFocused, !textField.isFirstResponder {
                textField.becomeFirstResponder()
            } else if !isFocused, textField.isFirstResponder {
                textField.resignFirstResponder()
            }
        }
    }

    static func dismantleUIView(_ textField: UITextField, coordinator: Coordinator) {
        textField.resignFirstResponder()
        textField.delegate = nil
    }

    private func configure(_ textField: UITextField, coordinator: Coordinator) {
        let localizedPlaceholder = appLanguage.text(placeholder)
        if textField.placeholder != localizedPlaceholder { textField.placeholder = localizedPlaceholder }
        if textField.keyboardType != keyboardType { textField.keyboardType = keyboardType }
        if textField.returnKeyType != returnKeyType { textField.returnKeyType = returnKeyType }
        if textField.autocapitalizationType != autocapitalizationType {
            textField.autocapitalizationType = autocapitalizationType
        }
        if textField.autocorrectionType != autocorrectionType {
            textField.autocorrectionType = autocorrectionType
        }
        if textField.spellCheckingType != spellCheckingType {
            textField.spellCheckingType = spellCheckingType
        }
        if textField.textContentType != textContentType { textField.textContentType = textContentType }
        if textField.smartDashesType != smartDashesType { textField.smartDashesType = smartDashesType }
        if textField.smartQuotesType != smartQuotesType { textField.smartQuotesType = smartQuotesType }
        if textField.smartInsertDeleteType != smartInsertDeleteType {
            textField.smartInsertDeleteType = smartInsertDeleteType
        }
        if !isSecureTextEntry {
            coordinator.isSecureTextRevealed = false
        }
        let shouldHideText = isSecureTextEntry && !coordinator.isSecureTextRevealed
        if textField.isSecureTextEntry != shouldHideText {
            coordinator.setSecureTextEntry(shouldHideText, on: textField)
        }
        coordinator.configureSecureEntryButton(
            isEnabled: isSecureTextEntry,
            revealLabel: appLanguage.text("显示密码"),
            concealLabel: appLanguage.text("隐藏密码")
        )

        let desiredFont = AppInputFont.scaled(textStyle, weight: fontWeight)
        if textField.font != desiredFont { textField.font = desiredFont }

        if showsDoneAccessory {
            if textField.inputAccessoryView == nil {
                textField.inputAccessoryView = AppInputAccessory.makeDoneBar(
                    target: coordinator,
                    action: #selector(Coordinator.dismissKeyboard)
                )
            }
        } else if textField.inputAccessoryView != nil {
            textField.inputAccessoryView = nil
            if textField.isFirstResponder { textField.reloadInputViews() }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ResponsiveTextField
        var isSecureTextRevealed = false
        weak var textField: UITextField?
        var secureEntryButton: UIButton?
        init(parent: ResponsiveTextField) {
            self.parent = parent
        }

        func installSecureEntryButton(on textField: UITextField) {
            let button = UIButton(type: .system)
            button.frame = CGRect(x: 0, y: 0, width: 36, height: 44)
            button.tintColor = UIColor(AppColor.secondary)
            button.addTarget(self, action: #selector(toggleSecureEntryVisibility), for: .touchUpInside)
            secureEntryButton = button
        }

        func configureSecureEntryButton(
            isEnabled: Bool,
            revealLabel: String,
            concealLabel: String
        ) {
            guard let textField, let secureEntryButton else { return }
            guard isEnabled else {
                textField.rightView = nil
                textField.rightViewMode = .never
                return
            }

            // The symbol communicates the current state; the accessibility
            // label below communicates the action performed by the button.
            let symbolName = isSecureTextRevealed ? "eye" : "eye.slash"
            let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            secureEntryButton.setImage(
                UIImage(systemName: symbolName, withConfiguration: configuration),
                for: .normal
            )
            secureEntryButton.accessibilityLabel = isSecureTextRevealed ? concealLabel : revealLabel
            textField.rightView = secureEntryButton
            textField.rightViewMode = .always
        }

        @objc func toggleSecureEntryVisibility() {
            guard parent.isSecureTextEntry, let textField else { return }
            synchronizeText(from: textField)
            isSecureTextRevealed.toggle()
            setSecureTextEntry(!isSecureTextRevealed, on: textField)
            configureSecureEntryButton(
                isEnabled: true,
                revealLabel: parent.appLanguage.text("显示密码"),
                concealLabel: parent.appLanguage.text("隐藏密码")
            )
        }

        func setSecureTextEntry(_ shouldHideText: Bool, on textField: UITextField) {
            guard textField.isSecureTextEntry != shouldHideText else { return }
            let currentText = textField.text ?? ""
            let selectionOffsets = textField.selectedTextRange.map { range in
                (
                    textField.offset(from: textField.beginningOfDocument, to: range.start),
                    textField.offset(from: textField.beginningOfDocument, to: range.end)
                )
            }

            textField.isSecureTextEntry = shouldHideText
            // Reassigning the value works around UIKit dropping the rendered
            // secure text while the field remains first responder.
            textField.text = currentText

            if let selectionOffsets,
               let start = textField.position(
                   from: textField.beginningOfDocument,
                   offset: selectionOffsets.0
               ),
               let end = textField.position(
                   from: textField.beginningOfDocument,
                   offset: selectionOffsets.1
               ) {
                textField.selectedTextRange = textField.textRange(from: start, to: end)
            }
        }

        @objc func textDidChange(_ sender: UITextField) {
            synchronizeText(from: sender)
        }

        private func synchronizeText(from textField: UITextField) {
            let currentText = textField.text ?? ""
            if parent.text != currentText { parent.text = currentText }
        }

        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
            // Flush pending secure/marked text before changing focus. Otherwise
            // a SwiftUI refresh can write the previous binding value back into
            // the UIKit field during the responder transition.
            synchronizeText(from: textField)
            return true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            // `textFieldShouldEndEditing` already committed the final value.
            // Do not read the UIKit field again here: secure text fields may
            // transiently report an empty value while resigning first responder.
            restoreBoundText(in: textField)
            if parent.isFocused { parent.isFocused = false }
            Task { @MainActor [weak self, weak textField] in
                guard let self, let textField else { return }
                // UIKit can finish its secure-field redraw after the delegate
                // callback, so restore once more on the next main-actor turn.
                self.restoreBoundText(in: textField)
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            synchronizeText(from: textField)
            textField.resignFirstResponder()
            if parent.isFocused { parent.isFocused = false }
            return true
        }

        @objc func dismissKeyboard() {
            if let textField { synchronizeText(from: textField) }
            textField?.resignFirstResponder()
            if parent.isFocused { parent.isFocused = false }
        }

        private func restoreBoundText(in textField: UITextField) {
            let committedText = parent.text
            if textField.text != committedText { textField.text = committedText }
        }
    }
}

struct ResponsiveTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var autocorrectionType: UITextAutocorrectionType = .default
    var spellCheckingType: UITextSpellCheckingType = .default
    var usesMonospacedFont = false
    var showsDoneAccessory = true

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = UIColor(AppColor.ink)
        textView.tintColor = UIColor(AppColor.mint)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        context.coordinator.textView = textView
        configure(textView, coordinator: context.coordinator)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        configure(textView, coordinator: context.coordinator)

        if textView.text != text {
            textView.text = text
        }

        if isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ textView: UITextView, coordinator: Coordinator) {
        textView.resignFirstResponder()
        textView.delegate = nil
    }

    private func configure(_ textView: UITextView, coordinator: Coordinator) {
        textView.autocapitalizationType = autocapitalizationType
        textView.autocorrectionType = autocorrectionType
        textView.spellCheckingType = spellCheckingType
        textView.font = usesMonospacedFont
            ? AppInputFont.scaledMonospaced(.caption1)
            : AppInputFont.scaled(.body, weight: .regular)

        if showsDoneAccessory, textView.inputAccessoryView == nil {
            textView.inputAccessoryView = AppInputAccessory.makeDoneBar(
                target: coordinator,
                action: #selector(Coordinator.dismissKeyboard)
            )
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ResponsiveTextEditor
        weak var textView: UITextView?

        init(parent: ResponsiveTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused { parent.isFocused = false }
        }

        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
            if parent.isFocused { parent.isFocused = false }
        }
    }
}

private enum AppInputAccessory {
    @MainActor
    static func makeDoneBar(target: Any, action: Selector) -> UIToolbar {
        let toolbar = UIToolbar(frame: .zero)
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "完成", style: .done, target: target, action: action)
        ]
        toolbar.tintColor = UIColor(AppColor.mint)
        toolbar.sizeToFit()
        return toolbar
    }
}

private enum AppInputFont {
    static func scaled(_ textStyle: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let preferred = UIFont.preferredFont(forTextStyle: textStyle)
        let base = UIFont.systemFont(ofSize: preferred.pointSize, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    static func scaledMonospaced(_ textStyle: UIFont.TextStyle) -> UIFont {
        let preferred = UIFont.preferredFont(forTextStyle: textStyle)
        let base = UIFont.monospacedSystemFont(ofSize: preferred.pointSize, weight: .regular)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}
