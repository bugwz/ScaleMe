enum RunstarPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.runstar-r6",
            name: "Runstar R6",
            services: ["FFB0"],
            notify: ["FFB2", "FFB3"],
            write: ["FFB1"],
            requirements: [.historyStateMachine, .multiFrameSession],
            sources: [.openScale("RunstarR6Handler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.runstar-r5",
            name: "Runstar R5",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("RunstarR5Handler.kt")]
        )
    ]
}
