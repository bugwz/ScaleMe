enum VitafitPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.vitafit",
            name: "Vitafit VT701",
            services: ["FFF0"],
            notify: ["FFF1"],
            write: ["FFF2"],
            requirements: [.multiFrameSession],
            sources: [.openScale("VitafitVT701Handler.kt")]
        )
    ]
}
