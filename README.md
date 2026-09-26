# Anthropic Swift SDK

A production-quality Swift SDK for the [Anthropic](https://www.anthropic.com) Claude API.
Supports the Messages, Batches, Models, Files and Skills APIs, and the Admin/Organization API
(Workspaces, API Keys, Members, Invites).

> **Wire contracts:** API version `2023-06-01` — current, checked 2026-09-21.
>
> - **Skills is on GA as of 2026-09-22** and sends no beta header. It previously decoded a `name`
>   field the API has never returned, so every `client.skills` call failed; if you are on `0.2.0`
>   or earlier, Skills does not work at all. `Skill.name` still compiles, deprecated, and now
>   returns `displayName`.
> - **Files still sends `files-api-2025-04-14`**, checked 2026-09-21. The header is optional now and
>   sending it keeps the old response shapes, so the cost is missing surface: no `expires_at` on a
>   file, no `expires_in_seconds` at upload, and the superseded `before_id`/`after_id` cursor
>   instead of `page`/`next_page`. Migrating it is the next roadmap entry of its kind.
>
> See [UPSTREAM.md](UPSTREAM.md) for the shape-by-shape diff and what was verified when, and
> [ROADMAP.md](ROADMAP.md) for the order.

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+
- Xcode 15+

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/taumatix/anthropic-swift", from: "0.2.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "Anthropic", package: "anthropic-swift"),
    ]),
    // Add test support only in test targets
    .testTarget(name: "MyAppTests", dependencies: [
        .product(name: "AnthropicTestSupport", package: "anthropic-swift"),
    ]),
]
```

## Quick Start

```swift
import Anthropic

let client = AnthropicClient(apiKey: "sk-ant-...")

let response = try await client.messages.create(
    MessageRequest(
        model: .claudeSonnet5,
        messages: [.user("Hello, Claude!")],
        maxTokens: 1024
    )
)
print(response.textContent)
```

## Features

### Non-Streaming Messages

```swift
let response = try await client.messages.create(
    MessageRequest(
        model: .claude4Sonnet,
        messages: [
            .user("What is the capital of France?")
        ],
        maxTokens: 256
    )
)
print(response.textContent) // "The capital of France is Paris."
```

### Streaming Messages

Stream tokens as they arrive:

```swift
let stream = client.messages.stream(
    MessageRequest(model: .claude4Opus, messages: [.user("Tell me a story.")], maxTokens: 2048)
)

for try await text in stream.textStream {
    print(text, terminator: "")
    fflush(stdout)
}
```

Collect the full `MessageResponse` after streaming:

```swift
let response = try await client.messages.stream(request).collect()
print(response.textContent)
```

Inspect individual events:

```swift
for try await event in client.messages.stream(request) {
    switch event {
    case .messageStart(let e):   print("Model:", e.message.model)
    case .contentBlockDelta(let e):
        if case .textDelta(let text) = e.delta { print(text, terminator: "") }
    case .messageStop:           print("\nDone")
    default: break
    }
}
```

### Tool Use

```swift
let weatherTool = Tool(
    name: "get_weather",
    description: "Get the current weather for a location",
    inputSchema: .object(properties: [
        "location": .string(description: "City name")
    ], required: ["location"])
)

let response = try await client.messages.create(
    MessageRequest(
        model: .claude4Sonnet,
        messages: [.user("What's the weather in London?")],
        maxTokens: 1024,
        tools: [weatherTool]
    )
)

if let toolUse = response.firstToolUse {
    print("Tool:", toolUse.name)
    print("Input:", toolUse.input)
}
```

### Token Counting

```swift
let count = try await client.messages.countTokens(
    CountTokensRequest(
        model: .claude4Sonnet,
        messages: [.user("Hello")]
    )
)
print("Input tokens:", count.inputTokens)
```

### Models

`Model` carries the wire ID as a plain string, so any model works — including ones released after
this SDK version:

```swift
MessageRequest(model: .claudeOpus5, ...)                  // named constant
MessageRequest(model: "claude-some-future-model", ...)    // string literal, no SDK release needed
```

| Constant | Wire ID |
|---|---|
| `.claudeFable5` | `claude-fable-5` |
| `.claudeOpus5` | `claude-opus-5` |
| `.claudeOpus48` / `.claudeOpus47` / `.claudeOpus46` / `.claudeOpus45` | `claude-opus-4-8` … `-4-5` |
| `.claudeSonnet5` | `claude-sonnet-5` |
| `.claudeSonnet46` / `.claudeSonnet45` | `claude-sonnet-4-6` / `-4-5` |
| `.claudeHaiku45` | `claude-haiku-4-5` |

`.claudeMythos5` is also defined, but only Project Glasswing participants can reach it.

The Claude 3.x constants (`.claude35Sonnet`, `.claude3Opus`, …) are deprecated: those models are
retired and the API returns 404 for them. They still compile so existing code isn't broken, but
each one now warns with its replacement.

`.claude4Opus`, `.claude4Sonnet`, and `.claude4Haiku` keep their original 4.5-generation values —
repointing a name at a newer model would silently change which model your code runs against. Use
the explicitly versioned constants above instead.

```swift
// List what the API currently serves — the authoritative answer
for try await model in try await client.models.list() {
    print(model.id, model.displayName)
}

