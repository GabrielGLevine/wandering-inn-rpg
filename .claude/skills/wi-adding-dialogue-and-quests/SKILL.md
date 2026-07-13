---
name: wi-adding-dialogue-and-quests
description: Use when adding or editing an NPC conversation graph in `data/dialogue/*.json`, a quest in `data/quests.json`, or any dialogue option gating/effects in the Wandering Inn RPG.
---

# Adding Dialogue and Quests

## Core principle
`WIDialogue` (`src/core/dialogue.gd`) is a pure conversation-graph walker —
it returns effects, never applies them. `WIGame.dialogue_choose` applies
effects, calls `set_ctx` with a fresh context, THEN advances — **ctx
refreshes on every node advance**, not once at conversation start. Quests
(`WIQuests`, `src/core/quests.gd`) are a pure FUNCTION of accomplishment
counters, stored nowhere — never add a "quest progress" field to save data.

## Conversation graph anatomy (one file per NPC/scene under `data/dialogue/`)
```
{ "start": "hub", "nodes": { "<id>": {
    "speaker": "Erin", "text": "...",
    "text_variants": [ { "requires": {...}, "text": "..." } ],   // optional
    "options": [ { "text": "...", "requires": {...}, "hide_when": {...},
                   "effects": [...], "goto": "<node_id>" | "end": true } ]
} } }
```
`text_variants` (list, later match wins) lets a hub's greeting change once
an accomplishment lands (`erin_errand.json`'s hub reads differently
before/after `has_package`/`errand_decided`).

