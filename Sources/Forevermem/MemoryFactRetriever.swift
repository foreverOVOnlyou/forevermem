import Foundation

/// Pure fact ranking used by CompanionMemory and the retrieval baseline tests.
public enum MemoryFactRetriever {
    public static func select(
        _ facts: [MemoryFactRecord],
        query: String,
        queryVector: [Double]? = nil,
        vectorThreshold: Double = 0.62,
        now: Date = Date()
    ) -> [MemoryFactRecord] {
        let active = facts.filter { $0.isDeleted != true && $0.archived != true }
        guard !active.isEmpty else { return [] }

        let pinned = Array(
            active
                .filter { $0.pinned == true }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(4)
        )
        let pinnedIDs = Set(pinned.map(\.id))
        let candidates = active.filter { !pinnedIDs.contains($0.id) }

        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ranked = candidates
                .map { fact -> (MemoryFactRecord, Double) in
                    let score = MemoryScoring.retrievalScore(
                        relevance: 0,
                        createdAt: fact.createdAt,
                        lastAccessAt: fact.lastAccessAt,
                        accessCount: fact.accessCount ?? 0,
                        importance: fact.importance ?? MemoryScoring.defaultImportance(for: fact.kind),
                        confidence: fact.confidence,
                        halfLifeDays: 30,
                        now: now
                    )
                    return (fact, score)
                }
                .sorted {
                    if $0.1 != $1.1 { return $0.1 > $1.1 }
                    return $0.0.createdAt > $1.0.createdAt
                }
                .prefix(max(0, 4 - pinned.count))
                .map(\.0)
            return pinned + Array(ranked)
        }

        let ranked = candidates
            .compactMap { fact -> (MemoryFactRecord, Double)? in
                var relevance = MemoryLexical.relevance(fact.text, query: query)
                if let queryVector,
                   let vector = fact.vector,
                   vector.count == queryVector.count {
                    let similarity = cosine(queryVector, vector)
                    if similarity >= vectorThreshold {
                        relevance = max(relevance, similarity)
                    }
                }
                guard relevance >= 0.12 else { return nil }
                let score = MemoryScoring.retrievalScore(
                    relevance: relevance,
                    createdAt: fact.createdAt,
                    lastAccessAt: fact.lastAccessAt,
                    accessCount: fact.accessCount ?? 0,
                    importance: fact.importance ?? MemoryScoring.defaultImportance(for: fact.kind),
                    confidence: fact.confidence,
                    halfLifeDays: 30,
                    now: now
                )
                return (fact, score)
            }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.createdAt > $1.0.createdAt
            }
            .prefix(2)
            .map(\.0)
        return pinned + Array(ranked)
    }

    private static func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return -1 }
        var dot = 0.0, left = 0.0, right = 0.0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            left += lhs[index] * lhs[index]
            right += rhs[index] * rhs[index]
        }
        let denominator = (left.squareRoot() * right.squareRoot())
        return denominator > 0 ? dot / denominator : -1
    }
}