// Get a specific model
let model = try await client.models.get(id: "claude-opus-5")
print(model.displayName)
```

### Message Batches

```swift
// Create a batch
let batch = try await client.batches.create(
    BatchCreateRequest(requests: [
        .init(customId: "req-1", params: MessageRequest(
            model: .claude4Sonnet,
            messages: [.user("Hello")],
            maxTokens: 100
        )),
    ])
)

// Poll until complete
var current = batch
while current.processingStatus != .ended {
    try await Task.sleep(for: .seconds(5))
    current = try await client.batches.get(id: current.id)
}

// Stream results
for try await result in client.batches.results(id: current.id) {
    print(result.customId, result.result)
}
```

### Files (Beta)

```swift
// Upload a file
let data = try Data(contentsOf: URL(fileURLWithPath: "document.pdf"))
let file = try await client.files.upload(
    FileUploadRequest(filename: "document.pdf", mimeType: "application/pdf", data: data)
)

// Use the file in a message
let response = try await client.messages.create(
    MessageRequest(
        model: .claude4Sonnet,
        messages: [
            .user([
                .text("Summarise this document:"),
                .document(.file(id: file.id)),
            ])
        ],
        maxTokens: 1024
    )
)

// Clean up
try await client.files.delete(id: file.id)
```

### Skills

A skill is created from a file set, which must contain a `SKILL.md` at the root of one shared
top-level directory. `displayName` is optional — the API derives it from the `SKILL.md` frontmatter.

```swift
let manifest = """
---
name: invoice-parser
description: Extracts line items from supplier invoices.
---

Read the invoice and return each line item as JSON.
"""

let skill = try await client.skills.create(
    files: [
        SkillFile(path: "invoice-parser/SKILL.md",
                  content: Data(manifest.utf8),
                  mimeType: "text/markdown")
    ],
    displayName: "Invoice parser"
)
print(skill.id, skill.displayName, skill.latestVersionId ?? "-")
```

Listing paginates by token. `Page` is an `AsyncSequence`, so iterating follows `next_page` for you
and keeps the `source` filter across the boundary:

```swift
for try await skill in try await client.skills.list(source: .custom) {
    print(skill.displayName, skill.source?.rawType ?? "unknown")
}

// Or a single page, when you want to hold the cursor yourself.
let page = try await client.skills.list(limit: 100)
let next = page.nextPageToken

try await client.skills.delete(id: skill.id)
```

`SkillSource.Kind` is `RawRepresentable` with an `unknown(String)` case that carries the value the
API sent, so a source Anthropic adds later decodes instead of failing the response — and can be
handed straight back as a filter:

```swift
let seen = try await client.skills.list(limit: 1).data.first?.source?.type
let more = try await client.skills.list(source: seen)   // works even for a source this SDK predates
```

### Admin API

The Admin API requires a separate admin API key:

```swift
let client = AnthropicClient(
    apiKey: "sk-ant-...",
    options: ClientOptions().adminAPIKey("sk-ant-admin-...")
)

// List workspaces
for try await workspace in try await client.admin.workspaces.list() {
    print(workspace.id, workspace.name)
}

// List API keys
for try await key in try await client.admin.apiKeys.list() {
    print(key.id, key.name, key.status)
}
```

## Error Handling

All errors are instances of `AnthropicError`:

```swift
do {
    let response = try await client.messages.create(request)
} catch AnthropicError.authenticationFailed {
    print("Invalid API key")
} catch AnthropicError.rateLimited(let retryAfter) {
    if let delay = retryAfter {
        print("Rate limited. Retry after \(delay) seconds")
    }
} catch AnthropicError.apiError(let error) {
    print("API error:", error.error.type, error.error.message)
} catch AnthropicError.decodingError(let error, let rawBody) {
    print("Decode failed:", error)
    print("Raw:", String(data: rawBody, encoding: .utf8) ?? "?")
} catch {
    print("Unexpected:", error)
}
```

## Configuration

```swift
let client = AnthropicClient(
    configuration: ClientConfiguration(
        apiKey: "sk-ant-...",
        baseURL: URL(string: "https://api.anthropic.com")!,
        anthropicVersion: "2023-06-01",
        timeout: 600,
        maxRetries: 2,
        additionalHeaders: ["x-custom-header": "value"]
    )
)
```

Or using the fluent builder:

```swift
let client = AnthropicClient(
    apiKey: "sk-ant-...",
    options: ClientOptions(apiKey: "sk-ant-...")
        .maxRetries(3)
        .additionalHeaders(["x-request-id": "my-id"])
)
```

`baseURL` retargets the SDK's HTTP client, so pointing it at a gateway or a proxy works through
either form. A client you supply yourself keeps its own routing and is never replaced.

### Where your API key is allowed to go

The SDK authenticates with an `x-api-key` header, so two things about `baseURL` are enforced
rather than documented:

- **A plaintext `baseURL` is refused.** Anything that is not `https` throws
  `AnthropicError.networkError` with `URLError.appTransportSecurityRequiresSecureConnection`
  before a byte is sent. Loopback is exempt — `127.0.0.0/8`, `::1`, `localhost` and `*.localhost`
  — because plaintext there does not leave the machine. Matching is exact, so
  `http://localhost.example.com` is refused. If you genuinely have an internal plaintext gateway,
  set `allowsInsecureBaseURL: true` (or `.allowsInsecureBaseURL(true)` on the builder) and your
  key goes out in the clear, which is the point of having to write it.
