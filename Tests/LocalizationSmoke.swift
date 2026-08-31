import Foundation

@main
struct LocalizationSmoke {
    static func main() throws {
        precondition(AppLanguage.allCases.count == 10)
        precondition(Set(AppLanguage.allCases.map(\.rawValue)).count == 10)
        precondition(Set(AppLanguage.allCases.map(\.nativeName)).count == 10)

        for language in AppLanguage.allCases {
            precondition(!language.text(.productName).isEmpty)
            precondition(!language.text(.tagline).isEmpty)
            precondition(!language.text(.home).isEmpty)
            precondition(!language.text(.settings).isEmpty)
        }

        let profile = UserProfile()
        let configuration = AppConfiguration(
            profiles: [profile],
            selectedProfileID: profile.id,
            pairedScales: [],
            unit: .kilograms,
            appLanguage: .japanese,
            mergeFrequentMeasurements: false,
            customCommunicationRules: []
        )
        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: encoded)
        precondition(decoded.appLanguage == .japanese)

        guard var legacyObject = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            preconditionFailure("Encoded configuration must be a JSON object")
        }
        legacyObject.removeValue(forKey: "appLanguage")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyConfiguration = try JSONDecoder().decode(AppConfiguration.self, from: legacyData)
        precondition(AppLanguage.allCases.contains(legacyConfiguration.appLanguage))

        let requiredLocalizedKeys = [
            "健康指标", "体脂率", "基础代谢", "测量", "选择测量成员",
            "手动录入测量数据", "模拟数据模式", "本次测量", "数据默认保存在本机",
            "手动录入", "生物电阻抗", "保存测量数据", "趋势", "类别", "时间",
            "来源设备", "全部设备", "测量记录", "添加设备", "正在扫描周围设备",
            "正在演示设备发现流程。这里显示的都是预设内容，不会搜索、连接或操作附近的真实设备。"
        ]
        for language in AppLanguage.allCases where language != .simplifiedChinese {
            let path = "ScaleMe/\(language.rawValue).lproj/Localizable.strings"
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            for key in requiredLocalizedKeys {
                precondition(contents.contains("\"\(key)\""), "\(language.rawValue) is missing: \(key)")
            }
        }

        print("Localization smoke tests passed")
    }
}
