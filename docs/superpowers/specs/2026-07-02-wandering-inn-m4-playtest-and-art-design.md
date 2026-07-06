# M4 Design — Playtest Fixes + Asset Integration

**Status:** spec written under standing delegation (same convention as M3: design calls I made are marked **[D]**; product-level surprises are PARKED with options, not decided). User priority order honored: 1) playtest-feedback fixes, 2) asset integration, 3) action-driven classes — item 3 is **deferred to M5** because its vision doc explicitly forbids resolving its open design questions without the user (`2026-07-02-progression-vision-action-driven-classes.md` §Open design questions); it needs an interactive brainstorm, not a delegated one.

**Inputs:** HANDOFF.md "Human playtest results (2026-07-02)" (findings 1–10, user directives), `2026-07-02-wandering-inn-asset-design.md`, the **newly purchased Pixel Crawler full pack** (10 environment packs + 2 bat packs + Free Pack 2.1, unzipped in `potential_assets/` this session — inventory below), M3 deferred minors.

---

## 0. New-asset inventory delta (2026-07-02, full-pack purchase)

The asset doc was written against the Free Pack only. The purchase adds:

| Pack | Contents relevant to us |
|---|---|
| Cave | **cave tileset (directly solves `cave_mouth` arena env)**, Fungus enemies ×3, spore weapons |
| Hideout | Bandit ("Baldits") enemies ×4 — human raider silhouettes, Idle/Run/**Hit**/Death |
| Sewer | Rat enemies ×3 |
| Desert | Mummy enemies ×3, desert tiles |
| Fairy Forest | Elf enemies ×4, forest tiles |
| Cemetery | Zombie enemies ×4, A_Hunter character |
| Castle / Forge / Garden / Library | Royal Crew / Stone golems / Medusa + villager bodies / Scholars + matching tilesets |
| Bat_Fur, Small_Bat | **the only 4-directional mobs** (Idle/Move/Hit/Death × Down/Side/Up) |
| Free Pack 2.1 | newer rev of the extracted free pack — treat 2.1 as canonical when extracting |

Every pack ships the same Terms.txt (commercial use OK, alteration OK, no resale of assets). Pack enemies are single-facing (mirror-only) but — unlike the old free-pack mobs — **include Hit animations**, so hurt feedback no longer needs a tint hack for them.

**PARKED (product surprise): the canon combat-sprite gap is NOT closed by the purchase.** Zero goblin, spider, or drake/lizardfolk sprites exist in any pack (full-tree search). Options for the user, in rough preference order: (a) source a goblin/spider/drakonid pack externally (CraftPix/Sanctumpixel per asset doc §4 — needs license verification and possibly money); (b) accept a same-author stand-in (Hideout Bandits *read* as raiders; asset doc recommends against Orc-as-Goblin mislabels and I agree — canon rule); (c) ship M4 with styled placeholders for gapped combatants (what this spec does) and revisit. M4 proceeds with (c) so nothing blocks; swapping sprites later is a data-only registry edit by design.

---

## 1. Goals / non-goals

**Goals**
1. Every user directive from the 2026-07-02 playtest (findings 2–9) fixed and QA-pinned; a `defeat_reload` QA script covering the hotfixed finding 1.
2. Real art on screen: tile-rendered maps + arenas, sprite-rendered PC/NPCs/props, sprite-rendered PC in combat, animated where in-hand assets allow — inside the existing data→codegen architecture (no hand-authored scenes).
3. Combat readable: paced AI-turn playback, complete affordability greying, no text overlap.

**Non-goals**
- Action-driven classes (M5, interactive brainstorm required).
- External asset sourcing/purchases and the goblin/Relc/spider likeness problem (PARKED above).
- Custom spell VFX beyond cheap in-hand effects (parked with sourcing).
- Portrait busts from Tiny RPG packs (license still unverified — stays excluded).

---

## 2. Design — Phase A: playtest fixes (logic first, rendering-independent)

### 2.1 Dialogue gating visibility split (finding 3, user policy)
`WIDialogue.visible_options` currently treats all unmet `requires` as visible-locked grey rows. Split by requirement key:
- `accomplishment` / `quest` requirements unmet → **option hidden** (progress-gated content must not leak).
- `skill` / `class` requirements unmet → **visible-locked** (the tease is deliberate).
A `requires` dict mixing both kinds: hidden wins (progress secrecy dominates). Locked-label rendering (`requires …`) survives only for the visible-locked kind.

### 2.2 ctx refresh **[D]**
`_ctx` is snapshotted at `start_dialogue`, so hub loops can't react to mid-conversation effects. **[D] decision: refresh ctx per node visit** — `WIGame.dialogue_choose` passes a fresh ctx into the dialogue instance before computing the next node's visible options. This closes the documented-staleness bug class outright and is required for 2.3/2.4 to behave. Purity unaffected (ctx is still an injected snapshot, just re-injected per step). The M2 "snapshot at start" comment/docs get updated.

