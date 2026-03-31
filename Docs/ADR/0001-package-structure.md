# ADR 0001 — Package Structure

**Status**: Accepted
**Date**: 2025-01-01

## Context

The SDK must be distributable as a Swift Package while also providing test-support
utilities that users should not ship in production builds. Examples need to be
runnable standalone with `swift run`.

## Decision

The package is split into four kinds of targets:

| Target | Kind | Notes |
|--------|------|-------|
| `Anthropic` | library | Core SDK, zero external deps |
| `AnthropicTestSupport` | library | MockHTTPClient and fixtures; importable only in test targets |
| `AnthropicTests` | test | Imports both libraries |
| `BasicChat`, `StreamingChat`, `ToolUse`, `FileUpload`, `BatchProcessing` | executable | Each lives under `Examples/<Name>/` |

`AnthropicTestSupport` is a separate library (not a test target) so that consumer
packages can import it in their own test targets. We recommend consumers add it
to their `testDependencies` only, using Swift Package Manager's `condition: .when(platforms: ...)`.

## Consequences

- Users who import only `Anthropic` get zero test-support symbols in their production app.
- The `AnthropicTestSupport` library cannot import anything except Foundation and Anthropic.
- Each example is a tiny standalone executable that demonstrates one primary feature.
