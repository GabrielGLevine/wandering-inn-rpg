# Dialogue Voice Bible — de-AI pass (W1, authoritative)

**Date:** 2026-08-03 · **Author:** Fable (W1 adjudicating voice)
**Scope:** all 71 files in `wandering_inn_game/data/dialogue/` · **Spec:** `docs/superpowers/specs/2026-08-03-dialogue-voice-pass-design.md` · **Rubric:** `docs/dialogue-voice/critique-2026-08-03.md`
**Manifest:** `docs/dialogue-voice/clusters.json` (finalized by this document; 36 clusters). Constraint cards: `docs/dialogue-voice-cards/<cluster-id>.md` — your card overrides this bible where they conflict; this bible overrides your taste everywhere else.

Canon guard: Book 17 spoiler bar, game advertises Vol 7. Write **"Magical Door"**, never the Vol-9 name. Never change facts, names, numbers, directions, item names, or quest instructions — reword them, keep them findable in the same node.

---

## 1. Ban list, operationalized

Budgets are corpus-wide and enforced twice: W3 regex where a tell is mechanical (1, 4, 5, 6), W4 cold-read judgment for the rest. "0" means zero — do not spend cleverness looking for the exception.

| # | Tell | Rule | How you comply |
|---|---|---|---|
| 1 | Antithesis "X, not Y" / "not X. Y." | **≤1 per NPC lifetime; corpus ≤30** (from 62 strict / 185 loose) | Only speakers in the allocation table (§5) keep one. If your card pins the instance, keep exactly that one and kill every other. If unpinned, you may keep at most one — or zero. Unlisted speakers: zero, including soft forms ("It's not the coin. It's the counting."). |
| 2 | Button / epigram closer | **Never** on hub, shop, bark, or repeat/variant nodes. **≤1 per conversation graph**, only at its emotional peak | Your card names the peak node (or says "no button"). Every other node ends per the replacement mandate (§4). A truncated epigram is still an epigram — replace, don't amputate. |
| 3 | Sentiment-then-deflect | **≤2 corpus-wide, different shapes** (from 13) | Keepers: `rags_inn.json` and `zevara_intro.json` only (§5). Every other warm beat lands and *stays landed* — the speaker changes subject, keeps working, or just stops. No "don't tell anyone", no "forget I said that", no joke-rule. |
| 4 | CAPS emphasis | **0** (from 48 nodes) | Recast the sentence so the stress falls on word order, not typography. Not italics either — no emphasis markup at all. Acronyms/sigils that are canonically capitals are fine. |
| 5 | Mid-line ellipsis; leading-ellipsis stage beat | **0** (from 48 nodes) | `...` as hesitation/realization dies everywhere, including T0 files. Replace with a short sentence, a repeated word, a dash cut-off, or nothing. Trailing-off at end of a *node* is allowed only as a dash ("—"), and rarely. |
| 6 | "the whole of / the entire [X]" closer | **0** (from 12+) | Say the plain thing: "That's all I know." "That's it." Or end one sentence earlier. |
| 7 | Prose triads | Triads live in quest structure, never in the sentence | Three quest paths may exist; the NPC never announces "three things/ways/measures" and never lists them in one balanced sentence. Break the list across turns, or count wrong, or forget one and come back to it. |
| 8 | Character names the theme | **0** | The reveal's *facts* survive; the thesis sentence dies. If a line would look good on a poster, the character may not say it. The reframe belongs to the player. |
| 9 | Recursive-bureaucracy gag | **1 instance survives** (from 3) | Keeper: `pallass_lift_attendant.json` (§5). `pallass_den_keeper.json` loses both of its instances — the grievance stays, the self-referential loop goes. |
| 10 | "Apparent object isn't the real one" reveal | **≤2 of 4 quests keep the shape** | Keepers: `riverfarm_tallyman.json`, `pisces_seal.json` (§5). `pallass_forge_smith.json` and `invrisil_stationer_client.json` keep every fact but lose the aha-reframe staging (see those cards). |
| 11 | Combat-bark template (sensory + dry understatement) | **5+ different shapes** | Each bark card assigns a shape (§3, barks). No bark ends on wit. |

