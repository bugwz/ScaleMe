import Combine
import WatchConnectivity

/// Exposes only read operations. Measurement creation and persistence stay on iPhone.
@MainActor
final class PhoneWatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    private weak var store: MeasurementStore?
    private var subscription: AnyCancellable?
    private var revision = UUID()
    private var records: [BodyMeasurement] = []
    private var profile: UserProfile?
    private var simulationMode: Bool?
    private var language: AppLanguage?
    private var unit: WeightUnit?

    func configure(store: MeasurementStore) {
        guard self.store == nil else { return }
        self.store = store
        subscription = store.objectWillChange
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.publish() }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func snapshot() -> WatchSnapshot? {
        guard let store else { return nil }
        let currentRecords = store.displayMeasurements.sorted { $0.date > $1.date }
        if records != currentRecords || profile != store.displaySelectedProfile
            || simulationMode != store.isShowingDemoData || language != store.appLanguage || unit != store.unit {
            revision = UUID()
            records = currentRecords
        }
        profile = store.displaySelectedProfile
        simulationMode = store.isShowingDemoData
        language = store.appLanguage
        unit = store.unit
        return WatchSnapshot(
            generatedAt: .now, revision: revision, language: store.appLanguage.rawValue,
            profileID: store.displaySelectedProfileID,
            profileName: String(store.displaySelectedProfile.name.prefix(160)),
            isSimulation: store.isShowingDemoData,
            records: records.prefix(WatchExchange.pageSize).map(record), totalRecords: records.count
        )
    }

    private func weightText(_ kg: Double) -> String {
        guard let store else { return "" }
        return store.unit.value(fromKilograms: kg)
            .formatted(.number.precision(.fractionLength(2)).locale(store.appLanguage.locale))
            + " " + store.unit.symbol
    }

    private func record(_ value: BodyMeasurement) -> WatchRecord {
        guard let store else {
            return WatchRecord(id: value.id, date: value.date, weight: "", details: [], device: "")
        }
        let details = TrendMetric.allCases.filter { $0 != .weight }.compactMap { metric -> WatchMetric? in
            guard let number = metric.value(for: value, profile: store.displaySelectedProfile) else { return nil }
            let unit = metric.unitLabel(weightUnit: store.unit)
            let formatted = metric.displayValue(number, unit: store.unit)
                .formatted(.number.precision(.fractionLength(2)).locale(store.appLanguage.locale))
            return WatchMetric(title: store.appLanguage.text(metric.title),
                value: formatted + (unit.isEmpty ? "" : " " + unit))
        }
        return WatchRecord(id: value.id, date: value.date, weight: weightText(value.weightKG),
            details: details,
            device: String((value.deviceName ?? store.appLanguage.text(value.source.localizationKey)).prefix(160)))
    }

    private func publish() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled,
              let snapshot = snapshot(), let data = try? WatchExchange.encode(snapshot) else { return }
        do {
            try WCSession.default.updateApplicationContext(["snapshot": data])
        } catch {
            // Refresh retries the latest state; never log health records.
        }
        if WCSession.default.isReachable {
            WCSession.default.sendMessageData(data, replyHandler: nil, errorHandler: { _ in })
        }
    }

    private func handle(_ request: WatchRequest) -> WatchReply? {
        guard let snapshot = snapshot() else { return nil }
        switch request.action {
        case .refresh:
            return WatchReply(snapshot: snapshot)
        case .history:
            guard request.revision == snapshot.revision, request.profileID == snapshot.profileID,
                  request.offset >= 0, request.offset <= records.count else {
                return WatchReply(snapshot: snapshot,
                    error: WatchText.text("手机记录已更新，请刷新后重试", language: snapshot.language))
            }
            return WatchReply(snapshot: snapshot,
                history: records.dropFirst(request.offset).prefix(WatchExchange.pageSize).map(record),
                offset: request.offset)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.publish() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.publish() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.publish() }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor [weak self] in
            guard let request = try? WatchExchange.decode(WatchRequest.self, from: messageData),
                  let reply = self?.handle(request), let data = try? WatchExchange.encode(reply) else {
                replyHandler(Data())
                return
            }
            replyHandler(data)
        }
    }
}
