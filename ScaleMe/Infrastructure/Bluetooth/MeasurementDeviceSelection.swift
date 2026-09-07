import Foundation

struct MeasurementDeviceSelection {
    private(set) var orderedDeviceIDs: [UUID] = []
    private(set) var manuallySelectedDeviceID: UUID?
    private(set) var candidateDeviceID: UUID?
    private(set) var isLocked = false
    private(set) var discoveredDeviceIDs: Set<UUID> = []

    var isAutomatic: Bool { manuallySelectedDeviceID == nil }

    mutating func reset(orderedDeviceIDs: [UUID], manuallySelectedDeviceID: UUID?) {
        self.orderedDeviceIDs = orderedDeviceIDs
        self.manuallySelectedDeviceID = manuallySelectedDeviceID.flatMap { selectedID in
            orderedDeviceIDs.contains(selectedID) ? selectedID : nil
        }
        candidateDeviceID = self.manuallySelectedDeviceID
        isLocked = self.manuallySelectedDeviceID != nil
        discoveredDeviceIDs.removeAll()
    }

    mutating func updateOrderedDeviceIDs(_ orderedDeviceIDs: [UUID]) {
        self.orderedDeviceIDs = orderedDeviceIDs

        if let manuallySelectedDeviceID {
            candidateDeviceID = orderedDeviceIDs.contains(manuallySelectedDeviceID)
                ? manuallySelectedDeviceID
                : nil
            isLocked = candidateDeviceID != nil
            return
        }

        discoveredDeviceIDs.formIntersection(orderedDeviceIDs)
        if let candidateDeviceID, !orderedDeviceIDs.contains(candidateDeviceID) {
            self.candidateDeviceID = nil
            isLocked = false
        }
    }

    @discardableResult
    mutating func observe(_ deviceID: UUID) -> Bool {
        guard isAutomatic, orderedDeviceIDs.contains(deviceID), !isLocked else { return false }
        return discoveredDeviceIDs.insert(deviceID).inserted
    }

    mutating func selectHighestPriorityDiscoveredDevice() -> UUID? {
        guard isAutomatic, !isLocked else { return candidateDeviceID }
        candidateDeviceID = orderedDeviceIDs.first(where: discoveredDeviceIDs.contains)
        return candidateDeviceID
    }

    func accepts(_ deviceID: UUID) -> Bool {
        candidateDeviceID == deviceID
    }

    mutating func lock(_ deviceID: UUID) -> Bool {
        guard accepts(deviceID) else { return false }
        isLocked = true
        return true
    }

    mutating func advanceAfterFailure(of deviceID: UUID) -> UUID? {
        guard isAutomatic, !isLocked, candidateDeviceID == deviceID else {
            return candidateDeviceID
        }
        discoveredDeviceIDs.remove(deviceID)
        candidateDeviceID = orderedDeviceIDs.first(where: discoveredDeviceIDs.contains)
        return candidateDeviceID
    }
}
