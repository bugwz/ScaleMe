enum RobiPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.robi-s9",
            name: "Robi S9",
            services: ["FFB0"],
            notify: ["FFB2", "FFB3"],
            write: ["FFB1"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.bleScaleSync("robi-s9.ts"), .openScale("RobiS9Handler.kt")]
        )
    ]
}
