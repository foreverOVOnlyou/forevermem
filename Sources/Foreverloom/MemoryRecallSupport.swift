import Foundation

public struct MemoryRecallBudget: Sendable {
    public var profileCharacters = 1_500
    public var recentCharacters = 6_000
    public var socialCharacters = 1_200
    public var factCharacters = 2_000
    public var capsuleCharacters = 7_500
    public var recalledCapsuleCharacters = 3_000
    public var daySummaryCharacters = 5_000
    public var evidenceCharacters = 4_000
    public var totalCharacters = 30_000

    public static let `default` = MemoryRecallBudget()

    public init() {}
}

public enum MemoryLexical {
    public static func relevance(_ text: String, query: String) -> Double {
        let lhs = terms(text), rhs = terms(query)
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(rhs.count)
    }

    public static func jaccard(_ lhs: String, _ rhs: String) -> Double {
        let left = terms(lhs), right = terms(rhs)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }

    public static func terms(_ text: String) -> Set<String> {
        let normalized = canonical(text).lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
        let chars = Array(normalized)
        guard chars.count > 1 else { return Set(chars.map(String.init)) }
        return Set((0..<(chars.count - 1)).map { String(chars[$0...$0 + 1]) })
    }

    private static func canonical(_ text: String) -> String {
        var value = text
        for pair in canonicalPairs {
            value = value.replacingOccurrences(of: pair.0, with: pair.1)
        }
        return value
    }

    private static let canonicalPairs: [(String, String)] = [
        ("看海", "海边"),
        ("海滩", "海边"),
        ("上班", "工作"),
        ("吃饭", "饮食"),
        ("美食", "饮食"),
        ("喜爱", "喜欢"),
        ("旅游", "旅行"),
        ("周六", "周末"),
        ("周日", "周末")
    ]
}

public struct MemoryEvidenceWindow: Equatable, Sendable {
    public let messages: [MemoryMessage]
    public let score: Double

    public var characterCount: Int { messages.reduce(0) { $0 + $1.content.count + 24 } }

    public init(messages: [MemoryMessage], score: Double) {
        self.messages = messages
        self.score = score
    }
}

public enum MemoryEvidenceRetriever {
    public static func windows(
        messages: [MemoryMessage],
        query: String,
        seedIDs: Set<UUID> = [],
        excludingIDs: Set<UUID> = [],
        maximumWindows: Int = 4,
        characterBudget: Int = 4_000
    ) -> [MemoryEvidenceWindow] {
        guard (!query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !seedIDs.isEmpty),
              !messages.isEmpty else { return [] }
        let scored = messages.enumerated().compactMap { index, message -> (Int, Double)? in
            guard !excludingIDs.contains(message.id), !message.content.isEmpty else { return nil }
            if seedIDs.contains(message.id) { return (index, 1) }
            let score = MemoryLexical.relevance(message.content, query: query)
            return score >= 0.12 ? (index, score) : nil
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return messages[$0.0].createdAt > messages[$1.0].createdAt
        }

        var selectedIDs = excludingIDs
        var windows: [MemoryEvidenceWindow] = []
        var usedCharacters = 0
        for (index, score) in scored {
            guard windows.count < maximumWindows else { break }
            let lower = max(0, index - 1)
            let upper = min(messages.count - 1, index + 1)
            var accepted: [MemoryMessage] = []
            for offset in lower...upper {
                let message = messages[offset]
                guard !selectedIDs.contains(message.id) else { continue }
                let cost = message.content.count + 24
                guard usedCharacters + cost <= characterBudget else { continue }
                accepted.append(message)
                selectedIDs.insert(message.id)
                usedCharacters += cost
            }
            if !accepted.isEmpty {
                windows.append(.init(messages: accepted, score: score))
            }
        }
        return windows.sorted {
            ($0.messages.first?.createdAt ?? .distantPast) < ($1.messages.first?.createdAt ?? .distantPast)
        }
    }
}

public struct MemoryRecallTrace: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public let conversationID: UUID
    public let startedAt: Date
    public let duration: TimeInterval
    public let queryCharacters: Int
    public let socialCount: Int
    public let factCount: Int
    public let capsuleCount: Int
    public let recalledCapsuleCount: Int
    public let daySummaryCount: Int
    public let evidenceWindowCount: Int
    public let evidenceMessageCount: Int
    public let contextCharacters: Int
    public let embeddingAttempted: Bool
    public let embeddingSucceeded: Bool

    public init(
        conversationID: UUID,
        startedAt: Date,
        duration: TimeInterval,
        queryCharacters: Int,
        socialCount: Int,
        factCount: Int,
        capsuleCount: Int,
        recalledCapsuleCount: Int,
        daySummaryCount: Int,
        evidenceWindowCount: Int,
        evidenceMessageCount: Int,
        contextCharacters: Int,
        embeddingAttempted: Bool,
        embeddingSucceeded: Bool
    ) {
        self.conversationID = conversationID
        self.startedAt = startedAt
        self.duration = duration
        self.queryCharacters = queryCharacters
        self.socialCount = socialCount
        self.factCount = factCount
        self.capsuleCount = capsuleCount
        self.recalledCapsuleCount = recalledCapsuleCount
        self.daySummaryCount = daySummaryCount
        self.evidenceWindowCount = evidenceWindowCount
        self.evidenceMessageCount = evidenceMessageCount
        self.contextCharacters = contextCharacters
        self.embeddingAttempted = embeddingAttempted
        self.embeddingSucceeded = embeddingSucceeded
    }
}
