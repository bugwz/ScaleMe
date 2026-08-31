import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

struct InputDiagnosticEvent: Codable, Identifiable, Sendable {
    enum Name: String, Codable, Sendable {
        case diagnosticsEnabled
        case diagnosticsDisabled
        case sessionStarted
        case manualEntryButtonTapped
        case manualEntryPresented
        case inputTouched
        case inputWillBeginEditing
        case inputDidBeginEditing
        case keyboardWillShow
        case keyboardDidShow
        case firstTextChange
        case keyboardWillHide
        case keyboardDidHide
    }

    let id: UUID
    let sequence: Int
    let name: Name
    let recordedAt: Date
    let sessionElapsedMilliseconds: Double
    let attemptID: UUID?
    let attemptElapsedMilliseconds: Double?
    let fieldID: String?
    let inputLanguage: String?
    let keyboardAnimationDurationMilliseconds: Double?
    let keyboardHeightPoints: Double?
    let keyboardIsLocal: Bool?
}

struct InputDiagnosticAttemptSummary: Codable, Identifiable, Sendable {
    let id: UUID
    let fieldID: String
    let touchToWillBeginEditingMilliseconds: Double?
    let touchToDidBeginEditingMilliseconds: Double?
    let touchToKeyboardWillShowMilliseconds: Double?
    let touchToKeyboardDidShowMilliseconds: Double?
    let keyboardPresentationMilliseconds: Double?
    let touchToFirstTextChangeMilliseconds: Double?
}

struct InputDiagnosticReport: Codable, Sendable {
    let schemaVersion: Int
    let product: String
    let generatedAt: Date
    let appVersion: String
    let appBuild: String
    let systemName: String
    let systemVersion: String
    let deviceModel: String
    let localeIdentifier: String
    let sessionID: UUID
    let sessionStartedAt: Date
    let events: [InputDiagnosticEvent]
    let attempts: [InputDiagnosticAttemptSummary]

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

struct InputDiagnosticsExport: Transferable, Sendable {
    let report: InputDiagnosticReport

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            try export.report.encoded()
        }
        .suggestedFileName("ScaleMe-Input-Diagnostics.json")
    }
}

