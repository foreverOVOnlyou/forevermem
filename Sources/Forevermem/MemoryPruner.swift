import Foundation

/// Capacity control for long-term memory. Low-strength records are archived
/// instead of hard-deleted, so they disappear from prompts but remain available
/// for diagnostics/export later.
public enum MemoryPruner {
    public static let maximumFacts = 200
    public static let maximumCapsules = 150
    public static let maximumSummaries = 150
    public static let maximumArchivedFacts = 300
    public static let maximumArchivedCapsules = 200
    public static let maximumArchivedSummaries = 200

    public static func prune(_ memory: inout ConversationMemory, now: Date = Date()) {
        pruneFacts(&memory, now: now)
        pruneCapsules(&memory, now: now)
        pruneSummaries(&memory, now: now)
        trimArchivedFacts(&memory)
        trimArchivedCapsules(&memory)
        trimArchivedSummaries(&memory)
    }

    private static func pruneFacts(_ memory: inout ConversationMemory, now: Date) {
        guard var facts = memory.facts else { return }
        let active = facts.indices.filter {
            facts[$0].isDeleted != true && facts[$0].archived != true
        }
        guard active.count > maximumFacts else { return }

        let pinned = active.filter { facts[$0].pinned == true }
        let others = active
            .filter { facts[$0].pinned != true }
            .sorted { left, right in
                strength(facts[left], now: now) > strength(facts[right], now: now)
            }
        let keepCount = max(0, maximumFacts - pinned.count)
        let keep = Set((pinned + others.prefix(keepCount)).map { facts[$0].id })
        for index in active where !keep.contains(facts[index].id) {
            facts[index].archived = true
        }
        memory.facts = facts
    }

    private static func pruneCapsules(_ memory: inout ConversationMemory, now: Date) {
        let active = memory.capsules.indices.filter { memory.capsules[$0].archived != true }
        guard active.count > maximumCapsules else { return }
        let keep = Set(active.sorted {
            strength(memory.capsules[$0], now: now) > strength(memory.capsules[$1], now: now)
        }.prefix(maximumCapsules).map { memory.capsules[$0].id })
        for index in active where !keep.contains(memory.capsules[index].id) {
            memory.capsules[index].archived = true
        }
    }

    private static func pruneSummaries(_ memory: inout ConversationMemory, now: Date) {
        guard var summaries = memory.daySummaries else { return }
        let active = summaries.indices.filter { summaries[$0].archived != true }
        guard active.count > maximumSummaries else { return }
        let keep = Set(active.sorted {
            strength(summaries[$0], now: now) > strength(summaries[$1], now: now)
        }.prefix(maximumSummaries).map { summaries[$0].id })
        for index in active where !keep.contains(summaries[index].id) {
            summaries[index].archived = true
        }
        memory.daySummaries = summaries
    }

    private static func trimArchivedFacts(_ memory: inout ConversationMemory) {
        guard var facts = memory.facts else { return }
        let archived = facts.indices.filter { facts[$0].archived == true }
        guard archived.count > maximumArchivedFacts else { return }
        let removeIDs = Set(
            archived
                .sorted { facts[$0].createdAt < facts[$1].createdAt }
                .prefix(archived.count - maximumArchivedFacts)
                .map { facts[$0].id }
        )
        facts.removeAll { removeIDs.contains($0.id) }
        memory.facts = facts
    }

    private static func trimArchivedCapsules(_ memory: inout ConversationMemory) {
        let archived = memory.capsules.indices.filter { memory.capsules[$0].archived == true }
        guard archived.count > maximumArchivedCapsules else { return }
        let removeIDs = Set(
            archived
                .sorted { memory.capsules[$0].endAt < memory.capsules[$1].endAt }
                .prefix(archived.count - maximumArchivedCapsules)
                .map { memory.capsules[$0].id }
        )
        memory.capsules.removeAll { removeIDs.contains($0.id) }
    }

    private static func trimArchivedSummaries(_ memory: inout ConversationMemory) {
        guard var summaries = memory.daySummaries else { return }
        let archived = summaries.indices.filter { summaries[$0].archived == true }
        guard archived.count > maximumArchivedSummaries else { return }
        let removeIDs = Set(
            archived
                .sorted {
                    (summaries[$0].createdAt ?? .distantPast) < (summaries[$1].createdAt ?? .distantPast)
                }
                .prefix(archived.count - maximumArchivedSummaries)
                .map { summaries[$0].id }
        )
        summaries.removeAll { removeIDs.contains($0.id) }
        memory.daySummaries = summaries
    }

    private static func strength(_ fact: MemoryFactRecord, now: Date) -> Double {
        MemoryScoring.strength(
            createdAt: fact.createdAt,
            lastAccessAt: fact.lastAccessAt,
            accessCount: fact.accessCount ?? 0,
            importance: fact.importance ?? MemoryScoring.defaultImportance(for: fact.kind),
            now: now
        )
    }

    private static func strength(_ capsule: MemoryCapsule, now: Date) -> Double {
        MemoryScoring.strength(
            createdAt: capsule.endAt,
            lastAccessAt: capsule.lastAccessAt,
            accessCount: capsule.accessCount ?? 0,
            importance: capsule.importance ?? 0.5,
            now: now
        )
    }

    private static func strength(_ summary: MemoryDaySummary, now: Date) -> Double {
        MemoryScoring.strength(
            createdAt: summary.createdAt ?? summary.lastAccessAt ?? .distantPast,
            lastAccessAt: summary.lastAccessAt,
            accessCount: summary.accessCount ?? 0,
            importance: summary.importance ?? 0.6,
            now: now
        )
    }
}
