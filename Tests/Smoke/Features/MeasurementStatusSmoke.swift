@main
enum MeasurementStatusSmoke {
    static func main() {
        var presentation = MeasurementStatusPresentation()
        presentation.receive(.scanning)
        presentation.receive(.connecting("MI SCALE2"))
        presentation.receive(.connecting("Other scale"))
        presentation.receive(.scanning)
        precondition(presentation.state == .connecting("MI SCALE2"))

        presentation.receive(.connected("MI SCALE2"))
        presentation.receive(.connecting("Other scale"))
        presentation.receive(.connected("Other scale"))
        precondition(presentation.state == .connected("MI SCALE2"))

        presentation.receive(.measuringWeight)
        presentation.receive(.connected("Other scale"))
        precondition(presentation.state == .measuringWeight)
        presentation.receive(.measuringBodyComposition)
        presentation.receive(.measuringWeight)
        precondition(presentation.state == .measuringBodyComposition)
        presentation.receive(.confirmingMeasurement)
        presentation.receive(.measuringBodyComposition)
        precondition(presentation.state == .confirmingMeasurement)

        presentation.receive(.completed)
        presentation.receive(.connected("Other scale"))
        presentation.receive(.scanning)
        presentation.receive(.unavailable("Disconnected"))
        precondition(presentation.state == .completed)
        presentation.receive(.measuringWeight)
        presentation.receive(.confirmingMeasurement)
        precondition(presentation.state == .completed, "Another scale must not demote the completed status")

        presentation.reset()
        presentation.receive(.unavailable("Bluetooth off"))
        precondition(presentation.state == .unavailable("Bluetooth off"))
        presentation.receive(.scanning)
        precondition(presentation.state == .scanning)
        presentation.receive(.completed)
        presentation.reset()
        presentation.receive(.connecting("Other scale"))
        precondition(presentation.state == .connecting("Other scale"))
        print("Measurement status presentation smoke tests passed")
    }
}
