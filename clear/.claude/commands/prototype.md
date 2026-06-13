---
name: prototype
description: Build a fast, throwaway, playable prototype of a rough idea so the user can learn by using it right now. Use this skill whenever the user invokes "/prototype", or says "make a quick version of this," "let me play with this idea," "rough this out so I can try it," "build a throwaway X," or otherwise hands over a half-formed idea they want to feel rather than discuss. Route by what the idea is about: ideas about logic, state, rules, or behavior become a quick interactive terminal program the user runs immediately; ideas about how something looks or feels become a single-page clickable website with two or three RADICALLY different design variations switchable in-page. The prototype is disposable by design — optimize for speed and learning, not robustness, tests, or shippability. Do NOT over-engineer, do NOT build the production version, do NOT add features the user didn't ask about.
---

# /prototype

The user has a rough idea and wants to *play with it now*, not talk about it. Your job is to turn the idea into something they can poke at within one turn, then get out of the way. The prototype is scaffolding to think with — it gets thrown away. Internalize that, because it changes every decision: speed over polish, clarity over cleverness, one good-enough version over a robust one.

Three rules sit above everything:

1. **Disposable, not shippable.** No test suites, no error-handling for inputs that won't occur in play, no config files, no abstraction layers, no "this will scale." If you catch yourself building infrastructure, stop — that's the production version, and that's not this.
2. **Playable this turn.** The user should be able to run or click it the moment you finish. Minimize setup. Prefer zero dependencies; if you must add one, it's because the prototype is impossible without it.
3. **Don't out-scope the idea.** Build exactly the rough idea, at the fidelity needed to learn from it. Resist adding adjacent features, settings, or "while I'm here" extras. Surprises are bad here.

## Step 1 — Route the idea

Decide what the idea is fundamentally *about*. This determines what you build.

**Logic / state / behavior → terminal program.** If the idea is about how something *works* — rules, algorithms, state transitions, game mechanics, a workflow, a simulation, a decision process, "what happens when..." — the interesting part is dynamics, not pixels. Build a small interactive program the user runs in the terminal. (See "Terminal branch.")

**Look / feel / layout → single-page website.** If the idea is about how something *appears or feels* — a UI, a landing page, a layout, a vibe, a visual concept, "what if it looked like..." — the interesting part is the aesthetic, which you can't evaluate in the abstract. Build one self-contained HTML page with two or three radically different design takes the user can switch between live. (See "Look-and-feel branch.")

**If it's genuinely both or genuinely ambiguous**, ask one quick question — "Is the thing you want to feel out the *behavior* or the *look*?" — and route on the answer. Don't guess if it's a coin-flip; a wrong route wastes the whole prototype. But if there's a clear lean, just go with it and say which way you routed so the user can redirect.

## Terminal branch — interactive program

Build a single self-contained script (Python is the safe default — it's everywhere and needs no build step; use Node only if the idea is clearly JS-flavored). Save it to `/mnt/user-data/outputs/` with an obvious name like `prototype_<slug>.py`.

Make it genuinely interactive — a REPL-style loop, prompts, a tiny menu, or simulated turns — so the user *drives* it rather than reading a transcript. The point is to let them poke the logic from angles you didn't anticipate. Concretely:

- Print a one-line "here's what this is and how to drive it" banner on start.
- Loop on input. Handle the obvious commands; for anything unexpected, just say "didn't get that, try X" and keep going — don't crash, but don't build elaborate validation either.
- Make the state *visible*. After each action, show what changed. The user is here to watch the behavior, so surface it.
- Keep it to one file, standard library only if at all possible.

Then tell the user exactly how to run it (`python prototype_<slug>.py`) in one line, and name the two or three things you'd pay attention to while playing — the questions the prototype was built to answer.

## Look-and-feel branch — clickable site with variations

Build **one** self-contained `.html` file (inline CSS and JS, no build step, no external assets beyond fonts/CDN if needed) saved to `/mnt/user-data/outputs/prototype_<slug>.html`. It must contain **two or three radically different design variations** the user can switch between in-page — a visible toggle (buttons/tabs fixed in a corner) that swaps the active variation instantly.

"Radically different" is the whole point — these are not three shades of the same idea. Each variation commits to a genuinely distinct aesthetic direction (e.g. brutally minimal vs. maximalist-editorial vs. retro-terminal), distinct typography, distinct color, distinct layout logic. The user learns by feeling the *contrast*. Three timid variations teach nothing; two bold opposites teach a lot.

For the design quality of each variation, read and apply `/mnt/skills/public/frontend-design/SKILL.md` — it covers committing to a bold aesthetic direction and avoiding generic "AI slop" looks. Each variation should follow that guidance independently, so they don't converge.

Keep the *content* identical across variations (same text, same buttons, same sections) so the user is comparing the look, not the substance. Make the clickable elements actually respond — hover states, a working toggle, navigable sections — enough to *feel* it, not enough to function as a real site. No backend, no real data, no forms that submit anywhere.

Then present the file and, in one or two lines, describe the variations by their aesthetic so the user knows what they're switching between, and name what you'd watch for while clicking around.

## After building — keep it cheap to discard

Close by reminding the user, briefly, that this is a throwaway meant for learning, and offer the natural next move: iterate on a variation, route the *other* way (e.g. "now that the behavior feels right, want to see how it could look?"), or hand the learnings to a real planning/build process. Don't polish the prototype further unless they ask — refinement is a signal it's becoming precious, which defeats the purpose.

## What good looks like

**Bad (built the production version):** User: /prototype a habit tracker where streaks decay if you skip. → You scaffold a React app with a database schema, auth, and a test suite.

**Good:** User: /prototype a habit tracker where streaks decay if you skip. → This is about *behavior* (the decay rule), so a terminal program: a script where you add habits, "check in" on simulated days, skip days, and watch streaks decay by your rule — so the user can feel whether the decay curve is satisfying or punishing before anyone designs a screen.

**Good:** User: /prototype a landing page for a meditation app, calm but not boring. → This is about *feel*, so one HTML file with three switchable takes — say, a near-empty single-breath minimalism, a warm organic gradient-and-serif take, and a stark high-contrast editorial take — same copy throughout, toggle in the corner, so the user can feel which "calm" is the right calm.
