# ADR 0008 — Networking Backend

**Status**: Accepted
**Date**: 2025-01-01

## Context

The SDK needs a production HTTP backend and a fully injectable seam for testing.
Third-party networking libraries were evaluated and rejected to keep the dependency
footprint at zero.

## Decision

### HTTPClient Protocol (testability seam)

```swift
public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error>
}
```

All service methods call `RequestPipeline`, which calls `HTTPClient`. The protocol
is injected via `ClientConfiguration.httpClient`.

### URLSessionHTTPClient (production)

Uses `URLSession.data(for:)` for non-streaming and `URLSession.bytes(for:)` for
streaming. The shared `URLSession` instance uses a default configuration; callers
who need custom TLS/proxy settings can provide their own `URLSession`.

### RequestPipeline

Sits between service methods and `HTTPClient`. Responsibilities:
1. Injects `x-api-key` (or `x-admin-api-key` for `/v1/organizations` paths).
2. Injects `anthropic-version: 2023-06-01`.
3. Merges per-request headers (e.g. `anthropic-beta`).
4. Builds the full `URLRequest` with base URL, path, query items, and body.
5. Applies `RetryPolicy` for 429/5xx responses.
6. Maps the `HTTPResponse` to `AnthropicError` for non-2xx status codes.

### RetryPolicy

Exponential backoff (base 1 s, multiplier 2, max 30 s) for status codes
`[429, 500, 502, 503, 529]`. For 429, honours the `Retry-After` header if present.
Maximum retry count is configurable via `ClientConfiguration.maxRetries` (default 2).
Status codes in `[400, 401, 403, 404]` are not retried.

### MockHTTPClient (AnthropicTestSupport)

Stores a `handler: ((HTTPRequest) throws -> HTTPResponse)?` closure and a
`streamHandler: ((HTTPRequest) -> AsyncThrowingStream<Data, Error>)?` closure.
Records every call in `recordedRequests: [HTTPRequest]`.

## Consequences

- Swapping the HTTP backend (e.g., for custom proxy, certificate pinning) requires
  only providing a different `HTTPClient` implementation in `ClientConfiguration`.
- All unit and service tests run without network by injecting `MockHTTPClient`.
- Integration tests use the default `URLSessionHTTPClient` and require `ANTHROPIC_API_KEY`.
