import Foundation

/// Applying a new phone revision replaces all pages, including deleted records.
struct WatchHistoryState {
    private(set) var snapshot: WatchSnapshot?
    private(set) var records: [WatchRecord] = []

    mutating func accept(_ incoming: WatchSnapshot) {
        guard snapshot.map({ incoming.generatedAt >= $0.generatedAt }) ?? true else { return }
        if snapshot?.revision != incoming.revision || snapshot?.profileID != incoming.profileID
            || snapshot?.isSimulation != incoming.isSimulation || snapshot?.language != incoming.language
            || snapshot?.records != incoming.records {
            records = incoming.records
        }
        snapshot = incoming
    }

    mutating func accept(_ reply: WatchReply) {
        accept(reply.snapshot)
        guard reply.error == nil, let page = reply.history, let offset = reply.offset,
              reply.snapshot.revision == snapshot?.revision,
              reply.snapshot.profileID == snapshot?.profileID,
              offset == records.count,
              records.count + page.count <= reply.snapshot.totalRecords,
              Set(records.map(\.id)).isDisjoint(with: page.map(\.id)),
              Set(page.map(\.id)).count == page.count else { return }
        records.append(contentsOf: page)
    }
}
