---
name: commit-by-commit-review
description: Walk a feature branch with the user one commit at a time for code review. Present each commit's diff, gather feedback, apply requested changes, confirm with the user before amending. Use when the user says "review my changes one commit at a time", "let's go through these commits one by one", "present your code for review", or after proposing a commit sequence and the user wants to walk through it.
user_invocable: true
---

# Commit-by-Commit Review

An **orchestrated, multi-agent, token-light** workflow for walking a feature branch with the user, commit by commit. The user reviews each commit, leaves feedback (arbiter notes, inline working-tree comments, or verbal), and you apply it — but **you do not amend or rebase until the user explicitly confirms**. Each commit is a small back-and-forth conversation, not a batch operation.

The defining constraint: the **orchestrator at top level stays token-light and roughly constant** across the whole branch. It never reads a full commit diff, never reads full new files, never runs the edit churn itself. All heavy work — reading diffs, editing the working tree, investigating open questions — lives in **ephemeral subagent contexts**, and only compact results return. This mirrors the sibling `branch-step-review` skill's presenter/subagent discipline, extended from review-only to a workflow that also **edits code and amends commits**.

The four cooperating roles:

- **Orchestrator** (you, top level) — drives the loop, holds only durable per-commit state, dispatches subagents with the right skills + context, owns git-history mutation and the confirmation gate.
- **Presenter** subagent — reads one commit's diff, returns a compact presentation package. Read-only.
- **Editor** subagent — applies feedback for the *current* commit to the working tree. One editor-role per commit; edits only, never commits.
- **Explorer** subagent — investigates open questions that arise mid-review (`Explore` agent type). Read-only.

## When to use this

- The user asks to review a feature branch one commit at a time
- After proposing a multi-commit sequence and the user wants to walk through it
- The user says things like "present your code for review", "let's go through these one by one", "step through the commits"

## When NOT to use this

- Single-commit reviews — just show the diff and discuss
- The user wants a summary of all commits at once — use a walkthrough skill instead
- The user has already approved the branch and just wants it pushed
- The user wants logical-step (not commit-boundary) review, or review-only with no edits — use **`branch-step-review`** (the review-only sibling)
- The user wants to rewrite a messy history into a clean sequence first — use **`commit-cleanup`**, then review

## The four roles

