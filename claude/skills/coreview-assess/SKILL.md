---
name: coreview-assess
description: Triage a coreview/review.md findings document — check each item's current viability and rough complexity, then decide with the user which are addressed now, deferred, or cancelled. Use when the user says "/coreview assess", "assess the coreview", "triage coreview", or "let's go through the coreview findings". Not for implementing findings — that's "/coreview execute" (coreview-execute).
user_invocable: true
---

# Coreview Assess

A **triage pass** over a `coreview/review.md` produced by the `coreview` skill. Not
every finding recorded during a review is ready to act on — some need a second look at
whether they still hold up, and how big the fix actually is, before anyone commits to
doing them now.

This is a **pre-development** stage. No coding happens here — not even a spike. The
only output is items moving between files.

**Prefer a fresh session.** This works best run in a new Claude session rather than
continuing the one that did the review — a session that just wrote the findings is
anchored on its own read of them. It's not required; if the user invokes this in the
same session, proceed anyway.

## Files

All three live at the repo root, in a `coreview/` folder:

- `coreview/review.md` — the working document. Items land here from a `coreview` pass.
  Items assessed and kept "now" stay here.
- `coreview/deferred.md` — items the user decided to postpone.
- `coreview/cancelled.md` — items the user decided not to do.

If `coreview/review.md` doesn't exist, say so and stop — there's nothing to assess.

## Workflow

### 1. Read the document

Read `coreview/review.md` in full. It has two sections — `## Human feedback` and
`## Agent feedback` — each a list of `file:line` items with what's wrong and a
**Should be:** line. Keep track of which section each item came from; that provenance
carries through to wherever the item ends up.

If `coreview/deferred.md` or `coreview/cancelled.md` already exist, skim them too, so
you don't re-litigate a verdict already reached in an earlier assess session.

### 2. Research viability and complexity, via subagents

For each item still in `review.md` (or grouped in small batches of related items —
your judgment), spawn a subagent to check it against the **current** state of the
code. Use as many subagents as needed to get a clear, independent picture of each
item — parallelize across items that don't depend on each other. **Read-only. No
edits.**

Each subagent should report back:

- **Still valid?** Does the finding still hold against the code as it stands now, or
  has it since been fixed, changed, or become moot?
- **Rough shape of the fix** — which files/areas it touches, whether it's contained or
  ripples outward, and anything that makes it trickier than it looks (e.g. touches a
  seam, needs a migration, affects a high-fan-in path).
- **Rough size** — a one-line complexity call: trivial / small / medium / large, with
  the one-line reason.

Hold these reports; they feed step 3, they are not shown to the user verbatim as a
subagent transcript.

### 3. Walk the items with the user

Present items one at a time (or grouped, if several are small and related — ask
first). For each:

- State the finding briefly (it's already written in `review.md` — don't restate the
  whole thing, just enough to place it).
- Give the subagent's viability and complexity findings in a few lines.
- **Offer a recommendation** — address now / defer / cancel — with a one-line reason
  grounded in what the subagent found (e.g. "still valid, contained to one file —
  addressable now" or "still valid but touches the migration path and three call
  sites — bigger than it looked, consider deferring").

The recommendation is a starting point, not a verdict. **The user decides.** Wait for
their response before moving anything.

### 4. Route on the user's words

Listen for the verb the user actually uses, and route accordingly:

- **"cancel", "scrap", "ditch"** (or clear equivalent) → move the item to
  `coreview/cancelled.md`.
- **"defer", "postpone", "do later"** (or clear equivalent) → move the item to
  `coreview/deferred.md`.
- **Explicit agreement to address it now** ("yes", "let's do it", "keep it", "address
  now") → leave the item in `coreview/review.md`, marked as assessed.
- **Ambiguous** — ask. Don't guess between defer and cancel; they mean different
  things and the document is only useful if the distinction is trustworthy.

**Moving** an item means: cut its full block (heading through its **Should be:** line)
out of `coreview/review.md`, and append it to the target file under a heading that
preserves its original provenance (`## Human feedback` / `## Agent feedback`, creating
the section in the target file if it doesn't exist yet). Add one line noting the verdict
date and a short reason, taken from the discussion:

```markdown
### `path/to/file.ts:41` — response shape drifted from the client type

_Deferred 2026-09-18: valid, but the fix touches the shared serializer and both
clients — bigger than a quick pass, revisit after the client migration lands._

The endpoint now returns `createdAt` as an epoch int; the SPA still types it as a
string and formats it directly.

**Should be:** one representation agreed across the seam — pick ISO-8601 or epoch and
make the server, the client type, and the formatter agree.
```

Items **assessed and kept** in `review.md` get the same kind of one-line note added
in place (`_Assessed 2026-09-18: still valid, contained — ready to address._`), so a
later pass can tell what's already been triaged versus what's still fresh from a
review.

Write changes as the session goes, not batched at the end — an interrupted session
should still leave a consistent set of files.

### 5. Wrap up

Report the tally: items kept in `review.md`, items deferred, items cancelled, and
whether anything is still untriaged (the user stopped early, or asked to skip
something). Point at the three files. Mention `/coreview execute` is available to
implement whatever's left in `review.md` — nothing more than that it exists.

## Voice

Same as the parent `coreview` skill: answer first, short and direct, bullets over
prose. The recommendation is one line with one reason — not a case being argued.
Once said, get out of the way for the user's call.

## What this skill never does

- Never edits code. Never runs a spike or a proof-of-concept to test viability — the
  subagents research by reading, not by building.
- Never touches GitLab, arbiter, or any other external system.
- Never moves an item without the user's own word for it landing in step 4. A
  recommendation is not a verdict.
- Never invents a fourth destination file. Only `review.md`, `deferred.md`,
  `cancelled.md`.
