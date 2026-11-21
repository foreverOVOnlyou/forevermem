import Foundation

public enum ProfileUpdatePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case everySegment
    case every3Segments
    case daily
    case off

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .everySegment: "每个完成段落都更新"
        case .every3Segments: "每 3 个段落更新"
        case .daily: "每天最多一次"
        case .off: "关闭自动更新"
        }
    }

    public var detail: String {
        switch self {
        case .everySegment: "画像最跟手；成本已合并进段落总结，不额外增加调用。"
        case .every3Segments: "更省 token，但画像可能滞后两段。"
        case .daily: "每天最多一次，适合慢节奏聊天。"
        case .off: "只保留已有画像，不再自动更新。"
        }
    }

    public static func shouldUpdateProfile(
        _ policy: ProfileUpdatePolicy,
        memory: ConversationMemory,
        now: Date = Date()
    ) -> Bool {
        switch policy {
        case .everySegment:
            return true
        case .every3Segments:
            return (memory.segmentsSinceProfileUpdate ?? 0) + 1 >= 3
        case .daily:
            guard let last = memory.lastProfileUpdateAt else { return true }
            return now.timeIntervalSince(last) >= 24 * 60 * 60
        case .off:
            return false
        }
    }
}
