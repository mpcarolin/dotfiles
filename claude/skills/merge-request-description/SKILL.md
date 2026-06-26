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

### Phase 2: Analyze Intent

Before writing, answer these questions (do NOT include them in the output):

1. **Why** do these changes exist? What problem do they solve or what capability do they add?
2. **What** are the logical change groups? (features, fixes, config, infrastructure, tests)
3. **How** should a reviewer test this? What services need starting, what config needs changing, what should they observe?

### Phase 3: Write the Description

Output a single markdown document with exactly three sections: **Context**, **Updates**, and **Testing**.

#### Context

A **bulleted list**. The first bullet is always `Closes: <full Jira ticket URL>` — if a Jira ticket was provided or can be inferred from the branch name. Remaining bullets describe motivation: what problem is being solved, what capability is being added. Write for someone who hasn't seen the code. No file paths or implementation details.

```markdown
## Context

* Closes: https://i360dataops.atlassian.net/browse/RAG-123
* Adds comprehensive E2E tests for the Daily Topline and Grassroots View dashboards using Playwright, with a shared test factory pattern to avoid duplication
```

**Not this:**
```markdown
## Context

This PR adds E2E tests for the dashboards. The changes include modifications to several files...
```

#### Updates

Bulleted list of **what** changed. Each file is a bullet with its path, and sub-bullets describe what changed in that file.

```markdown
## Updates

* `configs/prism/v4portal.yaml`
  * Added `overflowWrap: "anywhere"` to the Survey Name column `sx` config
* `repos/prism/repos/app/mocks/reports.ts`
  * Added `overflowWrap: 'anywhere'` in the mock report data to match the config
```

#### Testing

A section with a `### Setup` subsection containing exact setup commands (config changes, backend/frontend start), followed by a `### Verify` subsection with **numbered steps** describing what to do and what to observe.

```markdown
## Testing

### Setup

* Ensure mocks are disabled in `~/.config/ragorama/values.yaml`:
  ```
  RAG_PM_API_MOCK: 0
  RAG_PM_API_MOCK_DEBUG: 0
  ```
* Start backend: `pdm ror prism start -rc -w`
* Load the YAML: `pdm ror prism create --file "./configs/prism/v4portal.yaml"`
* Start app: `cd repos/prism && pnpm start`

### Verify

1. Navigate to Grassroots Reporting > Survey View
2. Find a survey with a long single-word name
3. The name should wrap within the column rather than overflowing past the boundary
```

**Key principles for Testing:**
- Setup should include config changes, service start commands, and any data loading steps
- Verify steps are **numbered** (not bulleted) — they are a sequential walkthrough
- Be specific about expected behavior — don't just say "test it", say what success looks like
- Include config blocks inline when the reviewer needs to add/change configuration

## Output and File Saving

The final output should be **only** the markdown description — no preamble, no "here's the MR description", no wrapper. Just the three sections.

Save the description to `~/Development/notes/mr-descriptions/` with the naming pattern `RAG-{ticket}-{short-slug}.md`. If there are associated screenshots, save those alongside with the prefix `RAG-{ticket}-`.

## Formatting Rules

- **No conventional commit prefixes** in MR titles (no `feat():`, `fix():`, etc.) — but always start with the Jira key (e.g. `RAG-707: Fix survey name overflow`)
- **No "Generated with Claude Code" footer** or any tool attribution
- **Context is always a bulleted list** — first bullet is always the Jira ticket link
- **Updates list files** as bullets with sub-bullets for what changed in each file
- **Verify steps are numbered** — not bulleted

## Common Mistakes

- Writing prose paragraphs in Context instead of a bulleted list
- Forgetting `Closes: <URL>` as the first Context bullet
- Writing a file-by-file changelog in Updates without sub-bullets explaining what changed
- Using bullets instead of numbered steps in Verify
- Omitting the Setup subsection in Testing
- Being too terse in Testing — reviewers need exact commands and expected results
- Including implementation details in Context (save those for Updates)
- Adding a Claude Code footer or commit-style prefixes in titles
