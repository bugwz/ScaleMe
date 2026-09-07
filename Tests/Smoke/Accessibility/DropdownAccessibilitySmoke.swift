import Foundation

/// Source-structure regression guard, not a substitute for rendered UI or VoiceOver tests.
@main
enum DropdownAccessibilitySmoke {
    static func main() throws {
        let sharedSource = try String(contentsOfFile: "ScaleMe/Shared/DesignSystem/DesignSystem.swift", encoding: .utf8)
        let deviceSource = try String(contentsOfFile: "ScaleMe/Features/Devices/DevicesView.swift", encoding: .utf8)
        let shared = section(sharedSource, from: "struct AppDropdownMenuLayer", to: "struct MintActionButtonStyle")
        let protocolMenu = section(deviceSource, from: "private func protocolDropdown(for", to: "private func selectCommunicationRule")

        for menu in [shared, protocolMenu] {
            precondition(menu.range(of: #"ScrollView\s*\{\s*LazyVStack"#, options: .regularExpression) != nil,
                         "dropdown scroll content must have one explicit stack, not overlapping sibling views")
            precondition(!menu.contains("\"完成\""), "accessibility must not insert a visible Done button into option menus")
            precondition(menu.contains(".accessibilityAction(named: Text(") && menu.contains("\"收起选项\""),
                         "options must retain a named dismissal action")
            precondition(menu.contains(".accessibilityAction(.escape"), "menus must retain the escape gesture")
            precondition(menu.contains(".accessibilityAddTraits(.isModal)"), "menus must remain modal to VoiceOver")
        }
        let heightLine = shared.split(separator: "\n").first { $0.contains("let desiredHeight =") }
        precondition(heightLine?.hasSuffix("+ listPadding") == true, "menu height must not reserve an accessibility-only button row")
        print("Dropdown accessibility source regression checks passed")
    }

    private static func section(_ source: String, from start: String, to end: String) -> String {
        guard let startRange = source.range(of: start),
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            preconditionFailure("dropdown source section was not found")
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }
}
