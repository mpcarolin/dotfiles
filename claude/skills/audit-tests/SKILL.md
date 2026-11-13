---
name: audit-tests
description: Use when work that added or changed tests is finished, before committing it or opening an MR, and when asked to review, prune, clean up, dedupe, or cut tests. Symptoms include a large test diff next to a small feature, tests that copy config or literals, heavy stubbing, tests that skip in CI, or a suite that grew during a "cleanup".
---

# Audit Tests

A test earns its place when it fails for a real bug that nothing else would catch first. Everything else costs reading and maintenance and buys nothing.

You wrote the tests, so you don't judge them. A fresh reviewer does, and you apply its verdicts.

## Steps

1. **Scope.** Find the base (`git merge-base <base> HEAD`; base is what the user named, else the default branch). List the test files the branch added or changed with `git diff <base-sha> --stat`.
2. **Dispatch a fresh reviewer.** Use the Agent tool (`general-purpose`) with the full text of [reviewer.md](reviewer.md) as the prompt, followed by:
   - repo path, base sha, and the test files from step 1
   - how to run the tests, if you know, including any env or path setup needed so they import this checkout and not another one
   - what the feature does, in one or two sentences

   Don't send your opinion of the tests. Don't edit anything while it runs.
3. **Check the tree.** When it returns, `git status` must match what it was before you dispatched. If the reviewer left a mutation behind, restore it before doing anything else.
4. **Apply the verdicts.**
   - `cut`: delete the test, or revert a changed test to base. Apply `merged into:` and `fix:` lines as written.
   - `block`: leave that test alone, and restore it if the branch deleted it.
   - `ask`: change nothing yet. Show the user the reviewer's **Ask** groups and ask, per group, whether to cut those tests or make the CI change. Don't make CI changes unless the user says so. For a group the user keeps, apply its `fix:` lines.

   Fix any live doc or comment that names a test you cut. Leave plans and specs that record past work alone. Never add a test during this pass.
5. **Run the tests** that remain and confirm they pass.
6. **Report** to the user: the reviewer's summary table, test lines added vs base before and after (`git diff <base-sha> --stat -- <test paths>`), and the gaps it listed, as suggestions only.

## Common mistakes

| Mistake | Fix |
|---|---|
| Auditing your own tests in place | Dispatch the reviewer. You're anchored on why you wrote them. |
| Writing new tests to "strengthen coverage" | This pass only removes or tightens. Report gaps instead. |
| Overriding a `cut` because the test "might be useful" | Apply every cut. If you disagree with one, apply it anyway and say which and why in the report. |
| Deciding an `ask` yourself, either way | It's the user's call: cutting loses a real check, changing CI is outside this pass. |
| Leaving a `block` deletion in place | Restore the test. |
