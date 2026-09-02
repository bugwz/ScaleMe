# ScaleMe 体重秤协议支持矩阵

> 返回 [文档导航](README.md) · 查看 [架构与实现](Architecture.md) · 查看 [开发与验证](Development.md)

本页调研基线为 2026-09-02：

- `ble-scale-sync` commit [`e5060b4`](https://github.com/KristianP26/ble-scale-sync/tree/e5060b4e43e2d08ecace7e327145c777872ea93f)。其说明页仍写“32”，但该 commit 的实际 `adapters` 数组已有 33 个实例；这里以代码注册表为准并记录该差异。
- `openScale` commit [`6613db5`](https://github.com/oliexdev/openScale/tree/6613db5838e4674a19652441073f82b3ee3d7009)，其 `ScaleFactory.createHandlers()` 实际注册 63 个 handler 实例，覆盖广播、GATT 与 Classic SPP。

上游“支持”表示其自身代码路径和测试状态，并不自动成为观我的硬件兼容声明。观我只把已经逐字节核对、具有可复现 fixture、并能在 iOS CoreBluetooth 生命周期中完整运行的路径列为内置可执行协议。

协议实现按协议家族组织字节解析，避免把品牌名称判断堆积在蓝牙管理器中。解析器只负责验证和解码载荷；扫描、连接、通知订阅、写入与测量会话分别由上层组件负责。

## 目录约定

- `BluetoothSIG/`：Bluetooth SIG 标准特征。
- `Xiaomi/`：小米旧款广播及已确认的设备配置命令。
- `Wolai/`：Wolai AFU 私有 GATT 帧与设备适配器。
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
| Wolai AFU `FFB0/FFB2` | 私有 GATT | 实时、锁定、最终体重及双阻抗原始通道 | 已用 `AFU-WL-TZ-A1 / FG2313UWB-D` 真机采集分析；改动后待回归 |
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
| Huawei Scale 3 Hagrid/WSP | `FDEE` 广播 + `181C` 私有 GATT | 提供内置协议手动选择；已识别本地实机 GATT 表，支持无密钥认证探针、WSP 帧校验及 CAK/C1/C2 本机 Keychain 配置 | 完整认证与测量未实现，不宣称兼容 |

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

### Silvergear Smart Scale 108

CoreBluetooth 提供的 Manufacturer Data 为 2 字节小端 Company ID `AC A0`，后接 12 字节厂商载荷。载荷前 6 字节是设备 MAC 的逆序副本；后 6 字节记为 `p`：

| 偏移（相对 `p`） | 长度 | 格式 |
| --- | --- | --- |
| 0 | 1 | 与 `A0` 异或后的状态；bit 7=锁定 |
| 1 | 3 | 每字节与 `A0` 异或后组成 24 位大端值；克数=`value-0x8C0000` |
| 4 | 1 | 帧类型：`0D`=体重，`06`=未确认的身体数据 |
| 5 | 1 | 低 5 位=`sum(p[0...4]) & 0x1F`；高 3 位是秤面显示单位，不参与重量换算 |

实现还要求载荷恰好 12 字节、可选服务列表若存在则必须包含 `FFB0`，并把重量限制在 `2...300 kg`。`06` 帧只有一个人体样本和一个物体样本，证据不足以把其中字段命名为阻抗，因此当前严格拒绝，不写入身体成分。

## 两个上游项目的协议族整理

以下按线上的通信格式合并同源型号，避免把换牌型号数误当成不同协议数。

| 协议族 / 上游适配器 | 主要型号 | 传输与报文骨架 | 观我状态 |
| --- | --- | --- | --- |
| SIG WSS / BCS | 通用标准秤、Renpho ES-WBE28、Beurer BF720/BF105/BF500/BF788/BF950 | `181D/2A9D`、`181B/2A9C`；部分设备还要求 `181C/2A9F` 用户同意 | 标准测量已接入；用户同意/配对流程未泛化 |
| Xiaomi legacy 181B | MIBCS、MIBFS、XMTZC05HM | 13 字节 `181B` Service Data；flags、时间、阻抗、重量 | 已接入 |
| Xiaomi legacy 181D | XMTZC04HM / MI SCALE2 | 10 字节 `181D` Service Data，见上文 | 已接入 |
| Xiaomi S400/S800 | S400、ms116 S800 | `FE95` 加密 MiBeacon；S800 需要逐设备 bind key，8 电极数据还依赖加密 GATT | 协议骨架已登记；等待安全授权与密钥流程 |
| QN / Renpho 多方言 | ES-CS20M、ES-32MD、Elis 1、FITINDEX、Sencor、QN-Scale | `FFF0/FFF1/FFF2`、`FFE0/FFE1/FFE3`、`AE00/AE01/AE02` 或 `1A10/2A10/2A11`；`55 AA`/扩展帧、配置写入与多阶段完成 | AABB 非连接广播已接入；连接方言待会话适配器 |
| Renpho ES-26BB / R-MSC04 | ES-26BB-B、MorphoScan Nova | `1A10`；`2A10` 通知、`2A11` 写，MSC04 另有 `2A12` 最终指示；`55 AA` 帧 | 协议骨架已登记；需启动命令与跨帧状态 |
| FFF0 / FFF1 / FFF2 | Senssun、Digoo、Inlife、Picooc、Vitafit VT701、Etekcity ESF551 | 同一 UUID 上存在完全不同帧：Senssun `A5/B0/C0/D0`，Picooc opcode+length，Vitafit `5A/A5 ... 26 ... checksum AA` 等 | 不按 UUID 猜协议；待各自初始化和 fixture |
| FFF0 / FFF4 / FFF1(或 FFF3) | 1byone/Eufy C1/P1、Excelvan CF369、Hesley、Koogeek S1、Cult、Hume Dara 2 | 常见 `CF` 测量帧，但端序、字段和完成条件不同；多需时间/用户资料写入 | 各适配器骨架已登记；Eufy C20 的独立广播格式已可执行 |
| Eufy P2 / P2 Pro | T9148/T9149 | `FFF0`，`FFF1` 写、`FFF4` AES 认证、`FFF2` 数据 | 协议骨架已登记；等待独立密钥会话，不把未知字段当阻抗 |
| FFB0 / FFB1 / FFB2 / FFB3 | Active Era、1byone new、Robi S9、Hutbit、MGB、Runstar、Relaxmedic、HealthKeep、FitTrack、Dr Trust | 多为 20 字节 `AC/AB` 或分片帧；需要 profile/time 握手、校验、跨帧缓存，部分 `FFB3` 承载最终值或历史 | Wolai AFU 实机协议独立接入；其余不能因 UUID 相同而复用 |
| Yunmai | Signal、Mini、SE | `FFE0` 家族，`FFE4` 通知、`FFE9` 写，先发 `0D 05 13 00 16` | 协议骨架已登记；Yunmai X 的非连接广播已可执行 |
| Beurer / Sanitas vendor | BF700/BF710/BF800、SBF70/SBF75 | `FFE0/FFE1` 同特征读写，需用户资料和状态机 | 协议骨架已登记；运行时未完成 |
| Soehnle | Shape200/100/50、Style100 | 自定义 `352e3001...` 通知、`352e3002...` 命令，需用户槽 1 | 协议骨架已登记；运行时未完成 |
| Exingtech Y1 | vscale | 自定义 `f433bd80...` 服务、`1a2ea400...` 通知、`29f11080...` 写；20 字节帧含体重、脂肪、水分、骨量、肌肉和内脏脂肪 | 协议骨架已登记；需用户资料初始化与真机 fixture |
| Medisana / Trisa / ADE | BS430/440/444、Trisa Body Analyze、ADE BA1600 | `78B2` 或相近私有服务，`8A21/8A24` 测量、`8A81/8A82` 命令/事件 | 协议骨架已登记；需账户/用户与历史状态机 |
| Salter | SA00656 / SA00432 | `FFCC/FFC1` 轮询；读取 8 个记录槽并处理秤端时钟 | 协议骨架已登记；运行时未完成 |
| Huawei AH100 / CH100S | 华为早期体脂秤 | `FAA0/FAA1/FAA2`，MAC XOR；CH100S 另有 AES-CTR 与两段 `0E/8E`、`10/90` 帧 | 协议骨架已登记；运行时未完成 |
| Huawei Hagrid/WSP | Scale 2/3 | `FDEE` 身份、`181C` 私有 WSP，多帧 CRC、CAK/C1/C2 认证与会话密钥 | 诊断与凭据保存已接入；完整认证/测量未完成 |
| Omron WLC/WLP | HBF-702T 等 | 自定义 `ecbe3980...` 服务、多组 TX/RX 特征、地址块与环形记录 | 协议骨架已登记；运行时未完成 |
| Weight Gurus / BodyConnect | A3 等 | `8A22/8A24` 测量、`8A81/8A82` 命令/事件；密码、挑战、用户槽、资料与时间 | 协议骨架已登记；运行时未完成 |
| Classic SPP | iHealth HS3 | 串口字节流；`A0 09 A6 28` 后取 BCD 重量 | 已登记为“平台不支持”；CoreBluetooth 不提供 SPP/RFCOMM |

### 上游注册表审计清单

`ble-scale-sync` 的 33 个实际注册实例为：Eufy P2、Senssun、QN、Renpho ES-WBE28、Renpho R-MSC04、Renpho ES-26BB、Beurer BF720、Xiaomi XMTZC04HM、Silvergear 108、Xiaomi Mi Scale 2、Xiaomi S800、Yunmai、Beurer/Sanitas、Sanitas SBF72、Soehnle、Medisana、Trisa、ES-CS20M、Exingtech Y1、Excelvan CF369、Hesley、Koogeek S1、Inlife、Digoo、1byone/Eufy、1byone new、Active Era、Robi S9、Hutbit、MGB、Hoffen、Salter、Standard GATT。

openScale 的 63 个注册实例中，除上述重叠家族外还明确包含：HealthKeep 280、Picooc、AFU B1、Keep S3、Omron WLC、Beurer BF450、Taylor BIA、RyFit、Cult Smart Scale Pro、Realme Smart Scale、Mi Scale S400、Runstar R5/R6、Relaxmedic、Vitafit VT701、EEBBL、FitTrack Dara、Dr Trust SSW532、iHealth HS3、Huawei AH100/CH100S/Hagrid、Ebelter Body Fat B2、Hume Dara 2、Etekcity ESF551、BodyConnect、Weight Gurus A3、Custom openScale 等。全部注册实例现已进入观我的内置协议目录；已有解析器的条目标为“可执行”或“实验性”，尚缺完整解析器或会话状态机的条目标为“协议骨架”，Classic SPP 条目标为“平台不支持”。协议骨架不可选作测量协议，因此名称登记不会被误报成硬件兼容。

## 覆盖边界

调研样本中约有 65 个 openScale 设备处理器文件、63 个实际注册 handler，ble-scale-sync 当前代码则注册 33 个适配器实例；处理器数量不是可直接移植的协议数量：部分为同一协议的型号变体，另有大量实现依赖连接初始化、用户资料写入、时间同步、历史记录状态机或厂商安全绑定。

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

- [ble-scale-sync 支持清单（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/docs/guide/supported-scales.md)
- [ble-scale-sync 适配器注册表（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/index.ts)
- [Xiaomi XMTZC04HM 广播实现与格式（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/xiaomi-mi-scale-legacy.ts)
- [Xiaomi XMTZC04HM 抓包 fixture（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/tests/scales/xiaomi-mi-scale-legacy.test.ts)
- [Silvergear 108 广播实现与格式（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/silvergear-108.ts)
- [Silvergear 108 iOS 抓包 fixture（固定版本）](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/tests/scales/silvergear-108.test.ts)
- [openScale 处理器注册表（固定版本）](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/ScaleFactory.kt)
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
