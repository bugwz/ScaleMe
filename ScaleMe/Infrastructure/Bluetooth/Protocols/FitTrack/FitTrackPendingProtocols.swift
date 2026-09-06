enum FitTrackPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.fittrack",
            name: "FitTrack Dara",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("FitTrackDaraHandler.kt")]
        )
    ]
}
