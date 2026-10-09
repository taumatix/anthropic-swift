# Upstream

This library is a client for a versioned HTTP API. It is not a port, so there is no source SHA
to pin — what it is bound to is a set of **dated wire contracts**, and those expire. This file
says which ones it was built and checked against, so you can tell whether it still matches the
API you are calling.

```yaml
- name: anthropic-api-version
  kind: literal
  value: "2023-06-01"
  checked: 2026-10-05
  note: >-
    sent as the anthropic-version header on every request;
    ClientConfiguration.defaultAnthropicVersion. Still the newest version in the
    docs' version history on 2026-09-24 (the only other entry is 2023-01-01).

- name: files-api-beta
  kind: literal
  value: "files-api-2025-04-14"
  checked: 2026-10-09
  hold: >-
    RETIRED FROM USE, not stale. FilesService no longer sends this header: with it the
    server keeps the superseded {data, has_more, first_id, last_id} envelope and ignores
    the page token, so token pagination cannot work under it. Types follow the GA
    bodies documented 2026-10-09 (retrieve_metadata, list, upload, delete). NOT yet
    verified against the live API (needs a key); a ROADMAP entry covers it. Restore the
    header with ClientOptions.additionalHeaders if the live check shows a divergence.

- name: skills-api-beta
  kind: literal
  value: "skills-2025-10-02"
  checked: 2026-10-05
  hold: >-
    RETIRED FROM USE, not stale. SkillsService no longer sends this header — it is
    still a live beta value, but the beta endpoint returns the same object and the
    same {data, next_page} envelope as GA, so it changed nothing. Kept pinned so the
    next pass rechecks that claim; restore it with
    ClientOptions.additionalHeaders if it ever diverges again. Rechecked 2026-09-24:
    still in the beta enum (now 48 values), and the beta page's BetaSkill is still
    field-for-field the GA Skill.

- name: anthropic-sdk-python
  kind: github-release
  repo: anthropics/anthropic-sdk-python
  tag: v1.11.0
  checked: 2026-10-05
  note: >-
    not ported from, but read as the reference for new API surface — what it gains,
    this lacks. v1.8.0 (2026-09-22) added claude-opus-5-5, inline tool definitions
    and MCP tool-list pinning; only the model ID landed here. Read 2026-10-01 up to
    v1.11.0 (2026-09-30): claude-sonnet-5-5 and the Sonnet 4.5 deprecation landed
    here. Its v1.10.0 auto-paging fix (continue past an empty page while
    next_page is set) was already true here: Page.AsyncIterator loops until a page
    has an item or no cursor is left. Not here yet, and on ROADMAP.md's
    surface-gaps entry: the between_tools thinking type, and cache diagnostics (now
    GA) on Message and MessageCreateParams. The Admin, Managed Agents and
    MCP-tunnel additions are out of this SDK's scope.

- name: model-ids
  kind: literal
  value: "fable-5-1, opus-5-5, sonnet-5-5, haiku-4-5"
  checked: 2026-10-05
  note: >-
    the four current models per the docs' comparison table; Model.swift carries
    these plus every legacy ID. A model released later still works — Model takes an
    arbitrary string — so this pin costs autocomplete, not functionality.
```

## What each pin means for you

**`anthropic-version: 2023-06-01`** is the stable API version and the default every request
carries. Still the newest version listed in the docs' version history, read on 2026-09-21 — the
only other entry is `2023-01-01`. Override it per client via `ClientConfiguration` if you need a
different one.

**Both beta headers have gone stale, and that was the predicted failure.** The 2026-09-19 pass
wrote these two dates down precisely because a retired beta header fails against the live API while
every test here stays green. Checked by hand against the docs on 2026-09-21, two days later, and
**both APIs have since left beta.**

*Files* — the header is optional now, and this is the benign case: a request that still sends
`files-api-2025-04-14` keeps working and keeps returning the beta shapes. What it costs is what the
GA shape added. `FilesService` therefore:

