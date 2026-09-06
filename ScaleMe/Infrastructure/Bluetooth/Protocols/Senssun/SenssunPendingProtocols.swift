enum SenssunPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.senssun",
            name: "Senssun GATT",
            services: ["FFF0"],
            notify: ["FFF1"],
            write: ["FFF2"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("senssun.ts"), .openScale("SenssunHandler.kt")]
        )
    ]
}
