# v0.16 "Region Depth" — Invrisil Lane (#306) — Implementation Plan

> Status: **ACTIVE** (v0.16 wave, dispatched 2026-07-28)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Invrisil's two v0.16 side quests with full three-pillar parity — **I1 "A Setting for a Lady"** (Hedault commission, started at a client met inside a new stationer's) and **I2 "The Hat Stays On"** (Wilovan's parlor errand, run at a new Adventurer's Rest) — plus the two small interiors that host their beats and stay open afterwards as exploration payoff.

**Authority spec:** `docs/design/2026-07-28-v0.16-region-depth-spec.md` §"Invrisil (#306)" (lines 65–100) and §"Shared conventions (binding)" (lines 160–182), **as amended by the controller rulings recorded in `## Controller rulings applied` below — where they differ, the rulings win.**

**Issue:** #306. **Branch:** `issue/306-invrisil-depth`. **PR title:** `v0.16 Invrisil depth: A Setting for a Lady + The Hat Stays On, stationer's + Adventurer's Rest (#306)`

**Architecture:** Data-first Godot 4.7 (`wandering_inn_game/`). Everything in this lane is JSON content plus three shared-const appends in `tests/`. No engine work, no new autoloads, no new sprites, no new arenas, no new biomes.

**Tech Stack:** Godot 4.7 headless for tests; declarative QA scripts in `wandering_inn_game/qa/scripts/`; canonical fixtures with pinned `rng_state` derived by `tests/_derive_rng_state.gd`.

---

## Controller rulings applied (binding; each also goes to docs/CHOICE-LOG.md)

1. **I1 starts at the stationer client, not on Hedault's hub.** The client banks `heirloom_commission_started`; **every** new Hedault surface is gated `requires {"accomplishment": {"heirloom_commission_started": 1}}` (an accomplishment gate is *hidden*, not visible-locked), so `qa/scripts/hedault_fragment_loop.json`'s exact 5-row `options` pin and `qa/scripts/spine_reach.json`'s blind `move down 5` both stay stable with **zero re-pins** — neither fixture can ever hold a counter invented in this PR.
2. The Appraise skill id is **`appraise_goods`** (`[Appraise Goods]`), never `observe` (`[Appraise Foe]`).
3. Stationer conversion preserves entity id `boulevard_stationer`, its `observe` string **verbatim**, and `blocked [20,1]`; it becomes a `kind: "door"` on the shipped boulevard door idiom.
4. Adventurer's Rest door at **(18,1)**, approach **(18,2)** — justification in Task 2.1.
5. I1 FIGHT uses **new** combatant ids (never `alley_footpads_a/b`), and is correct on a save where the alleys are already cleared.
6. I1's reward item is a **distinct new item id**.
7. I2's venue is `adventurers_rest`; SKILL/SNEAK is a #204 plate-pattern transplant; `{addr}` in all Wilovan/parlor copy; `wilovan_inn.json`'s reactive line is a `text_variants` entry on `greet` keyed on `hat_job_done` — **never** a new option, **never** a base-text edit.
8. Hedault has no `character-profiles.md` section; this lane writes one. **Amended by ruling D:** the file is **SHARED**, not exclusive — the controller pre-landed a `## Hedault (v0.16 #306 STUB …)` header at `docs/design/character-profiles.md:525-527`, and this lane **fills that stub in place**. Never append at EOF (Pallass fills its own two pre-landed stubs the same way).
9. Spec correction: **four** shopfront observes ship — opening the stationer leaves **three**, not two.
10. Compound-requires trap: any bench arm wanting item + skill splits across two nodes (`pisces_seal.json:112` precedent). This plan uses two single-skill options instead.

### Wave-level controller rulings (bind all four v0.16 lanes; these win over anything above)

- **A — combat windows.** Every new `sim_combat_batch.gd` gated cell this wave uses **`win_lo 0.55` / `win_hi 0.95`** (the shipped stop-cell precedent). Region-band ordering is proven by **recording the measured medians and win rates in the PR body**, never by authoring a narrow window. The first draft's `win_hi 0.71` "asserts Riverfarm-easier-than-Invrisil" argument is **struck** — a narrow window is a flaky gate, not a proof.
- **B — census.** Per-lane constant is **112**, not 450 (see the Census section). This lane states an absolute projected `_comment` total and re-measures it at the gate.
- **C — shared-append anchors.** Every shared-file insert names an anchor row this lane does not share (FILE OWNERSHIP table). New test-file locals take the **`i_`** lane prefix.
- **D — `docs/design/character-profiles.md` is SHARED.** Fill the pre-landed `## Hedault` stub **in place**; never append at EOF.
- **E — `render_qa_notes.py` needs `--write`.** Every invocation is `--write` first, bare second as the check; the file is re-rendered at **every** train merge.
- **F — new-id figure bar.** `tests/test_combat_visuals.gd` does **not** measure any id this lane adds: `FIGURE_ROWS` (`:536-541`) holds exactly four sprites (`bat`, `briar_collector`, `briar_collector_deep`, `ruin_warden`) and `_board_cells` (`:563-566`) would KeyError on anything else, and the bar's only caller (`:609-620`) iterates a hardcoded `audited` list containing no new id. The suite therefore **passes by exclusion**. The **windowed shots are the legibility read**. **No unverifiable figure number may appear in a shipped `_comment`** — the "3.05 cells" claim drafted into `heirloom_fence` is struck (it also cost census). No id joins `audited` without first adding its sprite to `FIGURE_ROWS` with a re-derived row count.

---

## CONTROLLER AMENDMENT — the nobility layer (user directive 2026-07-28)

User ruling, arrived after plan verification: nobility is an important
component of the world this game has not represented, and Invrisil is
its home ground. The FULL thread (Magnolia-adjacent content, estate
surfaces, house politics) is **#318, v0.17, spec-first** — her voice
bar is the highest in the game and does not get bolted onto a verified
lane. THIS lane ships the copy-level layer below. All deltas are pure
copy + talk_pool additions: **no new counters, no new entities, no
floor-count changes, no new QA surfaces** — apply each delta AT its
named task, BEFORE that task's QA pins are authored (the client's
speaker string and the Rest pool lines land in this lane's own new
canonicals; there is nothing shipped to re-pin).

**A1 — The client IS a Lady (Task 2.1, 2.2, 2.6).** The quest is
titled "A Setting for a Lady"; make it literal. Display name and
`speaker` become **"A Lady with a Ring Box"** everywhere the graph,
entity, and this plan's QA drafts say "A Woman with a Ring Box".
Unnamed-house archetype (repo convention — never invent a house name;
canon collision risk). Task 2.1's report-beat description becomes "Go
back to the Lady with the ring box and tell her how it ended." Two
copy additions, verbatim:
- `terms` node, appended to its existing text: *"My house has exactly
  two assets left: its name, and the habit people have of not looking
  past it. The enchanter may have the truth. He may not have the
  name."*
- New line in `the_stone` (or its natural follow node), her only
  acknowledgment of the city's real owner — Vol-1-safe, oblique, no
  on-screen politics: *"This city is run from a house you cannot see
  from any street in it, by a woman who notices everything worth
  noticing. A glass stone is exactly the right size to stay beneath
  that notice. I intend to keep it there."*

**A2 — Noble texture at the Adventurer's Rest (Task 1.4).** Two
talk_pool additions to EXISTING drafted NPCs (pool lines do not change
interactable counts; POPULATION_FLOORS unaffected):
- `rest_house_factor` gains: *"The Reinhart carriage went up the
  boulevard twice last month. Both times, four adventurers in this
  room suddenly remembered appointments."*
- `rest_gnoll_ranger` gains: *"Half the good contracts north of Liscor
  have a house seal on them somewhere near the bottom. Read that far
  before you sign, yes?"*

**A3 — House paper at the stationer's (Task 1.3).** The scribe NPC's
talk_pool gains: *"House paper is a third of the trade and all of the
discretion. A crest on the envelope changes what the words inside are
allowed to mean."* (The nine-wax/blank-seal observable already carries
the other half of this texture; do not touch it.)

**A4 — Bars.** Book-17 trivially met (Magnolia Reinhart and her
carriage are Volume-1 canon). Reinhart is the ONLY house named, and
only in ambient speech. The Lady's house is never named. No {addr} in
her copy (she is hiring, not deferring). CHOICE-LOG carries the
directive, the scope split (copy layer now / #318 later), and the
unnamed-house call.

## Global Constraints

### Copy rules (binding)

- **Book-17 bar** on all new material. **"the Magical Door"** only — never a Vol-9 name.
- **`{addr}` for every PC address** in Wilovan/parlor/Rest copy. `{addr}` → "sir"/"miss"; `{Addr}` is the sentence-head form. It resolves **only** inside a `text` key, a `talk_pool` entry, a `talk_pool_stages.lines` entry, or a `*toast` key (`ADDRESS_TOKEN_KEYS`, `tests/test_content.gd:627`). **Never** put `{addr}` in `data/quests.json` or `data/items.json` — those two are scanned as UNRESOLVABLE and fail loud.
- **Register purity:** `data/dialogue/wilovan_inn.json` never touches the job, the package, the venue, Coyle, Farley, the marker or the fence shelf (its own `_comment:2` and `character-profiles.md:310-318`). The new variant is **manners, not business**.
- **No fetch-list copy:** beat descriptions point at a *place and a person*, never itemise objects.
- One em-dash maximum per line; use the literal `—`, never ASCII `--`. Lint both forms (`—` also hides as an escape in `data/maps/**`).
- Copy fit: `DIALOGUE_LINE_CAPACITY = 2` at `DIALOGUE_TEXT_WIDTH 656.0`; toasts at `TOAST_TEXT_WIDTH 412.0`; pool/stage lines are ambient barks, **2 wrapped lines max**.

### Census budget (hard gate) — controller ruling B

- `python3 scripts/comment_census.py --check` from repo root. Measured at plan time: `DATA chars=1113728 _comment_chars=166676 ratio=15.0% target<=15.0%` — **383 characters of global headroom**, and that headroom is the WHOLE WAVE's, not this lane's.
- **Rule for this lane (ruling B):** new `_comment` characters written under `wandering_inn_game/data/**` must satisfy **`new_comment_chars ≤ 112 + 0.1765 × new_noncomment_chars`**. The `450` constant in the first draft was the whole-wave slack solved out of `(166676+C)/(1113728+C+N) ≤ 0.15`; **four lanes split it**, so this lane's share of the constant is `450/4 ≈ 112`. The slope term is per-lane already (it is earned by the lane's own new bytes).
- **This lane's projected absolute `data/**` `_comment` total: ≈ 4,400 characters.** Measured off every `data/**` JSON draft in this plan (22 fenced blocks, minus the deferred `leads.json` drafts): **4,397 comment chars against 34,349 non-comment chars**, so the budget is `112 + 0.1765 × 34,349 ≈ 6,175` and the lane sits **≈ 1,775 chars under**. The shipped files are exploded 1-space-per-level, which grows the non-comment denominator and therefore the budget — the margin only widens. Sanity-checked against the global constraint too: `(166676 + 4397) / (1113728 + 38746) = 14.84% ≤ 15.0%`. Restate the **measured** number in the PR body so the controller can sum the four lanes before the train starts, and re-measure it in Task 6.1 Step 3 rather than trusting this estimate.
- **Merge-train rule:** `comment_census.py --check` is re-run against the **MERGED tree** at every train merge, never against this lane's branch alone — a green branch proves nothing about the train. Any **final** overshoot is owned by the **wave-close PR**, not this lane. Design to budget anyway.
- **What counts:** `comment_census.py:55-62` charges any key that starts with `_` **and** contains `comment`. So `_comment` and `_resolution_paths_comment` are charged; **`_resolution_order` and `floor_layers[]._pick` are free**. This plan therefore ships rationale in `_resolution_order` and `_pick` wherever the shape allows, and drops `_resolution_paths_comment` from both new quest blocks (only `_resolution_order` is required — `test_quests.gd:133-142`).
- Long rationale goes into **QA-script `_comment`s** (`wandering_inn_game/qa/**` is census-exempt) or **`docs/CHOICE-LOG.md`** (also exempt). In `data/**`, write **pointers, not paragraphs** — one trap comment at the seam.

### Sanctioned shapes only

- `requires`/`hide_when` single keys: `skill`, `class`, `accomplishment`, `board_accepted`, `delivery_accepted`, `gold`, `once_per_waking`, `item`, `race`, `phase`. Only six two-key compounds are legal: `{gold, accomplishment}`, `{accomplishment, once_per_waking}`, `{accomplishment, class}`, `{once_per_waking, item}`, `{accomplishment, skill}`, `{gold, item}`. **`{skill, item}` and `{skill, gold}` CONTENT_FAIL** (ruling 10).
- `hide_when` may **not** carry `once_per_waking`.
- `hide_when` semantics are **AND**: every key must be met for the option to hide.
- **Every effect dict carries exactly one verb.** The runtime applier is an `elif` chain (`src/core/wi_game.gd:1071-1131`) — a two-key dict silently drops one AND fails `test_content`. Author `[{...},{...}]`.
- Any `door_when` / `contains_when` / `portal_menu_when` / `fence_menu_when` **must wrap counters in `"requires"`** — `VACUOUS_GATE_ALLOWLIST` is empty by design (`data_lint.py:50-53`). This lane authors none of these; the two new doors are plain `kind: "door"`.
- `encounter_when` accepts **only** `phase`, `requires`, `absent`. `present_when` is **forbidden** on `kind: "encounter"`.
- Softlock guard: any node with a `hide_when` option **or** an accomplishment-`requires` option must keep ≥1 option carrying **neither** key.
- Every `kind: "encounter"` entity must carry `arena`, `enemies`, `allies` **and** `on_victory` explicitly — `"allies": []` is mandatory.
- Every non-pc combatant row must carry a positive `power_level`.
- `talk_pool_stages` need a unique non-empty `id`, a **non-empty** `requires_accomplishment`, ≥1 non-empty line, a base `talk_pool` on the same entity, and ascending thresholds on any shared counter.

### Counter freeze

New counters are named **verbatim at first write** — they freeze at the next release cut. This lane's complete list, and nothing else:

| Counter | Producer | Spec-named? |
|---|---|---|
| `heirloom_commission_started` | `invrisil_stationer_client.json` option effect | ruling 1 |
| `heirloom_truth_kept` | `hedault_enchanting.json` option effect | spec |
| `setting_assisted` | `hedault_enchanting.json` option effect (×2 arms) | spec |
| `original_recovered` | `alley_fence_door` encounter `on_victory` | spec |
| `setting_commissioned` | `invrisil_stationer_client.json` handover effect | spec (terminal) |
| `hat_job_taken` | `invrisil_wilovan.json` option effect | this plan |
| `handoff_talked` | `invrisil_rest_factor.json` option effect | spec |
| `hat_hook_set` | `rest_hat_hook` `on_interact_accomplishment` | this plan (plate NEAR) |
| `handoff_mistimed` | `rest_corner_table` base `on_interact_accomplishment` | this plan (plate wrong-order) |
| `handoff_quiet` | `rest_corner_table` `variants[0].accomplishment` | spec |
| `handoff_loud` | `rest_bravos` encounter `on_victory` | spec |
| `hat_job_done` | `invrisil_wilovan.json` report effect | spec (terminal) |

All twelve are **data-derived** — `generate_shipped_ids.py` picks them up at tag time with **zero hand-adds**. Do **not** regenerate `data/shipped_ids.json` in this PR (release-cut only; `RELEASE = "0.15.0"`).

### Process

- Test runner: `perl -e 'alarm 240; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/<file>.gd` from repo root. A failed `assert` **hangs** a headless run forever — alarm-wrap every godot call. macOS has no `timeout`.
- Grep every run's output for `SCRIPT ERROR|Parse Error|WARNING` — zero known-harmless warnings.
- Load the skill before the matching work: `wi-adding-a-scene` (maps), `wi-adding-dialogue-and-quests` (dialogue/quests), `wi-adding-an-encounter` (combat data), `wi-writing-qa-scripts` (QA), `wi-verifying-changes` (before any green claim), `wi-machine-playtest` (windowed pass).
- Never hand-write shipped-JSON splices: `python3 wandering_inn_game/scripts/splice_json.py --file data/<f>.json --container <key> --record '{...}'`. Indentation differs per file — `quests.json` TABS, `combatants.json`/`items.json`/map files 1-space-per-level. Never round-trip shipped JSON through `json.dump` with default `ensure_ascii=True` (it rewrites every literal em-dash); if you generate, pass `ensure_ascii=False` and grep the result for `—`.
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- The PR head commit message carries **`[ci-full]`** so the heavy `sweep` + `web-parity` jobs run.

---

## FILE OWNERSHIP

### Exclusive to this lane (own outright)

- `wandering_inn_game/data/maps/invrisil/invrisil_boulevard.json` (edit)
- `wandering_inn_game/data/maps/invrisil/mercantile_alleys.json` (edit)
- `wandering_inn_game/data/maps/invrisil/brothers_parlor.json` (edit)
- `wandering_inn_game/data/maps/invrisil/stationer.json` (**new**)
- `wandering_inn_game/data/maps/invrisil/adventurers_rest.json` (**new**)
- `wandering_inn_game/data/dialogue/hedault_enchanting.json` (edit)
- `wandering_inn_game/data/dialogue/invrisil_wilovan.json` (edit)
- `wandering_inn_game/data/dialogue/wilovan_inn.json` (edit — **ruling 7 shape only**)
- `wandering_inn_game/data/dialogue/invrisil_stationer_client.json` (**new**)
- `wandering_inn_game/data/dialogue/invrisil_rest_factor.json` (**new**)
- `wandering_inn_game/qa/scripts/*.json` and `wandering_inn_game/qa/fixtures/*.json` — **only the nine scripts and eight fixtures this plan creates**

### SHARED — anchored inserts, merge-train resolves (controller ruling C)

**The rule (ruling C):** never "append at EOF" or "append at end of array" on a file another lane also writes. Each lane inserts **immediately after a named row it does not share**, so the four lanes never touch the same line and git resolves the train mechanically. This lane's anchors, named explicitly:

