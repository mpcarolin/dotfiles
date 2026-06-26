---
name: branch-step-review
description: Walk a feature branch with the user one logical step at a time for code review. Diff the current branch against main, break the changes into N logical pieces (not commits), and present each piece in turn. The user leaves arbiter notes on each step; you discuss and reply to pending notes, and once the user marks a note needs-rereview you mirror it into a GitLab draft/pending MR comment on that line, then resolve the arbiter note. The GitLab review stays a DRAFT — only the user submits it. Use when the user says "review my branch step by step", "walk me through these changes logically", "present the branch one piece at a time", or "step through the diff against main".
user_invocable: true
---

# Branch Step Review

A structured workflow for walking a feature branch with the user, **one logical step at a time**. Unlike commit-by-commit review, this does not follow the commit boundaries — instead you diff the whole branch against `main`, group the changes into coherent logical pieces, and present them in a sensible order. Each step is a small review conversation.

You **never edit the codebase** in this workflow. The output of the user's review is a set of **arbiter notes**. The note's **status drives the loop**: while a note is `pending` you *discuss* it with the user — answer questions, validate or push back on suggestions — via `arbiter reply`. Only once the user marks a note **`needs-rereview`** (their "this one's settled, mirror it" signal) do you push it into a **GitLab draft (pending) MR comment** on that line, then resolve it in arbiter. The GitLab review **stays a draft** — only the user submits it.

This skill leans heavily on **subagents** to keep the top-level presenter token-light. The presenter holds only the step plan and the current step's summary; the heavy diff reading happens inside subagents.

## When to use this

- The user asks to review a feature branch step by step (logically, not by commit)
- The user says "walk me through the changes against main one piece at a time"
- The user wants to leave arbiter notes and have them mirrored to a GitLab draft review

## When NOT to use this

- The user wants to walk the actual commit sequence — use `commit-by-commit-review`
- The user wants you to apply feedback and edit code — this skill is review-only
- The user wants a single all-at-once branch summary — use `merge-request-review`
- The user wants the GitLab review submitted by you — never; this skill keeps it a draft

## The two roles

- **Presenter (you, top level).** Holds the step plan and the current step. Talks to the user, drives the loop, mirrors arbiter notes to GitLab, resolves arbiter notes. Spends as few tokens as possible — delegate any large diff reading.
- **Subagents.** Do the token-heavy work and return compact results: (1) the *planner* reads the full branch diff and returns the logical step breakdown; (2) a *per-step gatherer* reads one step's diff and returns a tight summary plus the exact code to present. The presenter never reads the full branch diff itself.

## Workflow

### 1. Establish the base and the MR

- Confirm the branch and base. Default base is `main`; merge-base it: `git merge-base HEAD main`.
- Confirm there's a GitLab MR for this branch (the draft comments attach to it). If none exists, ask the user whether to proceed without GitLab mirroring (arbiter-only) or to create the MR first via the `create-merge-request` skill. Don't create one silently.
- **Read the MR description on GitLab first** to get the author's stated intent — what the change is for, what's in/out of scope, any caveats or self-noted TODOs. This frames the whole review: it tells you what the change is *trying* to do, so you can spot where the diff diverges. Fetch it with `glab mr view <iid>` (or `glab api "projects/:id/merge_requests/<iid>"` and read the `description` field). Carry the gist into the planner's brief (step 2) so the step breakdown reflects the author's intent, and keep it in mind as you present each step.
- Capture the MR `iid` and the diff version SHAs once, up front — you'll reuse them for every draft comment (see "Mirroring to a GitLab draft comment").

### 2. Plan the steps — delegate to a subagent

Spawn a **planner subagent** to read the full branch diff and return the logical breakdown. The presenter does **not** read the whole diff itself — that's the point.

Tell the planner to return a compact JSON-ish plan: an ordered list of steps, each with a short title, a one-line rationale, and the list of files (and ideally line ranges) that belong to it. Group by *logical concern*, not by commit or by file — e.g. "new config schema", "wire config into the loader", "tests for the loader". Order them so each step builds on the last, the way you'd want to read the change for the first time.