## `requires` / `hide_when` — ONE gate key (one sanctioned exception)
`{"skill":"<id>"}` | `{"class":{"<id>":<level>}}` | `{"accomplishment":{"<id>":<count>}}`.
`_meets` checks skill, then class, then accomplishment, returning on the
first key present — **never combine two gate types in one dict** — EXCEPT
the FIVE sanctioned compounds (`test_content.gd`'s `_validate_requires`
whitelists exactly these; anything else fails validation):
`{gold, accomplishment}` (shop-perk buy: accomplishment leg HIDES until
met, gold leg greys-visible after — a broke player never buys on credit,
a pre-stage player never sees the perk), `{accomplishment,
once_per_waking}`, `{accomplishment, class}` (kept sanctioned, currently
no live user post-GH#64), `{once_per_waking, item}`, and
`{accomplishment, skill}` (GH#64 — the common persuade-fork shape:
stage-gated on the quest being open AND Skill-gated). `_meets` evaluates
a compound as AND; `_requirement_text` shows the visible-locked reason
only (hidden legs never render a reason).

## THE GATING SPLIT (playtest policy, M4)
- `requires.accomplishment` options are **HIDDEN** until met — progress
  must never leak (no greyed-out "3/12" hints).
- `requires.skill`/`requires.class` stay **visible-locked** — a deliberate
  tease (`current_options()` returns `locked: true` + flavor text).
- **User policy (HANDOFF):** gate options off actions taken *inside the
  conversation itself*, not unrelated class/quest progression — an
  unrelated class gate reads as arbitrary. `goblin_parley.json`'s
  `{"class":{"warrior":1}}` intimidate line is an accepted in-fiction
  exception.

## SKILL-GATES OVER CLASS-GATES (user policy 2026-07-11, GH#64)
Gate persuade options behind a CLASS-ASSOCIATED SKILL, never the bare
class, whenever a shipped Skill fits the social intent — `[Charming
Smile]`/`[Calming Touch]` (Diplomat's own L1 grants) beat `(Diplomat)`
for the same reason the verb-label policy exists: a bracket names a
real, usable thing. Keep `requires.class` ONLY when no shipped Skill
embodies the intent. Two accepted survivor shapes: (1) class-identity
recognition — an NPC greeting/text_variant reacting to the PC BEING a
class (Olesm's "you have the look of a Tactician"; Lyonette's held-a-
line read at Warrior 2) — no Skill represents membership itself;
(2) reputation/intimidation with no matching Skill in any shipped kit
(`goblin_parley`'s Warrior threat — every Warrior grant is a mechanical
combat effect). Flag every survivor with an in-file `_comment` reason.
GRANT-LEVEL COUPLING TRAP: parity with the old class gates holds
because these skills are granted at their class's L1 — moving a
dialogue-gated skill's grant level in classes.json silently tightens
every gate on it; re-check dialogue gates before any such rebalance
(mirrored in wi-adding-a-class-or-skill).

## ANTI-AUTO-WIN (finding 18, GH#64)
A Skill-gated persuade must SKIP FRICTION, never the quest's SUBSTANCE.
Before shipping any gate, trace the payoff: does the option resolve the
whole quest in one click, or land on the quest's real middle beat?
The witch mediation chain (hub → mediate_pitch → mediate_argue, report
beat still pending) is the model — the Skill gets you INTO the
negotiation; the negotiation still resolves; the report still follows.
Multi-node persuade chains (pitch → argue → close) are the shipped
idiom for a gate that feels earned inside the conversation itself.

## EVERY QUEST PATH PAYS A REAL COST (user ruling 2026-07-10, GH#50)
A fork path with no Skill gate, gold cost, combat risk, or exploration
work is a SIGNPOSTING LINE, not a solution — the v0.4.0 playtest
resolved the whole Invrisil main quest with two free conversations.
The shipped repo-wide pattern (the "witch pattern", from Riverfarm's
mediation):
- **Persuade-class options are [Diplomat]-gated, visible-locked** —
  the tease teaches that social is a build, not a freebie. The
  `persuaded_someone` counter is produced ONLY by Diplomat-gated
  persuades.
- **Each quest's TALK fork carries one real-cost ALTERNATE** for
  non-Diplomat players (gold priced to the quest's act: 2-10g), so the
  fork stays reachable without the class but never free.
- **The cost must FIT the fantasy** — a fixer selling testimony fits;
  an arbitrary toll does not. Never nerf a fork into a key-behind-a-
  door: the point is expression, not friction.
- **Entry point stays free**: exactly one ungated persuade lives in
  the world (the frazzled drayman, street 19,14) so a player can
  discover the Diplomat line at all. Don't add more; don't remove it.
- Re-pricing a shipped path invalidates its canonical's fixture/route —
  script + fixture update land in the SAME commit as the gate.
- Verb-label corollary (finding 29): bracket-verb labels on options
  (`[Persuade]`) are reserved for REAL Skills/classes the option gates
  on — never decorative.

## QUESTS ARE MULTI-STAGE; POSTINGS ARE JOBS (user ruling 2026-07-11)
A quest (journal entry, beat text) needs 2+ REAL STAGES per path — a
stage is a distinct beat with its own location/interaction and a state
change between (travel, a gate opening, information re-gating a hub).
One-interaction resolution is a POSTING's shape (Request/Delivery
board jobs are legitimately single-task); shipping it as a quest was
the Invrisil mistake (GH#68 rework). Composes with the two rules
above: the Skill/gold alternate prices ONE STAGE, never the quest;
no path auto-wins past the quest's middle beats (GH#64).

## Option lists are VISIBLE lists — index shifts
`current_options()`/`choose(index)` both iterate `_visible_options()`, so a
hidden option is invisible to indexing too — drive QA by the **currently
rendered** index, never the authored JSON index. Effects apply → `set_ctx`
refreshes → `advance()` — a mid-conversation effect (e.g.
`{"accomplishment":"asked_lyonette_guild"}`) can re-gate the very next
node, which is how hubs "unlock" a follow-up without leaving the
conversation.

## Effects (returned from `choose()`, applied by `WIGame`)
`{"accomplishment":"<id>"}` increments a counter (must be reachable or
`test_content` flags it unproduced); `{"quest":"<id>"}` starts a quest;
`{"remove_entity":"<id>"}` removes a map entity; `{"start_combat":"<id>"}`
starts a fight — **only legal on a conversation-ending option**
(`"end": true`).

## EVENT-ORDER TRAP: effects + end:true fire DIALOGUE_ENDED FIRST
`WIDialogue.choose()` emits `DIALOGUE_ENDED` synchronously INSIDE
`choose()` on an `end: true` option — BEFORE `WIGame.dialogue_choose()`
applies the option's `effects` array. So an option carrying both
`effects` and `end: true` fires `dialogue_ended`/`ui_dialogue_hidden`
before its accomplishment/quest/gold events — the OPPOSITE order from a
`goto` option (effects first, end later). Benign in the sim (effects
still apply); bites QA authoring: wait for `dialogue_ended` THEN the
effect events on a single-option close, or the effect wait times out
staring at an already-ended conversation (cost a real debug cycle,
GH#81's recruit_pell).

## Hubs and always-available exits (softlock guard)
Any node with a `hide_when` option OR an accomplishment-`requires` option
must keep at least one option with NEITHER key — a fully ungated exit.
`_validate_hide_when_nodes_have_always_available_exit` enforces this across
every graph (`WIDialogue._enter` also has a runtime fail-safe, not to be
relied on). Hubs loop back via `"goto":"hub"` (e.g. "Actually - one more
thing.") rather than `end: true`, so the player can re-enter after an
effect fires.

## Quests (`data/quests.json`)
```
{ "id":"the_errand", "title":"The Errand",
  "beats":[ {"id":"deliver","description":"...","complete_when":{"package_delivered":1}} ] }
```
`WIQuests.beat_index` walks beats in order; the first unmet beat is active
(no skipping). `evaluate()` returns `{beat_index, completed,
beat_description}` per started quest, recomputed every read, never
persisted.

## Example
Gating a follow-up on an in-conversation choice: add
`{"accomplishment":"asked_x"}` to the choice that unlocks it, gate the
follow-up with `"requires":{"accomplishment":{"asked_x":1}}`, and
`"hide_when"` the asking option (so it stops re-offering) — exactly
`lyonette_tip.json`'s `hub`→`barmaid_retort`→`tip` shape.

## THE THIRD DASH FORM (audit find, 2026-07-11)
The dash lint greps `—` and `\u2014` — but new copy keeps arriving with
ASCII `--`, which renders as two literal hyphens through the plain
`Label` pipeline. Lint all THREE forms; normalize `--` to `—` in spoken
lines at delivery time, and hold the one-dash-per-line budget on NEW
copy in the same pass (the Invrisil wave shipped 8 multi-dash lines —
the discipline exists, apply it at authoring, not in audits). Also:
hub EXIT options must be per-character voice ("Just tea, then." /
"Just getting my bearings."), never the shared "Actually - one more
thing." template — 11 byte-identical copies shipped before this rule.

## Verification
`tests/test_content.gd` (cross-references every graph: gate ids, goto
targets, effect targets, softlock guard, every `gained_by`/quest
`complete_when` accomplishment is produced somewhere); `tests/test_dialogue.gd`
(pure unit behavior); canonical QA scripts `dialogue_walkthrough`,
`dialogue_hub_loop` (seed 9) — extend/add one asserting both the
domain event and `ui_dialogue_rendered`/`ui_dialogue_shown`. Canon voice
(names, register) comes from the Wandering Inn Wiki, never invented.

## Common mistakes
Combining `{"skill":...}` with `{"class":...}`/`{"accomplishment":...}` in
one dict (only the first-checked key is ever evaluated); letting an
accomplishment-gated option leak progress text instead of hiding it;
adding a vanishing option without a fully ungated exit; putting
`start_combat` on a non-ending option; forgetting a `goto` back-reference
on a hub follow-up, stranding the player.

## Cross-references
`wi-adding-a-class-or-skill` (class-keyed `requires` reads the same
`classes` dict), `wi-verifying-changes` (gates to run), `wi-art-and-sprites`
(dialogue panel rendering, if visuals are touched).

## SPOILER CUTOFF: Book 17 bar, Volume 7 advertised (user, 2026-07-07)
`docs/design/spoiler-cutoff.md` is BINDING on all content. TWO TIERS:
NEW content must not introduce anything entering the story after
**Book 17** (*Garden of Sanctuary*, Vol 7 Part 1); existing/planned
content as of 2026-07-07 (incl. Wilovan/Ratici in 8c) is grandfathered,
and the ADVERTISED cutoff is through Volume 7 to cover it. Every wiki
canon-check must also check WHEN the item enters the story (past the
Book-17 slice = fails for new content; ambiguous timing = treat as
past the cutoff or re-flag). Known trap already caught: the
portal-Skill name is Vol 9 — the game says "the Magical Door", never
that name.

## Character profiles are the writing contract (2026-07-06)
`docs/design/character-profiles.md` = single source of truth per
character (species/palette/silhouette + the 3 voice notes + canon
cites). Every dialogue/pool/observe/friendly line derives from the
profile; contradicting it is a defect (the Lyonette blonde-miss class).
New character → wiki-verify → ADD THE PROFILE FIRST, then write.

## Content-task brief header (adapted from Claude-Code-Game-Studios)
Every content brief states up front: (1) NARRATIVE PURPOSE — what beat
this serves; (2) emotional tone target; (3) lore dependencies (what
canon it touches) + new-canon flags. Cheap to write, keeps quest/
dialogue waves coherent at scale.

## Canon-consistency sweep (run at each content milestone's F-task)
Cross-surface drift check: for each character, grep ALL their surfaces
(dialogue files, talk_pool, observe/friendly_line strings, quest text)
and read against the profile — same voice notes, same facts, no
contradiction between surfaces (a pool line claiming X while a quest
line claims not-X). The registry-diff idea from
github.com/Donchitos/Claude-Code-Game-Studios, sized to our data files.

## Voice lint — the anti-AI-tell guard (user directive 2026-07-06)
Run on EVERY dialogue/lore/toast delivery (writer self-check + the
task reviewer's standing hunt), against the character's profile voice:
- BANNED TELLS: "a testament to", "cannot help but", "little did",
  "palpable", "unwavering", "the air was thick with", "a mix of X
  and Y", "eyes gleaming/glinting with", triadic flourishes ("X, Y,
  and Z" cadence stacking), rhetorical-question openers, over-named
  emotions ("she felt a surge of"), symmetrical sentence rhythm three
  lines running, em-dash chains, "somehow", needless "very own",
  and the ELABORATING em-dash continuation ("X — and Y that explains
  what X means", user-named 2026-07-07 on GDI copy: "This world
  watches what you do — and answers by making you someone" → cut at
  the dash; the bare statement is stronger. A dash continuation must
  add a NEW fact, never amplify/restate the clause before it).
- EM-DASH BUDGET (user playtest ruling 2026-07-07: "serially overused
  across dialogue"): at most ONE em-dash per line, and most lines need
  ZERO — reach for a period or comma first; a dash must earn its
  interruption (a real self-interruption or turn, not rhythm
  decoration). The corpus-wide reduction pass LANDED 2026-07-07 (155
  pairs + 28 earned keeps, staged in
  docs/archive/staging/emdash-reduction-staging.md); hold every NEW line to this
  bar. Label-separator dashes (keybind hints, `[Skill] — body` builders)
  are convention, EXEMPT from the budget.
- **Em-dashes hide as `—` escapes** (data/maps/** + some QA
  scripts mix literal and escaped in the SAME file): any corpus grep for
  dash abuse — or for a pinned string containing one — must sweep BOTH
  forms, or it silently misses sites (7 pin sites survived the staging
  sweep this way; they surfaced as wait-for-event TIMEOUTS, not string
  asserts, when the rendered text changed under them).
- POSITIVE BAR: lines survive being read ALOUD in the character's
  register; contractions where the voice has them; people interrupt
  themselves, use wrong-size words, reference concrete objects; humor
  is SPECIFIC (Relc jokes about spears and paperwork, not "jokes").
- Lore text: state facts a resident would know, in resident diction —
  never travel-brochure omniscience.
- The FULL VOICE PASS (chain step: after all content delivers) audits
  every player-facing string against this + profiles; guards reduce
  its findings, they don't replace it.

## Shipped-id freeze (issue #99, 2026-07-12)
Accomplishment counter ids, quest ids, item ids, and map keys that have
shipped in a public release (frozen in
`wandering_inn_game/data/shipped_ids.json`) are permanent API — never
rename or re-semanticize one (a shipped save may carry it forever). To
retire one: `WISave.DEPRECATED_IDS` in `src/core/save.gd` (deprecate-
and-map; `tests/test_shipped_ids.gd` enforces). New counters follow the
prefix conventions (`completed_bounty_<id>`, `chatted_with_<entity>`,
quest-beat verbs) — they freeze at the next release cut, so name them
right the FIRST time (wi-shipping deploy step 0).
