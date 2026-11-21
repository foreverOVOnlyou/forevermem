# Privacy

Foreverloom stores derived long-term memory, which may contain personal data. The host app is responsible for how that data is collected, stored, transmitted and deleted.

## What Foreverloom stores

- Conversation memory JSON: profile items, social events, facts, capsules (legacy), day summaries
- Optional fact/summary embeddings
- Trace metadata passed through the host's `recordTrace` callback (Foreverloom does not persist it itself)

Foreverloom does **not** store API keys.

## What leaves the device

The host's `complete` and `embed` closures send prompts/text to whatever provider the host configures. Memory summarization and consolidation can send private conversation content to that provider. The host must disclose this to users and comply with the provider's data policy.

## Storage

`FileMemoryStore` writes:

```text
<directory>/<conversationID>.json
<directory>/<conversationID>.json.bak
```

On iOS it requests complete file protection; the host still controls the directory, backup policy, and device encryption.

## User control

Foreverloom exposes snapshot/export, fact editing, fact deletion, profile item deletion, day summary deletion, tombstone purge, and archived-record purge. The host must surface these controls and honor conversation deletion.

## Prompt injection

Memories and retrieved original messages are untrusted data. Foreverloom's default prompts delimit them as reference material, but hosts should keep system instructions separate and avoid treating memory text as executable instructions.

## Logging

Foreverloom does not log conversation content by default. The example CLI uses synthetic data only.
