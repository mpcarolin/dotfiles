---
name: audit-comments
description: Use when work that added or changed code comments is finished, before committing it or opening an MR, and when asked to review, trim, cut, or clean up comments. Symptoms include comments that restate the next line, docstrings that repeat the signature, change-history narration ("now uses X", "added for RAG-123"), section banners, and multi-line comments where one short line would do.
---

# Audit Comments

Most code needs no comments. A comment earns its place only when it tells the reader something
important that the code can't: a reason, a constraint from outside the code, or a trap. Everything
else is noise the reader has to skip and someone has to keep true.

You wrote the comments, so you don't judge them. A fresh reviewer does, and you apply its verdicts.

## Scope: only new comments

Audit only comments the change adds or edits. Leave every other comment alone.

The user says which change. Map what they said to a diff:

| User says | Diff | Untracked files |
|---|---|---|
| `working`, "my changes", "uncommitted" | `git diff HEAD` (staged + unstaged) | include |
| `staged` | `git diff --cached` | skip |
| `unstaged` | `git diff` | include |
| `branch`, "this branch", "the MR" | `git diff <base-sha>` where `<base-sha>` is `git merge-base <parent> HEAD` | skip |

For `branch`, the parent is what the user named, else `git merge-base --fork-point main HEAD`, else
`main`. If the user gave no scope at all, ask: working changes or the branch, and against which
parent. Don't guess.

## Steps

1. **Scope.** Resolve the diff command from the table. Run it with `--stat` to list the files, and
   note `git status --short` so you can check the tree later.
2. **Dispatch a fresh reviewer.** Use the Agent tool (`general-purpose`) with the full text of
   [reviewer.md](reviewer.md) as the prompt, followed by:
   - repo path, and the exact diff command from step 1 (plus untracked files, if the table says so)
   - what the change does, in one or two sentences

   Don't send your opinion of the comments. Don't edit anything while it runs.
3. **Check the tree.** `git status --short` must match step 1. The reviewer is read-only.
4. **Apply the verdicts.**
   - `cut`: delete the comment. If the line is code with a trailing comment, delete only the comment.
   - `rewrite`: replace the comment with the reviewer's text, as written.
   - `keep`: leave it.
   - `ask`: change nothing yet. Show the user the reviewer's question and apply their answer.
   - `stale` (in **Noticed**): an old comment the change made false. Show it to the user; don't fix it unless they say so.

   Touch nothing but comment text. Never add a comment in this pass.
5. **Verify** with the same diff command: every hunk you changed differs only in comment lines.
   Run the formatter or linter if the repo has a fast one, since a deleted comment can leave a blank
   line or an empty block behind.
6. **Report** to the user: the reviewer's summary table, the counts line, and any `stale` comments.
   For `staged` scope, say that your edits are unstaged and need `git add`.

## Common mistakes

| Mistake | Fix |
|---|---|
| Auditing your own comments in place | Dispatch the reviewer. You're anchored on why you wrote them. |
| Auditing comments the change didn't touch | Only added or edited comment lines are in scope. Report stale ones, don't edit them. |
| Overriding a `cut` because the comment "might help someone" | Apply it. If you disagree, apply it anyway and say which and why in the report. |
| Softening a `rewrite` back toward the original | Use the reviewer's text. |
| Replacing a cut comment with a better one | A cut means no comment. |
| Removing lint or type directives (`eslint-disable`, `# noqa`, `@ts-expect-error`) | Those are code. Only the free text after them is judged. |
