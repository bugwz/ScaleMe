import Combine
import WatchConnectivity

@MainActor
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var history = WatchHistoryState()
    var snapshot: WatchSnapshot? { history.snapshot }
    var records: [WatchRecord] { history.records }
    @Published private(set) var reachable = false
    @Published private(set) var isRequesting = false
    @Published var error: String?
    private var pendingID: UUID?
    private var requestTimeout: Task<Void, Never>?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func text(_ key: String) -> String { WatchText.text(key, language: snapshot?.language) }

    func request(_ action: WatchRequest.Action) {
        guard !isRequesting else { return }
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            error = text("手机暂不可达，请打开手机上的观我")
            return
        }
        let request = WatchRequest(action: action, profileID: snapshot?.profileID,
            revision: snapshot?.revision, offset: records.count)
        guard let data = try? WatchExchange.encode(request) else { return }
        error = nil
        isRequesting = true
        pendingID = request.id
        requestTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            self?.failed(request.id)
        }
        WCSession.default.sendMessageData(data, replyHandler: { [weak self] data in
            Task { @MainActor in
                guard let self, self.pendingID == request.id else { return }
                self.complete()
                guard let reply = try? WatchExchange.decode(WatchReply.self, from: data) else {
                    self.error = self.text("手机暂不可达，请打开手机上的观我")
                    return
                }
                self.history.accept(reply)
                self.error = reply.error
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.failed(request.id) }
        })
    }

    private func failed(_ id: UUID) {
        guard pendingID == id else { return }
        complete()
        error = text("请求未确认，请刷新手机状态")
    }

    private func complete() {
        requestTimeout?.cancel()
        pendingID = nil
        isRequesting = false
    }

    private func activated() {
        reachable = WCSession.default.isReachable
        if let data = WCSession.default.receivedApplicationContext["snapshot"] as? Data,
           let snapshot = try? WatchExchange.decode(WatchSnapshot.self, from: data) {
            history.accept(snapshot)
        }
        if reachable { request(.refresh) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.activated() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.activated() }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        receive(data)
    }
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) { receive(messageData) }
    private nonisolated func receive(_ data: Data) {
        guard let snapshot = try? WatchExchange.decode(WatchSnapshot.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.history.accept(snapshot) }
    }
}