- **A redirect that changes origin loses your credentials.** `URLSession` follows redirects
  itself and replays the original request's headers onto the target, stripping nothing — so
  without this, anything able to answer with a `302` could harvest your key. When the scheme, host
  or port changes, the SDK keeps only content-negotiation and framing headers and drops the rest:
  `x-api-key`, `anthropic-*`, and anything you added through `additionalHeaders`. Same-origin
  redirects are untouched, so a server moving a path still works.

If you route through a gateway that redirects to a different host, point `baseURL` at the host
that actually answers — the redirect will not carry your key there for you.

> **`timeout` is currently ignored.** It is stored on the configuration but never reaches the
> `URLSession`, which uses its own 60-second default. Setting it has no effect today; a long
> streaming turn can still fail at 60s as `AnthropicError.timeout`. Tracked at the top of
> [ROADMAP.md](ROADMAP.md).

## Testing

Use `MockHTTPClient` from `AnthropicTestSupport` to test without network access:

```swift
import AnthropicTestSupport
import XCTest

final class MyTests: XCTestCase {
    func testMyFeature() async throws {
        let mock = MockHTTPClient()
        mock.handler = { _ in
            HTTPResponse(statusCode: 200, body: MockResponses.singleMessage)
        }
        let client = AnthropicClient(
            configuration: ClientConfiguration(apiKey: "test", httpClient: mock)
        )

        let response = try await client.messages.create(
            MessageRequest(model: .claude4Sonnet, messages: [.user("Hi")], maxTokens: 100)
        )
        XCTAssertEqual(response.id, "msg_01XFDUDYJgAACzvnptvVoYEL")
    }
}
```

## Running Examples

```bash
export ANTHROPIC_API_KEY=sk-ant-...

swift run BasicChat
swift run StreamingChat
swift run ToolUse
swift run FileUpload
swift run BatchProcessing
```

## Running Tests

```bash
# Unit, service and loopback end-to-end tests (no network required)
swift test --skip Live

# Live tests against api.anthropic.com (requires an API key)
ANTHROPIC_API_KEY=sk-ant-... swift test --filter Live
```

`swift test` filters on test-case and test-method names, not on directories, so `--filter
Integration` selects nothing and exits 0 having run no test. The classes are `Live*Tests`.

**What CI proves, and what it does not.** This repository has no `ANTHROPIC_API_KEY` secret, so
the **Integration Tests** job is skipped on every run and every green build you see here was
produced against `MockHTTPClient` and a loopback HTTP server. That covers encoding, decoding,
pagination, retry, error mapping and the SSE parser. It cannot catch a request the API rejects,
a response shape that changed, or a header this SDK stopped sending — the drift recorded in
[`UPSTREAM.md`](UPSTREAM.md) is exactly that class of problem. Tracked in
[#5](https://github.com/taumatix/anthropic-swift/issues/5); run the live tests yourself with your
own key if that matters to you.

## Architecture

See [`Docs/ADR/`](Docs/ADR/) for the full set of Architectural Decision Records:

- [0001 — Package Structure](Docs/ADR/0001-package-structure.md)
- [0002 — Client Design](Docs/ADR/0002-client-design.md)
- [0003 — Concurrency Model](Docs/ADR/0003-concurrency-model.md)
- [0004 — Type System](Docs/ADR/0004-type-system.md)
- [0005 — Streaming Strategy](Docs/ADR/0005-streaming-strategy.md)
- [0006 — Error Hierarchy](Docs/ADR/0006-error-hierarchy.md)
- [0007 — Pagination Design](Docs/ADR/0007-pagination-design.md)
- [0008 — Networking Backend](Docs/ADR/0008-networking-backend.md)

## License

MIT. See [LICENSE](LICENSE) for details.
