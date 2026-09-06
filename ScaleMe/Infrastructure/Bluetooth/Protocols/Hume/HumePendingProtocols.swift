enum HumePendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.hume-dara2",
            name: "Hume Dara 2",
            services: ["FFF0"],
            notify: ["FFF4"],
            write: ["FFF1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("HumeDara2Handler.kt")]
        )
    ]
}
