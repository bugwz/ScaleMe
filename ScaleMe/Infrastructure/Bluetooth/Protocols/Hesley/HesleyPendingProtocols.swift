enum HesleyPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.hesley",
            name: "Hesley / YunChen",
            services: ["FFF0"],
            notify: ["FFF4"],
            write: ["FFF1"],
            requirements: [.multiFrameSession],
            sources: [.bleScaleSync("hesley.ts"), .openScale("HesleyHandler.kt")]
        )
    ]
}
