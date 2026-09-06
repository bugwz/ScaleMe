enum InlifePendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.inlife",
            name: "Inlife FatScale",
            services: ["FFF0"],
            notify: ["FFF1"],
            write: ["FFF2"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("inlife.ts"), .openScale("InlifeHandler.kt")]
        )
    ]
}
