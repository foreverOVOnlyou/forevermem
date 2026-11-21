import Foundation

public struct MemoryCapsule: Codable, Sendable {
    public let id: UUID
    public let firstMessageID: UUID
    public let lastMessageID: UUID
    public let startAt: Date
    public let endAt: Date
    public let text: String
    public var importance: Double?
    public var accessCount: Int?
    public var lastAccessAt: Date?
    public var stability: Double?
    public var archived: Bool?

    public init(
        id: UUID,
        firstMessageID: UUID,
        lastMessageID: UUID,
        startAt: Date,
        endAt: Date,
        text: String,
        importance: Double? = nil,
        accessCount: Int? = nil,
        lastAccessAt: Date? = nil,
        stability: Double? = nil,
        archived: Bool? = nil
    ) {
        self.id = id
        self.firstMessageID = firstMessageID
        self.lastMessageID = lastMessageID
        self.startAt = startAt
        self.endAt = endAt
        self.text = text
        self.importance = importance
        self.accessCount = accessCount
        self.lastAccessAt = lastAccessAt
        self.stability = stability
        self.archived = archived
    }
}

public struct MemoryDaySummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let day: String
    public let segment: Int
    public let firstMessageID: UUID
    public let lastMessageID: UUID
    public let text: String
    public let vector: [Double]?
    public var createdAt: Date?
    public var importance: Double?
    public var accessCount: Int?
    public var lastAccessAt: Date?
    public var stability: Double?
    public var archived: Bool?

    public init(
        id: UUID,
        day: String,
        segment: Int,
        firstMessageID: UUID,
        lastMessageID: UUID,
        text: String,
        vector: [Double]?,
        createdAt: Date? = nil,
        importance: Double? = nil,
        accessCount: Int? = nil,
        lastAccessAt: Date? = nil,
        stability: Double? = nil,
        archived: Bool? = nil
    ) {
        self.id = id
        self.day = day
        self.segment = segment
        self.firstMessageID = firstMessageID
        self.lastMessageID = lastMessageID
        self.text = text
        self.vector = vector
        self.createdAt = createdAt
        self.importance = importance
        self.accessCount = accessCount
        self.lastAccessAt = lastAccessAt
        self.stability = stability
        self.archived = archived
    }
}

public struct MemoryFactRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let kind: MemoryFactKind
    public var text: String
    public var sourceMessageIDs: [UUID]
    public var createdAt: Date
    public var confidence: Double
    public var pinned: Bool?
    public var importance: Double?
    public var accessCount: Int?
    public var lastAccessAt: Date?
    public var stability: Double?
    public var updatedAt: Date?
    public var isDeleted: Bool?
    public var deletedAt: Date?
    public var archived: Bool?
    public var vector: [Double]?

    public init(
        id: UUID,
        kind: MemoryFactKind,
        text: String,
        sourceMessageIDs: [UUID],
        createdAt: Date,
        confidence: Double,
        pinned: Bool? = nil,
        importance: Double? = nil,
        accessCount: Int? = nil,
        lastAccessAt: Date? = nil,
        stability: Double? = nil,
        updatedAt: Date? = nil,
        isDeleted: Bool? = nil,
        deletedAt: Date? = nil,
        archived: Bool? = nil,
        vector: [Double]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.sourceMessageIDs = sourceMessageIDs
        self.createdAt = createdAt
        self.confidence = confidence
        self.pinned = pinned
        self.importance = importance
        self.accessCount = accessCount
        self.lastAccessAt = lastAccessAt
        self.stability = stability
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.archived = archived
        self.vector = vector
    }
}

public struct MemoryProfileItem: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: MemoryProfileItemKind
    public var text: String
    public var sourceMessageIDs: [UUID]
    public var confidence: Double
    public var updatedAt: Date

    public init(
        id: UUID,
        kind: MemoryProfileItemKind,
        text: String,
        sourceMessageIDs: [UUID],
        confidence: Double,
        updatedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.sourceMessageIDs = sourceMessageIDs
        self.confidence = confidence
        self.updatedAt = updatedAt
    }
}

public struct MemoryProfile: Codable, Sendable, Equatable {
    public var text: String
    public var sourceMessageIDs: [UUID]
    public var updatedAt: Date
    public var confidence: Double
    public var items: [MemoryProfileItem]?

    public init(
        text: String,
        sourceMessageIDs: [UUID],
        updatedAt: Date,
        confidence: Double,
        items: [MemoryProfileItem]? = nil
    ) {
        self.text = text
        self.sourceMessageIDs = sourceMessageIDs
        self.updatedAt = updatedAt
        self.confidence = confidence
        self.items = items
    }

    public var renderedText: String {
        guard let items, !items.isEmpty else { return text }
        return items.map(\.text).joined(separator: "\n")
    }
}

public struct ConversationMemory: Codable, Sendable {
    public var schemaVersion: Int
    public var socialEvents: [String]?
    public var capsules: [MemoryCapsule]
    public var daySummaries: [MemoryDaySummary]?
    public var facts: [MemoryFactRecord]?
    public var profile: MemoryProfile?
    public var segmentsSinceProfileUpdate: Int?
    public var lastProfileUpdateAt: Date?

    public init() {
        schemaVersion = 2
        socialEvents = nil
        capsules = []
        daySummaries = nil
        facts = nil
        profile = nil
        segmentsSinceProfileUpdate = 0
        lastProfileUpdateAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, socialEvents, capsules, daySummaries, facts
        case profile, segmentsSinceProfileUpdate, lastProfileUpdateAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        socialEvents = try values.decodeIfPresent([String].self, forKey: .socialEvents)
        capsules = try values.decodeIfPresent([MemoryCapsule].self, forKey: .capsules) ?? []
        daySummaries = try values.decodeIfPresent([MemoryDaySummary].self, forKey: .daySummaries)
        facts = try values.decodeIfPresent([MemoryFactRecord].self, forKey: .facts)
        profile = try values.decodeIfPresent(MemoryProfile.self, forKey: .profile)
        segmentsSinceProfileUpdate = try values.decodeIfPresent(Int.self, forKey: .segmentsSinceProfileUpdate)
        lastProfileUpdateAt = try values.decodeIfPresent(Date.self, forKey: .lastProfileUpdateAt)
    }
}

extension ConversationMemory {
    @discardableResult
    public mutating func forgetSource(of messageID: UUID) -> Bool {
        var changed = false

        if let facts, facts.contains(where: { $0.sourceMessageIDs.contains(messageID) }) {
            self.facts = facts.compactMap { fact -> MemoryFactRecord? in
                var copy = fact
                copy.sourceMessageIDs.removeAll { $0 == messageID }
                return copy.sourceMessageIDs.isEmpty ? nil : copy
            }
            changed = true
        }

        let capsuleCount = capsules.count
        capsules.removeAll { $0.firstMessageID == messageID || $0.lastMessageID == messageID }
        if capsules.count != capsuleCount { changed = true }

        if let summaries = daySummaries {
            let remaining = summaries.filter {
                $0.firstMessageID != messageID && $0.lastMessageID != messageID
            }
            if remaining.count != summaries.count {
                daySummaries = remaining
                changed = true
            }
        }
        return changed
    }
}

public typealias MemoryDocument = ConversationMemory
