---
name: to-prd
description: Turn the current conversation into a product requirements document (PRD) that someone who wasn't present can pick up cold and fully understand. Use this skill whenever the user invokes "/to-prd", or asks to "turn this into a PRD," "write this up as a product requirements doc," "document what we decided," "make a spec from this conversation," or otherwise wants the discussion so far crystallized into a shareable product document. Synthesize everything discussed — the what, the why, who it's for, what success looks like, what's intentionally out of scope, and open questions — capturing not just the decisions but the reasoning behind them. Write for a cold reader who has zero context from the conversation. Do NOT invent requirements that weren't discussed; mark genuine gaps as open questions rather than filling them with plausible guesses.
---

# /to-prd

Convert the conversation so far into a product requirements document that stands on its own. The single hardest requirement, and the one that makes this useful: **it must work for someone who wasn't in the room.** Everything obvious-in-context to the participants is invisible to a cold reader — the shorthand, the "obviously we'd do X," the decision made three messages ago and never restated. Your job is to surface all of it.

## Step 1 — Mine the whole conversation

Read back over everything discussed, not just the last few messages. Pull out:

- **What was decided** — the actual choices, even ones made casually in passing.
- **Why** — the reasoning, tradeoffs, and rejected alternatives behind each decision. This is the most valuable and most easily lost content; a decision without its rationale invites the reader to relitigate it.
- **What's assumed** — context the participants shared implicitly (who the user is, what the product is, constraints taken for granted). A cold reader has none of it; make it explicit.
- **What's unresolved** — questions raised but not answered, things deferred, "we'll figure that out later" items.

If this conversation drew on other skills (research, pricing, competitive analysis, prototyping, probing), fold those findings in — they're part of the reasoning the PRD should capture.

## Step 2 — Find the gaps, don't fill them

A PRD written from a conversation will have holes, because conversations don't cover everything. The discipline here mirrors honest research: **distinguish what was actually discussed from what wasn't.**

- Include what was genuinely decided or discussed.
- For things that clearly need an answer but never got one, list them as **open questions** — do not invent a plausible-sounding requirement to paper over the gap. A fabricated requirement is worse than a flagged hole, because the reader can't tell it wasn't really decided.
- Where you make a connective inference to keep the document coherent, keep it minimal and signal it ("implied, not explicitly confirmed") so it isn't mistaken for a settled decision.

## Step 3 — Write the PRD for a cold reader

Use this structure. Adapt section depth to what the conversation actually supports — don't pad a thin section to look complete, and don't force content that isn't there.

```markdown
# [Product / Feature Name] — PRD

## Overview
One paragraph a cold reader can absorb in 20 seconds: what this is, who it's for, and why it matters. Assume zero prior context.

## Problem & Why Now
The problem being solved and who has it. Why it's worth solving, and why now. Ground in whatever evidence the conversation produced.

## Target User
Who this is for — the specific segment, not "everyone." Their relevant context, needs, and the situation they're in when they'd use this.

## Goals & Success Metrics
What we're trying to achieve, and how we'd know we succeeded — measurable where the conversation gave us something measurable. If success was discussed only vaguely, say so rather than inventing metrics.

## What We're Building
The actual product/feature requirements and scope. The decisions made, described concretely enough to act on.

## Key Decisions & Rationale
The important choices AND why we made them — including notable alternatives considered and rejected. This is what lets a cold reader understand the decisions instead of relitigating them.

## Out of Scope
What we explicitly decided NOT to do, and why. This section is as important as the in-scope one — it prevents scope creep and answers the reader's "why didn't they just...?" before they ask.

## Open Questions
What's genuinely unresolved, each phrased as a concrete question, ideally with what's needed to answer it and who might own it. Honest emptiness here is rare; don't fake completeness.

## Context & Assumptions
The implicit context a participant had but a cold reader doesn't — what the product is, prior decisions this builds on, constraints taken as given.
```

Writing standards for the cold reader:
- **Define the shorthand.** Any term, product name, or reference that was clear in conversation but opaque cold gets a brief definition the first time it appears.
- **State decisions as decisions**, with their reasoning attached — not as open musings, unless they genuinely are open (in which case they belong in Open Questions).
- **Prose over fragments** for anything load-bearing; a cold reader can't reconstruct meaning from a cryptic bullet. Lists are fine for genuinely list-like content.
- **No invented specificity** — no metrics, dates, or requirements that weren't discussed. Precision you didn't earn from the conversation is a liability.

## Step 4 — Deliver

Default to a markdown file in `/mnt/user-data/outputs/` (read the `md` conventions if unsure) so it's easy to read and share, then present it. If the user signals they want a formal/polished document to circulate (e.g. "something I can send to leadership"), produce a `docx` instead — read the `docx` skill first. Match the format to how they'll use it.

After presenting, give a one-line pointer to the **Open Questions** section — those are the things the document couldn't resolve and the most likely reason someone reading it cold would come back with questions, so the user should see them before circulating.

## What good looks like

**Bad:** a tidy-looking PRD that reads well to the participants but assumes the reader knows what the product is, states decisions without why, invents three success metrics that were never discussed, and has an empty Open Questions section despite the conversation clearly leaving things unresolved.

**Good:** a cold reader finishes it understanding what's being built, for whom, why, what success looks like, what was deliberately excluded and why, and exactly what's still undecided — and can tell, throughout, the difference between what the team actually decided and what's still an open question.
