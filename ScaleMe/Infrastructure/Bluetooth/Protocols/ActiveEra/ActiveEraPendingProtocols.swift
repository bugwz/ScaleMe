enum ActiveEraPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.active-era",
            name: "Active Era BS-06/BF06",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.multiFrameSession],
            sources: [.bleScaleSync("active-era.ts"), .openScale("ActiveEraBF06Handler.kt")]
        )
    ]
}
