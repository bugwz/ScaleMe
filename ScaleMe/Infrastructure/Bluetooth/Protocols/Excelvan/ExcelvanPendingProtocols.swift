enum ExcelvanPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.excelvan",
            name: "Excelvan CF36x",
            services: ["FFF0"],
            notify: ["FFF4"],
            write: ["FFF1"],
            requirements: [.userProfile, .multiFrameSession],
            sources: [.bleScaleSync("excelvan-cf369.ts"), .openScale("ExcelvanCF36xHandler.kt")]
        )
    ]
}
