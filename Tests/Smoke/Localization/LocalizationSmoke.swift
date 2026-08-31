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

        let requiredLocalizedKeys = [
            "健康指标", "体脂率", "基础代谢", "测量", "选择测量成员",
            "手动录入测量数据", "模拟数据模式", "本次测量", "数据默认保存在本机",
            "手动录入", "生物电阻抗", "保存测量数据", "趋势", "类别", "时间",
            "来源设备", "全部设备", "测量记录", "添加设备", "正在扫描周围设备",
            "正在演示设备发现流程。这里显示的都是预设内容，不会搜索、连接或操作附近的真实设备。",
            "当前显示最近一条模拟测量，关闭模拟数据后恢复真实设备监听",
            "身体成分指标为消费级估算值，仅用于长期趋势参考，不构成医疗诊断。",
            "BMI、脂肪量、肌肉占比、水分量、骨量占比和蛋白质等指标，将根据测量值与当前成员 %@ 的身体资料自动计算。",
            "按时间跨度合并为日、周或月均值", "保留每次测量及其真实时间位置",
            "横轴从首条数据延伸至末条数据", "横轴覆盖所选区间，包括无数据时段",
            "自定义时间", "时间范围", "全选", "已选择", "已选择 %lld 项",
            "演示扫描并关联预设模拟设备", "正在载入预设模拟设备",
            "扫描并关联附近的体重秤或体脂秤", "暂未发现设备，请唤醒体重秤并靠近手机",
            "客厅智能体脂秤", "旅行便携体重秤", "附近的健康设备", "模拟设备", "协议待验证",
            "其他附近蓝牙设备（%lld）", "关联", "已绑定", "已关联",
            "管理全部成员", "搜索、切换或编辑资料", "当前", "搜索姓名或关系",
            "显示与记录", "体重单位", "千克（kg）", "市斤（斤）", "磅（lb）",
            "合并连续称重", "同一成员和设备在 30 秒内连续完成的称重，只保留最新一条。",
            "启用模拟数据", "全界面展示可操作的模拟成员、设备和近一年记录；真实资料与测量数据不会被删除或替换。",
            "模拟模式下可手动录入，也可新增、编辑或删除模拟资料。所有变动只保存在应用内存中，不会写入本机档案或同步到 iCloud；关闭应用后再次打开，将恢复为初始模拟数据。",
            "暂无展示指标", "暂无隐藏指标",
            "%lld 人", "%lld 台", "%@ · %@ cm · %lld 岁", "%@ · %lld 岁",
            "全部成员（%lld 人）", "搜索结果（%lld 人）", "当前成员，%@，管理全部成员",
            "%@趋势", "%@ · %lld 次测量", "%lld 次测量均值",
            "版本 %@（%@）", "版本 %@", "版本信息暂不可用", "蓝牙秤", "自动识别",
            "本人", "伴侣", "父母", "子女", "其他", "女", "男",
            "偏低", "标准", "偏高", "级", "小米体重秤", "标准蓝牙体重秤",
            "手动记录", "示例数据", "安全提醒", "查看安全提醒", "最终值",
            "测量详情", "基础指标", "身体成分估算", "设备原始数据",
            "正在扫描模拟设备", "已发现模拟设备", "设备设置", "连接状态",
            "秤端设置", "协议匹配", "抓包与诊断日志", "成员管理", "添加成员",
            "编辑成员", "人物形象", "成员信息", "出生日期", "运动员模式",
            "同步应用配置", "同步测量数据", "通信规则", "协议详情",
            "规则配置格式", "输入响应记录", "开启开发诊断", "关于观我",
            "我们的原则", "本地优先", "标准优先", "关注长期趋势", "重要说明",
            "返回", "正在连接", "正在读取设备能力", "设备能力已更新"
        ]
            + MemberAvatar.allCases.flatMap { [$0.title, $0.ageHint] }
        let catalogPath = "ScaleMe/Resources/Localization/Localizable.xcstrings"
        let catalogData = try Data(contentsOf: URL(fileURLWithPath: catalogPath))
        guard
            let catalog = try JSONSerialization.jsonObject(with: catalogData) as? [String: Any],
            catalog["sourceLanguage"] as? String == AppLanguage.simplifiedChinese.rawValue,
            let strings = catalog["strings"] as? [String: Any]
        else {
            preconditionFailure("Localizable.xcstrings must be a valid zh-Hans source catalog")
        }

        for key in requiredLocalizedKeys + AppText.allCases.map(\.rawValue) {
            guard
                let entry = strings[key] as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                preconditionFailure("localization catalog is missing: \(key)")
            }
            for language in AppLanguage.allCases {
                guard
                    let localization = localizations[language.rawValue] as? [String: Any],
                    let stringUnit = localization["stringUnit"] as? [String: Any],
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    preconditionFailure("\(language.rawValue) is missing: \(key)")
                }
            }
        }

        for (key, rawEntry) in strings {
            guard
                let entry = rawEntry as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                preconditionFailure("localization catalog entry has no localizations: \(key)")
            }
            for language in AppLanguage.allCases {
                guard
                    let localization = localizations[language.rawValue] as? [String: Any],
                    let stringUnit = localization["stringUnit"] as? [String: Any],
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    preconditionFailure("\(language.rawValue) is missing from catalog entry: \(key)")
                }
            }
        }

        precondition(
            ((strings["标准"] as? [String: Any])?["localizations"] as? [String: Any])
                .flatMap { $0[AppLanguage.english.rawValue] as? [String: Any] }
                .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String == "Standard"
        )
        precondition(
            ((strings[MeasurementSource.manual.rawValue] as? [String: Any])?["localizations"] as? [String: Any])
                .flatMap { $0[AppLanguage.english.rawValue] as? [String: Any] }
                .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String == "Manual entry"
        )

        let infoCatalogData = try Data(
            contentsOf: URL(fileURLWithPath: "ScaleMe/Resources/Localization/InfoPlist.xcstrings")
        )
        guard
            let infoCatalog = try JSONSerialization.jsonObject(with: infoCatalogData) as? [String: Any],
            let infoStrings = infoCatalog["strings"] as? [String: Any],
            let displayName = infoStrings["CFBundleDisplayName"] as? [String: Any],
            let displayNameLocalizations = displayName["localizations"] as? [String: Any]
        else {
            preconditionFailure("InfoPlist.xcstrings must localize CFBundleDisplayName")
        }
        precondition(
            AppLanguage.allCases.allSatisfy { displayNameLocalizations[$0.rawValue] != nil },
            "every supported language needs a localized app display name"
        )

        if let appBundlePath = CommandLine.arguments.dropFirst().first {
            guard let appBundle = Bundle(path: appBundlePath) else {
                preconditionFailure("unable to open app bundle at \(appBundlePath)")
            }
            let runtimeKeys = requiredLocalizedKeys.map { ($0, $0) }
                + AppText.allCases.map { ($0.rawValue, $0.defaultValue) }
            for language in AppLanguage.allCases {
                for (key, defaultValue) in runtimeKeys {
                    guard
                        let entry = strings[key] as? [String: Any],
                        let localizations = entry["localizations"] as? [String: Any],
                        let localization = localizations[language.rawValue] as? [String: Any],
                        let stringUnit = localization["stringUnit"] as? [String: Any],
                        let expected = stringUnit["value"] as? String
                    else {
                        preconditionFailure("missing expected translation for \(language.rawValue): \(key)")
                    }
                    let actual = language.localized(
                        key,
                        defaultValue: defaultValue,
                        in: appBundle
                    )
                    precondition(
                        actual == expected,
                        "runtime lookup mismatch for \(language.rawValue): \(key)"
                    )
                }
            }
        }

        print("Localization smoke tests passed")
    }
}
