import Foundation

public struct ExtractedMemoryFact: Equatable, Sendable {
    public let kind: MemoryFactKind
    public let text: String
    public let sourceMessageIDs: [UUID]
    public let confidence: Double

    public init(kind: MemoryFactKind, text: String, sourceMessageIDs: [UUID], confidence: Double) {
        self.kind = kind
        self.text = text
        self.sourceMessageIDs = sourceMessageIDs
        self.confidence = confidence
    }
}

public struct ExtractedProfileItem: Equatable, Sendable {
    public let kind: MemoryProfileItemKind
    public let text: String
    public let sourceMessageIDs: [UUID]
    public let confidence: Double

    public init(kind: MemoryProfileItemKind, text: String, sourceMessageIDs: [UUID], confidence: Double) {
        self.kind = kind
        self.text = text
        self.sourceMessageIDs = sourceMessageIDs
        self.confidence = confidence
    }
}

public struct ExtractedProfileUpdate: Equatable, Sendable {
    public let items: [ExtractedProfileItem]

    public init(items: [ExtractedProfileItem]) {
        self.items = items
    }
}

public struct MemorySegmentExtraction: Equatable, Sendable {
    public let summary: String
    public let facts: [ExtractedMemoryFact]
    public let profile: ExtractedProfileUpdate?
    public let importance: Double?

    public init(
        summary: String,
        facts: [ExtractedMemoryFact],
        profile: ExtractedProfileUpdate?,
        importance: Double?
    ) {
        self.summary = summary
        self.facts = facts
        self.profile = profile
        self.importance = importance
    }
}

public enum MemoryExtractionParser {
    private struct Envelope: Decodable {
        let summary: String?
        let facts: [Fact]?
        let profile: Profile?
        let importance: Double?
    }

    private struct Fact: Decodable {
        let kind: String?
        let text: String?
        let sourceIndexes: [Int]?
        let confidence: Double?
    }

    private struct Profile: Decodable {
        let changed: Bool?
        let summary: String?
        let items: [ProfileItem]?
        let sourceIndexes: [Int]?
        let confidence: Double?
    }

    private struct ProfileItem: Decodable {
        let kind: String?
        let text: String?
        let sourceIndexes: [Int]?
        let confidence: Double?
    }

    public static func parse(_ raw: String, sourceIDs: [UUID]) throws -> MemorySegmentExtraction {
        var content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```") {
            guard let newline = content.firstIndex(of: "\n") else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "记忆总结缺少 JSON 正文。"))
            }
            content = String(content[content.index(after: newline)...])
            if content.hasSuffix("```") { content = String(content.dropLast(3)) }
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard content.hasPrefix("{") else {
            guard !content.isEmpty else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "记忆总结为空。"))
            }
            return .init(summary: content, facts: [], profile: nil, importance: nil)
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(content.utf8))
        let summary = envelope.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !summary.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "记忆总结为空。"))
        }

        var seen = Set<String>()
        let facts = (envelope.facts ?? []).compactMap { value -> ExtractedMemoryFact? in
            let text = value.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return nil }
            let bounded = String(text.prefix(1_000))
            let key = bounded.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            let ids = Array(Set((value.sourceIndexes ?? []).compactMap { index in
                sourceIDs.indices.contains(index) ? sourceIDs[index] : nil
            }))
            guard !ids.isEmpty else { return nil }
            let kind = value.kind.flatMap(MemoryFactKind.init(rawValue:)) ?? .fact
            let confidence = min(1, max(0, value.confidence ?? 0.7))
            return .init(kind: kind, text: bounded, sourceMessageIDs: ids, confidence: confidence)
        }
        let profile: ExtractedProfileUpdate?
        if let value = envelope.profile, value.changed != false {
            let fallbackIDs = Array(Set((value.sourceIndexes ?? []).compactMap { index in
                sourceIDs.indices.contains(index) ? sourceIDs[index] : nil
            }))
            var seen = Set<String>()
            var items: [ExtractedProfileItem] = (value.items ?? []).compactMap { item in
                let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { return nil }
                let bounded = String(text.prefix(300))
                let key = bounded.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
                guard !key.isEmpty, seen.insert(key).inserted else { return nil }
                let ids = Array(Set((item.sourceIndexes ?? []).compactMap { index in
                    sourceIDs.indices.contains(index) ? sourceIDs[index] : nil
                }))
                guard !ids.isEmpty else { return nil }
                let kind = item.kind.flatMap(MemoryProfileItemKind.init(rawValue:)) ?? .other
                return ExtractedProfileItem(
                    kind: kind,
                    text: bounded,
                    sourceMessageIDs: ids,
                    confidence: min(1, max(0, item.confidence ?? value.confidence ?? 0.7))
                )
            }
            // Backward compatibility: an older prompt may return one summary.
            if items.isEmpty {
                let text = value.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !text.isEmpty, !fallbackIDs.isEmpty {
                    items = [ExtractedProfileItem(
                        kind: .other,
                        text: String(text.prefix(600)),
                        sourceMessageIDs: fallbackIDs,
                        confidence: min(1, max(0, value.confidence ?? 0.7))
                    )]
                }
            }
            profile = items.isEmpty ? nil : ExtractedProfileUpdate(items: Array(items.prefix(8)))
        } else {
            profile = nil
        }

        return .init(
            summary: String(summary.prefix(8_000)),
            facts: Array(facts.prefix(8)),
            profile: profile,
            importance: envelope.importance.map { min(1, max(0, $0)) }
        )
    }
}
