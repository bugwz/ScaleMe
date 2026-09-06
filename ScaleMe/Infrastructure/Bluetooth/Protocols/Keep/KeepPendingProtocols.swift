enum KeepPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.keep-s3",
            name: "Keep S3",
            services: ["待捕获"],
            requirements: [.userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("KeepS3Handler.kt")]
        )
    ]
}
