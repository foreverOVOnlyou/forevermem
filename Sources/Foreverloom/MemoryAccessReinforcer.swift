import Foundation

/// MemoryBank-style access reinforcement, separated from CompanionMemory so it
/// can be tested and applied in batches when a memory document is finally saved.
public enum MemoryAccessReinforcer {
    @discardableResult
    public static func apply(
        to memory: inout ConversationMemory,
        factIDs: Set<UUID>,
        capsuleIDs: Set<UUID>,
        summaryIDs: Set<UUID>,
        now: Date = Date()
    ) -> Bool {
        var changed = false

        if let facts = memory.facts, !factIDs.isEmpty {
            var updated = facts
            for index in updated.indices where factIDs.contains(updated[index].id) {
                guard updated[index].isDeleted != true, updated[index].archived != true else { continue }
                let importance = updated[index].importance
                    ?? MemoryScoring.defaultImportance(for: updated[index].kind)
                let access = (updated[index].accessCount ?? 0) + 1
                updated[index].accessCount = access
                updated[index].lastAccessAt = now
                updated[index].stability = max(
                    updated[index].stability ?? 0,
                    MemoryScoring.stabilityDays(importance: importance, accessCount: access)
                )
                changed = true
            }
            memory.facts = updated
        }

        if !capsuleIDs.isEmpty {
            for index in memory.capsules.indices where capsuleIDs.contains(memory.capsules[index].id) {
                guard memory.capsules[index].archived != true else { continue }
                let importance = memory.capsules[index].importance ?? 0.5
                let access = (memory.capsules[index].accessCount ?? 0) + 1
                memory.capsules[index].accessCount = access
                memory.capsules[index].lastAccessAt = now
                memory.capsules[index].stability = max(
                    memory.capsules[index].stability ?? 0,
                    MemoryScoring.stabilityDays(importance: importance, accessCount: access)
                )
                changed = true
            }
        }

        if let summaries = memory.daySummaries, !summaryIDs.isEmpty {
            var updated = summaries
            for index in updated.indices where summaryIDs.contains(updated[index].id) {
                guard updated[index].archived != true else { continue }
                let importance = updated[index].importance ?? 0.6
                let access = (updated[index].accessCount ?? 0) + 1
                updated[index].accessCount = access
                updated[index].lastAccessAt = now
                updated[index].stability = max(
                    updated[index].stability ?? 0,
                    MemoryScoring.stabilityDays(importance: importance, accessCount: access)
                )
                changed = true
            }
            memory.daySummaries = updated
        }
        return changed
    }
}
