---
name: commit-cleanup
description: Rewrite a messy feature-branch commit sequence into a clean, minimal series of conventional commits that tells the story of the change. Always creates a backup branch first and validates byte-for-byte equivalence before sign-off. Use when the user says "clean up these commits", "rewrite the commit history", "squash this into a clean story", "tidy up the branch", or "turn these messy commits into a clean PR".
user_invocable: true
---

# Commit Cleanup

Rewrite a feature branch's messy commit sequence into a minimal series of conventional commits that tells the story of the change. The diff against the base branch stays identical — only the commit boundaries and messages change. Every run follows the same safety arc: **backup → propose → rewrite → validate → sign-off → delete backup**. The backup branch is the safety net; it only goes away on explicit human sign-off, never automatically.

This skill is purely local. It never mentions or runs `git push`. Remote sync is a separate decision the user owns.

Pairs with `commit-by-commit-review`: this skill creates the clean story, that one walks the user through it.

## When to use this

- A feature branch headed for review has churny commits (add/remove of the same file, fixup-then-refactor, "wip" / "oops" messages, etc.)
- The user asks to "tell the story" of the branch, "tidy up" before opening a PR, or "squash this into a clean PR"
- The user wants the commit sequence to read like a deliberate narrative rather than a record of how the work actually unfolded

## When NOT to use this

- Single-commit branches — nothing to clean up
- Branches whose commits are already clean and tell the right story
- Shared / protected branches: `main`, `master`, `develop`, `trunk` — refuse outright
- Detached HEAD — not supported
- Dirty working tree — the user must stash or commit first

## Workflow

### 1. Preflight checks

Refuse early if any of these fail:

- `git status --porcelain` is non-empty → tell the user to stash or commit first. Do not proceed.
- `git symbolic-ref -q HEAD` fails → detached HEAD; not supported.
- Current branch is `main` / `master` / `develop` / `trunk` → refuse. These are shared branches.
- `git rev-list --count <base>..HEAD` is `0` or `1` → "nothing to clean up". Stop.

### 2. Detect base branch and confirm scope

Detect the base in this order:

1. `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `refs/remotes/origin/main` → `main`)
2. Fall back to `main`, then `master`, whichever exists locally

Then show the range and confirm with the user before any branch operations:

```
git log --oneline <base>..HEAD
```

Ask: "Cleaning up these N commits on top of `<base>`. Proceed?" Do not move on until the user confirms the range.

### 3. Detect commit convention

Check in this precedence order, stopping at the first signal:

1. `CONTRIBUTING.md` or `.github/CONTRIBUTING.md` — search for a commit-message section
2. `commitlint.config.*` / `.commitlintrc*` / `package.json` `commitlint` key
3. `.gitmessage` template
4. Sample the last 30 commits on the base branch: `git log --oneline -n 30 <base>`

Default to **Conventional Commits** (`type(scope): subject`) only when at least one signal points to it. If the signals are silent or ambiguous, ask the user explicitly which convention to use. Do not guess.

### 4. Create the backup branch

```bash
git branch backup/<branch>-<UTC-YYYYMMDD-HHMMSS> <branch>
```

Local-only. No checkout. No push. Tell the user the exact backup name so they can `git reset --hard backup/<...>` at any point if something goes sideways.

### 5. Read every commit in the range

```bash
git log --stat <base>..HEAD
git show <hash>   # for each commit
```

While reading, identify:

- Files added in one commit and removed in a later one (will *not* appear in the final tree — surface these in the proposal so the user confirms they should stay dropped)
- Files churned then refactored (the final state is what matters; the intermediate steps are noise)
- The true *final-state* intent of each logical change group — what does each group accomplish in the end state, not what did the messy commit say at the time

### 6. Propose the clean sequence

Present a numbered proposal. For each planned commit:

- **Subject line** in the detected convention (e.g. `feat(api): add rate-limit middleware`)
- **One-paragraph body** describing what and why (final intent, not "what the old commit said")
- **Files** (or specific hunks) that belong in this commit

Then a separate section: **Files added then removed by the old history** — list them so the user explicitly confirms they should remain dropped.

End with:

> Approve to proceed, or edit. I won't run any rewrite commands until you say go.

**Do not run rewrite commands until explicit approval.** Iterate on the proposal until the user says go.

### 7. Execute the rewrite on a sibling branch

Never rewrite on the live branch directly. Work on a sibling and only move the live pointer after validation passes.

```bash
git switch -c <branch>-rewrite
git reset --soft <base>
git reset                          # unstage everything; working tree unchanged