| Role | What it holds | What it returns | Read-only / edits |
|---|---|---|---|
| **Orchestrator** (top level) | commit sequence, current position, the per-commit state bundle (hash, presentation package, running feedback list + what's applied) | user-facing messages composed from compact subagent results | **owns git-history mutation** (fixup + autosquash, amend) and the **confirmation gate** |
| **Presenter** subagent | one commit hash + base | presentation package (overview → diff → Notes for review) | **read-only** |
| **Editor** subagent | current commit hash, its package, the exact feedback to address, `arbiter` skill | per-item summary of what changed and where | **edits working tree only** — never commits/amends/rebases |
| **Explorer** subagent (`Explore`) | a specific question + relevant file paths | findings / options | **read-only** |

The orchestrator is the only place that knows the whole picture. Each subagent gets exactly its slice. The orchestrator never reads full diffs or full new files; it relays the compact packages subagents return.

## Workflow

### 1. Establish the commit sequence

Before walking commits, the branch should already have a coherent commit sequence (ideally each commit bisectable). If commits aren't laid out yet, propose a sequence first and get approval, then start walking.

Capture the **base** once (`git merge-base HEAD main`, or whatever the branch forked from) — every subagent and every amend references it. Capture the ordered list of commit hashes (`git log --oneline <base>..HEAD`).

State which commit you're on and how many remain: "Starting with commit 1 of 5."

### 2. Present each commit — delegate to a Presenter subagent

Spawn a **presenter subagent** for the current commit. The orchestrator does **not** read the diff itself — that's the point. Give the presenter:

- the commit hash and the base
- instruction to `git show <hash>` and to read full new files
- the package format to return (below), and the rules: **don't paraphrase the diff — show the actual code; lead with intent**

The presenter returns a tight package:

- **a one-paragraph plain-English overview** — what this commit does, why, and any cross-cutting choice worth orienting on. Conversational, not a bullet list.
- **the diff to show** — new files in full; modified files as `diff` blocks. The user is reviewing code, not navigating git.
- **a "Notes for review" list** — the non-obvious decisions: why this approach over alternatives, what constraints shaped it, where the gotchas are.

The orchestrator **holds the package and relays it** — composes the message: "Commit N of M" header + title/body, then the overview, then the diff blocks, then Notes for review, then an explicit handoff: "Anything you want changed before I move on?" Keep the orchestrator's own prose minimal.

**Don't read packages ahead.** Present one commit at a time; spawn the next presenter only when you reach the next commit. Pre-spawning all N presenters and holding every package reintroduces the context bloat the subagents exist to avoid.

### 3. Receive feedback

Three channels, same as always:

- **Arbiter notes** — structured notes the user leaves via the arbiter nvim plugin (`<git_dir>/arbiter.jsonl`). When the file exists and has notes for the current branch, this is the **canonical, authoritative** channel. **See the `arbiter` skill** for the read/write protocol — file location, branch filtering, status taxonomy, atomic-rewrite rules. Check arbiter *before* asking the user for feedback on each commit.
- **Inline comments in the working tree** — the user edits the actual files and adds `// comment` lines. After they say they've added comments, the orchestrator can `git diff` to capture exactly what they wrote (this is cheap — it's the user's comments, not a full diff), then hand the comment text + locations to the editor.
- **Verbal feedback in chat** — plain-English requests.

Read inline comments in context — what surrounding code prompted the comment matters. Address every comment; don't cherry-pick. When you remove or rewrite around a comment, the comment goes too (it was scaffolding).

### 4. Apply changes — delegate to an Editor subagent, DO NOT COMMIT

This is the load-bearing rule. Spawn a **fresh editor subagent for the current commit**, re-hydrated from the orchestrator's state bundle. Hand it:

- the commit hash **and its presentation package** (so it knows intent without re-reading the diff)
- the **exact feedback to address** — arbiter note bodies with their `file:line` ranges, and/or the inline comment text + locations, and/or the verbal items
- the **`arbiter` skill** (so it reads note ranges correctly)
- the hard rule, verbatim: **"Edit the working tree only — do NOT commit, amend, or rebase. Touch no commit history."**

The editor edits the working tree and returns a **per-item summary**: for each feedback item, what changed and where (`file:line`). The orchestrator relays that summary so the user can see each comment was addressed.

If the user wants *more* changes, spawn **another editor round for the same commit** — same commit context + package, the new feedback bundle, the same no-commit rule. The orchestrator carries the running list of what's been applied so each round builds on the last. Loop steps 3–4 without committing.

### 5. Open questions — delegate to an Explorer subagent

When feedback raises something unknown — "would changing X be safe?", "is there an existing helper for this?", "what calls this?" — **dispatch an explorer rather than investigating inline**. Use the **`Explore` agent type** (read-only). Hand it the specific question and the relevant file paths.

The explorer returns compact findings / options — no edits. Those findings inform the next editor round. Keeping this out of the orchestrator's context is the whole point: investigation churn stays ephemeral.

### 6. Wait for confirmation, then the orchestrator amends

The user says "looks good, commit it" / "go ahead" / "next". **Only the orchestrator touches history** — never the editor. Then:

- stage the changes
- `git commit --fixup <commit-hash>`
- `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>` to fold the fixup into the target commit
- verify the resulting log shape with `git log --oneline`

(Or `git commit --amend` when the target commit is HEAD and the user has confirmed.)

If the user instead asks for *more* changes, go back to steps 3–5 without committing.

### 7. Move to the next commit

Once the fixup is applied and the log looks right, **drop the finished commit's state bundle** (its editor-role is gone) and **immediately move to the next commit** — spawn the next presenter (step 2). Don't ask "do you want me to move on?" — redundant once they've confirmed the previous commit. Lead the next message with the next commit.

**Stay at branch tip the whole review — do NOT check out each commit** (see "Stay at tip" below).

On the last commit, report that the branch is review-clean and ask whether they want a push or a PR.

## Stay at tip

The review stays on the branch tip throughout. The orchestrator **never checks out individual commits.** Rationale:

- The **presenter** reads via `git show <hash>` — works from any HEAD, no checkout needed.
- The **editor** must operate at tip so `git commit --fixup <hash>` + `rebase --autosquash` folds cleanly into the target commit. Editing a detached past snapshot fights the fixup machinery.
- **Arbiter note line numbers are post-image / working-tree (tip).** Checking out an old commit desyncs them.
- This drops the old ceremony entirely: no clean-tree-before-checkout, no "return to branch tip on the last commit," no detached-HEAD edit-loss risk.

**On-demand exception:** if the user wants to *run* the code as of commit N, that's a rare explicit action — prefer a throwaway `git worktree add <tmpdir> <hash>` over detaching HEAD, so the review tree stays put; tear it down (`git worktree remove`) after.

## Context-budget discipline

This is the other half of the point. Explicit rules:

- **The orchestrator never reads full diffs, full new files, or edit churn** — always delegate (presenter for reading, editor for editing, explorer for investigating).
- **Hold subagent packages; pull each into the message only when reached.** Don't read all packages at once. Present one commit at a time.
- **One editor-role per commit.** Re-hydrate a fresh editor each round from the orchestrator's state bundle; **discard the bundle on commit confirmation.** Don't carry one commit's feedback context into the next — stale feedback pollutes both the orchestrator and the next editor.

## Anti-patterns to avoid

- **Don't commit after applying changes.** Wait for confirmation; the user may want to iterate.
- **Don't rebase without explicit go-ahead.** History rewrites surprise users. Always confirm. Only the orchestrator rewrites history.
- **Don't paraphrase the diff.** Show the actual code — that's what the review is for.
- **Don't bury "Notes for review."** Surface the non-obvious decisions, trade-offs, gotchas.
- **Don't skip ahead.** One commit at a time; wait between each, even when the next feels obvious.
- **Don't address comments selectively.** Every comment is feedback the user spent time on. If you can't address one, say so and explain why.
- **Don't read full diffs in the orchestrator.** Delegate to a presenter. The orchestrator stays token-light.
- **Don't let the editor commit, amend, or rebase.** The editor edits the working tree only; history mutation is the orchestrator's alone.
- **Don't reuse one editor's context across commits.** Fresh editor per commit, re-hydrated from the state bundle; drop the bundle on confirmation.
- **Don't investigate open questions inline.** Dispatch an explorer (`Explore` type) so investigation churn stays ephemeral.
- **Don't check out individual commits.** Stay at tip; the presenter reads via `git show`, the editor must be at tip for fixup to fold cleanly.

## Tools / subagents

- **`Agent`** — spawn the presenter (read-only, per commit), the editor (per feedback round, current commit; no-commit rule), and the explorer (use the **`Explore`** agent type, read-only). The heavy diff reading, editing, and investigating all live here.
- **git (orchestrator-only for history):**
  - `git merge-base HEAD main` — capture the base once
  - `git log --oneline <base>..HEAD` — the commit sequence; verify after rebase
  - `git diff` (working tree) — read the user's inline comments (cheap; their comments, not a full diff)
  - `git show <hash>` — handed to the presenter for presentation
  - `git commit --fixup <hash>` + `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>` — fold a fixup into a target commit non-interactively
  - `git commit --amend` — only when the target is HEAD and the user confirmed
- **`arbiter` CLI** — defer to the **`arbiter` skill** for the read protocol; check before asking for feedback. Hand the editor the relevant notes + the skill.
- **`git worktree add`** — only for the on-demand "run code at commit N" exception; tear it down after.

## Tone

Treat each commit like a code review conversation. Be opinionated but not defensive — when the user pushes back, the right move is usually to update the code, not defend the original choice. When you do disagree, say so briefly and ask which they prefer rather than overriding.

Keep updates between commits short. The interesting content is the diff and the user's response to it; surrounding prose should be minimal.
