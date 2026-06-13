---
name: find-skills
description: Help the user discover which skills exist for a task they want to do, by searching the skills available in this environment and recommending the best matches. Use this skill whenever the user invokes "/find-skills", or asks "is there a skill for X," "how do I do X with my AI tool," "what skills do I have," "do I already have something for X," "what can you help me with," or otherwise wants to know whether a capability exists rather than asking to perform the task directly. Inventory the skills actually present in the environment — built-in/public skills, example or marketplace-style skills, and the user's own local skills — match them against the user's described need, and recommend the closest fits with what each does and where it lives. For genuinely missing capabilities, offer the real next step (obtain from a source the user points to, or scaffold a new skill) rather than promising an install mechanism that doesn't exist.
---

# /find-skills

Help the user find the right skill for what they're trying to do. They'll describe a need ("how do I research customers," "is there a skill for pricing") and want to know what already exists before reinventing it. Your job is to inventory what's actually available, match it honestly against the need, and point them to the best fit — or tell them plainly when nothing fits.

The one rule that keeps this trustworthy: **recommend only skills that actually exist in the environment, and be honest about what you can and can't do to get them new ones.** Don't invent skill names that sound plausible, and don't promise a one-click install or a marketplace that isn't really there.

## Step 1 — Inventory what's actually present

Skills live in known locations on the filesystem. Look in all of them — don't answer from memory, the set changes. Run:

```bash
echo "=== USER (local) skills ===";    ls -1 /mnt/skills/user/ 2>/dev/null
echo "=== PUBLIC (built-in) skills ==="; ls -1 /mnt/skills/public/ 2>/dev/null | grep -v '\.skill$'
echo "=== EXAMPLE / marketplace skills ==="; ls -1 /mnt/skills/examples/ 2>/dev/null | grep -v '\.skill$'
```

(There may also be `/mnt/skills/private/` — check it too if it exists.) These three buckets map to what the user thinks of as: **built-in** (public), **marketplace-style** (examples — a library of installable skills), and **their local setup** (user).

To match well, you need each candidate's *description*, not just its name. For any skill whose relevance isn't obvious from the name, read its frontmatter to see what it actually does and when it triggers:

```bash
# read just the YAML frontmatter (name + description) of a skill
sed -n '1,8p' /mnt/skills/<bucket>/<skill-name>/SKILL.md
```

Read the descriptions of the plausible candidates before recommending — the name often undersells or misrepresents the scope.

## Step 2 — Match against the need

Map the user's described task to the skills whose *descriptions* cover it. Judge by what the skill actually does (from its frontmatter), not by surface word-matching on the name. A few principles:

- **Rank by fit.** Lead with the closest match, then near-misses. If several overlap, say how they differ so the user picks the right one (e.g. two research skills where one is for customers and one for the open web).
- **Note the bucket.** Tell the user where each lives — already in their local setup (ready now), built-in (ready now), or an example/marketplace skill (available but they may need to add it).
- **Be honest about partial fits.** If a skill covers half the need, say which half. Don't oversell a loose match as a perfect one.
- **Say so when nothing fits.** A clear "there's no skill for this" is more useful than stretching an unrelated skill to seem responsive.

## Step 3 — Offer the real next step for gaps

This is where honesty matters most. What you can actually do depends on the situation:

- **It's an example/marketplace skill they don't have locally:** these already exist as packaged `.skill` files in the examples directory. You can explain what it does and, if the user wants it in their own setup, copy it into place or point them to the packaged file — that's a real action, do it. Don't describe it as a remote "install" if it's a local copy.
- **The skill exists somewhere the user can point you to** (a GitHub repo, a URL they provide): offer to fetch it with `web_fetch`/git within the allowed network and set it up. Only promise this for sources actually reachable — the network here is limited to a fixed allow-list (github, npm, pypi, etc.), so a skill in some arbitrary marketplace may not be reachable. Say so if it isn't.
- **Nothing exists and the user wants one:** offer to **build** it. Creating a new skill is something you can genuinely do (that's the `skill-creator` skill, which is itself available) — scaffold a new SKILL.md to their spec and save it to their local skills directory.

Be straight about the boundary: there is no universal one-click skill store you can silently install from. What you *can* do is recommend what exists, copy in the local/example ones, fetch from a reachable source the user names, or author a new skill. Offer whichever genuinely applies — don't imply a capability you don't have.

## Step 4 — Present cleanly

Give a scannable recommendation: the best match first with a one-line "what it does" and where it lives, then alternatives, then honest gaps with the concrete next step offered. Keep it conversational — this is a "here's what you've got" answer, not a report. End by offering the applicable action ("want me to copy that example skill into your setup, or build a new one for the part that's missing?") rather than a generic "let me know if you need anything."

## What good looks like

**User:** "Is there a skill for researching what customers think?"

**Good response:** Checks the directories, reads the relevant frontmatter, then: "Yes — you've got `customer-research` in your local setup already, which does exactly this: interview-transcript analysis, mining reviews and Reddit/G2, personas, JTBD. If you mean researching the open web rather than your own customers, `deep-research` (also local) is the better fit, and `competitive-intelligence` covers sizing up rivals specifically. All three are ready to use now. Want a quick rundown of how they differ?"

**Bad response:** "Yes! Try the `customer-insights-pro` skill" (invented), or "I'll install a customer research skill from the marketplace" (no such mechanism), or recommending from memory without checking what's actually there.
