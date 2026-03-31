# Anthropic Swift SDK

A production-quality Swift SDK for the [Anthropic](https://www.anthropic.com) Claude API.
Supports all GA APIs (Messages, Batches, Models), beta APIs (Files, Skills), and the
Admin/Organization API (Workspaces, API Keys, Members, Invites).

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+
- Xcode 15+

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/taumatix/anthropic-swift", from: "0.1.0"),
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
        model: .claude4Sonnet,
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

```swift
// List all available models
for try await model in try await client.models.list() {
    print(model.id, model.displayName)
}

// Get a specific model
let model = try await client.models.get(id: "claude-opus-4-6")
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
    options: ClientOptions()
        .timeout(120)
        .maxRetries(3)
        .additionalHeader("x-request-id", "my-id")
)
```

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
# Unit + service tests (no network required)
swift test

# Integration tests (requires live API key)
ANTHROPIC_API_KEY=sk-ant-... swift test --filter Integration
```

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
