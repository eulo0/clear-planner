---
name: pricing-strategy
description: Think through pricing and packaging decisions and arrive at a concrete recommendation. Use this skill whenever the user invokes "/pricing-strategy", or raises any pricing/monetization question: tier structure, packaging and bundling, free trials vs. freemium, willingness to pay, value metrics (what you charge per), price increases, free-plan design, paywall placement, discounting, or "how should I price X." Always establish the customer, segment, and business model BEFORE recommending anything — pricing advice without that context is worthless. Apply real frameworks (Van Westendorp price sensitivity, value-metric selection, good-better-best, the value-cost-competition triangle) when they sharpen the decision. The defining rule: never give generic "it depends" advice — push the user for the specifics that resolve the "it depends," then commit to a concrete recommendation with reasoning and the risk you see.
---

# /pricing-strategy

Help the user make a real pricing decision and walk away with a specific answer. Pricing is the highest-leverage number in a business and the easiest to get wrong by reasoning in the abstract. Two commitments define this skill: **context before advice** (you cannot price without knowing the customer, segment, and model), and **a concrete recommendation at the end** (never the cowardly "it depends" — get the specifics that resolve it, then commit).

## Step 1 — Establish context before suggesting anything

Do not propose a price, tier, or structure until you understand the situation. Ask about what you don't already know — pull from prior context (e.g. a `consult` skill or earlier conversation may describe the product) before asking, and only ask for what's actually missing. The essentials:

- **Who's the customer, and what segment?** Self-serve consumer, prosumer, SMB, mid-market, enterprise? B2B vs. B2C? The same product prices completely differently across these. A $50/mo plan is nothing to a company and a lot to a student.
- **Business model & motion** — subscription, usage-based, one-time, marketplace, ads? Sales-led or self-serve/PLG? This constrains what packaging even makes sense.
- **The value they deliver** — what does the product *get the customer*, ideally in money or time saved? Price anchors to value, not cost. If they can't articulate the value, that's the first problem to solve.
- **Current state** — is this net-new pricing or a change to existing pricing? If a change, what's the current price, and what's prompting the rethink (margins, churn, competitor moves, "feels too cheap")?
- **Competition & alternatives** — what do prospects compare against, including doing nothing or a spreadsheet? Competitor prices are a reference point, not a target.
- **Constraints & goals** — are they optimizing for growth, revenue, margin, or land-and-expand? Any floor (unit costs) or ceiling (what the market bears)?

Ask the few that matter most for *their specific* question — don't run the whole checklist if they're asking narrowly about, say, trial length. Batch related questions so it's one or two rounds, not an interrogation. If the user resists specifics ("just give me a rule of thumb"), explain briefly why the specifics change the answer materially, and give your best provisional read *labeled as provisional* — but keep pushing for what would firm it up.

## Step 2 — Bring the right framework (only when it sharpens the call)

Use frameworks as tools, not decoration. Reach for them when they resolve something:

- **Value metric selection** — *what* you charge for (per seat, per usage, per outcome, flat). Often the highest-leverage decision in the whole exercise: the best value metric scales with the value the customer receives, aligns price with their success, and grows the account naturally. Probe whether the current metric does this.
- **Van Westendorp Price Sensitivity Meter** — when the question is "what price?" and the user can get (or has) survey data. The four questions: at what price is it *too expensive* (won't buy), *too cheap* (doubt quality), *getting expensive* (gives pause but considers), and *a bargain* (good value). The intersections bound an acceptable range and an optimal point. Explain it plainly if the user isn't familiar; note it captures *stated* willingness to pay, which overstates reality — pair with behavioral evidence where possible.
- **Good-better-best / tiering** — when the question is packaging. Anchor with the structure: a tier that segments by the value metric, a clear "most popular" middle, and an anchor-high tier that makes the middle feel reasonable. Avoid feature-salad tiers no one can parse.
- **Value-cost-competition triangle** — the three reference points for any price. Cost sets the floor, competition sets the reference, value sets the ceiling. Generic advice ignores one; name where the user's pricing sits among the three.
- **Freemium vs. free trial** — free trial when value is fast to demonstrate and the buyer is evaluating; freemium when the free tier drives acquisition/virality and you can cleanly gate the monetizable value without crippling the free experience. The trap is a free plan so generous no one upgrades, or a paywall so aggressive no one reaches value — name which risk applies.

Don't force a framework that doesn't fit; a sharp qualitative argument beats a misapplied model.

## Step 3 — Commit to a concrete recommendation

This is the part that makes the skill worth invoking. After the context and analysis, **give a specific answer**:

- Name actual numbers, tiers, or structures — "$29/mo for the core tier, gated on [metric], with a 14-day free trial" not "consider a mid-range price with a trial."
- Give the reasoning: why this price, why this metric, why this structure — tied to the customer and value you established.
- State the **biggest risk** in your recommendation and how to de-risk it (e.g. "test the top tier price; it's the softest assumption").
- Where you're genuinely uncertain, say what *evidence* would resolve it (a Van Westendorp survey, a price test on new signups, churn analysis) — that's the legitimate form of "it depends": a path to the answer, not a shrug.
- If the user's instinct is wrong, say so directly and explain why. You're a partner with a stake in getting this right, not a menu of options.

"It depends" is only acceptable immediately followed by *what it depends on* and *what you'd do given the most likely case*.

## Step 4 — Optional artifact

If the decision is complex (multi-tier packaging, a pricing-page redesign, a Van Westendorp analysis with data), offer to capture it — a tiering table or model in `xlsx`, a recommendation memo in `docx`, or an inline comparison. Read the relevant document skill first and save to `/mnt/user-data/outputs/`. For most questions, a clear conversational recommendation is the right output; don't manufacture a document the user didn't need.

## What good looks like

**Bad:** "Pricing depends on your market and customers. Consider value-based pricing, maybe a few tiers, and test different price points. Free trials can work well for SaaS."

**Good:** "Before I price this — are you selling to the students directly or to universities? ... Okay, self-serve to students. At that segment, $5–8/mo is the believable band; above ~$12 you'll trigger the 'it's just a planner' objection. I'd charge per-active-semester rather than monthly, because that's when the value (surviving a chaotic schedule) actually lands and it kills summer churn. Structure: a genuinely useful free tier capped at one term's planning to drive word-of-mouth on campus, then $6/mo or $40/year for unlimited + the auto-reschedule feature that's your real differentiator. Biggest risk: the free tier might be too generous and cannibalize — so gate auto-rescheduling, which is the feature they can't live without once they've felt it. If you can run it, a Van Westendorp survey on 100 students would tighten that $5–8 band before you commit."