### 2.3 Decision-invalidated options disappear (finding 4)
Extend `hide_when` across the M2/M3 graphs: options invalidated by a committed decision (e.g. Erin's two quest responses after committing, Selys's keep/return pair after choosing) get `hide_when` on the deciding accomplishment. Content-only task once 2.2 lands.

### 2.4 Dialogue hubs / backtracking (finding 9)
Author "I have more questions." loop-backs (`goto` back to hub) across Erin/Selys/Lyonette graphs so conversations stop being one-shot. Depends on 2.1+2.2 so hub re-entry re-evaluates gating correctly. Engine already supports `goto` loops — this is graph authoring plus the ctx fix.

### 2.5 [Basic Cleaning] via the Dirty Table prop (finding 2, user directive)
Erin's hub option 2 currently grants `cleaned_the_inn` inline and jumps to the congratulation node. Change: the option keeps the `skill: basic_cleaning` gate but only *directs* ("I'll get to it") with **no accomplishment effect**; the `dirty_table` prop (already in `skeleton_scene.json`) becomes interactable exactly like `dusty_scroll` — interacting with [Basic Cleaning] held grants `cleaned_the_inn` + toast. Erin's congratulation node becomes reachable from the hub via a `requires {accomplishment: cleaned_the_inn}` option (visible only after the deed, per 2.1 it's hidden before). QA: extend `dialogue_walkthrough` (or quest script) to walk option → prop → return-to-Erin.

