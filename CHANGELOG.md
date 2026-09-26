# Changelog

All notable changes to the Anthropic Swift SDK are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Security

- **A redirect carried your API key to any host that asked for it.** `URLSession` follows
  redirects itself and replays the original request's headers onto the target, stripping nothing —
  not `Authorization`, and not the `x-api-key` this SDK authenticates with. Two loopback listeners
  confirmed it on 301, 302, 307 and 308, from both the unary and the streaming transport. Anything
  able to answer with a `302` — a gateway you configured, a compromised one, or whoever can answer
  on a plaintext endpoint — could harvest the key. A redirect that changes scheme, host or port now
  keeps only content-negotiation and framing headers and drops everything else, including
  `anthropic-*` and anything supplied through `additionalHeaders`. Same-origin redirects are
  unchanged, so a server moving a path still works.
- **A plaintext `baseURL` sent the key in cleartext.** `baseURL` began routing traffic in this same
  unreleased cycle and nothing checked where it pointed, so an app reading its endpoint from
  configuration could be downgraded to `http://` by whoever controlled that value. A non-`https`
  `baseURL` is now refused before anything is sent, with
  `URLError.appTransportSecurityRequiresSecureConnection`. Loopback (`127.0.0.0/8`, `::1`,
  `localhost`, `*.localhost`) is exempt; matching is exact, so `http://localhost.evil.example` is
  refused.

### Fixed

- `MessageStream` reported a failure to build its request as `AnthropicError.encodingError` about
  the path, whatever had actually gone wrong — the streaming path wrapped request construction in
  `try?` and substituted a fabricated error. It now propagates the real one.
- **`SkillsService` never worked.** `Skill` required a `name` key and `Page` required `has_more`;
  the Skills API returns neither, under the GA path or under `anthropic-beta: skills-2025-10-02`.
  Every `client.skills` call threw `AnthropicError.decodingError` from the first release. The
  service now targets the GA endpoints and decodes the documented object.
- **`baseURL` was ignored.** `ClientConfiguration.init` built `URLSessionHTTPClient` eagerly, so
  setting `baseURL` afterwards — all that `ClientOptions.baseURL(_:)` does — left the client
  pointed at `https://api.anthropic.com`. Anyone routing through a gateway, proxy, regional
  endpoint or local test server sent their traffic and their API key to the public API instead.
  Assigning `baseURL` now retargets any `URLSessionHTTPClient`, preserving its `URLSession` —
  injecting a client is the only way to supply a pinned or proxied session, so doing that must not
  cost you `baseURL`. A client of another type routes itself and is left alone.
- Iterating a `Page` stopped at the first page with an empty `data` array even when a cursor said
  more pages followed, silently dropping the rest. Plausible with a token cursor in a way it was
  not with an id cursor.
- CI's integration job matched no test case (`swift test --filter "Integration"` — the filter
  takes a test-case name, and `Integration` is only a directory), so it reported green while
  running zero tests for as long as it existed. It now filters on `Live`, and a guard reads the
  run's own summary and fails the job if every selected test skipped. The job itself is skipped,
  not failed, when no `ANTHROPIC_API_KEY` secret is configured — the first spelling of this fix
  failed instead, which left `main` red from 2026-09-22 with no repair available from inside the
  repository. The README now says plainly that CI's green is against mocks only.
- The README's own instruction for running the live tests carried the same dead filter
  (`swift test --filter Integration`), so anyone following it ran nothing and saw success.
- The fluent-builder example in the README did not compile: `ClientOptions()` requires an
  `apiKey`, and `additionalHeader(_:_:)` does not exist.

### Added

- `ClientConfiguration.allowsInsecureBaseURL` (default `false`) and the matching
  `ClientOptions.allowsInsecureBaseURL(_:)`, for a caller with an internal plaintext gateway.
  It waives the transport requirement and nothing else — a `file:` or `ftp:` `baseURL` stays
  refused.
- `Model.claudeFable51` (`claude-fable-5-1`) and `Model.claudeOpus55` (`claude-opus-5-5`). Two of
  the four models on the docs' current-lineup table were missing, and `claudeFable5` and
  `claudeOpus5` — both filed as *legacy* on that page — carried doc comments calling them "the
  most capable widely released model" and "the current Opus". Nothing was removed; the two
  superseded constants keep working and now say what they are.
- `Skill.displayName`, `.latestVersionId`, `.source` and `.updatedAt`, matching the documented
  object. `SkillSource.Kind` is `RawRepresentable` with an `unknown(String)` case carrying the
  value the API sent, so a source added later decodes rather than failing the response, and can be
  passed straight back as a `source:` filter.
- `SkillsService.create(files:displayName:)` — `POST /v1/skills` is `multipart/form-data` with a
  `files[]` part per file, which is what it has always taken. Rejects a file set with no `SKILL.md`
  before sending anything.
