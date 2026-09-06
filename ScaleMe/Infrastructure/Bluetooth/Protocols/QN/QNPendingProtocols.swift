enum QNPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.qn",
            name: "QN GATT",
            services: ["FFF0", "FFE0", "AE00", "181B", "181D"],
            notify: ["FFF1", "FFE1", "AE01", "2A9D"],
            write: ["FFF2", "FFE3", "AE02", "2A9F"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.bleScaleSync("qn-scale.ts"), .openScale("QNHandler.kt")]
        )
    ]
}
