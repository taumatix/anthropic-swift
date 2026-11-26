# Running the live suite

Everything else in this repository runs against mocks or a loopback server. These tests are the
only ones that talk to `api.anthropic.com`, so they are the only ones that can say what Anthropic
actually serves. **They had never been run before 1.0.** Run them before tagging a release.

## Run

    export ANTHROPIC_API_KEY=sk-ant-...        # a key for a workspace you can afford to test in
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Live

Without a key every `Live*` test is skipped and the command exits 0, so read the summary: it must
say tests *passed*, not only *skipped*. `--filter Integration` selects nothing; use `Live`.

Optional, each needs its own opt-in because it touches more than it creates and deletes itself:

    ANTHROPIC_SKILLS_WRITE_TESTS=1             # creates and deletes a skill and its versions
    ANTHROPIC_ADMIN_API_KEY=sk-ant-admin-...   # read-only Admin endpoints (members, workspaces)

## What each file checks, and what it costs

| Class | Checks | Cost |
|---|---|---|
| `LiveMessagesTests` | create, count tokens, list models | a few Haiku tokens |
| `LiveStreamingTests` | SSE stream decodes end to end through the real transport | a few Haiku tokens |
| `LiveModelsTests` | list/get decode; every constant this SDK calls current is still served | free |
| `LiveFilesTests` | upload, get, `list(ids:)`, download, delete, with no beta header | free |
| `LiveBatchesTests` | create, get, cancel, list | at most a few Haiku tokens |
| `LiveSkillsTests` | list, versions, (opt-in) create/delete round trip | free |

The 1.0 change that most needs a live run: a response with no `url` is now refused. `URLSession`
supplies it, so every test above doubles as proof the production transport still passes the check.

## Report back

Paste the final `Executed N tests, with M failures` line and the text of any failure. A failure
is a **finding**, not necessarily a bug in the test: it means the real API differs from the
documentation this SDK was built from. Say so and it goes on `ROADMAP.md` as the next entry.
