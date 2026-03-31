# ADR 0004 — Type System Design

**Status**: Accepted
**Date**: 2025-01-01

## Context

The Anthropic API returns polymorphic content blocks (`text`, `image`, `tool_use`,
`tool_result`, `document`, `thinking`) and will add new types over time. The SDK
must represent these safely in Swift without crashing on unknown types.

Model identifiers (`claude-3-5-sonnet-20241022`, custom fine-tuned models) need both
autocomplete for known values and openness to arbitrary strings.

## Decisions

### ContentBlock — Discriminated Union with Forward-Compat Case

`ContentBlock` is an `enum` with one case per known block type plus:
```swift
case unknown(type: String, rawData: AnyJSONValue)
```
Custom `Codable` reads the `"type"` discriminator and falls through to `.unknown`
for any unrecognised value. This guarantees that future API additions never crash
existing SDK versions.

`AnyJSONValue` is a thin wrapper around Foundation's `Any` (arrays, dicts, strings,
numbers) to carry the raw JSON payload forward without requiring a concrete type.
It is `@unchecked Sendable` — safe because JSONSerialization only produces
immutable-in-practice Foundation objects.

### Model — RawRepresentable + ExpressibleByStringLiteral

```swift
struct Model: RawRepresentable, ExpressibleByStringLiteral, Sendable, Codable {
    var rawValue: String
}
extension Model {
    static let claude4Opus: Model = "claude-opus-4-6"
    static let claude4Sonnet: Model = "claude-sonnet-4-6"
    // ...
}
```
Callers get autocomplete for known models and can pass custom strings:
```swift
let request = MessageRequest(model: "my-fine-tuned-model", ...)
```

### Separate Request and Response Types

`MessageRequest` is `Encodable`; `MessageResponse` is `Decodable`. They share no
base class and have no optional fields to accommodate the "other direction".
Keeping them separate avoids the proliferation of optionals that would result from
trying to make one type serve both roles.

## Consequences

- Adding a new `ContentBlock` case is a non-breaking change (new case + unknown fallback).
- Removing a `ContentBlock` case IS a source-breaking change and requires a major version bump.
- `Model` string constants live in `Types/Common/Model.swift` alongside their raw string values,
  making it trivial to add new models with a one-line addition.
