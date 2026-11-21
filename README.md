# Forevermem

从乌托邦 App 抽出的完整长期记忆逻辑。Forevermem 负责记忆生命周期；宿主只提供聊天记录、Chat API、Embedding API、设置和 UI。

Author: [foreverOVOnlyou](https://x.com/foreverOVOnlyou)

Repository: https://github.com/foreverOVOnlyou/forevermem

> 在当前 monorepo 中路径是 `Packages/Forevermem`。抽成独立仓库后，本目录就是仓库根目录；命令中的 `cd Packages/Forevermem` 换成 `cd Forevermem` 即可。

## 状态

- ✅ 核心算法 public 化
- ✅ App target 通过本地 package 链接
- ✅ App 只剩薄适配器 `CompanionMemory`
- ✅ `MemoryEngine` 完整写入/读取/维护编排
- ✅ 5 个 XCTest（含端到端 Engine flow）
- ✅ Example CLI
- ✅ MIT License
- ⏳ 旧 `Tests/` standalone 脚本尚未迁移

## 目录

```text
Packages/Forevermem/
├── Package.swift
├── Sources/Forevermem/
│   ├── MemoryEngine.swift
│   ├── MemoryPrompts.swift
│   ├── MemoryProfilePolicy.swift
│   ├── MemoryStore.swift
│   ├── MemoryDocument.swift
│   ├── MemoryScoring.swift
│   ├── MemorySegmenter.swift
│   ├── MemoryExtractionParser.swift
│   ├── MemoryFactConsolidator.swift
│   ├── MemoryProfileMerger.swift
│   ├── MemoryPruner.swift
│   ├── MemoryFactRetriever.swift
│   └── ...
├── Examples/ForevermemCLI/
├── Tests/ForevermemTests/
├── Docs/
│   ├── Privacy.md
│   ├── Standalone.md
│   └── ReleaseChecklist.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
└── THIRD_PARTY_NOTICES.md
```

## 最小接入

```swift
import Forevermem

let dependencies = MemoryEngineDependencies(
    complete: { task, system, user, timeout in
        // task == .segment / .consolidation
        // 调你的 Chat API，原样返回文本
    },
    embed: { text in
        // 调你的 Embedding API；失败就 throw
    },
    recordTrace: { trace in
        // 可选：写入你自己的 trace
    },
    profilePolicy: {
        .everySegment
    },
    vectorThreshold: {
        0.62
    },
    fallbackMessages: { conversationID in
        // 当调用方 messages 为空时，从你的聊天存储重建
    }
)

let engine = MemoryEngine(
    store: FileMemoryStore(directory: memoryDirectory),
    dependencies: dependencies
)
```

然后：

```swift
await engine.summarizeCompletedSegmentIfNeeded(
    conversationID: id,
    messages: messages,
    contactName: name
)

let context = await engine.buildContext(
    conversationID: id,
    messages: messages,
    currentText: userText
)
```

## Prompt 覆盖

默认 prompt 在 `MemoryPrompts.swift`。宿主可以实现：

```swift
struct MyPrompts: MemoryPromptProvider {
    func segment(transcript: String, profileContext: String?) -> MemoryPrompt { ... }
    func consolidation(existing: [MemoryFactRecord], incoming: [MemoryFactRecord]) -> MemoryPrompt { ... }
}
```

然后在构造 `MemoryEngineDependencies` 时传入：

```swift
let deps = MemoryEngineDependencies(
    complete: ...,
    embed: ...,
    recordTrace: ...,
    profilePolicy: ...,
    vectorThreshold: ...,
    fallbackMessages: ...,
    prompts: MyPrompts()
)
```

## Example CLI

不联网、不需要 API Key：

```bash
cd Packages/Forevermem
swift run ForevermemCLI
```

输出会展示：

- 段落总结写入
- 事实写入
- `buildContext` 召回结构化记忆和日总结

## 测试

```bash
cd Packages/Forevermem
swift test
```

覆盖：评分、分段、文件存储、Engine 写入 + 召回。

## 设计边界

Forevermem 负责：

- 记忆模型与 schema
- 评分、衰减、访问强化
- 话题分段
- 段落解析
- Mem0 事实巩固
- 画像增量合并
- 容量控制与归档
- 文件存储、备份、迁移
- 完整 Engine 编排

宿主负责：

- 聊天记录来源
- Chat API / Embedding API 的传输、鉴权、计费
- API Key、UserDefaults、UI
- 角色人设、世界书、App 专属 prompt
- 记忆检查器 UI

## Release

- 独立仓库步骤：[Docs/Standalone.md](Docs/Standalone.md)
- 发布检查清单：[Docs/ReleaseChecklist.md](Docs/ReleaseChecklist.md)
- 版本记录：[CHANGELOG.md](CHANGELOG.md)

## License

MIT。`companion-memory` 的 MIT notice 保留在 `THIRD_PARTY_NOTICES.md`。

这不是 Mem0 / SeCom / MOOM 的官方实现；实现受这些论文和项目启发。
