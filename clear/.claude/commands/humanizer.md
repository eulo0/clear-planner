---
name: humanizer
description: Rewrite a piece of writing to remove the tells that mark it as AI-generated, so it reads like a real person wrote it. Use this skill whenever the user invokes "/humanizer", or asks to "make this sound human," "remove the AI tells," "de-slop this," "this reads like ChatGPT, fix it," "edit out the robotic voice," or otherwise wants existing prose stripped of machine-writing signatures. Target the specific tells: overused vocabulary (delve, leverage, robust, navigate, ensure, seamless, tapestry, testament, realm), em-dash overuse, the rule-of-three pattern (always three parallel examples), vague attributions ("many experts believe," "studies show"), hollow analysis that states the obvious, promotional filler, and mechanically predictable parallel structures. Preserve the original meaning and overall structure; rewrite only the prose. Do NOT change the author's claims, add new content, or flatten genuine voice — the goal is to sound like the writer, not like a different AI.
---

# /humanizer

Take a piece of writing and rewrite it so it reads like a person wrote it, not a language model. The work is mostly subtractive and corrective: the meaning and the bones of the piece stay; the machine-signatures in the prose come out. The trap to avoid is replacing one set of tells with another — over-edited writing that's been "humanized" has its own stiff, trying-too-hard signature. The target is prose that's simply *unremarkable* in the way human writing is: a little uneven, plainspoken, willing to be direct.

## What to remove (the tells)

Work through these deliberately — they're the specific fingerprints of AI prose:

**Overused vocabulary.** Cut and replace the words models reach for by default: *delve, leverage, robust, navigate (figuratively), ensure, seamless, tapestry, testament, realm, foster, underscore, pivotal, crucial, vital, intricate, multifaceted, landscape (figurative), embark, harness, elevate, unlock, dive in, at its core, in today's world.* Replace with the plain word a person would use — *leverage* → *use*, *delve into* → *look at* / *get into*, *ensure* → *make sure*. Don't swap one fancy word for another; go simpler.

**Em-dash overuse.** Models scatter em-dashes everywhere. Keep one only where it genuinely earns its place; convert the rest to commas, periods, parentheses, or just restructure. If a paragraph has three em-dashes, at least two are wrong.

**The rule of three.** AI compulsively lists exactly three things, builds three parallel clauses, gives three examples. Real writers list two, or four, or one. Break the pattern: cut an example, add a fourth, collapse three parallel clauses into one direct statement. When you notice a triple, change its count.

**Vague attributions.** "Many experts believe," "studies show," "it is widely regarded," "research suggests" — these are hollow because they cite no one. Either name the actual source if it's known, or drop the false authority and state the claim plainly as the author's own, or hedge honestly ("I think," "as far as I can tell"). Never keep the empty appeal to unnamed authority.

**Hollow analysis.** AI states the obvious in an analytical tone — sentences that sound like insight but say nothing ("This highlights the importance of...", "It's worth noting that...", "This serves as a reminder that..."). Cut them. If a sentence would be equally true of almost any topic, it's filler. Keep only sentences that carry real, specific content.

**Promotional language.** Unearned superlatives and marketing gloss — "game-changing," "revolutionary," "powerful," "cutting-edge," "world-class," "seamlessly integrates." Strip the boosterism; let the substance make the case. Downgrade hype to accurate description.

**Predictable parallel structure.** Endless "Not only X, but Y," "It's not just A, it's B," perfectly balanced sentence pairs, every paragraph opening the same way. Vary it. Real prose has sentences of uneven length and shape; let some be short. Let one be very short.

## What to preserve

- **The meaning and the claims.** Don't change what the author is asserting, soften a strong stance into mush, or add information they didn't have. You're editing the voice, not the argument.
- **The overall structure.** Same sections, same order, same scope — unless a structural tic *is* the tell (e.g. a mechanical "intro-three-points-conclusion" shell), in which case loosen it lightly without reorganizing the substance.
- **Genuine voice.** If the author has real style — humor, bluntness, a way of phrasing things — protect it. The aim is to sound like *this writer*, not like a neutral default human. When in doubt about whether something is a tell or the author's intentional choice, leave it.
- **Length, roughly.** Humanizing usually shortens (filler is most of what you cut), but don't pad to hit a count or gut the piece to prove a point.

## How to do it well

- **Read for rhythm.** The deepest AI tell isn't any single word — it's the metronomic evenness, every sentence the same medium length and balanced shape. Introduce real variation: a three-word sentence next to a long winding one. This does more than any word swap.
- **Prefer the plain version.** When choosing between two phrasings, the simpler, more direct, slightly more casual one is almost always more human.
- **Let it be a little imperfect.** A sentence that starts with "And" or "But." A mild redundancy a person wouldn't bother to fix. Contractions. These are features. Over-polished is itself a tell.
- **Don't overcorrect into a new style.** The failure mode is prose so aggressively "human" — folksy, quirky, stuffed with idioms — that it's just a different costume. Aim for invisible, not performatively casual.
- **Match register to the piece.** A technical doc humanized still reads as a technical doc by a person, not a blog post. Keep the formality level the author intended; remove the *machine-ness* at that register.

## Delivering it

If the writing was pasted into the conversation or is short, return the rewritten version inline. If it's a file (at `/mnt/user-data/uploads/`, or the user wants a file back), read it, rewrite it, and save the result to `/mnt/user-data/outputs/` preserving the original format (read the `docx` skill first for Word files, etc.), then present it.

Unless the user asks for an explanation, just give them the rewritten prose — don't annotate every change or lecture them on what was wrong with the original. If they want to see the reasoning or a few example before/afters, offer that as a follow-up. If a passage is genuinely fine as-is, leave it; not every piece is equally sloppy, and inventing changes to look busy is its own kind of failure.

## What good looks like

**Before:** "In today's fast-paced world, businesses must leverage robust, cutting-edge solutions to navigate an ever-evolving landscape. Many experts believe that, to ensure success, companies need to delve into three key areas: innovation, efficiency, and scalability."

**After:** "Companies that want to keep up have to actually use the tools available to them. The hard part is knowing where to focus — and for most, it comes down to whether they can grow without their costs growing just as fast."

The after says something, drops the dead vocabulary and the fake "many experts," breaks the triple, varies the rhythm, and still makes the original point — without sounding like it's auditioning for "casual human writer."
