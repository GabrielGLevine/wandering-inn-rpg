# Social Pillar II — Per-NPC Stage Tables (STAGING, not shipped)

Staged by the design lane 2026-07-06 per
`docs/superpowers/specs/2026-07-06-social-pillar-2-design.md`. LINEAR
stages, the Lyonette-thaw model: ordered stage list per NPC, each stage
advances on an authored milestone condition (existing counters read as
`_accomplishment_gate_met` AND-dicts — multi-key AND is shipped machinery,
`wi_game.gd` L756), swaps the talk pool, unlocks 1-2 deeper dialogue
options, and the FINAL stage lands one perk in visible currencies. No
points, no meters, no hearts — nothing here ever renders a number.

**Machinery note (for the execution lane, not authored here):** the shipped
seam is `talk_pool_post` (one gated replacement pool). The generalization
this table assumes: `talk_pool_stages`, an ORDERED array of
`{id, requires_accomplishment, lines}` where the LAST met entry wins
(ascending authoring, same convention as `visual_states` / classes.json
level tables). Lyonette's shipped `talk_pool_post` is exactly a
one-entry instance of it. Dialogue-option unlocks use existing
`requires`/`hide_when` accomplishment gating — hidden until met, per the
M4 gating split (progress must never leak).

**Counter dependency, named:** `chatted_with_<id>` exists ONLY for NPCs
with landed talk pools. Krshia/Selys/Pisces/Olesm/Zevara/Lyonette/
gate_guard have pools; **Erin and Relc do not** — their pools were
authored and reverted in S2 (copy preserved in
`.superpowers/sdd/fp-handoff/task-s2-social-report.md` §Dropped-but-authored)
because they red ~28 canonical scripts. Every Erin/Relc condition below
that reads `chatted_with_erin`/`chatted_with_relc` is therefore **one
authored bank away: landing their deferred pools + the S4-style re-path
wave.** That work is the single biggest cost item in this design and is
flagged as such.

Legend: ⚑ = user taste-gate (condition feel, perk shape, or canon reveal).
"Stage 1" is always the shipped base pool — listed for shape, no work.

---

## Lyonette du Marquin — THE RETROFIT (reference implementation)

| # | Stage (internal) | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `lyonette_help` | — (base) | shipped `talk_pool` (wounded pride) | — | — |
| 2 | `lyonette_thawed` | `{"resolved_wrong_order": 1}` — settled "The Wrong Order", any path | shipped `talk_pool_post.lines` (open warmth) | ⚑ optional: the oblique "too many rules" home topic (see `lyonette_stages.md` — princess-adjacent, conservative draft provided, default OUT) | ⚑ optional: "the good chair by the fire" — her pool already offers it in fiction; could back it with a once-per-waking short rest (small HP restore at the inn without sleeping). Shipped thaw has NO perk; adding one is a user call |

Her shipped `talk_pool_post` IS stage 2 expressed in the old seam — the
retrofit is renaming, not rewriting. Zero copy changes required.

---

