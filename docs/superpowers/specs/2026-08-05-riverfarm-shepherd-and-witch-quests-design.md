# Riverfarm redesign: A Shepherd, A Winter of Teeth, and Eloise's craft quest (design)

Date: 2026-08-05. Status: SPEC — awaiting user review. No implementation yet.
Supersedes `2026-08-05-riverfarm-shepherd-swap-design.md` (the surface-swap
baseline). Constraint analysis from that spec carries forward; where the two
disagree, this spec wins.

## User rulings (2026-08-05, all in one session)

1. "The Hunter" reads as a Hunter of Noelictus beside witch content; the
   v0.16.1 copy-only disambiguation failed. Swap the character out.
2. Replace the quest too — "A Winter of Teeth" chosen over reskinning
   "What the Thicket Keeps" and over a drover/social alternative.
3. Untie the new quest from the witch chain (offer at first talk).
4. Don't inherit the ally role just because the Hunter had it — briar-fight
   escort dies; wolf-night watch stays.
5. Naming: the Hunter was the region's only definite-article NPC and it made
   him read overly significant. Pattern is named-if-significant (Eloise),
   descriptive-indefinite for commoners (A Villager, Former Headman). New NPC
   is **"A Shepherd"**.
6. The witch class deserves quest weight: Eloise teaches [Hedge Witch]
   through a quest, not a single dialogue option.
7. General (memory-logged): three-pillars balance is game-level, not
   per-quest. Single quests may lean combat or social; audit the region mix.

## Hard constraints (unchanged from superseded spec)

