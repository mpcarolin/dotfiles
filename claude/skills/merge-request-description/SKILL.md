---
name: merge-request-description
description: Use when writing a merge request description, MR summary, or PR description for a feature branch. Triggers on "write MR description", "MR description", "PR description", "describe these changes for merge", or when preparing branch changes for reviewer consumption.
user_invocable: true
---

# Merge Request Description

Generate a reviewer-friendly merge request description from the current branch's diff against `main`.

## Process

### Phase 1: Gather Changes

```bash
git log main..HEAD --oneline
git diff main...HEAD --stat
git diff main...HEAD
```

For large diffs (>100KB), read changed files individually. Skip lock file contents (`*.lock`, `pdm.lock`) — just note they were regenerated.

Read commit messages carefully — they contain intent and motivation that belongs in the Context section.

Find the Jira ticket in the branch name or commit messages. If there is none, **ask for it before writing anything**; the Context bullet and the saved filename both need it.

### Phase 2: Analyze Intent

Before writing, answer these questions (do NOT include them in the output):

1. **Why** do these changes exist? What did the user or the deploy see go wrong, or what can they do now that they could not before?
2. **What** are the logical change groups? (features, fixes, config, infrastructure, tests)
3. **How** does a tester prove it inside an AIO? Which modes matter, which commands read the state, what exact output means success?

### Phase 3: Write the Description

Output a single markdown document with exactly three sections: **Context**, **Updates**, and **Testing**.

#### Context

Exactly three bullets unless there is a real reason for more:

1. `Closes: <full Jira ticket URL>`
2. One sentence on what was broken or missing, stated as its observed impact ("broke a deploy", "the report showed stale totals"), not the mechanism.
3. One sentence starting "This MR adds/fixes ..." that says what capability now exists.

No root-cause chains, no file names, no per-environment nuance. If a reviewer needs the mechanism or an edge-case default, it goes in Updates on the file that implements it.

```markdown
## Context

* Closes: https://i360dataops.atlassian.net/browse/RAG-1195
* The `v4portal` prism config declares a `mock-reporting` connection whose secret doesn't exist on `prod`, so this broke a deploy.
* This MR adds an optional per-connection `environments` property to connection specs in the YAML, so a connection is only created if it includes the active environment
```

**Not this:**
```markdown
## Context

* Closes: https://i360dataops.atlassian.net/browse/RAG-1195
* The secret is fetched before the connection row is written and the sync swallows errors per file, so one failed lookup made the entire v4portal file (parameters, datasets, dashboards) silently fail to sync in test and prod
* A missing or empty list means every mode, matching the top-level key; an unknown mode name is skipped with a log line rather than rejected
```

#### Updates

Bulleted list of **what** changed. Each file is a bullet with its path, and sub-bullets describe what changed in that file.

```markdown
## Updates

* `repos/cli/cli/services/app.py`
  * `_upsert_connections` now takes `mode` and skips any connection whose `environments` list is set and does not contain it. A missing or empty list means the connection is created in every mode, matching the top-level `environments` key
* `configs/prism/v4portal.yaml`
  * `mock-reporting` gets `environments: [mock]`
  * Only the mock connection is gated this way.
* `repos/cli/tests/commands/prism/test_connection_environments.py` (new)
  * Unit tests for the gate
```

Rules:
- Behavioral nuance (defaults, empty-list handling, what a typo does) lives here on the file that implements it, never in Context.
- Test files get one sub-bullet ("Unit tests for the gate"). Never list cases; tests are not the review focus.
- When a config change applies to one entry among many, say so ("Only the mock connection is gated this way").

#### Testing

Everything runs inside AIO containers. Never host compose, dev servers, or `prism create` on the host.

Leave out anything a dev has already done to be a dev: unit tests (CI runs them), `pdm ror task creds`, installs, config-file edits under `~/.config`.

`### Setup` follows this recipe, with one fresh AIO per mode the change cares about:

