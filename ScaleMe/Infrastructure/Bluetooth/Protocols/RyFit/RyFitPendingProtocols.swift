enum RyFitPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.ryfit",
            name: "RyFit",
            services: ["FFE0"],
            notify: ["FFE1"],
            write: ["FFE1"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("RyFitHandler.kt")]
        )
    ]
}
