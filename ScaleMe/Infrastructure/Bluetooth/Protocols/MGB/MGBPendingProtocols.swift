enum MGBPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.mgb",
            name: "MGB Swan/Icomon/YG",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.bleScaleSync("mgb.ts"), .openScale("MGBHandler.kt")]
        )
    ]
}
