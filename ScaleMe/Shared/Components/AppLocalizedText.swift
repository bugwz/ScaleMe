import SwiftUI

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.systemDefault
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

struct AppLocalizedText: View {
    @Environment(\.appLanguage) private var language
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(language.text(key))
    }
}
