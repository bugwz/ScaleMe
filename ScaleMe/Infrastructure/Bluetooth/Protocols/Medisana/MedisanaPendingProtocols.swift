enum MedisanaPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.medisana",
            name: "Medisana BS44x",
            services: ["78B2"],
            notify: ["8A21"],
            write: ["8A81"],
            supportedModels: ["BS430", "BS440", "BS444"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.bleScaleSync("medisana-bs44x.ts"), .openScale("MedisanaBs44xHandler.kt")]
        )
    ]
}
