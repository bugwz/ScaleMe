enum OmronPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.omron-wlc",
            name: "Omron WLC/WLP",
            services: ["ECBE3980-C9A2-11E1-B1BD-0002A5D5C51B"],
            notify: ["DB5B55E0-AEE7-11E1-965E-0002A5D5C51B"],
            write: ["49123040-AEE8-11E1-A74D-0002A5D5C51B"],
            requirements: [.bonding, .historyStateMachine, .multiFrameSession],
            sources: [.openScale("OmronWlcHandler.kt")]
        )
    ]
}
