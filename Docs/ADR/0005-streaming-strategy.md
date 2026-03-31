# ADR 0005 — Streaming Strategy

**Status**: Accepted
**Date**: 2025-01-01

## Context

The Anthropic Messages API supports Server-Sent Events (SSE) streaming. The SDK
must expose streaming in a way that:
- Provides real-time text tokens for display.
- Allows collecting a complete `MessageResponse` at the end.
- Is lazily connected (HTTP not sent until iteration begins).
- Propagates cancellation correctly.

## Decision

The streaming pipeline has three layers:

### Layer 1: SSEParser (pure, no HTTP)
`SSEParser.parse(_:)` converts `AsyncThrowingStream<Data, Error>` (one line per element)
into `AsyncThrowingStream<RawSSEEvent, Error>`. It strips leading/trailing whitespace,
parses `event:` and `data:` field prefixes, and dispatches on blank lines.

Being pure, `SSEParser` is unit-testable with canned byte fixtures from
`AnthropicTestSupport/SSEFixtures.swift` — no network needed.

### Layer 2: MessageStream (named AsyncSequence)
`MessageStream` wraps the SSE stream and decodes each `RawSSEEvent` into a typed
`MessageStreamEvent`. It is a named type (not an opaque `any AsyncSequence`) so
that extension methods can be added to it.

`MessageStream` is lazy: `HTTPClient.stream(_:)` is called inside `makeAsyncIterator()`,
not at initialization. This means constructing `client.messages.stream(request)` does
not open a network connection until you start iterating.

### Layer 3: StreamingHelpers (high-level conveniences)
Two extensions on `MessageStream`:

- `.collect() async throws -> MessageResponse` — accumulates all events into a full
  message, assembling text and tool-input JSON fragments.
- `.textStream: AsyncThrowingStream<String, Error>` — yields only text delta strings;
  useful for real-time printing.

## Consequences

- Callers who want the full message can call `.collect()` as if the API were non-streaming
  while still benefiting from TCP streaming performance.
- Cancelling the parent Task while iterating `MessageStream` (or `.textStream`) will cancel
  the underlying `URLSession` task via structured concurrency propagation.
- The SSE parser correctly handles real Anthropic responses (which use `\n\n` event
  separators) and test fixtures (which may have leading whitespace from Swift indentation).
