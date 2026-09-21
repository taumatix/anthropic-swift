# Roadmap

Ordered by how much each entry limits real deployments, not by how interesting it is to build.
Each entry says what breaks today, so it can be judged on its own.

## Move `SkillsService` onto the GA Skills API

**Today:** it sends `anthropic-beta: skills-2025-10-02` on every call, and the docs no longer
mention that header anywhere — the Skills API has left beta (checked by hand 2026-09-21 against
<https://platform.claude.com/docs/en/api/skills/list>). This is first on the list because it is the
only entry here that can fail *hard*:

- `Skill` requires `name` and `created_at`. The documented GA object has **no `name`** — it carries
  `display_name`, `latest_version_id`, `source` (an object: `custom`, `anthropic`,
  `anthropic_example`, `plugin`), `created_at` and `updated_at`. If the header stops being honoured,
  decoding throws instead of degrading.
- `list(limit:afterId:)` sends `after_id` and decodes `has_more`/`first_id`/`last_id`. GA paginates
  with `page` and returns `{data, next_page}`.
- `latest_version_id` points at a Skill *versions* sub-resource this SDK does not model at all.

**Whether the beta header still works today is unverified**, and that is the part to settle first:
it needs a live key, which this host does not have and the integration tests skip without.

**Why it is not simply done:** `Skill`'s stored properties and `Page`'s cursor are public API.
`name` cannot simply become `displayName`, and the cursor cannot simply change type. It has to grow
additively — new optional fields, a cursor that accepts either form — with the beta path kept until
a major version removes it. A break here needs an issue and review, not a commit.

**Shape:** add the GA fields as optionals, teach `Page` the `page`/`next_page` cursor alongside the
id cursor, stop sending the header by default with an opt-in to restore it, then model skill
versions. Verified against the live API under a key, because a mock cannot tell you which shape
Anthropic is actually returning.

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
