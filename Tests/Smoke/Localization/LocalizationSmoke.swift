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
        let healthDeviceID = UUID()
        let configuration = AppConfiguration(
            profiles: [profile],
            selectedProfileID: profile.id,
            pairedScales: [],
            unit: .kilograms,
            languageSelection: .japanese,
            appearance: .dark,
            mergeFrequentMeasurements: false,
            appleHealthProfileID: profile.id,
            appleHealthDeviceIDs: [healthDeviceID],
            customCommunicationRules: []
        )
        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: encoded)
        precondition(decoded.languageSelection == .japanese)
        precondition(decoded.languageSelection.resolvedLanguage == .japanese)
        precondition(decoded.appearance == .dark)
        precondition(decoded.appleHealthProfileID == profile.id)
        precondition(decoded.appleHealthDeviceIDs == [healthDeviceID])
        precondition(AppLanguage.matchingSystemLanguage(preferredLanguages: ["ar-SA"]) == .english)
        precondition(AppLanguage.matchingSystemLanguage(preferredLanguages: ["zh-TW"]) == .traditionalChinese)
        precondition(AppLanguageSelection.system.resolvedLanguage == AppLanguage.systemDefault)

        let requiredLocalizedKeys = [
            "健康指标", "体脂率", "基础代谢", "测量", "选择测量成员", "选择测量设备",
            "测量中", "测量完成", "正在测量体重，请保持站立", "体重测量完成，正在测量身体成分，请保持站立",
            "正在确认测量结果，请保持站立",
            "自动选择", "等待任一已关联设备", "切换测量设备，当前为 %@", "点击选择本次测量使用的体重秤或体脂秤",
            "手动录入测量数据", "模拟数据模式", "本次测量", "详情", "数据默认保存在本机",
            "手动录入", "生物电阻抗", "保存测量数据", "趋势", "类别", "时间",
            "来源设备", "全部设备", "测量记录", "添加设备", "正在扫描周围设备",
            "正在演示设备发现流程。这里显示的都是预设内容，不会搜索、连接或操作附近的真实设备。",
            "模拟一次测量",
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
            "模拟模式下的修改仅保留到本次运行结束；下次启动会恢复预设数据。",
            "暂无展示指标", "暂无隐藏指标",
            "%lld 人", "%lld 台", "%@ · %@ cm · %lld 岁", "%@ · %lld 岁",
            "全部成员（%lld 人）", "搜索结果（%lld 人）", "当前成员，%@，管理全部成员",
            "%@趋势", "%@ · %lld 次测量", "%lld 次测量均值",
            "版本 %@（%@）", "版本 %@", "版本信息暂不可用", "蓝牙秤", "自动识别",
            "本人", "伴侣", "父母", "子女", "其他", "女", "男",
            "偏低", "标准", "偏高", "级", "小米体重秤", "标准蓝牙体重秤",
            "手动记录", "示例数据", "最终值",
            "测量详情", "基础指标", "身体成分估算", "设备原始数据",
            "体脂率", "脂肪量", "肌肉率", "肌肉量", "身体水分", "水分量",
            "蛋白质占比", "蛋白质量", "骨量占比", "骨量", "内脏脂肪", "基础代谢",
            "阻抗通道 1", "阻抗通道 2",
            "体脂及相关指标是基于生物电阻抗和个人资料的消费级估算值，仅用于日常趋势参考，不构成医疗诊断。",
            "阻抗通道名称和频率尚未获得厂商定义，因此仅保留原始读数，不据此声称具体频率。",
            "正在扫描模拟设备", "已发现模拟设备", "设备管理", "连接状态",
            "秤端设置", "数据抓包", "成员管理", "添加成员",
            "编辑成员", "人物形象", "成员信息", "出生日期",
            "文件导入/导出", "导入", "导出", "数据模拟",
            "包含称重和身体成分记录的版本化 JSON 文件。",
            "配置文件与数据文件均以版本化 JSON 格式导入导出，可跨设备分享。",
            "导入配置？", "导入并替换", "导入数据文件？", "合并导入", "导出失败",
            "导入的成员、设备、显示单位和通信协议将替换本机配置。测量记录不受影响。",
            "将把文件中的 %lld 条记录与本机记录合并，重复记录不会重复保存。",
            "配置文件格式无效", "数据文件格式无效",
            "协议详情",
            "规则配置格式", "关于应用", "可执行", "实验性", "协议骨架", "平台不支持",
            "实现状态", "支持型号", "运行要求", "协议信息", "协议特征", "传输特征", "备用特征", "订阅特征", "写入特征",
            "需要成员资料", "需要时间同步", "需要系统配对", "需要用户同意码",
            "需要设备绑定密钥", "需要加密会话", "需要厂商应用预注册", "需要多帧状态机",
            "需要历史记录状态机", "需要持续保活", "需要经典蓝牙", "经典蓝牙串口", "厂商广播数据",
            "内置目录同时包含可执行协议和已登记的上游协议骨架；请以“实现状态”与“验证状态”标签为准。",
            "该项已纳入内置协议目录，但运行时解析或会话状态机尚未完整移植，暂不可用于测量。",
            "该协议资料参考 %@ 项目。",
            "设计原则", "本地优先", "标准优先", "关注长期趋势", "重要说明",
            "返回", "正在连接", "正在读取设备能力", "设备能力已更新"
        ]
            + CommunicationRuleCatalog.builtIn.map(\.summary)
            + MemberAvatar.allCases.flatMap { [$0.title, $0.ageHint] }
        let catalogDirectory = URL(fileURLWithPath: "ScaleMe/Resources/Localization", isDirectory: true)
        var strings: [String: Any] = [:]
        var tableByKey: [String: LocalizationTable] = [:]
        for table in LocalizationTable.allCases {
            let catalogURL = catalogDirectory.appendingPathComponent(table.catalogFileName)
            let catalogData = try Data(contentsOf: catalogURL)
            guard
                let catalog = try JSONSerialization.jsonObject(with: catalogData) as? [String: Any],
                catalog["sourceLanguage"] as? String == AppLanguage.simplifiedChinese.rawValue,
                let tableStrings = catalog["strings"] as? [String: Any],
                !tableStrings.isEmpty
            else {
                preconditionFailure("\(table.catalogFileName) must be a nonempty zh-Hans source catalog")
            }
            for (key, entry) in tableStrings {
                precondition(
                    strings.updateValue(entry, forKey: key) == nil,
                    "localization key appears in multiple catalogs: \(key)"
                )
                tableByKey[key] = table
            }
        }

        for key in requiredLocalizedKeys + AppText.allCases.map(\.rawValue) {
            guard
                let entry = strings[key] as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                preconditionFailure("localization catalogs are missing: \(key)")
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
            ((strings[MeasurementSource.manual.localizationKey] as? [String: Any])?["localizations"] as? [String: Any])
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
        guard
            let healthUpdateDescription = infoStrings["NSHealthUpdateUsageDescription"] as? [String: Any],
            let healthUpdateLocalizations = healthUpdateDescription["localizations"] as? [String: Any]
        else {
            preconditionFailure("InfoPlist.xcstrings must localize HealthKit write permission")
        }
        precondition(
            AppLanguage.allCases.allSatisfy { healthUpdateLocalizations[$0.rawValue] != nil },
            "every supported language needs a localized HealthKit write permission"
        )
        precondition(
            infoStrings["NSHealthShareUsageDescription"] == nil,
            "write-only Apple Health integration must not declare read access"
        )

        if let appBundlePath = CommandLine.arguments.dropFirst().first {
            guard let appBundle = Bundle(path: appBundlePath) else {
                preconditionFailure("unable to open app bundle at \(appBundlePath)")
            }
            let runtimeKeys = requiredLocalizedKeys.map { ($0, $0) }
                + AppText.allCases.map { ($0.rawValue, $0.defaultValue) }
            let coveredTables = Set(runtimeKeys.compactMap { tableByKey[$0.0] })
            precondition(
                coveredTables == Set(LocalizationTable.allCases),
                "runtime localization fixtures must cover every string table"
            )
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
                    guard let table = tableByKey[key] else {
                        preconditionFailure("missing localization table for key: \(key)")
                    }
                    let tableActual = language.localized(
                        key,
                        defaultValue: defaultValue,
                        table: table,
                        in: appBundle
                    )
                    precondition(
                        tableActual == expected,
                        "runtime table lookup mismatch for \(language.rawValue): \(key)"
                    )
                    let aggregateActual = language.localized(
                        key,
                        defaultValue: defaultValue,
                        in: appBundle
                    )
                    precondition(
                        aggregateActual == expected,
                        "runtime aggregate lookup mismatch for \(language.rawValue): \(key)"
                    )
                }
            }
        }

        print("Localization smoke tests passed")
    }
}
