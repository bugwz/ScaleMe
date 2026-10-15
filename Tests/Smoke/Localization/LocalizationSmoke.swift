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

        let profile = UserProfile(role: "本人")
        let healthDeviceID = UUID()
        let configuration = AppConfiguration(
            profiles: [profile],
            pairedScales: [],
            unit: .kilograms,
            languageSelection: .japanese,
            visualTheme: .colorVisionAccessible,
            appearance: .dark,
            mergeFrequentMeasurements: false,
            appleHealthProfileID: profile.id,
            appleHealthDeviceIDs: [healthDeviceID],
            isAppleHealthImportEnabled: true,
            appleHealthReadTypes: [.bodyMass],
            customCommunicationRules: []
        )
        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: encoded)
        precondition(decoded.languageSelection == .japanese)
        precondition(decoded.languageSelection.resolvedLanguage == .japanese)
        precondition(decoded.visualTheme == .colorVisionAccessible)
        precondition(decoded.appearance == .dark)
        precondition(decoded.appleHealthProfileID == profile.id)
        precondition(decoded.appleHealthDeviceIDs == [healthDeviceID])
        precondition(decoded.isAppleHealthImportEnabled)
        precondition(decoded.appleHealthReadTypes == [.bodyMass])
        precondition(AppLanguage.matchingSystemLanguage(preferredLanguages: ["ar-SA"]) == .english)
        precondition(AppLanguage.matchingSystemLanguage(preferredLanguages: ["zh-TW"]) == .traditionalChinese)
        precondition(AppLanguageSelection.system.resolvedLanguage == AppLanguage.systemDefault)

        let requiredLocalizedKeys = [
            "儿童阻抗研究 · Schaefer",
            "儿童足间阻抗研究 · Tyrrell",
            "宽年龄阻抗研究 · Sun",
            "儿童 BMI 标准 · WHO",
            "青少年 BMI 参考 · WHO",
            "分年龄基础代谢 · FAO",
            "严重偏低",
            "超重风险",
            "骨骼肌参考表 · OMRON",
            "指标状态",
            "参考资料",
            "皮下脂肪率",
            "皮下脂肪量",
            "蛋白质占比",
            "蛋白质含量",
            "骨骼肌率",
            "骨骼肌量",
            "皮下脂肪是皮肤下的脂肪，比例和质量可以相互换算；不能把总脂肪量直接当作皮下脂肪量。当前没有适配本指标的全年龄统一分级。",
            "蛋白质参考 PHICOMM S7 的 16%–20% 区间，本应用仅用于成人；不代表饮食摄入或血液蛋白水平。",
            "骨骼肌是参与身体运动的肌肉，与总肌肉量不同。采用 OMRON 的 18–80 岁性别和年龄参考表，按一位小数分级；其他年龄保留数值供参考。偏高不等同于优，也不是诊断结论。",

            "低于 %@",
            "高于 %@",
            "%@ 及以上",
            "%@ 及以下",

            "BMI 是体重与身高平方的比值，用于描述体重相对身高的水平，不能直接区分脂肪和肌肉。",
            "体脂率是脂肪占体重的比例；脂肪量是对应的质量。质量范围随体重变化，状态按同次体脂率判断。",
            "肌肉采用 Withings 的 20–79 岁年龄与性别参考范围；质量区间按体重换算。偏高不代表更健康。",
            "身体水分是水分占体重的比例；水分量是对应的质量。质量范围随体重变化，状态按同次水分率判断。",
            "骨量参考 Withings：男性占体重 3%–5%，女性 2.5%–4%。本应用仅用于成人；不是骨密度分级。",
            "内脏脂肪反映腹腔内脂肪相关水平。这里的数值是指数，不是质量或百分比；不同算法的范围不能直接通用。",
            "基础代谢描述静息状态下维持基本生命活动的每日能量需求，不是全天总消耗。它受年龄、性别及体型影响，没有统一的高低范围。",

            "BMI 分级 · WHO",
            "体脂参考表 · OMRON",
            "体脂参考研究 · PubMed",
            "水分参考范围 · TANITA",
            "肌肉评估共识 · PubMed",
            "骨密度说明 · NIH",
            "偏低",
            "偏高",
            "很高",
            "超重",
            "肥胖",
            "不评级",
            "不适用",
            "无数据",
            "数据异常",
            "足间生物电阻抗研究 · PubMed",
            "成人静息能量研究 · PubMed",
            "生物电阻抗应用指南 · PubMed",

            "成员已添加",
            "成员信息已保存",
            "设备已关联",
            "通信协议已导入",
            "文件已导出",
            "导入已完成",

            "未保存",
            "重试保存",
            "保存失败，数据尚未写入本机。请重试；退出应用后未保存的数据可能丢失。",

            "健康同步",
            "与 Apple 健康同步数据",
            "此功能通过 HealthKit 读写 Apple 健康中的体重和体脂率，用于同步记录和查看长期变化。同步为可选功能，不授权也可使用本地测量和记录。",
            "你可以在接下来的系统页面选择允许访问的数据。",
            "继续",
            "体重与体脂率",
            "请前往“健康”App → 个人头像 → App → 观我调整权限。",

            "必填", "选填", "请检查输入：%@", "放大图表", "缩小图表", "恢复图表范围", "可通过上移、下移操作调整顺序",
            "身体成分仅供趋势参考，不用于诊断或治疗。在作出医疗决定前，请咨询医生。", "去脂体重", "静息能量消耗",
            "数据说明", "查看数据来源、计算方法、使用边界和参考依据。",
            "数据来源", "测量记录可能来自已连接的蓝牙体重秤、手动录入，或在授权后从 Apple 健康导入；模拟模式只使用示例数据。手机本身不能测量体重或身体成分。",
            "计算方法", "估算按当前成员身高、性别和测量时年龄重算，不覆盖原始记录，也不作为设备体脂率同步到 Apple 健康。",
            "去脂体重水合研究 · PubMed",
            "BMI 公式 · CDC", "生物电阻抗 · NCBI", "水分影响 · PubMed",
            "健康指标", "体脂率", "基础代谢", "测量", "选择测量成员", "选择测量设备",
            "测量中", "测量完成", "正在测量体重，请保持站立", "体重测量完成，正在测量身体成分，请保持站立",
            "正在确认测量结果，请保持站立",
            "切换测量设备，当前为 %@", "点击选择本次测量使用的体重秤或体脂秤",
            "手动录入数据", "模拟数据模式", "本次测量", "详情", "数据默认保存在本机",
            "手动录入", "测量时间", "基础数据", "必填，0.00 ~ 500.00", "详细数据（可选）", "已展开", "已收起", "保存", "趋势", "类别", "时间",
            "来源设备", "全部设备", "测量记录", "添加设备", "请先添加成员，再添加设备", "正在扫描附近的设备…",
            "正在演示设备发现流程。这里显示的都是预设内容，不会搜索、连接或操作附近的真实设备。",
            "模拟一次测量",
            "按时间跨度合并为日、周或月均值", "保留每次测量及其真实时间位置",
            "横轴从首条数据延伸至末条数据", "横轴覆盖所选区间，包括无数据时段",
            "自定义时间", "时间范围", "全选", "已选择", "已选择 %lld 项",
            "演示扫描并关联预设模拟设备", "正在扫描模拟设备…", "正在载入预设模拟设备",
            "扫描并关联附近的体重秤或体脂秤", "暂未发现设备，请唤醒体重秤并靠近手机",
            "客厅智能体脂秤", "旅行便携体重秤", "附近的健康设备", "模拟设备", "协议待验证",
            "其他附近蓝牙设备（%lld）", "关联", "已绑定", "已匹配", "未匹配",
            "搜索姓名或角色", "名称", "角色", "输入角色",
            "性别", "未选择",
            "显示与记录", "体重单位", "千克（kg）", "市斤（斤）", "磅（lb）",
            "合并连续称重", "同一成员和设备在 30 秒内连续完成的称重，只保留最新一条。",
            "启用模拟数据", "在整个应用中使用模拟成员、设备和近一年记录，不影响真实数据。",
            "模拟模式下的修改仅保留到本次运行结束；下次启动会恢复预设数据。",
            "暂无展示指标", "暂无隐藏指标",
            "%lld 人", "%lld 台", "%@ cm · %@ kg", "%@ · %lld 岁",
            "全部成员（%lld 人）", "搜索结果（%lld 人）",
            "%@趋势", "%@ · %lld 次测量", "%lld 次测量均值",
            "版本 %@（%@）", "版本 %@", "版本信息暂不可用", "蓝牙秤", "自动识别",
            "本人", "伴侣", "父母", "子女", "其他", "女", "男",
            "共享数据给 Apple 健康", "从 Apple 健康获取数据", "选择用户", "选择设备", "选择数据类型",
            "正在从 Apple 健康获取数据", "最近一次获取失败",
            "共享到 Apple 健康的记录仅包含所选用户由所选设备产生的新稳定测量。",
            "首位成员固定为本人，只能通过清除全部数据移除。",
            "偏低", "标准", "偏高", "级", "小米体重秤", "标准蓝牙体重秤",
            "手动记录", "示例数据", "示例用户", "最终值",
            "测量详情", "基础指标", "健康指标", "设备原始数据",
            "修改记录归属", "删除测量记录", "删除这条测量记录？",
            "这条测量记录将被永久删除，且无法恢复。",
            "体脂率", "脂肪量", "肌肉率", "肌肉量", "体水分率", "体水分量",
            "骨量占比", "骨量", "内脏脂肪等级", "基础代谢",
            "阻抗通道 1", "阻抗通道 2",
            "正在扫描模拟设备…", "已发现模拟设备", "设备管理", "连接状态",
            "未连接", "连接中", "已连接", "刷新",
            "秤端设置", "数据抓包", "成员管理", "添加成员",
            "编辑成员", "人物形象", "成员信息", "出生日期",
            "导入/导出", "导入", "导出", "数据模拟",
            "包含称重和身体成分记录的版本化 JSON 文件。", "配置和数据文件",
            "一个 JSON 文件同时包含完整配置和测量记录。",
            "数据删除", "请选择要删除的内容", "选择要永久删除的本地文件。",
            "删除所选内容", "剩余 %lld 秒", "确认删除",
            "删除本机保存的所有真实测量记录，保留成员、设备和设置。",
            "删除所有真实测量记录、成员、设备和设置，并恢复初始状态。",
            "删除数据文件？", "删除配置和数据文件？",
            "所有真实测量记录将被永久删除，且无法恢复。成员、设备和设置不受影响。",
            "所有真实测量记录、成员、设备和设置将被永久删除，且无法恢复。应用会退出模拟模式并恢复初始状态。",
            "导入配置？", "导入并替换", "导入数据文件？", "合并导入", "导出失败",
            "导入配置和数据文件？",
            "导入的成员、设备、显示单位和通信协议将替换本机配置。测量记录不受影响。",
            "将把文件中的 %lld 条记录与本机记录合并，重复记录不会重复保存。",
            "配置将替换本机配置，并把文件中的 %lld 条记录与本机记录合并。重复记录不会重复保存。",
            "配置文件格式无效", "数据文件格式无效", "配置和数据文件格式无效",
            "协议详情",
            "关于应用", "可执行", "可执行协议", "实验性", "协议骨架",
            "已实现并验证", "待完善协议", "待完善或验证",
            "实现状态", "支持型号", "运行要求", "协议信息", "协议特征", "传输特征", "备用特征", "订阅特征", "写入特征",
            "需要成员资料", "需要时间同步", "需要系统配对", "需要用户同意码",
            "需要设备绑定密钥", "需要加密会话", "需要厂商应用预注册", "需要多帧状态机",
            "需要历史记录状态机", "需要持续保活", "厂商广播数据",
            "该项已纳入内置协议目录，但运行时解析或会话状态机尚未完整移植，暂不可用于测量。",
            "该协议资料参考 %@ 项目。",
            "选择文件", "解析后的协议内容", "解析字段",
            "选择文件后，这里会显示校验通过的协议名称、标识和通信特征。",
            "请先选择并校验本地协议文件。", "点击“添加”并选择本地协议文件导入。",
            "协议文件超过 512 KB 限制",
            "删除协议", "删除外部协议？", "删除后，使用该协议的设备会恢复为自动识别。",
            "将删除“%@”。使用该协议的设备会恢复为自动识别。",
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

        guard
            let productName = strings[AppText.productName.rawValue] as? [String: Any],
            let productNameLocalizations = productName["localizations"] as? [String: Any],
            let simplifiedProductName = productNameLocalizations[AppLanguage.simplifiedChinese.rawValue] as? [String: Any],
            let simplifiedProductNameUnit = simplifiedProductName["stringUnit"] as? [String: Any],
            simplifiedProductNameUnit["value"] as? String == "观我",
            let traditionalProductName = productNameLocalizations[AppLanguage.traditionalChinese.rawValue] as? [String: Any],
            let traditionalProductNameUnit = traditionalProductName["stringUnit"] as? [String: Any],
            traditionalProductNameUnit["value"] as? String == "觀我"
        else {
            preconditionFailure("Chinese product names must be 观我 and 觀我")
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
            precondition(key != "%@ %@", "number and unit text must be rendered verbatim")
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

        let japaneseProtocolDetailValues = [
            "协议详情": "プロトコルの詳細",
            "协议信息": "プロトコル情報",
            "名称": "名称",
            "版本": "バージョン",
            "来源": "提供元",
            "内置": "内蔵",
            "实现状态": "実装状態",
            "可执行": "実行可能",
            "协议特征": "プロトコルの特性",
            "传输特征": "通信方式の特性",
            "方式": "方式",
            "服务 UUID": "サービス UUID",
            "特征 UUID": "特性 UUID",
            "长度": "長さ",
            "至少 %lld 字节": "%lld バイト以上",
            "备用特征": "代替特性",
            "订阅特征": "通知特性",
            "写入特征": "書き込み特性",
            "运行要求": "実行要件",
            "支持型号": "対応モデル",
            "帧前缀": "フレーム接頭辞",
            "说明": "説明"
        ]
        for (key, expectedValue) in japaneseProtocolDetailValues {
            guard
                let entry = strings[key] as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any],
                let japanese = localizations[AppLanguage.japanese.rawValue] as? [String: Any],
                let stringUnit = japanese["stringUnit"] as? [String: Any],
                stringUnit["value"] as? String == expectedValue
            else {
                preconditionFailure("Japanese protocol detail localization is incorrect: \(key)")
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
        for (key, rawEntry) in infoStrings {
            guard
                let entry = rawEntry as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                preconditionFailure("InfoPlist.xcstrings entry has no localizations: \(key)")
            }
            for language in AppLanguage.allCases {
                guard
                    let localization = localizations[language.rawValue] as? [String: Any],
                    let stringUnit = localization["stringUnit"] as? [String: Any],
                    stringUnit["state"] as? String == "translated",
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    preconditionFailure("\(language.rawValue) is missing from InfoPlist entry: \(key)")
                }
            }
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
        guard
            let healthReadDescription = infoStrings["NSHealthShareUsageDescription"] as? [String: Any],
            let healthReadLocalizations = healthReadDescription["localizations"] as? [String: Any]
        else {
            preconditionFailure("InfoPlist.xcstrings must localize HealthKit read permission")
        }
        precondition(
            AppLanguage.allCases.allSatisfy { healthReadLocalizations[$0.rawValue] != nil },
            "every supported language needs a localized HealthKit read permission"
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
