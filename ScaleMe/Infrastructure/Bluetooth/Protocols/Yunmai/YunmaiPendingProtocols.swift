enum YunmaiPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.yunmai",
            name: "Yunmai Signal/Mini/SE",
            services: ["FFE0"],
            notify: ["FFE4"],
            write: ["FFE9"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("yunmai.ts"), .openScale("YunmaiHandler.kt")]
        )
    ]
}
