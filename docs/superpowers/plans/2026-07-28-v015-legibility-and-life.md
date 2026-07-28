# v0.15 Legibility & Life Implementation Plan

> Status: **ACTIVE**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the narrative delivery layer (journal openings, leads, durable lore), the population pass, and the readability debt from the adversarial playtest — no new story.

**Architecture:** Data-first Godot 4.7. Five PR phases per the spec's delivery shape; SDD execution with per-task reviews; merge-train + counter-grep + census protocols per the v0.14 ledger (they are assumed by every task). Spec: docs/design/2026-07-28-v0.15-legibility-and-life-spec.md (authority; its four user rulings + never-blocked CHOICE-LOG discipline bind everything).

**Tech Stack:** JSON data + GDScript sim/UI; QA canonicals; sim_combat_batch bands; PixelLab MCP for any rig rebuild.

## Global Constraints

- NEVER user-block: every design fork decided in-wave, logged to docs/CHOICE-LOG.md (call, alternatives, why, revert path). Taste items → Playtest-State asks at wave close.
- Test runner alarm-wrapped (`perl -e 'alarm 240; exec @ARGV' --`); pristine output; test_content is fail-loud now — trust rc.
- Census margin ~0.5pt: pointers, not paragraphs; `python3 scripts/comment_census.py --check` in every phase gate.
- Live tripwires that MUST stay green: carrier-vs-row audit (test_portals), resolution-order guard (test_quests), address-token placement lint (test_content), talk_pool post-pool lint, fixture-coherence chains.
- Copy bars: Book-17; "the Magical Door"; `{addr}`/`{Addr}` for PC address; no unearned outcome text ever renders (A1's core rule); openings pose questions, never answers.
- New counters/save fields named at first write; freeze at next tag; save-schema changes follow the WISave VERSION+migration pattern (save.gd), migration composes.
- Skills per surface: wi-adding-dialogue-and-quests, wi-adding-a-scene, wi-adding-an-encounter, wi-writing-qa-scripts, wi-verifying-changes, wi-machine-playtest at phase closes.
- Commit trailer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. Branch per phase (`wave/v015-p<N>-<slug>`), PR base main, merge-train protocol.

---

## Phase 1 — Lane A core: openings, leads, durable lore (branch `wave/v015-p1-delivery`)

### Task 1.1: Pending-beat openings (spec A1)

**Files:**
- Modify: `wandering_inn_game/data/acts.json` (all 18 beats gain `opening`)
- Modify: `wandering_inn_game/src/ui/journal.gd:636-641` (pending render path)
- Modify: `wandering_inn_game/src/core/acts.gd` (expose opening in derived beats if the journal reads through it — read first)
- Test: `wandering_inn_game/tests/test_acts.gd`, `tests/test_content.gd`

**Interfaces:**
- Produces: beat schema key `opening: String` (optional); journal renders `· <opening>` for pending beats, `<text>` for banked; pending beat with NO opening is HIDDEN.

- [ ] **Step 1: Failing tests.** test_acts: derived act summary carries `opening` distinctly from `text`; a pending beat without opening is absent from the render list; a pending beat with opening renders the opening; a banked beat renders `text`. test_content arm: every `opening` differs from its beat's `text` AND contains none of `["settled", "You read", "You took", "You settled", "you walked"]` (outcome-marker list — extend during implementation if a draft trips honest copy; log any list change to CHOICE-LOG).
- [ ] **Step 2: Run — expect FAIL** (no opening key exists).
- [ ] **Step 3: acts.json — add all 18 openings verbatim:**

| beat | opening |
|---|---|
| first_class | "A class is waiting for the person you act like." |
| reached_city | "Liscor is a walk east, and it doesn't know you yet." |
| errands_around | "Work finds hands that take it." |
| krshia_trust | "Krshia's counter sees everything. Earn a look behind it." |
| watch_calls | "The Watch notices people who fix things." |
| known_face | "Keep showing up, and the city will remember your face." |
| the_stirring | "Something under the city has the Watch losing sleep." |
| warren_cleared | "Whatever moves down there has a den, and dens have doors." |
| counted_among | "The city is deciding what you are to it." |
| the_door_opens | "The Horns are digging east, and they are short a pair of hands." |
| riverfarm_owed | "Riverfarm's fields hold more trouble than wheat." |
| invrisil_squared | "A name needs settling in the City of Adventurers." |
| pallass_tiers | "The Walled City opens for paperwork, not heroics." |
| the_horns_home | "Four adventurers need somewhere to put their feet up." |
| the_reach_mapped | "The Door strains for somewhere it cannot reach yet." |
| the_descent | "Pisces wants to read the seal in person, not from a treatise." |
| the_reading | "The wardwork under Liscor is waiting to be read." |
| the_answer | "What the seal keeps is still the seal's secret. Settle it." |

(These are the shipped drafts — polish freely in voice, log reworded lines to CHOICE-LOG, keep the question-not-answer rule.)

- [ ] **Step 4: journal.gd** — pending branch renders `opening` (keep `· ` marker + pending style); missing/empty opening → skip the beat row entirely; banked branch unchanged.
- [ ] **Step 5: Run tests green; re-derive journal-pinning canonicals** (grep `act_beats\|journal` pins across qa/scripts — seal_open/climax_seal/spine_reach/arc_flow journal shots re-pinned from real runs; windowed re-shots of each act page).
- [ ] **Step 6: Commit** `feat(journal): pending act beats render authored openings, never outcomes`.

### Task 1.2: Leads strip (spec A2)

**Files:**
- Create: `wandering_inn_game/data/leads.json`
- Modify: `wandering_inn_game/src/ui/journal.gd` (Leads section above Quests when non-empty)
- Modify: `wandering_inn_game/src/core/wi_game.gd` (derived `active_leads()` — pure, counter-driven)
- Test: `tests/test_content.gd` (leads schema + gate counters exist), `tests/test_sim_core.gd`

**Interfaces:**
- Produces: `active_leads() -> Array[Dictionary]` ({id, lead_text, place}); leads.json rows `{id, requires:{}, hide_when:{}, lead_text, place}`.

- [ ] **Step 1: leads.json — the four seeded rows verbatim:**

```json
{ "_comment": "Derived journal Leads: un-started mainline hooks whose prerequisites are met. Pure counter reads; a lead vanishes when its hide_when (the quest-start counter) banks. v0.15 spec A2.",
  "leads": [
    { "id": "lead_survey", "requires": { "raskghar_sealed": 1 }, "hide_when": { "horns_delve_started": 1 }, "lead_text": "The Guild posted a Watch notice about the reopened gallery.", "place": "Adventurer's Guild" },
    { "id": "lead_dig", "requires": { "seal_kept_reported": 1 }, "hide_when": { "horns_dig_started": 1 }, "lead_text": "Ceria's been planning a dig east past the floodplains.", "place": "The Wandering Inn" },
    { "id": "lead_spine", "requires": { "door_awakened": 1 }, "hide_when": { "spine_started": 1 }, "lead_text": "Pisces keeps looking at the Door like it owes him a letter.", "place": "Guild steps, Market Street" },
    { "id": "lead_capstone", "requires": { "lattice_witch_lore": 1 }, "hide_when": { "seal_descent_agreed": 1 }, "lead_text": "Pisces is collecting what you learn out there.", "place": "Guild steps, Market Street" }
  ] }
```

- [ ] **Step 2: Failing sim test** — fixture at raskghar_sealed pre-delve → active_leads() contains lead_survey; bank horns_delve_started → empty.
- [ ] **Step 3: Implement** `active_leads()` (reuse `_accomplishment_gate_met` + absent semantics) + journal Leads render (place in parentheses; section hidden when empty).
- [ ] **Step 4: Green + canonical**: extend arc_flow at the three seams — journal shows the lead where it used to show "No quests in progress"; re-pin from runs.
- [ ] **Step 5: Commit** `feat(journal): Leads strip — the mainline never goes pointerless`.

### Task 1.3: Toast survival + Lore capture (spec A3)

**Files:**
- Modify: `wandering_inn_game/src/ui/message_layer.gd:290-340` (map-change/dialogue clears become drain-after; combat banks-then-clears)
- Modify: `wandering_inn_game/src/core/wi_game.gd` + `src/core/save.gd` (persistent `lore_notes: Array[String]`, VERSION bump + migration arm)
- Modify: `wandering_inn_game/src/ui/journal.gd` (Lore tab lists lore_notes newest-first, above item lore)
- Data: tag the lore-bearing toasts (`"lore": true` on toast-emitting effects/props: the detect-magic quartet payoffs, the tremor pointer, threshold narrations — grep `sticky` + the VISUAL-LOG QUEST-START/QUEUE-DROP entries name the set; enumerate in the commit)
- Test: `tests/test_sim_core.gd` (lore_notes append on emit regardless of render; idempotent per unique text), `tests/test_save.gd` (round-trip + migration), a queue-survival unit in whatever harness message_layer has (read first; else a QA leg)

**Interfaces:**
- Produces: `Game.sim.lore_notes` (Array[String], persisted); toast payload key `lore: bool`.

- [ ] **Step 1: Failing tests** (save round-trip with two notes; emit-while-dialogue-open still appends; duplicate text not re-appended).
- [ ] **Step 2: Implement** — smallest set: `_clear_toast()` call sites at :295/:310 (map change, dialogue) re-queue undisplayed non-sticky toasts instead of dropping (sticky already survives); combat's clear (:316) banks the queue and re-queues on combat end. Lore append happens at EMIT time in wi_game (render-independent).
- [ ] **Step 3: Migration** — old saves get `lore_notes: []`; compose per save.gd's chain.
- [ ] **Step 4: Green + canonicals**: horns_dig_flow's 17-emitted-toasts run now renders or lore-captures every tagged one (assert lore_notes count); the TALK-path reveal race canonical (seal_fed) asserts the reveal lands in lore even when the toast loses the race. Full sweep — queue changes have wide blast radius; re-derive moved pins.
- [ ] **Step 5: Commit** `feat(toasts): the queue survives transitions; lore-tagged lines become journal record`.

### Task 1.4: Phase gate
- [ ] wi-verifying-changes full set + windowed journal read of all five act pages + the three seams; PR `wave/v015-p1-delivery`; merge-train.

## Phase 2 — Lane A UI: viewports + acknowledgment (branch `wave/v015-p2-ui`)

### Task 2.1: Viewport correctness cluster (spec A4)
**Files:** `src/combat/combat_hud.gd` (feed row budget — measured rows, no sliced fourth; evict counts wrapped lines), `src/ui/journal.gd` (scroll clips at line boundary), `src/ui/sleep_veil.gd` (wrap-aware line budget for finale lines), `tests/test_copy_fit.gd` (+veil line table, +variant toast table — closes VEIL-COPY/UNMEASURED).
- [ ] Failing copy_fit arms first (the veil/variant tables with current strings — Invrisil recap line becomes a measured, wrapped, passing case, copy untouched). Implement the three viewport fixes. Windowed evidence: FEED-FOLD's three repro shots re-taken clean; JOURNAL/HALF-ROW's two shots clean. Re-pin touched canonicals. Commit per surface.

### Task 2.2: Endings acknowledgment (spec A5)
**Files:** `data/quests.json` (authored completion lines for the seven bare-Complete quests — draft in-file, voice per giver, log to CHOICE-LOG), `src/ui/sleep_veil.gd` (+3 finale recap variant lines: Act I class line variant, Act II "Liscor knows your face" variant keyed `post_game`, Act III warren line keyed `raskghar_sealed`), grant relabels: trapped-halls pacifist resolution grant → `{sneaked_past_danger: 6, persuaded_someone: 2}` (replaces melee_hit/won_combat on that path only), the two non-combat posting beats tick via their own counters (read the two beats, wire the existing route counters into complete_when alternatives per the OR-producer idiom).
- [ ] TDD on the grant swap (resolved_path returns the relabeled grant); finale variants pinned in test_sleep_veil; canonicals re-derived (chronicle_loop pins completion lines). Commit + phase gate + PR.

## Phase 3 — Guest windows + hygiene (branch `wave/v015-p3-guests`)

### Task 3.1: ANY-of-Array guest gates (ruling 1)
**Files:** `src/core/inn_guests.gd` (+Array shape in `_gate_open`: Array of specs = ANY passes; fail-closed on empty array/malformed members), `data/maps/inn/inn.json` (zevara + pisces rows' present_when mirror their pool windows), `tests/test_inn_guests.gd`.
- Entries: `"zevara": [{"absent": ["heard_the_deep_tremor"]}, {"requires": ["raskghar_sealed"]}]`; `"pisces": [{"absent": ["door_retrieved"]}, {"requires": ["door_mounted"]}]`. Audit relc's descent window (relc_descent gating) — add the analogous entry if his window reproduces; log the verdict either way.
- [ ] TDD: window states (summons pending → zevara out, sealed → back; haul window → pisces out with pisces_mounting present — the ghost seat dies); two-guests invariant extended across all windows; fail-closed shapes (empty array, [{}], junk member). Belt-and-braces row edits + fixture sweep for any fixture whose seating shifts (re-derive). Commit.

### Task 3.2: Hygiene batch (spec list, one commit each or grouped sensibly)
- [ ] Dead fixture keys ×2 stripped; interactions.gd variant-entry guard (skip non-dict, note unknown keys via lint not runtime); hedault fragment callback text_variant keyed `traded_guardian_fragment`; Pallass arrival cell → (4,8) or nearest free (re-derive pallass canonicals; add arrival-cell-vs-blocking lint to data_lint); `{addr}` coverage lint extension (quests/items scan); dash policy: em-dash wins (218>61) — sweep the 61 `--` strings + test_content lint forbidding ` -- ` in player strings; SEAL-SLEEP/TOAST-MISMATCH per its ledger entry; GOLEM-NAME-SPLIT (one display_name); TOAST/LENGTH re-cut only if 2.1's budget still clips it. Phase gate + PR.

## Phase 4 — Lane B population (branch `wave/v015-p4-population`)

### Task 4.1: Pallass (forge tier + market)
- New NPCs `forge_smith` (forge tier) + `lift_attendant` (by the Grand Lift): conversations (3-5 nodes, talk_pools, Book-17 Drake archetypes — smith proud/laconic, attendant precise/kind), reactive stages keyed `elevator_pass_stamped` + `seal_resolved`; 4-6 forge-tier observables + 2 market observables; census pointers. Voice blocks in character-profiles.md FIRST.
### Task 4.2: Invrisil (crowd + shopfronts)
- Seven crowd NPCs gain 3+ line pools; two gain `brothers_job_done` reactive stages; b5 #220 three shopfront observes (glazier/cordwainer/stationer) shipped verbatim from that issue's drafts if present, else authored.
### Task 4.3: The Dig camp + migrated remnant
- `ceria_dig_camp` window gains yvlon + ksmvr presence entities (same window, camp cells from free set), 3-4 camp observables; post-dig remnant observable on ruin_surface (gated door_mounted, closes RUIN/MIGRATED-DIORAMA).
### Task 4.4: Regional work
- One repeatable job prop per region: riverfarm field-work board, invrisil errand slate (parlor), pallass forge-fetch slip (forge tier). Reuse the deliveries/bounty machinery (read data/deliveries.json first; new counters `riverfarm_field_jobs`/`invrisil_errands_run`/`pallass_fetches_run` named now). Small grants per bounty-scaling conventions.
- [ ] Each task: TDD-ish (test_content + reachability arms), canonicals (one per region walking the new surfaces live), windowed shots, helper-pace gate re-run at phase end (evening lever stays holstered unless Act II worsens — log verdict). Phase gate + PR.

## Phase 5 — Lane C readability + rigs (branch `wave/v015-p5-readability`)

### Task 5.1: Arena/scene legibility
- DARK-ARENA (sewer rats) back over the acceptance bar; camouflage family (cellar vermin + briar collectors): outline/tint separation via the sprite tint idiom (visual only, zero stat edits — bands untouched); ARC-CLIMAX deep-tunnel overlap (cell/facing adjustments); PALLASS-FORGE-FLOOR floor/wall cue (tile swap on the top rows + arena blocked-cell tint). All windowed-proven before/after; canonical screenshot pins re-derived.
### Task 5.2: Rigs
- Grimalkin re-measure (sprites.json render_scale to the 43.4px figure convention — compute from his 224px frames; expect ≈0.19-0.20 from Relc's 0.6781@128px math — derive exactly, windowed proof at inn seat + Pallass; ruin_warden scale rides the same pass if its P3 math is trivial).
- Klbkch verify: one read of the rig vs the silhouette contract (docs/asset-catalog.md + wiki refs); if confirmed → PixelLab rebuild (create_character per wi-art-and-sprites conventions, ~$0.10-0.30, budget fine), registry swap, windowed proof; if refuted → CHOICE-LOG the verdict + VISUAL-LOG close. Either way logged, never gated.
### Task 5.3: MAP-LIGHTS/DAY opt-out
- `moods.json` per-map `lights_by_day: true` key honored by the world lighting path (read moods.meta comment the VISUAL-LOG cites); apply to seal_vault + trapped_halls; windowed day-time proof.
- [ ] Phase gate + PR + **wave close**: full machine playtest, VISUAL-LOG drain (every claimed item re-shot + moved to Fixed with hashes), helper-pace + census + full sweep, ROADMAP/HANDOFF entries, tag `v0.15.0` per wi-shipping step-0 (freeze the new counters + lore_notes save field note), deploy, Playtest-State bundle of taste items for the user.

## Self-review checklist (run at plan close)
- Spec coverage: A1-A5 → 1.1/1.2/1.3/2.1/2.2 ✓; Lane B → 4.1-4.4 ✓; Lane C → 5.1-5.3 ✓; guest windows → 3.1 ✓; hygiene list → 3.2 ✓; verification bars → phase gates ✓; CHOICE-LOG discipline → Global Constraints ✓.
- Every VISUAL-LOG item the spec claims: QUEST-START+QUEUE-DROP (1.3), PENDING-ITINERARY (1.1), FEED-FOLD+HALF-ROW+LONG-LINE+VEIL-COPY (2.1), DASH-MIX+SEAL-SLEEP+GOLEM-NAME+TOAST/LENGTH (3.2), MIGRATED-DIORAMA (4.3), b5 #220 (4.2), DARK-ARENA+CELLAR-VERMIN+BRIAR+ARC-CLIMAX+FORGE-FLOOR (5.1), GRIMALKIN+RUIN_WARDEN (5.2), KLBKCH (5.2), MAP-LIGHTS (5.3) ✓ — complete.
