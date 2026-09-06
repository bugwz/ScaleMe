enum DrTrustPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.drtrust",
            name: "Dr Trust SSW532",
            services: ["FFB0"],
            notify: ["FFB2", "FFB3"],
            write: ["FFB1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("DrTrustSSW532Handler.kt")]
        )
    ]
}
