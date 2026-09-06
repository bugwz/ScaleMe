enum SoehnlePendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.soehnle",
            name: "Soehnle Shape/Style",
            services: ["352E0000-28E9-40B8-A361-6DB4CCA4147C"],
            notify: ["352E3001-28E9-40B8-A361-6DB4CCA4147C"],
            write: ["352E3002-28E9-40B8-A361-6DB4CCA4147C"],
            supportedModels: ["Shape200", "Shape100", "Shape50", "Style100"],
            requirements: [.vendorRegistration, .multiFrameSession],
            sources: [.bleScaleSync("soehnle.ts"), .openScale("SoehnleHandler.kt")]
        )
    ]
}
