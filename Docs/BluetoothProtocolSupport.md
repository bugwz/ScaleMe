# ScaleMe 体重秤协议支持矩阵

> 返回 [文档导航](README.md) · 查看 [架构与实现](Architecture.md) · 查看 [开发与验证](Development.md)

应用的内置协议目录同时展示已经明确实现并验证的协议，以及已经登记但仍待完善或验证的设备协议。后者只提供识别信息和研究来源，不会因此宣称设备已经受支持；每项定义都放在对应品牌或协议族目录中。

协议实现按协议家族组织字节解析，避免把品牌名称判断堆积在蓝牙管理器中。解析器只负责验证和解码载荷；扫描、连接、通知订阅、写入与测量会话分别由上层组件负责。

## 目录约定

- `BluetoothSIG/`：Bluetooth SIG 标准特征。
- `Xiaomi/`：小米旧款广播及已确认的设备配置命令。
- `Wolai/`：Wolai AFU 私有 GATT 帧与设备适配器。
- `Senssun/`：香山 IF2121 系列的 `33 CC` 实时、阶段及分片最终结果帧。
- `Huawei/`：华为 Hagrid/WSP 设备识别、分帧校验、认证、会话加密与测量载荷解析。
- `QNAABB/`、`AAASeries/`、`Sinocare/` 等：每个私有协议族直接占用一个同级目录。
- `Contracts/ScaleProtocolAdapter.swift`：协议描述、输入输出、事件动作及可选能力契约。
- `Runtime/ScaleProtocolRegistry.swift`：内置协议的统一注册与广播匹配入口。
- `ScalePayloadError.swift`：解析器共享的错误类型。

目录只表达稳定的协议边界，不表达资料来源或验证阶段。标准规范、数据样本验证、实机样本等状态记录在通信规则元数据和本支持矩阵中，验证状态变化时不移动实现文件。

新增协议必须验证长度、字节序、单位、校验、稳定状态和合理范围，并为每种载荷形状添加确定性数据样本。仅能发现设备、匹配名称或找到网络代码，均不构成“支持”。

## 当前状态

| 协议家族 | 传输 | 当前能力 | 验证级别 |
| --- | --- | --- | --- |
| Bluetooth SIG WSS `181D/2A9D` | 标准 GATT | 体重、单位、时间戳、用户 ID、BMI/身高扩展 | 已实现，数据样本验证通过 |
| Bluetooth SIG BCS `181B/2A9C` | 标准 GATT | 体脂及标准可选身体成分字段 | 已实现，数据样本验证通过 |
| Xiaomi legacy `181B` | Service Data 广播 | 体重、阻抗、稳定/离秤、时间戳 | 已实现广播解析；该代际的 GATT 历史协议尚无真机抓包，不声明支持 |
| Xiaomi XMTZC04HM `181D` + `2A2F` | Service Data 广播 + 私有 GATT | 体重、稳定/离秤、时间戳；自动或手动读取秤内历史并在成功导入后回执 | 已迁移为独立广播适配器与连接会话，MI SCALE2 HCI 抓包及 fixture 验证通过；待 iOS 真机回归 |
| Wolai AFU `FFB0/FFB1/FFB2` | 私有 GATT | 主动连接、时间初始化、实时/锁定/最终体重、可选双阻抗、最终结果回执及历史读取 | 已用 `AFU-WL-TZ-A1 / FG2313UWB-D` 真机采集分析并完成 fixture 验证；抽象后的 iOS 会话待真机回归 |
| Senssun IF2121A `FFF0/FFF1/FFF3` | 私有 GATT | `33 CC` 校验、实时/稳定体重、体成分检测阶段、动态测量序号、40 字节最终结果分片重组；未确认字段不作为阻抗或心率入库 | 四次同机测量抓包 fixture 验证通过；实现后待 iPhone 真机回归 |
| QN AABB | Manufacturer Data | 体重、稳定状态 | 数据样本验证通过，待真机 |
| AAA002 / AAA007 / AAA013 | Manufacturer Data | XOR 解码、校验、体重、稳定状态 | 数据样本验证通过，待真机 |
| Sinocare | Manufacturer Data | 校验、体重；由测量会话判断收敛 | 数据样本验证通过，待真机 |
| Scaleup | Manufacturer Data | 体重、稳定状态 | 数据样本验证通过，待真机 |
| OKOK V20 / V11 / VF0 / C0 | Manufacturer Data | 多载荷版本、单位、体重、可用阻抗、稳定状态 | 数据样本验证通过，待真机 |
| Etekcity Fit 8S | Manufacturer Data + `FFD0` | 体重、阻抗、稳定状态 | 数据样本验证通过，待真机 |
| Eufy C20 | Manufacturer Data | 体重、可选阻抗、稳定状态 | 数据样本验证通过，待真机 |
| Yunmai X | Manufacturer Data + `1320` | 校验、阶段、体重、最终阻抗 | 数据样本验证通过，待真机 |
| Xiaomi XMTZC04HM / `MI SCALE2` | `181D` Service Data 广播 | 体重、kg/lb/斤、稳定/离秤、时间戳 | 上游真实抓包 fixture 验证通过，待本项目真机 |
| Silvergear Smart Scale 108 | Company ID `A0AC` Manufacturer Data + `FFB0` | 混淆解码、5 位校验、克数、稳定状态；不读取未确认的身体数据字段 | 上游两组 iOS PacketLogger fixture 验证通过，待本项目真机 |
| Huawei Scale 2 Pro / 3 / 3 Pro、Honor Scale 2 Hagrid/WSP | `FDEE` 广播 + `181C`、`1805`、`181B` 私有 GATT | 支持手动配置蓝牙地址与 CAK/C1/C2；独立连接会话负责 WSP 分帧、双向认证、C3/根密钥派生、AES-CTR 工作密钥、用户资料、状态轮询及实时测量解析，Keychain 读取留在协调器边界 | 抓包与确定性会话 fixture 验证通过；完整 iOS 会话待真机验证 |

