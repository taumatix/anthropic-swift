# Upstream

This library is a client for a versioned HTTP API. It is not a port, so there is no source SHA
to pin — what it is bound to is a set of **dated wire contracts**, and those expire. This file
says which ones it was built and checked against, so you can tell whether it still matches the
API you are calling.

```yaml
- name: anthropic-api-version
  kind: literal
  value: "2023-06-01"
  checked: 2026-09-24
  note: >-
    sent as the anthropic-version header on every request;
    ClientConfiguration.defaultAnthropicVersion. Still the newest version in the
    docs' version history on 2026-09-24 (the only other entry is 2023-01-01).

- name: files-api-beta
  kind: literal
  value: "files-api-2025-04-14"
  checked: 2026-09-24
  note: >-
    anthropic-beta header sent by FilesService. STALE: the Files API left beta. The
    header is now optional and requests that send it keep the beta response shapes,
    so nothing is broken — but list stays on has_more/first_id/last_id with
    before_id/after_id cursors and expires_at is never returned. Migrating is a
    ROADMAP entry.

- name: skills-api-beta
  kind: literal
  value: "skills-2025-10-02"
  checked: 2026-09-24
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
  tag: v1.8.0
  checked: 2026-09-24
  note: >-
    not ported from, but read as the reference for new API surface — what it gains,
    this lacks. v1.8.0 (2026-09-22) added claude-opus-5-5, inline tool definitions
    and MCP tool-list pinning; only the model ID landed here.

- name: model-ids
  kind: literal
  value: "fable-5-1, opus-5-5, sonnet-5, haiku-4-5"
  checked: 2026-09-24
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

Still open: skill **versions**. `latest_version_id` points at a sub-resource this SDK does not
model, so a version id cannot be resolved. That is a `ROADMAP.md` entry.

The *Files* migration remains a `ROADMAP.md` entry. It is the benign one, and the cursor work
landed here is most of what it needs.

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

`claude-mythos-5-1` is **not** added. The pricing footnote on that page names "Claude Mythos 5.1",
but no row gives its API ID, and a model constant guessed from a product name is a 404 at runtime.
It stays unlisted until an ID is published; `Model(rawValue:)` reaches it meanwhile.

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
gone: all five pins read 2026-09-24 because all five were actually checked.
