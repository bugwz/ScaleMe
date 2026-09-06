# 架构与实现

本文描述 ScaleMe 当前实现的职责边界与主要数据流。项目处于发布前快速迭代阶段：当设计变化时直接替换旧实现，不为开发期内部接口、文件名或本地数据结构保留兼容层。

## 总体结构

Xcode 工程使用文件系统同步组，磁盘目录会直接反映在工程导航中。生产代码采用“稳定职责分层 + 用户功能聚合”的组合方式：

```text
ScaleMe/
├── App/
│   ├── Launch/           # 自定义启动过渡
│   ├── Navigation/       # 根导航
│   └── State/            # 应用级可观察状态
├── Core/Localization/    # 支持语言与语义化文案入口
├── Domain/
│   ├── Models/           # 成员、设备、测量与配置模型
│   └── Trends/           # 纯趋势计算与聚合
├── Infrastructure/
│   ├── Bluetooth/        # CoreBluetooth 运行时、协议契约、协议实现与诊断
│   ├── Health/           # Apple 健康写入
│   ├── Persistence/      # 本地文件、系统数据保护与数据传输
├── Features/             # Dashboard、Measurement、Trends、Devices、Settings
├── Shared/               # 设计系统、组件与输入桥接
└── Resources/            # Assets、String Catalog 与 entitlements
```

`Tests/Smoke/` 按生产职责镜像组织确定性可执行测试；`Design/` 保存品牌源文件；`Tools/` 保存资源生成等开发工具。

## 依赖方向

核心依赖关系保持为：

```text
Features ──> App State ──> Domain
    │             │
    └─────────────┴──────> Infrastructure ──> Apple frameworks / device

Shared ──> SwiftUI
```

- `Domain` 保存不依赖 UI 和设备会话的模型与纯计算，便于独立测试。
- `Infrastructure` 封装蓝牙、文件系统、Keychain 和 HealthKit 等外部边界。
- `App/State/MeasurementStore.swift` 负责将配置、记录、设备测量和可选集成组织为应用级状态。
- `Features` 负责用户流程与视图组合，不在视图内重新实现协议解析或持久化规则。
- `Shared` 提供统一的视觉语言和可复用交互组件，避免功能页面产生互不一致的一次性实现。

## 测量数据流

一次蓝牙测量大致经过以下阶段：

```text
广播 / GATT notification
        ↓
CoreBluetooth 会话编排
        ↓
标准解析器或独立厂商适配器
        ↓
MeasurementSession 稳定性与完成态判断
        ↓
BodyMeasurement 领域记录
        ↓
应用状态 → 受系统数据保护的持久化 → 趋势与可选 HealthKit 写入
```

扫描发现、载荷解码和测量会话是不同职责：

- `BluetoothScaleCoordinator` 只作为 CoreBluetooth 生命周期与各会话组件之间的总协调入口；界面通过它观察连接和测量状态。
- `Bluetooth/Contracts` 定义协议描述、广播输入、事件、动作和可选能力接口，不依赖 `CBPeripheral`。
- `Bluetooth/Runtime/ScaleProtocolRegistry` 是内置协议的统一注册与匹配入口。广播解析器在各自协议目录中直接实现 `ScaleAdvertisementProtocolAdapter`，注册顺序用于处理宽泛格式与特定格式的优先级。
- 每个已实现协议在自身解析器或会话类型中定义 `communicationRule`；尚待实现的协议也在各自品牌或协议族目录中定义只读的协议骨架，记录稳定 ID、已知匹配条件、验证级别和资料来源。`CommunicationRuleCatalog` 只聚合这些定义，不保存品牌协议细节。
- 连接协议通过 `ScaleConnectedProtocolSession` 接收连接、服务、特征、通知、写入结果和定时器事件，并返回 discover、subscribe、write、测量阶段、最终测量或历史语义动作。当前 Senssun IF2121、Wolai AFU、Xiaomi XMTZC04HM 与 Huawei Hagrid 的连接测量均使用该路径；分片缓存、校时、稳定/最终帧关联、认证握手、会话密钥和最终结果 ACK 不保存在协调器中。
- 需要设备密钥的连接协议仍由协调器在会话创建边界从 Keychain 取得认证材料，并只把当前会话需要的凭据、成员资料和型号上下文传给具体协议会话；协议注册表可以单独登记这类上下文会话的描述与能力，而不提供无效的无参工厂。
- 历史读取、导入确认、硬件单位和校时分别使用 `ScaleHistoryCapability`、`ScaleHistoryImportConfirmationCapability`、`ScaleUnitConfigurationCapability` 与 `ScaleTimeSynchronizationCapability`。设备不支持某项能力时不实现对应接口，不保留空方法。Wolai AFU 的历史聚合、逐条 ACK、静默完成及超时，以及 Xiaomi XMTZC04HM 的游标查询、定长记录重组、停止、导入确认、硬件单位命令和时间同步，都由各自协议会话负责；协调器只处理手动/自动导入结果、通用写入回执和界面状态。
- `BluetoothScaleState` 集中定义发现结果、连接状态、设备设置和历史读取等界面可观察状态。
- `PairedScaleRegistry` 维护已关联设备、自动历史读取范围及所选通信规则的索引，避免协调器持有多组必须同步更新的平行字典。
- `DeviceDiagnosticLog` 独立负责诊断采集生命周期、容量限制和报告格式，协调器只记录蓝牙事件。
- 发现分类只决定候选设备如何展示，不等同于协议兼容结论。
- 标准 GATT 特征与厂商广播即使共享服务 UUID，也走不同解析路径。
- 每个私有协议族维护独立 parser/adapter，解析前检查长度、标志、字节序、单位和合理范围。
- `MeasurementSession` 处理实时值、稳定值、最终值、离秤和重复最终帧，只有满足协议完成条件的数据才进入记录。
- 体脂等推导指标由领域层根据明确的档案输入计算，不伪装成硬件直接上报值。

