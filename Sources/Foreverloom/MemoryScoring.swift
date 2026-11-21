import Foundation

/// Local-only scoring for long-term memory recall.
///
/// Lineage:
/// - Generative Agents: relevance + recency + importance
/// - MemoryBank: Ebbinghaus-style decay / reinforcement on access
///
/// Everything here is pure math on already-persisted fields, so it adds zero
/// model calls and can be unit-tested without UIKit or the chat API.
public enum MemoryScoring {
    public static func dayCount(_ interval: TimeInterval) -> Double {
        max(0, interval / 86_400)
    }

    /// Exponential recency. A memory last touched today is 1.0; after one
    /// half-life it is 0.5.
    public static func recency(
        createdAt: Date,
        lastAccessAt: Date?,
        halfLifeDays: Double,
        now: Date = Date()
    ) -> Double {
        guard halfLifeDays > 0 else { return 0 }
        let age = dayCount(now.timeIntervalSince(lastAccessAt ?? createdAt))
        // Proper half-life: one halfLifeDays of age yields exactly 0.5.
        return exp(-log(2) * age / halfLifeDays)
    }

    /// Base retention window grows with importance and repeated access.
    public static func stabilityDays(importance: Double, accessCount: Int) -> Double {
        let importance = min(1, max(0, importance))
        let access = min(10, max(0, accessCount))
        return 3 + 24 * importance + Double(access) * 2
    }

    /// Ebbinghaus-style strength. Used for eviction/archival later; kept
    /// separate from the retrieval score so both can be tuned independently.
    public static func strength(
        createdAt: Date,
        lastAccessAt: Date?,
        accessCount: Int,
        importance: Double,
        now: Date = Date()
    ) -> Double {
        let age = dayCount(now.timeIntervalSince(lastAccessAt ?? createdAt))
        let stability = stabilityDays(importance: importance, accessCount: accessCount)
        return exp(-age / stability)
    }

    /// Retrieval score. Weights sum to 1.0 so scores stay comparable.
    public static func retrievalScore(
        relevance: Double,
        createdAt: Date,
        lastAccessAt: Date?,
        accessCount: Int,
        importance: Double,
        confidence: Double,
        halfLifeDays: Double,
        now: Date = Date()
    ) -> Double {
        let relevance = min(1, max(0, relevance))
        let importance = min(1, max(0, importance))
        let confidence = min(1, max(0, confidence))
        let frequency = min(1, log1p(Double(max(0, accessCount))) / log(11))
        let recency = recency(
            createdAt: createdAt,
            lastAccessAt: lastAccessAt,
            halfLifeDays: halfLifeDays,
            now: now
        )
        return 0.45 * relevance
            + 0.20 * recency
            + 0.15 * importance
            + 0.10 * confidence
            + 0.10 * frequency
    }

    /// Default importance by fact kind when the writer did not assign one.
    public static func defaultImportance(for kind: MemoryFactKind) -> Double {
        switch kind {
        case .promise, .relationship: 0.8
        case .preference: 0.65
        case .event: 0.6
        case .fact: 0.55
        }
    }
}
