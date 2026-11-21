import XCTest
@testable import Foreverloom

final class ForeverloomTests: XCTestCase {
    func testScoringHalfLife() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let day: TimeInterval = 86_400
        let half = MemoryScoring.recency(
            createdAt: base,
            lastAccessAt: nil,
            halfLifeDays: 10,
            now: base.addingTimeInterval(10 * day)
        )
        XCTAssertEqual(half, 0.5, accuracy: 0.0001)
        XCTAssertGreaterThan(
            MemoryScoring.stabilityDays(importance: 0.9, accessCount: 0),
            MemoryScoring.stabilityDays(importance: 0.2, accessCount: 0)
        )
    }

    func testSegmentation() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let messages = (0..<12).map { index in
            MemoryMessage(
                id: UUID(),
                role: index.isMultiple(of: 2) ? "user" : "assistant",
                content: index < 6
                    ? "海边天气很好，记得带外套 \(index)"
                    : "今天开会讨论项目排期 \(index)",
                createdAt: base.addingTimeInterval(Double(index) * 60)
            )
        }
        let segments = MemorySegmenter.segments(messages)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].count, 6)
        XCTAssertEqual(segments[1].count, 6)
    }

    func testStoreRoundTripAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForeverloomTests-\(UUID().uuidString)", isDirectory: true)
        let suite = "ForeverloomTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let id = UUID()
        let store = FileMemoryStore(directory: directory, defaults: defaults)
        var document = MemoryDocument()
        document.facts = [
            MemoryFactRecord(
                id: UUID(),
                kind: .preference,
                text: "喜欢海边",
                sourceMessageIDs: [UUID()],
                createdAt: Date(),
                confidence: 0.8
            )
        ]
        store.save(document, conversationID: id)
        XCTAssertEqual(store.load(conversationID: id).facts?.first?.text, "喜欢海边")
        store.delete(conversationID: id)
        XCTAssertTrue(store.load(conversationID: id).facts?.isEmpty ?? true)
    }

    private func emptyDependencies() -> MemoryEngineDependencies {
        MemoryEngineDependencies(
            complete: { _, _, _, _ in "{}" },
            embed: { _ in throw NSError(domain: "test", code: 1) },
            recordTrace: { _ in },
            profilePolicy: { .off },
            vectorThreshold: { 0.62 },
            fallbackMessages: { _ in [] }
        )
    }

    func testEngineSummaryAndContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForeverloomEngineFlow-\(UUID().uuidString)", isDirectory: true)
        let store = FileMemoryStore(directory: directory)
        let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let conversationID = UUID()
        var messages: [MemoryMessage] = []
        for index in 0..<12 {
            let isSea = index < 6
            let content = isSea
                ? "我们约好周末去海边，记得带外套 \(index)"
                : "今天开会讨论项目排期 \(index)"
            let offset = isSea
                ? Double(index) * 60
                : 120 * 60 + Double(index) * 60
            messages.append(
                MemoryMessage(
                    id: UUID(),
                    role: index.isMultiple(of: 2) ? "user" : "assistant",
                    content: content,
                    createdAt: base.addingTimeInterval(offset)
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
            embed: { _ in throw NSError(domain: "test", code: 1) },
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
        XCTAssertEqual(snapshot.daySummaries?.count, 1)
        XCTAssertEqual(snapshot.facts?.first?.text, "用户和角色约好周末去海边")

        let context = await engine.buildContext(
            conversationID: conversationID,
            messages: messages,
            currentText: "海边"
        )
        let joined = context.compactMap { $0["content"] }.joined(separator: "\n")
        XCTAssertTrue(joined.contains("海边"))
    }

    func testEngineSnapshot() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForeverloomEngine-\(UUID().uuidString)", isDirectory: true)
        let store = FileMemoryStore(directory: directory)
        let engine = MemoryEngine(store: store, dependencies: emptyDependencies())
        let id = UUID()
        let snapshot = await engine.snapshot(conversationID: id)
        XCTAssertTrue(snapshot.facts?.isEmpty ?? true)
    }
}
