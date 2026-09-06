enum WolaiPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.afu-b1",
            name: "AFU B1",
            services: ["FC50", "AF000000-9F2D-4C8A-8D6F-6A7B45F90000"],
            write: ["AF000002-9F2D-4C8A-8D6F-6A7B45F90000"],
            requirements: [.historyStateMachine, .multiFrameSession],
            sources: [.openScale("AfuB1Handler.kt")]
        )
    ]
}
