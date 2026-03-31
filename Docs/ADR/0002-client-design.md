# ADR 0002 — Client Design

**Status**: Accepted
**Date**: 2025-01-01

## Context

The primary entry point of the SDK must be safe to use from concurrent Swift code,
easy to initialize, and efficient for long-lived use (connection pooling, header reuse).

## Decision

`AnthropicClient` is a `final class` that conforms to `Sendable` rather than an `actor`.

Reasons:
- All mutable state lives in the injected `URLSession` (which has its own thread-safety)
  or in the `ClientConfiguration` value type (immutable after creation).
- `actor` would impose an extra async hop on every property access including the
  service accessor properties (`client.messages`, `client.batches`, …), making
  simple call sites unnecessarily verbose.
- `final class: Sendable` with immutable stored properties achieves the same
  safety guarantees with less overhead.

Two initializers are provided:
- `init(apiKey: String)` — convenience for the common case.
- `init(configuration: ClientConfiguration)` — full control including injecting
  a custom `HTTPClient` for testing.

Service properties (`messages`, `batches`, …) are lazy `let` properties computed
once from the configuration. They are all value types or `Sendable` reference types.

## Consequences

- Callers can safely share a single `AnthropicClient` instance across actors and
  Task trees without `await`.
- To test any service, pass a `MockHTTPClient` in `ClientConfiguration`.
- `AdminServices` is a nested value type aggregating the four admin service objects,
  accessed via `client.admin.workspaces`, `client.admin.apiKeys`, etc.