## Erin Solstice (3 stages — she's the heart of the game)

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `erin_innkeeper` | — (base) | the S2 deferred pool (4 lines, preserved copy — landing it is the named dependency) | — | — |
| 2 | `erin_regular` | ⚑ `{"errand_decided": 1, "chatted_with_erin": 2}` — ran her errand to the end AND talked across 2 wakings | 3 lines, `erin_stages.json` | "I heard you play chess." → the chess topic (canon: her chess is core Volume 1; she beats Olesm) | — |
| 3 | `erin_friend_of_the_inn` | ⚑ `{"resolved_wrong_order": 1, "chatted_with_erin": 4}` — helped her people (Lyonette's order) AND kept showing up | 3 lines | ⚑ "You never talk about where you're from." → the oblique home topic (otherworlder-ADJACENT, no Earth, no "another world" — draft in companion) | ⚑ **a daily meal** (spec default): once per waking Erin feeds you — small HP restore, diegetic "sit, I'm testing a recipe". Needs a small seam: per-waking gating on a dialogue option or an `erin_meal` prop reusing `entity_first_use` (the verb-prefix dedup S3 built for [Observe]) |

---

## Relc Grasstongue (3 stages)

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `relc_guardsman` | — (base) | the S2 deferred pool (4 lines — same named dependency as Erin) | — | — |
| 2 | `relc_sparring_partner` | ⚑ `{"sparred_with_relc": 1, "chatted_with_relc": 2}` — took his spar AND talked across 2 wakings | 3 lines, `relc_stages.json` | "Were you always a guardsman?" → the army-past topic (safe early canon: ex-Liscor-army, chose the Watch) | — |
| 3 | `relc_brother_in_arms` | ⚑ `{"cleared_the_warren": 1, "chatted_with_relc": 3}` — the Raskghar is dead and he knows who did it. ⚑ variant: `{"relc_joined_descent": 1}` is the WARMER condition (he went into the dark WITH you) but permanently locks stage 3 for players who took the solo veto — recommend the neutral condition, user call | 3 lines | ⚑ "You ever miss the army?" → the people-he-left topic. **CANON-CHECK RESULT: Embria (his daughter) is a Volume 5 reveal (wiki/Embria, Ch 5.12) — NOT revealable at our timeline. The staged copy names NO daughter, no family.** An even-warmer "family thing" variant is drafted and flagged OFF by default | ⚑ **the repeatable spar** (spec default — NOTE `relc_spar` already re-offers, so as-specced this perk is already true). Refinement offered: post-spar once-per-waking "wager" beat — win the spar, he flips you 1 gold with a complaint about his pay. Visible currency, tiny, very Relc |

---

## Krshia Silverfang (3 stages)

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `krshia_merchant` | — (base) | shipped 4-line pool | — | — |
| 2 | `krshia_fair_weight` | `{"crate_returned": 1}` — resolved "The Missing Crate", any path, AND came back to tell her | 3 lines, `krshia_stages.json` | "Silverfang — that's your tribe?" → tribe pride topic (safe); closes with a diegetic not-yet on the necklace ("ask me when you have known me longer than one crate") | — |
| 3 | `krshia_friend_of_the_silverfangs` | ⚑ `{"crate_returned": 1, "chatted_with_krshia": 4}` — the crate plus four wakings of showing up and speaking plainly | 3 lines | ⚑ "You said the necklace was a promise." → her plans for her people. **CANON: the spellbook collection for the once-a-decade Meeting of Tribes (wiki/Krshia_Silverfang, 10 years collecting). Staged copy is OBLIQUE — "something Gnolls have been told we cannot have" — never says spellbook. User gates whether to name it** | **shop −1..2g** (spec default) — fully authorable TODAY in existing shapes: stage-gated duplicate buy options at the lower price (`requires` the stage counter) + `hide_when`-retire the full-price rows. Diegetic arrival line drafted ("the front-of-stall price is the back-of-stall price. Do not announce it."). NOTE the visible-option index shift for `economy_loop`/shop scripts — disclosure wave required |

---

## Selys Shivertail (2 stages)

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `selys_desk` | — (base) | shipped 4-line pool | — | — |
| 2 | `selys_past_the_counter` | `{"errand_decided": 1, "chatted_with_selys": 2}` — settled Erin's delivery business (either way — kept or returned, she genuinely doesn't care) AND talked across 2 wakings | 3 lines, `selys_stages.json` | "Shivertail — any relation to the Guildmistress?" → grandmother Tekshia topic (SAFE: Volume 1 canon, wiki/Selys_Shivertail — Tekshia is Liscor's Guildmistress and the hero Selys wanted to be) + follow-up "the desk keeps more people alive than a sword" beat | ⚑ **first pick at the board** (spec default): her stage-2 pool announces it in fiction ("I flag the sane ones — not a service everyone gets"). Mechanical backing: a stage-gated dialogue option offering one vetted job — cleanest v1 is a one-time good-bounty pointer (gold on completion); a *repeatable* board needs new machinery, flagged |

---

## Pisces Jealnv (2 stages — he thaws slowly, and only ever to "tolerable")

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `pisces_gawker_filter` | — (base) | shipped 4-line pool | — | — |
| 2 | `pisces_tolerable_company` | `{"learned_magic_from_pisces": 1, "chatted_with_pisces": 3}` — took his instruction seriously AND kept coming back (three wakings; he counts, he'd never admit it) | 3 lines, `pisces_stages.json` | "You hold yourself like a swordsman, not a scholar." → the rapier/father topic. ⚑ **CANON, tread-light verdict:** father a [Fencer] (Padurn, wiki/Pisces) = mild, staged; "I sold the blade years ago, when circumstances were... instructive" = oblique Wistram-era nod, staged with flag. **FORBIDDEN at this timeline: the expulsion cause, the sixty dead, Az'kerash, Ceria specifics** — listed in the companion as a hard rail | ⚑ **no spec default — proposal:** "a duelist's drill": once per waking, ask Pisces to drill your casting → full MP restore in the field (diegetic "second breath" callback to his own lesson). Alternative: a one-time practice-focus gift item. Both need small seams; user picks or strikes |

---

## Olesm Swifttail (3 stages)

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `olesm_clerk` | — (base) | shipped 3-line pool | — | — |
| 2 | `olesm_worth_interrupting_a_tally` | `{"cisterns_reported": 1}` — resolved the cisterns, ANY path, and reported back to him (all three report options bank it) | 3 lines, `olesm_stages.json` | "You run half this city from that desk. You know that, right?" → the self-doubt topic (safe early canon: he frets about his level and usefulness; quietly proud underneath) | — |
| 3 | `olesm_board_partner` | ⚑ `{"cisterns_reported": 1, "chatted_with_olesm": 3}` — the quest plus three wakings of actually stopping to talk | 3 lines | ⚑ "What's next for you, Olesm?" → the ambition topic: [Strategist] dream + "I've started writing to other [Tacticians]" (⚑ mild: proto-newsletter, canon has his chess newsletter later — kept oblique, no 'newsletter') | ⚑ **the chess counter-beat** (spec default): an authored chess-match dialogue scene — he shows you the eleven-move loss Erin handed him and makes you play it out. Suggested backing: a `chess_with_olesm` accomplishment + a 2g friendly wager either way (visible currency; gold effects exist in dialogue today). The match copy itself is a follow-up writing task — the option + frame node are staged |

---

## Zevara Sunderscale (2 stages)

| # | Stage | Advance condition | Pool | Unlocks | Perk |
|---|---|---|---|---|---|
| 1 | `zevara_captain` | — (base) | shipped 3-line pool | — | — |
| 2 | `zevara_trusted_irregular` | `{"resolved_the_cisterns": 1, "chatted_with_zevara": 2}` — a real problem under her city got HANDLED (any path — she respects closed files, not methods) AND you've talked across 2 wakings | 3 lines, `zevara_stages.json` | (a) "I heard you can breathe fire." → the Oldblood topic (SAFE + canon-exact: ~10 seconds, can't breathe while using it, wiki/Zevara_Sunderscale). (b) ⚑ "Why'd you take this job? It's eating you." → the oath topic. **CANON: she reported her predecessor for ignoring murders of Antinium Workers. Staged copy is OBLIQUE — "the dead were the kind the city didn't mourn", no Eresc, no Antinium named — user gates naming** | **watch-bounty access** (spec default): her stage-2 pool announces it ("see me about bounty work"). Backing: bounty-claim dialogue options paying gold for already-cleared incidents (`found_the_crate`, `resolved_the_cisterns`, `cleared_the_warren` — each `requires` the counter, `hide_when` a `claimed_*` bank; pure existing shapes, drafted in `zevara_stages.json`) |

---

## ⚑ Roll-up for the user skim (18 flags)

**Conditions (feel check, 6):** Erin s2, Erin s3, Relc s2, Relc s3 (+ the
`relc_joined_descent` warmer-variant call), Krshia s3, Olesm s3 — all the
`chatted_with_* ≥ N` AND-legs: do N=2/3/4 wakings feel like story beats or
chores? (They're invisible — the NPC just changes one morning.)

**Perks (shape check, 8):** Erin daily meal (needs per-waking seam), Relc
spar refinement (wager beat vs status quo), Krshia discount (authorable
now; index-shift disclosure), Selys board pick (one-time vs repeatable),
Pisces proposal (no spec default — drill vs gift vs strike), Olesm chess
beat (wager + follow-up writing task), Zevara bounties (authorable now),
Lyonette optional perk (ships perk-less today).

**Canon reveals (conservative-by-default, 4):** Relc's daughter **OUT**
(V5, hard finding) — oblique "people I left in it" staged instead, warmer
"family thing" variant OFF by default; Krshia spellbook obliqued; Pisces
Wistram-era obliqued (hard rails listed); Zevara's Eresc/Antinium
obliqued. Plus Erin's home topic (otherworlder-adjacent oblique) and
Lyonette's optional home topic (princess-adjacent, default OUT).
