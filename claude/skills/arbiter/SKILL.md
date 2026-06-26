---
name: arbiter
description: Read and update arbiter review notes left by a human reviewer for AI-written code. Notes live in <git_dir>/arbiter.jsonl as JSONL records keyed by branch. Use when a workflow needs to consume reviewer feedback, or when the user says "check my comments", "I replied to your comments", "arbitrate", or otherwise asks you to address arbiter notes. Covers the CLI invocation, status taxonomy, and the narrow rules for writing back.
user_invocable: false
---

# Arbiter

Arbiter is a Neovim plugin that lets a **human** leave structured review notes on code an **AI** wrote. Notes are persisted to `<git_dir>/arbiter.jsonl` and exposed to the AI side via a small CLI. This skill is the AI side of that contract.

## When to use

- A workflow defers to arbiter for the feedback channel
- The user says "check my comments", "I replied to your comments", "arbitrate", "address the arbiter notes", "check arbiter", or similar
- You're about to ask the user for review feedback on a branch — check arbiter first; structured notes there are authoritative over verbal/inline equivalents

## Invocation

Always go through the `arbiter` CLI. Don't read or write `arbiter.jsonl` directly — the CLI handles git-dir resolution, branch filtering, and atomic writes for you.

```
arbiter list [filter flags...] [--json]
arbiter show <id> [--json]
arbiter set-status <id> <pending|in-progress|needs-rereview|resolved>
arbiter resolve <id>
arbiter reply <id> [--author <name>] < body
```

The CLI lives at `~/.local/bin/arbiter` (symlinked from `~/.config/nvim/arbiter/cli.lua`). It must run from inside a git repo. Useful exit codes:

- `3` — not inside a git repo
- `4` — `arbiter.jsonl` doesn't exist (arbiter isn't in use here — fall back to whatever feedback channel the parent workflow specifies; **don't** create the file)
- `5` — id not found on the current branch

`arbiter list` defaults to actionable notes on the current branch (`pending` + `needs-rereview`, sorted chronologically with resolved pushed to the end). It already filters by branch — you don't have to.

## Record schema

The JSON returned by `arbiter list --json` (and `arbiter show <id> --json`) is one object per record:

```json
{
  "id": "b47506e8",
  "file": "src/foo.ts",
  "line_start": 42,
  "line_end": 47,
  "commit": "abc123def456",
  "branch": "feature-x",
  "note": "this should be debounced — see why below…",
  "created_at": "2026-04-30T14:22:00-04:00",
  "status": "pending",
  "author": "human",
  "comments": [
    { "author": "ai", "body": "picked 250ms — matches existing throttle", "created_at": "2026-05-07T15:01:12-04:00" }
  ]
}
```

| field | meaning |
|---|---|
| `id` | 8-char hex hash of `(file, line_start, branch, created_at)`. Use this when calling `set-status`/`resolve`/`show`/`reply` |
| `file` | repo-relative path |
| `line_start`, `line_end` | 1-indexed range in the **post-image** of the diff (the working tree, not the old version) |
| `commit` | short SHA the note was filed against if the user wrote it from a fugitive diff buffer; `null` otherwise. Informational only |
| `branch` | branch name, or short SHA on detached HEAD; `null` on error |
| `note` | free text, may be markdown — preserve fences/bullets when reading |
| `created_at` | ISO-8601 with offset |
| `status` | `pending` \| `in-progress` \| `needs-rereview` \| `resolved` |
| `author` | free-form string (`"human"` for plugin-created notes, `"ai"` or an agent name like `"claude-opus"` for CLI replies). Missing `author` reads as `"human"` for backward compatibility |
| `comments` | optional array of replies (one level — replies cannot themselves have replies). Each entry is `{author, body, created_at}`. Missing/empty means no replies; the field is only written once a reply exists |

Always read the **full** `line_start..line_end` range from the file before reasoning about a note — single-line `line_start` is common but multi-line notes are real, and the surrounding code is the context the user expected you to read.

## What to act on

After `arbiter list` returns, only these statuses appear by default:

| status | meaning | AI action |
|---|---|---|
| `pending` | new note, untouched | work it |
| `needs-rereview` | you previously addressed it, user hasn't signed off | re-examine; if the user pushed back, address again |

You can pass `--all-statuses` (or `--status in-progress`, `--status resolved`) to see the others. Default behavior is what you want for "address the open notes."

- `in-progress` — currently being worked. Usually skip (another agent or session may own it). If the user explicitly asks you to continue, the choice is theirs.
- `resolved` — user has signed off. Don't touch.

## Updating status

`arbiter set-status <id> <status>` mutates only that record's `status` and atomically rewrites the JSONL. The four statuses are `pending`, `in-progress`, `needs-rereview`, `resolved`.

