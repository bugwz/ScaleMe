enum CultPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.cult-smart",
            name: "Cult Smart Scale Pro",
            services: ["FFF0"],
            notify: ["FFF4"],
            write: ["FFF1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("CultSmartScaleProHandler.kt")]
        )
    ]
}