| File | This lane's edit | **Anchor — insert immediately after** |
|---|---|---|
| `wandering_inn_game/data/quests.json` | 2 quest objects | the `a_gentlemans_disagreement` quest object (Invrisil's own shipped quest) |
| `wandering_inn_game/data/combatants.json` | 4 rows | the `hired_blade_knife_b` row (Invrisil's shipped hired-blade roster) |
| `wandering_inn_game/data/items.json` | 1 row | the `hedaults_wardstone` row (Invrisil enchanting item) |
| `wandering_inn_game/data/moods.json` | 2 rows under `moods` | the `brothers_parlor` key (**ruling C**: Floodplains takes `floodplains`, Riverfarm `witch_hollow`, Invrisil `brothers_parlor`, Pallass `pallass_forge` — the four lanes never share a line) |
| `wandering_inn_game/qa/manifest.json` | 9 entries in `scripts[]` | the `hedault_fragment_loop` entry |
| `wandering_inn_game/AGENTS.md` | 9 seed-table rows | the `hedault_fragment_loop` row — **same relative order as the manifest insert**, since `qa/ci_sweep.sh` hard-fails at startup on any manifest/table disagreement |
| `wandering_inn_game/tests/test_content.gd` | `LANDMARK_TOKENS` +2, `POPULATION_FLOORS` +2 | the `"mercantile_alleys"` row in each const |
| `wandering_inn_game/tests/test_fixture_coherence.gd` | `MAP_REQUIRES` +2, `COMBAT_BAND_FIXTURES` +2 | `"mercantile_alleys"` (MAP_REQUIRES) / `"near_invrisil_fight"` (COMBAT_BAND_FIXTURES) |
| `wandering_inn_game/tests/test_quests.gd` | co-bank ladder pins for 2 quests | the `price_of_a_favor` block — **every new local in this file takes the `i_` lane prefix** (`i_setting`, `i_hat`, `i_setting_both`, …). Riverfarm and Pallass both wanted a bare `var ledger` in this same function body; `tests/test_quests.gd:90-132` is one continuous scope, so a duplicate `var` is a **parse error that reds the whole suite**, not a shadow. No bare `ledger`/`thicket`/`tempered`/`quest` locals from this lane. |
| `wandering_inn_game/tests/sim_combat_batch.gd` | `INVRISIL_CELLS` +2 | end of `INVRISIL_CELLS` — this const is lane-exclusive (each region has its own array), so no anchor is needed |
| `docs/design/character-profiles.md` | fill the **pre-landed `## Hedault` stub section IN PLACE** | **ruling D — SHARED, not exclusive.** The controller pre-landed three stub headers at the plan commit (`## Forge Hall Apprentice`, `## Den-Shop Keeper` = Pallass; `## Hedault` :525-527 = this lane). **Never append at EOF** — replace this lane's own `(placeholder — replaced by the Invrisil lane)` line in place. Pallass fills its two stubs the same way; the two lanes never touch each other's lines. |
| `docs/CHOICE-LOG.md` | this lane's entries | append |

**Never regenerate `wandering_inn_game/data/shipped_ids.json`** — tag-time only.

**GENERATED, never hand-edited (controller ruling E):**
- `qa/manifest.json`'s `surfaces` blocks — `python3 wandering_inn_game/scripts/derive_qa_surfaces.py --write`, then `--check`. (A **bare** `derive_qa_surfaces.py` also writes — `scripts/derive_qa_surfaces.py:412-414` returns `cmd_write()` on empty argv — but pass `--write` explicitly anyway.)
- `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` — **`python3 scripts/render_qa_notes.py --write`**, then a **bare** `python3 scripts/render_qa_notes.py` as the check (rc 0 + `PASS: QA notes match manifest`), then `python3 scripts/check_doc_drift.py`. **A bare `render_qa_notes.py` does NOT write** — `scripts/render_qa_notes.py:55-66` only writes under `--write`, and otherwise prints `QA NOTES DRIFT` and returns 1. The first draft's bare invocations were a no-op that would have reproduced the #312 `leak-check` red exactly.
- **Merge-train note:** `render_qa_notes.py` renders the file **whole from the entire manifest**, so it must be re-rendered on **every train merge that combines two lanes' manifest entries** — not only inside this lane's own commit. The same is true of `derive_qa_surfaces.py --write`.

Regenerate both in the **same commit** as any manifest or QA-script change.

### Deliberately NOT touched

`data/arenas.json` (reuse `mercantile_alley` + `merchant_warehouse`), `data/biomes.json` (reuse `brothers_parlor` + `inn`), `data/sprites.json` (reuse registered sprites only), `data/portals.json` (walk-in interiors, no portal surfaces), `data/leads.json` (see **DEFERRED TO CLOSE PR**), `data/skills.json`, `src/**`.

---

## Phase 1 — Maps and doors

`sim_combat_batch.gd`'s `total_cells` is **derived** from array sizes at `:321` — appending to `INVRISIL_CELLS` needs no manual count edit. (The cross recon's "update `total_cells`" note is stale for this array.)

### Task 1.1: Convert `boulevard_stationer` into the stationer's door

**Files:**
- Modify: `wandering_inn_game/data/maps/invrisil/invrisil_boulevard.json` (`boulevard_stationer`, entity at `:1394-1409`)

**Interfaces:**
- Produces: a walk-in door from `invrisil_boulevard` (20,1) → `stationer` (6,7). Task 1.3 owns the far side.

- [x] **Step 1: Load `wi-adding-a-scene`. Read the four shopfront props** (`boulevard_glazier` :1365, `boulevard_teahouse` :1387, `boulevard_cordwainer` :1376, `boulevard_stationer` :1394) and the two shipped door pairs (`boulevard_to_alleys` [26,8]→[1,7] at :931; `alleys_to_parlor` [19,12]→[1,4]). **Ruling 9:** four shopfronts ship, so this leaves three observes.
- [x] **Step 2: Rewrite the entity in place.** Keep `id`, keep `observe` **byte-identical**, keep the cell, drop `hide_sprite`, add the door keys:

```json
  {
   "_comment": "v0.16 I1 (#306): kind flips prop -> door in place on the SAME already-blocked cell (20,1), id and `observe` byte-identical, so invrisil_walkthrough's player_blocked + [Observe] + toast pins stay exact. hide_sprite dropped so the facade reads enterable.",
   "id": "boulevard_stationer",
   "kind": "door",
   "cell": [
    20,
    1
   ],
   "display_name": "A Stationer's Window",
   "sprite": "door",
   "observe": "Ruled paper in three weights, ink in four, and a card offering a scribe by the hour in a hand that is itself the advertisement. Half the contracts argued about on this street were bought here first, quietly, by both sides.",
   "to_map": "stationer",
   "to_cell": [
    6,
    7
   ]
  }
```

- [x] **Step 3: Prove the three pins by hand before running anything.** `qa/scripts/invrisil_walkthrough.json` steps 61–67 are: `move up 1` from (20,2) → `assert_event_logged player_blocked {cell:[20,1]}` → `press_field_skill observe` → `skill_used {target: "boulevard_stationer"}` → the full observe toast → `screenshot 01c_boulevard_stationer`. **There is no `press interact` at (20,2)** (verified: the walkthrough presses `interact` only at (25,8), (3,6), (18,12) and in the parlor), so no step becomes a map transition. (20,1) stays in `blocked`, so `player_blocked` still fires. **No canonical needs a re-pin.** Record that sentence in the PR body.
- [x] **Step 4: POPULATION_FLOORS check.** `invrisil_boulevard`'s floor is 20. `INTERACTABLE_KEYS` counts `observe`-carrying props **and** every `kind: "door"`, and this entity gains no `present_when`, so the count is unchanged by the conversion and **+1** from Task 1.2's new door. Floors are minimums — **no re-derive needed.** (Ruling 3's re-derive trigger does not fire.) State this in the PR body.
- [x] **Step 5: Run** `python3 wandering_inn_game/scripts/data_lint.py` — expect clean.
- [x] **Step 6: Commit** `feat(invrisil): the stationer's window becomes a door (#306)`.

### Task 1.2: Promote the (18,1) decor door into the Adventurer's Rest door

**Files:**
- Modify: `wandering_inn_game/data/maps/invrisil/invrisil_boulevard.json` (`decor` array `:878-884`; `entities` array)

**Interfaces:**
- Produces: a walk-in door from `invrisil_boulevard` (18,1) → `adventurers_rest` (6,7). Task 1.4 owns the far side.

- [x] **Step 1: Delete the decor row** `{"sprite": "door", "cell": [18, 1]}` at `:878-884`. Leave the `[4,1]` decor door alone — it stays dressing.
- [x] **Step 2: Append the entity** (place it adjacent to `boulevard_to_alleys` in the entities array so the two doors read together in diff):

```json
  {
   "_comment": "v0.16 I2 (#306): promotes the shipped [18,1] DECOR door sprite into a real door (its decor row is deleted in the same edit, so nothing double-draws). Row 1 is blocked x0-27, so no walkable cell gains a blocker. Cell chosen over [4,1]; rationale in CHOICE-LOG.",
   "id": "boulevard_to_adventurers_rest",
   "kind": "door",
   "cell": [
    18,
    1
   ],
   "display_name": "The Adventurer's Rest",
   "sprite": "door",
   "observe": "A house sign with no name on it, only a hand of cards face down and a hat on a peg. Half the silver in this city drinks here and none of it says so out loud.",
   "to_map": "adventurers_rest",
   "to_cell": [
    6,
    7
   ]
  }
```

- [x] **Step 3: Cell justification, hand-verified against the live scripts (the first draft's evidence sentence was WRONG — this is the corrected one).**
  - **(18,1) is on the fully blocked row 1** (`invrisil_boulevard.json` blocks x=0…27 at y=1 — all 28 cells), so no previously-walkable cell gains a blocker and the save-compat hazard in `wi-adding-a-scene:114-120` cannot fire. Both new doors (18,1) and (20,1) are on that row.
  - **Row 2 is NOT "x 20-23 only".** `invrisil_walkthrough` walks row 2 **end-to-end, x=1…27, thirty-six times**: steps 167–203 are an eighteen-fold `move right 26` / `move left 26` pacing loop used to grind the clock to night, with a hard `player_cell [27,2]` pin at step 185 and `phase night` at steps 204–206. Row 2 carries **zero** blocked cells today. The new door is harmless **only** because it sits on row 1, not because row 2 is unwalked.
  - **RULE — never occupy a row-2 boulevard cell.** Nothing in this lane may place an entity, an encounter or a blocked cell anywhere on `invrisil_boulevard` row 2. `WIGame.move_player` (`src/core/wi_game.gd:310-325`) **skips `_tick_action()` on a blocked step**, so a single new row-2 blocker would both break the `[27,2]` pin *and* stall the day→night pacing the shot-07 night read depends on. This rule is restated in the Danger list.
  - **(18,2) is open floor and clear of every pinned assert:** `invrisil_walkthrough` pins (20,2)/(23,2)/(14,2)/(27,2)/(1,2)/(23,6)/(25,8)/(18,9)/(18,12); `invrisil_round_trip` pins (4,8)/(13,8)/(15,8)/(25,8); `invrisil_disagreement_stealth|talk` pin (23,6); `parley_*` teleport to (24,14). (18,2) is walked **through** by the pacing loop but never pinned, and a walkable cell staying walkable changes nothing.
  - The walkthrough's `move right 5` from (18,9) and `move down 3` to (18,12) both stay on the x=18 column at y≥9 — untouched.
- [x] **Step 4: Run** `data_lint.py`; **commit** `feat(invrisil): the Adventurer's Rest opens off the boulevard (#306)`.

### Task 1.3: `data/maps/invrisil/stationer.json`

**Files:**
- Create: `wandering_inn_game/data/maps/invrisil/stationer.json`

**Interfaces:**
- Consumes: the (20,1) door (Task 1.1).
- Produces: map key `stationer`; hosts `stationer_client` (I1's giver, Task 2.2).

**Layout spec — authored on the `riverfarm_longhouse.json` template, NOT as a raw blocked ring.** Grid **12×9** (parlor is 14×10 — under scale). Biome **`brothers_parlor`** (reused: wood footsteps, `Interior_Walls_01` sheet; **no `data/biomes.json` edit**).

**Why the template matters (this was the first draft's structural bug):** `src/world/tile_board_builder.gd:24-31` `field_blocked_render_plan` drops a biome `blocked_props` prop on **every** blocked cell that is not `segment_covered`, `cover_skip` or `authored_covered`. A raw perimeter ring in a biome that declares `blocked_props` renders as a **ring of crates and barrels**, and `tests/test_world_visuals.gd:130-166` passes it (it is a 200-cell budget, not a shape check). `brothers_parlor` happens to declare no `blocked_props` so the stationer would have survived — but the Rest would not, and both rooms take the same shape so the pattern is reviewable once. Every shipped interior does it this way: `inn.json`, `riverfarm_longhouse.json` (walls + 4 furniture cells).

- **`walls.segments`** carries the whole perimeter. Wall cells become blocked at load — `src/core/wi_game.gd:140-143` folds every `segment_cells()` cell into the map's `blocked` dict — so **wall cells are NEVER also listed in `blocked`**. Double-listing is the trap this template exists to avoid.
- **`blocked`** holds **furniture only**, and every cell in it carries a matching **`decor`** row so the biome prop pool never fires on it.
- **`floor_layers`** lifts the room off the biome default (all 22 shipped maps carry one; `brothers_parlor.json`'s own `_pick` records that the parlor was moved off the plain inn plank because it "windowed-read too close").
- **`ambience`** — the shipped interior preset, `dust_motes` over `"all"` at dusk/night.

Perimeter segments (12 wide, 9 tall, door gap at **[6,8]**): row 0 `[0,0]→[11,0]`; col 0 `[0,1]→[0,8]`; col 11 `[11,1]→[11,8]`; row 8 left `[1,8]→[5,8]`; row 8 right `[7,8]→[10,8]`. That is the same 37 cells the first draft listed in `blocked`, now carried by the wall builder.

**Arrival cells, hand-verified both directions:**
- boulevard (20,1) → stationer **(6,7)**: (6,7) is interior floor, not in `blocked`, and carries no entity. ✔
- stationer (6,8) → boulevard **(20,2)**: (20,2) is open boulevard floor and is the exact cell `invrisil_walkthrough` stands on at step 60. ✔

- [x] **Step 1: Author the file** (match `brothers_parlor.json`'s 1-space-per-level exploded style; if you generate it, `ensure_ascii=False` and grep the result for a literal `—`):

```json
{
 "_comment": "v0.16 I1 (#306). Walk-in only (no portals row). Biome + every sprite reused -- zero biomes.json/sprites.json edits. Perimeter is walls.segments, so wall cells are NEVER also in `blocked`; `blocked` holds furniture only, each cell with a matching decor row.",
 "biome": "brothers_parlor",
 "grid": { "width": 12, "height": 9 },
 "blocked": [
  [4,5]
 ],
 "floor_layers": [
  {
   "_pick": "#225 floor differentiation (this key is census-FREE -- _pick carries the rationale so _comment does not have to). The brothers_parlor biome's default floor is the inn plank [1,21], and the parlor itself sits on Library-pack parquet; a stationer one street over must read as neither. Reuses the SAME Interior_Walls_01 sheet's plain pale-board swatch [16,21]/[17,21] -- the shipped runners_guild floor, so sheet, license and footstep-wood are all unchanged. Reads as a swept shop board: cooler and plainer than the parlor's brandy-lit parquet, warmer than stone.",
   "sheet": "res://assets/props/free_pack/Interior_Walls_01.png",
   "tile_px": 16,
   "variants": [[16,21],[17,21]],
   "cells": "all"
  }
 ],
 "walls": {
  "sheet": "res://assets/props/free_pack/Interior_Walls_01.png",
  "tile_px": 16,
  "segments": [
   { "from": [0,0], "to": [11,0], "cap": [14,6], "face": [14,7] },
   { "from": [0,1], "to": [0,8], "cap": [14,6] },
   { "from": [11,1], "to": [11,8], "cap": [14,6] },
   { "from": [1,8], "to": [5,8], "cap": [14,6] },
   { "from": [7,8], "to": [10,8], "cap": [14,6] }
  ]
 },
 "decor": [
  { "sprite": "table_brown", "cell": [4,5] },
  { "sprite": "stool", "cell": [3,5] },
  { "sprite": "stool", "cell": [5,5] },
  { "sprite": "rug_tan", "cell": [6,4], "tint": [0.52, 0.46, 0.38] },
  { "sprite": "window_blue", "cell": [7,1] },
  { "sprite": "sconce", "cell": [4,1], "light": { "color": [1.0, 0.82, 0.55], "energy": 0.8, "radius": 32, "flicker": true } },
  { "sprite": "plant_pot", "cell": [10,7] }
 ],
 "ambience": [
  { "preset": "dust_motes", "rect": "all", "phase": ["dusk", "night"] }
 ],
 "entities": [
  {
   "id": "stationer_to_boulevard",
   "kind": "door",
   "cell": [6, 8],
   "display_name": "Out to the Boulevard",
   "sprite": "door",
   "to_map": "invrisil_boulevard",
   "to_cell": [20, 2]
  },
  {
   "_comment": "I1's GIVER (ruling 1): the commission starts here, never on Hedault's hub.",
   "id": "stationer_client",
   "kind": "npc",
   "cell": [3, 2],
   "display_name": "A Woman with a Ring Box",
   "sprite": "pc_human_f",
   "tint": [0.62, 0.52, 0.58],
   "facing": "right",
   "observe": "She has taken the chair furthest from the window and put a small hinged box on the table in front of her, closed. She has not opened it once in the time you have been standing here.",
   "talk_pool": [
    "This is the only shop on the street where a woman may sit for an hour and be assumed to be choosing ink.",
    "I am not waiting for anyone. I am deciding something. They look identical from outside."
   ],
   "conversation": "invrisil_stationer_client"
  },
  {
   "id": "stationer_clerk",
   "kind": "npc",
   "cell": [8, 1],
   "display_name": "A Scribe by the Hour",
   "sprite": "human_laborer",
   "tint": [0.48, 0.5, 0.56],
   "facing": "down",
   "observe": "Cuffs pinned back, three nibs laid out in order of nerve, and the particular stillness of a man who is paid to have heard nothing.",
   "talk_pool": [
    "Contracts, letters, and the occasional apology. The apologies pay best and take longest.",
    "I write what I am told and I remember nothing after. That is the whole of the service.",
    "Both sides of an argument have bought their paper here. Neither knows. Neither asks."
   ]
  },
  {
   "id": "stationer_ruled_paper",
   "kind": "prop",
   "cell": [1, 1],
   "display_name": "Ruled Paper in Three Weights",
   "sprite": "crate",
   "observe": "Three weights, stacked lightest at the top, each with its price chalked on the edge of the shelf rather than the stock. Nothing here is priced where you can carry the number away."
  },
  {
   "id": "stationer_ink_rank",
   "kind": "prop",
   "cell": [2, 1],
   "display_name": "A Rank of Inks",
   "sprite": "barrel",
   "observe": "Four inks, and the fourth is twice the price of the third for a difference you can only see in daylight. Somebody in this city has bought it every week for years."
  },
  {
   "id": "stationer_counter_l",
   "kind": "prop",
   "cell": [5, 1],
   "display_name": "The Counter",
   "sprite": "counter_left",
   "observe": "Worn smooth in one narrow band where a hundred people a week have leaned to sign something they had already decided to sign."
  },
  {
   "id": "stationer_counter_r",
   "kind": "prop",
   "cell": [6, 1],
   "display_name": "The Counter's End",
   "sprite": "counter_right",
   "observe": "A brass bell nobody rings, a blotter, and a small mirror angled so the man behind the counter can watch the door without appearing to."
  },
  {
   "id": "stationer_wax_tray",
   "kind": "prop",
   "cell": [10, 5],
   "display_name": "A Tray of Sealing Wax",
   "sprite": "crate",
   "observe": "Nine colours of wax and one blank seal for hire. The blank is the most used thing in the shop, by a distance."
  },
  {
   "id": "stationer_contract_shelf",
   "kind": "prop",
   "cell": [1, 5],
   "display_name": "A Shelf of Blank Contracts",
   "sprite": "library_shelf",
   "observe": "Printed forms with the terms left open, sorted by how badly the second party will want to argue later. The thickest stack is the most reasonable-looking one."
  },
  {
   "id": "stationer_scribe_desk",
   "kind": "prop",
   "cell": [9, 3],
   "display_name": "The Scribe's Desk",
   "sprite": "library_desk",
   "observe": "A desk set at an angle that lets the scribe see the street and the street see nothing. There is a second chair, and it has been sat in recently."
  },
  {
   "id": "stationer_stove",
   "kind": "prop",
   "cell": [10, 1],
   "display_name": "A Small Iron Stove",
   "sprite": "barrel",
   "observe": "Banked low, kept alive all day. Paper hates damp and this street sits in the river's breath every morning."
  }
 ]
}
```

- [x] **Step 2: Non-quest observables audit.** Eight `observe`-carrying props plus a second talk-pool NPC (`stationer_clerk`) all stay live after `setting_commissioned` banks — comfortably over the spec's ≥3 bar (spec:172-174).
- [x] **Step 3: Sprite check — the ids above are already corrected; re-prove them, do not re-pick them.** The first draft shipped `"sprite": "table"` and `"sprite": "bookshelf"`, **neither of which is registered** — `data/sprites.json` has 278 entries and neither name is among them, and **nothing in the suite validates a map entity's sprite id** (`tests/test_combat_visuals.gd:21` checks *arena* decor only; `scripts/data_lint.py` check 5 only asserts each `sprites.json` entry has non-empty `animations`). It would have shipped GREEN and rendered as missing art. The corrected picks, all verified registered:

  | Entity | First draft | **Ships** | Why |
  |---|---|---|---|
  | `stationer_counter_l` | `table` ✗ | `counter_left` | literally a shop counter |
  | `stationer_counter_r` | `table` ✗ | `counter_right` | pairs with the left half into one run |
  | `stationer_scribe_desk` | `table` ✗ | `library_desk` | literally a desk |
  | `stationer_contract_shelf` | `bookshelf` ✗ | `library_shelf` | literally a shelf of forms |

  Re-verify each with `python3 -c "import json,sys; d=json.load(open('wandering_inn_game/data/sprites.json')); s=d.get('sprites',d); print([k for k in sys.argv[1:] if k not in s])" door pc_human_f human_laborer crate barrel counter_left counter_right library_desk library_shelf table_brown stool rug_tan window_blue sconce plant_pot` — expect `[]`. **Substitute a registered sibling rather than adding a sprite row** (the `seal_vault` precedent added zero sprite entries); if a stand-in compromises legibility, say so in that **entity's** `_comment` in one line. None of the four above is a compromise, so none carries a note.
- [x] **Step 4: Wall/blocked double-listing check.** `blocked` must contain **only** `[4,5]` (the writing table, which has its own `decor` row). If any perimeter cell appears in `blocked`, delete it — `wi_game.gd:140-143` already blocks every wall segment cell, and a double-listed cell is exactly what makes the biome prop pool fire on a wall.
- [x] **Step 5: Run** `python3 wandering_inn_game/scripts/data_lint.py` (grid + in-grid cells) and `perl -e 'alarm 240; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_content.gd` — expect PASS. `_validate_npc_interact_surface` will red an empty `talk_pool`; both NPCs carry real ones.
- [x] **Step 6: Scene-dynamism advisory** (the other three lanes each carry this step; the first draft of this one did not):

```
perl -e 'alarm 300; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd
```

  Read the scorecard row for `stationer`. **Target composite ≥ 50**; a score under 30 prints a loud advisory and means "brown box — fix before spending a windowed screenshot on it." The component breakdown says what to add: low internal variety → pull decor from a second pack family (the drafted decor deliberately mixes `props/free_pack` furniture with the Library-pack desk/shelf sprites), low composition → dress the border band and add an off-centre focal light (the `sconce` at (4,1)), low cross-scene distinctiveness → the `floor_layers` pick is the lever. The tool regenerates `docs/design/scene-dynamism-report.md` deterministically; commit the regenerated report with the map.
- [x] **Step 7: Commit** `feat(invrisil): the stationer's, a small working interior (#306)`.

### Task 1.4: `data/maps/invrisil/adventurers_rest.json`

**Files:**
- Create: `wandering_inn_game/data/maps/invrisil/adventurers_rest.json`

**Interfaces:**
- Consumes: the (18,1) door (Task 1.2), counter `hat_job_taken` (Task 3.2).
- Produces: map key `adventurers_rest`; hosts I2's three route surfaces (Task 3.3) plus the ambient cast.

**Layout spec — same `riverfarm_longhouse.json` template as Task 1.3, and here it is load-bearing.** Grid **13×9** (under parlor scale). Biome **`inn`** (reused — plank common-hall read; **no `data/biomes.json` edit**).

**THE BUG THE FIRST DRAFT SHIPPED:** `data/biomes.json` `inn.blocked_props = ["crate", "barrel"]`. A raw 39-cell perimeter ring in this biome renders **39 crates and barrels where the walls should be** — `tile_board_builder.gd:24-31` pools a prop onto every blocked cell that is not `segment_covered` / `cover_skip` / `authored_covered`, and with no `walls` and no `decor` all 39 qualify. `tests/test_world_visuals.gd:130-166` **passes** it (39 is far under the 200-cell budget and the `fallback` list is empty), so it ships green and looks like a warehouse. Every shipped `inn`-biome interior dodges it with walls: `data/maps/inn/inn.json` = walls + 8 `blocked`; `riverfarm_longhouse.json` = walls + 4 `blocked`.

Same three rules as Task 1.3: **`walls.segments`** carries the perimeter and is **never double-listed in `blocked`**; **`blocked`** is furniture only, every cell with a matching **`decor`** row; plus **`floor_layers`** and an **`ambience`** preset.

Perimeter segments (13 wide, 9 tall, door gap at **[6,8]**): row 0 `[0,0]→[12,0]`; col 0 `[0,1]→[0,8]`; col 12 `[12,1]→[12,8]`; row 8 left `[1,8]→[5,8]`; row 8 right `[7,8]→[11,8]`. Same 39 cells, now carried by the wall builder instead of the prop pool.

**Arrival cells, hand-verified both directions:**
- boulevard (18,1) → rest **(6,7)**: interior floor, unblocked, no entity. ✔
- rest (6,8) → boulevard **(18,2)**: open boulevard floor (row 2 is otherwise clear; the row-3 pillars are at x 4/10/16/22, so nothing crowds the landing). ✔

- [x] **Step 1: Author the file:**

```json
{
 "_comment": "v0.16 I2 (#306). Walk-in only. Biome `inn` + every sprite reused. Perimeter is walls.segments (NEVER also in `blocked`) -- a raw blocked ring in this biome renders 39 crates. `blocked` is furniture only, each cell with a decor row. Plates + bravos gate on hat_job_taken.",
 "biome": "inn",
 "grid": { "width": 13, "height": 9 },
 "blocked": [
  [8,1]
 ],
 "floor_layers": [
  {
   "_pick": "#225 floor differentiation (census-FREE key). The `inn` biome default is Erin's own light tavern plank [1,21] -- shipping it here would make the Rest read as a second Wandering Inn, which is the exact `brothers_parlor` pre-#49 smell. Reuses riverfarm_longhouse's darker, rougher timber swatch off the SAME Interior_Walls_01 sheet ([12,21]/[13,21]/[12,22]/[13,22], rgb~87,64,49): same wood family, same license, footstep-wood stays honest, and the hall reads as one that has been walked on harder than Erin's. Different city from the longhouse, same board -- an acceptable reuse for a working common hall.",
   "sheet": "res://assets/props/free_pack/Interior_Walls_01.png",
   "tile_px": 16,
   "variants": [[12,21],[13,21],[12,22],[13,22]],
   "cells": "all"
  }
 ],
 "walls": {
  "sheet": "res://assets/props/free_pack/Interior_Walls_01.png",
  "tile_px": 16,
  "segments": [
   { "from": [0,0], "to": [12,0], "cap": [14,6], "face": [14,7] },
   { "from": [0,1], "to": [0,8], "cap": [14,6] },
   { "from": [12,1], "to": [12,8], "cap": [14,6] },
   { "from": [1,8], "to": [5,8], "cap": [14,6] },
   { "from": [7,8], "to": [11,8], "cap": [14,6] }
  ]
 },
 "decor": [
  { "sprite": "barrel", "cell": [8,1] },
  { "sprite": "bench", "cell": [3,5] },
  { "sprite": "bench", "cell": [4,5] },
  { "sprite": "stool", "cell": [8,4] },
  { "sprite": "rug_green", "cell": [6,5], "tint": [0.42, 0.35, 0.3] },
  { "sprite": "sconce", "cell": [4,1], "light": { "color": [1.0, 0.75, 0.4], "energy": 0.7, "radius": 26, "flicker": true } },
  { "sprite": "sconce", "cell": [9,7], "light": { "color": [1.0, 0.75, 0.4], "energy": 0.7, "radius": 26, "flicker": true } },
  { "sprite": "unlit_lantern", "cell": [11,4] }
 ],
 "ambience": [
  { "preset": "dust_motes", "rect": "all", "phase": ["dusk", "night"] }
 ],
 "entities": [
  {
   "id": "adventurers_rest_to_boulevard",
   "kind": "door",
   "cell": [6, 8],
   "display_name": "Out to the Boulevard",
   "sprite": "door",
   "to_map": "invrisil_boulevard",
   "to_cell": [18, 2]
  },
  {
   "_comment": "I2 TALK route surface (three exchanges, the trade never named).",
   "id": "rest_house_factor",
   "kind": "npc",
   "cell": [6, 1],
   "display_name": "The House Factor",
   "sprite": "human_laborer",
   "tint": [0.44, 0.42, 0.5],
   "facing": "down",
   "observe": "He keeps the ledger of who is owed a table rather than who is owed money, which in this house is the more delicate book. He has not written anything down since you came in.",
   "talk_pool": [
    "Long table's for people waiting on somebody. This one's for people who've already arrived.",
    "Silver rank drinks free on the night they make it. Once. We've never had to say it twice."
   ],
   "conversation": "invrisil_rest_factor"
  },
  {
   "id": "rest_gnoll_ranger",
   "kind": "npc",
   "cell": [3, 6],
   "display_name": "A Gnoll with a Bad Ankle",
   "sprite": "gnoll_traveler",
   "facing": "right",
   "observe": "Boot off, ankle up on the bench, and a bowl of something going cold while she tells the story properly rather than quickly.",
   "talk_pool": [
    "Two seasons out of Liscor and every job north of it wanted a Gnoll who could track. None of them wanted to pay one.",
    "Ankle's fine. Ankle's been fine for a month. The bench is the good part.",
    "Nobody in here asks what you're carrying. That's not manners, it's arithmetic."
   ]
  },
  {
   "id": "rest_quiet_drinker",
   "kind": "npc",
   "cell": [10, 4],
   "display_name": "A Man Not Drinking",
   "sprite": "pc_human_m",
   "tint": [0.4, 0.4, 0.44],
   "facing": "left",
   "observe": "A full cup, untouched, at his right hand, and his chair turned three degrees off the table so he can see both doors without turning his head.",
   "talk_pool": [
    "I'll finish it before I go. I always do.",
    "You get the corner or you get the door. Corner's better. Door's honest."
   ]
  },
  {
   "id": "rest_hearth",
   "kind": "prop",
   "cell": [2, 1],
   "display_name": "The Hearth",
   "sprite": "hearth",
   "light": { "color": [1.0, 0.62, 0.32], "energy": 1.1, "radius": 40, "flicker": true },
   "observe": "Built for a bigger room than this one, and kept fed accordingly. The chairs nearest it are the worst chairs in the house and they are always taken."
  },
  {
   "_comment": "Stand-in: library_shelf is the only registered rack; the kit reads from display_name + observe, not the silhouette.",
   "id": "rest_trophy_rack",
   "kind": "prop",
   "cell": [10, 1],
   "display_name": "A Rack of Retired Kit",
   "sprite": "library_shelf",
   "observe": "Bows, a cracked buckler, one very good spear. Nothing here was donated. Every piece was left behind by somebody who did not come back for it, and the house does not say which."
  },
  {
   "id": "rest_bar_counter_l",
   "kind": "prop",
   "cell": [7, 1],
   "display_name": "The Counter",
   "sprite": "bar_counter",
   "observe": "Elbow-polished to a shine along its whole length except one arm's width at the far end, which is somebody's, permanently."
  },
  {
   "id": "rest_long_bench",
   "kind": "prop",
   "cell": [4, 4],
   "display_name": "The Long Table",
   "sprite": "table_brown",
   "observe": "Long enough for a full company and set for four. The house leaves it that way on purpose, and everybody in the room has noticed and nobody mentions it."
  },
  {
   "id": "rest_rank_notice",
   "kind": "prop",
   "cell": [11, 6],
   "display_name": "The Rank Board",
   "sprite": "request_board",
   "observe": "Names in three columns, and a fourth column with no heading. The fourth column is shorter than it was last season and nobody has rubbed it out."
  },
  {
   "_comment": "#204 plate NEAR: hanging the hat is the signal. Gated with the FAR plate so the pair cannot bank out of order. Stand-in sprite hat_stand -- no peg rail is registered; a stand reads close and the toast carries the beat.",
   "id": "rest_hat_hook",
   "kind": "prop",
   "cell": [1, 7],
   "display_name": "The Peg Rail",
   "sprite": "hat_stand",
   "present_when": { "requires": { "hat_job_taken": 1 } },
   "observe": "Nine pegs. Eight have hats. The third from the left is empty and has been wiped, which is not the same as being unused.",
   "on_interact_accomplishment": "hat_hook_set",
   "toast": "You hang your hat on the third peg, brim out, the way the house does it. Across the room a man you have not looked at stops not looking at you."
  },
  {
   "_comment": "#204 plate FAR = SECOND: banks handoff_quiet ONLY via the variant (hook first); base is wrong-order cold feedback. Zero new sim code.",
   "id": "rest_corner_table",
   "kind": "prop",
   "cell": [11, 2],
   "display_name": "The Corner Table",
   "sprite": "table_brown",
   "present_when": { "requires": { "hat_job_taken": 1 } },
   "observe": "A coat over the chair back, good cloth, nobody in it. The table has two cups and one of them has been sitting there since before you arrived.",
   "on_interact_accomplishment": "handoff_mistimed",
   "toast": "You set it down on a table nobody has claimed and it sits there being a package. Behind you a chair turns a quarter inch, so you pick it back up.",
   "variants": [
    {
     "when": { "hat_hook_set": 1 },
     "accomplishment": "handoff_quiet",
     "toast": "The coat is already over the chair back. You lay yours beside it, take the wrong one on the way past, and nobody in this room has raised a voice or an eye."
    }
   ]
  },
  {
   "_comment": "I2 FIGHT: INTERACT-ONLY (no trigger_radius) so it cannot spring on a pinned route. New ids only -- no shared combatant is retuned.",
   "id": "rest_bravos",
   "kind": "encounter",
   "cell": [9, 6],
   "display_name": "Three at the Far Table",
   "sprite": "hired_blade",
   "observe": "Three men at the far table who arrived together, ordered separately, and have been agreeing with each other about nothing for an hour.",
   "arena": "merchant_warehouse",
   "enemies": ["rest_bravo_a", "rest_bravo_b"],
   "allies": [],
   "on_victory": "handoff_loud",
   "encounter_when": { "requires": { "hat_job_taken": 1 } },
   "gate_closed_toast": "Three men at the far table are having a conversation you are not in. Tonight, that is all they are."
  }
 ]
}
```

- [x] **Step 2: Non-quest observables audit.** `rest_hearth`, `rest_trophy_rack`, `rest_bar_counter_l`, `rest_long_bench`, `rest_rank_notice` (five) plus three talk-pool NPCs are ungated and survive `hat_job_done` — the room is a real ambient interior afterwards, per spec:98-100.
- [x] **Step 3: Sprite check — corrected picks, re-prove them.** Same failure mode as Task 1.3 Step 3 (`table`/`bookshelf` are not registered and nothing gates it). The corrected picks:

  | Entity | First draft | **Ships** | Note |
  |---|---|---|---|
  | `rest_hearth` | `barrel` ✗ (a hearth drawn as a barrel) | `hearth` | + the longhouse's shipped `light` dict — entities carry `light` (`src/world/world.gd:759`) |
  | `rest_bar_counter_l` | `table` ✗ | `bar_counter` | it is literally a bar |
  | `rest_long_bench` | `table` ✗ | `table_brown` | the long table |
  | `rest_corner_table` | `table` ✗ | `table_brown` | the FAR plate |
  | `rest_trophy_rack` | `bookshelf` ✗ | `library_shelf` | **stand-in — carries a one-line entity `_comment`** |
  | `rest_rank_notice` | `bookshelf` ✗ | `request_board` | a board of names; no compromise |
  | `rest_hat_hook` | `bookshelf` ✗ | `hat_stand` | **stand-in — carries a one-line entity `_comment`.** A peg rail reading as a library shelf was the legibility bounce the windowed pass would have caught; `hat_stand` is the registered near-miss and the toast carries the beat. |

  Re-verify with the same one-liner as Task 1.3 Step 3 over: `door gnoll_traveler pc_human_m human_laborer hired_blade hearth bar_counter table_brown library_shelf request_board hat_stand barrel bench stool rug_green sconce unlit_lantern` — expect `[]`.
- [x] **Step 4: Wall/blocked double-listing check.** `blocked` must contain **only** `[8,1]` (the barrel behind the counter, which has its own `decor` row). No perimeter cell may appear in `blocked`. Confirm no `decor` cell collides with an `entities` cell (double-draw): decor sits at (8,1)/(3,5)/(4,5)/(8,4)/(6,5)/(4,1)/(9,7)/(11,4); entities at (6,8)/(6,1)/(3,6)/(10,4)/(2,1)/(10,1)/(7,1)/(4,4)/(11,6)/(1,7)/(11,2)/(9,6) — disjoint. ✔
- [x] **Step 5: `present_when` shape check.** `_validate_present_when` (`test_content.gd:749-801`) allows `requires`/`phase`/`absent`/`guest` and **forbids `present_when` on `kind: "encounter"`** — the bravos correctly use `encounter_when` instead.
- [x] **Step 6: Fixture-cell sanity.** `invrisil_hat_quiet_start` stands at (2,7) facing (1,7) — the hat stand — and `invrisil_hat_loud_start` at (9,5) facing (9,6) — the bravos. Both facing cells are interior floor and neither is in `blocked` or on a wall segment. ✔
- [x] **Step 7: Run** `data_lint.py` + `test_content.gd`, then the **scene-dynamism advisory** from Task 1.3 Step 6 and read the `adventurers_rest` row (target composite ≥ 50). **Commit** `feat(invrisil): the Adventurer's Rest common hall (#306)`.

### Task 1.5: Mood rows, landmarks, map gates, population floors

**Files:**
- Modify: `wandering_inn_game/data/moods.json` (append under `moods`)
- Modify: `wandering_inn_game/tests/test_content.gd` (`LANDMARK_TOKENS` `:1332-1363`; `POPULATION_FLOORS` `:532-541`)
- Modify: `wandering_inn_game/tests/test_fixture_coherence.gd` (`MAP_REQUIRES` `:31-53`)

**Interfaces:**
- Produces: the map-side consts every later task's beats and fixtures depend on.

- [x] **Step 1: `data/moods.json`** — insert **immediately after the `brothers_parlor` key**, per controller ruling C (`pallass_forge` is the file's LAST key and all four lanes would otherwise add a comma to the same closing brace; the four anchors are `floodplains` / `witch_hollow` / `brothers_parlor` / `pallass_forge`). No test enforces mood rows; a missing row renders flat identity-white at every phase and ships green, so it is a real visual defect:

```json
  "stationer": {
   "_comment": "Paper-warm and a shade cooler than the parlor: lamplight on rag paper, not on brandy.",
   "day": [0.86, 0.82, 0.72],
   "dusk": [0.86, 0.82, 0.72],
   "night": [0.86, 0.82, 0.72],
   "vignette": 0.30
  },
  "adventurers_rest": {
   "_comment": "Common-hall amber, one notch under the inn's: a bigger hearth in a smaller room.",
   "day": [0.88, 0.76, 0.60],
   "dusk": [0.88, 0.76, 0.60],
   "night": [0.88, 0.76, 0.60],
   "vignette": 0.36
  },
```

- [x] **Step 2: `LANDMARK_TOKENS`** — insert **after the `"mercantile_alleys"` row** (ruling C anchor; a beat whose producer map has no row **hard-fails** at `test_content.gd:1475`):

```gdscript
	# v0.16 Invrisil (#306): both new interiors take their own token plus the
	# region token -- the 2026-07-26 widening that gave invrisil_boulevard and
	# mercantile_alleys "invrisil" (brothers_parlor still carries only "parlor").
	"stationer": ["stationer", "invrisil"],
	"adventurers_rest": ["adventurer", "invrisil"],
```

`"adventurer"` (not `"rest"`) is the token deliberately: `_description_names_place` is a lowercase substring test, and `"rest"` matches *interest*, *restore*, *arrested*. `"adventurer"` matches "the Adventurer's Rest" and nothing accidental.

- [x] **Step 3: `MAP_REQUIRES`** in `test_fixture_coherence.gd` — insert **after the `"mercantile_alleys"` row** (ruling C anchor):

```gdscript
	"stationer": ["door_awakened", "invrisil_attuned"],
	"adventurers_rest": ["door_awakened", "invrisil_attuned"],
```

Both interiors are reachable only off `invrisil_boulevard`, which already carries exactly that pair — a fixture standing inside without it is a position no player can occupy.

- [x] **Step 4: `POPULATION_FLOORS`** — insert **after the `"invrisil_boulevard"` row** (ruling C anchor). The first draft wrote `11` for both and said "derive it from a real run"; **both halves of that were wrong.** `adventurers_rest` is **10**, and a run prints no number to read — `_validate_population_floors` (`test_content.gd:571-576`) only fires `_check` on **failure**, so a green run is silent and an over-high floor is a `CONTENT_FAIL`, not a printout.

  **Count it deterministically instead** (`test_content.gd:546-568`, transcribed as a rule):
  1. Skip **every** entity that has a `present_when` key. Nothing else exempts a row.
  2. For each surviving entity: `+1` if `kind` is `"door"` **or** `"encounter"` (and stop — do not also count its keys).
  3. Otherwise `+1` if it carries **any** member of `INTERACTABLE_KEYS`: `observe`, `toast`, `conversation`, `talk_pool`, `dialogue`, `on_interact_accomplishment`, `requires_skill`, `sleep`, `board`, `delivery_board`, `portal_menu`, `fence_menu`, `contains`.
  4. **`encounter_when` does NOT exempt a row** — only `present_when` does. This is exactly where the first draft's arithmetic broke.
  5. `decor` rows are not entities and never count.

  **`stationer` = 11.** Eleven entities, **none** with `present_when`: `stationer_to_boulevard` (door) 1; `stationer_client` 2; `stationer_clerk` 3; `stationer_ruled_paper` 4; `stationer_ink_rank` 5; `stationer_counter_l` 6; `stationer_counter_r` 7; `stationer_wax_tray` 8; `stationer_contract_shelf` 9; `stationer_scribe_desk` 10; `stationer_stove` 11.

  **`adventurers_rest` = 10.** Twelve entities, **two** skipped for `present_when` (`rest_hat_hook`, `rest_corner_table`): `adventurers_rest_to_boulevard` (door) 1; `rest_house_factor` 2; `rest_gnoll_ranger` 3; `rest_quiet_drinker` 4; `rest_hearth` 5; `rest_trophy_rack` 6; `rest_bar_counter_l` 7; `rest_long_bench` 8; `rest_rank_notice` 9; `rest_bravos` (kind `encounter`; its `encounter_when` gate does **not** exempt it) 10.

```gdscript
	# v0.16 Invrisil (#306). Counted by the test's own rule, not guessed: skip
	# present_when rows only (hat hook + corner table), +1 per door/encounter,
	# +1 per INTERACTABLE_KEYS carrier. encounter_when does NOT exempt a row.
	"stationer": 11,
	"adventurers_rest": 10,
```

  Floors are **minimums**, so under-stating one is safe and over-stating one reds `test_content.gd` on the first run. If a later step adds or window-gates an entity in either room, re-run this count **in the same commit**.

- [x] **Step 5: Run** `test_content.gd` + `test_fixture_coherence.gd` — expect PASS on both. **Commit** `feat(invrisil): mood, landmark, gate and floor rows for the two new interiors (#306)`.

---

## Phase 2 — I1 "A Setting for a Lady"

### Task 2.1: `data/quests.json` — the `a_setting_for_a_lady` block

**Files:**
- Modify: `wandering_inn_game/data/quests.json` (TAB-indented; insert **immediately after the `a_gentlemans_disagreement` object** per ruling C, not at the end of the array — `splice_json.py --container quests` appends, so splice and then move the block to the anchor, or hand-place it and re-run `data_lint.py`)

**Interfaces:**
- Produces: quest id `a_setting_for_a_lady`. Tasks 2.2–2.5 bank every counter it names.

- [x] **Step 1: Splice the block:**

```json
{
	"_comment": "v0.16 I1 (#306). Giver is the stationer client (ruling 1). `resolve` is a travel beat (producers on mercantile_alleys, giver on stationer) so it names the alleys; `report` produces on the giver's own map.",
	"id": "a_setting_for_a_lady",
	"title": "A Setting for a Lady",
	"region": "Invrisil",
	"beats": [
		{ "id": "resolve", "description": "Hedault keeps a bench in the alleys and will not set the stone until somebody says the true thing about it. Tell him, read the ward at his bench, or find out who took the original.", "complete_when_any": { "heirloom_truth_kept": 1, "setting_assisted": 1, "original_recovered": 1 } },
		{ "id": "report", "description": "Go back to the woman with the ring box and tell her how it ended.", "complete_when": { "setting_commissioned": 1 } }
	],
	"_resolution_order": "Weakest claim first (src/core/quests.gd:82-87); LAST MATCH WINS among real rungs, so a completionist reads as the strongest deed: setting_assisted (you helped) < heirloom_truth_kept (you brokered the truth) < original_recovered (you brought back the real stone). No \"\"-fallback rung -- the handover option is gated on holding at least one route counter, so setting_commissioned cannot bank without one.",
	"resolution_paths": [
		{ "accomplishment": "setting_assisted", "text": "You stood at Hedault's bench and read the ward-line with him. He did not correct you, which from him is a reference.", "grant": { "observed_things": 2, "heard_gossip": 2 } },
		{ "accomplishment": "heirloom_truth_kept", "text": "You said the true thing about the stone out loud so she would never have to, and the setting was made honest around it.", "grant": { "persuaded_someone": 2, "heard_gossip": 3 } },
		{ "accomplishment": "original_recovered", "text": "Forty years after somebody swapped it, you took the original back off a fence's shelf and put it in her hands.", "grant": { "melee_hit": 6, "won_combat": 1 } }
	]
}
```

- [x] **Step 2: Verify the travel-beat arithmetic by hand.** `_quest_giver_maps` resolves the giver from the map hosting the conversation that fires `{"quest": "a_setting_for_a_lady"}` → `stationer`. `resolve`'s three producers all live on `mercantile_alleys` (Hedault's conversation is hosted there; the fence encounter is placed there in Task 2.5), so the beat **needs** a landmark and `"alleys"` is in `LANDMARK_TOKENS["mercantile_alleys"]`. ✔ `report`'s producer is the giver's own map → no landmark required. ✔
- [x] **Step 3: `_comment` census discipline** — the one `_comment` string above is the whole quest-block charge. The ladder rationale lives in **`_resolution_order`**, which `comment_census.py` does **not** charge (it keys on `_`-prefixed keys containing `comment`), and `test_quests.gd:133-142` requires exactly that key for any array with ≥2 real rungs. Do **not** re-add `_resolution_paths_comment` — it is charged, and it is optional (one shipped quest carries it; ten do not). Anything longer goes to `docs/CHOICE-LOG.md`.
- [x] **Step 4: Run** `test_content.gd` (`_validate_quests` cross-refs every `complete_when`/`complete_when_any` counter against real producers — it will red until Tasks 2.2–2.5 land, which is expected; land those first if you prefer a green-at-every-commit ladder) and `test_quests.gd`.
- [x] **Step 5: Commit** `feat(quests): A Setting for a Lady (#306)`.

### Task 2.2: `data/dialogue/invrisil_stationer_client.json` — the giver

**Files:**
- Create: `wandering_inn_game/data/dialogue/invrisil_stationer_client.json`
- Modify: `wandering_inn_game/data/items.json` (Task 2.4 owns the row; this graph references it)

**Interfaces:**
- Produces: quest start, `heirloom_commission_started`, `setting_commissioned`, item `plum_silk_locket`, 25 gold.

**Voice:** composed, exact about money, unsentimental about the stone and completely sentimental about the setting. Her register is transactional-Invrisil (`city-identity-bible.md:15` — the city's word is DEAL) but she is the one person on the street who is buying something that cannot be priced.

- [x] **Step 1: Author the graph:**

```json
{
 "_comment": "v0.16 I1 giver (#306, ruling 1). Three route arms converge on `handover`, which carries the only grant, so the reward cannot double-fire. Every gated node keeps an ungated exit.",
 "start": "commission",
 "nodes": {
  "commission": {
   "speaker": "A Woman with a Ring Box",
   "text": "I have been sitting in a paper shop for an hour, because a paper shop is the only room on this street where a woman may hold something closed and nobody asks her to open it.",
   "text_variants": [
    {
     "requires": { "accomplishment": { "heirloom_commission_started": 1 } },
     "text": "You went, then. Sit down and tell me what he said, and please tell me the whole of it. I have had forty years of the polite half."
    },
    {
     "requires": { "accomplishment": { "setting_commissioned": 1 } },
     "text": "It sits differently on the chain. I noticed before I looked. Thank you for the part of that which was not the silver."
    }
   ],
   "options": [
    {
     "text": "\"What is it you're holding?\"",
     "hide_when": { "accomplishment": { "heirloom_commission_started": 1 } },
     "effects": [
      { "quest": "a_setting_for_a_lady" },
      { "accomplishment": "heirloom_commission_started" }
     ],
     "goto": "the_stone"
    },
    {
     "text": "\"He'll set it. He wanted the true thing said first, and it's said.\"",
     "requires": { "accomplishment": { "heirloom_truth_kept": 1 } },
     "hide_when": { "accomplishment": { "setting_commissioned": 1 } },
     "goto": "handover"
    },
    {
     "text": "\"I stood at his bench while he laid the ward. It's set properly.\"",
     "requires": { "accomplishment": { "setting_assisted": 1 } },
     "hide_when": { "accomplishment": { "setting_commissioned": 1 } },
     "goto": "handover"
    },
    {
     "text": "\"Your mother's stone was real. I have it back.\"",
     "requires": { "accomplishment": { "original_recovered": 1 } },
     "hide_when": { "accomplishment": { "setting_commissioned": 1 } },
     "goto": "handover"
    },
    { "text": "\"Another time.\"", "end": true }
   ]
  },
  "the_stone": {
   "speaker": "A Woman with a Ring Box",
   "text": "My mother's. The stone in it is glass. I have known since I was nineteen and I have never once said so out loud, and I am not going to begin by saying it to a jeweller who will write it on an order.",
   "options": [
    { "text": "\"Then why have it set at all?\"", "goto": "why_keep" },
    { "text": "\"Who's refusing the work?\"", "goto": "terms" }
   ]
  },
  "why_keep": {
   "speaker": "A Woman with a Ring Box",
   "text": "Because she wore it to every hard thing she ever did and it never once let her down. That part was never glass. That is the only part of it that was ever real, and it lives in the setting, not the stone.",
   "options": [
    { "text": "\"Who's refusing the work?\"", "goto": "terms" }
   ]
  },
  "terms": {
   "speaker": "A Woman with a Ring Box",
   "text": "There is an enchanter with a bench in the alleys who will not touch a piece until somebody in the transaction tells him the truth about it. He is right to insist and I cannot be the one who does it. Twenty five gold when it is set. Do not be charming at him.",
   "options": [
    { "text": "\"I'll tell him.\"", "end": true }
   ]
  },
  "handover": {
   "speaker": "A Woman with a Ring Box",
   "text": "Then it is done, and done in the open, which I did not expect and did not know I wanted. Here. My mother had a second piece, plain, honest, worth a tenth of the first and worn twice as often. I would rather it went to somebody who earned it than sat in a box being important.",
   "options": [
    {
     "text": "\"I'll take it.\"",
     "hide_when": { "accomplishment": { "setting_commissioned": 1 } },
     "effects": [
      { "accomplishment": "setting_commissioned" },
      { "item": "plum_silk_locket" },
      { "gold": 25 }
     ],
     "end": true
    },
    {
     "text": "\"Keep it. The work was the payment.\"",
     "hide_when": { "accomplishment": { "setting_commissioned": 1 } },
     "effects": [
      { "accomplishment": "setting_commissioned" }
     ],
     "end": true
    },
    { "text": "\"In a moment.\"", "end": true }
   ]
  }
 }
}
```

- [x] **Step 2: Grant-duplicate audit (ruling 6).** `plum_silk_locket` is a brand-new id with exactly one producer — this option — and the option is `hide_when`-guarded on the terminal it banks in the same array. Nothing force-consumes; nothing else in the game grants it.
- [x] **Step 3: Effect-verb audit.** Every effect dict above carries exactly one verb. Every gated node keeps an ungated option (`"Another time."`, `"In a moment."`). No `{skill, item}` compound anywhere.
- [x] **Step 4: Event-order note for QA (Task 5.x):** the two handover options carry **`effects` AND `end: true`** — `DIALOGUE_ENDED` fires synchronously **before** effects apply. QA scripts must wait `dialogue_ended` first, then `accomplishment_recorded`.
- [x] **Step 5: Run** `data_lint.py` (start/nodes/speaker/text/goto targets) + `test_dialogue.gd` + `test_content.gd`. **Commit** `feat(dialogue): the woman with the ring box (#306)`.

### Task 2.3: Hedault's commission surfaces

**Files:**
- Modify: `wandering_inn_game/data/dialogue/hedault_enchanting.json` (append one option to `hub.options` **last**, after the spine capstone arm at `:94-108`; add four nodes)

**Interfaces:**
- Consumes: `heirloom_commission_started`.
- Produces: `heirloom_truth_kept`, `setting_assisted`; points at the fence for the FIGHT route.

**Voice contract** (ruling 8 — no profile exists yet; write against these two sources): `docs/design/hedault-enchanting-spec.md:8-11` — "exacting, humorless, hates being touched, fair to a fault. ATTESTED canon-native. His services are priced formally; no haggling." — plus the in-file contract at `hedault_enchanting.json:2`: "Canon voice: exacting, formal, no haggling, hates being touched. Book-17 bar: no Vol 8+ content." His shipped register: imperatives, no pleasantries, prices stated as facts, refuses to speculate outside his trade ("I will not speculate further in a shop").

- [x] **Step 1: Append the hub option LAST** (authored index 6, after the spine capstone):

```json
    {
     "_comment": "v0.16 I1 (#306, ruling 1). Appended LAST and accomplishment-gated, so it is HIDDEN in hedault_fragment_start and spine_reach_start -- the 5-row options pin and spine_reach's blind `move down 5` both stay exact, zero re-pins.",
     "text": "A lady's heirloom. She was told you'd refuse it.",
     "requires": {
      "accomplishment": {
       "heirloom_commission_started": 1
      }
     },
     "hide_when": {
      "accomplishment": {
       "setting_commissioned": 1
      }
     },
     "goto": "heirloom_bench"
    }
```

- [x] **Step 2: Add the four nodes** to `nodes`:

```json
  "heirloom_bench": {
   "speaker": "Hedault",
   "_comment": "He will not work until the lie is named. The two SKILL arms are SEPARATE single-key options (test_content rejects {skill, item} -- pisces_seal.json:112).",
   "text": "Set it on the cloth. Do not hand it to me. I have looked at it twice already and I will not cut a mount until somebody in this transaction says the true thing out loud: that stone is glass, cut well, sold badly, and about forty years old. I do not work around a lie. I work around a fact, and I invoice for the work.",
   "options": [
    {
     "text": "\"She knows. She's known since she was nineteen. It's the setting she wants honest.\"",
     "hide_when": { "accomplishment": { "heirloom_truth_kept": 1 } },
     "effects": [ { "accomplishment": "heirloom_truth_kept" } ],
     "goto": "heirloom_truth"
    },
    {
     "text": "[Appraise Goods] Read it out with him, weight by weight.",
     "requires": { "skill": "appraise_goods" },
     "hide_when": { "accomplishment": { "setting_assisted": 1 } },
     "effects": [ { "accomplishment": "setting_assisted" } ],
     "goto": "bench_assist"
    },
    {
     "text": "[Detect Magic] Follow the ward-line to where it wants to sit.",
     "requires": { "skill": "detect_magic" },
     "hide_when": { "accomplishment": { "setting_assisted": 1 } },
     "effects": [ { "accomplishment": "setting_assisted" } ],
     "goto": "bench_assist"
    },
    {
     "text": "\"Somebody swapped it. Who buys a stone like that?\"",
     "hide_when": { "accomplishment": { "original_recovered": 1 } },
     "goto": "fence_pointer"
    },
    { "text": "\"I'll come back with an answer.\"", "end": true }
   ]
  },
  "heirloom_truth": {
   "speaker": "Hedault",
   "text": "Good. Then it goes on the order in those words and the price changes, downward, because glass takes less holding than a stone does. A mount for glass is not a lesser commission. It is a different one, and I would rather be told than discover it at the bench.",
   "options": [
    { "text": "\"She'll be glad of the price.\"", "end": true }
   ]
  },
  "bench_assist": {
   "speaker": "Hedault",
   "text": "Stand where I put you and keep your hands flat on the cloth. Now read it back to me. If you are right I will not say so; I will simply not correct you, and you may take that as the same thing. There. The ward wants to sit under the setting, not around the stone. It always did.",
   "options": [
    { "text": "\"Understood.\"", "end": true }
   ]
  },
  "fence_pointer": {
   "speaker": "Hedault",
   "_comment": "Pointer only -- banks nothing; the FIGHT counter comes off the alley encounter's on_victory.",
   "text": "Forty years ago somebody took the stone and left the glass, and did it well enough that the family never thought to ask. A stone like that is sold twice in this city and kept once. There is a man with a back door off the alleys and a ledger he would not show the Watch. I do not go there. I am telling you where it is, and that is the entire extent of my involvement.",
   "options": [
    { "text": "\"That's enough.\"", "end": true }
   ]
  }
```

- [x] **Step 3: Pin-stability proof (ruling 1) — run it, do not assume.**
  - `perl -e 'alarm 240; exec @ARGV' -- wandering_inn_game/qa/run_qa.sh hedault_fragment_loop headless --seed=<its manifest seed>` → the `options` array at `qa/scripts/hedault_fragment_loop.json:52` must still be exactly 5 rows (`payload_contains` compares arrays by SIZE FIRST, `qa/test_driver.gd:967-984`).
  - `wandering_inn_game/qa/run_qa.sh spine_reach headless --seed=<its manifest seed>` → the blind `move down 5` at `:365-370` must still land on the spine capstone.
  - Neither fixture can hold `heirloom_commission_started` (it is created in this PR), so both must be green **with zero edits**. If either reds, stop and report — the gate shape is wrong, not the pin.
- [x] **Step 4: Softlock guard** — `heirloom_bench` keeps `"I'll come back with an answer."` with neither `requires` nor `hide_when`. ✔
- [x] **Step 5: Run** `test_dialogue.gd` + `test_content.gd` + `data_lint.py`. **Commit** `feat(dialogue): Hedault will not set a lie (#306)`.

### Task 2.4: The reward item

**Files:**
- Modify: `wandering_inn_game/data/items.json` (TAB-indented; insert **immediately after the `hedaults_wardstone` row** per ruling C — `splice_json.py --container items` appends, so splice then move it to the anchor)

- [x] **Step 1: Splice the row.** Deliberately weaker than `hedaults_warded_setting` (hp 2 / dr 1 / res 1 / price 45) so the quest reward never outclasses the shipped enchanting swap:

```json
		{
			"id": "plum_silk_locket",
			"name": "A Plum-Silk Locket",
			"kind": "accessory",
			"weapon_family": "none",
			"damage_mod": 0,
			"hp_mod": 1,
			"damage_reduction": 0,
			"resonance": 1,
			"tier": "enchanted",
			"price": 30,
			"abilities": [],
			"description": "Plain silver on a plum ribbon, worn thin at the clasp by somebody who put it on every morning without thinking about it.",
			"lore": "The second piece, the honest one. It was never appraised, never insured and never once taken off for company, which in Invrisil makes it the rarer of the two."
		}
```

- [x] **Step 2: NO `{addr}` in this file** — `data/items.json` is in `ADDRESS_TOKEN_UNRESOLVABLE_FILES`; a token here renders raw and fails loud.
- [x] **Step 3: Run** `test_content.gd` + `test_items.gd` if present (`ls wandering_inn_game/tests/ | grep -i item`). **Commit** `feat(items): a plum-silk locket (#306)`.

### Task 2.5: The fence — combatants, encounter, harness cell

**Files:**
- Modify: `wandering_inn_game/data/combatants.json` (append 2 rows)
- Modify: `wandering_inn_game/data/maps/invrisil/mercantile_alleys.json` (append 1 encounter entity)
- Modify: `wandering_inn_game/tests/sim_combat_batch.gd` (`INVRISIL_CELLS` +1)

**Interfaces:**
- Consumes: `heirloom_commission_started`.
- Produces: `original_recovered`.

**Cell choice, justified against the recon's crowded-cell evidence.** `mercantile_alleys` is 20×14 with **225 blocked cells and 42 free** — an L-shaped corridor. Pinned/traversed cells: `invrisil_walkthrough` row 7 x1→7, (7,6)→(3,6), then the sneak leg row 6 x3→10, column x=10 y6→11, row 11 x10→18, (18,12); `invrisil_round_trip` (1,7)→(5,7). Shipped trigger zones: `alley_footpads_a` (9,9) r2 = x7–11 / y7–11; `alley_footpads_b` (14,12) r2 = x12–16 / y10–14.

**(11,12)** is free, is outside **both** trigger zones (y=12 is past a's y-ceiling of 11; x=11 is short of b's x-floor of 12), and is on **no** pinned cell. Its approach (11,11) is free. The encounter is **interact-only** (no `trigger_radius`, the `hired_blades` idiom) so it cannot spring on any route, sneaking or not.

- [x] **Step 1: Insert two combatant rows after the `hired_blade_knife_b` row** (ruling C anchor; 1-space-per-level; `splice_json.py --container combatants` appends, so splice then move to the anchor). **Ruling 5: brand-new ids — `alley_footpads_a/b` are removed by `invrisil_wilovan.json:100-104` on `brothers_job_done`, so they can be absent from any real save.**

```json
 {
  "_comment": "v0.16 I1 FIGHT (#306). NEW ids, never a retune of footpad_*/hired_blade_* -- those feed boulevard_duel_ring, both night loops and Invrisil's two ladder rungs. A distinct id IS the per-encounter override. Sprite reused from hired_blade; no combat_scale.",
  "id": "heirloom_fence",
  "power_level": 8.0,
  "display_name": "The Fence",
  "sprite": "hired_blade",
  "side": "enemy",
  "combat_tint": [0.62, 0.58, 0.42],
  "stats": { "str": 12, "dex": 12, "con": 26, "int": 8, "wis": 8, "cha": 12 },
  "weapon_die": 5,
  "ai": "melee",
  "skills": []
 },
 {
  "_comment": "Sprite human_laborer, the hired_blade_knife_b precedent -- registered and distinct at a glance from the fence.",
  "id": "fence_doorman",
  "power_level": 9.5,
  "display_name": "The Back Door",
  "sprite": "human_laborer",
  "side": "enemy",
  "combat_tint": [0.45, 0.45, 0.52],
  "stats": { "str": 14, "dex": 10, "con": 30, "int": 5, "wis": 6, "cha": 5 },
  "weapon_die": 6,
  "ai": "melee",
  "skills": ["power_strike"]
 }
```

- [x] **Step 2: Append the encounter entity** to `mercantile_alleys.json`:

```json
  {
   "_comment": "v0.16 I1 FIGHT (#306). INTERACT-ONLY (no trigger_radius) at (11,12): outside both shipped footpad trigger zones and off every pinned cell. Independent of the footpad rigs, so it is correct on a brothers_job_done save.",
   "id": "alley_fence_door",
   "kind": "encounter",
   "cell": [11, 12],
   "display_name": "A Back Door with a Ledger Behind It",
   "sprite": "door",
   "observe": "A door with no handle on this side and a fresh scrape where somebody's boot goes when their hands are full. The ledger inside is worth more than the stock.",
   "arena": "mercantile_alley",
   "enemies": ["heirloom_fence", "fence_doorman"],
   "allies": [],
   "on_victory": "original_recovered",
   "encounter_when": { "requires": { "heirloom_commission_started": 1 } },
   "gate_closed_toast": "A back door with no handle on this side. Nothing about it is any of your business tonight."
  }
```

`arena`, `enemies`, `allies`, `on_victory` are **all four** present (`test_combat_data.gd:116-117` asserts presence; `"allies": []` is mandatory). No `respawns`, so the fence is removed permanently on victory — correct for a one-shot recovery. No `scales` (a quest-counter `on_victory` may never scale).

- [x] **Step 3: Append the harness cell** to `INVRISIL_CELLS` (`solo: true` = no Wilovan; the loop hardcodes him as the ally when `solo` is false, `sim_combat_batch.gd:705-711`):

```gdscript
	# v0.16 I1 (#306). Side-quest fight at Invrisil's own expected level, SOLO
	# (Wilovan has no part in a stranger's commission). Window is the shipped
	# stop-cell precedent 0.55/0.95 (controller ruling A) -- a NARROW window is a
	# flaky gate, not a proof, so region-band ordering is evidenced by the
	# MEASURED median recorded in the PR body, not by the ceiling authored here.
	# New ids only: no shared combatant is retuned, so both hired_blades_* gates
	# and boulevard_duel_ring are untouched.
	{"name": "alley_fence_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["heirloom_fence", "fence_doorman"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
```

- [x] **Step 4: MEASURE FIRST, then keep or tune.** Get the cell index with `WI_CELL_COUNT_ONLY=1` and locate the new cell, then run just it:

```
WI_CELL_RANGE=<lo>:<hi> perl -e 'alarm 600; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
```

**Gate acceptance (ruling A):** `win_rate` inside **0.55–0.95** and `median_rounds` inside **3–12**.
**Design target, NOT a gate:** aim the measured `win_rate` at ≈ **0.62–0.70** so Invrisil still reads harder than Riverfarm. If it lands outside that band but inside the gate, tune **only the two new ids**, in this order: `+1 weapon_die` on `fence_doorman` → `+4 con` on both → `+1 str` (reverse if it lands low). After tuning, set each `power_level` so the pair stays monotone against the shipped roster (above `hired_blade_knife_*` 7.5, below `hired_blade_leader` 11.0). Record the final **measured** `win_rate` and `median_rounds` in the cell's comment, matching the shipped idiom ("Measured 0.64, median 7").
- [x] **Step 5: Re-gate the shared cells.** Run the **full** `INVRISIL_CELLS` range and confirm `hired_blades_t3_warrior10_wilovan` (0.57–0.71), `hired_blades_t5_sw14_wilovan` (0.77–0.87), `alley_footpads_w2_solo` (0.75–0.98) and `boulevard_duel_ring_t3_solo` (0.55–0.95) are all still in window. They must be untouched by construction — prove it anyway. **Record every measured median in the PR body**: per ruling A, the region-band ordering claim is carried by those numbers, not by a narrow window.
- [x] **Step 6: Board-figure bar — it does NOT measure these ids (ruling F).** `tests/test_combat_visuals.gd`'s `FIGURE_ROWS` (`:536-541`) holds exactly four sprites (`bat`, `briar_collector`, `briar_collector_deep`, `ruin_warden`); `_board_cells` (`:563-566`) indexes `FIGURE_ROWS[cfg["sprite"]]` and would **KeyError** on anything else, and the bar's only caller (`:609-620`) iterates a hardcoded `audited` array containing none of these ids. `hired_blade` and `human_laborer` are in neither structure. So: **no new sprite id and no `combat_scale`, therefore the bar is unchanged by construction and the suite passes by EXCLUSION — running it proves nothing about these four rows.** Run it anyway as a regression guard on the ids it *does* cover. The **windowed shots (Task 5.5 shot 7) are the legibility read** for the new rigs. The first draft's "3.05 cells" figure is **struck from the shipped `_comment`** — it exists only as prose in the bar's own doc comment (`:543`) and no run can confirm it. No id joins `audited` without first adding its sprite to `FIGURE_ROWS` with a re-derived row count.
- [x] **Step 7: Run** `test_combat_data.gd` (power_level presence, arena spawn reachability, encounter key presence), `test_content.gd`, `test_combat_visuals.gd`, `data_lint.py`. **Commit** `feat(invrisil): the fence's back door (#306)`.

### Task 2.6: I1 post-quest life — the client's reactive stage

**Files:**
- Modify: `wandering_inn_game/data/maps/invrisil/stationer.json` (`stationer_client`)

- [x] **Step 1: Append `talk_pool_stages` to the entity** — it has no stages today, so this is trivially "after the last existing stage". Key it on the **terminal**, `setting_commissioned`:

```json
   "talk_pool_stages": [
    {
     "id": "stationer_client_setting_done",
     "requires_accomplishment": { "setting_commissioned": 1 },
     "lines": [
      "I wear it to the difficult errands now. That was always what it was for.",
      "He sent the order back with the true weight written on it in his own hand. I have kept the paper as well."
     ]
    }
   ]
```

- [x] **Step 2: Shadow-out audit** (mandatory before shipping any stage). One stage over a two-line base pool: pre-terminal the base pool serves; post-terminal the stage wins permanently. Both states are reachable and both read correctly. Ascending-threshold check is vacuous with one stage. The entity keeps its base `talk_pool` (required when stages exist).
- [x] **Step 3: Run** `test_content.gd`; **commit** `feat(invrisil): the client remembers (#306)`.

---

## Phase 3 — I2 "The Hat Stays On"

### Task 3.1: `data/quests.json` — the `the_hat_stays_on` block

**Files:**
- Modify: `wandering_inn_game/data/quests.json` (insert **immediately after the `a_setting_for_a_lady` block landed in Task 2.1**, which sits after the `a_gentlemans_disagreement` anchor — ruling C)

- [x] **Step 1: Splice the block:**

```json
{
	"_comment": "v0.16 I2 (#306). Giver is Wilovan in the parlor; all three route counters produce on adventurers_rest, so `run` is a travel beat naming the Rest (LANDMARK_TOKENS `adventurer`). `{addr}` is FORBIDDEN here -- quests.json is scanned as unresolvable.",
	"id": "the_hat_stays_on",
	"title": "The Hat Stays On",
	"region": "Invrisil",
	"beats": [
		{ "id": "run", "description": "The handover happens at the Adventurer's Rest, where nobody raises a voice. Talk it round, move it without a word, or find out what happens when it goes loud.", "complete_when_any": { "handoff_talked": 1, "handoff_quiet": 1, "handoff_loud": 1 } },
		{ "id": "report", "description": "Go back to the parlor and tell Wilovan how the evening went.", "complete_when": { "hat_job_done": 1 } }
	],
	"_resolution_order": "Weakest claim first, LAST MATCH WINS: handoff_loud (it went wrong, you finished it) < handoff_talked (you talked it round) < handoff_quiet (nobody in the room ever knew). The loud ending is the job done badly and finished anyway; the quiet one is the gentleman's ideal, so it wins a completionist's read.",
	"resolution_paths": [
		{ "accomplishment": "handoff_loud", "text": "The hat came off. The package still changed hands, and the house has agreed to remember it as a misunderstanding about a chair.", "grant": { "melee_hit": 5, "won_combat": 1 } },
		{ "accomplishment": "handoff_talked", "text": "Three exchanges, no names, and a package that was never once mentioned by anybody at the table.", "grant": { "persuaded_someone": 2, "heard_gossip": 3 } },
		{ "accomplishment": "handoff_quiet", "text": "Hat on the third peg, coat over the chair, the wrong one taken on the way out. Nobody raised a voice and nobody raised an eye.", "grant": { "sneaked_past_danger": 2, "observed_things": 2 } }
	]
}
```

- [x] **Step 2: Landmark arithmetic.** Giver map = `brothers_parlor` (Wilovan's conversation is hosted there). `run`'s producers are all on `adventurers_rest` → landmark required → `"the Adventurer's Rest"` contains `"adventurer"`. ✔ `report`'s producer (`invrisil_wilovan.json`) is the giver's own map → no landmark. ✔
- [x] **Step 3: Author both quests' co-bank ladder pins in `tests/test_quests.gd`** — insert after the `price_of_a_favor` block (ruling C anchor), in the same style as the shipped arms: for each quest, assert the single-counter resolution, then the co-bank case that proves last-match-wins, then that the grant is the winner's.

  **EVERY new local in this file takes the `i_` lane prefix** (ruling C): `i_setting`, `i_setting_both`, `i_hat`, `i_hat_both`, … `tests/test_quests.gd:90-132` is **one continuous function body at a single indent level** — `halls`, `door`, `crate`, `order`, `favor` all share one scope — so a duplicate `var` from a sibling lane is a **GDScript parse error that reds the whole suite the moment the second lane merges**, not a shadow. Riverfarm and Pallass both drafted a bare `var ledger` here. Never use a bare `ledger`, `thicket`, `tempered`, `quest`, `setting` or `hat` local from this lane.

- [x] **Step 4: Run** `test_content.gd` + `test_quests.gd`; **commit** `feat(quests): The Hat Stays On (#306)`.

### Task 3.2: Wilovan's parlor surfaces

**Files:**
- Modify: `wandering_inn_game/data/dialogue/invrisil_wilovan.json` (append **two** options last to `hub.options`, after the fence row at `:133-141`; add four nodes)

**Interfaces:**
- Consumes: `brothers_job_done`, the three route counters.
- Produces: `hat_job_taken`, `hat_job_done`, 25 gold.

**Voice contract:** `character-profiles.md:300-307` — Gnoll, `{addr}` address (never a literal honorific at the PC), apology-before-threat, **"recover" never "steal"**, removes his hat plain-and-slow, **one dash per line maximum**. The file's own binding contract at `:2`: "append new hub options last to preserve QA-visible indexes."

- [ ] **Step 1: Append option 7** (the giver):

```json
    {
     "_comment": "v0.16 I2 giver (#306). Appended LAST per this file's index contract; accomplishment-gated so it is HIDDEN in every shipped disagreement fixture and in wilovan_parlor_f_start.",
     "text": "\"Anything wanting a quiet pair of hands?\"",
     "requires": {
      "accomplishment": {
       "brothers_job_done": 1
      }
     },
     "hide_when": {
      "accomplishment": {
       "hat_job_taken": 1
      }
     },
     "goto": "hat_errand"
    },
```

- [ ] **Step 2: Append option 8** (the report):

```json
    {
     "text": "\"The package is where it ought to be.\"",
     "requires": {
      "accomplishment": {
       "hat_job_taken": 1
      }
     },
     "hide_when": {
      "accomplishment": {
       "hat_job_done": 1
      }
     },
     "goto": "hat_report"
    }
```

- [ ] **Step 3: Add the four nodes:**

```json
  "hat_errand": {
   "speaker": "Wilovan",
   "text": "There is, {addr}, and I'll ask your pardon before I describe it, because describing it is most of the offence. A small parcel wants to be somewhere else by morning, and the somewhere else drinks at the Adventurer's Rest. House rule there is that nobody raises a voice. We hold to it. So does everybody who owes them a table.",
   "options": [
    {
     "text": "\"I'll carry it.\"",
     "hide_when": { "accomplishment": { "hat_job_taken": 1 } },
     "effects": [
      { "quest": "the_hat_stays_on" },
      { "accomplishment": "hat_job_taken" }
     ],
     "goto": "hat_terms"
    },
    { "text": "\"And if it goes wrong?\"", "goto": "hat_terms_loud" },
    { "text": "\"Another evening.\"", "end": true }
   ]
  },
  "hat_terms": {
   "speaker": "Wilovan",
   "text": "Then here are the manners of it. You don't name the thing, you don't name the man, and you don't hurry. A gentleman who hurries is a gentleman explaining himself later. Hat stays on the whole while, {addr}. That's not superstition. That's the whole of the etiquette.",
   "options": [
    { "text": "\"Understood.\"", "end": true }
   ]
  },
  "hat_terms_loud": {
   "speaker": "Wilovan",
   "text": "Then the hat comes off, {addr}, plain and slow, and everybody in the room reads it correctly and steps back a pace. I'd rather it didn't. My colleague would rather it did, which is why he isn't going.",
   "options": [
    { "text": "\"Let's hope not.\"", "goto": "hat_terms" }
   ]
  },
  "hat_report": {
   "speaker": "Wilovan",
   "_comment": "Three route arms, one close. Ungated exit keeps the softlock guard satisfied.",
   "text": "It is, and I've had it confirmed by a man who does not confirm things. Tell me how the room took it, {addr}, and I'll know what I owe you.",
   "options": [
    {
     "text": "\"Three exchanges. Nobody said a word that mattered.\"",
     "requires": { "accomplishment": { "handoff_talked": 1 } },
     "hide_when": { "accomplishment": { "hat_job_done": 1 } },
     "effects": [
      { "accomplishment": "hat_job_done" },
      { "gold": 25 }
     ],
     "end": true
    },
    {
     "text": "\"Hat on the peg, coat on the chair. Nobody looked up.\"",
     "requires": { "accomplishment": { "handoff_quiet": 1 } },
     "hide_when": { "accomplishment": { "hat_job_done": 1 } },
     "effects": [
      { "accomplishment": "hat_job_done" },
      { "gold": 25 }
     ],
     "end": true
    },
    {
     "text": "\"It went loud. The hat came off. It's still done.\"",
     "requires": { "accomplishment": { "handoff_loud": 1 } },
     "hide_when": { "accomplishment": { "hat_job_done": 1 } },
     "effects": [
      { "accomplishment": "hat_job_done" },
      { "gold": 25 }
     ],
     "end": true
    },
    { "text": "\"Not yet.\"", "end": true }
   ]
  }
```

- [ ] **Step 4: Index-stability proof — run it, do not assume.** After banking `brothers_job_done`, the hub's visible rows become `["Evening.", "Cups asked me to see something back to you." (item-gated, VISIBLE-LOCKED), "Anything come through lately? (Show the marker.)"]` plus the two new rows **at the end**. Verify against every script that touches this graph:
  - `qa/scripts/invrisil_disagreement_talk.json`, `..._stealth.json`, `..._fight.json`, `qa/scripts/wilovan_address_f.json` — none of these pins an `options` array (verified: zero `"options"` keys in all four), but all four navigate by `move down N`. Re-run **all four** at their manifest seeds and require green with **zero** script edits.
  - `invrisil_disagreement_fight.json` is the sharp one: it banks `brothers_job_done` mid-conversation at step ~91 and then does `move down 1` + `confirm` at steps 99–100. Read steps 84–102 in full and confirm those steps sit inside the `marker`/`marker_terms` nodes, **not** a re-rendered hub. If the hub is re-entered, the fix is a re-pin **in this PR**, not a gate change.
- [ ] **Step 5: Dash budget.** Grep the four new nodes for `—` and for `--`: at most one em-dash per line, zero ASCII double-hyphens. Wilovan's `ways` node already blows the budget — do not add to it.
- [ ] **Step 6: Run** `test_dialogue.gd` + `test_content.gd` + `data_lint.py`; **commit** `feat(dialogue): Wilovan's quiet errand (#306)`.

### Task 3.3: `data/dialogue/invrisil_rest_factor.json` — the TALK route

**Files:**
- Create: `wandering_inn_game/data/dialogue/invrisil_rest_factor.json`

**Interfaces:**
- Consumes: `hat_job_taken`.
- Produces: `handoff_talked`.

- [ ] **Step 1: Author the graph.** Three exchanges, the trade never named, `{addr}` where he addresses the player:

```json
{
 "_comment": "v0.16 I2 TALK (#306): three exchanges, nothing named. The job arm is accomplishment-gated so the node reads as plain house talk before the errand exists; the ungated `house` arm keeps the softlock guard satisfied and gives the room a permanent surface after hat_job_done.",
 "start": "table",
 "nodes": {
  "table": {
   "speaker": "The House Factor",
   "text": "You'll want the long table, {addr}, not this one. Long table's for people waiting on somebody. This one's for people who have already arrived.",
   "options": [
    {
     "text": "\"I was told to wait on somebody.\"",
     "requires": { "accomplishment": { "hat_job_taken": 1 } },
     "hide_when": { "accomplishment": { "handoff_talked": 1 } },
     "goto": "exchange_one"
    },
    { "text": "\"Busy house.\"", "goto": "house" },
    { "text": "\"I'll leave you to it.\"", "end": true }
   ]
  },
  "exchange_one": {
   "speaker": "The House Factor",
   "text": "Then you're early, which is a manner, or you're late, which is a message. Which would you like it to have been?",
   "options": [
    { "text": "\"Early. I can wait.\"", "goto": "exchange_two" },
    { "text": "\"Neither. I'm only warm.\"", "goto": "exchange_two" }
   ]
  },
  "exchange_two": {
   "speaker": "The House Factor",
   "text": "Warm is a good answer. The gentleman who left that coat was warm too, and he'll be back for it or he won't, and either way the coat is paid for through the season.",
   "options": [
    { "text": "\"Then I'll mind it until he is.\"", "goto": "exchange_three" }
   ]
  },
  "exchange_three": {
   "speaker": "The House Factor",
   "text": "Mind it well, {addr}. Nobody in this room raises their voice and nobody in this room has ever seen a thing. That isn't a rule of the house. That's the rent.",
   "options": [
    {
     "text": "\"Understood.\"",
     "effects": [ { "accomplishment": "handoff_talked" } ],
     "end": true
    }
   ]
  },
  "house": {
   "speaker": "The House Factor",
   "text": "Busy enough. Silver rank drinks free the night they make it, once, and we have never once had to say it twice. The rest pay, and the rest are grateful for a room where the price is the only thing anybody asks them for.",
   "options": [
    { "text": "\"Fair terms.\"", "end": true }
   ]
  }
 }
}
```

- [ ] **Step 2: Event-order note for QA:** `exchange_three`'s close carries `effects` + `end: true` — wait `dialogue_ended`, **then** `accomplishment_recorded {id: handoff_talked}`.
- [ ] **Step 3: Run** `data_lint.py` + `test_dialogue.gd` + `test_content.gd`; **commit** `feat(dialogue): the house factor (#306)`.

### Task 3.4: I2 combatants + harness cell

**Files:**
- Modify: `wandering_inn_game/data/combatants.json` (2 rows, inserted after the two Task 2.5 rows — i.e. still inside this lane's own block at the `hired_blade_knife_b` anchor, ruling C)
- Modify: `wandering_inn_game/tests/sim_combat_batch.gd` (`INVRISIL_CELLS` +1)

(The encounter entity itself already shipped in Task 1.4's map file.)

- [ ] **Step 1: Insert two rows:**

```json
 {
  "_comment": "v0.16 I2 FIGHT (#306). NEW ids -- the shared footpad/hired-blade rosters are never retuned. Sprite citizen_f, the hired_blade_knife_a precedent (registered, no combat_scale).",
  "id": "rest_bravo_a",
  "power_level": 7.5,
  "display_name": "A Man Who Stood Up",
  "sprite": "citizen_f",
  "side": "enemy",
  "combat_tint": [0.58, 0.5, 0.46],
  "stats": { "str": 12, "dex": 11, "con": 24, "int": 5, "wis": 6, "cha": 7 },
  "weapon_die": 5,
  "ai": "melee",
  "skills": []
 },
 {
  "_comment": "The one who was waiting for a reason. Distinct sprite so the pair reads apart on the board.",
  "id": "rest_bravo_b",
  "power_level": 8.5,
  "display_name": "The One Who Was Waiting",
  "sprite": "human_laborer",
  "side": "enemy",
  "combat_tint": [0.5, 0.44, 0.4],
  "stats": { "str": 13, "dex": 10, "con": 28, "int": 5, "wis": 6, "cha": 6 },
  "weapon_die": 5,
  "ai": "melee",
  "skills": ["power_strike"]
 }
```

- [ ] **Step 2: Append the harness cell:**

```gdscript
	# v0.16 I2 (#306). Interior brawl at Invrisil's expected level, SOLO. Same
	# window contract as the fence cell: the shipped stop-cell precedent
	# 0.55/0.95 (controller ruling A). Region-band ordering is evidenced by the
	# MEASURED median recorded in the PR body, not by a narrow authored ceiling.
	# Arena merchant_warehouse (biome inn) reused -- zero arenas.json edits.
	{"name": "rest_bravos_t3_warrior10_solo", "arena": "merchant_warehouse", "enemies": ["rest_bravo_a", "rest_bravo_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
```

- [ ] **Step 3: Measure-first / tune / re-gate** — identical procedure and acceptance to Task 2.5 Steps 4–6, including the 0.55–0.95 gate, the 3–12 median band, and the **measured** median going into the PR body. The bravos are authored one notch softer than the fence pair (16.0 vs 17.5 total power) because the brawl is a failure state, not a target, so their measured `win_rate` should land **above** the fence cell's — that relationship is a number to report, not a window to author.
- [ ] **Step 4: Run** `test_combat_data.gd`, `test_content.gd`, and `test_combat_visuals.gd` — noting per **ruling F** that the visuals suite does **not** measure `citizen_f` or `human_laborer` board figures for these ids and passes by exclusion; the Task 5.5 shot-7 windowed read is the actual legibility gate. **Commit** `feat(invrisil): it goes loud at the Rest (#306)`.

### Task 3.5: I2 post-quest life — parlor stage + inn register variant

**Files:**
- Modify: `wandering_inn_game/data/maps/invrisil/brothers_parlor.json` (`wilovan` entity)
- Modify: `wandering_inn_game/data/dialogue/wilovan_inn.json` (`greet` node **only**)

- [ ] **Step 1: Append `talk_pool_stages` to the parlor `wilovan` entity.** It carries `talk_pool` but **no** stages today (entity keys: `_comment, id, kind, cell, display_name, sprite, tint, facing, observe, friendly_line, talk_pool, conversation, dialogue`), so this stage is trivially last and last-match-wins is safe:

```json
   "talk_pool_stages": [
    {
     "id": "wilovan_hat_job_done",
     "requires_accomplishment": { "hat_job_done": 1 },
     "lines": [
      "The Rest sends its regards, {addr}, which from that house is a standing ovation.",
      "A quiet evening, well kept. There's no higher compliment in my line and no lower fee."
     ]
    }
   ]
```

- [ ] **Step 2: Shadow-out audit.** Pre-terminal the base pool serves; post-terminal this stage wins permanently on the parlor entity. Wilovan's `conversation` (`invrisil_wilovan`) is unaffected — pool lines serve **before** the conversation opens (`src/core/interactions.gd:73-81`), which is exactly why every Invrisil QA script interacts with him twice. Confirm `wilovan_address_f.json` still reaches his hub on the second interact in a fixture that lacks `hat_job_done` (it will — the stage cannot arm).
- [ ] **Step 3: `wilovan_inn.json` — ruling 7 shape ONLY.** The `greet` node has **no** `text_variants` today, so create the array with exactly one entry. **Do not touch the base `text`. Do not add an option.** `qa/scripts/inn_guests_ext_loop.json:100` pins `greet`'s exact text **and** an exact 3-option array; its fixture cannot hold `hat_job_done`, so both pins stay green:

```json
		"greet": { "speaker": "Wilovan", "text": "{Addr}. A good evening to you, and a very good room to have it in. No business tonight, you'll be relieved to hear. A gentleman does occasionally sit somewhere nobody owes anybody anything.", "text_variants": [
			{ "requires": { "accomplishment": { "hat_job_done": 1 } }, "text": "{Addr}. A good evening, and I'll say only that some evenings are quieter than others and the quiet ones are the ones worth sitting in. That's the whole of my report and it's more than I usually give." }
		], "options": [
```

REGISTER PURITY CHECK on that line: no package, no venue, no Rest, no factor, no fee, no colleague's errand, no Coyle, no marker. It is a Gentleman Caller declining to discuss his evening at length, which is his register exactly.

- [ ] **Step 4: Variant-shadow audit.** `text_variants` are last-match-wins and **any** match beats the base text. This is the only variant on the node and its gate (`hat_job_done`) is unreachable in `inn_guests_ext_loop`'s fixture, so the pinned base text can never be shadowed. `VARIANT_KEYS` allows only `_comment`, `requires`, `text` — the entry above carries exactly `requires` + `text`.
- [ ] **Step 5: Run** `test_dialogue.gd`, `test_content.gd`, and `wandering_inn_game/qa/run_qa.sh inn_guests_ext_loop headless --seed=<manifest seed>` — expect green with zero script edits. **Commit** `feat(invrisil): Wilovan remembers a quiet evening (#306)`.

---

## Phase 4 — Character profile (ruling 8, as amended by ruling D)

### Task 4.1: Hedault's profile entry

**Files:**
- Modify: `docs/design/character-profiles.md` — **fill the pre-landed `## Hedault` stub IN PLACE. This file is SHARED, not exclusive to this lane, and nothing is appended at EOF.**

**Why (ruling D):** the first draft claimed this file outright and said "append at EOF". Pallass edits the same file in its very first task (Task 0.1, a preflight that lands *before* this lane), adding **Forge Hall Apprentice** and **Den-Shop Keeper** — and its own ownership table listed the file under neither Exclusive nor SHARED. Both lanes appending at the same EOF point is a designed-in conflict. The controller resolved it by **pre-landing three stub section headers at the plan commit**, so each lane edits only its own lines.

- [ ] **Step 1: Confirm the stub, do not confirm a gap.** `grep -n -i "hedault" docs/design/character-profiles.md` returns the **pre-landed stub** at `:525-527`:

```markdown
## Hedault (v0.16 #306 STUB — Invrisil lane fills this section in place;
## scaffolded at plan commit)
(placeholder — replaced by the Invrisil lane)
```

  If that stub is missing, **stop and report to the controller** — do not append at EOF and do not invent a header. Leave Pallass's two stubs (`## Forge Hall Apprentice` :516, `## Den-Shop Keeper` :521) untouched whether they are still placeholders or already filled.
- [ ] **Step 2: Replace the two stub header lines and the placeholder line with the real section, in place** (short — this is a writing contract, not an essay):

```markdown
## Hedault (profile added 2026-07-28; v0.16 I1 lane, #306)
- Canon (wiki + `docs/design/hedault-enchanting-spec.md:8-11`): human
  [Enchanter] of Invrisil, ATTESTED canon-native. Exacting, humorless,
  fair to a fault, **hates being touched**. Services priced formally;
  **no haggling, ever** — a haggle is answered by restating the price.
- Voice contract (as shipped, `data/dialogue/hedault_enchanting.json`):
  imperatives, not pleasantries ("State the item", "Set it on the
  cloth", "Stand where I put you"). Prices and facts stated flat. He
  refuses to speculate outside his own trade and says so ("I will not
  speculate further in a shop"). Praise is delivered as the absence of
  correction. Never warm, never cruel, never charming and immune to it.
- Register bar: Book-17, no Vol 8+ content, no seal content. He reads
  CRAFT only — a fed draw versus a set one — and stops there.
- v0.16 (I1, "A Setting for a Lady"): he will not cut a mount around a
  lie. The comedy and the kindness are both in his refusal being the
  most respectful thing anyone does for the client all quest.
```

- [ ] **Step 3: Diff discipline.** `git diff docs/design/character-profiles.md` must show **only** the three stub lines replaced by this section — zero context lines touched at EOF, zero lines touched in the Pallass stubs. Anything else is a merge-train conflict waiting to happen.
- [ ] **Step 4: Run** `python3 scripts/check_doc_drift.py` (doc structure) and `python3 scripts/sync_agent_guidance.py` (guidance-mirror check); **commit** `docs(profiles): Hedault's voice contract (#306)`.

---

## Phase 5 — QA

Load `wi-writing-qa-scripts` before this phase. **Fixture-first policy:** every new canonical starts from a fixture unless the route itself is the subject.

### Task 5.1: Fixtures

**Files:**
- Create: eight files under `wandering_inn_game/qa/fixtures/`
- Modify: `wandering_inn_game/tests/test_fixture_coherence.gd` (`COMBAT_BAND_FIXTURES` +2)

**Base-copy rule (do not hand-author from the skill doc — it is stale):** copy `qa/fixtures/near_invrisil.json` as the base for every fixture below. It already satisfies the whole monotone chain that `test_fixture_coherence.gd:193-273` enforces — `invrisil_attuned` → `blight_lifted` + the `invrisil_attunement_stone` **in inventory**; `blight_lifted` → `riverfarm_attuned`; any `*_attuned` → `door_awakened`; `door_awakened` → `door_understood` + `recovered_anchor_stone` + `bought_catalyst` + `door_mounted` + `door_study_sleeps == 3`; `door_mounted` → `door_retrieved` + `pedestal_breached`; `door_retrieved` → `horns_dig_joined` → `horns_dig_started`. Shipped fixtures carry `"version": 5` (the skill doc's "version 3" is stale; `WISave.VERSION` is 8 and migrates on apply). `player_facing` is a **2-vector** (`[0,-1]`), never a string.

| Fixture | `current_map` / `player_cell` | Added counters | Notes |
|---|---|---|---|
| `invrisil_stationer_start` | `invrisil_boulevard` / `[20,2]`, facing `[0,-1]` | none | interior-loop start, bumping the new door |
| `invrisil_setting_start` | `stationer` / `[4,2]`, facing `[-1,0]` | none | I1 TALK: quest not yet started, faces the client. **Carries NO `appraise_goods` — this is the fixture the VISIBLE-LOCKED pin needs** (Task 5.2 Step 2) |
| `invrisil_setting_skill_start` | `stationer` / `[4,2]` | `heirloom_commission_started` 1; `started_quests` += `a_setting_for_a_lady` | `player_skills` += `appraise_goods`. Proves the **selectable** arm only — a skill cannot be unlearned mid-run, so the locked leg can never live here |
| `invrisil_setting_fight_start` | `mercantile_alleys` / `[11,11]`, facing `[0,1]` | `heirloom_commission_started` 1, `brothers_job_done` 1 (+ its co-banks); `started_quests` += `a_setting_for_a_lady` | `removed_entities`: `["alley_footpads_a","alley_footpads_b"]` — **ruling 5's already-cleared save**; level-10 build |
| `invrisil_rest_start` | `invrisil_boulevard` / `[18,2]`, facing `[0,-1]` | `brothers_job_done` 1 | Rest interior loop |
| `invrisil_hat_start` | `brothers_parlor` / `[5,3]`, facing `[1,0]` | `brothers_job_done` 1 | I2 TALK, at Wilovan |
| `invrisil_hat_quiet_start` | `adventurers_rest` / `[2,7]`, facing `[-1,0]` | `brothers_job_done` 1, `hat_job_taken` 1; `started_quests` += `the_hat_stays_on` | plates armed, hook adjacent |
| `invrisil_hat_loud_start` | `adventurers_rest` / `[9,5]`, facing `[0,1]` | `brothers_job_done` 1, `hat_job_taken` 1; `started_quests` += `the_hat_stays_on` | level-10 build, faces the bravos |

- [ ] **Step 1: Author all eight from the `near_invrisil` base**, editing only `current_map`, `player_cell`, `player_facing`, `accomplishments`, `started_quests`, `player_skills`, `removed_entities`, `inventory` and `rng_state`.
- [ ] **Step 2: Derive every `rng_state`** — never hand-type one:

```
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/_derive_rng_state.gd -- <seed>
```

`RNG_STATE_MIN_MAGNITUDE = 1_000_000` (`test_fixture_coherence.gd:378-388`) fails any value below 1e6 as hand-typed.

- [ ] **Step 3: `MAP_REQUIRES` compliance.** The three fixtures standing inside `stationer`/`adventurers_rest` inherit Task 1.5's rows — `door_awakened` + `invrisil_attuned` are already in the base fixture. Confirm, do not assume.
- [ ] **Step 4: `COMBAT_BAND_FIXTURES`.** Read the const's semantics at `test_fixture_coherence.gd:19-29` (fixture → expected class level; `near_invrisil_fight` is 10), then append:

```gdscript
	"invrisil_setting_fight_start": 10,
	"invrisil_hat_loud_start": 10,
```

and make both fixtures' `classes` match the level the const declares.

- [ ] **Step 5: Run** `test_fixture_coherence.gd` — expect PASS. **Commit** `test(qa): Invrisil v0.16 fixtures (#306)`.

### Task 5.2: Canonical scripts

**Files:**
- Create: nine files under `wandering_inn_game/qa/scripts/`

Nine canonicals: **one per route for both terminal paths** (six), **both interior loops** (two), and **one gate-proof leg** (one).

| Script | Fixture | Proves |
|---|---|---|
| `stationer_room_loop` | `invrisil_stationer_start` | boulevard→stationer door, three non-quest observes, the clerk's pool, stationer→boulevard return landing on (20,2) |
| `invrisil_setting_talk` | `invrisil_setting_start` (**no `appraise_goods`**) | full I1 TALK terminal path: client → Hedault → `heirloom_truth_kept` → handover → `setting_commissioned` + item + gold. **Also owns the VISIBLE-LOCKED pin** on the `[Appraise Goods]` row (see Step 2) |
| `invrisil_setting_skill` | `invrisil_setting_skill_start` (**has `appraise_goods`**) | the `[Appraise Goods]` arm is **SELECTABLE** and banks `setting_assisted`; terminal. **Owns the selectable pin only** |
| `invrisil_setting_fight` | `invrisil_setting_fight_start` | fence door interact → combat → `original_recovered` → terminal, on a save where both footpad rigs are already removed |
| `adventurers_rest_loop` | `invrisil_rest_start` | boulevard→Rest door, three non-quest observes, ambient cast, return landing on (18,2) |
| `invrisil_hat_talk` | `invrisil_hat_start` | Wilovan's errand node → three exchanges → `handoff_talked` → report → `hat_job_done` + gold |
| `invrisil_hat_quiet` | `invrisil_hat_quiet_start` | **the plate order, both ways**: corner table FIRST banks `handoff_mistimed` with the cold toast (the can-fail), then hook, then table banks `handoff_quiet` with the variant toast |
| `invrisil_hat_loud` | `invrisil_hat_loud_start` | bravos interact → combat → `handoff_loud` → report |
| `invrisil_v016_gate_check` | `invrisil_stationer_start` | **gate-proof:** Hedault's hub still renders exactly 5 rows without `heirloom_commission_started` (the ruling-1 pin-stability assertion, as a permanent regression guard); and the Rest's bravos emit `gate_closed_toast` without `hat_job_taken` |

- [ ] **Step 1: Author each script** on the shipped idioms:
  - Fixture-start title sequence: `ui_title_gate_rendered` → `confirm` → `ui_title_rendered` → `move down 1` (Continue) → `confirm` → `game_loaded` → `world_ready` → `assert_state current_map` / `player_cell`.
  - Dialogue option selection: `ui_dialogue_shown` → `move down N` → `press confirm`, counting **visible** options only. (`click_dialogue_option` takes `"option"` and is **1-based**; a wrong key silently no-ops.)
  - Every toast assertion pins the **exact text** via `payload_contains` — a bare `wait_for_event ui_toast_rendered` proves nothing about which toast.
  - Never put a comment key inside `payload_contains`.
  - Never pin toast **order** across `combat_started`.
  - `assert_event_logged` / `assert_event_absent` scan the **whole run**, not since the last wait — place negatives deliberately.
  - JSON coordinates parse as floats: `[5.0,8.0] != [5,8]` in GDScript. Copy the cell literal shape from a shipped Invrisil script.
  - Effects-plus-`end` options: wait `dialogue_ended` **then** `accomplishment_recorded`.
  - Gray-band fights emit no `won_combat` — for the two combat scripts pin `victories` (or the encounter's own `on_victory` counter, which is the reliable one here) rather than `won_combat`.
- [ ] **Step 2: The visible-lock contract — split across TWO scripts, because one script starts from one fixture.** The first draft assigned the locked-arm assertion to `invrisil_setting_skill`, whose only fixture **grants** `appraise_goods`; a skill cannot be unlearned mid-run, so as drafted the contract could not be proven by its assigned script at all. Corrected ownership, stated explicitly so neither script drifts:
  - **`invrisil_setting_talk` owns the LOCKED pin.** Its fixture `invrisil_setting_start` carries **no** `appraise_goods`, and the script already opens `heirloom_bench` on its way to the TALK arm. On that node, pin the `[Appraise Goods]` row as **present and `locked`** with its `requirement` string, from a real `events.jsonl` — `src/core/dialogue.gd:29-32` marks a `{skill}`-requires option `locked` and fills `requirement` from `_requirement_text` (`:241-244`, `"requires <skill name>"`), and `_visible_options` (`:113-122`) hides only `_progress_gated` requires (accomplishment / board_accepted / delivery_accepted / once_per_waking), so a skill arm is **visible-locked, never hidden**. This is the `parley_gates_check` idiom.
  - **`invrisil_setting_skill` owns the SELECTABLE pin.** Same node, fixture **with** the skill: the row is unlocked, is selected, and banks `setting_assisted` through to the terminal.
  - **Do not** try to prove both legs in one script and **do not** give `invrisil_setting_skill` a second fixture — one canonical, one fixture is the shipped idiom, and the pair above already covers both states.
  - The same locked-vs-hidden distinction is the reason `invrisil_v016_gate_check` (Step 3) pins Hedault's hub at exactly 5 rows: the **accomplishment**-gated commission option is HIDDEN, not locked.
- [ ] **Step 3: `invrisil_v016_gate_check` is the ruling-1 regression guard.** Pin Hedault's hub `options` array at exactly 5 rows with their exact `text`/`locked`/`requirement` fields, copied **from a real run's `events.jsonl`**, never assumed. This makes the pin-stability adjudication permanent rather than a one-time PR claim.
- [ ] **Step 4: Seeds.** Start every script at **seed 9** (the Invrisil canonical seed). For the two combat scripts, if seed 9 does not produce a deterministic win, search seeds 1–40, pin the first clean win, and record the search in the script's `_comment` (census-exempt).
- [ ] **Step 5: Run each script individually** and re-derive every pin from its own `events.jsonl`:

```
perl -e 'alarm 300; exec @ARGV' -- wandering_inn_game/qa/run_qa.sh <script> headless --seed=9
```

Output at `wandering_inn_game/qa_output/<script>/{result.json,events.jsonl,*.png}` — **the dir is clobbered by any re-run**, so read before re-running. A missing `result.json` with `rc=0` is a RED, never a pass.
- [ ] **Step 6: Commit** `test(qa): nine Invrisil v0.16 canonicals (#306)`.

### Task 5.3: Manifest, seed table, generated docs — one commit

**Files:**
- Modify: `wandering_inn_game/qa/manifest.json` (9 entries, inserted **after the `hedault_fragment_loop` entry** — ruling C)
- Modify: `wandering_inn_game/AGENTS.md` (9 seed-table rows, inserted **after the `hedault_fragment_loop` row**, same relative order as the manifest)
- Regenerate: `wandering_inn_game/qa/manifest.json` `surfaces`, `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`

- [ ] **Step 1: Insert nine manifest entries** at the anchor, each with `script`, `seed`, `fixture`, a real `note`, and `"tiers": ["full"]`. Leave `surfaces` **absent** — it is generated. (No new entry joins `smoke`: smoke must stay a subset of full and the smoke sweep is a latency budget.)
- [ ] **Step 2: Insert the nine AGENTS.md seed-table rows** at the matching anchor. `qa/ci_sweep.sh` **hard-fails at startup** if the manifest and the table disagree — they must land in the same commit.
- [ ] **Step 3: Regenerate, in this exact order (controller ruling E):**

```
python3 wandering_inn_game/scripts/derive_qa_surfaces.py --write
python3 wandering_inn_game/scripts/derive_qa_surfaces.py --check
python3 scripts/render_qa_notes.py --write
python3 scripts/render_qa_notes.py
python3 scripts/check_doc_drift.py
```

**`--write` is mandatory on `render_qa_notes.py` and the first draft omitted it.** `scripts/render_qa_notes.py:55-66` writes **only** under `--write`; a bare run compares, prints `QA NOTES DRIFT` + `Run: python3 scripts/render_qa_notes.py --write`, and returns **1**. A bare-only invocation is a no-op that leaves `docs/QA-SCRIPT-NOTES.md` stale and reds `leak-check` — precisely the #312 CI red this plan cites as the lesson. The **bare** run is the *verification* step: expect rc 0 and `PASS: QA notes match manifest`. (`derive_qa_surfaces.py` is the opposite — bare **is** a write, `scripts/derive_qa_surfaces.py:412-414` — but pass `--write` explicitly anyway.)

**Merge-train note:** `render_qa_notes.py` renders the file whole from the **entire** manifest, so the pair must be re-run on **every train merge that combines two lanes' manifest entries**, not just inside this lane's commit. Same for `derive_qa_surfaces.py --write`. Never hand-edit `surfaces` or `QA-SCRIPT-NOTES.md`.
- [ ] **Step 4: Commit** `test(qa): register the Invrisil v0.16 canonicals (#306)` — manifest + seed table + both generated artifacts in **one** commit.

### Task 5.4: Re-gate sweep

- [ ] **Step 1: Settle the tree first** — no edits in flight. A sweep launched mid-edit produces a mixed-state verdict; kill and relaunch.
- [ ] **Step 2: Compute the touched-surface re-gate list.** Run `--touching` for each shared/edited path and take the **union**:

```
wandering_inn_game/qa/ci_sweep.sh --touching data/quests.json
wandering_inn_game/qa/ci_sweep.sh --touching data/maps/invrisil/invrisil_boulevard.json,data/maps/invrisil/mercantile_alleys.json,data/maps/invrisil/brothers_parlor.json
wandering_inn_game/qa/ci_sweep.sh --touching data/dialogue/hedault_enchanting.json,data/dialogue/invrisil_wilovan.json,data/dialogue/wilovan_inn.json
wandering_inn_game/qa/ci_sweep.sh --touching data/combatants.json
```

`--touching data/quests.json` maps to **20+** canonicals via `MONOLITH_SYSTEMS` (GH#281) — `cisterns_*`, `crate_*`, `door_chain_*`, `horns_dig_*`, `invrisil_disagreement_*`, `missing_recruit_loop`, `pallass_walkthrough`, … The `wi-writing-qa-scripts` claim that it maps to zero scripts is **out of date**. Budget the time.

The must-be-green named set, at minimum: `invrisil_walkthrough`, `invrisil_round_trip`, `invrisil_disagreement_talk|_stealth|_fight`, `wilovan_address_f`, `hedault_enchant_loop`, `hedault_fragment_loop`, `spine_reach`, `ratici_fence_loop`, `ratici_fence_gate_check`, `boulevard_night_footpads_loop`, `invrisil_mothbear_loop`, `parley_gates_check`, `parley_talkdowns_loop`, `regional_work_loop`, `inn_guests_ext_loop`, `inn_guests_gate_proof`.

- [ ] **Step 3: Subagent-safe sweep idiom.** A full `ci_sweep.sh` cannot run foreground in one Bash call — the harness promotes it to background and strands the waiter. Start it writing to a log with its own `rc=` echo, then poll with short foreground `sleep 60; tail -1 <log>` calls and read `rc` from the log.
- [ ] **Step 4: Report per script, never "everything passed."**

### Task 5.5: Windowed machine playtest

- [ ] **Step 1: Load `wi-machine-playtest`.** Run windowed passes and capture these shots:
  1. `invrisil_walkthrough` at (20,2) — the stationer facade now rendering as a **door**, not `hide_sprite` wall band (this changes the shipped `01c_boulevard_stationer` image; it is a capture, not an assert).
  2. The (18,1) Adventurer's Rest door on the facade band, and the two doors read together at x=18–20.
  3. `stationer.json` interior — full room, the client at (3,2), the clerk at (8,1), mood/vignette, **and the room's dressing**: the `walls.segments` perimeter reading as walls (not a crate ring), the `[16,21]/[17,21]` shop-board floor reading apart from the parlor's parquet, the writing table + stools at (3–5,5), the sconce pool at (4,1), and the `counter_left`/`counter_right` run at (5–6,1) reading as one counter.
  4. `adventurers_rest.json` interior — full room, the three-NPC cast, mood/vignette, **and the dressing**: walls not crates, the darker longhouse plank floor reading apart from the inn's, the lit `hearth` at (2,1), the `bar_counter` at (7,1), the benches/rug, and both sconce pools at dusk.
  5. The armed state of the Rest: hat hook (1,7) and corner table (11,2) present, bravos at (9,6). **Legibility check on the two stand-ins**: does `hat_stand` at (1,7) read as "The Peg Rail", and does `library_shelf` at (10,1) read as "A Rack of Retired Kit"? If either bounces, re-pick from the registered set and note it — **do not** add a sprite row.
  6. `alley_fence_door` at (11,12) in the alleys, and its `gate_closed_toast`.
  7. Both new fight boards (`mercantile_alley` with the fence pair; `merchant_warehouse` with the bravos) — figure sizes, tints, hit-flash settling back to the resting modulate. **This is the ONLY figure read the four new rigs get** — per ruling F, `test_combat_visuals.gd` does not measure `hired_blade`, `human_laborer` or `citizen_f` board figures and passes by exclusion. Check by eye that each pair reads apart at a glance and that neither figure crowds its cell.
  8. The handover node and the locket grant toast; Wilovan's errand node with `{addr}` resolved.
- [ ] **Step 2: Drain findings to `docs/VISUAL-LOG.md`** (repo-root docs/, the wave's log — note that `wandering_inn_game/docs/VISUAL-LOG.md` is a **second, distinct** file).

---

## DEFERRED TO CLOSE PR — `data/leads.json`

**Leads-strip rule check:** `test_content.gd:78-101` `_validate_leads` requires **every** `requires` and `hide_when` counter to be present in `data/shipped_ids.json`'s `accomplishments` list. That file is generated at release-cut only and is frozen at `RELEASE = "0.15.0"`. Both natural Invrisil leads need a **hide_when on the quest-start counter**, and both of those counters are created in this PR:

- I1's hide_when would be `heirloom_commission_started` — **new**, not shipped.
- I2's hide_when would be `hat_job_taken` — **new**, not shipped.

There is no shipped substitute: a lead whose `hide_when` is not the start counter would never vanish, which `_validate_leads` exists to prevent. **Therefore no `data/leads.json` row ships in this PR.** `data/leads.json` is removed from this lane's shared-file list.

Row drafts, ready to splice into the v0.16 close PR **after** `shipped_ids.json` is regenerated at the tag:

```json
		{ "id": "lead_setting_for_a_lady", "requires": { "invrisil_attuned": 1 }, "hide_when": { "heirloom_commission_started": 1 }, "lead_text": "A woman has been sitting in the stationer's for an hour holding a closed box.", "place": "The stationer's, Invrisil boulevard" },
		{ "id": "lead_hat_stays_on", "requires": { "brothers_job_done": 1 }, "hide_when": { "hat_job_taken": 1 }, "lead_text": "Wilovan has an errand that wants a quiet pair of hands.", "place": "The Brothers' parlor, Invrisil" }
```

Both `place` strings name a `LANDMARK_TOKENS` token (`stationer`, `boulevard`, `invrisil`, `parlor`) — verified against the widened table from Task 1.5.

---

## Danger list

Every risk below has its mitigation baked into a numbered step above.

### From the Invrisil recon

| Risk | Mitigation |
|---|---|
| **Hedault's exact 5-row `options` pin** (`hedault_fragment_loop.json:52`; arrays compare by SIZE first, `test_driver.gd:970-976`) | Ruling 1 — the new hub option is accomplishment-gated on a counter no shipped fixture holds, so it is HIDDEN. Task 2.3 Step 3 **runs** the script to prove it; Task 5.2 Step 3 makes the 5-row pin a permanent canonical. |
| **`spine_reach.json:365-370` blind `move down 5`** | Same gate; the new option is appended at authored index 6, after the capstone, so visible index 5 is unmoved. Proven by re-run, Task 2.3 Step 3. |
| **`inn_guests_ext_loop.json:100` pins `wilovan_inn` `greet` text + exact 3-option array** | Ruling 7 — a single `text_variants` entry gated on `hat_job_done`; no option added, base text untouched. Task 3.5 Steps 3–5, with a re-run. |
| **Stationer observe pin** (`invrisil_walkthrough.json:290-295`: `player_blocked [20,1]`, `skill_used target boulevard_stationer`, full toast) | Task 1.1 — id and observe kept byte-identical, (20,1) stays blocked, and the walkthrough presses **no** `interact` at (20,2) (verified step-by-step). No re-pin needed; stated in the PR body. |
| **Crowded boulevard cells** (rows 2 and 8 are the pinned corridors) | Task 1.2 Step 3 — (18,1)/(18,2) enumerated against every pinned cell in all five boulevard-walking scripts. |
| **Row 2 is the day→night pacing lane, not a short leg** (the first draft's "x 20-23 only" was wrong) | `invrisil_walkthrough` steps 167–203 walk row 2 **end-to-end x=1…27 thirty-six times** to grind the clock, pinning `[27,2]` at step 185 and `phase night` at 204–206. `wi_game.gd:310-325` skips `_tick_action()` on a blocked step, so one new row-2 blocker breaks the pin **and** stalls the phase grind. **RULE: this lane never occupies a row-2 boulevard cell** — both new doors sit on the fully blocked row 1. Task 1.2 Step 3. |
| **Crowded alleys** (225/280 cells blocked, 42 free) | Task 2.5 — (11,12) chosen outside both shipped trigger zones and off every traversed cell, interact-only so it cannot spring. |
| **`remove_entity` collision** (`invrisil_wilovan.json:100-104` removes both footpad rigs on `brothers_job_done`) | Ruling 5 — brand-new ids, an independent entity, and `invrisil_setting_fight_start` carries `removed_entities: [alley_footpads_a, alley_footpads_b]` so the already-cleared save is the tested case. |
| **Band ordering is a hard gate** | New ids only; no shared combatant retuned. **Ruling A:** both new cells gate at the shipped stop-cell precedent **`win_lo 0.55` / `win_hi 0.95`** — a narrow window is a flaky gate, not a proof. Region-band ordering is evidenced by the **measured medians and win rates recorded in the PR body** (Task 2.5 Steps 4–5, Task 3.4 Step 3, Task 6.1 Step 5), which also re-gate all four shipped Invrisil cells. |
| **A stand-in sprite that reads wrong ships green** | No gate validates a map entity's `sprite` id (`test_combat_visuals.gd:21` is arena decor only; `data_lint.py` check 5 only checks `sprites.json`'s own rows). The first draft shipped unregistered `table`/`bookshelf` on **9** entities. Tasks 1.3/1.4 Step 3 fix the ids in the drafts, table the substitutions, and put a one-line `_comment` on the two genuine stand-ins (`rest_trophy_rack`, `rest_hat_hook`). Task 5.5 shots 3–5 are the eye check. |
| **A raw blocked ring in an `inn`-biome interior renders 39 crates, green** | `tile_board_builder.gd:24-31` pools a `blocked_props` prop onto every uncovered blocked cell; `test_world_visuals.gd:130-166` passes it under a 200-cell budget. Both interiors are authored on the `riverfarm_longhouse` template: `walls.segments` for the perimeter (**never** double-listed in `blocked`), `blocked` for furniture only with a matching `decor` row, plus `floor_layers` and an `ambience` preset. Tasks 1.3/1.4 Step 4, and the scene-dynamism advisory at Task 1.3 Step 6 / Task 1.4 Step 7 (target composite ≥ 50). |
| **`test_combat_visuals.gd` does NOT measure new ids** | **Ruling F.** `FIGURE_ROWS` (`:536-541`) holds four sprites; `_board_cells` would KeyError on any other; the only caller iterates a hardcoded `audited` list with no new id. The suite passes **by exclusion**. The windowed shots are the legibility read, and no unverifiable figure number appears in a shipped `_comment` (the "3.05 cells" claim is struck from `heirloom_fence`). Task 2.5 Step 6, Task 3.4 Step 4. |
| **`render_qa_notes.py` without `--write` is a no-op** | **Ruling E.** `scripts/render_qa_notes.py:55-66` writes only under `--write`; bare prints `QA NOTES DRIFT` and returns 1. Every invocation is `--write` then bare-as-check (Task 5.3 Step 3, Task 6.1 Step 7), and the file is re-rendered at **every** train merge because `render()` walks the whole manifest. |
| **Four-lane shared-file collisions** | **Ruling C.** FILE OWNERSHIP names an explicit anchor row per shared file (`a_gentlemans_disagreement`, `hired_blade_knife_b`, `hedaults_wardstone`, `brothers_parlor`, `hedault_fragment_loop`, `mercantile_alleys`, `near_invrisil_fight`) instead of "append at end", and every new `tests/**` local takes the **`i_`** prefix — Riverfarm and Pallass both wanted a bare `var ledger` in `test_quests.gd`'s single continuous scope (`:90-132`), which is a **parse error**, not a shadow. |
| **`docs/design/character-profiles.md` is shared with Pallass** | **Ruling D.** Controller pre-landed three stub headers; this lane fills `## Hedault` (`:525-527`) **in place** and never appends at EOF. Task 4.1 Steps 1–3, with a diff-discipline check. |
| **Census slack is the WHOLE WAVE's, not this lane's** | **Ruling B.** Per-lane constant is **112**, not 450; this lane states an absolute projection (≈ 4,400 chars against a ≈ 6,175 budget) in the plan and the PR body, re-measures at Task 6.1 Step 3, and the binding check runs on the **merged** tree at every train merge. |
| **Compound-requires trap** | Ruling 10 — the two SKILL arms are separate single-key `{skill}` options. No `{skill, item}` anywhere. |
| **Hedault has no profile** | Ruling 8 — Task 4.1 writes one against `hedault-enchanting-spec.md:8-11` + the in-file contract. |
| **Spec says two remaining shopfronts; four ship** | Ruling 9 — logged as a spec correction; three observes remain (glazier, teahouse, cordwainer). |
| **`[Appraise]` is not an id** | Ruling 2 — `appraise_goods` (`[Appraise Goods]`); `observe` is `[Appraise Foe]` and would read wrong for jewellery. |
| **Door landing cells are unvalidated at runtime** | Both pairs hand-verified in Tasks 1.3/1.4 layout specs: (20,1)↔(6,7) and (6,8)↔(20,2); (18,1)↔(6,7) and (6,8)↔(18,2). |
| **Save-compat: a new blocker on a walkable cell traps old saves** | Both new doors sit on cells already in `blocked` (row 1). The alley encounter at (11,12) is a new occupied cell — its neighbour (11,11) and (10,12) are open, so no save can be trapped. |
| **QA surface drift** | Task 5.3 Step 3 — `derive_qa_surfaces --write` then `--check`, **`render_qa_notes.py --write` then bare**, `check_doc_drift`, all in one commit with the manifest and seed table, and re-run at every train merge. |
| **Census has no margin** | Global Constraints census rule (ruling B: constant **112**, projection ≈ 4,400 chars against a ≈ 6,175 budget); every `_comment` above is a pointer, ladder rationale lives in the census-free `_resolution_order`/`_pick` keys, and `_resolution_paths_comment` is dropped. Measured in Task 6.1 Step 3, re-checked on the merged tree at every train merge. |

### From the cross-cutting recon

| Risk | Mitigation |
|---|---|
| **leads.json counters must already be frozen** | Both leads deferred; drafts parked in **DEFERRED TO CLOSE PR**. |
| **`LANDMARK_TOKENS` hard-fails for new interior beats** | Task 1.5 Step 2 adds both rows and picks `"adventurer"` over the substring-hazardous `"rest"`; both quest blocks' travel beats name a token. |
| **`POPULATION_FLOORS` is a subtraction tripwire** | Task 1.1 Step 4 shows the boulevard count is unchanged by the conversion and +1 from the new door; Task 1.5 Step 4 **counts** the two new floors by the test's own rule (`stationer` **11**, `adventurers_rest` **10** — the first draft's 11/11 would have CONTENT_FAILed). A run prints **no** number: `_validate_population_floors` (`:571-576`) fires `_check` only on failure, so "read it off a run" was unexecutable. |
| **`decor`/`floor_layers`/`ambience` absence is silent** | `world.gd:477` treats `floor_layers` as optional and nothing in `data_lint.py` or `test_content.gd` mentions `decor`. Both new maps carry all three (Tasks 1.3/1.4), so the bare-biome read is not deferred to the final windowed pass. |
| **Vacuous-gate lint** (`VACUOUS_GATE_ALLOWLIST` is empty by design) | This lane authors no `*_when` door/contains/menu gates — both new doors are plain `kind: "door"`. `present_when`/`encounter_when` correctly wrap in `requires`. |
| **Portal arrival lint** | No portals row is added; both interiors are walk-in only, keeping the carrier-vs-row audit trivially green. |
| **Every encounter needs `arena`/`enemies`/`allies`/`on_victory`** | Both new encounters carry all four, with `"allies": []` explicit. |
| **Every combatant needs a positive `power_level`** | All four new rows carry one; `test_combat_data.gd` run in Tasks 2.5/3.4. |
| **Effect dicts are an `elif` chain — one verb each** | Audited explicitly in Task 2.2 Step 3; every effect array in this plan is split. |
| **Grant-duplicate force-consume** | Ruling 6 — `plum_silk_locket` is a distinct new id with exactly one `hide_when`-guarded producer. |
| **Adding a visible option to a shipped hub shifts index-driven scripts** | Both Hedault's and Wilovan's new options are accomplishment-gated (hidden) and appended last; Tasks 2.3/3.2 re-run every script that touches those graphs. |
| **Moods are not gated — a missing row ships green as flat white** | Task 1.5 Step 1 adds both rows. |
| **Fixture-coherence monotone chains** | Task 5.1's base-copy rule (copy `near_invrisil.json`, never hand-author). |
| **`MAP_REQUIRES` for fixtures on new maps** | Task 1.5 Step 3. |
| **Seed/RNG blast radius from any combat-data edit** | Tasks 2.5/3.4 re-gate the shared cells; Task 5.4 re-runs every combat-touching canonical at its pinned seed; every fixture `rng_state` is derived, never typed. |
| **`test_content.gd` collects failures and suppresses PASS** | Verification gate below requires all three of nonzero-exit, `^PASS`, and zero-noise grep — never verdict from the last line. |
| **`QA-SCRIPT-NOTES.md` is generated** | Task 5.3 Step 3. |
| **The inn guest roster is one shared array on 12 rows** | This lane touches **only** `data/dialogue/wilovan_inn.json`, never a row in `data/maps/inn/inn.json`. `WIInnGuests.GUEST_POOL_GATES` is untouched. |
| **Multi-lane shared files** | FILE OWNERSHIP above (ruling C): every shared edit is an **anchored insert after a named row this lane does not share**, never a bare append at the end of a container. |
| **Fresh worktrees need `godot --headless --import`** | Verification gate Step 0. |

---

## Phase 6 — Verification gate and PR

### Task 6.1: The `wi-verifying-changes` bar

- [ ] **Step 0:** If working in a fresh worktree, run `/usr/local/bin/godot --headless --path wandering_inn_game --import` **before any QA**.
- [ ] **Step 1: Structural lint** — `python3 wandering_inn_game/scripts/data_lint.py` from repo root (**this is not pytest**; there is no `scripts/tests/test_data_lint.py` in this layout). Expect clean exit.
- [ ] **Step 2: Load gate** — the headless boot/smoke check, alarm-wrapped.
- [ ] **Step 3: Census** — `python3 scripts/comment_census.py --check` from repo root. Must return 0. **Also measure this lane's absolute new-`_comment` total** and compare it against the ≈ 4,400-char projection (budget ≈ 6,175) in the Census section; report the real number in the PR body so the controller can sum the four lanes:

```
git diff --stat main -- 'wandering_inn_game/data/**'
python3 - <<'PY'
import json, subprocess
from pathlib import Path
def cc(v):
    if isinstance(v, dict):
        return sum(len(i) if k.startswith("_") and "comment" in k and isinstance(i, str) else cc(i) for k, i in v.items())
    if isinstance(v, list):
        return sum(cc(i) for i in v)
    return 0
files = subprocess.check_output(["git","diff","--name-only","main","--","wandering_inn_game/data"]).decode().split()
tot = 0
for f in files:
    now = cc(json.loads(Path(f).read_text()))
    try:
        before = cc(json.loads(subprocess.check_output(["git","show",f"main:{f}"]).decode()))
    except subprocess.CalledProcessError:
        before = 0
    print(f, now - before)
    tot += now - before
print("LANE NEW _comment CHARS:", tot)
PY
```

  If it returns 1, cut `_comment` prose from `data/**` (move it to a QA-script `_comment`, a census-free `_pick`/`_resolution_order` key, or `docs/CHOICE-LOG.md`) until it does — **never** by deleting content JSON. Remember the merge-train rule: the binding check is on the **merged** tree, and final overshoot is the wave-close PR's to own.
- [ ] **Step 4: Every unit suite** — loop every `tests/test_*.gd` under a 240s alarm. For **each** script the bar is all three of: **nonzero-exit absent (rc 0)**, a **`^PASS` line present**, and a **zero-hit grep** for `SCRIPT ERROR|Parse Error|WARNING`. Any one missing is a RED.
- [ ] **Step 5: Balance harness** — `sim_combat_batch.gd` in full under a 600s alarm, same three-part bar. Both new gated cells inside **0.55–0.95** (ruling A), all four shipped Invrisil cells still in window, medians 3–12. **Copy every measured `win_rate` and `median_rounds` into the PR body** — that table, not the window, is the region-ordering evidence.
- [ ] **Step 6: Full canonical sweep** — `wandering_inn_game/qa/ci_sweep.sh` (the background-log-and-poll idiom from Task 5.4 Step 3). Every script green; report per script.
- [ ] **Step 7: Generated-doc drift** — `derive_qa_surfaces.py --check`, **`render_qa_notes.py --write` then bare `render_qa_notes.py`** (ruling E — bare-only does not write and returns 1), `check_doc_drift.py`, `sync_agent_guidance.py`, `scripts/leak_check.sh` — the full `leak-check` job locally. If the bare run prints `QA NOTES DRIFT`, the `--write` did not land in the commit; fix the commit, do not hand-edit the file.
- [ ] **Step 8: Windowed playtest** — Task 5.5, VISUAL-LOG drained.

### Task 6.2: CHOICE-LOG and PR

- [ ] **Step 1: Append this lane's entries to `docs/CHOICE-LOG.md`** — every controller ruling applied and every design fork taken (the list is in the plan-return `choice_log_entries`; do not re-derive, copy it).
- [ ] **Step 2: Open the PR** with title `v0.16 Invrisil depth: A Setting for a Lady + The Hat Stays On, stationer's + Adventurer's Rest (#306)`, using `.github/PULL_REQUEST_TEMPLATE/issue-close.md`:
  - `Closes #306`
  - **Choices made** — the ten lane rulings plus wave rulings A–F plus the forks, each with the rejected alternative and why.
  - **Validation evidence** — exact command + one-line result per gate from Task 6.1, plus **three numbers the controller needs to merge the train**: (a) this lane's measured absolute new-`_comment` char total under `data/**` against the `112 + 0.1765 × new_noncomment` budget; (b) a table of **measured** `win_rate` / `median_rounds` for both new cells and all four shipped Invrisil cells — this table, not the window, is the region-band-ordering evidence; (c) the `scene_dynamism.gd` composite for `stationer` and `adventurers_rest`.
  - **Player-visible proof** — the eight windowed shots from Task 5.5, what was checked by eye. State plainly that shot 7 is the **only** legibility read on the four new combatant rigs, because `test_combat_visuals.gd` does not measure them (ruling F).
  - **New agent context** — the traps this lane added, with `file:symbol`: the ruling-1 pin-stability contract on `hedault_enchanting.json`'s hub; `boulevard_stationer` as a door that still serves its `observe`; the `adventurers_rest` plate pair's `present_when` gating; the never-occupy-row-2 rule on `invrisil_boulevard` and why (`invrisil_walkthrough`'s 36-pass phase grind); the walls-vs-`blocked` template rule that keeps an `inn`-biome interior from rendering a crate ring; and that `POPULATION_FLOORS` counts `encounter_when`-gated rows but not `present_when` ones.
  - **Merge-train notes** — the anchors this lane used (ruling C), the `i_` local prefix in `test_quests.gd`, and the reminder that `render_qa_notes.py --write`, `derive_qa_surfaces.py --write` and `comment_census.py --check` all have to be re-run on the **merged** tree.
  - **Deferred / follow-ups** — the two `data/leads.json` rows, verbatim from the DEFERRED section.
- [ ] **Step 3: The PR head commit message carries `[ci-full]`** so `sweep` and `web-parity` both run.

---

## Exit criteria

1. Both quests are startable, completable on **all three routes each**, and every route banks its spec-named counter; `_resolution_order` is authored on both (`test_quests.gd:136-142`).
2. Both interiors exist, are reachable on foot from the boulevard and return to it, carry a mood row, a `LANDMARK_TOKENS` row, a `MAP_REQUIRES` row and a **counted** `POPULATION_FLOORS` row (`stationer` 11, `adventurers_rest` 10), host ≥1 quest beat each, and keep ≥3 non-quest observables live after their quest closes.
2b. Both interiors are authored on the `riverfarm_longhouse` template — `walls.segments` perimeter with **zero** wall cells double-listed in `blocked`, `blocked` furniture-only with a matching `decor` row per cell, a `floor_layers` pick off the biome default, and an `ambience` preset — and both score ≥ 50 composite on `tools/scene_dynamism.gd`. Every entity `sprite` resolves in `data/sprites.json` (verified by the Task 1.3/1.4 Step 3 one-liner returning `[]`), and the two stand-ins carry their one-line entity `_comment`.
3. `hedault_fragment_loop`, `spine_reach`, `invrisil_walkthrough` and `inn_guests_ext_loop` are green **with zero script edits** — the ruling-1/3/7 pin-stability claim is proven by run, not by argument, and is locked in permanently by `invrisil_v016_gate_check`. Nothing in this lane occupies a row-2 boulevard cell.
4. Both new harness cells are inside **`win_lo 0.55` / `win_hi 0.95`** (ruling A) with medians 3–12; all four shipped Invrisil cells are still in window; no shared combatant was retuned; and the **measured** win rates and medians for all six cells are tabulated in the PR body as the region-band-ordering evidence.
4b. The `[Appraise Goods]` visible-lock contract is proven by **two** scripts: `invrisil_setting_talk` owns the LOCKED pin (fixture without the skill), `invrisil_setting_skill` owns the SELECTABLE pin (fixture with it).
5. Nine canonicals registered in `qa/manifest.json` **and** the AGENTS.md seed table at their named anchors, with `surfaces` and `QA-SCRIPT-NOTES.md` regenerated **via `--write`** in the same commit, and a bare `render_qa_notes.py` returning rc 0 + `PASS: QA notes match manifest`.
6. Each giver carries exactly one reactive `talk_pool_stage` keyed on its quest's terminal, appended after every existing stage; Wilovan's inn register gains exactly one `text_variants` entry and nothing else.
7. `python3 scripts/comment_census.py --check` returns 0, and this lane's **absolute** new-`_comment` total under `data/**` is measured (Task 6.1 Step 3) and reported in the PR body against the ≈ 4,400-char projection and the `112 + 0.1765 × new_noncomment` budget (≈ 6,175 at the drafted volume).
8. The full local gate order (data_lint → load gate → ci_sweep → every `tests/test_*.gd` → headless smoke) is green with the three-part bar reported **per script**.
9. `data/shipped_ids.json` is untouched; `data/leads.json` is untouched; `data/arenas.json`, `data/biomes.json`, `data/sprites.json`, `data/portals.json` and `src/**` are untouched.
