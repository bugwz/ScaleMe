enum TaylorPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.taylor-bia",
            name: "Taylor BIA",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.multiFrameSession],
            sources: [.openScale("TaylorBIAHandler.kt")]
        )
    ]
}
