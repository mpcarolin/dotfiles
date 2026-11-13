---
name: teardown
description: Use when the user is finished with a Herdr worktree and wants it torn down — e.g. "/teardown", "/teardown keep volumes", "tear this worktree down", "clean up this worktree", "I'm done here, delete the worktree". Also use when leftover Docker Compose projects or detached processes from deleted worktrees need finding. Requires running inside Herdr (HERDR_ENV=1).
---

# Teardown

Tear down the Herdr worktree this session runs in: the Docker Compose projects started from it
(with volumes), other processes it started that would outlive it, any orphans on the machine the
user approves, and finally the git worktree plus its Herdr workspace. Removing the workspace ends
this session, so it is always the last call.

**Scope:** local only. Never push, delete remote branches, change PR/MR state, or call any remote
API. Never delete a local branch either; the user cleans branches up separately.

`<skill-dir>` below is this skill's directory. Run its scripts with `bash`.

A project-specific skill may wrap this one and add its own inspect and stop steps (for example
a dev-environment CLI that must be used instead of raw `docker compose`). When it does, its steps
replace the matching ones here; everything else still applies.

## Overrides

Free text after `/teardown`, or in the reply to the confirmation, overrides any default below:
"keep volumes", "leave the containers running", "skip orphans", "don't kill 1234",
"discard my changes", "don't remove the worktree". Apply exactly what was asked. An override never
widens scope to anything remote or to deleting a branch; if asked, say that is out of scope.

## Phase 1: Inspect (read-only)

1. `test "${HERDR_ENV:-}" = 1`, else stop and tell the user.
2. `WT=$(git rev-parse --show-toplevel)`. Find the entry in `herdr worktree list --cwd "$WT"`
   whose `path` resolves to the same directory (compare `realpath` of both). Keep its
   `open_workspace_id` as `$WS` and its `branch`.
   - Not `is_linked_worktree: true` (the main checkout): say teardown only removes linked
     worktrees, and offer the orphan sweep (step 7) alone.
   - `$WS` is null or differs from `$HERDR_WORKSPACE_ID`: stop. Removing `$HERDR_WORKSPACE_ID`
     would close a different workspace than the one this worktree is open in.
3. **Compose projects** started from this worktree (compose labels the working dir). Skip this
   step if `docker` is not installed or its daemon is not running.
   ```bash
   docker ps -a --filter "label=com.docker.compose.project.working_dir=$WT" \
     --format '{{.Names}}\t{{.Status}}\t{{.Label "com.docker.compose.project"}}'
   ```
   Also check subdirectories: list all `working_dir` labels and keep those equal to `$WT` or under
   `$WT/`.
4. **Other processes** that would outlive the workspace: `bash <skill-dir>/scripts/survivors.sh "$WT"`.
   One line per detached subtree root, with its kind:
   - `detached`: already outlives its launcher (dev servers, `docker compose watch`, browser
     daemons). Will stop.
   - `chrome-helper`: Chrome crash handlers that headless-browser daemons leave under launchd.
     Will stop. Report them as one line with a count; nothing ties a helper to a specific daemon.
   - `background:claude` (or another agent): a background task from an agent session in this
     worktree. It runs in its own session, so closing the pane does not stop it. Will stop.
   - `background:<editor or other>` (for example `nvim --embed`): owned by a live terminal program
     that exits with the pane and takes it along. Leave it out.
5. **Uncommitted work:** `git -C "$WT" status --porcelain`. Anything here **blocks** worktree
   removal unless the user explicitly says to discard it.
6. **What survives in the shared repo**, for the Kept list:
   - Stashes for this branch: `git -C "$WT" stash list | grep -F -e "On $branch:" -e "WIP on $branch:"`.
   - Ahead/behind: `git -C "$WT" rev-list --left-right --count @{upstream}...HEAD` prints
     `<behind> <ahead>` against the last-fetched upstream (no fetch). Report both; if there is no
     upstream, say so. The branch is kept, so nothing is lost, but the user should know.
7. **Orphans, machine-wide.** Compose projects whose working dir is gone:
   ```bash
   docker ps -a --filter label=com.docker.compose.project.working_dir \
     --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.project.working_dir"}}'
   ```
   then `test -d` each dir. A project whose dir still exists is not an orphan.

## Phase 2: One confirmation

Send one message and wait. Sections, in order, each a short list (write "none" where empty):

- **Will stop:** each compose project ("+ volumes" unless overridden) and survivor root (pid,
  short name, descendant count), with Chrome helpers as one counted line.
- **Orphans found:** each one and why it is orphaned. They are handled only if the user says so.
- **Blocking:** uncommitted changes, by file. Teardown stops before removing the worktree unless
  told to discard them.
- **Then:** "Remove worktree `<path>` and Herdr workspace `<$WS>`. This ends this session."
- **Kept:** the local branch (with ahead/behind), this branch's stashes, `background:<editor>`
  processes (they exit with their pane), and anything an override excludes.

The reply is the go-ahead and may carry overrides. Apply them and proceed. Ask again only if the
reply is ambiguous about something destructive.

## Phase 3: Execute (no more questions)

Report each failure and keep going, except where a step says stop:

1. **Compose projects:** for each, `docker compose -p <project> down --volumes` (drop `--volumes`
   if the user said keep volumes), then
   `docker volume ls -q --filter label=com.docker.compose.project=<project> | xargs -r docker volume rm`.
2. **Survivors:** `kill` each approved root and the Chrome helpers. After a few seconds, re-run
   `survivors.sh` and `kill -9` pids from the approved list that are still there. Never kill a pid
   that was not in the approved list; a new one is not approved.
3. **Approved orphans:** the same as step 1.
4. **Verify:** re-run the Phase 1 step 3 container check and `survivors.sh "$WT"`. Only items the user
   chose to keep may remain. If uncommitted changes remain and the user did not say to discard
   them, print the report (step 5) and stop here.
5. **Final report**, printed now because the session is about to end: what was stopped, what
   failed, what was kept.
6. **Remove the worktree, last:** `herdr worktree remove --workspace "$WS"`, adding `--force` only
   when the user said to discard changes. This closes the workspace and ends this session.

## Common mistakes

| Mistake | Fix |
|---|---|
| `docker compose down` without `--volumes` | Always add it unless the user said keep volumes |
| Listing pane shells, editors, or this session's `claude` | Only `survivors.sh` output; leave `background:<editor>` lines out |
| Skipping `background:claude` lines because they sit under a terminal | They run in their own session and survive; stop them |
| Killing a pid that showed up only on the re-run | Kill only pids the user approved |
| Running the scripts with zsh | `bash <script>`; zsh aborts on empty globs |
| Calling another live worktree's compose project an orphan | Only projects whose working dir is gone |
| `herdr worktree remove --workspace $HERDR_WORKSPACE_ID` without checking | Use `$WS` from step 2; stop if they differ |
| Asking again before each step | One confirmation, then execute |
| Deleting the branch or touching the remote | Out of scope, even if asked mid-run: say so |
