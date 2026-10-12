import Foundation

@main
enum WatchExchangeSmoke {
    static func main() throws {
        let profileID = UUID()
        let first = record()
        let second = record()
        let third = record()
        var snapshot = WatchSnapshot(generatedAt: Date(timeIntervalSince1970: 100), revision: UUID(),
            language: "zh-Hans", profileID: profileID, profileName: "本人", isSimulation: true,
            records: [first], totalRecords: 3)
        let encoded = try WatchExchange.encode(snapshot)
        let decoded = try WatchExchange.decode(WatchSnapshot.self, from: encoded)
        precondition(decoded == snapshot)
        var state = WatchHistoryState()
        state.accept(snapshot)
        let page = WatchReply(snapshot: snapshot, history: [second], offset: 1)
        state.accept(page)
        precondition(state.records == [first, second])
        state.accept(page)
        precondition(state.records == [first, second], "Repeated pages must not duplicate records")
        state.accept(WatchReply(snapshot: snapshot, history: [third], offset: 0))
        precondition(state.records.count == 2, "Out-of-order pages must be rejected")
        state.accept(WatchReply(snapshot: snapshot, history: [second], offset: 2))
        precondition(state.records.count == 2, "Overlapping record IDs must be rejected")
        let oldSnapshot = snapshot
        snapshot.generatedAt = Date(timeIntervalSince1970: 101)
        snapshot.revision = UUID()
        snapshot.records = [third]
        snapshot.totalRecords = 1
        snapshot.isSimulation = false
        state.accept(snapshot)
        precondition(state.records == [third], "New revisions must remove old/deleted/test records")
        state.accept(WatchReply(snapshot: oldSnapshot, history: [second], offset: 1))
        precondition(state.records == [third], "Delayed old replies must not restore stale records")
        snapshot.generatedAt = Date(timeIntervalSince1970: 102)
        snapshot.profileID = UUID()
        snapshot.records = []
        snapshot.totalRecords = 0
        state.accept(snapshot)
        precondition(state.records.isEmpty, "Switching members must clear their previous pages")

        let illegalCommand = Data("{\"id\":\"\(UUID().uuidString)\",\"action\":\"start\",\"offset\":0}".utf8)
        do {
            _ = try WatchExchange.decode(WatchRequest.self, from: illegalCommand)
            preconditionFailure("The Watch protocol must not accept measurement commands")
        } catch {}
        do {
            _ = try WatchExchange.decode(WatchSnapshot.self,
                from: Data(repeating: 0, count: WatchExchange.maximumPayloadBytes + 1))
            preconditionFailure("Oversized payload must be rejected")
        } catch {}
        // A full first page and history page fit below WatchConnectivity's message limit.
        snapshot.records = (0..<WatchExchange.pageSize).map { _ in record() }
        snapshot.totalRecords = 100
        let reply = WatchReply(snapshot: snapshot,
            history: (0..<WatchExchange.pageSize).map { _ in record() }, offset: WatchExchange.pageSize)
        _ = try WatchExchange.encode(reply)
        try checkLocalization()
        print("Watch exchange, read-only commands, pagination and localization smoke passed")
    }

    private static func record() -> WatchRecord {
        WatchRecord(id: UUID(), date: Date(timeIntervalSince1970: 100), weight: "60.25 kg",
            details: (0..<11).map { _ in WatchMetric(title: "身体水分", value: "55.00 %") },
            device: String(repeating: "秤", count: 160))
    }

    private static func checkLocalization() throws {
        let languages = ["de", "en", "es", "fr", "ja", "ko", "pt", "ru", "zh-Hans", "zh-Hant"]
        for path in ["ScaleMeWatchShared/Watch.xcstrings", "ScaleMeWatch/InfoPlist.xcstrings"] {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            precondition(catalog["sourceLanguage"] as? String == "zh-Hans")
            let strings = catalog["strings"] as! [String: [String: Any]]
            for (key, entry) in strings {
                precondition(entry["extractionState"] as? String == "manual")
                let localizations = entry["localizations"] as! [String: [String: Any]]
                for language in languages {
                    let unit = localizations[language]?["stringUnit"] as? [String: String]
                    precondition(unit?["state"] == "translated", "\(key): \(language)")
                    precondition(unit?["value"]?.isEmpty == false)
                }
            }
            let source = String(decoding: data, as: UTF8.self)
            precondition(source.components(separatedBy: "\n").filter { $0.contains("\"extractionState\"") }.count == strings.count)
        }
    }
}
