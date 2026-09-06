enum EtekcityPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.etekcity-551",
            name: "Etekcity ESF551",
            services: ["FFF0"],
            notify: ["FFF1"],
            write: ["FFF2"],
            requirements: [.multiFrameSession],
            sources: [.openScale("EtekcityESF551Handler.kt")]
        )
    ]
}
