# ble-scale-sync

- 上游：https://github.com/KristianP26/ble-scale-sync
- 引用版本：`e5060b4e43e2d08ecace7e327145c777872ea93f`。
- 许可证：`GPL-3.0-or-later`。该版本 package.json 简写为 GPL-3.0；[原始 LICENSE](LICENSE)中针对 ble-scale-sync 的署名声明明确允许 GPL v3 或后续版本。副本保留完整上游文本。
- 本地用途：Xiaomi XMTZC04HM 和 Silvergear 108 广播协议资料、解析逻辑及原测试样本来源。

## 保留的版权声明

```text
Copyright (C) 2026 Kristián Partl
```

## 文件映射

| 上游文件（固定版本） | 本地文件 |
| --- | --- |
| [silvergear-108.ts](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/silvergear-108.ts) | [Silvergear/Silvergear108ScaleParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/Silvergear/Silvergear108ScaleParser.swift) |
| [xiaomi-mi-scale-legacy.ts](https://github.com/KristianP26/ble-scale-sync/blob/e5060b4e43e2d08ecace7e327145c777872ea93f/src/scales/xiaomi-mi-scale-legacy.ts) | [Xiaomi/XiaomiMiScale2BroadcastParser.swift](../../ScaleMe/Infrastructure/Bluetooth/Protocols/Xiaomi/XiaomiMiScale2BroadcastParser.swift) |

相关资料和 fixture 来源链接保留在 [协议文档](../../Docs/BluetoothProtocolSupport.md)。本地 [ParserSmoke.swift](../../Tests/Smoke/Bluetooth/ParserSmoke.swift) 中这两个协议的样本现为合成数据；不要将其描述为上游未经修改的实测载荷。

## ScaleMe 的修改

Swift 改编与本项目新增部分：Copyright (C) 2026 bugwz。

- 将 TypeScript/Node 广播适配逻辑整理为 Swift 纯解析器，返回本项目 BodyMeasurement。
- 调整匹配、错误处理、范围验证及实时/稳定状态的表达，并接入本项目协议注册与历史会话。
- 不引入上游身体成分计算、导出器或 Node 运行时。
- 将 fixture 的设备地址、体重和日期替换为合成数据，并重新计算相应校验值。
- 2026-10-10 补充本许可声明、文件映射及源文件归属头。更早的功能修改记录保留在 Git 历史中。

其他待实现协议中的 ble-scale-sync 链接仅作为研究来源；实际引入实现时需补充具体文件的许可和归属记录。
