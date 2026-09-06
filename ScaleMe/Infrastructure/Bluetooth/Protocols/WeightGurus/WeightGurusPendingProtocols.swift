enum WeightGurusPendingProtocols {
    static let communicationRules: [CommunicationRule] = [
        .pendingBuiltIn(
            id: "protocol.builtin.weightgurus-a3",
            name: "Weight Gurus A3",
            services: ["0D005750-C36B-11E3-9C1A-0800200C9A66"],
            notify: ["8A24", "8A22", "8A82"],
            write: ["8A81"],
            requirements: [.consentCode, .userProfile, .timeSynchronization, .multiFrameSession],
            sources: [.openScale("WeightGurusA3Handler.kt")]
        )
    ]
}
