enum DigooPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.digoo",
            name: "Digoo / Mengii",
            services: ["FFF0"],
            notify: ["FFF1"],
            write: ["FFF2"],
            supportedModels: ["DG-SO38H"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("digoo.ts"), .openScale("DigooDGSO38HHandler.kt")]
        )
    ]
}
