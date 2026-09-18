# Roadmap

Ordered by how much each entry limits real deployments, not by how interesting it is to build.
Each entry says what breaks today, so it can be judged on its own.

## A test that catches a retired beta header

**Today:** `FilesService` sends `files-api-2025-04-14` and `SkillsService` sends
`skills-2025-10-02`. Both are dated contracts on beta endpoints that Anthropic can retire. When
that happens those two services start failing against the live API and **every test here stays
green**, because the tests assert what this SDK sends, not what Anthropic still accepts. The
first signal would be a user's bug report. `UPSTREAM.md` now at least writes the dates down,
which turns a silent failure into a checkable one, but a human still has to do the checking.

**Why it is not simply fixed:** the check has to reach the real API, and that needs a key. This
is precisely the case the doctrine calls awkward rather than impossible — "it needs auth" is the
reason to spend the effort, not the excuse for leaving the SDK's riskiest contract untested.

**Shape:** a gated live test that sends the minimal request each beta header guards and asserts
the response is not a beta-rejection, skipped with a loud message when no key is present, and run
on a schedule rather than on every PR. A recorded exchange is the fallback if a key cannot be
provisioned, but it proves less and should say so.

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