@MainActor
final class InputDiagnosticsRecorder: NSObject {
    static let shared = InputDiagnosticsRecorder()

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            if isEnabled {
                resetSession()
                append(name: .diagnosticsEnabled)
            } else {
                append(name: .diagnosticsDisabled, evenWhenDisabled: true)
                activeAttempt = nil
            }
        }
    }

    private(set) var events: [InputDiagnosticEvent] = []

    private static let enabledDefaultsKey = "InputDiagnosticsEnabled"
    private static let maximumEventCount = 500

    private let clock = ContinuousClock()
    private var sessionID = UUID()
    private var sessionStartedAt = Date.now
    private var sessionStartedInstant: ContinuousClock.Instant
    private var sequence = 0
    private var activeAttempt: ActiveAttempt?

    private override init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        sessionStartedInstant = clock.now
        super.init()
        events.reserveCapacity(64)
        registerForKeyboardNotifications()
        if isEnabled { append(name: .sessionStarted) }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var eventCount: Int { events.count }

    var export: InputDiagnosticsExport {
        InputDiagnosticsExport(report: report)
    }

    var latestAttemptSummary: InputDiagnosticAttemptSummary? {
        attemptSummaries.last
    }

    func clear() {
        resetSession()
    }

    func recordManualEntryButtonTapped() {
        append(name: .manualEntryButtonTapped)
    }

    func recordManualEntryPresented() {
        append(name: .manualEntryPresented)
    }

    func recordInputTouch(fieldID: String) {
        guard isEnabled else { return }
        activeAttempt = ActiveAttempt(
            id: UUID(),
            fieldID: fieldID,
            startedInstant: clock.now
        )
        append(name: .inputTouched, fieldID: fieldID)
    }

    func recordInputWillBeginEditing(fieldID: String, inputLanguage: String?) {
        guard isEnabled, activeAttempt?.fieldID == fieldID else { return }
        append(
            name: .inputWillBeginEditing,
            fieldID: fieldID,
            inputLanguage: inputLanguage
        )
    }

    func recordInputDidBeginEditing(fieldID: String, inputLanguage: String?) {
        ensureActiveAttempt(fieldID: fieldID)
        append(
            name: .inputDidBeginEditing,
            fieldID: fieldID,
            inputLanguage: inputLanguage
        )
    }

    func recordFirstTextChange(fieldID: String, inputLanguage: String?) {
        ensureActiveAttempt(fieldID: fieldID)
        append(
            name: .firstTextChange,
            fieldID: fieldID,
            inputLanguage: inputLanguage
        )
    }

    private var report: InputDiagnosticReport {
        InputDiagnosticReport(
            schemaVersion: 1,
            product: "ScaleMe",
            generatedAt: .now,
            appVersion: bundleValue(for: "CFBundleShortVersionString"),
            appBuild: bundleValue(for: "CFBundleVersion"),
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            localeIdentifier: Locale.current.identifier,
            sessionID: sessionID,
            sessionStartedAt: sessionStartedAt,
            events: events,
            attempts: attemptSummaries
        )
    }

    private var attemptSummaries: [InputDiagnosticAttemptSummary] {
        let grouped = Dictionary(grouping: events.compactMap { event in
            event.attemptID.map { ($0, event) }
        }, by: { $0.0 })

        return grouped.compactMap { attemptID, entries -> InputDiagnosticAttemptSummary? in
            let attemptEvents = entries.map(\.1).sorted { $0.sequence < $1.sequence }
            guard let fieldID = attemptEvents.compactMap(\.fieldID).first else { return nil }

            func elapsed(for name: InputDiagnosticEvent.Name) -> Double? {
                attemptEvents.first(where: { $0.name == name })?.attemptElapsedMilliseconds
            }

            let keyboardWillShow = elapsed(for: .keyboardWillShow)
            let keyboardDidShow = elapsed(for: .keyboardDidShow)
            let keyboardPresentation: Double?
            if let keyboardWillShow, let keyboardDidShow {
                keyboardPresentation = keyboardDidShow - keyboardWillShow
            } else {
                keyboardPresentation = nil
            }

            return InputDiagnosticAttemptSummary(
                id: attemptID,
                fieldID: fieldID,
                touchToWillBeginEditingMilliseconds: elapsed(for: .inputWillBeginEditing),
                touchToDidBeginEditingMilliseconds: elapsed(for: .inputDidBeginEditing),
                touchToKeyboardWillShowMilliseconds: keyboardWillShow,
                touchToKeyboardDidShowMilliseconds: keyboardDidShow,
                keyboardPresentationMilliseconds: keyboardPresentation,
                touchToFirstTextChangeMilliseconds: elapsed(for: .firstTextChange)
            )
        }
        .sorted { lhs, rhs in
            let lhsSequence = events.first(where: { $0.attemptID == lhs.id })?.sequence ?? 0
            let rhsSequence = events.first(where: { $0.attemptID == rhs.id })?.sequence ?? 0
            return lhsSequence < rhsSequence
        }
    }

    private func ensureActiveAttempt(fieldID: String) {
        guard isEnabled else { return }
        guard activeAttempt?.fieldID != fieldID else { return }
        activeAttempt = ActiveAttempt(
            id: UUID(),
            fieldID: fieldID,
            startedInstant: clock.now
        )
    }

    private func resetSession() {
        sessionID = UUID()
        sessionStartedAt = .now
        sessionStartedInstant = clock.now
        sequence = 0
        activeAttempt = nil
        events.removeAll(keepingCapacity: true)
        events.reserveCapacity(64)
    }

    private func append(
        name: InputDiagnosticEvent.Name,
        fieldID: String? = nil,
        inputLanguage: String? = nil,
        keyboardAnimationDurationMilliseconds: Double? = nil,
        keyboardHeightPoints: Double? = nil,
        keyboardIsLocal: Bool? = nil,
        evenWhenDisabled: Bool = false
    ) {
        guard isEnabled || evenWhenDisabled else { return }
        let now = clock.now
        sequence += 1
        events.append(
            InputDiagnosticEvent(
                id: UUID(),
                sequence: sequence,
                name: name,
                recordedAt: .now,
                sessionElapsedMilliseconds: milliseconds(from: sessionStartedInstant, to: now),
                attemptID: activeAttempt?.id,
                attemptElapsedMilliseconds: activeAttempt.map {
                    milliseconds(from: $0.startedInstant, to: now)
                },
                fieldID: fieldID ?? activeAttempt?.fieldID,
                inputLanguage: inputLanguage,
                keyboardAnimationDurationMilliseconds: keyboardAnimationDurationMilliseconds,
                keyboardHeightPoints: keyboardHeightPoints,
                keyboardIsLocal: keyboardIsLocal
            )
        )
        if events.count > Self.maximumEventCount {
            events.removeFirst(events.count - Self.maximumEventCount)
        }
    }

    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        appendKeyboardEvent(name: .keyboardWillShow, notification: notification)
    }

    @objc private func keyboardDidShow(_ notification: Notification) {
        appendKeyboardEvent(name: .keyboardDidShow, notification: notification)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        appendKeyboardEvent(name: .keyboardWillHide, notification: notification)
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        appendKeyboardEvent(name: .keyboardDidHide, notification: notification)
        activeAttempt = nil
    }

    private func appendKeyboardEvent(name: InputDiagnosticEvent.Name, notification: Notification) {
        let userInfo = notification.userInfo
        let animationDuration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        let endFrame = (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let isLocal = userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool
        append(
            name: name,
            keyboardAnimationDurationMilliseconds: animationDuration.map { $0 * 1_000 },
            keyboardHeightPoints: endFrame.map { Double($0.height) },
            keyboardIsLocal: isLocal
        )
    }

    private func milliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Double {
        let components = start.duration(to: end).components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private func bundleValue(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "unknown"
    }

    private struct ActiveAttempt {
        let id: UUID
        let fieldID: String
        let startedInstant: ContinuousClock.Instant
    }
}