“数据样本验证通过”只说明给定字节样本可被确定性解析，不代表任意同品牌设备或固件都已兼容。设备 UI 应继续展示验证级别，不得把数据样本验证等同于真机支持。

## 已接入广播格式

### Xiaomi XMTZC04HM / MI SCALE2

识别条件为本地名严格等于 `MI SCALE2`，或 Manufacturer Data 的 Bluetooth Company Identifier 为 Huami `0x0157`；同时必须出现恰好 10 字节的 `0x181D` Service Data。这样不会把任意标准 WSS 设备误判成小米。

| 偏移 | 长度 | 格式 |
| --- | --- | --- |
| 0 | 1 | flags：bit 0=lb，bit 4=斤，bit 5=锁定，bit 7=离秤 |
| 1 | 2 | 小端无符号重量；kg=`raw/200`，lb=`raw/100×0.45359237`，斤=`raw/100×0.5` |
| 3 | 7 | 小端年份、月、日、时、分、秒；仅锁定读数采用该时间 |

fixture `23 B0 36 E4 07 01 02 03 04 05` 解码为 `63.5029318 kg`、锁定状态。该变体不发送阻抗，观我不会虚构体脂数据。

### Wolai AFU 测量阶段与路由

已解析为 Wolai AFU 的设备使用 `FFB0/FFB1/FFB2` 连接会话：实时 `D5` 帧立即更新体重，锁定 `D5` 帧保持“正在测量身体成分”阶段，只有最终 `D6` 帧完成测量并发送回执。重复锁定体重不得触发通用稳定窗口完成逻辑。最终帧保留设备提供的两路阻抗；零阻抗最终帧仍可作为仅体重结果。

自动识别和手动指定的连接协议均不允许其他广播解析器接管测量。回归测试使用合成的重叠广播验证路由隔离，并用已有 AFU 报文 fixture 验证实时、锁定、最终阶段；合成重叠广播不代表已确认该 AFU 真机会广播这些字节，端到端行为仍需真机回归。

AFU 当前已确认的字段是体重与双阻抗，不包含设备直接报告的体脂率。历史版本曾由应用推算体脂等指标，`eee4add` 已移除这项逻辑；恢复测量阶段不等于恢复这些推算值。

### Silvergear Smart Scale 108

CoreBluetooth 提供的 Manufacturer Data 为 2 字节小端 Company ID `AC A0`，后接 12 字节厂商载荷。载荷前 6 字节是设备 MAC 的逆序副本；后 6 字节记为 `p`：

| 偏移（相对 `p`） | 长度 | 格式 |
| --- | --- | --- |
| 0 | 1 | 与 `A0` 异或后的状态；bit 7=锁定 |
| 1 | 3 | 每字节与 `A0` 异或后组成 24 位大端值；克数=`value-0x8C0000` |
| 4 | 1 | 帧类型：`0D`=体重，`06`=未确认的身体数据 |
| 5 | 1 | 低 5 位=`sum(p[0...4]) & 0x1F`；高 3 位是秤面显示单位，不参与重量换算 |

实现还要求载荷恰好 12 字节、可选服务列表若存在则必须包含 `FFB0`，并把重量限制在 `2...300 kg`。`06` 帧只有一个人体样本和一个物体样本，证据不足以把其中字段命名为阻抗，因此当前严格拒绝，不写入身体成分。

## 覆盖边界

以下类别仍未实现或尚未完成验证，会作为“待完善或验证的协议”显示，但扫描到时仍只能标记为“协议待验证”：

