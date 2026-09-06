enum EufyPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.eufy-p2",
            name: "Eufy P2/P2 Pro",
            services: ["FFF0"],
            notify: ["FFF2", "FFF4"],
            write: ["FFF1", "FFF4"],
            supportedModels: ["T9148", "T9149"],
            requirements: [.encryption, .multiFrameSession],
            sources: [.bleScaleSync("eufy-p2.ts"), .openScale("EufyP2Handler.kt")]
        )
    ]
}
