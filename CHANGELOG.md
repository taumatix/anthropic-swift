# Changelog

All notable changes to the Anthropic Swift SDK are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [0.1.0] — 2025-01-01

### Added

**Core infrastructure**
- `AnthropicClient` — primary entry point; `final class: Sendable`, not an `actor`
- `ClientConfiguration` — Sendable configuration struct with all SDK settings
- `ClientOptions` — fluent builder for `ClientConfiguration`
- `RequestPipeline` — auth header injection, retry policy, error mapping
- `HTTPClient` protocol — sole testability seam for unit tests
- `URLSessionHTTPClient` — production backend using `URLSession.data` / `.bytes`
- `RetryPolicy` — exponential backoff for 429/5xx, respects `Retry-After` header
- `AnthropicError` — single exhaustive error enum covering all failure modes
- `APIError` — typed Anthropic JSON error body
- `JSONCoding` — shared snake_case `JSONEncoder` / `JSONDecoder` singletons

**GA APIs**
- `MessagesService.create(_:)` — non-streaming message creation
- `MessagesService.stream(_:) -> MessageStream` — lazy streaming messages
- `MessagesService.countTokens(_:)` — token counting
- `BatchesService` — create, get, list, cancel, delete, stream JSONL results
- `ModelsService` — list all models, get a model by ID

**Streaming**
- `SSEParser` — pure SSE line parser, unit-testable without HTTP
- `MessageStream: AsyncSequence` — named type, lazy HTTP connect
- `MessageStream.collect()` — accumulates events into a final `MessageResponse`
- `MessageStream.textStream` — yields only incremental text delta strings

**Pagination**
- `Page<T>: AsyncSequence` — transparent multi-page cursor-based iteration

**Type system**
- `Model` — `RawRepresentable<String>` + `ExpressibleByStringLiteral` with constants
  for all current Claude models
- `ContentBlock` — discriminated union enum with `.unknown` forward-compat case
- `MessageRequest`, `MessageResponse`, `MessageParam`, `SystemPrompt`
- `CountTokensRequest`, `CountTokensResponse`
- `MessageBatch`, `BatchRequest`, `BatchResult`
- `ModelInfo`
- `Tool`, `ToolChoice`, `ToolInputSchema`
- `Usage`, `UsageDelta`, `StopReason`, `Metadata`

**Beta APIs**
- `FilesService` — upload, list, get, delete, download (beta header auto-injected)
- `SkillsService` — create, list, get, delete (beta header auto-injected)
- `FileObject`, `FileUploadRequest`
- `Skill`

**Admin / Organization API**
- `WorkspacesService` — list, create, get, archive
- `APIKeysService` — list, get
- `MembersService` — list, update, delete
- `InvitesService` — list, create, get, delete
- `AdminServices` — groups all four admin services under `client.admin.*`
- Automatic routing of `/v1/organizations/*` paths to `adminAPIKey`

**Test support (AnthropicTestSupport)**
- `MockHTTPClient` — injectable `HTTPClient` with request recording
- `RecordingHTTPClient` — cassette-style request/response replay
- `MockResponses` — canned JSON fixtures for all endpoints
- `SSEFixtures` — canned SSE byte sequences for streaming tests

**Examples**
- `BasicChat` — simple synchronous message exchange
- `StreamingChat` — real-time streaming with text delta display
- `ToolUse` — tool definition, invocation, and result handling
- `FileUpload` — file upload, document message, file deletion
- `BatchProcessing` — batch creation, polling, and JSONL result streaming

**Documentation**
- `CLAUDE.md` — conventions and 9-step checklist for future contributors
- `README.md` — full feature documentation and usage examples
- `Docs/ADR/` — eight Architectural Decision Records (0001–0008)

[Unreleased]: https://github.com/taumatix/anthropic-swift/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/taumatix/anthropic-swift/releases/tag/v0.1.0