| | sending the header (what this SDK does) | without it |
|---|---|---|
| list response | `{data, has_more, first_id, last_id}` | `{data, next_page}`, `page` query parameter |
| list cursors | `before_id`, `after_id` | `page`, or up to 100 `ids[]` |
| `expires_at` on a file | never returned | always present, `null` when unset |
| upload `Content-Type` | required | optional, detected |

So a caller of this SDK cannot read a file's expiry or use the GA cursor, and `expires_in_seconds`
at upload is unreachable. Nothing fails; the surface is just a year behind.

*Skills* — **migrated on 2026-09-22, and the framing above it was wrong.**

The 2026-09-21 note said the header was the thing protecting `Skill` from a decoding failure, and
that the docs no longer mentioned `skills-2025-10-02` anywhere. Re-read on 2026-09-22 against
<https://platform.claude.com/docs/en/api/beta/skills/list>, the header **is** still a live beta
value — it appears in that page's `anthropic-beta` enum with 46 others. But the beta page and the
GA page describe **the same object and the same envelope**: `display_name`, `latest_version_id`,
`source`, `updated_at`, `{data, next_page}`. Neither returns `name`. Neither returns `has_more`.

So the header was never load-bearing, and there was no future failure to wait for. `Skill` required
`name` and `Page` required `has_more`, so **every `client.skills` call threw `decodingError` from
the day it shipped**, under either header. The suite stayed green because its fixtures asserted the
shape this SDK had invented.

`SkillsService` now targets GA and sends no `anthropic-beta` header. `Skill` carries the documented
fields, `name` survives as a deprecated alias for `displayName`, and `Page` reads the `next_page`
token alongside the id cursor the other services still use. `SkillDecodingTests` and
`SkillsEndToEndTests` assert Anthropic's literal published response bodies and cite the page each
came from.

Skill **versions** (`skills.versions`: list, get, create, delete) are modelled from the published pages, retrieved 2026-10-09; the beta form (epoch-timestamp addressing) is not.

*Files* — **migrated on 2026-10-09** on the same footing as Skills: `FilesService` sends no
`anthropic-beta` header, `FileObject` decodes the documented `FileMetadata` body, `upload` takes
`expires_in_seconds`, and `list` follows `next_page`. The old `FileObject` could not decode that
body at all (`created_at` is a string, not an integer, and there is no `purpose`), and
`FileDeleteResponse` required a `deleted` field the delete body lacks, so the "benign" framing
above was wrong for the same reason the Skills one was: the header never protected a shape this SDK
had invented. Verified against the docs only; the live check is on the roadmap.

**The documentation moved hosts.** `docs.anthropic.com/en/...` now 301s to
`platform.claude.com/docs/en/...`. Links here and in the README use the new host; an old link still
redirects, so this costs nothing but is worth knowing when a link check fails.

**`anthropic-sdk-python` is a surface reference, not a dependency.** This library was written
against the API directly. The official Python SDK is read to spot API surface that exists and is
not implemented here — its gaining a feature is a signal this lacks one, which no test can
produce.

**Model identifiers are compiled in, and on 2026-09-24 half the current lineup was missing.**
`Sources/Anthropic/Types/Common/Model.swift` carries a list of known model IDs. It is a
convenience, not a constraint — the API takes a string, and `Model` accepts an arbitrary one, so
a model released after this version still works, and the compiled list going stale costs you
autocomplete rather than functionality.

That is why it went stale. The docs' comparison table lists four current models — **Claude Fable
5.1** (`claude-fable-5-1`), **Claude Opus 5.5** (`claude-opus-5-5`), Claude Sonnet 5 and Claude
Haiku 4.5 — and this SDK knew only the last two. `claudeFable5` and `claudeOpus5` had doc comments
calling them "the most capable widely released model" and "the current Opus"; both are on that
page's *legacy* line. Autocomplete was steering callers to superseded models and the prose was
agreeing with it. Both constants are added and both doc comments corrected; nothing was removed.

`claude-mythos-5-1` was **not** added on 2026-09-24. The pricing footnote on that page named
"Claude Mythos 5.1", but no row gave its API ID, and a model constant guessed from a product name
is a 404 at runtime. The ID has since been published on the model's own page, which is not linked
from the comparison table because the model is invite only. `.claudeMythos51` was added on
2026-09-27 from that page.

