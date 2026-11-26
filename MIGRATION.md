# Migrating to 1.0

1.0 removes what 0.x deprecated and tightens one safety check. Everything below is a compile error or
an explicit runtime refusal, never a silent change in what a request sends. Nothing about the wire
format changed.

## 1. A response that does not say where it came from is refused

A response with no `HTTPResponse.url` now fails with `AnthropicError.networkError`
(`URLError.badServerResponse`). Before, it passed unchecked.

**Only custom `HTTPClient`s are affected.** `URLSessionHTTPClient` always reports the URL.

    // Before: url omitted, response accepted unchecked
    HTTPResponse(statusCode: http.statusCode, body: data)
    // After
    HTTPResponse(statusCode: http.statusCode, body: data, url: http.url)

For routing, `HTTPRequest` now carries `baseURL: URL?`, set by the pipeline to the configured base
URL, so a client that builds its own URLs can resolve the path against the right origin.

**Test doubles:** `MockHTTPClient` and `RecordingHTTPClient` (from `AnthropicTestSupport`) report the
request's `baseURL` by default, so tests that use them need no change. A hand-written test double
must set `url:`. To see a transport that reports nothing being refused, set
`MockHTTPClient.reportsResponseURL = false`.

## 2. `HTTPClient.stream(_:validatingResponseFrom:)` is required

It is now a protocol requirement with no default. `stream(_:)` is no longer a requirement: it is an
extension method that calls the validating one with a no-op validator.

A client that implemented only `stream(_:)` no longer conforms. Replace it with:

    func stream(
        _ request: HTTPRequest,
        validatingResponseFrom validate: @escaping @Sendable (URL?) throws -> Void
    ) -> AsyncThrowingStream<Data, Error> {
        // ... perform the request, then before yielding any byte:
        try validate(response.url)
    }

## 3. `AnthropicError.invalidRequest(String)`

New case, for caller input refused before anything is sent. Skill uploads that lack a root
`SKILL.md`, name a path outside the skill, or are otherwise malformed used to throw `.encodingError`,
which looked like a serialisation bug; they now throw `.invalidRequest`.

- An exhaustive `switch` over `AnthropicError` needs the new case.
- Code that caught `.encodingError` to detect a bad skill upload must catch `.invalidRequest`.

## 4. `BatchResultOutcome.unknown(type:)`

A batch result whose `type` this SDK does not recognise now decodes as `.unknown(type:)`. It used to
decode as `.canceled`, hiding a new outcome kind as a cancellation. An exhaustive `switch` needs the
new case; a `switch` with `default` is unaffected.

## 5. Removed deprecated API

| Removed | Use instead |
|---|---|
| `client.skills.create(_: CreateSkillRequest)` and `CreateSkillRequest` | `client.skills.create(files:displayName:)` |
| `client.skills.list(limit:afterId:)` | `client.skills.list(limit:)`, which pages by `page` token |
| `client.files.list(limit:afterId:beforeId:)` | `client.files.list(limit:pageToken:)` |
| `Skill.name` | `Skill.displayName` |
| `FileObject.purpose` | none; the API no longer returns it |

Decoding a response that still carries a legacy `name` key continues to work: it fills `displayName`.
