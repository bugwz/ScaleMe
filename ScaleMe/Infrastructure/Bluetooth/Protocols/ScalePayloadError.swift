import Foundation

enum ScalePayloadError: LocalizedError {
    case tooShort
    case unsupported
    case unstable

    var errorDescription: String? {
        switch self {
        case .tooShort: "蓝牙数据长度不足"
        case .unsupported: "暂不支持该数据格式"
        case .unstable: "等待秤面读数稳定"
        }
    }
}
