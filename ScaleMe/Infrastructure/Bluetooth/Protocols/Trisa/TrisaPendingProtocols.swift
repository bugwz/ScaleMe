enum TrisaPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.trisa",
            name: "Trisa/ADE BA1600",
            services: ["78B2"],
            notify: ["8A21", "8A24", "8A22", "8A82"],
            write: ["8A81"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.bleScaleSync("trisa.ts"), .openScale("TrisaBodyAnalyzeHandler.kt")]
        )
    ]
}
