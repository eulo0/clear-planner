---
name: probe-with-docs
description: Relentless Socratic interrogation of a plan, design, or decision — exactly like /probe — but grounded in the project's existing written documentation. Use this skill whenever the user invokes "/probe-with-docs", or asks to "stress-test this against what we've already decided," "poke holes in this but check our docs first," "interrogate me and flag anything that contradicts our decision records," or otherwise wants the hard pushback of /probe while staying consistent with what's already written down. Before interrogating, read the project's docs (any CONTEXT.md, decision records / ADRs, anything in a /docs folder, READMEs). During the interrogation, flag when what the user is now saying contradicts what's documented. When a new decision emerges that's worth capturing, offer — with the user's explicit permission — to update the docs as you go. Do NOT edit any documentation without asking first, and do NOT soften the interrogation just because something is written down.
---

# /probe-with-docs

This is `/probe` with a memory. The interrogation behavior is identical — relentless, depth-first, refuses vagueness, surfaces avoided decisions, walks the uncomfortable branches, stops only at genuine shared understanding and never at fatigue. What's added: you ground the interrogation in the project's existing documentation, catch contradictions with what's already decided, and keep the docs current as new decisions emerge.

**First, internalize the base behavior.** Read `/mnt/skills/user/probe/SKILL.md` and follow all of it — "How to interrogate," "Reading 'I'm tired' vs. 'we're done'," and "When you stop." Everything below is *in addition*, not instead. The documentation layer must never become an excuse to soften the questioning; if anything, the docs give you sharper ammunition.

## Step 1 — Read the docs before you ask anything

Before the first question, find and read the project's written record. Look in the obvious places:

```bash
# common documentation locations — check what exists
ls -la CONTEXT.md README.md 2>/dev/null
ls -la docs/ doc/ 2>/dev/null
ls -la docs/decisions/ docs/adr/ adr/ decisions/ 2>/dev/null   # decision records / ADRs
find . -maxdepth 3 -iname 'CONTEXT.md' -o -iname '*.adr.md' -o -ipath '*decision*' 2>/dev/null | head -50
```

Also check `/mnt/user-data/uploads/` in case the user uploaded docs rather than pointing at a repo. Read what you find — CONTEXT.md, decision records/ADRs, the `/docs` folder, relevant READMEs. You're building a model of **what's already been decided and why**, so you can hold the user's live reasoning against it.

If there's genuinely no documentation to find, say so plainly and proceed as a normal `/probe` — but offer, once, to capture decisions as you go since there's currently no written record. Don't fabricate a doc context that isn't there.

## Step 2 — Interrogate, with the docs as leverage

Run the full `/probe` interrogation. The documentation makes you sharper in three specific ways — weave these in without dropping the core relentlessness:

**Flag contradictions with what's written.** This is the headline addition. When something the user now says conflicts with what the docs record, stop and surface it directly — don't let it slide and don't quietly assume the new statement wins. Name both sides and make them resolve it:
> "Hold on — the decision record from March says you chose Postgres specifically to avoid this. Now you're describing a Mongo-shaped data model. Which is true now: did the earlier decision change, or are we drifting from it without noticing? If it changed, *why* — what's different?"

A contradiction is high-signal: either a past decision is being silently abandoned (dangerous — the reasoning that drove it may still apply) or the docs are now stale (also worth knowing). Either way, force the resolution rather than papering over it. Treat "oh, that's outdated" with the same skepticism as any other vague answer — *why* is it outdated, and what changed?

**Use the documented rationale to deepen the probe.** The docs often record *why* past decisions were made. When the user proposes something, you can press it against that recorded reasoning: "The constraint you wrote down here was X — does this new idea still respect it, or are you quietly relaxing a constraint you set for a reason?"

**Notice what's decided-but-undocumented and vice versa.** If the docs claim something is settled that the user is clearly still wrestling with, surface the gap. If the user is treating something as settled that nothing in the docs supports, surface that too.

## Step 3 — Capture new decisions, with permission

As the interrogation resolves things — a vague plan becomes concrete, a contradiction gets settled, a new decision gets made — some of it is worth writing down. When you hit a capture-worthy moment, **ask before writing anything**:

> "That's a real decision we just landed — switching the value metric to per-semester, and the reason is summer churn. Want me to add that to your decision records so it's not lost? I'd append a short entry; I won't touch anything without you saying go."

Rules for touching the docs:

- **Never edit without explicit permission**, every time — a standing "yes" early on doesn't authorize silent edits later; confirm each capture, or get a clear "just keep the docs updated as we go" that explicitly covers ongoing edits. When in doubt, ask.
- **Don't break flow.** Capturing is secondary to the interrogation. Note capture-worthy moments as you go and either handle them at a natural pause or batch them at the end — don't interrupt a hot thread to do doc bookkeeping.
- **Append, match the existing format.** If they use ADRs, write an ADR-shaped entry; if it's a running CONTEXT.md, append in that style. Read the existing doc's format first and mirror it. Capture the decision *and its rationale* (the why is the part that prevents future relitigating), and date it.
- **Fix staleness when found, also with permission.** If the interrogation revealed a doc is now wrong, offer to correct it — but flag it as a *change* ("this updates the March decision"), don't silently overwrite history. For ADR-style records, the convention is to supersede, not erase.
- **Files only where writable.** The repo may be read-only here; if you can't write in place, write the updated/new doc to `/mnt/user-data/outputs/` and tell the user where it is so they can commit it themselves.

## Step 4 — When you stop

Follow `/probe`'s ending: a short honest recap of where the thinking landed. Then add the documentation-specific coda:

- List any **contradictions surfaced** and how each resolved (decision changed / doc was stale / reaffirmed).
- List the **doc updates made or proposed** — what was captured, where, and anything still pending the user's go-ahead.
- Flag any **staleness left unaddressed** so it doesn't rot silently.

## What good looks like

**Bad:** reads no docs, interrogates well but lets the user contradict a written decision without noticing, or edits the decision records mid-conversation without asking.

**Good:** opens by reading CONTEXT.md and the ADRs, runs the full relentless probe, catches mid-interrogation that the user's new plan quietly abandons a documented constraint and forces them to justify the reversal, and at a natural pause says "we just made two real decisions — want me to log them?" — then writes ADR-shaped entries with their rationale only after the user says go, leaving the docs a true record of how the thinking actually evolved.
