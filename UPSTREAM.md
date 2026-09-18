# Upstream

This library is a client for a versioned HTTP API. It is not a port, so there is no source SHA
to pin — what it is bound to is a set of **dated wire contracts**, and those expire. This file
says which ones it was built and checked against, so you can tell whether it still matches the
API you are calling.

```yaml
- name: anthropic-api-version
  kind: literal
  value: "2023-06-01"
  checked: 2026-09-19
  note: sent as the anthropic-version header on every request; ClientConfiguration.defaultAnthropicVersion

- name: files-api-beta
  kind: literal
  value: "files-api-2025-04-14"
  checked: 2026-09-19
  note: anthropic-beta header required by FilesService; a beta header is dated and can be retired

- name: skills-api-beta
  kind: literal
  value: "skills-2025-10-02"
  checked: 2026-09-19
  note: anthropic-beta header required by SkillsService; same expiry risk as above

- name: anthropic-sdk-python
  kind: github-release
  repo: anthropics/anthropic-sdk-python
  tag: v1.7.0
  checked: 2026-09-19
  note: not ported from, but read as the reference for new API surface — what it gains, this lacks
```

## What each pin means for you

**`anthropic-version: 2023-06-01`** is the stable API version and the default every request
carries. Override it per client via `ClientConfiguration` if you need a different one.

**The two beta headers are the fragile part.** `files-api-2025-04-14` and `skills-2025-10-02` are
dated contracts on beta endpoints. Anthropic can retire a beta header, and when that happens
`FilesService` and `SkillsService` start failing against the live API while every test here stays
green — the tests exercise the SDK's behaviour, not Anthropic's current opinion of that header.
If either service returns an unexpected 4xx, check this file's date against the API docs first.

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
inventing a check that would be wrong is not.