`ModelTests` now splits current from legacy and cites the page and the date it was read, so the
next stale-list finding is one failing assertion rather than an act of noticing.

## How this file is kept honest

`checked` is bumped on every maintenance pass whether or not anything drifted — an unrefreshed
date cannot be told apart from an unchecked one. The mechanical pins are reported by:

    /Users/taumatix/bootstrap/bin/check-upstream-drift.py <checkout>

The dated header values have no registry to query, so that tool reports them as `REVIEW` and a
human checks them against the vendor's docs. Reporting them as needing a look is honest;
inventing a check that would be wrong is not. On 2026-09-21 that by-hand check is what found both
betas had gone GA — two days after the dates were first written down, and with the test suite green
throughout.

Pages read on 2026-09-21, for whoever checks next:

- <https://platform.claude.com/docs/en/api/versioning> — the `anthropic-version` history
- <https://platform.claude.com/docs/en/build-with-claude/files> — including its
  "Migrate from `files-api-2025-04-14`" section
- <https://platform.claude.com/docs/en/api/skills/list> — the GA Skill object and cursor

Pages read on 2026-09-22, when Skills was migrated:

- <https://platform.claude.com/docs/en/api/skills/list> — GA list, `page`/`next_page`, `source`
- <https://platform.claude.com/docs/en/api/skills/retrieve> — the GA `Skill` object
- <https://platform.claude.com/docs/en/api/skills/create> — `multipart/form-data`, `files[]`
- <https://platform.claude.com/docs/en/api/skills/delete> — the `skill_deleted` object
- <https://platform.claude.com/docs/en/api/beta/skills/list> — the `skills-2025-10-02` shape,
  identical to GA, and the live `anthropic-beta` enum that still contains it

Pages read on 2026-09-24, the maintenance pass that moved every date to the same day:

- <https://platform.claude.com/docs/en/api/versioning> — `2023-06-01` is still the newest entry;
  the history still holds exactly two.
- <https://platform.claude.com/docs/en/build-with-claude/files> — status `ga`, and the
  "Migrate from `files-api-2025-04-14`" table still matches the one reproduced above row for row.
  Migrating stays optional; requests that send the header keep the beta shapes.
- <https://platform.claude.com/docs/en/api/beta/skills/list> — `skills-2025-10-02` is still in the
  `anthropic-beta` enum, which now carries 48 values. `BetaSkill` is still field-for-field the GA
  `Skill`, and `BetaSkillSource` still has the four kinds `SkillSource.Kind` already models.
- <https://platform.claude.com/docs/en/about-claude/models/overview> — the comparison table that
  showed two of the four current model IDs were missing here.

The 2026-09-22 roadmap pass deliberately left `anthropic-api-version` and `files-api-beta` at
2026-09-21, because that pass was about Skills and did not open those pages. That asymmetry is now
gone: all five pins read the same date because all five were actually checked.

Pages read on 2026-09-26, the roadmap pass that hardened `baseURL` and redirects. **Nothing
drifted** — every pin is re-dated, not moved:

- <https://platform.claude.com/docs/en/api/versioning> — `2023-06-01` is still the newest, and the
  history still holds exactly two entries.
- <https://platform.claude.com/docs/en/build-with-claude/files> — still `status: ga`, the header is
  still optional, and the migration table still matches the one reproduced above row for row. One
  addition worth knowing: a request sending `managed-agents-2026-04-01` *without*
  `files-api-2025-04-14` now gets the GA shapes plus a compatibility affordance — `before_id` and
  `after_id` are still accepted, and the list response carries `has_more`, `first_id` and `last_id`
  alongside `next_page`. That does not change what this SDK sends, but it means the Files migration
  entry cannot assume the two cursor styles are mutually exclusive.
- <https://platform.claude.com/docs/en/api/beta/skills/list> — `skills-2025-10-02` is still in the
  `anthropic-beta` enum, still 48 values. `BetaSkill` is still field-for-field the GA `Skill`, and
  `BetaSkillSource` still has the four kinds `SkillSource.Kind` models.
