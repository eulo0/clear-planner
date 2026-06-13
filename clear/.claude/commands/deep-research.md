---
name: deep-research
description: Run rigorous, multi-angle web research on a question and produce a synthesized, fully cited report with every claim adversarially fact-checked before inclusion. Use this skill whenever the user invokes "/deep-research", or asks to "research X thoroughly," "do a deep dive on X," "find everything about X," "write me a researched report on X," or otherwise wants depth and verification rather than a quick answer. Cover the question from many distinct angles via many searches, fetch and read the actual sources (not just snippets), then verify each claim adversarially — actively trying to disprove it — before it goes in. Cite every source. If the question is underspecified in a way that would change the research (e.g. "what car should I buy" with no budget or use case), ask two or three clarifying questions BEFORE starting. Never include an unverified claim as fact; flag what couldn't be confirmed.
---

# /deep-research

Produce research the user can rely on for a real decision. The two things that separate this from a quick search are **breadth** (attack the question from many angles, not one) and **verification** (every claim is challenged before it earns a place in the report). Depth without verification is just a longer way to be confidently wrong.

## Step 0 — Scope check before any searching

If the question is underspecified in a way that materially changes what you'd research, ask **two or three** clarifying questions and wait — don't burn searches on the wrong interpretation. The test is whether the answer would differ: "what car should I buy" genuinely needs budget, use case, and new/used before it's researchable; "what causes coral bleaching" is already answerable and needs no preamble.

When you do ask, ask the few highest-leverage questions (budget, use case, constraints, what decision this feeds) using the quick-select tool if it fits, then proceed on the answers. Ask once — don't drip-feed clarifications. If the question is already well-scoped, skip this entirely and start.

## Step 1 — Decompose into angles, then search broadly

Before searching, break the question into its distinct sub-questions and angles — the facets a thorough analyst would insist on covering. For a product decision that might be: the options, the evaluation criteria, expert reviews, real owner/user experiences, known problems, cost of ownership, and the contrarian case. For a factual/analytical question: the main thesis, the mechanisms, the counter-evidence, the expert consensus, and the dissent.

Then search **many times, one angle per search**. A single broad query returns shallow results for everything; a separate query per angle goes deep on each. Scale to the question — a substantive research request typically warrants 8–20 searches across angles, sometimes more. Reformulate when a query misses rather than repeating it. Deliberately search for the *counter*-view, not only confirmation — "X criticism," "X problems," "X doesn't work" — so you're not just building a one-sided case.

> Environment note: in this interface searches run one at a time, not truly in parallel — so issue them in quick succession across your angles rather than expecting simultaneous execution. The goal (broad multi-angle coverage) is the same; the mechanism is sequential.

## Step 2 — Fetch and actually read the sources

Search snippets are too thin to build a report on and often misleading out of context. For any source that matters to a claim, `web_fetch` the full page and read it. Favor primary and high-quality sources — original research, official data, the company's own pages, reputable outlets — over aggregators and SEO content. Note each source's date (recency matters for anything that changes) and its potential bias.

## Step 3 — Adversarial fact-check, claim by claim

This is the core of the skill. Before any claim goes in the report, challenge it as if your job were to *disprove* it — the mindset of a skeptical reviewer, not the author who wants it to be true.

> Environment note: this interface has no separate sub-agents, so the adversarial pass is one you run yourself as a distinct, deliberate step — switching into a disconfirming stance — rather than a separate agent. Do it explicitly and rigorously; don't let the author's optimism leak into the check.

For each material claim, run this gauntlet:

- **Source quality** — is it from a credible primary source, or an aggregator parroting something? Trace it to origin where possible.
- **Corroboration** — is it confirmed by at least one *independent* source? A claim repeated across sites that all cite the same origin is single-sourced, not corroborated. If it matters and you can't corroborate it, search again specifically to confirm or refute.
- **Disconfirmation** — actively look for evidence *against* the claim. Run a search aimed at refuting it. If credible contradicting evidence exists, the claim is contested — report it as contested, don't pick the side you like.
- **Recency** — is it current, or superseded? Stale facts (prices, rankings, "the latest," who-holds-what) are a common failure.
- **Precision** — does the claim overstate what the source actually supports? Tighten it to exactly what the evidence shows.

Classify the outcome: **verified** (credible, corroborated, uncontested → include with citation), **contested** (credible evidence on both sides → include explicitly as contested, both sides cited), or **unverified** (couldn't confirm → either exclude, or include only if clearly flagged as unconfirmed). Never silently promote an unverified claim to a stated fact.

## Step 4 — Synthesize the report with citations on everything

Write a synthesized report — *synthesized*, meaning organized around the answer and the insights, not a list of "source 1 said... source 2 said..." Lead with the direct answer to the question, then the supporting analysis, then the nuances and contested points, then what remains uncertain.

- **Cite every claim** to its source. Every factual statement traces to where it came from; a reader should be able to check any line.
- **Respect copyright**: paraphrase in your own words; quote only rarely, briefly (well under 15 words), once per source at most. Never reproduce source paragraphs or mirror their structure.
- **Surface the contested and the unknown** — a report that admits "the evidence on X is mixed" and "no reliable data on Y" is more trustworthy than one with false uniformity. Include a short "what we couldn't confirm" note where relevant.
- **Don't bury the answer.** The user asked a question; answer it plainly up front, then support it.

For a substantial report, save it as a file in `/mnt/user-data/outputs/` (markdown by default; `docx` if the user wants a formal document — read the `docx` skill first) and present it. For a lighter question, a well-cited conversational synthesis is fine — match the artifact to the weight of the request. Keep the citations in whatever form you deliver.

## What good looks like

**Bad:** ten searches, snippets only, every claim from the first source that said it, a report that reads as a confident summary of one narrative with no sense of what's disputed or dated.

**Good:** the question broken into angles, many targeted searches including deliberate searches for the counter-case, full sources read, each claim run through corroboration and a disconfirming search before inclusion, contested points flagged as contested, a clear answer up front, every line cited, and an honest note on what couldn't be confirmed.
