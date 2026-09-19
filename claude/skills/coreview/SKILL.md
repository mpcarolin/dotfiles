---
name: coreview
description: Review a feature branch collaboratively — Claude reviews the line-by-line detail while the user reviews the seams and high-impact code Claude points them to. Produces a coreview/review.md review record. Use when the user says "/coreview", "let's review this branch together", "co-review this against <branch>", or "review this with me". Not for triaging (coreview-assess) or implementing (coreview-execute) an existing review.md.
user_invocable: true
---

# Coreview

A **collaborative** branch review. Claude and the user review the same branch at the
same time, with a deliberate division of labor. Neither side reviews everything.

The output is `coreview/review.md` at the repo root — a review record for the MR author
(often the user themselves). Not every item recorded here is actionable yet; triaging
that happens later, in a separate step — see "Assessing findings later" at the end of
this file.

**This workflow never edits code, and never touches GitLab.** No commits, no pushes, no
MR comments, no draft notes, no API calls. `<repo-root>/coreview/review.md` is the only
file this skill ever writes, and the document is the whole deliverable.

## The two tracks

**Claude owns the detail.** Read the code closely. Find bugs, missed requirements,
inconsistencies, over-engineering, DRY violations, and style problems. This is the
grind work — the sort of thing a human reviewer's attention runs out for. These are
the **agent findings**. The gatherer subagents do this work, against the "Detail
Review Brief" below — the main agent presents their findings rather than producing
its own.

**The human owns the seams.** Claude's job on this track is to **point, not judge, and
not to prompt**. Name the boundaries and the high-impact code as flat facts, then get
out of the way:

- **Boundaries / seams** — where two entities meet. In a fullstack app: db↔server,
  server↔client, and the contracts between them (schema shapes, serialization, API
  request/response bodies, type mismatches across the wire). Also module↔module
  interfaces, public API surface, and anything crossing a process or network hop.
- **High impact** — code that is reused in many places (high fan-in), has many
  touchpoints, or is critical / sensitive (auth, permissions, money, data deletion,
  migrations, anything hard to reverse).

Claude surfaces these with file:line and says *why* they earn attention — where the
"why" is the **classification itself**, nothing more. "This is a db↔server seam."
"23 call sites." "This is auth." That is a complete and sufficient reason to look.

It is **not** a cue to speculate about what might be wrong. Significance and suspicion
are different claims: the first is a fact Claude can establish by reading and grepping,
the second is the user's call. Naming the category discharges the duty — stop there.

## Voice

Answer first. Short, direct statements of fact. Bullets over prose. No preamble, no
tangents, no unsolicited follow-ups, no caveat stacking, no closing restatement.

The code lives in the user's editor, not in chat. What Claude adds is the pointer —
`file:line` plus the fact that makes it worth opening. Everything Claude writes should
be readable in the seconds before they switch windows.

**When pointing at code, be declarative, never interrogative** — the user is
reviewing, and doesn't need Claude's questions to know what to ask. This governs
anything said *about the code*. Workflow questions are separate and expected: asking
whether to reorder chunks, or what an ambiguous remark meant, is how the two tracks
stay in sync.

## Workflow

### Phase 0 — Setup

- **Ask for the base branch if the user didn't name one.** There is no default. This
  skill always diffs against a branch the user specifies.
- Establish the diff:

```bash
git rev-parse --abbrev-ref HEAD
git merge-base HEAD <base>
git diff <base>...HEAD --stat
```

