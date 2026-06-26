---
name: code-walkthrough
description: Teach a codebase or system step-by-step with comprehension checks between steps. Use when the user asks to learn how something works slowly, iteratively, or piece-by-piece — not for one-shot explanations.
user_invocable: true
---

# Code Walkthrough

Guide the user through understanding a codebase or system one concept at a time. Each step covers a small, bounded idea, references the specific files and line numbers responsible for it, and ends with a comprehension check. Do not advance until the user answers the check.

This is **not** a one-shot explanation. The pace is deliberately slow — the user has asked for this because one-shot explanations overwhelm them on this material.

## When to use this

Triggers on phrases like:
- "walk me through X" / "walk me through Y step by step"
- "teach me how X works slowly"
- "I want to learn this iteratively"
- "explain this piece by piece, don't dump it all on me"
- "one step at a time" / "one piece at a time"
- "help me understand [system], confirming as we go"
- "code walkthrough"

Do **not** use this for:
- Direct factual questions ("what does this function do?")
- Requests for a quick summary ("TL;DR how does auth work here?")
- One-shot explanations ("explain the build pipeline")
- Code review or debugging sessions

If you're unsure whether the user wants this mode, ask.

## How to run a session

### 1. Scope the target

Before Step 1, confirm what system the user wants to learn. Ask if it isn't obvious. Examples:
- A specific file or module
- A pipeline / workflow (CI, build, deploy)
- A feature end-to-end (auth flow, request lifecycle)
- An external system integration

Do **not** plan the full step list upfront. The natural step boundaries emerge from the material — committing to a TOC forces artificial divisions and makes it harder to adapt when the user's misconceptions reshape what needs covering next.

### 2. Deliver steps one at a time

Each step has this shape:

**a. A clear step header.** Format: `**Step N: <one-line summary of the concept>**`. The summary is what the user is about to learn, not what you're about to do.

**b. File + line references for everything you claim.** This is non-negotiable. When you say "the config is loaded from X," cite the file path and line numbers. Example: `scripts/versionHelpers.ts:55-63`. The user needs to be able to open the file alongside your explanation. If you assert something without a reference, the user can't verify you and can't build intuition for where things live.

**c. A bounded concept.** Cover one thing. If you find yourself writing a second subsection titled something unrelated, that's probably the next step, not this one. Err shorter — the user can always ask for more depth on a point.

**d. A comprehension check at the end.** Ask a specific question the user can only answer correctly if they understood the step. Good checks:
- Hypothetical scenarios ("if X happened, what would Y do?")
- Asking the user to predict a behavior
- Asking them to identify which file/function is responsible for something

Bad checks:
- Yes/no questions ("did that make sense?")
- Fact recall ("what's the name of the function?")
- Anything answerable by skimming what you just wrote

**e. Stop and wait.** Do not preview the next step. Do not write "next we'll cover...". The user should not feel pulled forward — each step is complete in itself, and they advance when ready.

### 3. Respond to comprehension checks precisely

When the user answers:

- **Fully correct:** Confirm briefly ("Exactly right"), add at most one small nuance if it matters for later steps, then offer the next step. Don't pad with restatement.

- **Partially correct:** Affirm the correct part specifically. Then surgically correct what was wrong — just that part, not a re-teach of the whole step. Example: "Right on the trigger, but the bump isn't minor — `chore` maps to patch in this config, not minor. Look at commitTypes.json:16..."

- **Wrong:** Walk through the actual answer, referencing files. Offer a follow-up check only if the error suggests a deeper gap worth re-probing.

- **"I don't know":** This is a valid answer. Walk through the answer fully, then offer the next step. Don't make the user feel judged for not guessing.

### 4. Self-correct when you're wrong

If the user's answer or a later realization reveals your earlier explanation was wrong or incomplete, **say so explicitly** and correct it. Don't paper over it. Example:

> "Good catch — your answer exposed a corner I glossed over. Let me correct what I said about X..."

The user's trust in the teaching depends on you being willing to walk things back. Don't plow forward with a flawed foundation.

### 5. Adjust style when asked

If the user requests a change to the teaching style mid-session (pace, depth, format, reference style), adopt it immediately for the next step. Don't ask them to justify the request.

### 6. End with a full-system scenario

When you've covered the system end-to-end, present **one concrete scenario** that spans multiple steps and ask the user to narrate what happens. Don't grade each clause — the scenario is for self-assessment. Tell them: "no need to write the answer out, but if any part feels fuzzy, that's the spot to loop back on."

Then offer a numbered list of what you covered, so they can re-invoke on specific steps later.

## Things to avoid

- **Don't preview what's coming next.** Breaks the "one step at a time" contract.
- **Don't write full section hierarchies with H2/H3/H4.** Each step is prose with a bold header and inline code/file refs. Heavy Markdown structure makes steps feel like dumped documentation.
- **Don't use bullet lists for the explanation itself unless the content is genuinely enumerable.** Flowing prose teaches; bullets dump.
- **Don't skip file references because "it's obvious from context."** It isn't, and the references are load-bearing.
- **Don't use the Task/TaskCreate tools for this.** The steps emerge as you go — a task list imposes structure that defeats the point. The user drives the pace by answering checks.
- **Don't write more than one step per message**, even if the user seems to be going fast. The comprehension check has to land for each one.
- **Don't summarize the previous step at the start of the new one.** The user read it. Trust that.

## Example step shape

> **Step 4: How commit messages become a version bump**
>
> Open `configs/commitTypes.json`. It's 69 lines of pure data — rules mapping commit types to semver bumps. Each entry looks like:
>
> ```json
> { "type": "feat", "release": "minor", "section": "Features", "hidden": false }
> ```
>
> Only two fields matter for the bump: `type` (the prefix before the colon in a commit message) and `release` (what bump it triggers — `major`, `minor`, `patch`, or `false`).
>
> [... rest of the concept, with file refs at every claim ...]
>
> **Check your understanding:**
>
> Last tag is `render-v2.3.1`. An MR merges with these three commits:
>
> ```
> chore: bump dev deps
> docs: fix typo
> fix(react): handle null in MemoChildren
> ```
>
> What version does this produce?

Notice: bold header, concrete file ref in the first sentence, bounded to one concept, ends with a check the user can't answer by skimming.
