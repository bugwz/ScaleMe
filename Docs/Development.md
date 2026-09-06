# 开发与验证

本文记录本地运行、自动化检查与真机验证方式。所有代码改动还应遵循仓库根目录的 [AGENTS.md](../AGENTS.md)。

## 环境

- Xcode 26 或更新版本
- iOS 17 或更新版本的运行目标
- Swift 5
- 蓝牙测量、HealthKit 和设备协议验证所需的签名开发账号与物理 iPhone

项目优先使用 SwiftUI、Charts、CoreBluetooth、Foundation、CryptoKit 与 HealthKit 等 Apple 框架，不依赖第三方运行时库。

## 快速运行

1. 使用 Xcode 打开 `ScaleMe.xcodeproj` 并选择 `ScaleMe` scheme。
2. 选择模拟器即可浏览常规界面。
3. 在“设置 → 数据管理”的“数据模拟”中开启模拟数据，可体验多成员、多设备、测量记录和趋势图表。
4. 需要扫描或测量时，使用项目既有签名配置运行到 Xcode 当前选中的物理 iPhone，并在首次搜索设备时允许蓝牙权限。

模拟器成功不代表蓝牙、HealthKit 或具体秤型已经通过硬件验证。

## 最小编译检查

```sh
xcodebuild -project ScaleMe.xcodeproj \
  -scheme ScaleMe \
  -sdk iphoneos \
  -configuration Debug \
  -derivedDataPath .build/AgentCheck \
  CODE_SIGNING_ALLOWED=NO build
```

CoreSimulator 服务异常不应被判断为源码失败；发生此类问题时仍应完成 iPhoneOS 无签名编译。

## 确定性烟雾测试

协议与本地化基础测试：

```sh
swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Bluetooth/ParserSmoke.swift \
  -o /tmp/scaleme-parser-smoke
/tmp/scaleme-parser-smoke

swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Bluetooth/CommunicationRuleSmoke.swift \
  -o /tmp/scaleme-rule-smoke
/tmp/scaleme-rule-smoke

swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Bluetooth/ProtocolSessionSmoke.swift \
  -o /tmp/scaleme-protocol-session-smoke
/tmp/scaleme-protocol-session-smoke

swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  Tests/Smoke/Localization/LocalizationSmoke.swift \
  -o /tmp/scaleme-localization-smoke
/tmp/scaleme-localization-smoke
```

领域模拟数据测试：

```sh
swiftc -module-cache-path /tmp/scaleme-swift-module-cache \
  @Tests/Smoke/Bluetooth/ProtocolSources.rsp \
  ScaleMe/Domain/Models/SimulationData.swift \
  Tests/Smoke/Domain/SimulationDataSmoke.swift \
  -o /tmp/scaleme-simulation-smoke
/tmp/scaleme-simulation-smoke
```

按改动范围还可运行以下测试入口：

| 范围 | 测试文件 |
| --- | --- |
| 测量稳定与完成态 | `Tests/Smoke/Bluetooth/MeasurementSessionSmoke.swift` |
| 连接协议事件与动作 | `Tests/Smoke/Bluetooth/ProtocolSessionSmoke.swift` |
| 发现分类 | `Tests/Smoke/Bluetooth/DiscoveryClassifierSmoke.swift` |
| 设备设置命令 | `Tests/Smoke/Bluetooth/DeviceConfigurationSmoke.swift` |
| 趋势分析 | `Tests/Smoke/Domain/TrendAnalysisSmoke.swift` |
| 本地受保护存储 | `Tests/Smoke/Persistence/StorageSmoke.swift` |
| 本地数据传输 | `Tests/Smoke/Persistence/LocalDataTransferSmoke.swift` |

这些测试是确定性实现检查，不替代真实体重秤和固件验证。

## 真机验证

每个修改代码的任务在完成相关自动化检查后，都应在 Xcode 当前连接并选中的物理 iPhone 上触发一次开发运行。沿用项目已有签名和设备选择，不为绕过问题修改签名配置或切换设备。

至少确认：

- 应用成功安装并启动到真实根视图。
- 本次改动涉及的界面或流程可以进入。
- 蓝牙相关改动使用目标秤及固件采集真实载荷验证。
- HealthKit 相关改动验证系统授权与实际样本落库。

若设备断开、锁定、未信任或无法安装，应完成其余安全检查并记录准确的命令或 Xcode 错误，不得宣称已完成真机验证。

## 协议验证层级

协议兼容状态必须使用一致证据表达：

1. **已实现**：存在可执行解析或会话代码。
2. **Fixture 验证**：通过可复现的捕获载荷和畸形输入测试。
3. **实机验证**：在明确型号与固件上完成测量流程验证。
4. **待完善或验证**：可以在对应协议目录中登记只读协议骨架，并显示在内置协议目录和设备协议选择器中；没有可执行解析或会话实现时不能作为已支持协议或产生测量结果。

发现到设备、名称匹配、网络片段或上游 handler 存在，都不能单独升级为“实机支持”。完整清单维护在 [体重秤协议支持矩阵](BluetoothProtocolSupport.md)。

## 设备诊断流程

适配真实设备时，在设备设置页按需开启诊断采集，唤醒目标秤并完成一次完整操作。重点核对：

- 广播中的服务 UUID、Service Data 与 Manufacturer Data
- GATT 服务、特征和 read/write/notify 属性
- 原始通知、写入载荷、ATT 回执及时间顺序
- 实时、稳定、最终与离秤阶段
- 单位、字节序、阻抗通道、时间字段和重复帧行为

ATT 成功仅表示外设接受写请求，不等于秤端功能已生效。设置类命令应结合后续读回、秤面变化和下一次测量载荷确认。

### 小米二代单位设置

旧款小米体脂秤只有在实际公开私有配置特征 `00001542-0000-3512-2118-0009AF100700` 且该特征可写时，才允许设置秤端单位。验证步骤为：

1. 退出其他可能占用体重秤连接的应用并唤醒秤。
2. 进入目标设备设置，等待 GATT 能力发现完成。
3. 在诊断中确认 `1530` 服务、`1542` 可写特征和固件版本。
4. 记录原始单位，写入另一单位并核对发送载荷与 ATT 回执。
5. 重新唤醒和称量，使用秤面变化与后续广播确认实际生效，测试后恢复原单位。

即时读回可能是缓存或其他响应；只有内容可解析且与目标单位一致时才能视作读回确认。项目不使用缺少可信资料的清空命令，也不会把历史接收确认命令描述为清空。

## 提交前检查

- 运行与改动范围匹配的最小编译和烟雾测试。
- 运行 `git diff --check`。
- 代码改动完成物理 iPhone 开发运行，或记录准确阻塞原因。
- 用户能力、架构、协议、存储或环境发生变化时更新对应文档。
- 不提交生成缓存、诊断报告、健康数据、设备密钥或个人档案。

项目提交必须使用 [commit skill](../.agents/skills/commit/SKILL.md)，并在暂存或创建提交前取得用户明确确认。
