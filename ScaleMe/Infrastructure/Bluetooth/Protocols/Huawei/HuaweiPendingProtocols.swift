enum HuaweiPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.huawei-ah100",
            name: "Huawei AH100",
            services: ["FAA0"],
            notify: ["FAA2"],
            write: ["FAA1"],
            requirements: [.encryption, .multiFrameSession],
            sources: [.openScale("HuaweiAhCh100Handler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.huawei-ch100s",
            name: "Huawei CH100S",
            services: ["FAA0"],
            notify: ["FAA2"],
            write: ["FAA1"],
            requirements: [.encryption, .historyStateMachine, .multiFrameSession],
            sources: [.openScale("HuaweiCH100SHandler.kt")]
        )
    ]
}
