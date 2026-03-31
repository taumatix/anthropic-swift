# ADR 0003 — Concurrency Model

**Status**: Accepted
**Date**: 2025-01-01

## Context

Swift 5.5+ ships structured concurrency (`async/await`, `AsyncSequence`,
`AsyncThrowingStream`). The SDK must integrate cleanly with these primitives
while remaining free of data races under strict concurrency checking.

## Decision

1. **`async/await` for all network calls.** Non-streaming service methods are
   `async throws` functions. No completion-handler or Combine APIs are provided —
   those can be bridged by callers using standard Swift async-to-legacy adapters.

2. **`AsyncThrowingStream` as the streaming primitive.** `URLSession.bytes` yields
   `Data` chunks, which flow through `SSEParser.parse(_:)` (also an
   `AsyncThrowingStream`) into `MessageStream` (a named `AsyncSequence`).

3. **`Sendable` everywhere.** The experimental `StrictConcurrency` feature flag is
   enabled. All public types must satisfy the compiler's Sendable requirements.
   The only exception is `AnyJSONValue`, which holds `Any` and is declared
   `@unchecked Sendable` — this is safe because `JSONSerialization` only returns
   thread-safe Foundation containers (dictionaries, arrays, strings, numbers, nil).

4. **No global mutable state.** `JSONCoding.encoder` and `JSONCoding.decoder` are
   `let` constants (immutable after initialisation). `MockHTTPClient` uses `NSLock`
   for its mutable `recordings` array, with `@unchecked Sendable`.

5. **Structured Task lifetimes.** `SSEParser.parse` and `MessageStream` both use
   `Task { ... }` internally. These tasks are scoped to the lifetime of the
   `AsyncThrowingStream`'s continuation, so cancellation propagates correctly when
   the caller cancels the surrounding Task.

## Consequences

- The SDK requires Swift 5.9+ (for `AsyncThrowingStream` improvements) and Xcode 15+.
- Deployment targets: macOS 13, iOS 16, tvOS 16, watchOS 9 (all support async/await).
- No Combine or callback APIs ship in the initial version; this can be revisited in
  a future minor release if demanded by users.