W3 regexes will sweep: `[A-Z]{2,}` (excluding legal sigils), `\.\.\.` and `…`, `the (whole|entirety|entire)`, and a strict/loose antithesis pattern set. Do not try to sneak a tell past the regex with formatting; W4 reads cold.

---

## 2. Tier definitions and worked pairs

A tier is a *register*, not a quality level. Dullness lives in **how**, never in **what**: every fact, hook, and instruction stays. The failure mode you are being paid to avoid is stripped-but-flat — a node that lost its button and gained nothing. Every deletion buys something concrete (§4).

### T0 — preserve (already reads human)

Strip tells (bans 1–8 still apply, including ellipses), change **nothing else**. Sentence stats must land within ±10% of the original node. If a T0 line has no tell, do not touch it. W4 diffs T0 output against the original and flags drift.

**Worked pair A — `rags_inn.json`, node `served`** (this file's one button *and* one of the two corpus sentiment-deflect keeps — the maximum-value case, and still the touch is one character wide):

> Before: `Hot. Good. ...Chieftain eats last. Always last. Tonight, first. Tell no one.`
> After: `Hot. Good. Chieftain eats last. Always last. Tonight, first. Tell no one.`

The ellipsis dies (ban 5, no exceptions). Everything else stays: the repeat is her voice, "Tell no one." is a budgeted keep.

**Worked pair B — `crab_nest.json`, node `confront`** (a bark inside a T0 cluster — the one place a T0 batch does real rewriting):

> Before: `One of the boulder shapes grinds upright — plates of grey stone sliding over something alive underneath. It does not hurry. Things armored like that rarely need to.`
> After: `One of the boulder shapes grinds upright — plates of grey stone sliding over something alive underneath. Sand pours out of the joints. It starts toward you at a walk and does not speed up.`

The dry-understatement closer (bark template, ban 11) is replaced with motion that carries the same information: armored, unhurried, coming.

### T1 — rural / illiterate

Dropped agreement ("it weren't", "them fences"), self-repeats, thread-losing. **Avg ≤8 words/sentence, max 14. No subordinate clauses** — coordination only ("and", "but", "so"), sentence-initial conjunctions encouraged. **No semicolons, no colons, no parentheses.** Dashes only as cut-offs. People here are allowed to be dull, wrong-footed, and unquotable; that is the point.

**Worked pair A — `riverfarm_villager.json`, node `remember`:**

> Before: `Pieces. A price I agreed to without reading the whole of it. A voice that wasn't mine coming out of my own mouth for weeks. I keep waiting to feel angrier about that than grateful. Maybe both fit.`
> After: `Pieces. A price I said yes to. Never read the terms, none of us did. There was a voice in my mouth for weeks and it weren't mine. I should be angry. I keep meaning to be angry.`

"The whole of" dies (ban 6), the balanced closer dies (ban 2), and what replaces it is a self-repeat that doesn't resolve — the villager can't finish the feeling, which is truer than "maybe both fit."

**Worked pair B — `riverfarm_hunter.json`, node `thicket_sign`:**

> Before: `Here. Hoof marks come up, stop, turn, and go back, all along one line you can't see from standing. Not one print past it in a mile of treeline. Whatever's holding them isn't teeth. Teeth leave a mess.`
> After: `Here. Hoof marks come up, stop, turn, go back. Same line, every time. You can't see it from standing. Not one print past it in a mile. Teeth would've left a mess. There's no mess.`

The antithesis-plus-button ("isn't teeth. Teeth leave a mess.") becomes a repeat-move: he says "mess" twice because he's still looking at the ground. All facts survive: the line, the mile, the no-teeth inference.

### T2 — trade / working

Shop jargon, concrete nouns, impatience, interruptions. **Avg 9–13 words/sentence.** Subordinate clauses ≤1 per three sentences. **No semicolons.** Colons only for prices and lists. Exclamations sparingly, and only from the loud ones (Relc, patrons). These people think in tools, quantities, and shifts — when in doubt, name the object in their hands.

**Worked pair A — `selys_inn.json`, node `served`** (a sentiment-deflect that did NOT get a budget slot):

> Before: `...that is a good bowl of stew. Do not tell anyone I said so. I have a reputation for being hard to please.`
> After: `That's a proper bowl. Barley in it and everything. Where does she even get barley before the pass opens?`

The warmth stays — it just goes somewhere: a concrete trade question she doesn't answer herself (replacement move 3). No secrecy-quip, no reputation-quip.

**Worked pair B — `relc_intro.json`, node `relc_army_two`:**

> Before: `Long version costs a drink. Short version: I got tired of holes in the ground and people I liked going into them. Watch work, the worst thing I dig is paperwork. ...What? I can be deep. It's the tail, nobody expects it.`
> After: `Long version costs a drink. Short version: I got tired of holes in the ground and people I liked going into them. Watch work, the worst thing I dig is paperwork. There's a longer version. It costs a drink and I lose the middle of it every time.`

The self-aware button ("It's the tail, nobody expects it") dies. What replaces it is an unfinished fact — the story he can't tell straight — which does the emotional work the quip was faking.

### T3 — educated / formal

The only tier where complex syntax survives. **Avg 13–18 words/sentence.** Subordination allowed to depth 2. Semicolons ≤1 per node; colons fine. What you must break here is not complexity but *balance*: T3 characters may build a long sentence, but it should lean — trail into specifics, over-qualify, self-correct — rather than land on a fulcrum. Educated is not the same as epigrammatic.

**Worked pair A — `hedault_enchanting.json`, node `door_reading_verdict`** (worst-lines table entry):

> Before: `A set ward holds a shape. A fed ward holds an appetite, and an appetite has to be sourced. Whoever hung that frame did not hang it alone. A draw that size runs to something, and the something is not in your pantry. I will not speculate further in a shop. Bring me the setting when you know, and I will price the work correctly.`
> After: `A set ward holds a shape. A fed ward has to be sourced, continuously, from somewhere with capacity. Whoever hung that frame did not hang it alone, and I have measured what it pulls. Nothing in your pantry pulls that. I will not speculate further in a shop. Bring me the setting when you know, and I will price the work correctly.`

"The something is not in your pantry" (noun-repeat-as-wit) becomes a measurement — Hedault reaching for his instruments instead of a phrase. The fact (the source isn't domestic) survives verbatim in function.

**Worked pair B — `zevara_intro.json`, node `zevara_oath_two`** (worst-lines table entry, and the second sentiment-deflect keep):

> Before: `Luck is what people call other people's overtime. But — thank you. File that under 'said once'. Now get out of my gatehouse before I find you a shift.`
> After: `Ten years of overtime is what that was. But — thank you. File it under 'said once.' Now get out of my gatehouse before I find you a shift.`

The bumper sticker dies; the flat fact that was hiding inside it takes the slot. The deflect ("File it under 'said once.'") is a budgeted keep — its shape is *paperwork*, which is hers and no one else's.

### T4 — non-human / construct

Rule-bound, literal, never witty. **Avg 8–13 words/sentence, declaratives.** **Zero contractions, zero exclamations, zero metaphor, zero rhetorical questions.** Subordination only as conditionals ("If X, then Y."). Numbers and measurements are this tier's texture — a T4 speaker counts what others would feel. The trap: literal-minded characters attract "accidentally profound" closers. A T4 line may be *touching*; it may never be *arranged*.

**Worked pair A — `klbkch_inn.json`, node `offduty`:**

> Before: `Then I would like to know what it IS supposed to do. Relc says the point is that there is no point, which is what he says about anything he has not thought about. So I have measured instead. Eleven people have laughed since I sat down. Not one has looked at the door. On a street that would concern me a great deal. In here I believe it is the intended result.`
> After: `Then I would like to know what it is supposed to do. Relc says the point is that there is no point, which is what he says about anything he has not thought about. So I have measured instead. Eleven people have laughed since I sat down. Not one has looked at the door. On a street I would report that. Here, apparently, it is normal. I am still counting.`

CAPS dies (ban 4). The tidy closer ("the intended result") becomes an action beat: he keeps counting, because he is Klbkch and stopping is not among his settings.

**Worked pair B — `forge_calibration_golem.json`, node `confront`** (bark template instance, ban 11):

> Before: `A stone shape at the edge of the forge-heat turns too fast, cracks glowing brighter along its arms — one of the tier's own constructs, off its command spells again. It hasn't been told you're not a shipment.`
> After: `A stone shape at the edge of the forge-heat turns too fast, cracks glowing brighter along its arms — one of the tier's own constructs, off its command spells again. Its head-block swings to you, to the crates, back to you. The second swing is faster.`

The understatement closer dies. Escalation replaces it: the golem is deciding, and the decision is speeding up.

### Barks and object notes (tierless)

The six combat/exploration barks (`crab_nest`, `corusdeer_range`, `razorbeak_nest`, `kingslayer_den`, `gallery_vermin_nest`, `boulevard_duel_ring`) plus `riverfarm_thicket_patch` are narrator-voiced; object notes (`dummies_note`, and narrator framing inside `room_ledger`) likewise. Rules: 2–4 sentences, concrete sensory verbs, **no closer-wit, no understatement punchline, no "It has seen things"-class asides**. Each combat bark's card assigns one shape so no two match: pure motion · environment-first · sound-first · your-body-reacts · count-and-measure · detail-interrupted.

---

## 3. Per-tier sentence-stat targets (summary table)

| Tier | Avg words/sentence | Subordinate clauses | Punctuation policy |
|---|---|---|---|
| T0 | match original node ±10% | as original | strip bans 4/5/6 only |
| T1 | ≤8 (max sentence 14) | none — coordination only | . ? — only; no ; : ( ) |
| T2 | 9–13 | ≤1 per 3 sentences | no ; · : for prices/lists only · ! sparingly |
| T3 | 13–18 | depth ≤2 | ; ≤1/node · : fine · no emphasis markup |
| T4 | 8–13, declarative | conditionals only | no contractions · no ! · no ? (rhetorical) |
| bark/note | 2–4 sentences/node | light | no wit closers; no ellipses; present tense |

Stats are per-node targets, not straitjackets — W4 judges by read, W3 only flags outliers. A single 20-word sentence in T1 is fine if it's a man losing his thread; five of them is a failed file.

---

## 4. The replacement mandate

A deleted button is never mere truncation — truncation produces stripped-but-flat, which plays *worse* than what we have. Every kill is a swap. Three named moves; your card's FORCED section may demand specific ones.

**Move 1 — PUT A THING IN THE LINE (concrete physical detail).** End on an object the speaker can see or touch, specific enough to be nobody else's.

> `invrisil_rest_factor.json`, `exchange_three` — Before: `Nobody in this room raises their voice and nobody in this room has ever seen a thing. That isn't a rule of the house. That's the rent.`
> After: `Nobody in this room raises their voice and nobody in this room has ever seen a thing. Third peg by the fire's been holding the same coat since Wintersday. Nobody's asked about that either.`

The epigram ("That's the rent") dies; the coat — already this NPC's prop — carries the same threat with a real object.

**Move 2 — HANDS KEEP WORKING (action beat).** The speaker resumes their task mid-line; the conversation ends because their attention moved, not because the line resolved.

> `pallass_forge_smith.json`, `commission_settled` tv[0] — Before: `The rig is honest again and my apprentice gets a fair reading. I will not thank you over a hot hammer. Take it as said.`
> After: `The rig is honest again and my apprentice gets a fair reading. Hand me the tongs — no, the short ones. She has forty-two on the board and I want the slab hot before second bell.`

"Take it as said" is a deflect-shaped closer; the swap is the smith already back at the slab, ordering the player around like an apprentice — which *is* her thanks.

**Move 3 — LEAVE THE LEDGER OPEN (plainly unfinished fact).** End on a fact with a hole in it that the speaker doesn't fill. No punchline geometry — the sentence should feel like it has a next sentence that never comes.

> `selys_inn.json`, `served` — Before: `...that is a good bowl of stew. Do not tell anyone I said so. I have a reputation for being hard to please.`
> After: `That's a proper bowl. Barley in it and everything. Where does she even get barley before the pass opens?`

The question is real, unanswered, and stays that way. (Also the T2 worked pair A — one swap can serve two masters.)

**Anti-patterns.** (1) Trailing dash as a tic — one per file, maximum. (2) The "flat fact" that is secretly an epigram ("Paperwork doesn't bleed.") — if it would fit on a poster, it's a button. (3) Replacing every button with move 3 — vary, or you've built a new template. (4) Adding narrator stage direction to speech-only files — match the file's existing mode.

---

## 5. Allocation of scarce budgets (binding)

### 5a. The one recursive-bureaucracy gag (ban 9)

| Keeps it | Loses it |
|---|---|
| **`pallass_lift_attendant.json`** — its single instance ("the office cannot clear the queue until the queue clears the office…"), which may be lightly retouched but keeps the self-referential loop | `pallass_den_keeper.json` — **both** instances ("My tin is in a queue. I am in the queue behind my tin." and "Countersigned. By the office that was waiting on the queue, about the queue.") become plain grievance + physical detail, no loop |

Reason: the lift queue *is* the attendant's entire job — the gag is diegetic there and decoration everywhere else; the den keeper's file is the most-quoted in the critique and needs the most distance from it. `pallass_forge_clerk.json`'s release-chain procedure is not the gag and must not become it — keep it procedure, never self-referential.

### 5b. The ≤2 "apparent object isn't the real one" reveals (ban 10)

| Quest file | Verdict | Note |
|---|---|---|
| **`riverfarm_tallyman.json`** (shortfall = shame, not theft) | **KEEPS the shape** | Emotional core of a T1-adjacent quest; the plain register earns it |
| **`pisces_seal.json`** (ward = keeping, not imprisoning) | **KEEPS the shape** | The climax read; T3 is the one tier where an articulated reframe is in-register |
| `pallass_forge_smith.json` (blades = recovery, not hardness) | loses the shape | Facts stay; restaged as procedure — the examiner's notice read aloud, no reframe epigram, no theme-naming (its two worst-lines die with it) |
| `invrisil_stationer_client.json` (heirloom = setting, not stone) | loses the shape | Facts stay; Hedault's side of the same chain already articulates it once — the Lady's nodes present it as price arithmetic and habit, not revelation |

### 5c. The ≤2 sentiment-then-deflect nodes (ban 3)

| Keeper | Node | Shape (must stay distinct) |
|---|---|---|
| **`rags_inn.json`** | `served` | Four-word secrecy order after flat facts ("Tell no one.") |
| **`zevara_intro.json`** | `zevara_oath_two` | Emotion filed as paperwork ("File it under 'said once.'") |

Every other instance in the corpus dies — including Zevara's own other three (`seal` "Don't make me say it twice", hub tv[2] "Don't tell the others I said so", hub tv[4] "report… I'll deny writing"), both Selys nodes, Relc's "stand still while it lands", Erin's "no more feelings before lunch", Lyonette's gratitude quip, Krshia's if present. One keep per keeper file: Zevara's budget is spent on `zevara_oath_two` alone.

### 5d. Antithesis allocation (ban 1: ≤1 per NPC lifetime, corpus ≤30)

22 grants; 8 held in reserve by Fable for W5 failure-loop petitions. **Any speaker not listed gets zero.** "Pinned" = keep exactly that instance; "floating" = the cluster agent may keep at most one instance of their choice, or none.

| Speaker (lifetime scope) | Grant | Pinned instance |
|---|---|---|
| Rags (`rags_*`, `goblin_parley`) | 1 | `rags_inn` greet tv[0]: "Habit, not you." |
| The Hunter (`riverfarm_hunter`, `riverfarm_thicket_patch`) | 1 | `thicket_reported_rerouted`: "Fences before deer." |
| Relc (`relc_*`) | 1 | floating |
| Selys (`selys_*`) | 1 | floating |
| Krshia (`krshia_*`) | 1 | floating |
| Erin (`erin_errand`) | 1 | floating |
| Lyonette (`lyonette_tip`, `room_ledger`) | 1 | floating |
| Zevara (`zevara_*`) | 1 | `swept_paid`: "Funding, not evidence." |
| Olesm (`olesm_*`) | 1 | floating |
| Pisces (`pisces_*`, `door_mounting`) | 1 | floating |
| Ceria (`ceria_*`) | 1 | floating |
| Yvlon (`yvlon_intro`) | 1 | floating |
| Grimalkin (`grimalkin_inn`, `pallass_grimalkin`) | 1 | floating |
| Wilovan (`invrisil_wilovan`, `wilovan_inn`) | 1 | floating |
| Hedault (`hedault_enchanting`) | 1 | floating |
| Klbkch (`klbkch_inn`) | 1 | floating (logical contrast, never rhetorical) |
| Forge-Tier Smith (`pallass_forge_smith`) | 1 | floating |
| Tallyman (`riverfarm_tallyman`) | 1 | floating |
| Cups (`invrisil_fixer`) | 1 | floating |
| House Steward's envoy (`invrisil_house_steward`) | 1 | floating |
| Lady with a Ring Box (`invrisil_stationer_client`) | 1 | floating |
| Master Coyle (`invrisil_merchant_prince`) | 1 | floating |

Explicit zeros worth naming: the Witch (her fix is concrete detail, not balance), the Seal Broker (his worst-line *is* the pattern; he rebuilds without it), all T1 speakers except the Hunter, all clerks/attendants/den keeper, market local, both Watch sergeants, Vess, Renn, Octavia, Dresk, Xif, all golems/constructs except Klbkch, all patrons, and the narrator (all barks + notes, collectively).

### 5e. Buttons (ban 2) — rule, not table

≤1 per conversation graph, never on hub/shop/bark/repeat nodes. Each card names the peak node where the file's single button may stand (or "no button"). If a card is silent, the default is **no button**.

---

## 6. Final tier/cluster assignments

The finalized manifest is `docs/dialogue-voice/clusters.json` (36 clusters; every dialogue file in exactly one). Moves from the provisional spec table, all logged in the manifest changelog:

- `invrisil_hired_scribe`, `invrisil_rest_factor`, `invrisil_fixer`, `patron_serving` → **T2** (trade-register speakers; also breaks Invrisil/inn uniform-literacy blocks — critique tell #10)
- `pallass_forge_clerk` → **T3** (procedural-formal functionary; keeps him dull-formal, not witty)
- `door_mounting` → **pisces** cluster (speaker is Pisces; same-speaker rule)
- `invrisil_stationer_client` + `invrisil_hired_scribe` paired (same shop, same quest); `invrisil_merchant_prince` + `invrisil_fixer` paired (same quest, Coyle)
- `pallass_market_local` and `watch_crate` split into singleton clusters (rule 2)
- `dummies_note`, `goblin_parley` annotated narrator-voiced (bark/note class, tierless)

The three manifest rules are invariant and were re-validated after every move: same-speaker files share a cluster; same-tier different-speaker files never share one; each combat bark lands in a different cluster.

---

## 7. How to work (W2 agent checklist)

1. Read this bible, then your card. Extract the fact checklist per node (proper nouns, numbers, items, directions, instructions) **before** touching prose.
2. Rewrite node by node. Only `text`-carrying strings change; structure, keys, variant order, options' targets, effects, conditions, speakers, `_comment`s are frozen.
3. Player option labels are corpus text too — same bans, same budgets (they count against the *player's* register: plain, direct, no epigrams).
4. After rewriting: self-verify facts, run your own ban sweep (CAPS, `...`, "the whole/entire", antithesis count vs your card, button count vs your card), check sentence stats against §3.
5. Do not read sibling files. Do not import phrasing from this bible's worked examples into files they weren't written for — they are calibration, not stock.
