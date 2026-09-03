import Foundation

@main
enum WidgetLocalizationSmoke {
    static func main() throws {
        let supportedLanguages = [
            "de", "en", "es", "fr", "ja", "ko", "pt", "ru", "zh-Hans", "zh-Hant"
        ]
        let catalogData = try Data(
            contentsOf: URL(fileURLWithPath: "ScaleMeWidget/Localizable.xcstrings")
        )
        guard
            let catalog = try JSONSerialization.jsonObject(with: catalogData) as? [String: Any],
            catalog["sourceLanguage"] as? String == "zh-Hans",
            let strings = catalog["strings"] as? [String: Any]
        else {
            preconditionFailure("widget Localizable.xcstrings must be a zh-Hans source catalog")
        }

        let requiredKeys = [
            "身体趋势", "趋势图", "趋势类别", "时间范围", "来源设备", "用户", "显示方式",
            "体重", "近 30 天", "全部设备", "汇总趋势 · 聚焦数据",
            "所选范围暂无此项数据", "打开观我后即可配置用户与设备趋势", "我", "本人"
        ]
        for key in requiredKeys {
            precondition(strings[key] != nil, "widget localization catalog is missing: \(key)")
        }

        for (key, rawEntry) in strings {
            guard
                let entry = rawEntry as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                preconditionFailure("widget localization entry has no localizations: \(key)")
            }
            for language in supportedLanguages {
                guard
                    let localization = localizations[language] as? [String: Any],
                    let stringUnit = localization["stringUnit"] as? [String: Any],
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    preconditionFailure("\(language) is missing from widget entry: \(key)")
                }
            }
        }

        print("Widget localization smoke passed")
    }
}
