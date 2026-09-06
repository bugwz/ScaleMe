enum XiaomiPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.xiaomi-s800",
            name: "Xiaomi S800",
            transport: .advertisementServiceData,
            services: ["FE95"],
            supportedModels: ["ms116"],
            requirements: [.bindKey, .encryption],
            summary: "已登记 FE95 加密 MiBeacon；需要逐设备 bind key，8 电极 GATT 数据尚未解码。",
            sources: [.bleScaleSync("xiaomi-s800.ts"), .openScale("XiaomiS800Handler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.mi-s400",
            name: "Xiaomi S400",
            transport: .advertisementServiceData,
            services: ["FE95"],
            requirements: [.bindKey, .encryption],
            sources: [.openScale("MiScaleS400Handler.kt")]
        )
    ]
}