### 2.6 Save/load discoverability (finding 8)
- Persistent hint in the message layer on map screens: `Esc — menu (save/load)   J — journal` **[D]: always-visible one-line footer hint rather than a first-run-only toast** (cheap, can't be missed, no "did the player see it" state to save).
- First autosave per session also emits a feed line "Autosaved." so the save system announces its existence.
Save/load remains queued for the next human playtest.

### 2.7 `defeat_reload` QA script (finding 1 regression guard)
The hotfix `a9b4dc2` (defeat → load `auto` slot) has no QA coverage because autoplay always plays winning seeds. **[D]: use a natural losing seed** — fighter-only vs `chieftains_raid` wins 0.61 of seeds, so losing seeds exist; search one (same technique as the T8 seed searches), no test-only forced-loss hooks. Script: sleep (autosave) → enter `chieftains_raid` → `combat_autoplay` at the losing seed → assert defeat banner → assert post-banner state equals the autosave (marker accomplishment present pre-fight, absent state changes post-fight rolled back). Pin the seed in the canonical table.

### 2.8 Combat affordability greying completion (finding 6)
`_skill_affordable` greying already covers skills/Dash; extend the same convention to **Attack** (AP < 2) and **Move** (move_pool 0 AND no AP to dash — i.e. no legal movement). Confirm-refusal stays consistent with the existing unaffordable-row behavior.

---

## 3. Design — Phase B: asset integration (data→codegen, per asset doc §5 as amended)

### 3.1 Sprite registry + cell unification (plumbing, no art)
- Combat `CELL` 48 → **64** to match field + native asset size (asset doc §5.1). Verify QA windowed capture handles 768×512 board.
- `assets/` directory in the project gains the *curated, license-clean* PNG extracts (only what we use — never the whole `potential_assets/` tree; that stays gitignored. Extracted PNGs shipped in-game are permitted by Terms.txt "functional use"). **[D]: committed curated extracts are fine; redistribution clause forbids reselling the pack, not shipping sprites in a game.**
- A sprite registry (`data/sprites.json` + a small loader) maps `sprite_id → {sheet(s), frame size, animations, directional?}`, mirroring the `skills.json` catalog-by-id pattern. `skeleton_scene.json` entities, `combatants.json`, and `arenas.json` gain optional `sprite` fields. **No `sprite` field → current ColorRect placeholder** (graceful fallback is the gapped-combatant strategy).
- Frames sliced per-animation, not fixed-grid (Idle 32×32 vs Run 64×64 canvases — asset doc §1.3).

### 3.2 Environment codegen
`world.gd _build_floor()` and the combat arena floor emit `TileMapLayer` cells from data instead of ColorRects. Schema: per-map `tiles` block (floor/wall tile ids per cell or a compact biome + overrides form — plan decides the encoding) in `skeleton_scene.json` / `arenas.json`. Inn interior + Liscor street from Free Pack 2.1 tilesets; `cave_mouth` from the Cave pack; `goblin_ambush` street dirt/cobble. Props (beds/tables/bar) render via the entities array's existing `prop` kind + new `sprite` field. Tavern_02 mockup is the inn's layout reference.

### 3.3 Field sprites
PC = Body_A (full directional walk). Erin/Lyonette/Selys = Citizen_F + **[D] programmatic palette-swap recolors** (scripted PNG hue/palette shifts committed as generated variants — no Aseprite-by-hand dependency; Terms.txt allows alteration). Garden pack's villager bodies (Feminine/Masculine/Old) get evaluated in-plan as additional distinct NPC bodies before falling back to recolors-only. Props: dusty scroll (Esoteric sheet), dirty table (furniture sheet), doors.

### 3.4 Combat sprites
- PC: Body_A full set (Idle/Slice/Pierce/Hit/Death) wired to combat events.
- Relc, goblins ×3, Cave Spider: **styled placeholders** (current chips + name), awaiting the PARKED sourcing decision. Registry design makes the future swap data-only.
- Enemy hurt/death feedback for sprite-backed units uses their Hit/Death sheets; chip units keep the existing flash.
- Spell visuals **[D]: minimal in-hand pass** — Frost Bolt/Flame Jet get simple traveling/line color effects + screen-readable feed lines (already exist); Bonfire fire loop optionally cannibalized for Flame Jet. Real VFX parked with sourcing.

### 3.5 QA impact (asset doc §5.5)
Event/snapshot assertions unaffected. Windowed screenshots change wholesale → **one-time recapture** of all baselines at the end of Phase C, flagged in HANDOFF so nobody diffs new against stale. Add `ui_*_rendered` confirmations for tile/sprite rendering (e.g. `ui_map_rendered {tiles: N, sprites: M}`) so headless QA can assert art actually rendered without reading pixels.

---

## 4. Design — Phase C: combat presentation

### 4.1 Paced AI-turn playback (finding 5 — biggest presentation item)
Sim stays synchronous/pure (resolves the whole AI turn instantly, events flow to the bus). The **presentation layer queues bus events during WAIT_AI and plays them back paced**: per-beat delay (~0.5s **[D]**, constant pinned in one place), highlighting the acting unit, showing its action (sprite anim where available, feed line + flash otherwise) before the next beat. Any key skips to instant-complete. Under `--qa-script` the delay is 0 (headless scripts unchanged; `ui_*_rendered` confirmations still fire in order). This is a render-queue change in `combat_screen.gd` only — no sim or TestDriver semantics change.

### 4.2 Layout / overlap pass (finding 7 + M3 deferred minor)
After sprites land (so we polish the final look once): fix enemy-label collision with the action menu (labels clamp/flip side at x≥9), audit every screen at default window size for overlap (dialogue panel, journal, toasts, combat feed/menu/labels), prefer containers over manual offsets per `godot-ui` conventions. Exit bar: windowed screenshots of every screen show zero overlapping text.

---

## 5. Task sketch (plan will finalize)

Phase A: T1 gating split + ctx refresh; T2 dirty-table cleaning rewire; T3 hide_when sweep + dialogue hubs; T4 defeat_reload script + save/load discoverability; T5 affordability greying (small — may merge into T4).
Phase B: T6 sprite registry + 64px + asset extraction; T7 environment tile codegen; T8 field sprites + recolors; T9 combat PC sprite + minimal spell visuals.
Phase C: T10 paced AI playback; T11 overlap/layout pass + full screenshot recapture + docs.
Final: mandatory Opus whole-branch review + fix wave.

Combat-data note: none of this changes combat *rules* or data, so canonical seeds should hold; T4's new losing seed is additive. Any task that does touch combat data re-verifies the seed table.

## 6. [D] register (delegated calls for user review)

1. Action-driven classes deferred to M5 (vision doc forbids delegated resolution).
2. ctx refreshed per node visit (kills documented staleness; enables hubs).
3. Mixed-kind `requires` → hidden wins.
4. Always-visible footer hint for menu/journal discoverability.
5. `defeat_reload` via natural losing seed, no forced-loss hooks.
6. Gapped combatants stay styled placeholders (no orc-as-goblin mislabel); swap is data-only later.
7. Curated sprite extracts committed to the repo (license permits functional use; `potential_assets/` itself stays gitignored).
8. Programmatic palette-swap recolors for NPC differentiation.
9. AI playback beat ~0.5s, skippable, 0 under QA.
10. Combat CELL 48→64.
11. Minimal in-hand spell visuals this milestone.

## 7. Parked for the user (not decided)

1. **Goblin/Relc/Cave-Spider sprite sourcing** (§0) — buy/verify external pack vs stand-in vs keep placeholders.
2. Spell VFX sourcing (BDragon1727/Pimen per asset doc §4.6) — same trip.
3. Tiny RPG portrait-bust idea — still license-blocked.
4. Epilogue spoiler surface in dialogue data (carried from M2) — policy when content grows.
