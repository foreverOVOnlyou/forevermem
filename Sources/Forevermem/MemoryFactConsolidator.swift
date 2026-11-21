import Foundation

public enum MemoryOperationAction: String, Codable, Sendable, CaseIterable {
    case add
    case update
    case delete
    case noop
}

public struct MemoryConsolidationOperation: Equatable, Sendable {
    public let action: MemoryOperationAction
    public let existingID: UUID?
    public let newIndexes: [Int]
    public let text: String?

    public init(
        action: MemoryOperationAction,
        existingID: UUID? = nil,
        newIndexes: [Int] = [],
        text: String? = nil
    ) {
        self.action = action
        self.existingID = existingID
        self.newIndexes = newIndexes
        self.text = text
    }
}

public enum MemoryConsolidationError: LocalizedError {
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let detail): "记忆巩固结果无效：\(detail)"
        }
    }
}

/// Pure Mem0-style write consolidation. Retrieval here is only for choosing
/// candidate facts to show the model; applying operations is deterministic and
/// fully unit-testable without the chat API.
public enum MemoryFactConsolidator {
    public static func activeFacts(_ facts: [MemoryFactRecord]) -> [MemoryFactRecord] {
        facts.filter { $0.isDeleted != true && $0.archived != true }
    }

    public static func candidates(
        existing: [MemoryFactRecord],
        incoming: [MemoryFactRecord],
        limit: Int = 12,
        now: Date = Date()
    ) -> [MemoryFactRecord] {
        let active = activeFacts(existing)
        guard !active.isEmpty else { return [] }
        let pinned = active
            .filter { $0.pinned == true }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
        let pinnedIDs = Set(pinned.map(\.id))
        let remaining = active.filter { !pinnedIDs.contains($0.id) }
        let scored = remaining.map { fact -> (MemoryFactRecord, Double) in
            let overlap = incoming
                .map { MemoryLexical.jaccard(fact.text, $0.text) }
                .max() ?? 0
            let importance = fact.importance ?? MemoryScoring.defaultImportance(for: fact.kind)
            let recency = MemoryScoring.recency(
                createdAt: fact.createdAt,
                lastAccessAt: fact.lastAccessAt,
                halfLifeDays: 30,
                now: now
            )
            return (fact, 0.7 * overlap + 0.2 * importance + 0.1 * recency)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(max(0, limit - pinned.count))
        .map(\.0)
        return Array(pinned) + scored
    }

    public static func apply(
        _ operations: [MemoryConsolidationOperation],
        existing: [MemoryFactRecord],
        incoming: [MemoryFactRecord],
        now: Date = Date()
    ) -> [MemoryFactRecord] {
        var facts = existing
        var usedNewIndexes = Set<Int>()

        for operation in operations {
            switch operation.action {
            case .add:
                guard let fact = makeFact(
                    base: nil,
                    incoming: incoming,
                    indexes: operation.newIndexes,
                    text: operation.text,
                    now: now
                ) else { continue }
                facts.append(fact)
                usedNewIndexes.formUnion(operation.newIndexes)

            case .update:
                guard let id = operation.existingID,
                      let index = facts.firstIndex(where: { $0.id == id }),
                      facts[index].isDeleted != true,
                      facts[index].archived != true else { continue }
                guard let fact = makeFact(
                    base: facts[index],
                    incoming: incoming,
                    indexes: operation.newIndexes,
                    text: operation.text,
                    now: now
                ) else { continue }
                facts[index] = fact
                usedNewIndexes.formUnion(operation.newIndexes)

            case .delete:
                guard let id = operation.existingID,
                      let index = facts.firstIndex(where: { $0.id == id }),
                      facts[index].isDeleted != true,
                      facts[index].archived != true else { continue }
                // Pinned facts are user-intentional and are never auto-deleted.
                guard facts[index].pinned != true else { continue }
                facts[index].isDeleted = true
                facts[index].deletedAt = now
                facts[index].updatedAt = now

            case .noop:
                usedNewIndexes.formUnion(operation.newIndexes)
            }
        }

        // Every new fact must be accounted for. If the model omitted one, add it
        // instead of silently dropping information.
        var unaccounted: [MemoryFactKind: [Int]] = [:]
        for index in incoming.indices where !usedNewIndexes.contains(index) {
            unaccounted[incoming[index].kind, default: []].append(index)
        }
        for indexes in unaccounted.values {
            if let fact = makeFact(base: nil, incoming: incoming, indexes: indexes, text: nil, now: now) {
                facts.append(fact)
            }
        }

        return capped(facts)
    }

    private static func makeFact(
        base: MemoryFactRecord?,
        incoming: [MemoryFactRecord],
        indexes: [Int],
        text: String?,
        now: Date
    ) -> MemoryFactRecord? {
        let selected = indexes.compactMap { index -> MemoryFactRecord? in
            incoming.indices.contains(index) ? incoming[index] : nil
        }
        guard base != nil || !selected.isEmpty else { return nil }

        let kind = base?.kind ?? selected.first?.kind ?? .fact
        let override = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseText = base?.text ?? ""
        let incomingText = selected
            .max(by: { $0.text.count < $1.text.count })?
            .text ?? ""

        let mergedText: String
        if let override, !override.isEmpty {
            mergedText = String(override.prefix(1_000))
        } else if incomingText.count > max(24, baseText.count) {
            mergedText = String(incomingText.prefix(1_000))
        } else if !baseText.isEmpty {
            mergedText = baseText
        } else {
            mergedText = String(incomingText.prefix(1_000))
        }
        guard !mergedText.isEmpty else { return nil }

        var sources = base?.sourceMessageIDs ?? []
        for fact in selected { sources.append(contentsOf: fact.sourceMessageIDs) }
        var seen = Set<UUID>()
        sources = sources.filter { seen.insert($0).inserted }

        let createdAt = base?.createdAt
            ?? selected.map(\.createdAt).min()
            ?? now
        let confidence = max(
            base?.confidence ?? 0,
            selected.map(\.confidence).max() ?? 0
        )
        let importance = max(
            base?.importance ?? MemoryScoring.defaultImportance(for: base?.kind ?? kind),
            selected.map { $0.importance ?? MemoryScoring.defaultImportance(for: $0.kind) }.max() ?? 0
        )
        let pinned: Bool? = (base?.pinned == true || selected.contains(where: { $0.pinned == true }))
            ? true
            : base?.pinned

        // Preserve an existing vector only when the text did not change.
        let vector: [Double]?
        if let base, mergedText == base.text {
            vector = base.vector
        } else if let match = selected.first(where: { $0.text == mergedText }) {
            vector = match.vector
        } else {
            vector = nil
        }

        return MemoryFactRecord(
            id: base?.id ?? UUID(),
            kind: kind,
            text: mergedText,
            sourceMessageIDs: sources,
            createdAt: createdAt,
            confidence: confidence,
            pinned: pinned,
            importance: importance,
            accessCount: max(base?.accessCount ?? 0, selected.map { $0.accessCount ?? 0 }.max() ?? 0),
            lastAccessAt: [base?.lastAccessAt, selected.compactMap(\.lastAccessAt).max()]
                .compactMap { $0 }
                .max(),
            stability: max(base?.stability ?? 0, selected.map { $0.stability ?? 0 }.max() ?? 0),
            updatedAt: now,
            isDeleted: nil,
            deletedAt: nil,
            vector: vector
        )
    }

    private static func capped(_ facts: [MemoryFactRecord]) -> [MemoryFactRecord] {
        let active = facts.filter { $0.isDeleted != true && $0.archived != true }
        guard active.count > 200 else { return facts }
        let pinned = active.filter { $0.pinned == true }
        let remaining = active
            .filter { $0.pinned != true }
            .sorted {
                let left = $0.importance ?? MemoryScoring.defaultImportance(for: $0.kind)
                let right = $1.importance ?? MemoryScoring.defaultImportance(for: $1.kind)
                if left != right { return left > right }
                return $0.createdAt > $1.createdAt
            }
        let keep = Set((pinned + remaining.prefix(max(0, 200 - pinned.count))).map(\.id))
        return facts.map { fact in
            if fact.isDeleted == true || fact.archived == true || keep.contains(fact.id) {
                return fact
            }
            var archived = fact
            archived.archived = true
            return archived
        }
    }
}

public enum MemoryConsolidationParser {
    public static func parse(
        _ raw: String,
        existingIDs: Set<UUID>,
        incomingCount: Int
    ) throws -> [MemoryConsolidationOperation] {
        var content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```") {
            guard let newline = content.firstIndex(of: "\n") else {
                throw MemoryConsolidationError.invalid("缺少 JSON 正文")
            }
            content = String(content[content.index(after: newline)...])
            if content.hasSuffix("```") { content = String(content.dropLast(3)) }
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let object: [String: Any]
        if let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end {
            guard let decoded = try? JSONSerialization.jsonObject(with: Data(content[start...end].utf8)) as? [String: Any] else {
                throw MemoryConsolidationError.invalid("JSON 无法解析")
            }
            object = decoded
        } else {
            throw MemoryConsolidationError.invalid("缺少 JSON 对象")
        }
        guard let rows = object["operations"] as? [[String: Any]] else {
            throw MemoryConsolidationError.invalid("缺少 operations")
        }
        guard rows.count <= 20 else {
            throw MemoryConsolidationError.invalid("操作超过 20 条")
        }

        var usedNew = Set<Int>()
        var usedExisting = Set<UUID>()
        var result: [MemoryConsolidationOperation] = []

        for row in rows {
            guard let rawAction = row["op"] as? String,
                  let action = MemoryOperationAction(rawValue: rawAction.lowercased()) else {
                throw MemoryConsolidationError.invalid("未知操作")
            }
            let indexes = (row["newIndexes"] as? [Int]) ?? []
            guard Set(indexes).count == indexes.count else {
                throw MemoryConsolidationError.invalid("重复的新事实索引")
            }
            for index in indexes {
                guard index >= 0, index < incomingCount else {
                    throw MemoryConsolidationError.invalid("新事实索引越界")
                }
                guard usedNew.insert(index).inserted else {
                    throw MemoryConsolidationError.invalid("新事实索引被重复使用")
                }
            }

            let text = (row["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let text, text.count > 1_000 {
                throw MemoryConsolidationError.invalid("合并文本过长")
            }

            var existingID: UUID?
            if action != .add {
                guard let rawID = row["existingId"] as? String,
                      let id = UUID(uuidString: rawID),
                      existingIDs.contains(id) else {
                    throw MemoryConsolidationError.invalid("existingId 不在候选列表")
                }
                guard usedExisting.insert(id).inserted else {
                    throw MemoryConsolidationError.invalid("同一事实被重复操作")
                }
                existingID = id
            }

            switch action {
            case .add:
                guard !indexes.isEmpty else {
                    throw MemoryConsolidationError.invalid("ADD 缺少 newIndexes")
                }
            case .update:
                guard !indexes.isEmpty || !(text ?? "").isEmpty else {
                    throw MemoryConsolidationError.invalid("UPDATE 缺少内容")
                }
            case .delete:
                guard indexes.isEmpty else {
                    throw MemoryConsolidationError.invalid("DELETE 不应带 newIndexes")
                }
            case .noop:
                break
            }

            result.append(MemoryConsolidationOperation(
                action: action,
                existingID: existingID,
                newIndexes: indexes,
                text: (text?.isEmpty == false) ? text : nil
            ))
        }
        return result
    }
}