- `SkillsService.list(limit:pageToken:source:)` using the `page`/`next_page` token cursor.
  Iterating the returned `Page` follows the token and keeps `limit` and `source` across every page
  boundary.
- `Page.nextPageToken`, alongside the existing id cursor. `hasMore` is derived from `next_page`
  when `has_more` is absent, so both envelope shapes decode.
- `SkillDeleteResponse`, returned by `delete(id:)`, and `SkillFile`.
- `AnthropicError` conforms to `LocalizedError`, so `error.localizedDescription` reports the
  reason instead of "The operation couldn't be completed. (… error 3.)". Applies to every case.
- `SkillsEndToEndTests` drives the real client over a real socket against a loopback server
  replaying Anthropic's published response bodies. `LiveSkillsTests` drives `api.anthropic.com`
  and is skipped without `ANTHROPIC_API_KEY`.

### Changed

- `SkillsService` no longer sends `anthropic-beta: skills-2025-10-02`. It is still a live beta
  value, but the beta endpoint returns the same object and envelope as GA, so it changed nothing.
  Restore it with `ClientOptions.additionalHeaders(["anthropic-beta": "skills-2025-10-02"])`.
- Multipart part names and filenames are escaped per RFC 7578 §5.1. `SkillFile.path` is
  caller-supplied and went into `Content-Disposition` verbatim, so a `"` or CRLF in a path could
  forge part headers or an extra form field. Also affects `FilesService` uploads.

### Changed — source-breaking

Two shapes that compiled against `0.2.0` no longer do. Both are narrow, and neither can affect
working code that called `list`, `get` or `create`, because those always threw.

- `delete(id:)` returns `SkillDeleteResponse` instead of `Void`. It is `@discardableResult`, so
  `try await client.skills.delete(id: x)` as a statement still compiles. What breaks is binding it
  as a `Void` function — `let f: (String) async throws -> Void = client.skills.delete` — and
  `return try await client.skills.delete(id: x)` inside a `Void` function. Deleting was the one
  Skills call that worked before this release, so this is the only change here with a real
  incumbent; it is made because every other delete in this SDK (`FileDeleteResponse`,
  `BatchDeleteResponse`, `InviteDeleteResponse`) returns its response, and a caller cannot
  otherwise confirm *what* was deleted.
- `list(limit:afterId:)` no longer defaults `afterId`. It must be written out, which is what keeps
  a bare `list()` unambiguous against the new overload.

### Deprecated

- `Skill.name` — renamed to `displayName`. Still compiles and now returns the label the API sends.
- `SkillsService.list(limit:afterId:)` — the Skills API paginates by token, and `after_id` is
  ignored by the server. Use `list(limit:pageToken:source:)`. Its result no longer carries a page
  fetcher: iterating it would have re-requested the first page forever under a cursor the API does
  not implement, so it now yields one page and stops.
- `SkillsService.create(_:)` and `CreateSkillRequest` — the API creates skills from an uploaded
  file set, not a JSON body. Use `create(files:displayName:)`.

Nothing was removed or renamed. `Skill.description` is `nil` against the current API and is kept in
case a deployment returns one.

## [0.2.0] — 2026-09-17

### Added

- `Model` constants for the current lineup: `.claudeFable5`, `.claudeMythos5`, `.claudeOpus5`,
  `.claudeOpus48`, `.claudeOpus47`, `.claudeOpus46`, `.claudeOpus45`, `.claudeSonnet5`,
  `.claudeSonnet46`, `.claudeSonnet45`, `.claudeHaiku45`. The newest model the catalogue previously
  knew about was Opus 4.5.

### Deprecated

- Every Claude 3.x constant — `.claude37Sonnet`, `.claude35Sonnet`, `.claude35SonnetLatest`,
  `.claude35Haiku`, `.claude35HaikuLatest`, `.claude3Opus`, `.claude3Sonnet`, `.claude3Haiku`.
  Seven of those models are retired and the API returns 404 for them, so the constants were a
  runtime failure with no compile-time signal. Each now carries its retirement date and the
  constant to use instead. They still compile — nothing is removed.

`.claude4Opus`, `.claude4Sonnet`, and `.claude4Haiku` keep their existing 4.5-generation values.
Repointing a name at a newer model would silently change which model a caller runs against, so
they are documented as pinned rather than updated.

## [0.1.0] — 2026-09-06

### Fixed

- `RequestPipeline` no longer bypasses the injected `HTTPClient` for streaming requests,
  so a custom or mock client is honoured on every code path (#1).
- Decode `tool_use` blocks in assistant turns, which previously failed to parse when a
  model replied with a tool call.

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

[Unreleased]: https://github.com/taumatix/anthropic-swift/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/taumatix/anthropic-swift/releases/tag/v0.2.0
[0.1.0]: https://github.com/taumatix/anthropic-swift/releases/tag/v0.1.0