- 需要 GATT 初始化命令、用户资料或多阶段状态机的私有协议。后续必须在对应协议族目录中以独立 adapter 实现，不能塞入广播分发器。
- Xiaomi S400 / S800 等需要绑定密钥或加密载荷的变体。未安全实现授权与密钥保存前不得宣称支持。
- Huawei Hagrid/WSP 变体要求设备对应的蓝牙地址与 CAK/C1/C2 完成认证，并使用工作密钥保护后续数据。Android HCI 样本已确认 `181C` 认证、`1805` 状态轮询、`181B` 实时/历史数据特征及 WSP 多帧形态；固定 fixture 已验证根密钥、AES-CTR 与实时测量字段。由于 CoreBluetooth 不公开真实蓝牙地址，地址必须与密钥一起手动配置；完整 iOS 会话仍需真机验证。
- 只有设备名称或型号表、没有可复现载荷数据样本的型号。
- 厨房秤、血压计等非本项目体重/体脂秤范围设备。

每次新增支持都必须在对应协议目录中加入真实实现和 fixture，并在本表区分“已实现”“数据样本验证”与“真机验证”。

## 历史记录与外部操作规则

Xiaomi XMTZC04HM（广播名 `MI SCALE2`）的历史通道位于 Weight Service `181D` 下的私有特征 `00002A2F-0000-3512-2118-0009AF100700`。HCI 抓包确认的流程为：订阅通知，发送 `01 98 84 30 59` 查询，接收 `01 + UInt16LE 数量 + 原样回显的 4 字节游标` 后发送 `02`，再按每条 10 字节接收历史记录。设备以 `03` 结束，应用回写 `03` 停止；只有用户确认导入后，才发送 `04 + 同一查询游标` 接收确认。两次官方应用会话在回执后仍能用相同游标读到旧记录，因此该命令不能描述为“清空历史”。`181B` 设备的私有历史协议尚无本项目可复现的真机抓包，不能套用 `181D` 状态机或声明支持。

通信规则 schema 3 将外部文件定义与内部运行时规则分开。外部定义不能携带 `builtInParser`、验证级别、实现级别或内置来源声明；导入后能力由实际 decoder 和 operations 推导。其 `operations` 支持声明：

- `historyRead`：通知订阅、起始命令、响应匹配、固定长度或逐通知分帧、声明式记录 decoder、结束命令、导入后确认命令。
- `historyClear`：必须同时使用 `capability: historyClear` 和 `destructive: true`；当前应用不自动运行，也不会在缺少独立用户确认时发送。
- 受限模板仅允许静态十六进制、`sessionToken16BE`、标准 Current Time，以及最多 8 字节的有界完成响应字段引用；不支持脚本、任意循环或任意特征访问。
- 每次操作强制设置 1 至 60 秒超时、最大响应字节数和最大记录数。运行时还会核对服务、特征及 notify/write 属性。

其他协议族确实存在查询后清除、逐条 ACK、序号关联或终止标志等不同模式。它们只能在取得可复现数据样本并完成对应状态机后加入各自协议目录，不能套用小米命令或仅凭名称开放按钮。

公开仓库中的测试载荷已替换为合成设备地址、认证材料、测量值和日期，保留协议布局、校验与异常场景。实机研究结论与合成 fixture 验证应分别理解；这些测试数据不代表个人测量记录。

## 研究来源

上游代码许可、固定版本文件映射及 Swift 改编说明见 [许可证与第三方声明](../LICENSES/README.md)。来源链接不能替代许可证和版权声明。

- [Xiaomi XMTZC04HM 广播实现与格式（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/xiaomi-mi-scale-legacy.ts)
- [Xiaomi XMTZC04HM 抓包 fixture（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/tests/scales/xiaomi-mi-scale-legacy.test.ts)
- [Silvergear 108 广播实现与格式（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/silvergear-108.ts)
- [Silvergear 108 iOS 抓包 fixture（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/tests/scales/silvergear-108.test.ts)
- [AAAxHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/AAAxHandler.kt)
- [QNHandlerBroadcast.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/QNHandlerBroadcast.kt)
- [SinocareHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/SinocareHandler.kt)
- [ScaleupHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/ScaleupHandler.kt)
- [OkOkHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/OkOkHandler.kt)
- [EtekcityFit8SHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/EtekcityFit8SHandler.kt)
- [EufyC20Handler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/EufyC20Handler.kt)
- [YunmaiXHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/YunmaiXHandler.kt)
- [HuaweiHagridWspHandler.kt（固定版本）](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/HuaweiHagridWspHandler.kt)
- [HuaweiHagridWspLib.kt（固定版本）](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/libs/HuaweiHagridWspLib.kt)
- [Bluetooth SIG Weight Scale Service 1.0.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/WSS_v1.0.1/out/en/index-en.html)
- [Bluetooth SIG Body Composition Service 1.0](https://www.bluetooth.com/specifications/specs/body-composition-service-1-0/)
- [Xiaomi Bluetooth Mi Scale reverse engineering](https://github.com/oliexdev/openScale/wiki/Xiaomi-Bluetooth-Mi-Scale)
