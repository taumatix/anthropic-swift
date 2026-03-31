# ADR 0007 — Pagination Design

**Status**: Accepted
**Date**: 2025-01-01

## Context

Several Anthropic API endpoints (models, batches, files, admin resources) return
cursor-based paginated lists using `first_id`, `last_id`, and `has_more` fields.
Callers should be able to iterate all items across pages without manually managing
cursors.

## Decision

`Page<T: Sendable & Decodable>` conforms to `AsyncSequence` and drives multi-page
iteration transparently:

```swift
for try await model in try await client.models.list() {
    print(model.id)
}
```

Internally, `Page` stores:
- The current page's `data: [T]` array.
- `hasMore: Bool`.
- `lastId: String?` — the cursor to pass as `after_id` for the next page.
- An optional `@Sendable (_ afterId: String?) async throws -> Page<T>` closure
  that fetches the next page.

The `AsyncIterator` exhausts the current `data` array, then calls the fetcher if
`hasMore == true`, replacing the current page and continuing iteration.

`Page` is also `Decodable` so that service methods can decode the raw JSON response
directly into a `Page<T>` using the shared `JSONCoding.decoder`.

## Consequences

- Callers that only need the first page can call `.prefix(N)` or break early — the
  next-page HTTP request is never made.
- The `nextPageFetcher` closure is injected by service methods, keeping the
  pagination logic in the service layer rather than in the generic `Page` type.
- If `nextPageFetcher` is `nil` (e.g., when creating a `Page` directly in tests),
  iteration stops after the first page regardless of `hasMore`.