Give the planner roughly this brief (paste in the MR description gist from step 1 so the grouping reflects the author's intent):

> The MR's stated intent: `<description gist>`. Diff the current branch against `<merge-base>`. Break the changes into a small number (aim 3–8) of logical review steps. Group by concern, not by commit. Return an ordered list; for each step: `title`, `rationale` (one line), `files` (paths), and `line_ranges` where it helps. Keep it compact — no diff bodies, just the map.

When it returns, show the user the **plan** as a numbered list and confirm before walking: "Here's how I'd break this into N steps — want me to adjust the grouping or order before we start?" Let them re-group if they want.

State position as you go: "Step 1 of 5."

### 3. Build all step packages in parallel — once the plan is locked

**Wait until the plan is approved**, then fan out: spawn **one gatherer subagent per step, all in the same message** so they run concurrently. Each gatherer is scoped to just its step's files/ranges and returns the presentation package described below. This means you're not building each step's presentation on demand while the user waits — by the time they say "next," the package is already done and you just read that step's result.

Each gatherer returns a tight package:

- a one-paragraph plain-English overview of what this step does and why
- the actual diff to show (new files in full; modified files as `diff` blocks), scoped to the step
- a short "Notes for review" list: the non-obvious decisions, trade-offs, and gotchas in this step

**Hold the packages; read them on demand.** Keep the gatherer results available and pull in each step's package only when you reach that step — don't dump all N packages into the presenter at once, or you reintroduce the context bloat the subagents exist to avoid.

**Re-grouping invalidates packages.** This parallel build happens *after* the plan is locked precisely because re-grouping a step makes its pre-built package stale. If the user re-groups mid-review (merges, splits, or reorders steps), rebuild only the affected steps' packages — spawn fresh gatherers for those, leave the untouched ones as-is.

### 4. Present each step

For each step, relay its already-built package. The presenter composes the message to the user:

- **Lead with the one-paragraph overview** (from the gatherer), right after the "Step N of M" header and the step title.
- **Show the diff content directly in the message** using code blocks. Don't just link hashes or filenames — the user is reviewing code, not navigating git.
- **Include "Notes for review"** — surface the decisions that aren't obvious from the diff.
- **End with an explicit handoff**: "Leave any arbiter notes on this step and tell me when you're ready — or say next." Make clear you're waiting.

Keep the presenter's own prose minimal. The interesting content is the diff and the user's response.

### 5. Discuss feedback via arbiter — status drives everything

The feedback channel here is **arbiter** — structured notes the user leaves via the arbiter nvim plugin (`<git_dir>/arbiter.jsonl`). **See the `arbiter` skill** for the full read protocol: invocation, record schema, status taxonomy. In this workflow the note's **status is the control signal** for the whole feedback loop:

| status | meaning here | your action |
|---|---|---|
| `pending` | the user is still working this note with you — a question, a suggestion to validate, something to discuss | **discuss, don't sync.** Examine it, read the code in context, and `arbiter reply` with your answer / validation / pushback. Leave the status alone — the user owns the transition. |
| `needs-rereview` | the user has settled this note and marked it ready to mirror | **sync it** to a GitLab draft comment (step 6), then resolve it (step 7) |
| `resolved` | already mirrored (by you) or closed by the user | skip |
| `in-progress` | owned elsewhere | skip |

So the loop on each step is:

1. The user says they've left notes (or before you move on), run `arbiter list --all-statuses --json` so you see both `pending` and `needs-rereview` for the current step's files. (Plain `arbiter list` shows both too, since they're the actionable statuses — use whichever; you need to distinguish the two.)
2. For each `pending` note: read its `file:line_start..line_end` range, then **respond via `arbiter reply`** — answer the question, validate or push back on the suggestion, or ask for clarification. This is a real back-and-forth; the user may reply again, keeping it `pending`. **Do not sync a `pending` note to GitLab, and do not change its status** — only the user flips a note to `needs-rereview` when they've decided it's ready.
3. For each `needs-rereview` note: that's the user's signal it's settled and ready. Mirror it to GitLab (step 6) and resolve it (step 7).

You never decide a note is "done" — the user moving it to `needs-rereview` is the only thing that opens the GitLab sync. Verbal feedback in chat is fine for discussion, but **only an arbiter note in `needs-rereview` gets mirrored** — if the user wants a chat remark turned into an MR comment, ask them to drop it as an arbiter note and mark it ready.

If `arbiter list` exits 4 (`arbiter.jsonl` doesn't exist), arbiter isn't in use — there's no sync gate, so fall back to discussing verbally and tell the user nothing will be mirrored without arbiter. Don't create the file.

### 6. Mirror `needs-rereview` notes to GitLab DRAFT comments

For each arbiter note **in `needs-rereview`** on the current step — and only those — post a **draft/pending inline comment** on the MR at that line. (Notes still `pending` are mid-discussion; leave them alone.) Use the **`draft_notes`** API — NOT the `discussions` API. The `discussions` endpoint posts immediately; `draft_notes` creates a pending comment that sits in the user's unsubmitted review.

**Get the diff version SHAs once** (reuse for all comments):

```bash
glab api "projects/:id/merge_requests/<iid>/versions" | python3 -c "
import json, sys
v = json.load(sys.stdin)[0]
print(f'base: {v[\"base_commit_sha\"]}')
print(f'head: {v[\"head_commit_sha\"]}')
print(f'start: {v[\"start_commit_sha\"]}')"
```

**Post the draft note** with a `position` block (this is what makes it inline). Use a JSON body via `--input -` — the `--field`/`--raw-field` bracket notation does NOT build nested JSON and silently degrades to a non-inline note:

```bash
cat <<'JSON' | glab api --method POST "projects/:id/merge_requests/<iid>/draft_notes" --input - -H "Content-Type: application/json"
{
  "note": "Mirrored from arbiter: <the note text, lightly cleaned>",
  "position": {
    "position_type": "text",
    "base_sha": "<base_commit_sha>",
    "head_sha": "<head_commit_sha>",
    "start_sha": "<start_commit_sha>",
    "new_path": "path/to/file.ts",
    "old_path": "path/to/file.ts",
    "new_line": 42
  }
}
JSON
```

- The arbiter note's `line_start` is in the post-image (working tree), which matches `new_line`. Use `line_start` for `new_line`; for a multi-line note, anchor on `line_start` and reference the range in the body.
- `new_line` must fall within a diff hunk. If the arbiter line is outside any hunk (returns `400 ... line_code can't be blank`), anchor on the nearest in-hunk line and say so in the comment body.
- For renamed files, use the pre-rename path for `old_path`, post-rename for `new_path`.
- Mirror the **settled** note. By the time it's `needs-rereview` you've usually had a back-and-forth in the note's `comments` thread (step 5) — the comment you post should carry the conclusion that discussion reached, not the raw first draft. If the thread changed the ask (you answered a question, the user refined the suggestion), reflect the resolved version. Faithfully relay the user's intent; light cleanup (typos, formatting) is fine; don't editorialize or inject opinions they didn't land on.

**Verify it's a draft and inline.** The response should be a draft note object (has an `id`, lives under `draft_notes`). It must not appear as a submitted discussion. Never call the publish endpoints (`.../draft_notes/:id/publish` or `.../draft_notes/bulk_publish`) — **only the user submits the review.**

### 7. Resolve the arbiter note — only after the draft comment lands

Once the draft comment is successfully posted for a note, resolve that note so it drops out of the actionable list:

```bash
arbiter resolve <id>
```

Order matters: post the GitLab draft comment **first**, confirm it succeeded, **then** `arbiter resolve`. If the draft post fails, leave the arbiter note unresolved and tell the user — don't resolve a note you couldn't mirror.

(Note on the status convention: normally the `arbiter` skill says *you* set `needs-rereview` and the *human* resolves. This workflow flips both halves — the **user** sets `needs-rereview` (it's their "ready to mirror" signal, step 5), and **you** resolve once the draft comment lands, because here `resolved` means "mirrored to GitLab," not "code fixed." Only resolve a note you actually mirrored. Never set `needs-rereview` yourself — that would be deciding the discussion is over on the user's behalf, which is exactly the gate they control.)

### 8. Move to the next step

When the user says "next" (or signals they're done with this step), **move to the next step** — relay its already-built package (from the parallel build in step 3). Don't ask "ready to move on?"; the user's "next" is the signal. There's no gather-and-wait here — the package is ready, so the next step appears immediately.

A note can still be `pending` (mid-discussion) when the user moves on — that's fine; it's not ready to mirror and you don't block on it. It stays actionable and you'll mirror it later if and when the user flips it to `needs-rereview`. Before the final wrap-up, do a sweep: `arbiter list --all-statuses --json` across all steps and mirror any `needs-rereview` notes the user has settled since you last checked.

When the last step is done, report the tally: how many draft comments you posted across the review, and call out any notes still `pending` (awaiting the user, not mirrored). Remind the user the GitLab review is a **draft awaiting their submission** — they submit it from the MR's "Submit review" button. Never submit it for them.

## Anti-patterns to avoid

- **Don't edit the codebase.** This workflow is review-only. The deliverable is draft MR comments, not code changes.
- **Don't use the `discussions` API for the comments.** That posts immediately. Use `draft_notes` so the review stays pending.
- **Don't publish or submit the review.** Never call the publish/bulk_publish endpoints. Only the user submits.
- **Don't read the full branch diff in the presenter.** Delegate to the planner and the per-step gatherer subagents — that's how the presenter stays token-light.
- **Don't read all the gatherer packages at once.** Fan them out in parallel, but pull each into the presenter only when you reach that step. Reading all N up front reintroduces the context bloat the subagents exist to avoid.
- **Don't build the packages before the plan is locked.** Re-grouping makes pre-built packages stale; wait for plan approval, then fan out (and rebuild only affected steps if the user re-groups later).
- **Don't mirror a `pending` note.** Pending means mid-discussion — reply and discuss, but only `needs-rereview` notes get synced. The user owns that transition.
- **Don't flip a note to `needs-rereview` yourself.** That gate is the user's; setting it would mean deciding the discussion is over for them.
- **Don't resolve an arbiter note before its draft comment lands.** Post first, confirm, then resolve. (And only resolve notes you actually mirrored.)
- **Don't turn a verbal chat remark into an MR comment.** Only arbiter notes in `needs-rereview` get mirrored — ask the user to file it as a note and mark it ready.
- **Don't group steps by commit or by file.** Group by logical concern; order for first-time readability.
- **Don't paraphrase the diff.** Show the actual code in the message.
- **Don't skip ahead.** One step at a time; wait for the user between steps.
- **Don't editorialize the user's notes.** Mirror the settled intent faithfully; light cleanup only.

## Tools you'll lean on

- subagents (`Agent` / `Task`) — one planner, then one gatherer per step fanned out in parallel (all in a single message); this is where the heavy diff reading lives
- `git merge-base HEAD main` — find the base to diff against
- `glab mr view <iid>` / `glab api "projects/:id/merge_requests/<iid>" | jq -r '.description'` — read the MR description for the author's intent (the API form gives the full, untruncated body)
- `arbiter list --all-statuses --json` — see `pending` (discuss) and `needs-rereview` (ready to mirror) notes; `arbiter reply <id>` to discuss, `arbiter resolve <id>` after mirroring (see the `arbiter` skill)
- `glab api "projects/:id/merge_requests/<iid>/versions"` — get diff version SHAs (once)
- `glab api --method POST "projects/:id/merge_requests/<iid>/draft_notes" --input -` — post a pending inline comment (see the `glab` skill for inline-position mechanics)

## Tone

Treat each step like a code review conversation. Lead with intent, show the code, surface the non-obvious decisions, then get out of the way and let the user leave notes. Keep prose between steps short — the diff and the user's response are the substance.
