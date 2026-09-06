enum ESCS20MPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.es-cs20m",
            name: "ES-CS20M / ES-32MD",
            services: ["1A10"],
            notify: ["2A10"],
            write: ["2A11"],
            requirements: [.multiFrameSession],
            sources: [.bleScaleSync("es-cs20m.ts"), .openScale("ESCS20MHandler.kt")]
        )
    ]
}
