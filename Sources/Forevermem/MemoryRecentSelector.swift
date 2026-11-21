/// Keeps recent originals inside a hard character budget. Memory blocks get
/// totalCharacters - recentCharacters, so recent chat can never crowd out the
/// long-term memory layers.
public enum MemoryRecentSelector {
    public static func select(_ messages: [MemoryMessage], characterBudget: Int) -> [MemoryMessage] {
        guard characterBudget > 0 else { return [] }
        var selected: [MemoryMessage] = []
        var remaining = characterBudget
        for message in messages.reversed() {
            guard remaining > 0 else { break }
            if message.content.count <= remaining {
                selected.append(message)
                remaining -= message.content.count
            } else {
                selected.append(
                    MemoryMessage(
                        id: message.id,
                        role: message.role,
                        content: String(message.content.prefix(remaining)),
                        createdAt: message.createdAt
                    )
                )
                remaining = 0
            }
        }
        return selected.reversed()
    }
}
