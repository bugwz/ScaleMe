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

## 当前兼容范围

- Bluetooth SIG Weight Scale Service `0x181D` / Weight Measurement `0x2A9D`
- Bluetooth SIG Body Composition Service `0x181B` / Body Composition Measurement `0x2A9C`
- 小米体重秤、体脂秤旧款常见 `0x181B` 广播数据（重量、稳定状态、阻抗）
- 其他可发现设备会显示为“协议待验证”，不会误报为已兼容

不同品牌甚至同品牌不同型号常使用不同私有协议。新增品牌时，应在 `ScaleMe/Bluetooth` 下增加独立 parser/adapter，并使用真实设备数据与固件版本做回归测试。

## 运行

1. 使用 Xcode 26 或更新版本打开 `ScaleMe.xcodeproj`。
2. 模拟器可查看界面和示例趋势；蓝牙扫描必须使用真机。
3. 选择开发团队后安装到 iPhone，首次搜索设备时允许蓝牙权限。
4. 如需使用 iCloud 同步，请在开发者账号为 App ID 启用 iCloud Documents，并确认 Xcode 中的 `iCloud.com.scaleme.app` 容器可用于当前团队。

设备需先在“设备”页的独立扫描界面中添加并可自定义名称。进入“称重”页后，应用会自动监听已关联设备，不再展示或搜索任意附近设备。概览和趋势按当前成员展示数据；趋势默认聚合该成员的全部设备记录，也可筛选单台设备，并支持按住图表左右拖动查看具体时间点。

称重页会在收到首个有效载荷时立即进入测量态，但只提交最终值：小米旧款广播及在 `0x2A9D` RFU 位中携带小米状态的 GATT 变体，均要求离秤位未设置，并同时满足协议稳定位、最短上秤时间和连续读数收敛；符合 Bluetooth SIG 的标准 indication 视为完成的测量；对少数以 notify 连续发送过程值的设备，则要求短时间内多个读数收敛后才保存。一次测量完成后会锁定最终值，离秤期间的回落读数不会覆盖记录。

称重页持续停留时可以连续完成多次测量。小米设备若未发送离秤标志，应用会根据完成值后的明显下降进入等待重新加载状态，忽略下降过程，并在重量再次上升时开启下一次会话；标准 indication 则按每个独立事件直接完成测量。

称重页提供按需开启的小米测量诊断。诊断覆盖 `0x181B` 广播和当前连接设备的 `0x2A9D` / `0x2A9C` 特征值，仅在内存中保留最近 300 条原始数据、相对时间与解析状态，不自动写入文件；用户停止采集后可主动导出，用于针对具体型号和固件验证稳定及离秤标志。

协议解析烟雾测试可运行：

```sh
swiftc ScaleMe/Models/Models.swift ScaleMe/Bluetooth/ScalePayloadParsers.swift Tests/ParserSmoke.swift -o /tmp/scaleme-parser-smoke
/tmp/scaleme-parser-smoke

swiftc ScaleMe/Models/Models.swift ScaleMe/Bluetooth/MeasurementSession.swift Tests/MeasurementSessionSmoke.swift -o /tmp/scaleme-session-smoke
/tmp/scaleme-session-smoke
```

加密与数据合并烟雾测试可运行：

```sh
swiftc ScaleMe/Models/Models.swift ScaleMe/Storage/SecureAppRepository.swift Tests/StorageSmoke.swift -o /tmp/scaleme-storage-smoke
/tmp/scaleme-storage-smoke
```

## 数据与医学边界

配置与记录默认保存在应用沙盒的 `ScaleMe/` 目录：`configuration-v2.json` 保存成员、设备和应用配置，`measurements-v2.enc` 使用 AES-GCM 加密保存带成员及设备归属的测量记录。设置中可分别开启配置与数据的 iCloud 文件同步；配置策略只能选择单向推送或单向拉取，云端操作均异步执行。本机数据使用仅限当前设备的 Keychain 密钥；开启数据同步后，云端文件使用独立的可同步 iCloud Keychain 密钥，使同一 Apple 账户的设备能够解密数据文件。

阻抗推导的体脂等指标是消费级估算，不能用于诊断。正式发布前还应完成 HealthKit capability、隐私清单、iCloud 多设备实测、设备矩阵实测和 App Store 隐私申报。

## 协议资料

- [Bluetooth SIG Weight Scale Service 1.0.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/WSS_v1.0.1/out/en/index-en.html)
- [Bluetooth SIG Body Composition Service 1.0](https://www.bluetooth.com/specifications/specs/body-composition-service-1-0/)
- [openScale: Xiaomi Bluetooth Mi Scale reverse engineering](https://github.com/oliexdev/openScale/wiki/Xiaomi-Bluetooth-Mi-Scale)
- [openScale 支持设备与协议实现](https://github.com/oliexdev/openScale)
- [Mi Scale 2 BLE 数据布局参考](https://github.com/NeMaksym/mi-scale-2)

第三方仓库仅用于理解公开广播格式；品牌名称用于兼容性描述，不代表厂商背书。

## 开发规范

Codex、Claude Code、GitHub Copilot 及其他编码代理在修改项目之前，应完整阅读并遵循 [AGENTS.md](AGENTS.md)。当前项目处于快速开发阶段，不为未发布的历史实现保留兼容层。

项目提交使用 [`commit` skill](.agents/skills/commit/SKILL.md)：它会检查全部未忽略变更、生成英文 Conventional Commit，并在执行任何暂存或提交操作前用中文请求明确确认。
