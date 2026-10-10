# openScale

- 上游：https://github.com/oliexdev/openScale
- 来源快照：`6613db5838e4674a19652441073f82b3ee3d7009`。Huawei 原有引用固定于此版本；其余原先指向 master 的广播处理器在本次核对时也使用该快照作对照，不将它冒充为已证明的最初引入版本。
- 许可证：`GPL-3.0-or-later`；见 [原始 LICENSE](LICENSE)及相应源文件头。EufyC20Handler.kt 没有单独文件头，按该版本仓库 README 的 GPL v3 或后续版本声明记录。
- 本地用途：协议资料、广播解析及 Huawei 认证/会话的参考与 Swift 改编。源码实现与平台适配已有差异，不是原封不动复制整个 Android 模块。

## 保留的版权声明

```text
Copyright (C) 2025 olie.xdev <olie.xdeveloper@googlemail.com>
Copyright (C) 2026 openScale contributors
```

第一项见仓库 README 及 AAAx、QNHandlerBroadcast、Sinocare、Scaleup、OkOk 文件头；第二项见 EtekcityFit8S、YunmaiX、HuaweiHagridWspLib、HuaweiHagridWspHandler 文件头。EufyC20 不另行推定个人作者及年份。以上版权属于上游，不是 ScaleMe 作者的个人联系方式。

## 文件映射

| 上游文件（固定版本） | 本地文件 |
| --- | --- |
| [AAAxHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/AAAxHandler.kt) | [AAASeries/AAASeriesScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/AAASeries/AAASeriesScaleParser.swift) |
| [QNHandlerBroadcast.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/QNHandlerBroadcast.kt) | [QNAABB/QNAABBScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/QNAABB/QNAABBScaleParser.swift) |
| [SinocareHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/SinocareHandler.kt) | [Sinocare/SinocareScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/Sinocare/SinocareScaleParser.swift) |
| [ScaleupHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/ScaleupHandler.kt) | [Scaleup/ScaleupScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/Scaleup/ScaleupScaleParser.swift) |
| [OkOkHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/OkOkHandler.kt) | [OKOK/OKOKScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/OKOK/OKOKScaleParser.swift) |
| [EtekcityFit8SHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/EtekcityFit8SHandler.kt) | [EtekcityFit8S/EtekcityFit8SScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/EtekcityFit8S/EtekcityFit8SScaleParser.swift) |
| [EufyC20Handler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/EufyC20Handler.kt) | [EufyC20/EufyC20ScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/EufyC20/EufyC20ScaleParser.swift) |
| [YunmaiXHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/YunmaiXHandler.kt) | [YunmaiX/YunmaiXScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/YunmaiX/YunmaiXScaleParser.swift) |
| [HuaweiHagridWspLib.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/libs/HuaweiHagridWspLib.kt) | [Huawei/HuaweiHagridProtocol.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/Huawei/HuaweiHagridProtocol.swift) |
| [HuaweiHagridWspHandler.kt](https://github.com/oliexdev/openScale/blob/6613db5838e4674a19652441073f82b3ee3d7009/android_app/app/src/main/java/com/health/openscale/core/bluetooth/scales/HuaweiHagridWspHandler.kt) | [Huawei/HuaweiHagridProtocolSession.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/Huawei/HuaweiHagridProtocolSession.swift) |

## ScaleMe 的修改

Swift 改编与本项目新增部分：Copyright (C) 2026 bugwz。

- 改用 Swift、Foundation、CryptoKit/CommonCrypto 与 ScaleMe 的领域模型及错误处理。
- 广播解码与 CoreBluetooth 协调分离，增加本地长度、取值范围和匹配条件检查。
- Huawei 使用独立的凭据、分帧、认证、测量解析与连接会话接口；设备秘密由本项目 Keychain 实现管理。
- 测试中的设备地址、认证向量与个人测量样本已改为合成数据；不将它们标记为上游原始抓包。
- 2026-10-10 补充本许可声明、文件映射及源文件归属头。更早的功能修改记录保留在 Git 历史中。

其他 `*PendingProtocols.swift` 中的 openScale 链接用于待实现设备的研究与能力目录，不表示已移植对应处理器。后续实际移植时，应增加相应文件和版权映射。此清单不授权绕过或替代上游许可。
