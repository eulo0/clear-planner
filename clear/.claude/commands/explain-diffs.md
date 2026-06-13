---
name: explain-diffs
description: Walk the user through the diff of every file that was changed, so they understand what happened and why. Use this whenever the user wants a code review or explanation of recent edits — phrases like "explain the diff", "what did you change", "walk me through the changes", "explain what you just did", "review these edits", or when the user seems unsure about changes that were just made. Also use proactively after a substantial multi-file edit when the user would benefit from understanding it before moving on. Trigger even when the user doesn't say the word "diff".
---

# Explain Diffs

The goal is to turn a pile of code changes into something the user actually understands: what changed, why it changed, and what they should keep an eye on. A raw diff doesn't do that on its own — it shows the *what* but not the *why*, and it buries the important changes among the trivial ones. This skill fixes that.

## Step 1: Get the actual diff

Don't explain from memory — read the real changes from git so nothing is missed or misremembered.

Pick the scope that matches what the user is asking about:

- **Uncommitted work (the default).** Most of the time the user means "the edits you just made this session" and those aren't committed yet. Use this to capture both staged and unstaged changes:
  ```bash
  git diff HEAD
  ```
  If the edits were never staged and `git diff HEAD` looks incomplete, also check `git diff` (unstaged) and `git diff --staged` (staged) and combine.

- **A specific commit**, when the user references one or says "the last commit":
  ```bash
  git show <commit>        # or: git show HEAD
  ```

- **A range / the whole session**, when work spans several commits:
  ```bash
  git diff <base>...HEAD
  ```

Also run `git status` first to see new (untracked) files — these won't show in `git diff` until added. Read untracked files directly so you can explain them too.

If the project isn't a git repo, fall back to explaining the set of files you edited this session, reading each from disk.

## Step 2: Walk through it, file by file

Order files by importance — the changes that affect behavior come first, boilerplate and formatting last. For each file:

1. **Header line**: the file path and whether it was *created*, *modified*, or *deleted*.
2. **The relevant hunks**: show just the changed lines plus a little surrounding context — not the whole file. The user wants to see the change, not re-read everything.
3. **What and why, in plain language**: a few sentences. What did this change do, and why was it needed? Tie it back to the goal the user originally asked for. This is the part that makes the diff make sense.
4. **Flags**: call out anything worth attention — behavior changes, new dependencies, migrations, assumptions you made, or a spot where you chose one approach over another and a different choice was reasonable. This is the highest-value part; don't skip it.

## Keep it useful, not exhausting

- **Group the mechanical stuff.** Pure renames, import reordering, and formatting don't each need a paragraph — bundle them: "Reformatting and import sorting across these 4 files, no behavior change."
- **Lead with risk.** If something could break or made a non-obvious tradeoff, surface it early rather than burying it under routine changes.
- **Be concise.** A few sentences per meaningful change. The point is comprehension, not volume.
- **Don't edit while explaining.** This is a review pass. If you notice a bug, mention it in the flags and ask whether they want it fixed — but don't silently change code mid-explanation, since that defeats the purpose of the review.

## Example of a single file entry

**`src/auth/session.ts`** — modified

```diff
-  const token = jwt.sign(payload, SECRET);
+  const token = jwt.sign(payload, SECRET, { expiresIn: "1h" });
```

Added a 1-hour expiry to session tokens. Previously tokens never expired, which is what you flagged as the security issue. **Heads up:** any client holding an old token will now be logged out after an hour, so you may want a refresh-token flow if you don't already have one.
