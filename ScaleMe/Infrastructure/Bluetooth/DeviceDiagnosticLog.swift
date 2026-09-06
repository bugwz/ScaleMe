import Foundation

struct DeviceDiagnosticEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case advertisement = "广播"
        case service = "服务"
        case characteristic = "特征"
        case notification = "通知"
        case write = "写入"
        case acknowledgement = "回执"
        case read = "读取"
        case received = "响应"
        case error = "错误"
    }

    let id = UUID()
    var elapsedSeconds: TimeInterval
    var kind: Kind
    var source: String
    var payloadHex: String?
    var summary: String

    var reportLine: String {
        String(
            format: "%7.3fs  %-4@  %-36@  %-24@  %@",
            elapsedSeconds,
            kind.rawValue,
            source,
            payloadHex ?? "-",
            summary
        )
    }
}

struct DeviceDiagnosticLog {
    private(set) var isCapturing = false
    private(set) var events: [DeviceDiagnosticEvent] = []
    private var startedAt: Date?

    mutating func start(at date: Date = .now) {
        events.removeAll(keepingCapacity: true)
        startedAt = date
        isCapturing = true
    }

    mutating func stop() {
        isCapturing = false
    }

    mutating func resetIfInactive() {
        guard !isCapturing else { return }
        events.removeAll(keepingCapacity: true)
        startedAt = nil
    }

    mutating func end() {
        isCapturing = false
        startedAt = nil
    }

    mutating func append(
        kind: DeviceDiagnosticEvent.Kind,
        source: String,
        payloadHex: String? = nil,
        summary: String,
        receivedAt: Date = .now
    ) {
        guard isCapturing, let startedAt else { return }
        events.append(DeviceDiagnosticEvent(
            elapsedSeconds: receivedAt.timeIntervalSince(startedAt),
            kind: kind,
            source: source,
            payloadHex: payloadHex,
            summary: summary
        ))
        if events.count > 500 {
            events.removeFirst(events.count - 500)
        }
    }

    func report(deviceID: UUID?, serviceUUIDs: [String]) -> String {
        let device = deviceID?.uuidString ?? "-"
        let services = serviceUUIDs.joined(separator: ", ")
        let header = "ScaleMe device diagnostic capture\ndevice: \(device)\nservices: \(services)\nelapsed  type  source                                payload                   summary\n"
        return header + events.map(\.reportLine).joined(separator: "\n")
    }
}
