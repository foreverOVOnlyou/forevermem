import Foundation

public struct MemoryPrompt: Sendable {
    public let system: String
    public let user: String
    public let timeout: TimeInterval

    public init(system: String, user: String, timeout: TimeInterval) {
        self.system = system
        self.user = user
        self.timeout = timeout
    }
}

public protocol MemoryPromptProvider: Sendable {
    func segment(transcript: String, profileContext: String?) -> MemoryPrompt
    func consolidation(existing: [MemoryFactRecord], incoming: [MemoryFactRecord]) -> MemoryPrompt
}

public struct DefaultMemoryPrompts: MemoryPromptProvider {
    public init() {}

    public func segment(transcript: String, profileContext: String?) -> MemoryPrompt {
        MemoryPrompts.segment(transcript: transcript, profileContext: profileContext)
    }

    public func consolidation(existing: [MemoryFactRecord], incoming: [MemoryFactRecord]) -> MemoryPrompt {
        MemoryPrompts.consolidation(existing: existing, incoming: incoming)
    }
}

enum MemoryPrompts {
    static func segment(transcript: String, profileContext: String?) -> MemoryPrompt {
        let profileInstruction: String
        if let profileContext {
            let current = profileContext.trimmingCharacters(in: .whitespacesAndNewlines)
            profileInstruction = """
            当前人物画像（可为空）：
            \(current.isEmpty ? "（无）" : current)

            如果本段出现稳定的人物画像、偏好、关系状态或明确变化，在 JSON 增加 profile.items：
            "profile":{"changed":true,"items":[{"kind":"identity|preference|relationship|boundary|other","text":"一条稳定的画像条目","sourceIndexes":[0,1],"confidence":0.8}]}
            只返回本段新增或需要修正的稳定条目，不要复述全部旧画像；旧条目会自动保留。没有稳定变化时不要返回 profile（或 changed=false）。
            profile 只能引用本段真实消息，不能编造。每条不超过300字，最多8条。
            """
        } else {
            profileInstruction = "本轮不要返回 profile 字段。"
        }

        return MemoryPrompt(
            system: "你是记忆索引整理器。总结必须忠于原文，不续写、不推测、不写角色心声。只返回JSON，不要Markdown。",
            user: """
            把下方对话整理成两件事：summary 是忠实的时间段总结；facts 是少量可长期使用的事实、偏好、承诺、关系变化或明确事件。先去掉寒暄、重复、工具提示和无信息量的语气词，只保留有内容的部分。
            每行对话前的数字是 sourceIndexes。facts 只能引用真实发生过的内容，不确定就不提取；普通寒暄不要提取。最多8条事实。
            同时给这一段一个 importance（0到1，剧情冲突、承诺、关系变化越高；日常闲聊越低）。
            \(profileInstruction)
            {"summary":"时间段总结","facts":[{"kind":"event|preference|promise|relationship|fact","text":"简短忠实的事实","sourceIndexes":[0,1],"confidence":0.8}],"importance":0.6}
            <原始对话>
            \(transcript)
            </原始对话>
            """,
            timeout: 90
        )
    }

    static func consolidation(existing: [MemoryFactRecord], incoming: [MemoryFactRecord]) -> MemoryPrompt {
        let existingLines = existing.enumerated().map { index, fact in
            "[E\(index + 1)] id=\(fact.id.uuidString) kind=\(fact.kind.rawValue) pinned=\(fact.pinned == true ? "yes" : "no") text=\(String(fact.text.prefix(500)))"
        }.joined(separator: "\n")
        let incomingLines = incoming.enumerated().map { index, fact in
            "[\(index)] kind=\(fact.kind.rawValue) confidence=\(String(format: "%.2f", fact.confidence)) text=\(String(fact.text.prefix(500)))"
        }.joined(separator: "\n")

        return MemoryPrompt(
            system: "你是长期记忆巩固器。你只整理已提取的记忆事实，不新增没有依据的信息，不写角色心声，只返回JSON。",
            user: """
            把新事实与已有事实做去重、更新、失效处理。已有事实只能使用给出的 id；新事实用从 0 开始的 newIndexes 引用。

            规则：
            1. 语义重复或已被覆盖的新事实 → NOOP（用 newIndexes 标记已处理）。
            2. 同一事实有更完整/更新的表述 → UPDATE 到最相关的 existingId，可给 text 作为合并后的文本。
            3. 全新信息 → ADD。
            4. 只有明确过时、与当前事实冲突且非 pinned 的旧事实才 DELETE；pinned 事实禁止删除。
            5. 每条新事实都必须被 ADD、UPDATE 或 NOOP 之一覆盖，不要漏掉。
            6. 不编造 id、newIndexes、消息来源；最多 20 条操作。

            已有事实：
            \(existingLines.isEmpty ? "（无）" : existingLines)

            新事实：
            \(incomingLines)

            只返回：
            {"operations":[{"op":"ADD","newIndexes":[0]},{"op":"UPDATE","existingId":"已有事实的UUID","newIndexes":[1],"text":"合并后的文本"},{"op":"DELETE","existingId":"已有事实的UUID"},{"op":"NOOP","existingId":"已有事实的UUID","newIndexes":[2]}]}
            """,
            timeout: 60
        )
    }
}
