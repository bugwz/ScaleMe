enum ExingtechPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.exingtech-y1",
            name: "Exingtech Y1",
            services: ["F433BD80-75B8-11E2-97D9-0002A5D5C51B"],
            notify: ["1A2EA400-75B9-11E2-BE05-0002A5D5C51B"],
            write: ["29F11080-75B9-11E2-8BF6-0002A5D5C51B"],
            supportedModels: ["vscale"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("exingtech-y1.ts"), .openScale("ExingtechY1Handler.kt")]
        )
    ]
}
