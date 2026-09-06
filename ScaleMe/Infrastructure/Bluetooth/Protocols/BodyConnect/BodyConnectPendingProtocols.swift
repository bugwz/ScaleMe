enum BodyConnectPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.bodyconnect",
            name: "BodyConnect",
            services: ["7892"],
            notify: ["8A24", "8A22", "8A82"],
            write: ["8A81"],
            requirements: [.consentCode, .userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("BodyConnectHandler.kt")]
        )
    ]
}
