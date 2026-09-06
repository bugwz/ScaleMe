enum EEBBLPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.eebbl",
            name: "EEBBL",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("EEBBLHandler.kt")]
        )
    ]
}