协议实现、验证证据和型号边界见 [体重秤协议支持矩阵](BluetoothProtocolSupport.md)。

## 通信规则

内置通信规则为经过代码审查的能力目录，稳定 ID 使用 `protocol.builtin.<slug>`。外部导入规则使用 `protocol.custom.<slug>`，只能描述受约束的广播字段或设备实际公开、属性匹配的 GATT 操作，不能执行脚本，也不能取得内置命名空间。

外部文件当前使用 schema 3。公开结构由 `ExternalCommunicationRuleDocument` 和 `ExternalCommunicationRuleDefinition` 明确定义，只包含元数据、匹配条件、声明式 decoder、受限 operations、型号与 GATT 目标。`origin`、`verification`、`implementation`、`sourceURL` 和 `builtInParser` 属于运行时或信任边界，不进入公开文件格式；导入后统一标记为本地、未经验证，并由 decoder 与 operations 推导实际能力。

设备可选择匹配的通信规则。规则分别声明传输方式、服务/特征、载荷边界、字段解码、验证级别和运行要求。历史读取与清除属于显式操作：清除必须标记为破坏性，不能在普通测量流程中自动执行。

## 状态与并发

SwiftUI 可观察状态保持在主 actor。CoreBluetooth delegate、受保护文件读写与 HealthKit 操作具有明确的并发边界：设备或系统健康服务暂时不可用时，本地记录和浏览仍能继续工作。

持久化写入由专用 actor 串行化，避免配置变化与连续测量并发覆盖文件。配置与测量记录使用不同的本地文件，具体边界见 [数据、同步与隐私](DataAndPrivacy.md)。

## 趋势分析

趋势计算位于 `Domain/Trends/TrendAnalysis.swift`，与 SwiftUI Charts 展示分离。当前支持：

- 按成员、设备、指标和时间范围筛选
- 逐次测量的真实时间轴
- 根据跨度形成日、周或月均值的汇总趋势
- 聚焦当前数据或展示完整区间
- 多指标分图展示、点位查询和横屏全屏图表

图表只展示记录中实际存在或可明确推导的指标，不用空占位暗示设备能力。

## 本地化

简体中文是源语言。界面支持简体中文、繁體中文、English、日本語、Français、Deutsch、Español、Português、Русский与한국어。

本地化资源位于 `ScaleMe/Resources/Localization/`：默认 SwiftUI 文本在 `Localizable.xcstrings`，共享及各功能域使用独立 String Catalog，App 名称使用 `InfoPlist.xcstrings`。运行时选择的语义文本通过 `Core/Localization` 统一访问，不使用散落的 `.lproj` 文件或按语言编写 Swift 分支。

## 设计系统与品牌资源

共享色彩、卡片、设置面板、下拉菜单和页面背景集中在 `ScaleMe/Shared/DesignSystem/DesignSystem.swift`。功能页使用这些组件组合界面，避免依赖默认 `List`、`Form` 等系统样式形成不一致的产品体验。

品牌资源以 `Design/Logo/logo.svg` 为规范源，应用内矢量、README 标记、预览图和 App Icon 保持同步。iOS 26 使用 `ScaleMe/AppIcon.icon` 中关闭玻璃效果的绿色圆形与白色 M 分层资源；iOS 17 和 iOS 18 的回退 App Icon 由 `Tools/AssetGeneration/GenerateAppIcon.swift` 生成，确保输出不含 alpha 通道且视觉尺寸一致。

## 扩展指南

### 新增设备协议

1. 根据服务、特征、帧结构和会话方式确定真实协议族，不以设备名作为唯一判断。
2. 在 `Infrastructure/Bluetooth/Protocols/<协议族>/` 下添加隔离的解析器；广播协议由解析器类型实现 `ScaleAdvertisementProtocolAdapter`，连接协议实现 `ScaleConnectedProtocolSession` 及实际支持的可选能力接口。
3. 使用真实捕获载荷建立正常、边界与畸形数据 fixture。
4. 在同一协议类型中定义 `communicationRule`，再将适配器加入 `ScaleProtocolRegistry` 和中央规则聚合列表；除非新增的是通用能力，不能在 `BluetoothScaleCoordinator` 增加品牌或型号分支。
5. 更新协议支持矩阵，准确标记当前证据层级。
6. 在目标型号和固件上验证后，才将其标为硬件验证。

### 新增用户功能

优先将纯模型与计算放入 `Domain`，系统能力放入 `Infrastructure`，用户流程放入对应 `Features`，跨功能 UI 放入 `Shared`。新增用户文案必须进入 String Catalog；新增视觉样式应先判断是否属于设计系统能力。
