# Upstream

This library is a client for a versioned HTTP API. It is not a port, so there is no source SHA
to pin — what it is bound to is a set of **dated wire contracts**, and those expire. This file
says which ones it was built and checked against, so you can tell whether it still matches the
API you are calling.

```yaml
- name: anthropic-api-version
  kind: literal
  value: "2023-06-01"
  checked: 2026-09-21
  note: >-
    sent as the anthropic-version header on every request;
    ClientConfiguration.defaultAnthropicVersion. Still the newest version in the
    docs' version history on 2026-09-21 (the only other entry is 2023-01-01).

- name: files-api-beta
  kind: literal
  value: "files-api-2025-04-14"
  checked: 2026-09-21
  note: >-
    anthropic-beta header sent by FilesService. STALE: the Files API left beta. The
    header is now optional and requests that send it keep the beta response shapes,
    so nothing is broken — but list stays on has_more/first_id/last_id with
    before_id/after_id cursors and expires_at is never returned. Migrating is a
    ROADMAP entry.

- name: skills-api-beta
  kind: literal
  value: "skills-2025-10-02"
  checked: 2026-09-21
  note: >-
    anthropic-beta header sent by SkillsService. STALE and the riskier of the two:
    the docs no longer mention this header anywhere, and GA /v1/skills returns
    {data, next_page} with display_name, latest_version_id and a source object.
    Whether the header is still accepted is UNVERIFIED — checking needs an API key
    this host does not have. ROADMAP entry.

- name: anthropic-sdk-python
  kind: github-release
  repo: anthropics/anthropic-sdk-python
  tag: v1.7.0
  checked: 2026-09-21
  note: not ported from, but read as the reference for new API surface — what it gains, this lacks
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

*Skills* — the riskier one. The docs no longer mention `skills-2025-10-02` **anywhere**, and GA
`/v1/skills` returns `{data, next_page}` with `display_name`, `latest_version_id`, `updated_at` and
a `source` object (`custom` / `anthropic` / `anthropic_example` / `plugin`). This SDK's `Skill`
requires `name` and `created_at`, and `name` is not in the documented GA object at all — so if the
header stops being honoured, decoding fails outright rather than degrading. **Whether the header is
still accepted is unverified**: confirming it needs a live API key, which this host does not have,
and the integration tests skip themselves without one. `latest_version_id` also points at a Skill
*versions* sub-resource this SDK does not model.

Both migrations are `ROADMAP.md` entries, Skills first. Neither is a small change: the list cursor
type and the `Skill` fields are public API, so they have to grow additively rather than be swapped.

**The documentation moved hosts.** `docs.anthropic.com/en/...` now 301s to
`platform.claude.com/docs/en/...`. Links here and in the README use the new host; an old link still
redirects, so this costs nothing but is worth knowing when a link check fails.

**`anthropic-sdk-python` is a surface reference, not a dependency.** This library was written
against the API directly. The official Python SDK is read to spot API surface that exists and is
not implemented here — its gaining a feature is a signal this lacks one, which no test can
produce.

**Model identifiers are compiled in.** `Sources/Anthropic/Types/Common/Model.swift` carries a
list of known model IDs. It is a convenience, not a constraint — the API takes a string, and
`Model` accepts an arbitrary one, so a model released after this version still works. The
compiled list going stale costs you autocomplete, not functionality.

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
