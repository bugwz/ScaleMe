import Foundation

struct PairedScaleRegistry {
    private(set) var ids: Set<UUID> = []
    private(set) var names: [UUID: String] = [:]
    private(set) var modelNames: [UUID: String] = [:]
    private(set) var compatibilities: [UUID: String] = [:]
    private(set) var automaticHistoryIDs: Set<UUID> = []

    private var ruleIDs: [UUID: String] = [:]
    private var rulesByID: [String: CommunicationRule] = Dictionary(
        uniqueKeysWithValues: CommunicationRuleCatalog.builtIn.map { ($0.id, $0) }
    )

    mutating func updateScales(_ scales: [PairedScale]) {
        ids = Set(scales.map(\.id))
        names = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.name) })
        modelNames = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.modelName) })
        compatibilities = Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0.compatibility) })
        ruleIDs = Dictionary(uniqueKeysWithValues: scales.compactMap { scale in
            scale.communicationRuleID.map { (scale.id, $0) }
        })
        automaticHistoryIDs = Set(
            scales.lazy.filter(\.automaticallyImportsHistory).map(\.id)
        )
    }

    mutating func updateRules(_ rules: [CommunicationRule]) {
        rulesByID = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
    }

    func contains(_ deviceID: UUID) -> Bool {
        ids.contains(deviceID)
    }

    func selectedRule(for deviceID: UUID) -> CommunicationRule? {
        ruleIDs[deviceID].flatMap { rulesByID[$0] }
    }

    func effectiveRule(for deviceID: UUID) -> CommunicationRule? {
        if ruleIDs[deviceID] != nil {
            return selectedRule(for: deviceID).flatMap { $0.canMeasure ? $0 : nil }
        }
        guard let compatibility = compatibilities[deviceID],
              let ruleID = CommunicationRuleCatalog.automaticRuleID(for: compatibility) else {
            return nil
        }
        return rulesByID[ruleID].flatMap { $0.canMeasure ? $0 : nil }
    }

    func hasExplicitRule(for deviceID: UUID) -> Bool {
        ruleIDs[deviceID] != nil
    }

    func rule(id: String) -> CommunicationRule? {
        rulesByID[id]
    }
}
