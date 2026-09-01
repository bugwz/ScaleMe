<div align="center">

<img src="Design/Logo/readme-logo.svg" width="96" height="96" alt="观我">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![Local First](https://img.shields.io/badge/Data-Local%20First-2E8B57)](#数据与医学边界)

原生 iOS 体重与身体成分趋势应用

**从细微变化里，看见身体长期的方向。**

</div>

观我提供 SwiftUI 身体数据仪表盘、多成员档案、多个体重秤管理、可交互历史趋势、本地加密记录、手动录入、BLE 扫描、可选 iCloud 文件同步，以及可扩展的体重秤协议解析层。

界面内 Logo 使用纯薄荷绿圆形与白色对称 `M` 折线，由 [`Design/Logo/logo.svg`](Design/Logo/logo.svg) 生成并通过 Xcode Asset Catalog 管理；README 使用透明背景、无白色外圈的 [`readme-logo.svg`](Design/Logo/readme-logo.svg)。iOS 应用图标使用纯白外部区域，并将 Logo 居中呈现。

应用启动时会播放与 `M` Logo 对应的 SwiftUI 折线绘制动画，并在系统开启“减少动态效果”时自动使用静态呈现。

## 项目结构

Xcode 工程使用文件系统同步组，项目导航与磁盘目录保持一致。生产代码按职责与功能组织：

```text
ScaleMe/
├── App/                 # 应用入口、启动流程、根导航与全局状态
├── Core/Localization/   # 支持语言与语义化文案 key
├── Domain/              # 领域模型、计算、模拟数据与趋势分析
├── Infrastructure/      # 蓝牙、持久化、iCloud 同步与诊断
│   └── Bluetooth/Protocols/
│       ├── Common/      # 解析器共享错误与基础类型
│       ├── Standard/    # Bluetooth SIG 体重与体成分解析器
│       ├── Xiaomi/      # 小米配置与后续授权协议
│       ├── ICOMON/      # ICOMON 设备识别适配器
│       ├── Advertisement/ # 厂商广播拆包与协议目录
│       └── Community/   # 按协议家族隔离的社区逆向解析器
├── Features/            # Dashboard、Measurement、Trends、Devices、Settings
├── Shared/              # 共享组件、输入桥接与设计系统
└── Resources/           # Assets、String Catalog 与配置资源
Tests/Smoke/             # 按领域镜像组织的确定性烟雾测试
Design/Logo/             # 品牌源文件与文档预览
Tools/                   # 按用途分组的开发工具
```

简体中文是源语言。10 种界面语言统一维护在 `ScaleMe/Resources/Localization/Localizable.xcstrings`，系统 App 名称维护在同目录的 `InfoPlist.xcstrings`；不再使用散落的 `.lproj/Localizable.strings` 或按语言展开的 Swift 文案分支。

目录与本地化方案参考 Apple 的 [Managing files and folders in your Xcode project](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project/) 和 [Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)。Apple 负责定义工程资源与本地化机制；上述分层则按观我自身的职责边界设计。

## 当前兼容范围

- Bluetooth SIG Weight Scale Service `0x181D` / Weight Measurement `0x2A9D`
- Bluetooth SIG Body Composition Service `0x181B` / Body Composition Measurement `0x2A9C`
- 小米体重秤、体脂秤旧款常见 `0x181B` 广播数据（重量、稳定状态、阻抗）
- ICOMON `AFU-WL-TZ-A1` / `FG2313UWB-D` 的 `FFB0` / `FFB2` 私有协议（已用同一真机多轮采集验证实时、稳定、最终重量及双阻抗原始通道；改动后仍待真机回归验证）
- QN 血统非连接式 AABB 厂商广播（Company ID `0xFFFF`，重量与稳定状态；已通过数据样本验证，尚未在本项目真机验证）
- AAA002 / AAA007 / AAA013 厂商广播（XOR 解码、5 位校验、重量与稳定状态；已通过数据样本验证，尚未在本项目真机验证）
- Sinocare、Scaleup、OKOK、Etekcity Fit 8S、Eufy C20 与 Yunmai X 非连接式厂商广播（已实现独立解析器并通过数据样本验证，尚未在本项目真机验证）
- 其他可发现设备会显示为“协议待验证”，不会误报为已兼容

不同品牌甚至同品牌不同型号常使用不同私有协议。新增品牌时，应在 `ScaleMe/Infrastructure/Bluetooth/Protocols/<来源>/<协议家族>` 下增加独立 parser/adapter，通过 `ScaleBroadcastProtocolCatalog` 或 GATT 分发层接入，并使用真实设备数据与固件版本做回归测试。

完整状态与覆盖边界见 [`Docs/BluetoothProtocolSupport.md`](Docs/BluetoothProtocolSupport.md)。公开设备处理器并不等于可以直接复制的广播格式：大量型号依赖连接初始化、用户资料、时间同步、历史记录状态机或安全绑定，因此在具备安全实现和真实载荷前仍保持“待验证”，不会仅凭名称宣称兼容。

### 通信协议文件

每台已关联设备都可在“设备设置 → 协议匹配”中选择通信协议。协议库会列出内置解析器，并以标签展示标准规范、数据样本验证、实机样本或未经验证状态。应用支持从可信 HTTPS 地址拉取声明式外部协议，并在导入前校验资源与协议格式。外部协议不能执行脚本；普通测量只读取经过边界约束的服务广播或 GATT 通知字段，历史操作则只能订阅和写入协议声明且设备实际公开、属性匹配的 GATT 特征。厂商广播目前只允许使用经过代码审查和数据样本测试的内置解析器，外部协议也不能自行声明已经过硬件验证。

协议文件使用 `schemaVersion: 2`，可包含一条或多条协议定义。每条协议声明稳定 ID、传输方式、服务与可选特征 UUID、载荷长度/前缀、必需的体重字段，以及可选的阻抗、身体成分、状态字段和受限 GATT 历史操作。应用内可从“设置 → 通信协议”右侧的“添加”按钮输入可信 HTTPS 地址；应用会在格式与安全边界校验通过后导入。外部协议在具有可复现数据样本和真机验证前始终标记为未经硬件验证。

## 运行

1. 使用 Xcode 26 或更新版本打开 `ScaleMe.xcodeproj`。
2. 模拟器可查看界面；在“设置 → 偏好与同步”开启模拟数据后，全界面会使用覆盖儿童、青少年、父母和祖辈角色的 10 位三代家庭模拟成员、2 台模拟设备和近一年不等间隔的早晚测量记录。模拟快照不会写入或替换真实资料与加密测量档案；蓝牙扫描仍必须使用真机。
3. 选择开发团队后安装到 iPhone，首次搜索设备时允许蓝牙权限。
4. 如需使用 iCloud 同步，请在开发者账号为 App ID 启用 iCloud Documents，并确认 Xcode 中的 `iCloud.com.scaleme.app` 容器可用于当前团队。

添加设备时会扫描并展示所有附近正在广播的低功耗蓝牙设备，标准秤和已验证的旧款小米广播会优先排列，其余设备标记为“协议待验证”。如果进入页面时蓝牙仍在初始化，应用会在蓝牙可用后自动继续扫描。设备被发现不代表其测量协议已经兼容。

设备需先在“设备”页的独立扫描界面中添加并可自定义名称。进入“测量”页后，应用会自动监听已关联设备，不再展示或搜索任意附近设备。概览按当前成员展示数据；趋势页可独立筛选成员，并支持多选体重、BMI 及已有身体成分指标，在同一时间范围内依次展示多张图表，也可将单张图表放大为横屏全屏视图。趋势支持预设或自定义时间范围，以及“聚焦数据”与“完整区间”两种横轴范围；“汇总趋势”根据跨度合并为日、周或月均值并使用等距周期横轴，“逐次测量”保留每次测量并按真实时间间隔定位。图表根据可用宽度自动控制日期和数值标签密度，仍可按住图表查看未标注点的精确值。趋势默认聚合所选成员的全部设备记录，也可筛选单台设备。趋势页预览当前筛选条件下最近 5 条测量记录，可进入独立页面查看该条件下的完整记录。

设备设置页会在用户进入时按需连接所选秤并发现完整 GATT 服务，而不是根据设备名称猜测功能。当前可读取标准 Device Information `0x180A` 中公开的固件、硬件和序列号；发现可写的标准 Current Time `0x2A2B` 后可同步秤端时间。仅当设备实际公开小米二代配置特征 `00001542-0000-3512-2118-0009AF100700` 且带写权限时，才开放秤端单位设置，使用公开记录的 `06 04 00 00/01/02` 命令分别设置 kg、lb 和斤。观我显示单位与本地记录行为统一位于“我的 → 设置”，不混入单台硬件设置。

设备设置页统一提供按需开启的“设备诊断采集”。开启后会重新扫描并检测当前设备，只记录该设备 UUID 对应的广播与连接事件，在内存中保留最近 500 条诊断事件：本地名称、RSSI、广播服务、厂商数据、全部 Service Data、GATT 服务与特征属性、可读特征值、通知、写入载荷、ATT 回执和错误。已知的 `0x181B`、`0x2A9D`、`0x2A9C` 与 ICOMON AFU `FFB2` 数据会附带解析摘要，未知私有载荷保留十六进制原文，便于基于真实设备和固件样本开发独立 parser/adapter。采集不会自动写入文件或上传；报告可能含设备标识、序列号和测量载荷，只能由用户主动导出，不应公开分享或包含绑定密钥。

ATT 成功只表示外设接受了写请求；`0x1542` 的即时读回可能是缓存或非单位响应，因此只有可解析且匹配时才显示“读回确认”，其他情况保留原始载荷并提示核对秤面，不再误报写入失败。

“合并频繁称重记录”是观我的本地记录策略：开启后，同一成员和设备 30 秒内连续完成的测量只保留后一条，不会写入秤端。设备实际公开可通知、可写的私有历史特征 `00002A2F-0000-3512-2118-0009AF100700` 后，设备设置页可手动读取旧款小米最近未确认的历史记录；数据先在内存预览，用户确认导入当前成员后才发送“已收到”回执。实现支持 10 字节体重历史帧的跨通知分片重组，以及 13/26 字节体脂秤历史帧，并包含日期、体重、阻抗校验、去重、超时和最大资源限制。该流程已经过数据样本验证，仍需针对具体型号与固件真机确认。

公开逆向资料明确区分“确认最近历史已收到”和“清空全部历史”，且没有给出可信、可复现的旧款小米清空命令。因此应用不会把 `04 FF FF FF FF` 误称为清空，也不提供可能误写设备的按钮。外部通信协议格式版本 2 可声明 `historyRead` 与 `historyClear`：历史读取支持通知订阅、有序命令、固定长度分帧、时间字段、完成匹配、导入后确认命令、超时和资源上限；清除必须显式标记 `destructive`，不会自动运行。外部协议不能执行脚本或调用内置私有解析器，运行时只能访问协议声明且当前设备实际公开、属性匹配的 GATT 特征。小物称重需要独立的低重量记录模型，也不被误报为硬件设置。

### 小米二代设置真机验证

1. 在真机上安装应用并完全退出其他可能占用秤连接的应用。
2. 唤醒体重秤，进入“设备 → 对应设备 → 设备设置”，等待“设备能力已更新”。
3. 在“协议诊断”中确认实际发现 `1530` 服务、`1542` 可写特征及需要测试的固件版本；没有这些特征时不执行单位写入。
4. 开启“设备诊断采集”，记录原始单位并写入另一单位，在采集结果中确认写入载荷和 ATT 回执；如果即时读回无法解析或仍是旧值，导出报告用于分析，不把它单独视为失败。
5. 保持采集开启，唤醒秤确认屏幕单位变化并重新称量，核对报告中后续广播的单位位与显示单位一致；测试后恢复原单位。秤面变化与下一次广播才是硬件生效的最终证据。

设置命令的确定性烟雾测试可运行：

```sh
swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  ScaleMe/Infrastructure/Bluetooth/Protocols/Xiaomi/XiaomiScaleConfiguration.swift \
  Tests/Smoke/Bluetooth/DeviceConfigurationSmoke.swift \
  -o /tmp/scaleme-device-configuration-smoke
/tmp/scaleme-device-configuration-smoke
```

测量页会在收到首个有效载荷时立即进入测量态，但只提交最终值：小米旧款广播及在 `0x2A9D` RFU 位中携带小米状态的 GATT 变体，均要求离秤位未设置，并同时满足协议稳定位、最短上秤时间和连续读数收敛；ICOMON AFU 使用 `AC 29` 帧中的实时、锁定和最终阶段，只在 `D6` 最终体成分帧到达时保存，并忽略同次测量重复发送的最终帧。AFU 的三字节载荷是带 `0x680000` 零点偏移的克数，两个阻抗字段作为厂商频率定义尚未确认的原始通道保存。符合 Bluetooth SIG 的标准 indication 视为完成的测量；对少数以 notify 连续发送过程值的设备，则要求短时间内多个读数收敛后才保存。一次测量完成后会锁定最终值，离秤期间的回落读数不会覆盖记录。

测量完成后的内容按数据能力展示：纯体重记录只展示体重和 BMI；带阻抗的体脂秤会增加体脂、脂肪量、肌肉、水分、蛋白质、骨量、内脏脂肪和基础代谢等估算项，同时单独展示硬件直接上报的原始阻抗。不会用空占位暗示设备支持未上报的项目，也不会把估算项表述为秤的直接测量值。

测量页持续停留时可以连续完成多次测量。小米设备若未发送离秤标志，应用会根据完成值后的明显下降进入等待重新加载状态，忽略下降过程，并在重量再次上升时开启下一次会话；标准 indication 则按每个独立事件直接完成测量。

协议解析烟雾测试可运行：

```sh
swiftc @Tests/Smoke/Bluetooth/ProtocolSources.rsp Tests/Smoke/Bluetooth/ParserSmoke.swift -o /tmp/scaleme-parser-smoke
/tmp/scaleme-parser-smoke

swiftc @Tests/Smoke/Bluetooth/ProtocolSources.rsp ScaleMe/Infrastructure/Bluetooth/MeasurementSession.swift Tests/Smoke/Bluetooth/MeasurementSessionSmoke.swift -o /tmp/scaleme-session-smoke
/tmp/scaleme-session-smoke

swiftc @Tests/Smoke/Bluetooth/ProtocolSources.rsp Tests/Smoke/Bluetooth/CommunicationRuleSmoke.swift -o /tmp/scaleme-rule-smoke
/tmp/scaleme-rule-smoke
```

设备发现分类测试：

```bash
swiftc @Tests/Smoke/Bluetooth/ProtocolSources.rsp Tests/Smoke/Bluetooth/DiscoveryClassifierSmoke.swift -o /tmp/scaleme-discovery-smoke
/tmp/scaleme-discovery-smoke
```

加密与数据合并烟雾测试可运行：

```sh
swiftc @Tests/Smoke/Bluetooth/ProtocolSources.rsp ScaleMe/Infrastructure/Persistence/SecureAppRepository.swift Tests/Smoke/Persistence/StorageSmoke.swift -o /tmp/scaleme-storage-smoke
/tmp/scaleme-storage-smoke
```

## 数据与医学边界

配置与记录默认保存在应用沙盒的 `ScaleMe/` 目录：`configuration-v4.json` 保存成员、设备、界面语言和应用配置，`measurements-v2.enc` 使用 AES-GCM 加密保存带成员及设备归属的测量记录。设置中可分别开启配置与数据的 iCloud 文件同步；配置策略只能选择单向推送或单向拉取，云端操作均异步执行。本机数据使用仅限当前设备的 Keychain 密钥；开启数据同步后，云端文件使用独立的可同步 iCloud Keychain 密钥，使同一 Apple 账户的设备能够解密数据文件。

界面语言可在应用设置中即时切换，支持简体中文、繁體中文、English、日本語、Français、Deutsch、Español、Português、Русский与한국어。首次启动会匹配系统首选语言；首页与启动动画始终只显示当前所选语言的单一品牌名称和标语。模拟模式的预设家庭成员使用符合各语言姓名习惯的独立人物姓名与亲属称谓，模拟设备卡片及历史记录中的设备名称也使用对应语言。切换语言会直接载入该语言的整套内置模拟数据，并丢弃此前对模拟资料、设备、排序或记录所做的临时修改。

阻抗推导的体脂等指标是消费级估算，不能用于诊断。正式发布前还应完成 HealthKit capability、隐私清单、iCloud 多设备实测、设备矩阵实测和 App Store 隐私申报。

## 协议资料

- [Bluetooth SIG Weight Scale Service 1.0.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/WSS_v1.0.1/out/en/index-en.html)
- [Bluetooth SIG Body Composition Service 1.0](https://www.bluetooth.com/specifications/specs/body-composition-service-1-0/)
- [Mi Body Composition Scale 服务与 0x1542 单位命令逆向记录](https://github.com/freenetwork/ble-in-xiaomi/blob/master/doc/devices/huami.health.scale2.md)
- [Mi Scale 2 BLE 数据布局参考](https://github.com/NeMaksym/mi-scale-2)
- [E.volve / Fitdays `AC 29` 帧零点偏移逆向记录](https://community.home-assistant.io/t/e-volve-fitdays-smart-scale-solved/923243)

本项目的 ICOMON `AC 29 ... D5/D6` 布局来自上述型号的本地真机采集分析；第三方资料只用于辅助确认服务族，未作为该帧字段定义。品牌名称用于兼容性描述，不代表厂商背书。其他私有协议的研究引用集中记录在 [协议支持矩阵](Docs/BluetoothProtocolSupport.md) 中，不作为应用内兼容性标签展示。

## 开发规范

Codex、Claude Code、GitHub Copilot 及其他编码代理在修改项目之前，应完整阅读并遵循 [AGENTS.md](AGENTS.md)。当前项目处于快速开发阶段，不为未发布的历史实现保留兼容层。

项目提交使用 [`commit` skill](.agents/skills/commit/SKILL.md)：它会检查全部未忽略变更、生成英文 Conventional Commit，并在执行任何暂存或提交操作前用中文请求明确确认。
