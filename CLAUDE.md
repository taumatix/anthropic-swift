# CLAUDE.md — Anthropic Swift SDK Conventions

This file is loaded automatically by Claude Code at the start of every session.
It encodes the architectural decisions and conventions that must be followed when
extending or modifying this SDK.

---

## Non-Negotiable Rules

### Zero external dependencies in `Anthropic` target
`Package.swift` must not add any package dependency to the `Anthropic` library target.
`Foundation` and `URLSession` are the only permitted external imports.
`AnthropicTestSupport` may import `Anthropic` but nothing else beyond Foundation.

### All HTTP calls via `HTTPClient` protocol
Services must NEVER call `URLSession` directly. Every outbound request flows through
the `HTTPClient` protocol defined in `Sources/Anthropic/Networking/HTTPClient.swift`.
This is the sole testability seam for unit tests.

### `*Request` and `*Response` are always separate types
Request types conform to `Encodable`; response types conform to `Decodable`.
They must never be merged into a single type even when fields overlap.

### `ContentBlock.unknown` must never be removed
The `.unknown(type:rawData:)` case ensures forward compatibility when Anthropic adds
new content block types. Removing it would be a breaking change for all callers.

### All public types must conform to `Sendable`
Swift strict concurrency is enabled (`swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]`).
Every public type must be either `Sendable` or `@unchecked Sendable` with a documented
safety justification in a comment.

### Use only `JSONCoding.encoder` / `JSONCoding.decoder`
Never instantiate a standalone `JSONEncoder` or `JSONDecoder`. The shared singletons
in `Sources/Anthropic/Internal/JSONCoding.swift` provide consistent snake_case key
conversion across the entire SDK.

### Beta endpoints hardcode their `anthropic-beta` version string
Each beta service (Files, Skills) declares `private let betaHeader: String = "..."` as
a module-level or type-level constant. This makes the pinned version explicit and
easy to update in one place per service.

---

## Checklist for Adding a New Public API Endpoint

Follow this 9-step checklist every time you add a new endpoint:

1. **Types** — Create `Types/<Group>/<Resource>Request.swift` and `<Resource>Response.swift`
2. **JSON round-trip test** — Add a unit test in `Tests/AnthropicTests/Unit/` that decodes
   a canned JSON fixture and verifies field mapping
3. **Fixture** — Add the canned JSON to `AnthropicTestSupport/MockResponses.swift`
4. **Service method** — Implement in the appropriate `Services/*.swift` file
5. **Service test** — Add a test in `Tests/AnthropicTests/Services/` using `MockHTTPClient`
6. **Integration test** — Add a live test in `Tests/AnthropicTests/Integration/` guarded
   by `try XCTSkipUnless(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil, ...)`
7. **Example update** — Update or add an `Examples/` executable if the new feature warrants it
8. **DocC comment** — Add `///` doc comments to all public types and methods
9. **ADR** — If the feature requires a new architectural decision, add a `Docs/ADR/` document

---

## Architecture Overview

```
AnthropicClient
  ├── RequestPipeline          ← injects auth headers, retries, maps HTTP errors
  │     └── HTTPClient (protocol)
  │           └── URLSessionHTTPClient (production)
  │           └── MockHTTPClient (tests)
  ├── messages: MessagesService
  ├── batches:  BatchesService
  ├── models:   ModelsService
  ├── files:    FilesService       (beta)
  ├── skills:   SkillsService      (beta)
  └── admin:    AdminServices
        ├── workspaces: WorkspacesService
        ├── apiKeys:    APIKeysService
        ├── members:    MembersService
        └── invites:    InvitesService
```

### Key Type Decisions

| Concern | Type | Notes |
|---------|------|-------|
| Model identifier | `struct Model: RawRepresentable<String>` | Known constants + open to custom strings |
| Content blocks | `enum ContentBlock` | Discriminated union, always has `.unknown` |
| Pagination | `Page<T>: AsyncSequence` | Cursor-based, lazy multi-page |
| Streaming | `MessageStream: AsyncSequence` | Named type, lazy HTTP connect |
| Error hierarchy | `enum AnthropicError` | Single exhaustive enum, no inheritance |
| JSON coding | `JSONCoding.encoder/decoder` | Single snake_case instance |

---

## Running Tests

```bash
# Unit + service tests (no network required)
swift test

# Integration tests (requires live API key)
ANTHROPIC_API_KEY=sk-ant-... swift test --filter Integration

# Build only
swift build
```

All unit and service tests must pass without any network access. Integration tests
skip automatically when `ANTHROPIC_API_KEY` is not set.

---

## File Layout

```
Sources/Anthropic/
  Anthropic.swift               # version constant + top-level namespace
  Client/                       # AnthropicClient, Configuration, Pipeline
  Networking/                   # HTTPClient protocol + URLSession impl + RetryPolicy
  Auth/                         # APIKeyProvider
  Types/
    Common/                     # Model, ContentBlock, Usage, StopReason, Metadata, ToolUse
    Messages/                   # MessageRequest/Response, StreamEvent, CountTokens
    Batches/                    # MessageBatch, BatchRequest, BatchResult
    Models/                     # ModelInfo
    Files/                      # FileObject, FileUploadRequest
    Skills/                     # Skill
    Admin/                      # Workspace, APIKey, Member, Invite
  Services/                     # MessagesService, BatchesService, ModelsService, ...
  Streaming/                    # SSEParser, MessageStream, StreamingHelpers
  Pagination/                   # Page<T>, PaginationCursor
  Errors/                       # AnthropicError, APIError
  Internal/                     # JSONCoding, MultipartFormData, HeaderBuilder

Sources/AnthropicTestSupport/   # NOT shipped to users
  MockHTTPClient.swift
  MockResponses.swift
  SSEFixtures.swift
  RecordingHTTPClient.swift

Tests/AnthropicTests/
  Unit/                         # SSEParser, coding, error mapping, retry, pagination
  Services/                     # One file per service, uses MockHTTPClient
  Integration/                  # Live network tests, skipped without API key

Examples/
  BasicChat/                    # swift run BasicChat
  StreamingChat/                # swift run StreamingChat
  ToolUse/                      # swift run ToolUse
  FileUpload/                   # swift run FileUpload
  BatchProcessing/              # swift run BatchProcessing
```
