# 外部通信规则格式

> 返回 [文档导航](README.md) · 查看 [架构与实现](Architecture.md)

外部通信规则是本地导入的受限 JSON 数据，不是插件或可执行代码。复杂认证、加密、动态握手以及厂商状态机必须作为内置 Swift 协议适配器实现。

## 文档结构

当前格式版本为 `3`：

```json
{
  "schemaVersion": 3,
  "rules": [
    {
      "id": "protocol.custom.example-scale",
      "name": "Example Scale",
      "version": 1,
      "summary": "Example 6-byte notification frame.",
      "match": {
        "transport": "characteristicNotification",
        "serviceUUID": "FFF0",
        "characteristicUUID": "FFF1",
        "minimumLength": 6,
        "maximumLength": 6,
        "prefixHex": "A55A"
      },
      "decoder": {
        "weight": {
          "offset": 2,
          "length": 2,
          "byteOrder": "bigEndian",
          "scale": 0.01,
          "add": 0
        },
        "weightUnit": "kilograms",
        "impedance": {
          "offset": 4,
          "length": 2,
          "byteOrder": "littleEndian",
          "scale": 1,
          "add": 0
        },
        "stableWhen": {
          "offset": 0,
          "mask": 128,
          "equals": 128
        }
      }
    }
  ]
}
```

每个文件必须包含 `1...64` 条规则且不超过 512 KB。完整 ID 必须唯一，并使用 `protocol.custom.<slug>`；slug 长度为 `1...64`，首字符为 ASCII 字母或数字，其余字符只能使用字母、数字、`.`、`_` 或 `-`。

## 规则字段

| 字段 | 必需 | 含义 |
| --- | --- | --- |
| `id`、`name`、`version`、`summary` | 是 | 稳定 ID、显示名称、正整数版本和说明 |
| `author`、`sourceLinks` | 否 | 作者与原始资料链接，只作为来源元数据 |
| `match` | 是 | 主传输、服务/特征 UUID、长度及可选前缀 |
| `decoder` | 条件必需 | 声明式实时测量字段；与 `operations` 至少提供一个 |
| `operations` | 条件必需 | 受限历史读取或清除操作 |
| `supportedModels`、`requirements` | 否 | 型号和运行条件说明，不会自动获得对应运行能力 |
| `alternateMatches` | 否 | 同一线上协议的备用匹配条件，最多 16 个 |
| `notifyTargets`、`writeTargets` | 否 | 连接协议需要发现的 GATT 目标 |

外部规则当前允许 `advertisementServiceData` 与 `characteristicNotification`。`advertisementManufacturerData` 仍由内置适配器处理，因为 Company Identifier、设备身份与厂商载荷边界需要代码级校验。Classic SPP 不受 CoreBluetooth 支持。

`origin`、`verification`、`implementation`、`sourceURL` 和 `builtInParser` 不是外部格式字段。导入规则始终被标记为本地、未经验证，也不能调用应用内部解析器。

## Decoder

字段读取使用 `offset`、`length`、`byteOrder`、`scale` 和可选 `add`：

```text
decodedValue = unsignedInteger(rawBytes, byteOrder) × scale + add
```

- `length` 必须为 `1...8`，且字段不能越过匹配数据包的最小长度。
- `scale` 必须为正有限数，`add` 必须为有限数。
- `weight` 必需；`impedance`、设备直接提供的身体成分和日期字段可选。
- `weightUnit` 可为 `kilograms`、`pounds` 或 `jin`，运行时统一转换为 kg。
- `stableWhen` 与 `removedWhen` 使用 `offset`、非零 `mask` 和受 mask 约束的 `equals`。
- 解码后仍会检查重量、阻抗、日期和身体成分的合理范围。

## Operations

`operations` 目前可包含：

- `historyRead`：订阅目标、起始命令、历史响应、完成命令和导入确认命令。
- `historyClear`：必须同时声明 `capability: "historyClear"` 与 `destructive: true`，且必须经过独立用户确认。

命令由目标、十六进制载荷模板及 `withResponse`、`withoutResponse` 或自动选择可用属性的 `automatic` 写入方式组成。模板只允许静态十六进制和受限占位符：

- `{{sessionToken16BE}}`
- `{{currentTimeBLE}}`
- `{{response:<offset>:<length>}}`，最多引用 8 字节有界响应

内置协议专用占位符不属于外部格式。每个操作必须限制在 1 至 60 秒、最多 1 MiB 响应和最多 2000 条记录；运行时还会验证服务、特征以及 notify/write 属性。

## 能力规则

能力不由外部文件直接声明，而由可执行内容推导：

- 存在 `decoder`：实时测量。
- decoder 存在 `removedWhen`：离秤事件。
- 存在合法 `historyRead`：历史读取。
- 存在合法 `historyClear`：历史清除。

需要认证、绑定密钥、加密或任意状态机的协议必须进入对应 `Protocols/<协议族>/` 目录，实现内置连接会话与实际支持的能力接口。
