import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var bluetooth: BLEScaleManager
    @State private var showCompatibility = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    connectionCard
                    measurementCard
                    compatibilityCard
                }.padding(.horizontal, 18).padding(.bottom, 28)
            }
            .pageBackground().navigationTitle("设备")
        }
    }

    private var connectionCard: some View {
        SoftCard {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("体重体脂秤").font(.title3.bold())
                        Text(bluetooth.state.title).font(.subheadline).foregroundStyle(AppColor.secondary)
                    }
                    Spacer()
                    Image(systemName: "scalemass.fill").font(.system(size: 34)).foregroundStyle(AppColor.mint)
                        .frame(width: 66, height: 66).background(AppColor.paleMint, in: RoundedRectangle(cornerRadius: 20))
                }
                Button { bluetooth.startScanning() } label: {
                    Label("添加或更换设备", systemImage: "plus")
                        .frame(maxWidth: .infinity).padding(.vertical, 13).foregroundStyle(.white).background(AppColor.mint, in: RoundedRectangle(cornerRadius: 15))
                }
            }
        }
    }

    private var measurementCard: some View {
        SoftCard {
            HStack {
                Label("重复记录", systemImage: "square.stack.3d.down.right")
                Spacer()
                Text("30 秒自动合并").font(.subheadline).foregroundStyle(AppColor.secondary)
            }.padding(.vertical, 8)
        }
    }

    private var compatibilityCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack { Text("兼容性").font(.headline); Spacer(); Image(systemName: "checkmark.seal.fill").foregroundStyle(AppColor.mint) }
                CompatibilityRow(title: "Bluetooth SIG 标准秤", detail: "Weight Scale / Body Composition", state: "已实现", color: AppColor.mint)
                CompatibilityRow(title: "小米体重秤 / 体脂秤 1、2", detail: "公开 0x181B 广播格式", state: "已实现", color: AppColor.mint)
                CompatibilityRow(title: "云麦、香山、RENPHO 等", detail: "不同型号协议并不相同", state: "待实机", color: AppColor.apricot)
                CompatibilityRow(title: "小米 S400 等加密型号", detail: "需要设备绑定密钥与授权流程", state: "规划中", color: AppColor.violet)
                Button { showCompatibility.toggle() } label: {
                    Text(showCompatibility ? "收起说明" : "为什么不能写“全品牌兼容”？").font(.subheadline.weight(.semibold))
                }
                if showCompatibility {
                    Text("蓝牙秤没有统一使用同一种数据格式。标准服务可通用解析，但许多品牌采用私有、加密或随型号变化的协议，必须按真实硬件和固件逐项验证。观我会把每个协议做成独立适配器，避免一次改动影响其他设备。")
                        .font(.caption).foregroundStyle(AppColor.secondary).lineSpacing(3)
                }
            }
        }
    }
}

private struct CompatibilityRow: View {
    let title, detail, state: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(AppColor.secondary)
            }
            Spacer()
            StatusPill(text: state, color: color)
        }
    }
}
