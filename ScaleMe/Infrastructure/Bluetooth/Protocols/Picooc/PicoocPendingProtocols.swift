enum PicoocPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.picooc",
            name: "Picooc",
            services: ["FFF0"],
            notify: ["FFF1"],
            write: ["FFF2"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("PicoocHandler.kt")]
        )
    ]
}
