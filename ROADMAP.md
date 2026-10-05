# Roadmap

Ordered by how much each entry limits real deployments, not by how interesting it is to build.
Each entry says what breaks today, so it can be judged on its own.

## Nothing bounds a whole request

`ClientConfiguration.timeout` is `URLRequest.timeoutInterval`, which bounds the gap between packets
(0.8.0). A stream that trickles one byte a minute never times out. That is probably right for a
streaming API, whose turns can legitimately run for many minutes, but no caller has said so
either way. If one does, the shape is a separate, opt-in total deadline, not a change to
`timeout`: a caller's own Task cancellation already ends a request.

## Ergonomics the Skills GA migration left on the table

Small, additive, and each one removes a class of caller mistake. Grouped because no one of them
justifies a pass on its own.

- **`AnthropicError.invalidRequest(String)`.** `create`'s validation failures are reported as
  `encodingError`, which makes a caller-input mistake look like a serialisation bug. Adding an enum
  case breaks exhaustive `switch`es, so it waits for a major.
- **`SkillFile: Hashable, Codable`** and a public initializer for `SkillSource`. `AnthropicTestSupport`
  is a shipped product, so users write tests against these types; `SkillSource` is `Decodable`-only
  with no public init, and cannot be constructed in a caller's own test.
- **Retire `list(limit:afterId:)` and `create(_:)`.** Both are deprecated and both hit endpoints
  that reject them. `let fn = client.skills.list` still binds to the deprecated overload, so the
  ambiguity only really goes away when it does.

## Model the Skill versions sub-resource

**Today:** `Skill.latestVersionId` is an id this SDK cannot resolve. `GET
/v1/skills/{skill_id}/versions/{version}` and its list sibling exist — `version` accepts a version
id or the literal `latest` — and nothing here reaches them. A caller who wants the SKILL.md a skill
is actually running, or wants to pin a reference to a version rather than to `latest`, has to drop
out of the SDK and use `URLSession` directly.

This is left over from the GA migration that shipped on 2026-09-22; that entry covered the skill
object and the endpoints that return it, and deliberately stopped at versions.

**Why it is not simply done:** the version object's fields have not been read yet, only its
existence. `SkillVersion` must be written from the reference pages the way `Skill` was — against
the published `Response (200)` body, not from the shape of `Skill`.

**Shape:** `SkillVersion`, `client.skills.versions.list(skillID:)` and `get(skillID:version:)`,
with `version` a type that makes `latest` expressible rather than a bare `String`. Tests assert the
documented body and cite the page; the live round trip extends `LiveSkillsTests`.

## Sweep the other services for invented wire shapes

**Today:** the Skills migration found that `Skill` had never matched any response Anthropic
documents — it decoded a `name` key the API does not return, and the suite was green for six months
because the fixtures asserted the same invention. The fixtures were the bug, not the evidence.

**Nothing has checked whether the other services share that defect.** `FileObject`,
`MessageBatch`, `BatchResult`, `APIKey`, `Invite`, `Member`, `Workspace` and `ModelInfo` were all
written the same way at the same time, and every one of their tests uses a hand-written fixture.
`claude-agent-sdk-go` hit this exact shape twice — an invented content-block type that dropped
every server-side tool result, then the same failure one level up in system subtypes.

**Why it is not simply done:** it is eight services against eight reference pages, and the answer
per type is a judgement about how to add a field without breaking a public struct. It is also the
kind of work that goes stale if done as one sweep and never repeated.

**Shape:** one service at a time, ordered by blast radius — `FilesService` first, since it has the
same beta-header history. Per service: read the vendor's `Response (200)` bodies, add a decoding
test asserting those literal bodies with the page cited, and fix what fails. Admin last; it is the
least used. The Files entry below folds into the first slice.

## Migrate `FilesService` off `files-api-2025-04-14`

**Today:** the Files API left beta too, but this one is benign — the header is optional and a
request that still sends it keeps the beta shapes. Nothing fails; surface is missing:

- no `expires_at` on a file object (it is only returned without the header), so a caller cannot see
  when an uploaded file expires,
- no `expires_in_seconds` at upload, so expiry cannot be set at all,
- `before_id`/`after_id` instead of `page`/`next_page`, and no `ids[]` batch lookup,
- `Content-Type` still mandatory on the upload part.

