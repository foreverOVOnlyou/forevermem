# Changelog

## 0.1.0 — 2026-11-22

Initial standalone extraction.

### Added

- Public `MemoryEngine` with full ingest / recall / maintenance orchestration
- Pure core: models, scoring, SeCom segmentation, extraction parser, Mem0 consolidation, profile merge, pruning
- JSON file store with atomic writes, backup recovery and legacy migration
- Pluggable `MemoryLLM`, `MemoryEmbeddingProvider` and `MemoryPromptProvider`
- Profiles with incremental stable items
- Recent-original hard budget and evidence recovery
- Access reinforcement batching
- Export, tombstone purge and archived-record purge APIs
- `ForeverloomCLI` example with a fake provider
- XCTest coverage for scoring, segmentation, store and full engine flow

### Known limitations

- No hosted backend, vector database or network transport is included
- Embeddings are optional and caller-provided
- Default prompts are Chinese companion/role-play oriented and can be replaced
- The package does not manage API keys or user consent
