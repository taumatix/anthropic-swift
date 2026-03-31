# ADR 0006 — Error Hierarchy

**Status**: Accepted
**Date**: 2025-01-01

## Context

The SDK surfaces errors from multiple sources: HTTP status codes, JSON decoding
failures, SSE parse failures, network-level errors, and structured API error
bodies from Anthropic. Callers need to be able to switch exhaustively over
error cases without resorting to `is`/`as?` casts across an inheritance hierarchy.

## Decision

A single `enum AnthropicError: Error, Sendable` covers all failure modes:

| Case | When thrown |
|------|-------------|
| `.apiError(APIError)` | HTTP 400/500-range with a parseable Anthropic error body |
| `.httpError(Int, Data)` | HTTP error with an unparseable body |
| `.networkError(Error)` | URLSession transport error |
| `.encodingError(EncodingError)` | Failed to encode a request body |
| `.decodingError(DecodingError, rawBody: Data)` | Failed to decode a response |
| `.streamParseError(String)` | SSE line/event parse failure |
| `.timeout` | Request exceeded the configured timeout |
| `.rateLimited(retryAfter: TimeInterval?)` | HTTP 429 (after all retries exhausted) |
| `.authenticationFailed` | HTTP 401 |
| `.permissionDenied` | HTTP 403 |

The static method `AnthropicError.from(response: HTTPResponse)` centralises
status-to-error mapping so that every service benefits automatically.

`APIError` mirrors the Anthropic JSON body `{"type":"error","error":{"type":"...","message":"..."}}`.

## Consequences

- All thrown errors are `AnthropicError` — callers never need to catch `URLError` or
  `DecodingError` directly.
- The raw response body is attached to `.decodingError` and `.httpError` so callers
  can log or inspect it for debugging.
- `retryAfter` in `.rateLimited` is optional because the `Retry-After` header is not
  always present.
- No error subclassing is used — adding a new case is a source-breaking change
  requiring a major version bump.