# for each proposed commit i, in order:
git add <files-for-commit-i>       # or `git add -p` when a file straddles commits
git commit -m "<subject>" -m "<body>"
```

Hunk splitting via `git add -p` **only** when a single file genuinely belongs in two commits. Default to whole-file staging — it's simpler and harder to get wrong.

### 8. Validate byte-for-byte

Run all three and report each result:

```bash
git diff backup/<...>..HEAD                  # must be empty
git diff --stat backup/<...>..HEAD           # must be empty
git rev-parse 'backup/<...>^{tree}'          # must match…
git rev-parse 'HEAD^{tree}'                  # …this value
```

If any check disagrees:

- **Stop.** Do not advance.
- Surface the diff to the user.
- Keep the backup in place.
- Suggest: `git reset --hard backup/<...>` if they want to revert the rewrite branch and start over.

Only when all three checks pass do you continue.

### 9. Move the live branch pointer

Only after validation passes:

```bash
git branch -f <branch> <branch>-rewrite
git switch <branch>
git branch -D <branch>-rewrite
```

Show the final `git log --oneline <base>..HEAD` so the user can see the new story.

### 10. Request sign-off

Use this exact wording template:

> Rewrite is complete and validates byte-for-byte against `backup/<...>`. New log:
>
> ```
> <paste git log --oneline output>
> ```
>
> If this looks right, say "sign off" or "delete the backup" and I'll remove `backup/<...>`. Otherwise the backup stays in place and you can `git reset --hard backup/<...>` to undo.

Then **wait**. Do not delete the backup in the same turn as the rewrite. Validation passing is not sign-off.

### 11. Delete backup on explicit sign-off only

When the user says "sign off" / "delete the backup" / equivalent:

```bash
git branch -D backup/<...>
```

Confirm deletion to the user. Never mention `git push`. Remote sync is the user's separate decision.

## Anti-patterns to avoid

- **Don't skip the backup branch.** Every run starts with the backup. No exceptions.
- **Don't delete the backup before sign-off.** Validation passing is not sign-off. Two separate turns.
- **Don't rewrite shared branches.** `main` / `master` / `develop` / `trunk` — refuse.
- **Don't proceed with a dirty working tree.** Tell the user to stash or commit first.
- **Don't proceed if byte-for-byte validation fails.** Stop, surface the diff, keep the backup.
- **Don't guess the commit convention.** Check `CONTRIBUTING.md`, commitlint config, `.gitmessage`, then sample recent commits on the base. Ask if still ambiguous.
- **Don't rewrite without a proposal.** Always show the planned commits (subjects + bodies + file groupings) and get explicit approval first.
- **Don't drop files silently.** Surface added-then-removed files in the proposal so the user confirms.
- **Don't paraphrase old commit messages.** Write fresh subjects describing final intent — not "what the old commit said".
- **Don't mention `git push`.** Remote sync is a separate decision the user owns.

## Tools you'll lean on

### Inspection
- `git status --porcelain`
- `git symbolic-ref --short HEAD`
- `git symbolic-ref refs/remotes/origin/HEAD`
- `git log --oneline <base>..HEAD`
- `git log --stat <base>..HEAD`
- `git show <hash>`
- `git log --oneline -n 30 <base>`

### Convention detection
- `CONTRIBUTING.md`, `.github/CONTRIBUTING.md`
- `commitlint.config.*`, `.commitlintrc*`
- `package.json` (`commitlint` key)
- `.gitmessage`

### Backup
- `git branch backup/<branch>-<UTC-timestamp> <branch>`

### Rewrite
- `git switch -c <branch>-rewrite`
- `git reset --soft <base>`
- `git reset`
- `git add <files>` / `git add -p`
- `git commit -m "<subject>" -m "<body>"`
- `git branch -f <branch> <branch>-rewrite`
- `git switch <branch>`
- `git branch -D <branch>-rewrite`

### Validate
- `git diff backup/<...>..HEAD`
- `git diff --stat backup/<...>..HEAD`
- `git rev-parse '<ref>^{tree}'`

### Cleanup (post sign-off only)
- `git branch -D backup/<...>`

## Tone

Opinionated proposal, careful execution. Lay out the planned story decisively — that's the value the user is paying for. But always wait for an explicit "go" before any destructive operation, and never delete the backup without sign-off. When validation surfaces a divergence, stop and surface it plainly; don't try to paper over it. The backup is the safety net — treat it as sacred until the user releases you.
