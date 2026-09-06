enum HoffenPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.hoffen",
            name: "Hoffen BS-8107",
            services: ["FFB0"],
            notify: ["FFB2"],
            write: ["FFB2"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("hoffen.ts"), .openScale("HoffenBbs8107Handler.kt")]
        )
    ]
}
