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
    case followSystem = "settings.follow-system"
    case appearance = "settings.appearance.title"
    case lightAppearance = "settings.appearance.light"
    case darkAppearance = "settings.appearance.dark"
    case userInformation = "settings.user-information"
    case appSettings = "settings.app-settings"
    case displaySettings = "settings.display.title"
    case dataManagement = "settings.data-management.title"
    case dataSharing = "settings.data-sharing.title"
    case communicationProtocol = "settings.communication.title"
    case about = "settings.about.title"
    case privacyPolicy = "settings.privacy.title"
    case privacyPolicyDetail = "settings.privacy.detail"
    case privacyPolicyRevision = "settings.privacy.revision"
    case privacyPolicySummary = "settings.privacy.summary"
    case privacyPolicyBody = "settings.privacy.body"

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
        case .followSystem: "跟随系统"
        case .appearance: "外观"
        case .lightAppearance: "浅色"
        case .darkAppearance: "深色"
        case .userInformation: "用户信息"
        case .appSettings: "应用设置"
        case .displaySettings: "显示设置"
        case .dataManagement: "数据管理"
        case .dataSharing: "数据共享"
        case .communicationProtocol: "通信协议"
        case .about: "关于应用"
        case .privacyPolicy: "隐私政策"
        case .privacyPolicyDetail: "了解数据处理、系统权限、导入导出与删除方式"
        case .privacyPolicyRevision: "更新日期：2026年9月4日"
        case .privacyPolicySummary: "观我坚持本地优先。我们不会创建用户账号，也不会将你的成员资料或健康测量上传至开发者服务器。"
        case .privacyPolicyBody:
            """
            **本地存储与安全**
            成员姓名或昵称、关系、出生日期、生理性别、身高、关联设备、应用设置和测量记录默认保存在你的设备上。测量记录使用 AES-GCM 加密，密钥由系统钥匙串保管。应用不使用 iCloud 同步这些数据。

            **蓝牙设备**
            只有在你使用设备发现或测量功能时，应用才会请求蓝牙权限。应用会处理附近设备公开的标识、名称、型号、协议信息，以及体重、阻抗和设备明确提供的身体成分数据。部分设备所需的绑定或认证材料保存在系统钥匙串中，不会上传至开发者服务器。

            **Apple 健康**
            应用不会读取 Apple 健康数据。只有在你主动开启同步并授权后，应用才会把所选成员由所选真实设备产生的新稳定测量写入 Apple 健康，包括体重和设备明确提供的体脂率；历史记录、手动记录、模拟数据和估算身体成分不会写入。关闭应用内同步不会删除已写入的数据，你可以在“健康”应用中查看、删除或撤回权限。

            **网络与外部通信规则**
            应用不包含账号、广告或分析服务，也不会自动上传成员资料、设备认证材料或健康测量。外部通信规则仅在你主动选择本地 JSON 文件并通过格式校验后导入，应用不会从远程地址下载协议。导入的规则保存在本机。

            **导入、导出与分享**
            配置和测量记录仅在你主动操作时通过 JSON 文件导入或导出。导出的文件是未加密的明文，可能包含成员资料、设备信息和健康测量；保存位置、分享对象以及接收服务如何处理文件由你决定。导入前请确认文件来源可信。

            **数据保留与删除**
            本地数据会保留到你在应用内删除或移除应用。你可以在测量历史中删除记录，并在设置中删除成员或设备。删除成员或设备不会自动删除其历史测量记录，需要另行删除相关记录。移除应用会删除应用容器内的配置和加密测量文件；Apple 健康中的数据由“健康”应用管理。

            **权限、健康说明与联系**
            你可以随时在系统“设置”中撤回蓝牙或健康权限。消费级体脂秤的身体成分结果仅为趋势参考，不构成医疗诊断、治疗建议或临床结论。若对本政策有疑问，请通过 App Store 产品页面中的“开发者网站”或“App 支持”链接联系开发者；政策发生重要变化时，我们会更新本页及其日期。
            """
        }
    }
}
