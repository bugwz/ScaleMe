import Foundation

// SwiftUI literals stay in Localizable. Dynamic and semantic keys may live in
// the role-based tables and are resolved through the aggregate lookup below.
enum LocalizationTable: String, CaseIterable {
    case localizable = "Localizable"
    case shared = "Shared"
    case dashboard = "Dashboard"
    case measurement = "Measurement"
    case trends = "Trends"
    case devices = "Devices"
    case settings = "Settings"

    var catalogFileName: String {
        "\(rawValue).xcstrings"
    }
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case russian = "ru"
    case korean = "ko"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var nativeName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .russian: "Русский"
        case .korean: "한국어"
        }
    }

    static var systemDefault: AppLanguage {
        matchingSystemLanguage(preferredLanguages: Locale.preferredLanguages)
    }

    static func matchingSystemLanguage(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let normalized = identifier.lowercased()
            if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") {
                return .traditionalChinese
            }
            if normalized.hasPrefix("zh") { return .simplifiedChinese }
            if let language = allCases.first(where: { normalized.hasPrefix($0.rawValue.lowercased()) }) {
                return language
            }
        }
        return .english
    }

    func text(_ key: AppText) -> String {
        localized(key.rawValue, defaultValue: key.defaultValue)
    }

    func text(_ key: String) -> String {
        let missing = "__scaleme_missing_localization__"
        let resolved = localized(key, defaultValue: missing)
        guard resolved == missing else { return resolved }

        // Infrastructure keeps source-language messages so a language change can
        // re-render them. Localize a known semantic prefix while preserving the
        // system-, device-, or protocol-provided detail after it.
        if let separator = key.firstIndex(of: "：") {
            let prefix = String(key[..<separator])
            let detail = String(key[key.index(after: separator)...])
            let localizedPrefix = localized(prefix, defaultValue: missing)
            if localizedPrefix != missing {
                return format("%@：%@", localizedPrefix, detail)
            }
        }

        return key
    }

    func localized(
        _ key: String,
        defaultValue: String,
        table: LocalizationTable? = nil,
        in bundle: Bundle = .main
    ) -> String {
        guard
            let localizationPath = bundle.path(forResource: rawValue, ofType: "lproj"),
            let localizationBundle = Bundle(path: localizationPath)
        else {
            return defaultValue
        }

        let missing = "__scaleme_missing_localization__"
        let tables = table.map { [$0] } ?? LocalizationTable.allCases
        for candidate in tables {
            let resolved = localizationBundle.localizedString(
                forKey: key,
                value: missing,
                table: candidate.rawValue
            )
            if resolved != missing {
                return resolved
            }
        }
        return defaultValue
    }

    func format(_ key: String, _ arguments: CVarArg..., in bundle: Bundle = .main) -> String {
        String(
            format: localized(key, defaultValue: key, in: bundle),
            locale: locale,
            arguments: arguments
        )
    }
}

enum AppLanguageSelection: String, CaseIterable, Codable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case russian = "ru"
    case korean = "ko"

    var id: String { rawValue }

    var resolvedLanguage: AppLanguage {
        guard self != .system else { return .systemDefault }
        return AppLanguage(rawValue: rawValue) ?? .english
    }

    var explicitLanguage: AppLanguage? {
        self == .system ? nil : AppLanguage(rawValue: rawValue)
    }
}

enum AppText: String, CaseIterable {
    case productName = "app.product.name"
    case tagline = "app.product.tagline"
    case home = "navigation.home"
    case measure = "navigation.measure"
    case trends = "navigation.trends"
    case devices = "navigation.devices"
    case settings = "navigation.settings"
    case currentPage = "accessibility.current-page"
    case back = "navigation.back"
    case language = "settings.language.title"
    case languageDetail = "settings.language.detail"
    case languageSettings = "settings.language.navigation-title"
    case languageHint = "settings.language.hint"
    case followSystem = "settings.follow-system"
    case appearance = "settings.appearance.title"
    case appearanceHint = "settings.appearance.hint"
    case lightAppearance = "settings.appearance.light"
    case darkAppearance = "settings.appearance.dark"
    case selected = "accessibility.selected"
    case userInformation = "settings.user-information"
    case appSettings = "settings.app-settings"
    case displaySettings = "settings.display.title"
    case displaySettingsDetail = "settings.display.detail"
    case dataManagement = "settings.data-management.title"
    case dataManagementDetail = "settings.data-management.detail"
    case dataSharing = "settings.data-sharing.title"
    case dataSharingDetail = "settings.data-sharing.detail"
    case communicationProtocol = "settings.communication.title"
    case communicationProtocolDetail = "settings.communication.detail"
    case about = "settings.about.title"
    case aboutDetail = "settings.about.detail"

    var defaultValue: String {
        switch self {
        case .productName: "观我"
        case .tagline: "观察身体变化，看见自己的健康轨迹"
        case .home: "首页"
        case .measure: "测量"
        case .trends: "趋势"
        case .devices: "设备"
        case .settings: "设置"
        case .currentPage: "当前页面"
        case .back: "返回"
        case .language: "语言"
        case .languageDetail: "选择应用界面与启动页语言"
        case .languageSettings: "语言设置"
        case .languageHint: "更改后立即应用到界面，无需重新启动。"
        case .followSystem: "跟随系统"
        case .appearance: "外观"
        case .appearanceHint: "选择应用的界面外观；跟随系统会随设备设置自动切换。"
        case .lightAppearance: "浅色"
        case .darkAppearance: "深色"
        case .selected: "已选择"
        case .userInformation: "用户信息"
        case .appSettings: "应用设置"
        case .displaySettings: "显示设置"
        case .displaySettingsDetail: "体重单位、外观与连续称重"
        case .dataManagement: "数据管理"
        case .dataManagementDetail: "导入导出与数据模拟"
        case .dataSharing: "数据共享"
        case .dataSharingDetail: "管理 Apple 健康同步范围"
        case .communicationProtocol: "通信协议"
        case .communicationProtocolDetail: "设备识别与数据解析"
        case .about: "关于应用"
        case .aboutDetail: "产品原则与版本信息"
        }
    }
}