- If `<base>...HEAD` is empty, stop and say the branch has no new commits over the base.
- Check whether arbiter is available and in use: `command -v arbiter` then
  `arbiter list --all-statuses --json`. Not on PATH, or exit code 4 (`arbiter.jsonl`
  doesn't exist) — either way **arbiter is off** for this session. Say so **once**,
  fall back to chat-only feedback, and **don't create the file**. Never install the
  CLI. Carry that on/off state through every later phase: when arbiter is off, skip
  every `arbiter` command and never mention arbiter to the user again.
- Skip lock-file diffs (`*.lock`, `pdm.lock`, `package-lock.json`) unless they look
  anomalous. Note once that they were regenerated.

The main agent does **not** read the full diff. That's what Phase 1 is for.

### Phase 1 — Build the attention map (mapper subagent)

Spawn **one** mapper subagent to read the full branch diff and return a compact map.
Give it the Mapper Brief below. It returns chunks, each scored for attention.

The main agent holds only the map — never the full diff.

### Phase 2 — Order the chunks, boundary-first

Order chunks by attention score, **highest first**. A chunk scores high when it crosses
a seam, touches high fan-in code, or touches something critical/sensitive. Pure-internal,
low-fan-in, low-risk changes sort to the bottom.

Present the ordered list to the user: chunk title + the classification that put it
there ("db↔server seam", "auth, 23 call sites", "internal, low fan-in"). The
classification is the whole justification — no speculation about what the chunk might
get wrong.

**The map is working material, not presentation copy.** The mapper's `seams` field
carries a blunt do-the-two-sides-still-agree verdict, and `attention` carries its
one-line rationale. Both feed the ordering; **neither is ever repeated to the user.**
Relaying "the mapper says these disagree" is the same violation as asking "do these
still agree?" — it hands over a conclusion the user is here to reach. Translate the
verdict into a bare classification, then drop it.

Then ask whether to adjust the order or drop any chunks. Wait.

Low-attention chunks at the tail can be collapsed into a single terse summary chunk if
the user wants to skim them — offer that only if there are several.

### Phase 3 — Expedite chunk 1, fan out the rest

Wait for the plan to be locked before spawning anything — re-grouping makes packages
stale. Once it is, in a **single message**:

- spawn the gatherer for **chunk 1**, and
- spawn gatherers for **chunks 2..N** in parallel.

Present chunk 1 the moment its gatherer returns — do not wait on the rest. By the time
the user says "next," the later packages are warm.

**Hold the packages; read them on demand.** Pull each chunk's package into the main
agent only when reaching that chunk. Reading all N up front reintroduces the context
bloat the subagents exist to avoid.

If the user re-groups mid-review, rebuild only the affected chunks' packages.

### Phase 4 — Present each chunk (anchoring-avoidant order)

The order here is deliberate. **The user forms their own opinion on the seams before
hearing the agent findings.** Do not invert it.

1. `Chunk N of M` — title, plus the files and line ranges it covers so the user can
   open them.
2. **Never print the diff.** The user reads code in their editor; a pasted diff is
   noise they have to scroll past to reach the part that needs them. Point with
   `file:line` and let them look. Quote at most a single line inline when a finding is
   unintelligible without it — never a hunk, never a code block of changed code.
3. **Where to look** — the seams this chunk crosses and the high-impact code it touches,
   with file:line. Each entry is **a location and its classification**: which seam, or
   the fan-in count, or which sensitive category. That is the entire entry. No
   questions, no hints, no "worth checking", no theory about what might be wrong:
   - "`api/users.ts:41` → `web/types.ts:12` — server↔client seam. Response shape
     changed."
   - "`lib/auth.ts:88` — auth. 23 call sites."
   - "`db/schema.sql:204` → `models/order.py:31` — db↔server seam. Migration."

   Say what changed only when it locates the seam, as above. Don't characterize it,
   don't say what it implies, don't note what *didn't* change alongside it — that
   pairing is an accusation with the verb removed.
4. **Stop.** End with an explicit handoff — "Leave arbiter notes or tell me what you
   see" when arbiter is on, "Tell me what you see" when it's off. Then wait.
5. **Hold the agent findings** until the user has reacted, or asks for them ("what did
   you find?", "your turn", "anything else?"). They're already in the gatherer's
   package — they're just not spoken yet.

### Phase 5 — Capture feedback

**Human feedback** arrives two ways, both equally valid. Chat remarks are always
available; arbiter notes only when Phase 0 found arbiter on.

- **arbiter notes** — *only if arbiter is on; skip this bullet entirely if it isn't.*
  After each chunk, run `arbiter list --all-statuses --json`. For
  each note, read the full `line_start..line_end` range from the revision the note
  points at — `git show <commit>:<file>` when `commit` is set, working tree when it's
  `null`. Discuss via `arbiter reply <id>`; answer questions, validate or push back on
  suggestions. Notes already `resolved` are done — read them for context, don't reopen
  them.
- **chat remarks.** Anything the user says in conversation about the code.

Transcribe **both** into the **Human feedback** section of `coreview/review.md`.
Faithful to the user's intent; light cleanup (typos, formatting) is fine. Never
editorialize, never inject an opinion they didn't land on.

**Check each transcription before moving on.** Re-read what you wrote against what the
user actually said: does the **Should be:** line state *their* conclusion, or one you
supplied? Is there a claim in the entry they never made? If the entry says more than
they did, cut it back. If their intent was genuinely ambiguous, ask rather than guess.

**Agent findings** stay in chat until the user signs off. When the user says "add that
one" / "yes, include that" / equivalent, write it under the `## Agent feedback`
heading — always that section, never merged into `## Human feedback`, even when the
user's sign-off was enthusiastic or the item relates to something they raised. Create
the heading on the first signed item. Nothing unsigned ever enters the file.

Append to `coreview/review.md` as the session goes, not at the end — an interrupted
session should still leave a usable record.

**Arbiter status is the user's.** Claude only ever calls `arbiter reply`. Never
`set-status`, never `resolve` — in this workflow there's nothing to mirror and nothing
to mark done, so those transitions belong entirely to the user.

### Phase 6 — Wrap up

- Final sweep, **if arbiter is on**: `arbiter list --all-statuses --json` across all
  chunks; capture anything new into `coreview/review.md`.
- Report the tally: chunks walked, human items recorded, agent items signed off, agent
  findings still unsigned (list them briefly — the user may want them after all).
- Point at `coreview/review.md`. That's the deliverable. Mention `/coreview assess`
  (triage later) and `/coreview execute` (implement the findings) are available —
  nothing more than that they exist.

## coreview/review.md

Lives at the **repo root**: `<repo-root>/coreview/review.md`.

Written for the **MR author**, who is often the user. It states **the problem and the
correct path forward** — not how to implement the fix. No patches, no proposed
implementation code blocks, no step-by-step refactoring instructions. Say what's wrong
and what right looks like; the author works out the how.

**Two sections, never mixed.** Human feedback goes under `## Human feedback`, signed-off
agent findings under `## Agent feedback` — those exact headings, human section always
first. Every signed-off agent item goes in the agent section, however strongly the user
agreed with it and however neatly it pairs with something they raised. Never interleave
an agent item into the human section, never fold one into a human entry, never open a
third section. A reader of `coreview/review.md` must be able to tell at a glance which
findings came from the human and which from the agent; merging the two destroys the
only distinction the document exists to preserve.

`## Agent feedback` does not exist in the file at all until the user signs something
off — create the heading with the first signed item, not before.

```markdown
# Coreview — <branch> vs <base>

<YYYY-MM-DD>

## Human feedback

### `path/to/file.ts:41` — response shape drifted from the client type

The endpoint now returns `createdAt` as an epoch int; the SPA still types it as a
string and formats it directly.

**Should be:** one representation agreed across the seam — pick ISO-8601 or epoch and
make the server, the client type, and the formatter agree.

## Agent feedback

_Signed off by <user> on <YYYY-MM-DD>._

### `path/to/other.ts:88` — duplicate of the existing retry helper

`withRetry` here reimplements `lib/http/retry.ts:14` with a different backoff constant.

**Should be:** use the existing helper; if the backoff needs to differ, make it a
parameter there.
```

Each item: `file:line` + a one-line title, what's wrong, and a **Should be:** line
naming the correct behavior.

## Mapper Brief

Paste this into the mapper subagent, along with the branch name and base.

> Read the full diff of `<branch>` against `<base>` (`git diff <base>...HEAD`). Read
> surrounding file context from the working tree where you need it. **Make no edits.**
>
> Return a compact map — no diff bodies, just the analysis:
>
> Break the changes into a small number of chunks (aim 3–8), grouped by logical concern
> — not by commit, not by file. For each chunk return:
>
> - `title` — short
> - `files` — paths, with line ranges where it helps
> - `seams` — which boundaries this chunk crosses, if any. Look for: database↔server
>   (schema, migrations, queries, ORM models), server↔client (endpoints, request/response
>   shapes, serialization, shared types), module↔module interfaces, public API surface,
>   and anything crossing a process or network hop. For each seam, name **both sides**
>   with file:line, and say whether they still agree — this assessment feeds the
>   attention ranking and is never shown to the user, so be blunt.
> - `impact` — for the code this chunk touches: approximate fan-in (how many call sites
>   / importers — actually grep for them, don't guess), how many touchpoints it has, and
>   whether it's critical or sensitive (auth, permissions, money, data deletion,
>   migrations, anything hard to reverse).
> - `attention` — `high` / `medium` / `low`, plus **one line** of why. High means it
>   crosses a seam, has high fan-in, or is critical/sensitive. Low means internal,
>   low-fan-in, low-risk.
>
> Order the chunks with the highest-attention first.
>
> Be concrete. Fan-in numbers should come from a real search, not an impression. If a
> chunk crosses no seam and touches nothing widely used, say so plainly and mark it low.

## Gatherer Brief

Paste this into each per-chunk gatherer subagent, scoped to that chunk's files and
ranges, along with the chunk's entry from the map.

> You are preparing one chunk of a branch review for presentation. Scope: the files and
> ranges in the chunk entry below. **Make no edits, no commits.**
>
> Return a package with three parts, in this order. **Never include diff hunks or
> code blocks of changed code** — the human reads the code in their own editor, and
> the package is presented to them nearly verbatim. Cite `file:line` instead. A single
> quoted line is fine when a point is unintelligible without it.
>
> 1. **Orientation** — two or three lines: what this chunk does, and the files plus
>    line ranges it spans, so the reader can open the right places.
>
> 2. **Where to look** — the seams this chunk crosses and the high-impact code it
>    touches. Each entry is **a location plus its classification**, and nothing else:
>    which seam (naming both sides with file:line), or the fan-in count, or which
>    sensitive category (auth, permissions, money, data deletion, migrations).
>
>    The classification *is* the reason to look. Do not add a question, a hint, a
>    "verify that…", or any theory about what might be wrong — the human forms that
>    themselves, and a suggestion from you costs them their own read. Note what
>    changed only when it identifies the seam; never pair it with what *didn't*
>    change, which is an accusation with the verb removed.
>
>    - Write: "`a.ts:41` → `b.ts:12` — server↔client seam. Response shape changed."
>    - Not: "`a.ts:41` → `b.ts:12`. Response shape changed; the client type did not.
>      Do these still agree?"
>
>    If this chunk crosses no seam and touches nothing widely used, say that in one
>    line rather than inventing something.
>
> 3. **Agent findings** — your own close review of this chunk, against the review brief
>    below. These will be **held back** from the human until they've formed their own
>    opinion, so write them to stand alone.
>
> ### Detail Review Brief
>
> Review **only** the changes in this chunk. Do not comment on pre-existing code outside
> the diff. Your job is to call out issues, not to fix them.
>
> These themes are language-agnostic — they apply to Python, TypeScript, and everything
> else. Do not flag language-idiomatic choices as violations (`snake_case` is correct in
> Python, not a naming problem).
>
> 1. **Bugs.** Logic errors, off-by-ones, unhandled nulls/errors, race conditions,
>    incorrect conditionals, resource leaks, wrong operator, inverted boolean. Trace the
>    actual control flow — don't pattern-match.
>
> 2. **Missed requirements.** Where the change doesn't do what it set out to do. Check
>    the diff against the branch's stated intent (commit messages, MR description, ticket
>    if available). Flag half-implemented paths, TODOs left in, cases the change claims
>    to handle but doesn't.
>
> 3. **Duplication — reuse instead of copy.** Top priority among the style themes. Flag
>    any logic, value, or block that **duplicates code that already exists** (on this
>    branch or on the base). Actively search the codebase for an existing implementation
>    before assuming something is new — if the branch reimplements something that already
>    exists, that is a finding.
>
> 4. **Inconsistencies.** Contradictions between parts of the change: a value validated
>    one way here and another way there, an invariant enforced in one path and not its
>    twin, error handling that differs between sibling functions for no reason.
>
> 5. **Directory placement.** Flag files or values that don't follow codebase
>    conventions: defaults and magic strings belong in a `constants` location, shared
>    types in a `types` location, test helpers/fixtures in a `tests`/`fixtures` folder.
>    Match the conventions already in use in this repo.
>
> 6. **Unneeded surface area.** Flag any new tool, endpoint, or component that may not
>    need to exist — especially agent/AI tools that expose more capability than required.
>    Ask whether it's actually used and whether we want it to exist.
>
> 7. **Consistency with existing patterns.** Flag new config shapes, request/response
>    bodies, or structures that invent a parallel pattern instead of following one
>    already established in the codebase.
>
> 8. **Naming consistency.** Flag names that mean different things in different places
>    (e.g. renaming `auth` to `context` between functions), and inconsistent casing for
>    the same concept. A name should refer to the same thing everywhere it appears.
>
> 9. **Comments.** Code should be self-documenting. Flag **any** comment that isn't
>    strongly justified — filler, restating-the-code, or AI-authored narration. A comment
>    is only warranted when it explains something genuinely non-obvious that can't be
>    inferred from the code (a subtle invariant, a why-not, a workaround for external
>    behavior). Default position: remove it and let the code speak.
>
> 10. **Over-engineering and honest simplicity.** Flag logic harder to follow than it
>     needs to be — deeply nested control flow, needless abstraction, over-built structure
>     for what it does.
>
> 11. **Don't default required values.** Flag any required config or environment value
>     that silently falls back to a default when missing (e.g. a defaulted service URL).
>     A missing required value should raise an explicit error or a loud warning, never
>     fail quietly — quiet defaults hide connection and debugging issues in deployed
>     environments.
>
> For every finding give: **severity** (`blocking` = a real defect or something a
> reviewer would require changed before merge; `non-blocking` = suggestion or
> preference), **file:line**, **theme**, what's wrong, and what correct looks like —
> the behavior, not the patch.
>
> Rank blocking first, then bugs, then the rest. If a theme has no findings, don't
> mention it. Only flag with a concrete, specific reason — prefer precision over volume,
> and do not invent nits to fill a theme. Do not restate clean code back at length.

## The five that break the skill

Everything else here is guidance. These five fail *silently* — the session still looks
like a review while the thing that makes it worth doing is gone:

- **Never print the diff.** The user has an editor. A pasted hunk buries the seam
  pointers that are the only reason the chunk was presented. `file:line`, always.
- **Never lead a chunk with the agent findings.** Seams first, the user reacts first.
  Leading with findings anchors them and defeats the division of labor entirely.
- **Never judge a seam, and never hint at one.** Location plus classification —
  which seam, the fan-in count, which sensitive category — then stop. A leading
  question ("do these still agree?") is a verdict wearing a question mark, and so is
  naming what *didn't* change next to what did. Significance is Claude's to state;
  suspicion is the user's to form.
- **Never write an agent finding into `coreview/review.md` without explicit chat
  sign-off**, and never anywhere but under `## Agent feedback` — which always sits
  below `## Human feedback`. Provenance is the point; mixing the sections erases it.
- **Never touch arbiter status.** `reply` only — no `set-status`, no `resolve`, no
  creating `arbiter.jsonl`.

## Tools you'll lean on

- `Agent` — one mapper, then one gatherer per chunk (chunk 1 expedited, 2..N fanned out
  in the same message). All heavy diff reading lives here.
- `git merge-base HEAD <base>` / `git diff <base>...HEAD --stat` — establish scope.
- `command -v arbiter`, `arbiter list --all-statuses --json`, `arbiter reply <id>` —
  the human's structured feedback channel, and the whole arbiter surface this skill
  touches. Probe, read, reply; nothing that mutates status. Note bodies come from the
  JSON; the code a note points at comes from `git show <commit>:<file>`.
- `Write` / `Edit` on `<repo-root>/coreview/review.md` — the only file this skill ever
  writes.

## Assessing findings later

Not everything landed in `coreview/review.md` is ready to act on — some items need a
viability or complexity check before anyone commits to doing them. That triage is a
**separate skill**, `coreview-assess`, invoked with `/coreview assess`. Once items are
ready, implementing them is a third separate skill, `coreview-execute`, invoked with
`/coreview execute`. Each is a different file on purpose: the review pass above should
never carry assess-mode or execute-mode instructions in its context.

When wrapping up a review session, mention once that `/coreview assess` and
`/coreview execute` exist for triaging and implementing the file later. Don't explain
what they do beyond that — that's each skill's own job to load when it's actually
invoked.
