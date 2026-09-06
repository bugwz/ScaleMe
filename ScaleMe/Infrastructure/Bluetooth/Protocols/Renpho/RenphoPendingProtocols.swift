enum RenphoPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.renpho",
            name: "Renpho ES-WBE28",
            services: ["181B", "181D", "181C", "FFE0", "FFF0"],
            notify: ["2A9D", "2A9C", "FFE1"],
            write: ["2A9F", "FFE2"],
            requirements: [.userProfile, .consentCode, .multiFrameSession],
            sources: [.bleScaleSync("renpho.ts"), .openScale("RenphoHandler.kt")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.renpho-msc04",
            name: "Renpho R-MSC04",
            services: ["1A10"],
            notify: ["2A10", "2A12"],
            write: ["2A11"],
            supportedModels: ["MorphoScan Nova"],
            requirements: [.historyStateMachine, .multiFrameSession],
            sources: [.bleScaleSync("renpho-msc04.ts")]
        ),
        .pendingBuiltIn(
            id: "protocol.builtin.renpho-es26bb",
            name: "Renpho ES-26BB",
            services: ["1A10"],
            notify: ["2A10"],
            write: ["2A11"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("renpho-es26bb.ts"), .openScale("RenphoES26BBHandler.kt")]
        )
    ]
}
