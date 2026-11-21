import Foundation
import Forevermem

@main
struct ForevermemCLI {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForevermemCLI-\(UUID().uuidString)", isDirectory: true)
        let store = FileMemoryStore(directory: directory)
        let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let conversationID = UUID()

        var messages: [MemoryMessage] = []
        for index in 0..<12 {
            let sea = index < 6
            messages.append(
                MemoryMessage(
                    id: UUID(),
                    role: index.isMultiple(of: 2) ? "user" : "assistant",
                    content: sea
                        ? "我们约好周末去海边，记得带外套 \(index)"
                        : "今天开会讨论项目排期 \(index)",
                    createdAt: base.addingTimeInterval(
                        sea ? Double(index) * 60 : 120 * 60 + Double(index) * 60
                    )
                )
            )
        }

        let dependencies = MemoryEngineDependencies(
            complete: { task, _, _, _ in
                if task == .segment {
                    return #"{"summary":"他们约好周末去海边。","facts":[{"kind":"promise","text":"用户和角色约好周末去海边","sourceIndexes":[0,1],"confidence":0.9}],"importance":0.8}"#
                }
                return #"{"operations":[]}"#
            },
            embed: { _ in throw NSError(domain: "ForevermemCLI", code: 1) },
            recordTrace: { _ in },
            profilePolicy: { .everySegment },
            vectorThreshold: { 0.62 },
            fallbackMessages: { _ in [] }
        )
        let engine = MemoryEngine(store: store, dependencies: dependencies)
        await engine.summarizeCompletedSegmentIfNeeded(
            conversationID: conversationID,
            messages: messages,
            contactName: "林"
        )
        let snapshot = await engine.snapshot(conversationID: conversationID)
        print("facts=\(snapshot.facts?.count ?? 0) summaries=\(snapshot.daySummaries?.count ?? 0)")

        let context = await engine.buildContext(
            conversationID: conversationID,
            messages: messages,
            currentText: "海边"
        )
        for row in context {
            print("[\(row["role"] ?? "?")] \(row["content"]?.prefix(120) ?? "")")
        }
        try? FileManager.default.removeItem(at: directory)
    }
}