* **Rebuild only when needed.** Include `pdm ror aio build` when the branch changes something the container cannot pick up from `--watch` sync: the Dockerfile, dependency lockfiles, or anything the boot seed runs before watch's initial sync lands (CLI, prism configs, deploy scripts, migrations). Runtime-only changes to the UI, dashboards, threads, or nats are live-synced and do not need it.
* Start one AIO per mode, each fresh so the seed really runs. Mock goes on offset 0 (the e2e suite needs it), everything else on `--offset 100`, `200`, ...
* One blocking wait bullet per container, never a combined one.

`### Verify` is numbered. Every step names a command and the exact output that means success:

* Read state with `docker exec ror-aio-<name> pdm ror ...` and `docker logs ror-aio-<name> 2>&1 | grep ...`.
* Quote the expected log line or table row.
* Include the e2e suite whenever the change touches prism config, prism CLI sync, dashboards, or the prism UI, with the expected pass count.
* No "confirm it renders as before" steps. A UI check names the page, the element, and what it shows, or it is left out.

The description ends at the last Verify step. Operational follow-ups (stale rows to clean up, things to run after merge) go in the chat reply, not the description.

```markdown
## Testing

### Setup

* Build the AIO image from this branch: `pdm ror aio build`
* Start a fresh mock-mode AIO on offset 0: `RAG_AIO_FRESH=1 MODE=mock pdm ror aio run -d --name e2e`
* Start a fresh local-mode AIO on another offset: `RAG_AIO_FRESH=1 pdm ror aio run -d --name ui --offset 100`
* Wait for the mock AIO to finish seeding (blocks until the line appears, a few minutes on first boot):
  ```
  docker logs -f ror-aio-e2e 2>&1 | grep -m1 '\[aio-seed\] complete'
  ```
* Wait for the local AIO the same way:
  ```
  docker logs -f ror-aio-ui 2>&1 | grep -m1 '\[aio-seed\] complete'
  ```

### Verify

1. In the local AIO, the seed log shows the connection being skipped:
   ```
   docker logs ror-aio-ui 2>&1 | grep 'Skipping connection'
   ```
   Expect `Skipping connection mock-reporting: not configured for environment local`
2. `docker exec ror-aio-ui pdm ror prism connections list --app v4-portal` shows `dev-reporting` only
3. `docker exec ror-aio-e2e pdm ror prism connections list --app v4-portal` shows `mock-reporting`
4. Run the e2e suite against the mock AIO: `cd repos/tests/e2e && PRISM_BASE_URL=http://localhost:3011 pnpm test`, all 57 tests pass
```

## Output and File Saving

The final output should be **only** the markdown description — no preamble, no "here's the MR description", no wrapper. Just the three sections.

Save the description to `~/Development/notes/mr-descriptions/` with the naming pattern `RAG-{ticket}-{short-slug}.md`. If there are associated screenshots, save those alongside with the prefix `RAG-{ticket}-`.

## Formatting Rules

- **No conventional commit prefixes** in MR titles (no `feat():`, `fix():`, etc.) — but always start with the Jira key (e.g. `RAG-707: Fix survey name overflow`)
- **No "Generated with Claude Code" footer** or any tool attribution
- **Context is three bullets** — ticket link, impact, "This MR adds/fixes"
- **Updates list files** as bullets with sub-bullets for what changed in each file
- **Verify steps are numbered** — not bulleted

## Common Mistakes

- Writing prose paragraphs in Context instead of a bulleted list
- Forgetting `Closes: <URL>` as the first Context bullet, or guessing instead of asking when no ticket is found
- Explaining the failure mechanism in Context instead of the impact
- Writing a file-by-file changelog in Updates without sub-bullets explaining what changed
- Listing test cases under a test file in Updates
- Testing steps that run on the host instead of inside an AIO
- Telling the tester to run unit tests or refresh AWS credentials
- Including `pdm ror aio build` when watch sync would pick the change up, or leaving it out when the seed path changed
- A single "wait for both" bullet instead of one blocking command per container
- Using bullets instead of numbered steps in Verify
- Vague UI steps like "confirm it renders as before"
- A trailing note after Verify
- Adding a Claude Code footer or commit-style prefixes in titles