- <https://platform.claude.com/docs/en/about-claude/models/overview> — the same four current models
  this SDK already knows. `claude-mythos-5-1` still appears only in the pricing footnote with no
  API ID, so it still stays unlisted.

Pages read on 2026-09-27, a maintenance pass. Two pins moved, and both were models:

- <https://platform.claude.com/docs/en/api/versioning>: `2023-06-01` is still the newest, and the
  history still has two entries.
- <https://platform.claude.com/docs/en/build-with-claude/files>: still GA, the header is still
  optional, and the migration table still matches the one above.
- <https://platform.claude.com/docs/en/api/beta/skills/list>: `skills-2025-10-02` is still in the
  48-value `anthropic-beta` enum, and `BetaSkill` still matches the GA `Skill` field for field,
  with the same four source kinds.
- <https://platform.claude.com/docs/en/about-claude/models/overview>: the same four current models.
- <https://platform.claude.com/docs/en/models/mythos-5-1/overview>: **moved.** The page gives
  `claude-mythos-5-1` as the API ID, "Invite only. Released September 1, 2026", the same model as
  Fable 5.1 offered through Project Glasswing. Added as `.claudeMythos51`.
- <https://platform.claude.com/docs/en/about-claude/model-deprecations>: **moved.**
  `claude-3-haiku-20240307` shows as Retired on 2026-04-20, but `.claude3Haiku` still warned
  "retires 2026-04-19". The warning now says the model is retired and the API returns 404.
  `claude-haiku-4-5-20251001` is Active, "not sooner than October 15, 2026". That date is a
  minimum-lifetime commitment and no deprecation has been announced. Anthropic gives at least 60
  days' notice, so the next pass should re-read this row.
- `anthropics/anthropic-sdk-python`: v1.8.0 is still the latest release.

Pages read on 2026-10-05, a maintenance pass. **Nothing drifted**, so every pin is re-dated, not
moved:

- <https://platform.claude.com/docs/en/api/versioning>: `2023-06-01` is still the newest, and the
  history still has two entries.
- <https://platform.claude.com/docs/en/build-with-claude/files>: still GA, the header is still
  optional, and the migration table still has the same four rows.
- <https://platform.claude.com/docs/en/api/beta/skills/list>: `skills-2025-10-02` is still in the
  enum, which now has 50 values (`ce-plugins-2026-09-01` and `spend-limit-reads-2026-09-26` are
  new). `BetaSkill` still matches the GA `Skill` field for field, with the same four source kinds.
- <https://platform.claude.com/docs/en/about-claude/models/overview>: the same four current models
  as 2026-10-01, with Sonnet 5.5 the current Sonnet.
- <https://platform.claude.com/docs/en/about-claude/model-deprecations>: Sonnet 4.5 is still the
  only deprecated public model, retiring 2026-11-30. `claude-haiku-4-5-20251001` is still Active
  with no deprecation announced, ten days before its "not sooner than October 15, 2026" date.
- `anthropics/anthropic-sdk-python`: v1.11.0 is still the latest release.
- <https://platform.claude.com/docs/en/api/messages/batches/retrieve>, `/list` and `/results`
  (2026-10-09): `MessageBatch`, the list envelope and the four result outcomes match the documented
  bodies, except `archived_at`, now added. The `errored` outcome nests `error.error.{type,message}`
  as `APIError` already did.

## Models API (checked 2026-10-09)

`ModelInfo` follows <https://platform.claude.com/docs/en/api/models> (list and get `Response (200)`
bodies, retrieved 2026-10-09). Not confirmed against the live API (no key). The `lifecycle` list
filter is not implemented.

## Admin API (checked 2026-10-09)

`OrganizationAPIKey`, `OrganizationInvite`, `OrganizationMember` and `Workspace` follow the
`Response (200)` bodies of the `api_keys`, `invites`, `users` and `workspaces` retrieve, create,
update, delete and archive pages under <https://platform.claude.com/docs/en/api/admin/> (retrieved
2026-10-09). Not confirmed against the live API (no Admin key). The list pages were not read.
