enum IHealthPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.ihealth-hs3",
            name: "iHealth HS3",
            transport: .classicSPP,
            services: ["RFCOMM"],
            requirements: [.classicBluetooth],
            implementation: .unsupportedPlatform,
            summary: "协议为 Classic Bluetooth SPP；CoreBluetooth 不提供 RFCOMM 访问，当前 iOS 架构不可执行。",
            sources: [.openScale("IHealthHS3Handler.kt")]
        )
    ]
}
