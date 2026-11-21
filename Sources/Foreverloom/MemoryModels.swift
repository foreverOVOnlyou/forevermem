import Foundation

public struct MemoryMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: String
    public let content: String
    public let createdAt: Date

    public init(id: UUID, role: String, content: String, createdAt: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public enum MemoryProfileItemKind: String, Codable, CaseIterable, Sendable {
    case identity
    case preference
    case relationship
    case boundary
    case other

    public var title: String {
        switch self {
        case .identity: "身份"
        case .preference: "偏好"
        case .relationship: "关系"
        case .boundary: "边界"
        case .other: "其他"
        }
    }
}

public enum MemoryFactKind: String, Codable, CaseIterable, Sendable {
    case event
    case preference
    case promise
    case relationship
    case fact

    public var title: String {
        switch self {
        case .event: "事件"
        case .preference: "偏好"
        case .promise: "承诺"
        case .relationship: "关系"
        case .fact: "事实"
        }
    }
}
