import Foundation

public struct MemorySegmenterConfiguration: Sendable {
    public var minimumMessages = 6
    public var maximumMessages = 30
    public var timeGap: TimeInterval = 45 * 60
    public var windowSize = 4
    public var lookaheadMessages = 3
    public var similarityThreshold = 0.06

    public static let `default` = MemorySegmenterConfiguration()

    public init() {}
}

public enum MemorySegmenter {
    public static func segments(
        _ messages: [MemoryMessage],
        configuration: MemorySegmenterConfiguration = .default
    ) -> [[MemoryMessage]] {
        guard !messages.isEmpty else { return [] }
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        let minimum = max(1, configuration.minimumMessages)
        let maximum = max(minimum, configuration.maximumMessages)
        let window = max(1, configuration.windowSize)

        var raw: [[MemoryMessage]] = []
        var current: [MemoryMessage] = []

        for index in sorted.indices {
            let message = sorted[index]
            if let previous = current.last {
                var cut = message.createdAt.timeIntervalSince(previous.createdAt) >= configuration.timeGap

                if current.count >= maximum {
                    cut = true
                } else if !cut, current.count >= minimum, index + window <= sorted.count {
                    let previousText = current.suffix(window).map(\.content).joined(separator: "\n")
                    let lastCandidate = min(
                        max(index, sorted.count - window),
                        index + max(0, configuration.lookaheadMessages - 1)
                    )
                    var bestIndex = index
                    var bestSimilarity = Double.infinity
                    if index <= lastCandidate {
                        for candidate in index...lastCandidate {
                            let nextText = sorted[candidate..<(candidate + window)]
                                .map(\.content)
                                .joined(separator: "\n")
                            let similarity = MemoryLexical.jaccard(previousText, nextText)
                            if similarity < bestSimilarity {
                                bestSimilarity = similarity
                                bestIndex = candidate
                            }
                        }
                    }
                    cut = bestIndex == index && bestSimilarity < configuration.similarityThreshold
                }

                if cut {
                    raw.append(current)
                    current = []
                }
            }
            current.append(message)
        }
        if !current.isEmpty { raw.append(current) }

        var result = raw
        var index = 0
        while result.count > 1, index < result.count {
            if result[index].count < minimum {
                if index > 0 {
                    result[index - 1].append(contentsOf: result[index])
                    result.remove(at: index)
                    index = max(0, index - 1)
                } else {
                    result[1].insert(contentsOf: result[0], at: 0)
                    result.remove(at: 0)
                    index = 0
                }
            } else {
                index += 1
            }
        }
        return result
    }
}
