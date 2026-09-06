enum EbelterPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.ebelter",
            name: "Ebelter Body Fat B2",
            services: ["FAA0"],
            notify: ["FAA2"],
            write: ["FAA1"],
            requirements: [.multiFrameSession],
            sources: [.openScale("EbelterBodyFatB2Handler.kt")]
        )
    ]
}
