---
name: coreview-execute
description: Execute on the still-open findings in coreview/review.md, tracking progress in coreview/rounds/round-<n>.md. Use when the user says "/coreview execute", "execute the coreview findings", or "let's implement the coreview feedback". Never loads deferred.md or cancelled.md. Not for reviewing a branch (coreview) or triaging findings into now/deferred/cancelled (coreview-assess) — those are separate skills.
user_invocable: true
---

# Coreview Execute

The **third stage** of the coreview family, after `coreview` (review) and
`coreview assess` (triage). This is where fixes actually get implemented.

`coreview` never edits code. `coreview-assess` never edits code either. This skill is
the one that does — it turns the surviving findings in `coreview/review.md` into
actual changes.

## Scope: review.md only

This skill acts **only** on `coreview/review.md`. `coreview/deferred.md` and
`coreview/cancelled.md` are out of scope — **do not open or read either file**, not
even for context. Items landed there because the user already decided not to act on
them now; this skill has no business reconsidering that.

If `coreview/review.md` doesn't exist, say so and stop — there's nothing to execute.

## How to execute is not this skill's call

This skill does not prescribe an implementation method. Don't default to any
particular workflow. The user may want plan mode first, `superpowers:test-driven-development`,
`superpowers:subagent-driven-development`, direct edits, or something else entirely —
ask if it's not already clear, rather than assuming a style.

What this skill **does** own:

- knowing where the feedback lives (`review.md`, Human feedback + Agent feedback
  sections, same shape `coreview` and `coreview-assess` already use),
- tracking progress on each item as work proceeds, in the round file, and
- reconciling `review.md` once an item is actually done.

Everything about *how* an item gets fixed — sequencing, subagents, tests-first,
confirmation per item vs. batch — is the user's call for this invocation. Ask if
unstated; don't assume.

## Checklist for a round

Copy this into a todo list at the start of every invocation and check items off as
you go:

1. Read `coreview/review.md` in full. Never open `deferred.md` or `cancelled.md`.
2. Determine the next round number `n` and create `coreview/rounds/round-<n>.md`
   listing every item this round covers, before any implementation work.
3. Confirm with the user how this round will be executed (method is not this skill's
   call — see above), if not already stated.
4. Work the items. After each one:
   a. Update its line in `round-<n>.md` (checked off + outcome note, or a note that
      it's already stale — see "Tracking progress").
   b. If done, move it into `## Done` in `review.md` (see "Reconciling review.md"),
      then verify the move (see "Verify every move").
5. Report the wrap-up tally and point at both files.

## Rounds

Each invocation of `/coreview execute` is **one round**, tracked in its own file:

```
coreview/rounds/round-<n>.md
```

Determine `n` mechanically, don't estimate it:

```bash
ls coreview/rounds/round-*.md 2>/dev/null | sed -E 's/.*round-([0-9]+)\.md/\1/' | sort -n | tail -1
```

`n` is one more than that output (start at `1` if the command prints nothing, e.g. the
directory doesn't exist yet or is empty). Never reuse or overwrite an earlier round's
file.

Note every item still under `coreview/review.md`'s `## Human feedback` and
`## Agent feedback` (skip anything already under `## Done` — that's already handled).
If the user scopes the round to a subset of items rather than everything open, list
only those. Create `coreview/rounds/round-<n>.md` immediately, before any
implementation work, carrying over the same `file:line` + title used in `review.md`
so the two documents stay cross-referenceable:

```markdown
# Coreview execute — round <n>

<YYYY-MM-DD>

## Items

- [ ] `path/to/file.ts:41` — response shape drifted from the client type
- [ ] `path/to/other.ts:88` — duplicate of the existing retry helper
```

### Tracking progress

Update the round file **as work proceeds**, not at the end — an interrupted round
should still show what happened:

- Check off an item (`- [x]`) when it's done, and add a one-line note of what changed
  and where: `- [x] \`path/to/file.ts:41\` — response shape drifted... — normalized on
  ISO-8601 in \`api/users.ts:41\` and \`web/types.ts:12\`.`
- If an item turns out already fixed, out of date, or not worth doing after all,
  say so on its line rather than silently dropping it — that's a fact for the user to
  react to, not a decision this skill makes alone (compare to `coreview-assess`, which
  routes exactly this kind of call through the user).
- Leave items not yet reached unchecked; they stay visible as remaining work if the
  round is interrupted.

### Reconciling review.md

When an item is actually done, move it out of `coreview/review.md`: cut its full block
(heading through its **Should be:** line) from wherever it lives (`## Human feedback`
or `## Agent feedback`) and append it under a `## Done` heading, preserving which of
the two sections it came from — same provenance rule the parent skills use. Create
`## Done` (and its `### Human feedback` / `### Agent feedback` subheadings) on the
first item moved into it; it doesn't exist beforehand.

Because `## Done` is a section *within* `review.md` rather than its own file, each
item's own heading sits one level deeper than everywhere else in the pipeline: `####`
here, versus `###` under `## Human feedback` / `## Agent feedback` and in
`deferred.md` / `cancelled.md`. That's the only place in the family this happens —
don't carry `####` anywhere else.

Add a one-line note above the moved item, same style `coreview-assess` uses for its
deferred/cancelled notes:

```markdown
## Done

### Human feedback

#### `path/to/file.ts:41` — response shape drifted from the client type

_Executed round 2 (2026-09-18): normalized on ISO-8601 in the server response and the
client type._

The endpoint now returns `createdAt` as an epoch int; the SPA still types it as a
string and formats it directly.

**Should be:** one representation agreed across the seam — pick ISO-8601 or epoch and
make the server, the client type, and the formatter agree.
```

Move items as they're finished, not batched at the end.

**Don't move an item until it's actually done** — a partial or attempted fix stays in
its original section, with progress visible only in the round file.

### Verify every move

Cutting a block from one section and pasting it into another is easy to get subtly
wrong — a dropped blank line, a heading pasted at the wrong depth, a **Should be:**
line left behind. After each move, re-read the item in its new location in `## Done`
and confirm: the heading is present at `####`, the body and the **Should be:** line
both came across intact, and the original location no longer has any trace of the
item. Fix immediately if anything's off — don't move on to the next item first.

## Wrap-up

Report the tally: items done this round (moved to `## Done`), items left open in
`review.md` and why (skipped, still in progress, deprioritized), and point at
`coreview/rounds/round-<n>.md` and `coreview/review.md`.

## What this skill never does

- Never reads `coreview/deferred.md` or `coreview/cancelled.md`.
- Never moves an item into `## Done` before the work is actually complete.
- Never moves an item without re-reading the result in place — a botched cut/paste
  left unverified is worse than not moving it at all.
- Never prescribes the implementation workflow — that's the user's call each round.
- Never touches GitLab, arbiter, or any other external system on its own initiative —
  if the user wants commits or an MR out of this, that's a separate, explicit ask.
