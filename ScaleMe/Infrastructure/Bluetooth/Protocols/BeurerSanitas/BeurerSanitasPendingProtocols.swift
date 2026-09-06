enum BeurerSanitasPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.beurer-bf720",
            name: "Beurer SIG scales",
            services: ["181B", "181D", "181C"],
            notify: ["2A9C", "2A9D", "FFF2"],
            write: ["2A9F", "FFF3"],
            supportedModels: ["BF720", "BF105", "BF500", "BF788", "BF950"],
            requirements: [.bonding, .consentCode, .userProfile, .multiFrameSession],
            sources: [.bleScaleSync("beurer-bf720.ts")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.beurer-sanitas",
            name: "Beurer/Sanitas FFE0",
            services: ["FFE0"],
            notify: ["FFE1"],
            write: ["FFE1"],
            requirements: [.vendorRegistration, .userProfile, .multiFrameSession],
            sources: [.bleScaleSync("beurer-sanitas.ts"), .openScale("BeurerSanitasHandler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.sanitas-sbf72",
            name: "Sanitas SBF72/73",
            services: ["181B", "181C"],
            notify: ["2A9C"],
            write: ["2A9F"],
            requirements: [.vendorRegistration, .userProfile],
            sources: [.bleScaleSync("sanitas-sbf72.ts"), .openScale("SanitasSbf72Handler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.beurer-bf450",
            name: "Beurer BF450",
            services: ["FFFF"],
            notify: ["FFF0", "FFF5", "2A9C", "2A9D"],
            write: ["FFF1", "FFF2", "FFF4", "FFF7"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.openScale("BeurerBF450Handler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.beurer-sig",
            name: "Beurer/Sanitas SIG",
            services: ["181B", "181D", "181C"],
            notify: ["2A9C", "2A9D"],
            write: ["2A9F"],
            requirements: [.bonding, .consentCode, .userProfile],
            sources: [.openScale("StandardBeurerSanitasHandler.kt")]
        )
    ]
}
