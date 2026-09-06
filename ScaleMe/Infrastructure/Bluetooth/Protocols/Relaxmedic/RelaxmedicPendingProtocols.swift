enum RelaxmedicPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.relaxmedic",
            name: "Relaxmedic",
            services: ["FFB0"],
            notify: ["FFB2", "FFB3"],
            write: ["FFB1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("RelaxmedicHandler.kt")]
        )
    ]
}
