# Roadmap

Ordered by how much each entry limits real deployments, not by how interesting it is to build.
Each entry says what breaks today, so it can be judged on its own.

## `baseURL` now routes traffic, and nothing guards where it points

**Today:** until 2026-09-22 `baseURL` was ignored, so neither of these mattered. Now it decides
where the SDK sends the caller's API key, and there are two ways to lose it:

- **No scheme check.** `ClientOptions.baseURL(URL(string: "http://gateway")!)` sends `x-api-key`
  in cleartext. An app that reads its endpoint from config or an environment variable can be
  downgraded by whoever controls that value.
- **No redirect policy.** `URLSessionHTTPClient` installs no `URLSessionTaskDelegate`, so
  `URLSession` follows redirects and carries the custom `x-api-key` header onto the target,
  including a cross-host one. A gateway — or anyone able to answer on a plaintext one — can `302`
  the SDK to a host it controls and harvest the key. This applies to the default endpoint too; the
  custom-`baseURL` case merely widens who can trigger it.

**Why it is not simply done:** the loopback end-to-end tests deliberately use `http://127.0.0.1`,
so a scheme check needs a loopback exemption that is not itself a bypass. The redirect delegate has
to cover `URLSession.bytes(for:)` as well as `data(for:)`, so streaming needs the same treatment,
and `URLSession.shared` cannot carry a per-client delegate — which ties this to the entry below.

**Shape:** reject a non-`https` `baseURL` unless its host is loopback; add a delegate that strips
`x-api-key` and `anthropic-*` headers when a redirect changes host. Test both over the loopback
server — a 302 to a second listener, asserting the second never sees the key.

## Configuration that is stored and never applied

**Today:** `ClientConfiguration.timeout` is written, documented as "Default: `600` (10 minutes, for
streaming)", and **never reaches the network layer**. The SDK's own `URLSessionHTTPClient` is built
with `URLSession.shared`, whose `timeoutIntervalForRequest` is 60 seconds. So
`ClientOptions.timeout(600)` does nothing, and a long streaming turn dies at 60s having been
promised ten minutes — as a `URLError` mapped to `AnthropicError.timeout`, which reads like the
server was slow rather than like the SDK ignored the setting.

This is the same defect as the `baseURL` one fixed on 2026-09-22, and finding a second instance is
why it is at the top: `ClientConfiguration` is a bag of stored properties, and nothing checks that
any of them is wired to anything. `retryPolicy` and `maxRetries` *are* honoured, by
`RequestPipeline`. `timeout` is not honoured by anyone.

**Why it is not simply done:** building a per-configuration `URLSession` instead of sharing
`.shared` changes connection pooling and cookie/cache scope, so it is a behaviour change beyond the
one property. The timeout also has two meanings — per-request and per-resource — and streaming
wants them set differently from unary calls.

**Shape:** construct the session from the configuration (`timeoutIntervalForRequest` for unary,
`timeoutIntervalForResource` for streaming), rebuilt on assignment the way `baseURL` now is. Then
the test that would have caught both: assert, for every public property of `ClientConfiguration`,
that changing it changes an observable request or client property. A property nothing reads is the
bug this entry is really about.

## Ergonomics the Skills GA migration left on the table

Small, additive, and each one removes a class of caller mistake. Grouped because no one of them
justifies a pass on its own.

- **`SkillFile.directory(at:)`.** Creating a skill currently means reading each file, guessing a
  MIME type, and hand-assembling the `"my-skill/SKILL.md"` prefix on every entry — the README
  example is twelve lines of ceremony. A directory is the natural unit, and walking it is also what
  makes the `SKILL.md`-present check meaningful rather than advisory.
- **`AnthropicError.invalidRequest(String)`.** `create`'s validation failures are reported as
  `encodingError`, which makes a caller-input mistake look like a serialisation bug. Adding an enum
  case breaks exhaustive `switch`es, so it waits for a major.
- **`SkillFile: Hashable, Codable`** and a public initializer for `SkillSource`. `AnthropicTestSupport`
  is a shipped product, so users write tests against these types; `SkillSource` is `Decodable`-only
  with no public init, and cannot be constructed in a caller's own test.
- **Retire `list(limit:afterId:)` and `create(_:)`.** Both are deprecated and both hit endpoints
  that reject them. `let fn = client.skills.list` still binds to the deprecated overload, so the
  ambiguity only really goes away when it does.
- **`Page` iteration has no loop guard.** A server that returns the same `next_page` token twice
  makes `for try await` spin forever, issuing requests and never yielding a terminal condition —
  found by writing a test whose mock replayed one fixture, which hung the suite until it was
  killed. A real server terminating is not a guarantee the SDK should rely on. Cheapest fix is to
  stop when a token repeats and to check `Task.isCancelled` each time round, so a caller can at
  least cancel out.

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

**Shape:** a test that calls `client.models.list()` and reports IDs the API returns that the enum
lacks, and enum cases the API no longer returns. Same auth problem as above, same gated-run
answer. Deprecation belongs in the type, not in a changelog.

## Surface gaps against the official SDK

**Today:** `UPSTREAM.md` pins `anthropic-sdk-python` at `v1.7.0` as a surface reference, but
nothing compares the two. The SDK claims all GA APIs plus Files, Skills and Admin; whether that
is still true after an upstream release is unverified.

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
