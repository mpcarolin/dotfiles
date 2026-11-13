---
name: handoff
description: Hands a task the user has been discussing in this conversation to a separate Claude agent, which does the work on a new branch in its own Herdr worktree, using a self-contained task brief. Use when the user wants work discussed here carried out by another agent in its own worktree — e.g. "/handoff", "/handoff <hint>", "hand this off", "spin up an agent to build this", "open a herdr worktree and have claude do it". Requires running inside Herdr (HERDR_ENV=1).
---

# Handoff

You are the dispatcher. You turn the task from this conversation into a brief, create a new branch
in a new Herdr worktree, start a Claude agent there, and give it the brief. Then you stop. The
user takes over the agent.

The new agent sees none of this conversation. The brief is all it gets, so writing it is the main
job.

**REQUIRED:** load the `herdr` skill first. If a fetch or the network fails inside the sandbox,
rerun with the sandbox disabled.

## Steps

1. **Check Herdr.** Run `test "${HERDR_ENV:-}" = 1`. If it fails, stop and tell the user.

2. **Pin down the task.** From the conversation (and the `/handoff` args, if any), work out:
   the goal, what "done" means, and what has already been decided. If the args name a task, use
   that one. If the conversation covers several candidate tasks and the args don't pick one, or
   "done" is still an open question the user hasn't answered, ask once before creating anything.
   Otherwise go ahead without asking.

3. **Find the repo.** Use the repo the task lives in: the one the conversation has been working
   in (`git rev-parse --show-toplevel` from the relevant directory), or the one it names. Call
   its root `$REPO` and run every later git and herdr command against it (`git -C "$REPO"`,
   `--cwd "$REPO"`). If it's unclear which repo, ask. Do not clone anything.

4. **Pick the base and the branch name.**
   - **Base:** the branch the user named, else origin's default branch
     (`git -C "$REPO" symbolic-ref --short refs/remotes/origin/HEAD`, minus the `origin/`).
   - **Branch:** follow the repo's naming convention. Check it with
     `git -C "$REPO" for-each-ref --sort=-committerdate --count=15 --format='%(refname:short)' refs/remotes/origin`.
     Include the ticket key if the conversation has one (e.g. `ABC-123-short-slug`). Keep the
     slug short.
   - **Agent name:** `ho-<short-slug>`. If `herdr agent list` shows that name taken, add a
     suffix such as `-2`.

5. **Check for collisions.** Run `herdr worktree list --cwd "$REPO"` and
   `git -C "$REPO" branch --list <branch>`, and check `git -C "$REPO" ls-remote --heads origin <branch>`
   after the fetch in step 6.
   - If a worktree has `.branch` equal to `<branch>` and its `open_workspace_id` has an agent
     (`herdr agent list`: matching `workspace_id`, or a `cwd` under the worktree's `path`),
     **stop before changing anything**. Tell the user the worktree path, the agent's `pane_id`,
     and its status, and wait for instructions.
   - If the branch already exists locally or on origin, someone may have started this work.
     Tell the user and ask whether to pick another name or build on that branch. Don't guess.

6. **Fetch the base.** `git -C "$REPO" fetch origin <base>`, then
   `git -C "$REPO" rev-parse origin/<base>`. If either fails, read the output and fix the problem
   before you go on. Keep that SHA as `<base_sha>`.

7. **Create the worktree.**
   `herdr worktree create --cwd "$REPO" --branch <branch> --base origin/<base> --label "<Short task label>" --no-focus`.
   Without `--base`, the new branch starts at the clone's current HEAD. Keep
   `.result.root_pane.pane_id` and the worktree path. Use `create`, not `open`: `open` only
   attaches a worktree that already exists and errors `worktree_not_found`.

8. **Verify the checkout.** `git -C <worktree> rev-parse HEAD` must equal `<base_sha>`. If it
   doesn't, stop and tell the user both SHAs. Then run
   `git -C <worktree> branch --unset-upstream`. Git makes a branch created from `origin/<base>`
   track `origin/<base>`, and a plain `git pull` or `git push` on it would then go to the base
   branch.

9. **Carry over local-only context.** The worktree has only what is committed on `<base>`.
   Anything the task depends on that isn't — uncommitted edits in the user's checkout, an
   untracked plan or spec, a scratchpad file, notes elsewhere on disk outside the repo —
   either goes in the brief (paste it) or gets referenced by absolute path if it lives outside
   the repo. Never point the agent at a repo-relative path that only exists in the other
   checkout.

10. **Start the agent.** `herdr agent start <name> --kind claude --pane <pane_id>`. If start
    returns `agent_not_ready`, run `herdr agent wait <name> --timeout 60000`. If it settles on
    `blocked`, it is waiting at a startup dialog. Tell the user and stop.

11. **Write the brief** to your scratchpad (`<name>-brief.md`) using the template below. Then send
    it **without `--wait`**: `herdr agent prompt <name> "$(cat <scratchpad>/<name>-brief.md)"`.
    `--wait` blocks until the work finishes, which can take many minutes and time out.

12. **Hand off.** Run `herdr agent wait <name> --until working --until blocked --timeout 15000`
    once. Tell the user the workspace label, the agent name, the branch, the worktree path, the
    brief's path, and the status you saw. Then stop. Don't poll, read, or answer the agent's
    prompts. If it's `blocked`, say so and leave it to the user. If it times out while still
    `idle`, tell the user. Don't re-send the brief.

## Brief template

Fill every section from the conversation. Write facts and decisions, not a transcript. Where a
section has nothing, write "None".

```markdown
<One sentence: what to build or change, and why.>

## Your checkout
This worktree is on a new branch `<branch>`, created from `origin/<base>` at <base_sha>. It has
no upstream. Compare against `origin/<base>`.

## Background
<The problem and why it matters. What the user and I found while discussing it: how the current
code works, root causes, constraints from other systems.>

## Decisions already made
<Each decision with its reason. Include approaches considered and rejected, and why, so you don't
reopen them.>

## Where to look
<file:line pointers, functions, docs, tickets, and URLs found during the discussion, each with a
note on why it matters. Paste any local-only context from step 9 here.>

## Open questions
<Things not yet settled. For each, say whether to decide yourself (with a suggested default) or
to stop and ask me.>

## Done when
<Concrete, checkable outcomes: behavior, tests that pass, commands that succeed.>

## Ground rules
1. Read the repo's CLAUDE.md and any docs for the area you touch before you start.
2. Commit your work to `<branch>` as you go. Do not push, open a pull request, or post anywhere.
3. When you're done, report to me here: what you changed (file:line), how you tested it, and
   anything you left undone or decided differently from this brief.
```

Adjust the ground rules only when the conversation explicitly settled them differently (for
example, the user said the agent may push, or should not commit).

## Common mistakes

| Mistake | Fix |
|---|---|
| Brief says "as we discussed" or "the approach above" | The agent can't see this conversation. Write the approach out |
| Brief points at an untracked file or uncommitted edit by repo path | Step 9: paste it, or use an absolute path outside the repo |
| Brief drops rejected approaches | Put them under "Decisions already made" with the reason |
| Worktree HEAD isn't the base tip | You left out `--base`. Check `rev-parse HEAD` against `<base_sha>` |
| New branch tracks `origin/<base>` | `git branch --unset-upstream` right after creating it |
| Reusing a branch that already exists | Step 5: tell the user and ask |
| `agent prompt --wait` times out | Send without `--wait`, then check once with `agent wait --until working --until blocked` |
| Following the agent after handoff | Stop after the one status check |
