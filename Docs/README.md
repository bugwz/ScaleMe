# ScaleMe 文档

README 负责介绍“观我”是什么、解决什么问题以及项目坚持的原则；本目录记录实现、验证和维护项目所需的技术细节。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [架构与实现](Architecture.md) | 代码分层、状态与数据流、蓝牙管线、趋势分析、本地化和设计系统 |
| [体重秤协议支持矩阵](BluetoothProtocolSupport.md) | 已实现协议、验证层级、覆盖边界、上游研究与引用 |
| [外部通信规则格式](ExternalCommunicationRules.md) | schema 3 字段、声明式解码、受限操作和安全边界 |
| [数据、同步与隐私](DataAndPrivacy.md) | 本地存储、系统数据保护、备份、导入导出、HealthKit 和诊断数据 |
| [开发与验证](Development.md) | 开发环境、模拟数据、编译与烟雾测试、真机验证清单 |
| [Agent 开发约定](../AGENTS.md) | 目录职责、实现规则、视觉语言和协作约束 |

## 文档维护约定

- README 中只保留稳定的项目定位、核心能力与入口，不堆叠协议帧、命令载荷或测试脚本。
- 用户可见能力变化时，同步检查 README；架构边界变化时更新 `Architecture.md`。
- 新增或调整设备协议时更新 `BluetoothProtocolSupport.md`，并明确区分代码实现、fixture 验证和真实硬件验证。
- 存储格式、同步策略或健康数据范围变化时更新 `DataAndPrivacy.md`。
- 环境要求、构建方式或验证命令变化时更新 `Development.md`。
