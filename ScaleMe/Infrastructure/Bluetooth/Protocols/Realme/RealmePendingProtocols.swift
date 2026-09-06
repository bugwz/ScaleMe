enum RealmePendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.realme",
            name: "Realme Smart Scale",
            services: ["A602"],
            notify: ["A621", "A625"],
            write: ["A622", "A624"],
            requirements: [.encryption, .keepAlive, .userProfile, .historyStateMachine, .multiFrameSession],
            sources: [.openScale("RealmeSmartScaleHandler.kt")]
        )
    ]
}
