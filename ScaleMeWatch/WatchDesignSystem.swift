import SwiftUI

/// Watch adaptation of ScaleMe's dark palette for its always-dark interface.
enum WatchPalette {
    static let canvas = Color(red: 12 / 255, green: 23 / 255, blue: 21 / 255)
    static let surface = Color(red: 20 / 255, green: 37 / 255, blue: 34 / 255)
    static let mint = Color(red: 20 / 255, green: 173 / 255, blue: 140 / 255)
    static let ink = Color(red: 231 / 255, green: 245 / 255, blue: 241 / 255)
}

struct WatchCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(WatchPalette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct WatchSyncFooter: View {
    @EnvironmentObject private var session: WatchSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !session.reachable {
                Text(verbatim: session.text("手机暂不可达，当前显示上次同步记录")).font(.caption2)
            }
            if let error = session.error { Text(verbatim: error).font(.caption) }
            Button(session.text("刷新手机记录")) { session.request(.refresh) }
                .tint(WatchPalette.mint)
                .disabled(!session.reachable || session.isRequesting)
            if session.isRequesting {
                ProgressView().accessibilityLabel(session.text("正在同步手机记录"))
            }
            if let snapshot = session.snapshot {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: session.text("手机数据更新时间"))
                    Text(snapshot.generatedAt, format: .dateTime.month().day().hour().minute())
                }.font(.caption2).accessibilityElement(children: .combine)
            }
        }
    }
}
