<div align="center">

<img src="Design/Logo/readme-logo.svg" width="96" height="96" alt="观我">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![Local First](https://img.shields.io/badge/Data-Local%20First-2E8B57)](#隐私与边界)

原生 iOS 体重与身体成分趋势应用

**观察身体变化，看见自己的健康轨迹。**

</div>

观我是一款面向个人与家庭的体重、身体成分记录应用。它通过蓝牙连接兼容的体重秤，将一次次测量整理成可回顾的长期趋势，同时允许用户将数据安全保存在本机、手动导入导出或写入 Apple 健康。

项目仍处于发布前的快速迭代阶段。当前重点是建立清晰、可靠且可扩展的原生实现，并通过真实载荷与实机验证逐步扩大设备兼容范围。

## 它解决什么问题

- **看长期方向**：用可交互趋势图呈现体重、BMI 与已有身体成分指标，而不是只强调某次测量结果。
- **服务家庭场景**：支持多成员档案、多台设备、记录归属以及按成员和设备筛选。
- **降低设备绑定**：优先实现 Bluetooth SIG 标准，并将不同厂商协议隔离为独立解析器与适配器。
- **让数据留在用户手中**：本地优先、测量记录受 iOS 数据保护并可随设备备份恢复，Apple 健康仅在用户主动开启并授权后读写。
- **诚实表达能力边界**：区分硬件原始数据与推导指标；发现设备不等于宣称兼容，样本验证也不等于真机验证。

## 主要能力

- SwiftUI 原生仪表盘、测量流程、历史记录与趋势分析
- 多成员、多设备管理及手动记录；测量详情支持修改成员归属和删除记录，设备历史会结合成员趋势智能归属、自动去重，并持续忽略用户已经删除的设备记录
- BLE 设备发现、标准 GATT 测量与多个隔离的厂商协议解析路径
- 测量沿用已关联设备的广播探测与 GATT 连接流程；圆圈下方提示按测量阶段优先级显示，同级设备事件不反复刷新提示。未开启模拟数据时，仅显示当前测量会话的蓝牙读数，收到数据前显示占位符，不使用旧读数或人为生成的过渡数值
- 受 iOS Complete File Protection 保护且支持设备备份恢复的版本化本地 JSON，以及配置、测量记录或二者组合的明文 JSON 导入导出和带 10 秒确认保护的数据删除
- 实时测量先写入本地文件，再更新正式记录及触发健康共享；保存失败显示“未保存”和重试入口，蓝牙读数暂存于本次运行内存，手动录入保留表单供重试
- 可选的 Apple 健康体重、体脂率双向同步；读取记录只归入本机“本人”档案
- 可独立配置类别、时间范围、来源设备、用户和显示方式的中尺寸桌面趋势小组件，支持重复放置；点击仅进入应用趋势菜单，不改变应用内图表设置
- 10 种界面语言和用于完整体验演示的家庭模拟数据；运行中的修改仅保存在内存，下次启动恢复预设数据
- 默认与色觉友好两套界面主题，均支持跟随系统、浅色和深色外观；色觉友好主题采用高对比度蓝橙主轴，并保留文字、图标等非颜色信息线索
- 支持 VoiceOver 操作：测量连接与完成状态会主动播报，趋势图提供可逐点探索的无障碍数据描述，弹出菜单和确认对话框会隔离背景并管理朗读焦点
- 子页面提供输入名称、单位和校验提示，健康指标可通过无障碍动作排序，图表可通过动作缩放；桌面小组件提供趋势摘要。大字体下首页成员信息纵向展开，手动录入采用单列布局。真机 VoiceOver 验收范围见 [无障碍验证](Docs/Accessibility.md)
- 面向真实设备适配的诊断采集、声明式通信规则和确定性协议测试

详细的设备与协议状态见 [体重秤协议支持矩阵](Docs/BluetoothProtocolSupport.md)。其中会明确标记“已实现”“样本验证”“实机验证”与“计划中”，避免把设备名称匹配或上游代码记录当作兼容结论。
当前已提供 Senssun IF2121A `33 CC` 私有 GATT 协议的实验性测量路径，可读取经校验的实时、稳定及最终体重；尚未确认的身体成分字段不会被命名或保存。

## 设计原则

### 本地优先

应用无需账户即可使用。配置与测量记录以版本化 JSON 保存在应用沙盒，受 iOS Complete File Protection 保护并保持设备备份资格；Apple 健康属于可选能力，不影响本地测量和浏览。

### 标准优先，协议隔离

项目优先支持 Bluetooth SIG Weight Scale Service 与 Body Composition Service。私有协议按品牌或协议族隔离，字节解析与 CoreBluetooth 会话编排分开，便于测试、审计和扩展。

### 趋势优先，避免医疗化

消费级生物电阻抗结果适合观察趋势，不具备医疗诊断或临床精度。界面会区分设备直接上报的数据与基于档案信息推导的估算指标。

### 原生且一致

界面以 SwiftUI、Charts、CoreBluetooth、CryptoKit 与 HealthKit 等 Apple 框架为基础，使用项目自己的设计系统构建清爽、平静且易读的体验。

## 技术概览

ScaleMe 最低支持 iOS 17，采用按职责与用户功能组合的结构：

```text
ScaleMe/
├── App/              # 应用入口、导航、启动流程与全局状态
├── Core/             # 本地化等跨功能基础能力
├── Domain/           # 领域模型、计算与趋势分析
├── Infrastructure/   # 蓝牙、持久化、健康数据与诊断
├── Features/         # 概览、测量、趋势、设备和设置
├── Shared/           # 设计系统与共享组件
└── Resources/        # Assets、String Catalog 与配置资源
ScaleMeWidget/        # iOS 17+ 桌面趋势小组件
ScaleMeWidgetShared/  # 主应用与小组件共享的加密快照数据契约
```

完整的分层、状态流转、蓝牙管线、存储边界与扩展方式见 [架构与实现](Docs/Architecture.md)。

## 运行项目

1. 使用 Xcode 26 或更新版本打开 `ScaleMe.xcodeproj`。
2. 在模拟器中运行，并从“设置 → 数据管理”开启模拟数据以体验完整界面。
3. 如需扫描和测量真实设备，请选择开发团队并安装到 iPhone，在首次使用时授予蓝牙权限。

桌面小组件提供方形、长条和大尺寸三种趋势视图：方形突出最新值与变化方向，长条保留轻量趋势图，大尺寸增加较期初变化、平均值、数值区间和记录数。小组件使用 App Group 与共享 Keychain 读取经 AES-GCM 加密的精简趋势快照。首次运行时，签名团队需要为主应用和 `ScaleMeWidget` 扩展启用对应的 App Groups 与 Keychain Sharing 能力。

蓝牙测量、HealthKit 授权和具体体重秤协议最终都需要签名真机验证。详细环境说明、测试命令与真机检查项见 [开发与验证](Docs/Development.md)。

## 隐私与边界

- 不添加账户、广告标识或默认分析上报。
- 健康测量记录以版本化 JSON 保存在应用沙盒，使用 iOS Complete File Protection，并可包含在用户启用的设备备份中。
- Apple 健康系统授权与应用内同步开关相互独立：用户主动请求读写权限后，写入和读取仍默认关闭；写入仅覆盖“本人”和明确选择的真实设备，读取记录只归入“本人”并标记为 Apple 健康来源。
- 功能入口为“设置 → Apple 健康同步”；页面在授权前明确说明 HealthKit 用途、体重与体脂率读写范围及可选授权。功能检查与演示准备见 [HealthKit 验证指南](Docs/AppReviewHealthKit.md)。
- 诊断信息仅由用户主动采集和导出，可能包含设备标识与测量载荷，不应公开分享。
- 身体成分推导值仅供趋势参考，不用于诊断、治疗或医疗决策。

更多说明见 [数据、同步与隐私](Docs/DataAndPrivacy.md)。

## 文档

- [文档导航](Docs/README.md)
- [架构与实现](Docs/Architecture.md)
- [体重秤协议支持矩阵](Docs/BluetoothProtocolSupport.md)
- [数据、同步与隐私](Docs/DataAndPrivacy.md)
- [开发与验证](Docs/Development.md)
- [Agent 开发约定](AGENTS.md)

## 品牌

中文产品名为“观我”，英文名及 Xcode 工程名为 “ScaleMe”。规范源文件是 [`Design/Logo/logo.svg`](Design/Logo/logo.svg)：白色背景上的薄荷绿圆形与圆内白色 M。README 使用透明背景、紧密裁切的 [`readme-logo.svg`](Design/Logo/readme-logo.svg)，应用内矢量图与 iOS 图标由同一视觉规范派生。iOS 26 使用关闭玻璃材质与高光的分层 `AppIcon.icon`，iOS 17 和 iOS 18 使用同尺寸的不透明 PNG 回退图标。

品牌名称仅用于设备兼容性描述，不代表相关厂商背书。
