enum HealthKeepPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.healthkeep280",
            name: "HealthKeep 280",
            services: ["FFB0"],
            notify: ["FFB2", "FFB3"],
            write: ["FFB1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("HealthKeep280Handler.kt")]
        )
    ]
}
