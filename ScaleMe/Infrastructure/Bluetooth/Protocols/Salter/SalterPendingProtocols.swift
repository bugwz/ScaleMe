enum SalterPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.salter",
            name: "Salter SA00656/SA00432",
            services: ["FFCC"],
            notify: ["FFC1"],
            write: ["FFC1"],
            requirements: [.timeSynchronization, .historyStateMachine, .multiFrameSession],
            sources: [.bleScaleSync("salter.ts")]
        )
    ]
}
