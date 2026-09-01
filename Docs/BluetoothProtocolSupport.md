# ScaleMe 体重秤协议支持矩阵

协议实现按协议家族组织字节解析，避免把品牌名称判断堆积在蓝牙管理器中。解析器只负责验证和解码载荷；扫描、连接、通知订阅、写入与测量会话分别由上层组件负责。

## 目录约定

- `BluetoothSIG/`：Bluetooth SIG 标准特征。
- `Xiaomi/`：小米旧款广播及已确认的设备配置命令。
- `ICOMON/`：ICOMON AFU 私有 GATT 帧与设备适配器。
- `Huawei/`：华为 Hagrid/WSP 设备识别、帧校验与认证探针。
- `QNAABB/`、`AAASeries/`、`Sinocare/` 等：每个私有协议族直接占用一个同级目录。
- `ScaleBroadcastProtocolCatalog.swift`：非连接式厂商广播的统一分发入口。
- `ScalePayloadError.swift`：解析器共享的错误类型。

目录只表达稳定的协议边界，不表达资料来源或验证阶段。标准规范、数据样本验证、实机样本等状态记录在通信规则元数据和本支持矩阵中，验证状态变化时不移动实现文件。

新增协议必须验证长度、字节序、单位、校验、稳定状态和合理范围，并为每种载荷形状添加确定性数据样本。仅能发现设备、匹配名称或找到网络代码，均不构成“支持”。

## 当前状态

| 协议家族 | 传输 | 当前能力 | 验证级别 |
| --- | --- | --- | --- |
| Bluetooth SIG WSS `181D/2A9D` | 标准 GATT | 体重、单位、时间戳、用户 ID、BMI/身高扩展 | 已实现，数据样本验证通过 |
| Bluetooth SIG BCS `181B/2A9C` | 标准 GATT | 体脂及标准可选身体成分字段 | 已实现，数据样本验证通过 |
| Xiaomi legacy `181B` + `2A2F` | Service Data 广播 + 私有 GATT | 体重、阻抗、稳定/离秤、时间戳；手动读取最近未确认历史并在导入后回执 | 已实现，数据样本验证通过；具体型号与固件仍需真机矩阵 |
| ICOMON AFU `FFB0/FFB2` | 私有 GATT | 实时、锁定、最终体重及双阻抗原始通道 | 已用 `AFU-WL-TZ-A1 / FG2313UWB-D` 真机采集分析；改动后待回归 |
| QN AABB | Manufacturer Data | 体重、稳定状态 | 数据样本验证通过，待真机 |
| AAA002 / AAA007 / AAA013 | Manufacturer Data | XOR 解码、校验、体重、稳定状态 | 数据样本验证通过，待真机 |
| Sinocare | Manufacturer Data | 校验、体重；由测量会话判断收敛 | 数据样本验证通过，待真机 |
| Scaleup | Manufacturer Data | 体重、稳定状态 | 数据样本验证通过，待真机 |
| OKOK V20 / V11 / VF0 / C0 | Manufacturer Data | 多载荷版本、单位、体重、可用阻抗、稳定状态 | 数据样本验证通过，待真机 |
| Etekcity Fit 8S | Manufacturer Data + `FFD0` | 体重、阻抗、稳定状态 | 数据样本验证通过，待真机 |
| Eufy C20 | Manufacturer Data | 体重、可选阻抗、稳定状态 | 数据样本验证通过，待真机 |
| Yunmai X | Manufacturer Data + `1320` | 校验、阶段、体重、最终阻抗 | 数据样本验证通过，待真机 |
| Huawei Scale 3 Hagrid/WSP | `FDEE` 广播 + `181C` 私有 GATT | 提供内置协议手动选择；已识别本地实机 GATT 表，支持无密钥认证探针、WSP 帧校验及 CAK/C1/C2 本机 Keychain 配置 | 完整认证与测量未实现，不宣称兼容 |

“数据样本验证通过”只说明给定字节样本可被确定性解析，不代表任意同品牌设备或固件都已兼容。设备 UI 应继续展示验证级别，不得把数据样本验证等同于真机支持。

## 覆盖边界

调研样本中约有 65 个设备处理器文件，但处理器数量不是可直接移植的协议数量：部分为同一协议的型号变体，另有大量实现依赖连接初始化、用户资料写入、时间同步、历史记录状态机或厂商安全绑定。

