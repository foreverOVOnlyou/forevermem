# Contributing

## Requirements

- Swift 5.9+
- iOS 17+ / macOS 14+
- No API keys or private user data in tests

## Local checks

```bash
swift test
swift run ForeverloomCLI
```

## Design constraints

- Keep `MemoryCore`, `MemoryStore` and `MemoryEngine` free of UIKit/SwiftUI.
- Do not add app-specific chat schemas, Keychain code or UserDefaults keys to the package.
- New public API must be documented and covered by a test.
- Prompts should stay replaceable through `MemoryPromptProvider`.
- Use synthetic fixtures only.

## Pull requests

Describe the behavior change, the tests run, and any storage/schema compatibility impact.
