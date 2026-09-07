/// Presentation only: never selects a scale or changes the Bluetooth session.
struct MeasurementStatusPresentation {
    private(set) var state: BluetoothScaleState = .idle

    mutating func reset() {
        state = .idle
    }

    mutating func receive(_ incoming: BluetoothScaleState) {
        if case .unavailable = incoming {
            if state != .completed { state = incoming }
            return
        }
        if case .unavailable = state {
            state = incoming
            return
        }
        // Equal stages retain their existing device name; background connection
        // events cannot demote a measuring or completed status.
        if priority(incoming) > priority(state) {
            state = incoming
        }
    }

    private func priority(_ state: BluetoothScaleState) -> Int {
        switch state {
        case .idle: 0
        case .scanning: 1
        case .connecting: 2
        case .connected: 3
        case .measuringWeight: 4
        case .measuringBodyComposition: 5
        case .confirmingMeasurement: 6
        case .completed: 7
        case .unavailable: 0
        }
    }
}