- **Shipped-ids freeze** (`data/shipped_ids.json`, issue #99): every shipped
  counter is permanent API — `hunter_will_come`, `survived_wolf_night`,
  `heard_thicket_keeps`, `thicket_answered`, `thicket_cleared`,
  `witch_lessons`, `witch_craft_used`, `tended_beasts`, all `fought_*`.
  `WISave.DEPRECATED_IDS` migration is wired for classes only
  (`src/core/save.gd:7-17`). Nothing gets renamed or re-semanticized;
  retirement means gating producers, never deleting counters or quest defs.
- **Save-carried entity keys**: `riverfarm_hunter` (entity, combatant,
  dialogue file), `hunters_lamb_pen` keep their ids. Each carrier gets a
  one-line `_comment`: legacy id — character is A Shepherd (this spec).
- **Distinct-silhouette rule** (2026-08-02): new sprite must read shepherd at
  a glance; tint variants are not disambiguation.
- **Voice**: T1 rural bar (voice bible) for all new/edited copy.
- **Spoiler bar**: everything here sits at Vol 6 or below (witch craft rules
  cited 6.41 already live in `classes.json`); well under the Book 17 bar.

## Region shape after this spec

| Quest | Giver | Lean | Chain |
|---|---|---|---|
| The Price of a Favor (anchor, Act V terminal) | Former Headman / Eloise | social | root |
| The Flood Ledger | Former Headman | investigation | root |
| **A Winter of Teeth** (new) | A Shepherd | combat | **untied** |
| **Eloise's craft quest** (new) | Eloise | exploration/care | off anchor's peaceful path |
| What the Thicket Keeps | (retired for new saves; completable on legacy saves) | — | legacy only |
| Standing bounty: thicket watch | board | combat (renewable) | unchanged |

Region-level pillar mix balances per ruling 7; no per-quest route quotas.

---

## Workstream A — character swap: The Hunter → A Shepherd

As in the superseded spec, with two corrections:

- `display_name` is **"A Shepherd"** everywhere it renders: map entity,
  `combatants.json` (combat log reads "A Shepherd hits…" — verified the
  entry is otherwise surface-clean: `basic_swordwork` is a silent passive
  folded into `hit_bonus` at setup, `wi_combat.gd:140-149`; stats/die/ai
  generic; only name+sprite are player-visible).
- `hunters_lamb_pen.display_name` → **"A Lamb Pen"**; observe carries
  ownership ("fencing the shepherd threw up…").

Everything else holds: new `a_shepherd` sprite (crook, brimmed hat, no
bow/quiver/game bag; PixelLab per wi-art-and-sprites; sheet contract mirrors
`a_hunter`; `a_hunter` assets stay in-repo, removal deferred), observe/talk
pool/dialogue copy pass toward flock work, combatant stats untouched (no sim
re-gate from the swap itself), voice card recut as
`riverfarm-shepherd+bark.md`, baselines regenerated.

Talk-pool notes beyond the old spec: the corusdeer/treeline lines recast as
background lore (the herd mystery no longer carries a quest for new saves);
the "Nobody walks you there. Nobody local, anyway." line is now *true* (see
Workstream C) and stays.

## Workstream B — quest replacement: A Winter of Teeth

### Fiction

Wolf sign thickening toward the hollow, week by week. Two lambs in spring,
three now, and first snow coming. The pack is pushing in because something
took their old ground — the shepherd doesn't know that; the TRACK route
finds it.

### Structure (new quest id: `a_winter_of_teeth`)

- **Offer**: hub row in `riverfarm_hunter.json` at first talk — no
  prerequisite (ruling 3). Banks `heard_winter_teeth` (new), starts quest.
  New `lead_winter` in `leads.json` (no `requires`, `hide_when
  heard_winter_teeth`).
- **Beat 1 — resolve** (`complete_when_any`, flood-ledger idiom):
  - **FIGHT — stand the night watch.** The existing `river_wolf_pack` night
    encounter, fought beside the shepherd. Route counter is
    `survived_wolf_night` (frozen, semantics identical — the encounter
    already banks it via `on_victory`; encounter data untouched).
    *Pre-bank guard*: a new save can fight wolf night before ever talking to
    the shepherd. The offer row gets a pre-banked variant ("You stood a
    watch before I asked…") so accept-then-instant-resolve reads
    intentional, not the New-quest/Quest-complete toast defect. If the
    machine playtest still reads it as a glitch, fallback is a minted
    `watch_stood` counter banked by a post-fight dialogue row — decided at
    implementation, logged either way.
  - **WORK — rebuild the fold.** Interaction at the lamb pen, gated
    `requires heard_winter_teeth`, banks `fold_rebuilt` (new). Coexists with
    the #330 [Beast Tamer] tend loop; separate interaction row, `tended_beasts`
    untouched.
  - **TRACK — trace the pack's push.** Skill/exploration interaction at the
    field edge (gated on the quest), banks `pack_traced` (new). Copy reveals
    the displacement: the wolves' old denning ground is on the ward line.
    Points at the existing den fight (`thicket_line_den`) and hut/ward-scrap
    as optional deepeners — `ward_scrap_read` still must never bank
    `detected_wardwork` (trapped_halls protection, standing rule).
- **Beat 2 — report**: tell the shepherd at the pen; banks `winter_answered`
  (new) via report rows in dialogue (one per route, tallyman shape — same
  guard patterns the current file documents in its `_comment`s).
- **Resolution ladder** (weakest claim first): `survived_wolf_night` <
  `fold_rebuilt` < `pack_traced` — one night's wolves buy a night; hurdles
  buy a winter; knowing why they push is the answer.

New counters minted: `heard_winter_teeth`, `fold_rebuilt`, `pack_traced`,
`winter_answered` (+ `watch_stood` only if the fallback fires).
`shipped_ids.json` regenerates at next release cut, per contract.

### Retiring What the Thicket Keeps

- Quest def **stays** in `quests.json` (legacy saves mid-quest finish it;
  counters honored forever). `_comment` marks it retired-for-new-saves.
- The hub **offer row** ("The deer stopped at the treeline. Why?") is
  deleted; the re-entry row and all three report rows already gate on
  `heard_thicket_keeps` and keep working for legacy saves.
- `lead_thicket` row deleted (leads are UI hints, not save state).
- Known edge cohort: legacy saves that banked `price_of_a_favor_reported`
  but never asked about the deer lose the old offer and get the new quest
  instead. Accepted, CHOICE-LOG entry.
- All thicket world content survives unquested: den fight, hut + ward scrap,
  renewable remnant cull, standing thicket-watch bounty. The TRACK route
  re-points players at it.
- Voice-card cost: the pinned antithesis "Fences before deer."
  (`thicket_reported_rerouted`) survives only in legacy nodes. The new
  quest's copy needs its own single landed peak; the recut voice card
  assigns it (candidate slot: the report node of the TRACK route).

## Workstream C — ally rework + briar re-gate

- **Briar fights lose the ally.** Remove `allies`/`ally_requires` from
  `briar_collectors` and `briar_collectors_deep` in `witch_hollow.json`.
  Fiction already agrees ("Nobody walks you there. Nobody local, anyway.").
- **Wolf night keeps the ally, re-anchored.** The come-along dialogue beat
  becomes "stand the watch with me tonight" — the FIGHT route of his own
  quest, on his own fields. It banks `hunter_will_come` (frozen; semantics
  preserved: this NPC will fight beside you). `river_wolf_pack`'s
  `ally_requires {hunter_will_come: 1}` is untouched, so legacy saves that
  already banked it keep their wolf-night ally with zero data movement.
- **Sim re-gate (the real cost).** The gated design cells for both briar
  fights are with-ally: `briar_collectors_t3_warrior10_hunter` (0.55–0.95)
  and `briar_collectors_deep_t3_warrior10_hunter` (0.78–0.92)
  (`sim_combat_batch.gd:207,230`). Solo cells exist but are ungated. Plan:
  1. Run the batch; read solo win rates at `warrior5_mage5` and
     `t3_warrior10`.
  2. Move the gates to the solo cells with envelopes set from measurement.
  3. If `briar_collectors_deep` solo is unwinnable-in-practice at the w10
     design point, retune the deep pair downward — it banks `blight_lifted`
     on the anchor quest's fight route, which must stay viable solo. A
     harder-than-before fight route is acceptable (ruling 7); a
     practically-closed one is not.
  4. Delete the `_hunter` briar sim cells — the map no longer fields an
     ally there for any cohort, so with-ally cells model nothing. Solo cells
     stay and take the gates. Wolf-night ally cells unaffected.
- Legacy-save impact: mid-anchor-quest saves that banked the come-along
  lose briar help; the fight gets harder but stays sim-gated viable.
  CHOICE-LOG entry.

## Workstream D — Eloise's craft quest (new quest id: `the_makings`)

### Why

[Hedge Witch] is currently granted by one dialogue row (peaceful-path gated)
→ `witch_lessons`. A class entry point deserves quest weight (ruling 6), and
canon rule already in `classes.json`: a witch IS her craft — so the quest is
*doing* craft, not hearing about it.

### Structure

- **Offer**: the existing hub row "The way you work — the craft. Could a
  person learn it?" keeps its gate exactly (`requires blight_lifted`,
  `hide_when drove_off_collectors` — the ratified peaceful-OR path) but now
  starts the quest (banks `heard_the_makings`, new) instead of walking
  straight into the lesson.
- **Beats** (sequential, each a small proving task on existing surfaces;
  exact interactions at implementation):
  1. **Gather** — bring her the makings (forage interaction in the hollow /
     fields; banks `makings_brought`, new). Exploration.
  2. **Tend** — care with feeling behind it: a quest-gated tend interaction
     at the lamb pen (banks `craft_tended`, new — does NOT reuse
     `tended_beasts`, which stays #330's counter; separate row, same prop).
     Quiet cross-link: the witch's pupil tending the shepherd's lambs.
     Care/social.
  3. **Sit the kettle** — hearth interaction at her hut, then the existing
     `witch_lesson` conversation node closes the quest; its teach option
     stays the single place `witch_lessons` banks (frozen counter, same
     semantics, now quest-terminal).
- **Class data untouched**: `hedge_witch.gained_by {witch_lessons: 1}`,
  `witch_craft_used` curve, [Witch] evolution all as-is.
- Legacy saves with `witch_lessons` already banked: unaffected (offer row
  can additionally `hide_when witch_lessons` — it effectively already does,
  per the existing bank-option comment at `riverfarm_witch.json:377`).
- Legacy saves sitting at the gate un-asked simply get the quest — no
  cohort loss here.

New counters: `heard_the_makings`, `makings_brought`, `craft_tended`.

## QA impact

- **Winter of Teeth**: new QA scripts per route (talk/work/fight idioms per
  wi-writing-qa-scripts), fixture with a fresh save at the shepherd.
- **Thicket legacy**: existing `thicket_keeps_{talk,skill,fight}` scripts
  re-anchored to a legacy fixture (pre-banked `heard_thicket_keeps` +
  `price_of_a_favor_reported`) proving the retired quest still completes;
  their 4 pinned "The Hunter" speaker payloads re-pin to "A Shepherd".
- **riverfarm_fight.json**: come-along beat re-pins (new watch-ask copy);
  its briar legs re-shape to solo (ally assertions removed); 1 speaker
  payload re-pins.
- **Eloise quest**: new script walking offer → three beats → lesson →
  [Hedge Witch] grant; existing witch scripts (crate/price flows) unaffected
  except any pinned hub option-index payloads — the hub gains no reordering
  (quest-start replaces the goto on an existing row; appended rows go last,
  cursor-pin rule).
- **Sim**: briar solo re-gate per Workstream C; wolf-night and thicket cells
  untouched; shepherd combatant identical so no ally-side drift.
- **Sprite**: `test_sprite_registry.gd` coverage for `a_shepherd`;
  `gh330_lamb_pen_loop` shot 00 re-taken.
- **Machine playtest** (wi-machine-playtest) before close — new copy, new
  sprite, new toasts all player-facing. Eye-gate playtest states shipped
  with prepared saves (playtest-states pattern): (1) shepherd in village,
  (2) wolf-night watch with ally, (3) Eloise beat 2 mid-quest.
- Full unit bar + pin-sync per wi-verifying-changes (prose edits are
  QA-coupled since the voice pass).

## Acceptance criteria

1. Grep gate: no player-visible string in Riverfarm renders "Hunter" for
   this character (ids/`_comment`s exempt; Silverfang talisman items and
   Gnoll hunt-camp lowercase "hunters" out of scope).
2. New save: Winter of Teeth offered at first shepherd talk with no witch
   progress; all three routes complete and report; wolf-night pre-bank
   cohort reads intentional. Thicket quest unobtainable.
3. Legacy save (v0.16 bundle): mid-thicket quest completes; briar fights
   winnable solo; wolf-night ally still fields off banked `hunter_will_come`.
4. New save, peaceful witch path: craft quest offered, three beats, lesson
   banks `witch_lessons`, [Hedge Witch] grants exactly as before. Fight-path
   saves (`drove_off_collectors`) still never see the offer.
5. Briar solo sim gates green with measured envelopes; anchor fight route
   viable at design builds.
6. Eye-gates: shepherd silhouette distinct at gameplay zoom; the three
   playtest states read right.
7. No act/main-line drift: `riverfarm_owed` untouched (verified: thicket
   quest was never act-gated).

## Sequencing and lanes (file ownership up front)

- **Lane 0 (parallel, no repo contention): sprite.** PixelLab `a_shepherd`
  generation + `sprites.json`/manifest/ATTRIBUTION.
- **Lane 1: shepherd + Winter of Teeth.** Owns
  `maps/riverfarm/riverfarm_village.json`, `dialogue/riverfarm_hunter.json`,
  `leads.json`, its QA scripts.
- **Lane 2: ally rework + sims.** Owns `maps/riverfarm/witch_hollow.json`,
  `tests/sim_combat_batch.gd`, retune (if any) in `combatants.json`.
- **Lane 3: Eloise quest.** Owns `dialogue/riverfarm_witch.json`, its QA.
- **`quests.json` is shared** (lanes 1 and 3 both add a quest): integrator
  applies both quest blocks in one commit, or lanes hand patches to the
  controller. Decide at plan time; never two lanes writing it live.
- Voice cards + baselines regenerate once, after all copy lands.

## Non-goals

- No id renames, no `DEPRECATED_IDS` extension, no engine changes.
- No touch to thicket world content (den, hut, cull, bounty) beyond the
  TRACK route pointing at it.
- No change to witch class curve, evolution, or `witch_craft_used` economy.
- No decision on deleting `a_hunter` assets.
- Headman quests untouched.
