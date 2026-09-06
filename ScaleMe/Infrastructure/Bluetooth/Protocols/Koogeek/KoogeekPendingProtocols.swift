enum KoogeekPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.koogeek",
            name: "Koogeek S1",
            services: ["FFF0"],
            notify: ["FFF4"],
            write: ["FFF3"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("koogeek-s1.ts")]
        )
    ]
}