Anthropic documents the migration explicitly
(<https://platform.claude.com/docs/en/build-with-claude/files>, "Migrate from
`files-api-2025-04-14`"), which makes this mostly mechanical — and shares the cursor problem with
the Skills entry above, so do that one first and reuse the answer.

## A test that catches a retired wire contract

**Today:** nothing here reaches the real API, so what Anthropic currently accepts is checked by a
human reading docs once a pass. That worked — the 2026-09-21 pass found both betas had gone GA — but
it worked because a person went looking, two days after the dates were first written down. The tests
assert what this SDK sends, not what the API still honours, and they were green throughout.

**Why it is not simply fixed:** the check has to reach the real API, and that needs a key. This
is precisely the case the doctrine calls awkward rather than impossible — "it needs auth" is the
reason to spend the effort, not the excuse for leaving the SDK's riskiest contract untested.

**Shape:** a gated live test that sends the minimal request each dated contract guards and asserts
the response is neither a beta-rejection nor a shape this SDK cannot decode, skipped with a loud
message when no key is present, and run on a schedule rather than on every PR. A recorded exchange
is the fallback if a key cannot be provisioned, but it proves less and should say so.

**Partly done, for Skills only (2026-09-22).** `LiveSkillsTests` is that test for `/v1/skills`: it
asserts the documented fields are really returned, and compares the `skills-2025-10-02` response
against the GA one so the claim that they are identical fails loudly when it stops being true.
`SkillsEndToEndTests` adds a loopback HTTP server so the transport is exercised without a key.
**Neither has ever run against the live API** — this host has no key, and CI runs `Integration`
only on `main`. What remains: the same treatment for Messages, Files and Models, and a schedule,
because a live test that runs only on merge tells you after the fact.

## Model identifiers go stale silently

**Today:** `Sources/Anthropic/Types/Common/Model.swift` carries a compiled list of model IDs.
`Model` accepts an arbitrary string, so a newly released model still works and nothing breaks —
the cost is autocomplete and discoverability, which is why this sits below the beta headers.
A model that is *retired*, though, stays in the list looking supported.

**It already happened, and worse than "costs autocomplete" predicted.** On 2026-09-24 the docs'
comparison table listed four current models and this SDK knew two of them; `claude-fable-5-1` and
`claude-opus-5-5` were both absent. Worse than the missing constants: `claudeFable5`'s and
`claudeOpus5`'s doc comments still called them "the most capable widely released model" and "the
current Opus" while the same page filed both under *legacy*. So autocomplete steered callers to
superseded models and the documentation agreed with it. Fixed by hand that day, with
`ModelTests` split into current and legacy and citing the page and date — which turns the next
occurrence into a failing assertion rather than an act of noticing, but only for a human who
re-reads the page. The entry below is still the mechanical answer.

**Shape:** a test that calls `client.models.list()` and reports IDs the API returns that the enum
lacks, and enum cases the API no longer returns. Same auth problem as above, same gated-run
answer. Deprecation belongs in the type, not in a changelog.

## Surface gaps against the official SDK

**Today:** `UPSTREAM.md` pins `anthropic-sdk-python` at `v1.8.0` as a surface reference, but
nothing compares the two. The SDK claims all GA APIs plus Files, Skills and Admin; whether that
is still true after an upstream release is unverified.

Two named gaps from v1.8.0's release notes (2026-09-22), neither implemented here and neither
covered by issue #4's `MessageRequest` catalogue: **inline tool definitions** and **MCP tool-list
pinning**, both beta. The `anthropic-beta` enum read on 2026-09-24 carries `inline-tools-2026-09-15`
and `mcp-client-2026-09-15`, which is where a reader can check what they are before anyone builds
them here.

Two more from v1.9.0 (2026-09-28), both on the Messages API this SDK covers: the
**`between_tools` thinking type**, and **cache diagnostics**, which are now GA and appear on
`Message` and `MessageCreateParams`. Both were read from the release notes on 2026-10-01 and not
yet from the API reference, so check their shape there before building either.

**Shape:** diff this SDK's service methods against the official SDK's, record the result as
entries here, and keep the comparison as a checked-in inventory rather than a one-off reading —
the same shape as the drift problem it exists to catch.

## Streaming, retries, and the things a client needs under load

**Today:** to be filled in from the code rather than guessed. The three entries above came from
`UPSTREAM.md` work on 2026-09-19 and are what is *known* to limit deployments; this repo has not
yet had a roadmap pass that read the source properly.

**Shape:** the next roadmap pass reads `Sources/Anthropic` — retry policy, backoff, streaming
backpressure, cancellation, error typing — and replaces this placeholder with real entries.
An entry written from the code is worth more than one guessed before reading it.

## A custom `HTTPClient` can opt out of the origin check by saying nothing (for 1.0)

**Today:** a unary response with no `HTTPResponse.url` passes the origin check, and a client that
does not implement `stream(_:validatingResponseFrom:)` streams unchecked. 0.9.0 settled the
non-breaking half: no deprecation of the URL-less initializer (it would warn on every test double,
90 in this repo alone), `MockHTTPClient(responseURL:)` so tests can see the check, a test pinning
that `URLSessionHTTPClient` calls the `validate` it is given, and the 1.0 change announced in the
README and CHANGELOG.

Related, since 0.10.0: the pipeline enforces the plaintext policy on the configured `baseURL`
for every client, but a custom client may route a path-relative `HTTPRequest` anywhere it likes.
Handing the client the base URL, the same change the mock needs below, would let the pipeline
check the URL a request is actually for.

**Shape, at 1.0:** treat a `nil` URL as a refusal, and make `stream(_:validatingResponseFrom:)` a
requirement with no default. `MockHTTPClient` then needs a default `responseURL`, the configured
base URL, which it cannot know today because `HTTPRequest` is path-relative; the likeliest answer
is for the pipeline to hand the base URL to the client. Record all of it in a `MIGRATION.md`.