The default flow when addressing a note:

1. `arbiter set-status <id> in-progress` (signals you've started)
2. apply the change in the working tree
3. `arbiter set-status <id> needs-rereview` (signals you're done; awaits the human's sign-off)

**Only set `resolved` if the human has explicitly asked you to.** The default after addressing a note is `needs-rereview` — let the human confirm. `arbiter resolve <id>` is a shorthand for `set-status <id> resolved`; reach for it only when the user said "close these out" or equivalent.

You **must not**:
- Write to `arbiter.jsonl` outside of `set-status`/`resolve`/`reply` (no creating, deleting, reordering, editing field bodies).
- Set `status` to `pending` — only the plugin sets that on initial write.
- Set `status` outside the four-value taxonomy (the CLI will reject it with exit code 1).
- Add new notes — the human writes notes, not you.

## Replying

`arbiter reply <id> [--author <name>] < body` appends a reply (one level deep — replies cannot themselves have replies) to a note's `comments` array. Replies are **additive context**, not a status substitute: the status field stays the source of truth for "is this addressed."

When to reply:
- **Substantive context** the human will need on re-review: why you picked a specific value, the tradeoff you weighed, a follow-up question that's blocking the change.
- **Clarification** when the note is ambiguous and you've made an interpretation worth surfacing.
- **Dissent** when you disagree with the note — explain why before flipping to `needs-rereview`.

When **not** to reply: trivial fixes that need no explanation. The diff speaks for itself.

Default flow with a reply:

1. `arbiter set-status <id> in-progress`
2. apply the change
3. `arbiter reply <id> < explanation`
4. `arbiter set-status <id> needs-rereview`

`--author <name>` lets you identify the agent (e.g. `--author claude-opus`). Default is `"ai"`. **Never write `"human"` from the CLI** — that field is reserved for the plugin's note-create and reply-create paths.

Replies render as markdown in the plugin's preview window. Use ` ``` ` fences for code; a bare fence (no language tag) defaults to the parent note's file language, so you usually don't need to specify it. Add an explicit tag (` ```bash `, ` ```json `, …) when the snippet isn't in the same language as the note's file.

## Identity

Use the `id` field returned by `arbiter list --json` / `arbiter show`. Don't invent ids; don't rely on positional order.

## Example flow

A typical session looks like:

1. `arbiter list --json` — get the open notes for the current branch.
2. For each note: read `file:line_start..line_end` from the working tree to see the context.
3. `arbiter set-status <id> in-progress`
4. Apply the change.
5. `arbiter set-status <id> needs-rereview`
6. Move on. Don't touch `resolved` unless the user said to.

When all actionable notes are done, tell the user what you did and which notes are awaiting their re-review.

## Notifying the user when done

When all actionable notes for this session are in `needs-rereview` (i.e. you're finished with the batch and handing back to the human), fire a notification in their editor:

```bash
[ -n "$NVIM" ] && nvim --server "$NVIM" --remote-expr \
  "luaeval(\"require('arbiter-claude').notify_ready({count=_A})\", $COUNT)" \
  >/dev/null 2>&1 || true
```

Where `$COUNT` is the number of notes you flipped to `needs-rereview` in this session. This sends a green toast in the nvim that owns this Claude session. Skip silently if `$NVIM` is unset (you're not running under nvim's `termopen`) or if the `require` fails (the bridge plugin isn't installed) — the surrounding `|| true` handles both.

Do **not** fire this if you only replied without changing status, or if some notes are still `in-progress`/`pending` (e.g. you ran out of context and stopped mid-batch). The toast is the "I'm done, please re-review" signal.

## Anti-patterns

- **Inventing or guessing IDs.** Always pull them from `arbiter list --json` / `arbiter show`.
- **Running on the wrong branch.** The CLI uses the current branch automatically; don't pass `--branch` unless you have a specific reason.
- **Creating `arbiter.jsonl` when it doesn't exist.** Exit 4 from the CLI means arbiter isn't in use here — fall back to whatever feedback channel the parent workflow specifies.
- **Reading the JSONL directly with `Read` / `cat`.** Use `arbiter list --json` so the agent only sees the small filtered output it needs. The whole-file read is what the CLI exists to avoid.
- **Treating `--all-statuses` output as actionable.** Resolved notes are done; in-progress notes may be owned by someone else.
- **Fabricating replies for notes you didn't actually address.** A reply is a record of work — don't post one for a change you didn't make.
- **Impersonating the human via `--author`.** The `human` author is reserved for plugin-created records. Use `ai` (default) or an agent name like `claude-opus`.
- **Replying instead of changing status.** A reply doesn't move a note from `pending` to `needs-rereview`; you still have to call `set-status`. Replies augment status, they don't replace it.
