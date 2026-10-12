import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var session: WatchSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let snapshot = session.snapshot {
                        Text(verbatim: snapshot.profileName).font(.headline)
                        if snapshot.isSimulation {
                            Label(session.text("手机测试数据"), systemImage: "testtube.2")
                                .font(.caption).foregroundStyle(WatchPalette.mint)
                        }
                        if let latest = snapshot.records.first {
                            NavigationLink {
                                WatchRecordDetailView(recordID: latest.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verbatim: latest.weight)
                                        .font(.title2.bold()).minimumScaleFactor(0.65)
                                    Text(latest.date, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                }.modifier(WatchCard())
                            }.buttonStyle(.plain)
                        } else {
                            Text(verbatim: session.text("手机暂无测量记录"))
                        }
                        NavigationLink(session.text("查看手机测量记录")) { WatchHistoryView() }
                        Text(verbatim: session.text("跟随手机当前成员，仅查看手机记录"))
                            .font(.caption2)
                    } else {
                        Image(systemName: "iphone.and.arrow.forward").font(.title)
                            .accessibilityHidden(true)
                        Text(verbatim: session.text("打开手机上的观我以同步记录"))
                    }
                    WatchSyncFooter()
                }.padding(.horizontal, 8)
            }
            .background(WatchPalette.canvas)
            .foregroundStyle(WatchPalette.ink)
            .navigationTitle(Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? "ScaleMe")
        }
    }
}

struct WatchHistoryView: View {
    @EnvironmentObject private var session: WatchSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(verbatim: session.snapshot?.profileName ?? "").font(.headline)
                if session.snapshot?.isSimulation == true {
                    Text(verbatim: session.text("手机测试数据")).font(.caption)
                }
                if session.records.isEmpty { Text(verbatim: session.text("手机暂无测量记录")) }
                ForEach(session.records) { record in
                    NavigationLink {
                        WatchRecordDetailView(recordID: record.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: record.weight).font(.headline)
                            Text(record.date, format: .dateTime.month().day().hour().minute()).font(.caption2)
                        }.modifier(WatchCard())
                    }.buttonStyle(.plain)
                }
                if session.records.count < (session.snapshot?.totalRecords ?? 0) {
                    Button(session.text("加载更早的手机记录")) { session.request(.history) }
                        .disabled(!session.reachable || session.isRequesting)
                }
                WatchSyncFooter()
            }.padding(.horizontal, 8)
        }.background(WatchPalette.canvas)
            .foregroundStyle(WatchPalette.ink)
            .navigationTitle(session.text("查看手机测量记录"))
    }
}

struct WatchRecordDetailView: View {
    @EnvironmentObject private var session: WatchSession
    let recordID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let record = session.records.first(where: { $0.id == recordID }) {
                    Text(verbatim: session.snapshot?.profileName ?? "").font(.headline)
                    if session.snapshot?.isSimulation == true {
                        Text(verbatim: session.text("手机测试数据")).font(.caption)
                    }
                    Text(verbatim: record.weight).font(.title2.bold())
                    Text(record.date, format: .dateTime.year().month().day().hour().minute())
                    Text(verbatim: record.device).font(.caption)
                    ForEach(Array(record.details.enumerated()), id: \.offset) { _, metric in
                        VStack(alignment: .leading) {
                            Text(verbatim: metric.title).font(.caption)
                            Text(verbatim: metric.value)
                        }.modifier(WatchCard()).accessibilityElement(children: .combine)
                    }
                    Text(verbatim: session.text("身体成分为估算值，仅供趋势参考"))
                        .font(.caption2)
                } else {
                    Text(verbatim: session.text("手机记录已更新，请返回记录列表"))
                }
                WatchSyncFooter()
            }.padding(.horizontal, 8)
        }.background(WatchPalette.canvas).foregroundStyle(WatchPalette.ink)
    }
}
