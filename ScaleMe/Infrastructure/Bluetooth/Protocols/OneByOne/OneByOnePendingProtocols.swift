enum OneByOnePendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.onebyone",
            name: "1byone / Eufy C1/P1/A1",
            services: ["FFF0"],
            notify: ["FFF4"],
            write: ["FFF1"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.bleScaleSync("one-byone.ts"), .openScale("OneByoneHandler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.onebyone-new",
            name: "1byone Scale New",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.multiFrameSession],
            sources: [.bleScaleSync("one-by-one.ts"), .openScale("OneByoneNewHandler.kt")]
        )
    ]
}