本轮优先移植了能从清晰、未加密的广播载荷中完成严格验证的协议族。以下类别仍未实现，扫描到时只能标记为“协议待验证”：

- 需要 GATT 初始化命令、用户资料或多阶段状态机的私有协议。后续必须在对应协议族目录中以独立 adapter 实现，不能塞入广播分发器。
- Xiaomi S400 / S800 等需要绑定密钥或加密载荷的变体。未安全实现授权与密钥保存前不得宣称支持。
- Huawei Scale 2/3 Hagrid 变体要求设备对应的 CAK/C1/C2 完成认证，并使用会话工作密钥保护后续数据。本地 Scale 3 样本已确认 `FDEE` 广播、`181C` 认证特征、WSP 多帧重组，以及“16 字节随机挑战 + `00` 状态码”的认证响应形态；尚未取得实时测量载荷，因此仅识别为“认证待配置”。
- 只有设备名称或型号表、没有可复现载荷数据样本的型号。
- 厨房秤、血压计等非本项目体重/体脂秤范围设备。

因此，观我当前不宣称覆盖公开清单中的全部设备。每次新增支持都应在本表区分“已实现”“数据样本验证”“真机验证”与“计划中”。

## 历史记录与外部操作规则

旧款小米历史通道位于 Weight Service `181D` 或 Body Composition Service `181B` 下的私有特征 `00002A2F-0000-3512-2118-0009AF100700`，取决于设备代际。当前内置流程订阅该特征后依次发送初始化、最近历史查询和传输命令，接收 `0x03` 结束帧后先回写停止命令；只有用户确认导入后，才发送 `04 FF FF FF FF` 接收确认。该确认可能影响设备后续“未读记录”集合，因此不能在预览前自动发送。

通信规则 schema 2 的 `operations` 支持声明：

- `historyRead`：通知订阅、起始命令、响应匹配、固定长度或逐通知分帧、声明式记录 decoder、结束命令、导入后确认命令。
- `historyClear`：必须同时使用 `capability: historyClear` 和 `destructive: true`；当前应用不自动运行，也不会在缺少独立用户确认时发送。
- 受限模板仅允许静态十六进制、`sessionToken16BE`、标准 Current Time，以及最多 8 字节的有界完成响应字段引用；不支持脚本、任意循环或任意特征访问。
- 每次操作强制设置 1 至 60 秒超时、最大响应字节数和最大记录数。运行时还会核对服务、特征及 notify/write 属性。

其他协议族确实存在查询后清除、逐条 ACK、序号关联或终止标志等不同模式。它们只能在取得可复现数据样本并完成对应状态机后加入各自协议目录，不能套用小米命令或仅凭名称开放按钮。

公开仓库中的测试载荷已替换为合成设备地址、认证材料、测量值和日期，保留协议布局、校验与异常场景。实机研究结论与合成 fixture 验证应分别理解；这些测试数据不代表个人测量记录。

## 研究来源

- [openScale 支持设备清单](https://github.com/oliexdev/openScale/wiki/supported-scales-in-openScale)
- [AAAxHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/AAAxHandler.kt)
- [QNHandlerBroadcast.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/QNHandlerBroadcast.kt)
- [SinocareHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/SinocareHandler.kt)
- [ScaleupHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/ScaleupHandler.kt)
- [OkOkHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/OkOkHandler.kt)
- [EtekcityFit8SHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/EtekcityFit8SHandler.kt)
- [EufyC20Handler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/EufyC20Handler.kt)
- [YunmaiXHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/YunmaiXHandler.kt)
- [HuaweiHagridWspHandler.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/HuaweiHagridWspHandler.kt)
- [HuaweiHagridWspLib.kt](https://github.com/oliexdev/openScale/blob/master/android_app/app/src/main/java/com/health/openscale/core/bluetooth/libs/HuaweiHagridWspLib.kt)
- [Bluetooth SIG Weight Scale Service 1.0.1](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/WSS_v1.0.1/out/en/index-en.html)
- [Bluetooth SIG Body Composition Service 1.0](https://www.bluetooth.com/specifications/specs/body-composition-service-1-0/)
- [Xiaomi Bluetooth Mi Scale reverse engineering](https://github.com/oliexdev/openScale/wiki/Xiaomi-Bluetooth-Mi-Scale)
