---
name: customer-research
description: Conduct, analyze, or synthesize customer research grounded in real evidence. Use this skill whenever the user invokes "/customer-research", or asks to summarize customer-interview transcripts, mine online reviews and community discussions (Reddit, G2, Capterra, App Store / Play Store, Trustpilot, niche forums) for recurring complaints and praise, build evidence-based personas, map jobs-to-be-done (JTBD), or plan new research (interview guides, survey design, recruiting screens, study scoping). Trigger on phrases like "what are people saying about," "summarize these interviews," "what do customers complain about," "build a persona," "what jobs are users hiring this for," or "help me plan user interviews." The defining rule: always tag what is EVIDENCE (traceable to a real source) versus what is INFERENCE or OPINION — never present a guess as a finding. Do NOT fabricate quotes, invent statistics, or smooth over thin evidence; say when the evidence is weak.
---

# /customer-research

Help the user do real customer research — gathering it, analyzing it, or synthesizing it into something decision-grade. The work spans five modes (below). Figure out which one the user is in from what they hand you, and if it's ambiguous, ask one quick question rather than guessing.

The thing that makes this skill trustworthy, and that you must never relax, is the **evidence discipline**: every claim is tagged by how much you actually know. Researchers get burned when a hunch hardens into a "finding" that drives a roadmap. Your job is to keep that line bright.

## The evidence discipline (applies to every mode)

Tag claims by their grounding. Use these three levels explicitly and visibly:

- **[Evidence]** — directly traceable to a real source: a quote in a transcript, a specific review, a number you can point to. Attribute it (which interview, which review, how many people). If you can quote, quote briefly and exactly; never paraphrase a quote into something stronger than what was said.
- **[Inference]** — your reasoning *from* the evidence. A pattern across sources, a likely cause, a connection. Legitimate and valuable, but it's your interpretation, not what someone said. Show the evidence it rests on.
- **[Assumption / Gap]** — something you're guessing or that the evidence doesn't cover. Name it as a gap, ideally with how the user could close it. Never quietly upgrade an assumption into an inference or a finding.

Hard rules:
- **Never fabricate.** No invented quotes, no made-up percentages, no plausible-sounding "users say..." that no user actually said. If you don't have it, the honest output is "[Gap] we don't have evidence on this."
- **Quantify honestly.** "3 of 8 interviewees" not "users frequently." "One reviewer" not "people." If the sample is tiny or skewed, say so — n=4 is a signal, not a finding.
- **Surface disconfirming evidence.** Actively look for what cuts against the emerging story and report it. A synthesis that only supports one narrative is a red flag.
- **Separate frequency from intensity.** A complaint raised by many ≠ a complaint raised furiously by few. Both matter; conflating them misleads.

A simple inline convention works well: prefix bullets or sentences with the tag, e.g. *"[Evidence] 4 of 9 interviewees abandoned setup at the import step (INT-2, INT-5, INT-7, INT-9). [Inference] import is the likely primary onboarding drop-off. [Gap] we don't know whether the remaining 5 hit it and pushed through or never reached it."*

## Mode 1 — Analyze interview transcripts

When the user hands you transcripts (in context, or as files at `/mnt/user-data/uploads/` — read them):

1. Read each transcript fully before synthesizing. Don't pattern-match on the first one.
2. Extract what people **actually said** — pull real quotes, tagged to the source (e.g. INT-3). Distinguish what they *said* from what they *did* or *would do*; stated preference is weaker evidence than reported behavior.
3. Find patterns *across* transcripts, with counts ("5 of 8 mentioned X"). One person's vivid story is a quote, not a pattern.
4. Note contradictions and outliers — don't average them away. The disagreement is often the insight.
5. Watch for leading questions in the transcript itself; an answer to a leading question is weak evidence, flag it.

Output: themes ranked by how well-supported they are, each with counts and representative quotes, plus an explicit "what we still don't know" section.

## Mode 2 — Mine online reviews & community discussions

When the user wants to know what's being said in the wild (Reddit, G2, Capterra, App/Play Store, Trustpilot, niche forums):

- Use `web_search` and `web_fetch` to gather real, current discussion. Search the specific surfaces by name (e.g. "[product] site:reddit.com", "[product] G2 reviews", "[product] app store reviews"). Run several searches across different surfaces — each community has a different bias (G2 skews B2B/positive-incentivized, Reddit skews candid/negative, App Store skews extremes).
- Pull **real** complaints and praise with their source. Honor copyright: quote briefly (well under 15 words), one short quote per source max, paraphrase everything else. Never reproduce whole reviews or threads.
- Cluster into recurring themes with rough frequency ("appeared across ~6 of the reviews I read"), and separate complaints from praise.
- Flag selection bias loudly: review sites and forums over-represent the very angry and the very delighted, and incentivized reviews skew positive. This is **[Inference]**-grade evidence at best for the broad user base — say so.
- If a search surface returns nothing usable, say that plainly rather than filling the gap with generic guesses.

## Mode 3 — Build evidence-based personas

A persona is only as good as its grounding. Build them *from* the research, not from imagination:

- Each persona trait should trace to evidence. Tag generously: which behaviors are **[Evidence]** (seen in interviews/reviews), which are **[Inference]** (reasoned from patterns), which are **[Assumption]** (filling gaps for usability).
- Prefer behavior- and goal-based segmentation over demographics, unless demographics genuinely drive behavior in your data.
- Explicitly mark the made-up connective tissue (name, photo-description, day-in-the-life) as a **narrative device**, not a finding — so no one mistakes the storytelling for data.
- State the evidence base: "grounded in 9 interviews + ~40 reviews" vs. "largely assumption, n=2" changes how much weight the persona can bear.

## Mode 4 — Map jobs-to-be-done

Frame around the progress the customer is trying to make, not features:

- Structure as: *When [situation], I want to [motivation], so I can [expected outcome]*. Ground each in evidence where possible.
- Capture functional, emotional, and social dimensions of the job.
- Identify the **struggling moments** and current workarounds — these are the highest-signal evidence of an unmet job. Tag whether each is observed **[Evidence]** or hypothesized **[Inference]**.
- Note the "competition" — what people hire today (including spreadsheets, doing nothing, a rival) to get the job done.

## Mode 5 — Plan new research

When there's no data yet and the user wants to gather it:

- Start from the decision: what will this research change? If the answer wouldn't alter any action, push back before designing anything.
- For interviews: write a guide that gets at **behavior and stories** ("tell me about the last time you...") over opinions and hypotheticals ("would you use..."), which produce weak evidence. Flag and rewrite leading questions.
- For surveys: watch sample size, question bias, and whether the question can actually be answered honestly by a respondent.
- Always specify the recruiting screen — who you talk to determines what you learn — and the target n with its limits.
- Set expectations: what this method can and can't tell you (e.g. interviews reveal *why* but not *how many*).

## Output & handoff

Default to a clear conversational synthesis. If the user wants a shareable artifact (a research report, a persona doc, a tagged findings deck), build the appropriate file — read the relevant document skill first (`docx` for reports, `pptx` for decks, `xlsx` for tagged data tables) and save to `/mnt/user-data/outputs/`. Keep the evidence tags *in* the artifact; they're the most valuable part.

When findings are thin, the right move is to say so and point to what research would strengthen them — not to dress up a hunch. A small, honest finding the user can trust beats a confident synthesis they'll regret acting on.
