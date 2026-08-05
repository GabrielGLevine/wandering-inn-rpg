# Riverfarm NPC swap: The Hunter → The Shepherd (design)

Date: 2026-08-05. Status: SPEC — awaiting user review. No implementation yet.

## Problem

"The Hunter" in Riverfarm reads as a **Hunter of Noelictus** to a Wandering Inn
reader. Canon binds witches, Hunters, and Noelictus into one cluster, and this
NPC stands one map away from a witch quest (Witch Hollow / Eloise's craft) —
the worst possible neighborhood for the name. The v0.16.1 copy-only
disambiguation (map comment at `riverfarm_village.json` entity
`riverfarm_hunter`: "LOCAL GAME HUNTER, not a member of any order", trade
signal in observe + one appended talk line) did not resolve it. User ruling
2026-08-05: swap the character out altogether.

## Decision

Replace the character, keep the mechanical slot. **The Shepherd** — the
village shepherd whose lambs the thicket-thing took, who knows the treeline
because his flock grazes its margin, and who will walk you to the hollow
because the wolves are his problem before they are anyone else's.

All internal IDs stay. Only the player-visible surface (display name, sprite,
copy, voice card) changes.

### Why Shepherd wins

- The existing copy is already shepherd-coded: "Wolves took two lambs this
  spring. Lambs is my trade.", fences, herd roads, watering bends, the lamb
  pen, "Fences before deer." Most lines survive verbatim; the only lines that
  die are the ones v0.16.1 *added* to sell the hunting trade (game bag, wolf
  sign on boots, meat/pelts signal).
- The quest is a herd-behavior quest (corusdeer refusing a line; the humble
  answer is moving fences). A shepherd reading another species' herd is a
  tighter fit than a hunter tracking it.
- Wolf-night ally beat gets *stronger* motivation: a shepherd defends the
  field edge at night as his job description.
- Canon-safe: [Shepherd] is a mundane trade class with zero order association
  and fits a farming village. Within the Vol 7 / Book 17 content bar.
- Naming pattern holds: Riverfarm NPCs are unnamed archetypes (Former
  Headman, A Villager, The Witch) → "The Shepherd".

### Alternatives rejected

- **The Trapper** — still hunting-adjacent (a reader squinting at "Hunter"
  squints less but still squints), and a trapper does not own lambs: the lamb
  pen, "lambs is my trade", and the #330 beast-tamer pen loop all need
  re-justification. More copy churn, weaker fit.
- **The Field-Warden / hayward** — thematically elegant (a keeper of mundane
  boundaries meets a magical one) but "Warden" collides with the existing
  Warden character (v0.16 playtest bundle 09-the-warden) and with canon
  [Warden] usage. Trades one name confusion for another.

## Hard constraints (why IDs stay)

1. **Shipped-ids freeze** (`data/shipped_ids.json`, issue #99 contract):
   `hunter_will_come`, `survived_wolf_night`, `chatted_with_riverfarm_hunter`,
   `heard_thicket_keeps`, `thicket_answered`, `thicket_cleared`, etc. are
   permanent API. `WISave.DEPRECATED_IDS` migration is only wired for
   `classes` (`src/core/save.gd:7-17`); extending it to accomplishments for a
   cosmetic rename is unjustified risk.
2. **Save-carried entity keys**: `social_talked`, `entity_first_use`,
   `removed_entities`, ally references (`allies: ["riverfarm_hunter"]`) are
   keyed by entity id in live saves.
3. Therefore: `riverfarm_hunter` (entity, combatant, dialogue file/id),
   `hunters_lamb_pen`, and every accomplishment counter keep their names.
   Each carrier gets a one-line `_comment`: legacy id — character is The
   Shepherd (2026-08-05 swap, this spec).

## Surface changes, file by file

### `data/maps/riverfarm/riverfarm_village.json` — entity `riverfarm_hunter`
- `display_name` → `"The Shepherd"`. `sprite` → `"a_shepherd"` (new, below).
- `observe` rewrite: trade signal flips from game-hunting to shepherding.
  Direction: *"Tar-marked hands, a crook worn smooth, and wolf sign on his
  boots. The flock is penned; he is still watching the treeline."* (Final copy
  at implementation, voice bar below. Keeping "wolf sign" is fine — tracking
  wolves is flock defense, not the hunting trade.)
- `talk_pool` + 4 stages (`thread_hollow`, `thread_neutral`,
  `thicket_answered`, `lambs_tended`): copy pass. Lines that survive: hollow
  unease, "thorns for teeth", treeline-better-than-the-headman, witch
  keep-to-mine line, all three `thicket_answered` lines, all three
  `lambs_tended` lines. Lines that die: the v0.16.1 hunting-trade line and any
  "not walking that treeline for my health" phrasing that leans hunter —
  recast toward flock work.
- `dialogue` preview line ("Hollow's not safe alone.") survives.
- Entity `hunters_lamb_pen`: `display_name` → `"Shepherd's Lamb Pen"`;
  `observe` "fencing the hunter threw up" → "fencing the shepherd threw up".
  Id stays.
- Update the v0.16.1 disambiguation `_comment` to point at this spec.

### `data/dialogue/riverfarm_hunter.json`
- All `speaker` fields → `"The Shepherd"`.
- Copy pass, structure frozen: node ids, options order, `goto`/`end`,
  `requires`/`hide_when`/`effects` all unchanged (the hub's cursor-pinned
  canonical indices and the R2 re-entry row shape are load-bearing — see
  in-file comments).
- Line-level notes: hub text survives nearly verbatim (it was always a
  shepherd's speech). `thicket_topic` "Know that treeline better than the
  headman does" survives. `thicket_rerouted` narration "The hunter walks the
  new line twice before he trusts it." → "The shepherd walks…" — the pinned
  antithesis **"Fences before deer."** (`thicket_reported_rerouted`) survives
  exactly; it is *more* his line now. The father line survives.

### `data/combatants.json` — `riverfarm_hunter`
- `display_name` → `"The Shepherd"`. Stats, `power_level` 10.5, `weapon_die`,
  `ai`, `basic_swordwork` unchanged — no combat-balance drift, no sim re-gate.
  `_comment` gains the legacy-id note (flavor: a billhook is a sword the
  System doesn't argue with).

### `data/quests.json` — `what_the_thicket_keeps`
- Beat `resolve`: "Walk the line with the hunter…" → "…with the shepherd…".
- Beat `report`: "Tell the hunter what the thicket is keeping…" → "Tell the
  shepherd…". Title, counters, `complete_when_any` shape, resolution ladder
  and texts unchanged (resolution texts contain no "hunter").

### `data/leads.json` — `lead_thicket`
- "The hunter has been watching the treeline instead of the fields." →
  shepherd recast, e.g. "The shepherd watches the treeline more than his own
  flock." Gates unchanged.

### `data/maps/riverfarm/witch_hollow.json`
- No data changes (ally references are by id). Two `_comment`s mentioning the
  hunter's come-along get the legacy note in passing.

### New sprite `a_shepherd`
- **Distinct-silhouette rule applies** (2026-08-02 ruling: tint is not
  disambiguation). Must read *shepherd* at a glance: crook in hand, brimmed
  hat or hood, no bow/quiver/game bag. Distinct from Former Headman and
  A Villager silhouettes.
- PixelLab generation per wi-art-and-sprites flow; same sheet contract as
  `a_hunter` (Idle_Down/Side/Up + Run_Down/Side/Up sheets under
  `assets/sprites/a_shepherd/`), `sprites.json` block mirrors `a_hunter`'s
  frame counts/anchor. `assets_manifest.json` + ATTRIBUTION entries.
- `a_hunter` sprite assets stay in-repo (unused after swap; removal is a
  separate cleanup decision — cheap to keep, and other regions may want a
  true hunter someday, *away from witch country*).

## Voice

- Bar: T1 rural (voice bible) — avg ≤8 words/sentence, no subordinate
  clauses, self-repeat + dropped agreement, respect in work terms.
- Pinned antithesis "Fences before deer." keeps its slot and exclusivity.
- `docs/dialogue-voice-cards/riverfarm-hunter+bark.md` → superseded by a new
  card `riverfarm-shepherd+bark.md`: same bans/forced stats, CANON-VOICE
  recast ("Riverfarm shepherd, flock loss on his mind before mystery…").
- Voice-pass baselines (`docs/dialogue-voice/baseline/riverfarm_hunter.json`,
  `baseline-maps/riverfarm_village.json`) regenerate via the voice-pass
  tooling after the copy lands; historical w3–w5 reports untouched.

## QA impact (measured, not guessed)

- **Exactly 5 pinned `"The Hunter"` speaker payloads** re-pin:
  `riverfarm_fight.json` (1), `thicket_keeps_talk.json` (2),
  `thicket_keeps_skill.json` (1), `thicket_keeps_fight.json` (1) — plus any
  pinned *text* payloads whose lines change in the copy pass.
- Fixtures (`riverfarm_*_start`, `thicket_*_start`) carry accomplishment ids
  only — unchanged. `sim_combat_batch.gd` references ids only — unchanged; no
  sim re-gate (stats untouched).
- `gh330_lamb_pen_loop.json` windowed shot 00 (eye-gate: pen beside the
  NPC) re-taken with the new sprite.
- `test_sprite_registry.gd`: add `a_shepherd` coverage.
- Full bar per wi-verifying-changes; wi-machine-playtest pass (player-facing
  sprite + copy surface) before close; VISUAL-LOG entry for the sprite
  eye-gate; CHOICE-LOG entry for the swap decision.

## Acceptance criteria

1. Grep gate: no player-visible string in the Riverfarm region renders
   "Hunter"/"hunter" for this character — display names, talk pools, dialogue
   text, observes, quest beats, leads, toasts. Internal ids and `_comment`s
   exempt; Gnoll hunt-camp "hunters" (rags_camp, lowercase trade usage) and
   `hunters_fang_talisman` item family (Silverfang, unrelated) explicitly out
   of scope.
2. All riverfarm/thicket QA scripts green after re-pin; no other script
   touched.
3. Old saves load clean: come-along, wolf night, thicket routes, lamb-pen
   loop all resume mid-quest with the new surface (ids identical, so state
   carries; verify with the v0.16 playtest-save bundle).
4. Eye-gate: shepherd reads as shepherd at gameplay zoom, silhouette distinct
   from every other Riverfarm villager.

## Non-goals

- No quest-logic, gating, counter, or balance changes anywhere.
- No id renames; no DEPRECATED_IDS extension.
- No touch to witch/headman dialogue (no cross-references exist — verified).
- No decision on deleting `a_hunter` assets.
