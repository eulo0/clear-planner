---
name: to-issues
description: Break a plan, spec, or PRD into small, independent, shippable tasks ready to hand to a teammate or another agent. Use this skill whenever the user invokes "/to-issues", or asks to "break this into tasks/tickets/issues," "turn this PRD into work items," "split this up for the team," "make a backlog from this," or otherwise wants a body of work decomposed into handoff-ready units. Each task is a thin VERTICAL slice — independently completable and shippable on its own, not a horizontal layer blocked on every other task. Give each a clear title, a concrete definition of done, and only the dependencies that genuinely exist. Do NOT invent scope beyond the source material, do NOT create tasks that can't ship alone, and do NOT manufacture false dependencies that serialize work that could run in parallel.
---

# /to-issues

Decompose a plan, spec, or PRD into tasks someone can pick up and finish without needing the author over their shoulder. The work has to be handoff-ready — to a teammate or to another AI agent — which means each task carries its own context, has an unambiguous done-condition, and doesn't secretly depend on six other tasks. The defining discipline is **thin vertical slices**: each task delivers a complete, shippable sliver of value end-to-end, rather than a horizontal layer (all the database, then all the API, then all the UI) that's worthless until every layer lands.

## Step 1 — Absorb the source and find the slices

Read the plan/spec/PRD (in context, or from `/mnt/user-data/uploads/` — read it). Understand what's being built and, crucially, what *units of value* it breaks into. The decomposition move is to slice by **outcome**, not by **layer**:

- **Vertical (do this):** "User can sign up with email" — touches whatever data, logic, and UI that one capability needs, and ships as a working thing on its own.
- **Horizontal (avoid this):** "Build the database schema," "build all the API endpoints," "build the UI" — none ships independently; each is dead weight until the others exist, and they serialize the whole project.

Find the smallest slices that still deliver something real. A good slice is completable in a focused sitting and demoable when done. If a slice is too big to hold in one head, split it into thinner vertical slices — not into horizontal layers.

## Step 2 — Respect the scope, find the real dependencies

- **Don't invent scope.** Only create tasks the source material actually calls for. If the PRD left something as an open question, that's not a task — note it as a blocker or surface it, don't fabricate a requirement. (If the source has explicit open questions, list them separately as "needs resolution before X can start.")
- **Only real dependencies.** A dependency exists when task B genuinely cannot start or finish until task A is done — shared foundational code, an API another task consumes, an auth gate everything sits behind. Do not manufacture dependencies out of habit or tidiness; false dependencies serialize work that could run in parallel and are the most common way decomposition quietly kills velocity. When in doubt, assume independence and say what would make them dependent.
- Aim to **maximize the number of tasks that can start immediately and in parallel.** That's the whole point of independent slices.

If a true sequence is unavoidable (e.g. a foundational slice everything builds on), keep it minimal — one thin enabling task others depend on, not a long horizontal runway.

## Step 3 — Write each task as a handoff-ready issue

For each task, write:

```markdown
### [Clear, action-oriented title]
**What:** One or two sentences — the outcome this task delivers, in plain terms. Enough context that someone who didn't read the full PRD can pick it up.
**Done when:** Concrete, checkable definition of done — the conditions that must be true for this to be shippable. Behavioral/observable where possible ("a user can X and sees Y"), not vague ("implement X").
**Dependencies:** Only real ones, named by task title — or "None — can start immediately." 
**Notes:** (optional) Relevant decisions/rationale from the source, edge cases, or non-obvious context the assignee needs.
```

Standards that make a task genuinely handoff-ready:

- **Title is specific and outcome-shaped** — "Add email signup flow," not "Auth" or "Backend work."
- **Done condition is testable** — the assignee and a reviewer can both agree, unambiguously, whether it's met. This is what lets the task ship without the author adjudicating.
- **Self-contained context** — fold in the bit of reasoning from the source that the assignee needs, so they aren't blocked asking "why?" or "did we decide X?". Don't make them read the whole PRD to start one task.
- **Right-sized** — small enough to finish in a focused block, large enough to be a meaningful, shippable unit. If you can't write a clean done-condition, the task is probably too big or too vague — split or sharpen it.

## Step 4 — Order and deliver

Present the tasks grouped to make the work plan obvious:

1. **Start now (parallel):** tasks with no dependencies — ideally most of them.
2. **Unblocked once [X] ships:** tasks gated on a real dependency, with the gate named.

Add a one-line note on any genuine open questions from the source that block specific tasks, so nothing starts on an unresolved decision.

Default output is a markdown file in `/mnt/user-data/outputs/` (e.g. `issues_<slug>.md`) so the user can paste tasks straight into their tracker, then present it. Keep titles and done-conditions in a form that copies cleanly into GitHub/Jira/Linear. If the set is small (a handful of tasks), an inline list is fine — match the artifact to the size of the work.

## What good looks like

**Bad:** four tasks — "Database," "Backend," "Frontend," "Testing" — each depending on the previous, none shippable alone, the whole thing a waterfall in disguise; titles too generic to assign; done-conditions like "implement the backend."

**Good:** a dozen vertical slices — "User can create an account," "User can reset password," "Admin can deactivate a user" — most marked "start immediately," each with a testable done-condition a teammate or agent could verify, only the one or two genuine foundational dependencies called out, and the open questions from the PRD flagged as blockers rather than silently turned into tasks.
