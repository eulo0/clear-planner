---
name: competitive-intelligence
description: Research a competitor or market category and produce an interactive HTML sales battlecard. Use this skill whenever the user invokes "/competitive-intelligence", or asks to "research competitor X," "build a battlecard," "how do we compare to X," "what do I say when a prospect mentions X," "size up this market category," or otherwise wants competitor intel packaged for live sales use. Research the target across their website, marketing/positioning copy, pricing pages, public reviews (G2, Capterra, Reddit, App Store / Play Store, Trustpilot), and recent news, using web search and fetch. Output is a single self-contained interactive HTML battlecard a salesperson can pull up mid-conversation: strengths, weaknesses, head-to-head comparison on the dimensions prospects actually weigh, what to say when a prospect raises them, and traps to avoid. Ground every claim in a real source and never fabricate competitor facts, pricing, or quotes — flag what's unverified.
---

# /competitive-intelligence

Turn scattered public signal about a competitor (or a whole category) into a battlecard a salesperson can actually use while a prospect is on the line. Two things make this useful: the research has to be **real and current** (not memory — companies change pricing and positioning constantly), and the output has to be **fast to scan under pressure** (a battlecard read mid-call, not a report read at a desk).

## Step 0 — Get oriented (briefly)

You need to know who "we" are to build the comparison side. Check what you already know: there may be a `consult` skill or prior context describing the user's own product. If you can infer "us" from available context, use it and state your assumption. If you genuinely can't, ask one tight question — "Who are we positioning *against* them? One line on our product and who we sell to" — then proceed. Don't interrogate; one question max.

Also clarify the target if ambiguous: a single named competitor → research that company. A market category → identify the 3–5 most relevant players and either build one card for the category leader or offer a card per competitor.

## Step 1 — Research across all the surfaces

Use `web_search` and `web_fetch`. Cover each surface deliberately — they reveal different things, and skipping one leaves a blind spot:

- **Their website + marketing copy** — how they position themselves, who they claim to serve, their stated value prop and language. Fetch the homepage and key product pages. This is what they *want* prospects to believe.
- **Pricing page** — tiers, what's gated, what's expensive, what's hidden, contract/seat structure. Fetch it directly; pricing is the most decision-relevant and most often misremembered fact. If pricing isn't public ("contact sales"), say so — that itself is intel.
- **Public reviews** — G2, Capterra, Reddit, App/Play Store, Trustpilot. Search each by name (e.g. "[competitor] site:reddit.com", "[competitor] G2 reviews"). Reviews are where the *weaknesses* live — the gap between marketing and reality. Note each surface's bias (G2 skews positive/incentivized, Reddit candid, app stores extreme).
- **Recent news** — funding, launches, leadership changes, outages, pivots, layoffs. Search with the current year. Recency matters: a battlecard citing last year's positioning is a liability on a call.

Run several searches per surface. Pull real specifics — features, numbers, exact pricing, short verbatim phrases from reviews — with their source.

## Step 2 — Evidence discipline

A salesperson who repeats a "fact" that turns out wrong loses the deal and their credibility. So:

- **Ground every claim in a real source.** No invented features, pricing, stats, or quotes.
- **Honor copyright** when quoting reviews or copy: brief quotes only (well under 15 words), one per source, paraphrase the rest. Never reproduce whole reviews or marketing pages.
- **Mark confidence.** Distinguish what's verified (seen on their site/pricing page/multiple reviews) from what's inferred or single-sourced. In the battlecard, visually flag anything unverified so the rep knows not to assert it as fact — an "⚠ unverified" marker or similar.
- **Separate their claims from reality.** "They market themselves as X" is different from "users report Y." Keep both, labeled.
- **Date the intel.** Stamp the card with the research date and note anything likely to go stale (pricing, promotions, recent-news items).

## Step 3 — Build the interactive HTML battlecard

Produce **one self-contained `.html` file** (inline CSS + JS, no build step, works offline once loaded) saved to `/mnt/user-data/outputs/battlecard_<competitor-slug>.html`. Read `/mnt/skills/public/frontend-design/SKILL.md` first and apply it — but bias toward **clarity and scan-speed over decoration**; this is a working tool used under time pressure, so legibility, clear hierarchy, and fast navigation beat visual flourish.

Design for live use: collapsible/tabbed sections so the rep jumps straight to what they need, a sticky nav or section switcher, large readable type, and color-coded cues (e.g. green = our strength, red = their strength / trap). It should be usable on a second monitor or phone during a call. No backend, no external data calls at runtime.

**Required sections** (use this structure):

1. **Snapshot** — who they are, who they target, positioning in one line, pricing summary, research date. The 10-second orientation.
2. **Where they're strong** — their genuine strengths (don't pretend they have none; a card that says the competitor is all bad is one the rep stops trusting). Each grounded in a source.
3. **Where they're weak** — recurring complaints from reviews, gaps in coverage, things their pricing/positioning reveals. This is the rep's ammunition; tie each to evidence.
4. **Head-to-head comparison** — a table comparing us vs. them on the **dimensions prospects actually care about** (not a feature dump — the 5–8 axes that decide deals: price, ease of use, specific capabilities, support, integrations, fit for the buyer's use case). Mark each row as our advantage, their advantage, or even. Be honest where they win — reps need to know where *not* to fight.
5. **What to say when a prospect mentions them** — concrete talk tracks. For their main strengths, how to acknowledge-and-redirect. For their weaknesses, how to raise them without sounding desperate. Short, sayable lines, not paragraphs.
6. **Traps to avoid** — where the rep is likely to lose ground: claims not to make (that the competitor can easily rebut), their strongest counter-arguments, situations where they're genuinely the better fit (and the honest move is to disqualify rather than oversell). The unverified items live here too, flagged.

Keep talk tracks honest — overclaiming is itself a trap, because a prospect who's used the competitor will catch an exaggeration and discount everything else the rep says.

## Step 4 — Present and caveat

Present the file with `present_files`. In a line or two, summarize the sharpest finding (the competitor's biggest exploitable weakness or the dimension where we clearly win), and remind the user the intel is dated — pricing and positioning drift, so re-run before a big cycle. Offer to build cards for other players if this was a category request.

## What good looks like

A rep pulls up the card the moment a prospect says "we're also looking at [competitor]," lands on the snapshot, taps to "what to say," and has a grounded, honest line within seconds — including the awareness that on one axis the competitor genuinely wins, so they steer the conversation to where we don't. Bad is a beautiful static report full of confident claims the rep can't verify and a feature table no one can parse mid-call.
