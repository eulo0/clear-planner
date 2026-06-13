# Clear Planner — Agent Orientation

## What this is
A personal calendar and planner app. Users create events, courses, and work shifts, manage group projects, and use a draft mode to preview calendar changes before committing them.

## Stack
- **Rails 8.1.1** + PostgreSQL
- **Hotwire**: Turbo Frames, Turbo Streams, Stimulus controllers
- **Tailwind CSS** via `tailwindcss-rails`
- **Devise** for authentication
- **Propshaft** asset pipeline

## Universal guardrails — apply to every agent, every task, no exceptions
- **Never commit.** Stage work if asked, but do not run `git commit` without explicit human instruction.
- **Never push.** Do not run `git push` under any circumstances.
- **Never read `.env`.** Secrets live there. Do not open, cat, or pass its contents anywhere.
- **Never run destructive migrations unattended.** Adding columns is fine. Dropping tables, removing columns, or changing column types requires human sign-off first.
- **Never install gems or npm packages without asking.** Confirm with the user before modifying `Gemfile` or `package.json`.

## Key project decisions agents must know

**Draft system (Calendar Draft)**
- Draft mode shows NEW/EDITED/REMOVED pill overlays on calendar index pages before the user commits changes.
- Group events (`project_id` present) are **excluded from draft mode** entirely. Scope all draft queries to `project_id: nil`.
- The `calendar_occurrences_for_range` query already does this — mirror that filter in any draft preview logic.
- Full details: `GLOBAL_DRAFT_VISIBILITY.md`

**Display / layout**
- The user's primary machine renders at ~1367 effective CSS px (Retina Mac). "Looks fine" means at 1367px, not 1920px.
- When doing layout work: simulate at 1367px viewport. Use `getBoundingClientRect` / `getComputedStyle` to measure — don't eyeball.
- Widening a centered container past ~1287px will clip the landing-page header. Use full-width + fixed padding instead.

**Hotwire conventions**
- Prefer Turbo Streams for partial page updates over full redirects.
- Stimulus controllers live in `app/javascript/controllers/`. Follow existing naming conventions.
- Do not reach for JavaScript where a Turbo Frame or Stream will do.

## Role-specific context
If you are running as a specialized agent, check `.claude/agents/` for a file matching your role (e.g. `feature.md`, `review.md`, `monitoring.md`, `strategy.md`). These are created as each agent type is first deployed — the directory may be empty or not yet exist.

## Active skills
These skills are available and should be triggered for relevant tasks:
- `safe-codebase-changes` — use for any code edit; enforces safety guardrails
- `run-clear` — use to launch the app and verify visual changes
- `global-draft-visibility` — context for the draft overlay system
- `adversarial-collaborator` — use when evaluating plans or proposals
