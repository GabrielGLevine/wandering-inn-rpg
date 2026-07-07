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
first key present — **never combine two gate types in one dict** — EXCEPT the ONE sanctioned
compound (Social II, 2026-07-07): `{gold, accomplishment}` on a shop-perk
buy option, where the accomplishment leg HIDES until met and the gold leg
greys-visible after (a broke player must never buy on credit; a pre-stage
player must never see the perk). `_meets` evaluates a compound as AND;
`_requirement_text` shows only the gold reason (correct: the
accomplishment case is hidden, never locked). `test_content.gd`'s
`_validate_requires` asserts one gate key OR exactly this pair — any
other combination fails content validation.

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
- **Em-dashes hide as `—` escapes** (skeleton_scene.json + some QA
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
