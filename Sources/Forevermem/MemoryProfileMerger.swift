import Foundation

/// Incremental profile merge. The model returns only changed/new stable items;
/// existing items that are not mentioned survive, which prevents the
/// "full rewrite" drift where an old preference disappears after one segment.
public enum MemoryProfileMerger {
    public static func merge(
        existing: MemoryProfile?,
        incoming: [ExtractedProfileItem],
        now: Date = Date(),
        maxItems: Int = 30
    ) -> MemoryProfile? {
        guard existing != nil || !incoming.isEmpty else { return nil }

        let existingItems = existing?.items ?? []
        var items = existingItems.isEmpty ? seedItems(from: existing, now: now) : existingItems
        for incomingItem in incoming {
            let text = incomingItem.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let bounded = String(text.prefix(300))

            if let index = items.firstIndex(where: {
                $0.kind == incomingItem.kind && similarity($0.text, bounded) >= 0.6
            }) {
                var item = items[index]
                if bounded.count > item.text.count { item.text = bounded }
                item.sourceMessageIDs = union(item.sourceMessageIDs, incomingItem.sourceMessageIDs)
                item.confidence = max(item.confidence, incomingItem.confidence)
                item.updatedAt = now
                items[index] = item
            } else if let index = items.firstIndex(where: {
                similarity($0.text, bounded) >= 0.85
            }) {
                // Same statement under a different label: keep the stronger kind
                // only when the new item is more specific.
                var item = items[index]
                if item.kind == .other && incomingItem.kind != .other {
                    item.kind = incomingItem.kind
                }
                if bounded.count > item.text.count { item.text = bounded }
                item.sourceMessageIDs = union(item.sourceMessageIDs, incomingItem.sourceMessageIDs)
                item.confidence = max(item.confidence, incomingItem.confidence)
                item.updatedAt = now
                items[index] = item
            } else {
                items.append(
                    MemoryProfileItem(
                        id: UUID(),
                        kind: incomingItem.kind,
                        text: bounded,
                        sourceMessageIDs: incomingItem.sourceMessageIDs,
                        confidence: incomingItem.confidence,
                        updatedAt: now
                    )
                )
            }
        }

        if items.count > maxItems {
            items = Array(items
                .sorted {
                    if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                    return $0.confidence > $1.confidence
                }
                .prefix(maxItems))
        }
        guard !items.isEmpty else { return existing }

        let globalSources = union(
            existing?.sourceMessageIDs ?? [],
            items.flatMap(\.sourceMessageIDs)
        )
        let confidence = max(existing?.confidence ?? 0, items.map(\.confidence).max() ?? 0)
        return MemoryProfile(
            text: String(items.map(\.text).joined(separator: "\n").prefix(1_200)),
            sourceMessageIDs: globalSources,
            updatedAt: now,
            confidence: confidence,
            items: items
        )
    }

    private static func seedItems(from profile: MemoryProfile?, now: Date) -> [MemoryProfileItem] {
        guard let profile else { return [] }
        let pieces = profile.text
            .components(separatedBy: CharacterSet(charactersIn: "\n；;。"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let texts = pieces.isEmpty ? [profile.text] : pieces
        return texts.prefix(12).map { text in
            MemoryProfileItem(
                id: UUID(),
                kind: .other,
                text: String(text.prefix(300)),
                sourceMessageIDs: profile.sourceMessageIDs,
                confidence: profile.confidence,
                updatedAt: profile.updatedAt
            )
        }
    }

    private static func union(_ left: [UUID], _ right: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return (left + right).filter { seen.insert($0).inserted }
    }

    private static func similarity(_ left: String, _ right: String) -> Double {
        let jaccard = MemoryLexical.jaccard(left, right)
        if left.contains(right) || right.contains(left) { return max(jaccard, 0.9) }
        return jaccard
    }
}
