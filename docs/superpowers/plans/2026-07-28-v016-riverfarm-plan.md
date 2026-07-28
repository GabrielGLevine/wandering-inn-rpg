# v0.16 Region Depth — Riverfarm Lane (#305) — Implementation Plan

> Status: **ACTIVE** (v0.16 wave, dispatched 2026-07-28)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Riverfarm's two v0.16 side quests with full three-pillar parity — **R1 `flood_ledger` "The Flood Ledger"** (Former Headman) and **R2 `what_the_thicket_keeps` "What the Thicket Keeps"** (the Hunter) — plus two small walk-in interiors, **`riverfarm_mill`** and **`witch_hut`**, each hosting quest beats and staying open afterwards as observable-rich rooms.

**Authority spec:** `docs/design/2026-07-28-v0.16-region-depth-spec.md` (§ "Riverfarm (#305)" + "Shared conventions"), as amended by the controller rulings recorded in the Global Constraints below. **Do not re-design** — where this plan and the spec differ, the ruling cited in the step wins, and the difference is already logged to `docs/CHOICE-LOG.md` at implementation.

**Issue:** #305. **Branch:** `issue/305-riverfarm-depth` (off `main`). **PR title:** `Riverfarm depth: The Flood Ledger + What the Thicket Keeps, mill + witch hut (#305)`.

**Architecture:** Data-first Godot 4.7 (`wandering_inn_game/`). Everything in this lane is JSON content plus three shared-const table rows; **no `src/` edits at all**. If a step seems to need one, stop and escalate — it means a route was mis-designed.

**Tech Stack:** Godot 4.7 headless for tests; declarative QA scripts in `wandering_inn_game/qa/scripts/`; canonical fixtures with derived `rng_state`.

---

## Global Constraints

**Runner + hygiene**

- Test runner: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/<file>.gd` from repo root. A failed `assert` **HANGS** a headless run forever — alarm-wrap every godot call: `perl -e 'alarm 120; exec @ARGV' -- <command>` (macOS has no `timeout`).
- A unit run is green only on **all three**: nonzero-exit check passes (`rc=0`), a `^PASS` line is present, and `grep -E 'SCRIPT ERROR|Parse Error|WARNING'` returns nothing. `test_content.gd` collects failures and `quit(1)`s while suppressing PASS — never verdict from the last line alone.
- Load the right skill before the matching task: `wi-adding-dialogue-and-quests` (quests/dialogue), `wi-adding-a-scene` (maps), `wi-adding-an-encounter` (combat data), `wi-writing-qa-scripts` (QA), `wi-verifying-changes` (before any green claim), `wi-machine-playtest` (windowed pass).
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- The PR **head commit message must contain `[ci-full]`** so the heavy `sweep` + `web-parity` jobs run.

**Copy rules (binding)**

- Book-17 spoiler bar on every new line. The portal Skill's Vol-9 name is banned — say **"the Magical Door"**. No new-lord politics and no witch-lore politics on screen beyond the shipped oblique framing (the shame is the story in R1; the ward is old and failing in R2, nothing more).
- `{addr}`/`{Addr}` for any PC address, and **only** inside a `text` key, a `talk_pool` entry, a `talk_pool_stages.lines` entry, or a `*toast` key. `data/quests.json` is scanned as an UNRESOLVABLE file — **no `{addr}` in any beat description or resolution text**.
- Register purity: the Former Headman and the Hunter speak in their shipped registers only (read `data/dialogue/riverfarm_headman.json` and `data/dialogue/riverfarm_hunter.json` in full before writing a line). Eloise's new pool line is hearth-register, not business.
- At most **one em-dash per line**; ASCII `--` renders as two literal hyphens, so lint all three dash forms (`—`, `—` escapes, `--`) across both `data/maps/**` and `qa/scripts/**`.
- **No fetch-list copy**: beat descriptions point at a place and a reach, never itemize objects.
- Pool/stage lines are ambient barks: 2 wrapped lines max (`tests/test_copy_fit.gd` `DIALOGUE_LINE_CAPACITY = 2`).
- The tallyman is an **unnamed archetype** ("The Tallyman"), matching the shipped `Former Headman` / `The Hunter` / `riverfarm_charmed_villager` convention — no `docs/design/character-profiles.md` entry is owed. Naming him would owe a wiki-verified profile first; do not name him.

**Census budget (hard gate)**

- `python3 scripts/comment_census.py --check` from **repo root** (not `wandering_inn_game/scripts/`). Measured on `main` at plan time: **DATA 15.0% of a ≤15.0% limit — roughly 383 characters of absolute slack.**
- **The 383 chars are the WHOLE-WAVE slack, split four ways (controller ruling B).** Binding budget for THIS lane: **new `_comment` characters ≤ 112 + 0.1765 × new non-`_comment` characters**, measured with the command above after every task that writes JSON. The `450 + 0.1765x` figure that appeared in the first draft is the combined four-lane constraint, not a per-lane allowance — do not use it.
- **Projected absolute `_comment` total for this lane: 2,647 characters** — measured, not estimated, by summing the eight `data/**` `_comment` strings this plan authorises verbatim (quests 292 + 221, combatants 377 + 242, `mill_granary_scavengers` 315, `riverfarm_mill_door` 379, `hut_ward_scrap` 424, `witch_hut_door` 397). **That total requires ≥ 14,363 new non-`_comment` characters in `data/**` to stay inside `112 + 0.1765x`** — the two new map files, the new dialogue file, the dialogue appends, the quest blocks and the four combatant rows clear that comfortably, but **re-measure after Task 6** and, if the ratio is short, cut comment text (never invent filler). **State this number in the PR body** so the controller can sum the four lanes before the merge train starts.
- **Merge-train rule:** the census is re-run on the **MERGED tree** at every train merge, not on this branch alone. A green `--check` on `issue/305-riverfarm-depth` is necessary and not sufficient. Any final overshoot after the last merge is owned by the **wave-close PR**, not by this lane — but design to the budget above rather than to that backstop.
- Long rationale goes in **QA-script `_comment`s** (`qa/**` is outside the DATA census — `comment_census.py` walks `data/**` for the JSON ratio) or **`docs/CHOICE-LOG.md`** — both census-exempt. Inside `data/**`, prefer **one trap comment per seam** over per-entity prose. The eight seams that earn a comment in this lane are named in their tasks; everything else ships comment-free.

**Gate shapes (sanctioned only)**

- `door_when` / `contains_when` / `portal_menu_when` / `fence_menu_when` must **wrap counters in `"requires"`** — a bare counter dict is vacuously true and `VACUOUS_GATE_ALLOWLIST` is empty by design (`scripts/data_lint.py:221-239`).
- `hide_when` is **AND-semantics** — a multi-key `hide_when` only hides when EVERY key matches. Every `hide_when` written in this lane is single-key.
- Dialogue `requires`/`hide_when` use the sanctioned single keys only (`skill`, `class`, `accomplishment`, `gold`, `once_per_waking`, `item`, `race`, `phase`, `board_accepted`, `delivery_accepted`) or one of the six sanctioned two-key compounds. **Every gate this lane writes is single-key.** `hide_when` may never carry `once_per_waking`.
- **Each effect dict carries exactly one verb.** The runtime applier is an `elif` chain (`src/core/wi_game.gd:1071-1131`) — a two-key dict silently drops one AND fails `test_content`. Author `[{...},{...}]`.
- `requires.accomplishment` HIDES an option; `requires.skill` leaves it VISIBLE-LOCKED. Every node carrying a `hide_when` or accomplishment-`requires` option must keep ≥1 option with neither key (`_validate_hide_when_nodes_have_always_available_exit`).
- `on_skill_use` banks **exactly one** counter — `record_accomplishment(String(effect["accomplishment"]))`, `src/core/wi_game.gd:480`. `on_victory` and `on_open_accomplishment` accept `String|Array`; `on_skill_use.accomplishment` does not. This is why both quests use per-route report options instead of a shared resolve counter (see Tasks 1a/1b).

**Counter freeze**

These are the **freeze names, verbatim, at first write** (they lock at the next release cut). Spec names are used unchanged; the four not in the spec are named here and logged.

| counter | role | producer |
|---|---|---|
| `heard_flood_ledger` | R1 start flag (new name; mirrors `heard_price_of_a_favor`) | headman hub option |
| `ledger_read_true` | R1 TALK route | `riverfarm_tallyman` dialogue |
| `flood_prep_done` | R1 HELP route | `mill_flood_stack` `skill_uses` |
| `granary_cleared` | R1 FIGHT route | `mill_granary_scavengers` `on_victory` |
| `flood_ledger_settled` | R1 TERMINAL | headman report options |
| `heard_thicket_keeps` | R2 start flag (new name) | hunter hub option |
| `herd_rerouted` | R2 TALK route | `riverfarm_hunter` dialogue |
| `ward_scrap_read` | R2 SKILL route | `hut_ward_scrap` `on_skill_use` |
| `thicket_cleared` | R2 FIGHT route | `thicket_line_den` `on_victory` |
| `thicket_answered` | R2 TERMINAL | hunter report options |
| `observed_riverfarm_mill`, `observed_witch_hut` | door `on_enter_accomplishment` | new doors |
| `observed_mill_wheel_pit`, `observed_mill_high_shelf`, `observed_mill_tally_sticks` | mill observables | new props |
| `observed_hut_stoppered_jars`, `observed_hut_drying_rack`, `observed_hut_hearth_ash`, `observed_hut_shuttered_window` | hut observables | new props |

- **Every one of these is data-derived** by `scripts/generate_shipped_ids.py`'s producer walk (dialogue effects, `on_victory`, `on_skill_use.accomplishment`, `on_interact_accomplishment`, `on_enter_accomplishment`, `talk_pool` → `chatted_with_mill_tallyman` + `heard_gossip`). **Zero hand-adds to `STRUCTURAL_LITERALS`.** Do not touch `generate_shipped_ids.py` or `tests/test_shipped_ids.gd`.
- **Never regenerate `data/shipped_ids.json`** — it is release-cut-only (`RELEASE = "0.15.0"`). A new v0.16 counter absent from it is a non-event for `test_shipped_ids.gd`.

**Leads-strip rule**

- `test_content.gd:78` `_validate_leads` checks every `requires`/`hide_when` counter against `data/shipped_ids.json`'s frozen accomplishment list (RELEASE 0.15.0). Both Riverfarm lead rows would key their `hide_when` on `heard_flood_ledger` / `heard_thicket_keeps`, which are **not** in the 0.15.0 freeze. **Therefore this lane adds ZERO rows to `data/leads.json`.** The drafts live in the "Deferred to close PR" section below and land after the next freeze regeneration.

---

## File ownership

**EXCLUSIVE to this lane (own outright, no coordination):**

- `wandering_inn_game/data/maps/riverfarm/riverfarm_village.json` (1 door-entity append + 2 `talk_pool_stages` appends; **NO `decor` append** — the door entity carries `"sprite": "door"` itself, so the paired decor row the first draft called for would render a second door on the same cell)
- `wandering_inn_game/data/maps/riverfarm/witch_hollow.json` (2 entity appends + 1 talk_pool_stage append)
- `wandering_inn_game/data/maps/riverfarm/riverfarm_mill.json` **(new)**
- `wandering_inn_game/data/maps/riverfarm/witch_hut.json` **(new)**
- `wandering_inn_game/data/dialogue/riverfarm_headman.json`, `.../riverfarm_hunter.json`
- `wandering_inn_game/data/dialogue/riverfarm_tallyman.json` **(new)**
- `wandering_inn_game/qa/scripts/flood_ledger_*.json`, `.../thicket_keeps_*.json` **(new)**
- `wandering_inn_game/qa/fixtures/flood_ledger_*_start.json`, `.../thicket_*_start.json` **(new)**

**SHARED with the Invrisil (#306), Pallass (#307) and Floodplains lanes — APPEND-ONLY blocks, merge-train resolves conflicts.**

**Anchor discipline (controller ruling C) — binding.** Four lanes appending at the same EOF/last-row point is a designed-in four-way conflict on one line. Every shared append in this lane lands **immediately after a named existing row that no other lane touches**, named in the table below. Never "append at the end of the array" — that phrasing is banned in this lane. New locals in shared test files take this lane's prefix **`r_`**.

| file | this lane's append | ANCHOR — insert immediately after |
|---|---|---|
| `data/quests.json` | 2 quest objects | the `price_of_a_favor` object (Riverfarm's own shipped quest; no other lane touches it) |
| `data/combatants.json` | 4 rows: `granary_scavenger_a/_b`, `line_stalker_a/_b` | the `thicket_remnant_b` row (Riverfarm's own roster) |
| `data/arenas.json` | **NOT TOUCHED** — this lane reuses `inn_cellar` and `witch_hollow` (see Task 2 rationale) | — |
| `data/moods.json` | 2 rows under `moods`: `riverfarm_mill`, `witch_hut` | the **`witch_hollow`** key (ruling C: Floodplains takes `floodplains`, Riverfarm `witch_hollow`, Invrisil `brothers_parlor`, Pallass `pallass_forge` — so no two lanes touch the same closing brace) |
| `data/leads.json` | **NOT TOUCHED** (leads-strip rule above) | — |
| `docs/design/character-profiles.md` | **SHARED, not exclusive to any lane** (ruling D). This lane writes **nothing** here — the tallyman is an unnamed archetype. If a profile ever becomes owed, the controller pre-lands a stub section header in the plan commit and the lane **FILLS ITS OWN STUB IN PLACE**; appending at EOF is banned for every lane. | — |
| `qa/manifest.json` | 6 script entries + generated `surfaces` | the `witch_cottage_reachability` entry (Riverfarm-owned) |
| `tests/test_content.gd` | `LANDMARK_TOKENS` (:1344) — 2 rows, after the `"riverfarm_village"` row. `POPULATION_FLOORS` (:532) untouched (this lane only ADDS unconditional interactables; floors are minimums) | the `"riverfarm_village"` LANDMARK_TOKENS row |
| `tests/sim_combat_batch.gd` | `RIVERFARM_CELLS` (:96) — 2 gated cells. `total_cells` (:321) is **computed from array sizes** and needs no edit | the `riverfarm_thicket_patch_t3_solo` cell (:114) — Riverfarm-exclusive array, no cross-lane hazard |
| `tests/test_fixture_coherence.gd` | `MAP_REQUIRES` (:31) — 2 rows; `COMBAT_BAND_FIXTURES` (:19) — 2 rows | the `"witch_hollow"` MAP_REQUIRES row; the `"riverfarm_fight_start"` COMBAT_BAND_FIXTURES row |
| `tests/test_quests.gd` | 2 co-bank ladder pin blocks, locals named **`r_ledger` / `r_thicket`** | the `var order` (`wrong_order`) pin block, i.e. **BEFORE** the `price_of_a_favor` comment block — Pallass anchors after `price_of_a_favor`, so the two lanes never touch the same line |
| `wandering_inn_game/AGENTS.md` | 6 seed-table rows | the `thicket_cull_loop` row (:363) |
| `docs/CHOICE-LOG.md` | this lane's decision entries | — |

**Local-name collision (ruling C, from the cross-lane review):** `tests/test_quests.gd:90-132` is ONE continuous function body at a single indent level, so every co-bank pin shares one scope. Pallass appends `var ledger` for `ledger_eats_first`; a second `var ledger` here is a **duplicate declaration that fails to parse**, not a shadow, and reds the whole suite the moment the second lane merges. Hence `r_ledger` / `r_thicket`, and every future new local in a shared `tests/*.gd` file in this lane carries the `r_` prefix.

**GENERATED — regenerate, never hand-edit:**

- `qa/manifest.json` `surfaces` blocks → `python3 wandering_inn_game/scripts/derive_qa_surfaces.py` (and `--check` is the fatal drift gate `ci_sweep.sh` runs every invocation).
- `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` → **`python3 scripts/render_qa_notes.py --write`** (the WRITE), then **bare `python3 scripts/render_qa_notes.py`** (the CHECK: `rc=0` + `PASS: QA notes match manifest`), then `python3 scripts/check_doc_drift.py`. **A bare invocation does NOT regenerate the file** — `render_qa_notes.py:55-66` only writes under `--write` and otherwise prints `QA NOTES DRIFT` and returns 1. Every occurrence of this command in this plan is the two-step form (controller ruling E). All three run in the same commit as any manifest or QA-script `_comment` change — a forgotten regeneration is the #312 CI red.
  - **Merge-train note:** `render()` walks the ENTIRE manifest, so the file must be re-rendered on **every train merge that combines two lanes' manifest entries**, not only inside this lane's own commit. This lane's green render is stale the moment another lane's manifest rows land.
  - By contrast `derive_qa_surfaces.py` **bare IS a write** (`main(argv)` returns `cmd_write()` on empty argv) — the bare calls to that script in this plan are correct as written, and `--check` is the drift gate.
- `data/shipped_ids.json` → tag-time only. Never in this PR.

**Shipped-JSON splice discipline:** for the two top-level array containers use `python3 wandering_inn_game/scripts/splice_json.py --file data/quests.json --container quests --record '{...}'` and `--file data/combatants.json --container combatants`. It proves placement and byte-identity outside the splice and exits non-zero with the file untouched on failure. Serializer round-trips are BANNED for shipped JSON (`python json.dump` defaults `ensure_ascii=True` and rewrites every literal em-dash). Nested appends (map `entities`, `talk_pool_stages`) are hand edits that must match the file's own indentation — `quests.json` is TAB-indented, `combatants.json` and the riverfarm maps are 1-space-per-level.

**Splice tool vs. the anchor rule — read before Task 1a.** `splice_json.py` splices **only before the container's closing bracket** (it has no `--after`; verified in its own docstring and `scan_container_span`), so a tail append is all it can do, and a tail append is exactly the four-way conflict ruling C forbids. The sanctioned procedure for `quests.json` and `combatants.json` in this lane is therefore:

1. `splice_json.py ... --dry-run` to get the record re-indented to the file's own last-sibling style (this is the part that used to be got wrong by hand);
2. paste that exact block **immediately after the anchor object's closing brace** (anchors in the table above) as a hand edit;
3. verify: `python3 -c "import json;d=json.load(open('<file>'));print(len(d['<container>']))"` rose by exactly 1 per record, the new id appears at the intended index, and `git diff` shows **one contiguous added hunk at the anchor** and nothing else.

Record this as a deviation from the splice-only convention in `docs/CHOICE-LOG.md`; the anchor rule outranks it because a merge conflict on `quests.json` costs the whole train.

---

## Task 1: `data/quests.json` — the two quest blocks, spliced SEPARATELY (1a and 1b)

**THIS TASK IS TWO TASKS ON PURPOSE.** The first draft spliced both blocks up front, but Task 5 commits R1's half of the tree and Task 6 commits R2's half — and `tests/test_content.gd:1322 _validate_quests` fails on any beat counter without a producer, so R2's block (`herd_rerouted`, `ward_scrap_read`, `thicket_cleared`, `thicket_answered`) **must not be in the tree at Task 5's commit**. Splicing both up front would force hunk-level staging of a file whose whole discipline is "one splice run produces the whole-file state". So:

- **Task 1a** (`flood_ledger` only) runs **immediately before Task 5's commit**, after Task 3's mill work is in the working tree.
- **Task 1b** (`what_the_thicket_keeps` only) runs **immediately before Task 6's commit**, after Task 4's hut work is in the working tree.

Each commit is then a whole-file state produced by a single anchored splice, and the tree is never red.

**Files:**
- Modify: `wandering_inn_game/data/quests.json` (1 object per sub-task, inserted after the `price_of_a_favor` anchor)
- Test: `res://tests/test_content.gd`, `res://tests/test_quests.gd`, `python3 wandering_inn_game/scripts/data_lint.py`

**Interfaces:**
- Produces: quest id `flood_ledger` (1a), quest id `what_the_thicket_keeps` (1b). Tasks 3–6 bank every counter these beats read.
- Consumes: 1a consumes Task 3 + Task 5's producers being in the working tree; 1b consumes Task 4 + Task 6's. **Read Tasks 3–6 first, then come back here** — the quest text below is frozen, but the splice happens late.

**THE ROUTE-REPORT SHAPE (design fork, ruling-adjacent, log it).** The shipped `price_of_a_favor` gates its single report option on `blight_lifted`, one shared counter all three routes bank. That shape is **unavailable here**: R1's HELP route and R2's SKILL route bank through `on_skill_use`, which banks exactly one counter (`src/core/wi_game.gd:480`), so no shared resolve counter can cover them without inventing a second producer for one route only. Instead both quests use **`complete_when_any` over the three route counters** (the shipped `cisterns` resolve-beat idiom, `quests.json:35`) and **three route-specific report options** on the giver's hub, each gated on a single-key accomplishment `requires` and each banking the terminal. This adds no counters beyond the spec's, gives each route its own report line, and keeps every gate single-key.

- [x] **Step 1 (both sub-tasks): Read `data/quests.json` `price_of_a_favor` (:104-119) and `cisterns` (:30-44) first.** Match their TAB indentation and their `_comment` economy exactly. `price_of_a_favor` is also this lane's **insert anchor** — both blocks go immediately after its closing brace, per the anchor rule above.
- [x] **Step 2 (TASK 1a — run just before Task 5's commit): insert `flood_ledger` after `price_of_a_favor`:**

```json
{
	"_comment": "v0.16 #305 R1. Beat 1 is complete_when_any over the three route counters (cisterns idiom): the HELP route banks through on_skill_use, which banks exactly ONE counter (wi_game.gd:480), so no shared resolve counter can cover all three -- the headman carries one REPORT option per route instead.",
	"id": "flood_ledger",
	"title": "The Flood Ledger",
	"region": "Riverfarm",
	"beats": [
		{ "id": "resolve", "description": "The mill's grain tally is short and the village is quietly accusing itself. Walk the tally at the mill by the river, work the flood prep there, or clear whatever has been living in the granary corner.", "complete_when_any": { "ledger_read_true": 1, "flood_prep_done": 1, "granary_cleared": 1 } },
		{ "id": "report", "description": "Bring the headman an answer he can live with, at the village square.", "complete_when": { "flood_ledger_settled": 1 } }
	],
	"_resolution_order": "WEAKEST CLAIM FIRST (resolved_path is last-match-wins) and all three co-bank -- clear the granary, then still walk the tally. Ladder: read > worked > cleared. Driving vermin out of the corner explains eleven bushels of spoilage; standing in the shed until the count can be SEEN is better; naming the failed crop without naming the household is the answer the headman actually needed.",
	"resolution_paths": [
		{ "accomplishment": "granary_cleared", "text": "You cleared the granary corner, and the shortfall stopped growing." },
		{ "accomplishment": "flood_prep_done", "text": "You worked the flood prep at the mill until the count came right in the doing." },
		{ "accomplishment": "ledger_read_true", "text": "You walked the tally and found a failed crop where the village had looked for a thief." }
	]
}
```

- [x] **Step 3 (TASK 1b — run just before Task 6's commit): insert `what_the_thicket_keeps` after `flood_ledger`** (which by then is the anchor's new neighbour):

```json
{
	"_comment": "v0.16 #305 R2. Same route-report shape as flood_ledger. The SKILL route reads the ward and banks ward_scrap_read ONLY -- it must never bank detected_wardwork (trapped_halls.json:355 protects that counter's >=3 threshold).",
	"id": "what_the_thicket_keeps",
	"title": "What the Thicket Keeps",
	"region": "Riverfarm",
	"beats": [
		{ "id": "resolve", "description": "The corusdeer herd stops dead at a line in the thicket it will not cross. Read the sign with the hunter, read the old boundary work in the hut at the hollow, or clear whatever has denned on the line.", "complete_when_any": { "herd_rerouted": 1, "ward_scrap_read": 1, "thicket_cleared": 1 } },
		{ "id": "report", "description": "Tell the hunter what the thicket is keeping, back at his post in the village.", "complete_when": { "thicket_answered": 1 } }
	],
	"_resolution_order": "WEAKEST CLAIM FIRST (resolved_path is last-match-wins) and all three co-bank -- kill the den, then still read the ward. Ladder: read > rerouted > cleared. Killing the predator moves one animal off a line that was never about the predator; moving the fences is the humble, correct answer; reading the boundary is the only one that explains why the line is there at all.",
	"resolution_paths": [
		{ "accomplishment": "thicket_cleared", "text": "You cleared the den off the line and let the herd try again." },
		{ "accomplishment": "herd_rerouted", "text": "You moved the fences instead of the deer, and the herd kept its road." },
		{ "accomplishment": "ward_scrap_read", "text": "You read the old boundary work and learned what the thicket has been keeping out." }
	]
}
```

- [x] **Step 4: Run** `python3 wandering_inn_game/scripts/data_lint.py` — expect clean. Then `res://tests/test_content.gd`: because each block is spliced only once its own producers are already in the working tree, **this must be GREEN at both 1a and 1b**. A `waits on unproduced accomplishment` failure here means the splice ran too early — back it out and finish the producing task first. **Never commit a red tree.**
- [x] **Step 5: Census** `python3 scripts/comment_census.py --check` — expect `rc=0`. (Both quest `_comment`s together are ~480 chars against this lane's ~2,420 projection.)

---

## Task 2: `data/combatants.json` + `tests/sim_combat_batch.gd` — both fights

**Files:**
- Modify: `wandering_inn_game/data/combatants.json` (4 new rows, splice_json)
- Modify: `wandering_inn_game/tests/sim_combat_batch.gd` (`RIVERFARM_CELLS`, 2 gated cells)
- Test: `res://tests/test_combat_data.gd`, `res://tests/test_combat_visuals.gd`, `res://tests/sim_combat_batch.gd`

**Interfaces:**
- Produces: combatant ids `granary_scavenger_a/_b`, `line_stalker_a/_b`; harness cells `granary_scavengers_t3_warrior10_solo`, `thicket_line_den_t3_warrior10_solo`. Tasks 3–4 roster them on encounter entities.

**Rulings applied.** Ruling 2: R1 FIGHT uses **NEW distinct-id roster-only combatants** — never `goblin_raider` (power_level 2.0, four bands below Riverfarm's own content, and the reason the "reuse the scavenger rig family" line in the spec cannot be taken literally: `data/maps/liscor/street.json:1700`/`:1732` are the only shipped "scavenger" encounters and both roster `goblin_raider ×2`). Both new pairs are banded at **`thicket_remnant`'s exact numbers** (`combatants.json:1060`, pl 7.5, str 17 / dex 10 / con 24 / int 2 / wis 6 / cha 2, `weapon_die` 6, `ai` melee, no skills) and differ from each other **only by `combat_tint`** — the shipped roster-only/distinct-id convention (`combatants.json:468`, "a distinct id IS the override").

**WINDOW RULING A (binding, supersedes the first draft's 0.72–0.85).** Both new cells are gated at **`win_lo` 0.55 / `win_hi` 0.95** — the shipped **stop-cell** precedent, `riverfarm_thicket_patch_t3_solo` at `sim_combat_batch.gd:114`, which is the cell with the identical roster stats, `t3_warrior10` build and `solo` shape these two copy. The 0.72–0.85 window belongs to `:111 briar_collectors_deep_t3_warrior10_hunter`, a **ladder rung** whose narrow window exists only to keep four ordered rungs disjoint; these two cells are not rungs and must not inherit it. Two facts make the narrow window actively wrong here: `RUNS_PER_CELL := 100` (`:6`) gives sigma ≈ 0.039 at p ≈ 0.81, so a 0.04 upper margin is ~1 sigma — roughly a 1-in-6 false red per run per cell — and `granary_scavengers` fights on **`inn_cellar`**, a layout the 0.81 figure never covered, so the inherited rate is a cross-arena extrapolation, not a measurement.

**Region-band ordering is proven by RECORDED MEDIANS, not by narrow windows.** Run `WI_CELL_RANGE` on the two new cells, record each cell's **measured win rate and median rounds in the PR body**, and state there that both sit inside the Riverfarm stop band alongside `riverfarm_thicket_patch_t3_solo`'s own measured rate. That is the ordering evidence; the gate's job is only to catch a real regression.

**No new arena, on purpose.** `data/arenas.json` is a four-lane shared file and this lane needs nothing it does not already have: the granary fight reuses **`inn_cellar`** (biome `inn`, 12×8, 5 blocked, the shipped interior-arena language the mill's own biome matches), the den fight reuses **`witch_hollow`** (the arena `riverfarm_thicket_patch` already fights on). Leaving `arenas.json` untouched removes one merge-train conflict surface.

- [x] **Step 1: Read `data/combatants.json:1055-1085`** (`thicket_remnant_a/_b`) and `:468` (the roster-only convention comment). Match the 1-space-per-level indentation.
- [x] **Step 2: Splice the four rows** (`splice_json.py --file data/combatants.json --container combatants --record '<one row>'`, once per row):

```json
{
 "_comment": "v0.16 #305 R1 FIGHT. Roster-only clone of thicket_remnant's numbers (a distinct id IS the override, see :468) so the granary fight sits in the Riverfarm stop band. NOT goblin_raider: that Act-I rig sits four bands under this stop. Balance: sim_combat_batch.gd RIVERFARM_CELLS' `granary_scavengers_t3_warrior10_solo`, gated 0.55-0.95 (the stop-cell window, not a ladder rung's).",
 "id": "granary_scavenger_a",
 "power_level": 7.5,
 "display_name": "Granary Scavenger",
 "sprite": "bat",
 "combat_scale": 0.56,
 "combat_tint": [ 1.3, 1.12, 0.7 ],
 "side": "enemy",
 "stats": { "str": 17, "dex": 10, "con": 24, "int": 2, "wis": 6, "cha": 2 },
 "weapon_die": 6,
 "ai": "melee",
 "skills": []
}
```

```json
{
 "id": "granary_scavenger_b",
 "power_level": 7.5,
 "display_name": "Granary Scavenger",
 "sprite": "bat",
 "combat_scale": 0.56,
 "combat_tint": [ 0.96, 0.86, 0.72 ],
 "side": "enemy",
 "stats": { "str": 17, "dex": 10, "con": 24, "int": 2, "wis": 6, "cha": 2 },
 "weapon_die": 6,
 "ai": "melee",
 "skills": []
}
```

```json
{
 "_comment": "v0.16 #305 R2 FIGHT. Same roster-only clone at the mothbear silhouette so the den never reads as the briar-collector family riverfarm_thicket_patch already owns. Balance: RIVERFARM_CELLS' `thicket_line_den_t3_warrior10_solo`, gated 0.55-0.95.",
 "id": "line_stalker_a",
 "power_level": 7.5,
 "display_name": "Line Stalker",
 "sprite": "mothbear",
 "combat_tint": [ 0.78, 0.86, 0.7 ],
 "side": "enemy",
 "stats": { "str": 17, "dex": 10, "con": 24, "int": 2, "wis": 6, "cha": 2 },
 "weapon_die": 6,
 "ai": "melee",
 "skills": []
}
```

```json
{
 "id": "line_stalker_b",
 "power_level": 7.5,
 "display_name": "Line Stalker",
 "sprite": "mothbear",
 "combat_tint": [ 0.66, 0.72, 0.82 ],
 "side": "enemy",
 "stats": { "str": 17, "dex": 10, "con": 24, "int": 2, "wis": 6, "cha": 2 },
 "weapon_die": 6,
 "ai": "melee",
 "skills": []
}
```

`combat_scale` 0.56 on the `bat` rig mirrors `sewer_vermin`'s shipped value.

**New-id figure bar (controller ruling F), stated plainly:** `tests/test_combat_visuals.gd` **does NOT measure any new id in this lane — it passes by exclusion.** The bar runs only over the fixed `audited` array (`:609-611`), which contains none of these four ids, and `_board_cells` reads `FIGURE_ROWS[sprite]` where `FIGURE_ROWS` (`:536-541`) holds exactly `bat`, `briar_collector`, `briar_collector_deep`, `ruin_warden` — an unlisted sprite is a **KeyError, not a pass**. So: **do NOT add any of these four ids to `audited`**, and **do not put a derived figure number (cells, rows, "inside the band") into any shipped `data/**` `_comment`** — nothing in CI can verify it and it costs census. The legibility read for these rigs is the **windowed shot** in Task 10 Step 4, and it is the only claim allowed in the VISUAL-LOG row. (`mothbear` ships at default scale and is not in `FIGURE_ROWS` either.)

- [x] **Step 3: Append two gated cells to `RIVERFARM_CELLS`** (`tests/sim_combat_batch.gd`, after the `briar_collectors_deep_t5_sw14_hunter` rung at :125 so the main-line ladder rung stays visually last is NOT required — append after `riverfarm_thicket_patch_t3_solo` at :114 to keep the stop-band cells together):

```gdscript
	# v0.16 #305: the two new Riverfarm side-quest fights, both SOLO (neither
	# encounter fields the hunter -- the granary is inside the mill and the den
	# is the FIGHT alternative to walking the line with him). Same stats as
	# thicket_remnant and the SAME WINDOW as the stop cell above (0.55-0.95):
	# these are stop-band cells, not ladder rungs, and the rungs' narrow
	# windows exist only to keep four ordered rungs disjoint. At 100 runs per
	# cell sigma is ~0.04, so a rung-width window here would false-red on noise.
	# Region-band ORDERING is evidenced by the measured medians recorded in the
	# PR body, not by the gate. If a run lands outside 0.55-0.95, move the DATA
	# (con/weapon_die), never the window.
	{"name": "granary_scavengers_t3_warrior10_solo", "arena": "inn_cellar", "enemies": ["granary_scavenger_a", "granary_scavenger_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "thicket_line_den_t3_warrior10_solo", "arena": "witch_hollow", "enemies": ["line_stalker_a", "line_stalker_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
```

`total_cells` at `sim_combat_batch.gd:321` is `... + RIVERFARM_CELLS.size() + ...` — **computed, no edit needed.** Confirm with `WI_CELL_COUNT_ONLY=1` that the count rose by exactly 2.

- [x] **Step 4: MEASURE FIRST, then iterate cheaply.** `WI_CELL_COUNT_ONLY=1 godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd` to find the new cells' 0-based indices, then `WI_CELL_RANGE=LO:HI` to run only those two (100 runs each). **Write down each cell's win rate and median rounds — these two numbers are the PR body's band evidence and the reason the gate can stay wide.** Expect win_rate inside **0.55–0.95** and median rounds in **3–12**. If either misses: adjust `con` (24 → 22 raises the win rate, 24 → 26 lowers it) and re-run the slice. **Never widen the window past the stop-cell precedent** — if a cell cannot sit inside 0.55–0.95, the roster is wrong, not the gate.
- [x] **Step 5: Run** `res://tests/test_combat_data.gd` (power_level presence, arena spawn reachability) and `res://tests/test_combat_visuals.gd` — expect PASS on both.
- [x] **Step 6: Run the FULL `res://tests/sim_combat_batch.gd`** under a 600s alarm — every other gated cell must still be in band (a new roster row cannot move them, but this is the proof, not the assumption).
- [x] **Step 7: Census** check; **commit** `feat(combat): granary scavengers and line stalkers, banded at the Riverfarm stop`.

---

## Task 3: `riverfarm_mill` interior + the village door

**Files:**
- Create: `wandering_inn_game/data/maps/riverfarm/riverfarm_mill.json`
- Modify: `wandering_inn_game/data/maps/riverfarm/riverfarm_village.json` (1 entity + 1 decor)
- Modify: `wandering_inn_game/data/moods.json` (1 row), `wandering_inn_game/tests/test_content.gd` (`LANDMARK_TOKENS`), `wandering_inn_game/tests/test_fixture_coherence.gd` (`MAP_REQUIRES`)
- Test: `python3 wandering_inn_game/scripts/data_lint.py`, `res://tests/test_content.gd`

**Interfaces:**
- Produces: map key `riverfarm_mill`; counters `observed_riverfarm_mill`, `flood_prep_done`, `granary_cleared`, `observed_mill_wheel_pit`, `observed_mill_high_shelf`, `observed_mill_tally_sticks`; entity `mill_tallyman` hosting conversation `riverfarm_tallyman` (Task 5).
- Consumes: combatant ids from Task 2; `heard_flood_ledger` (Task 5) as the encounter gate.

**Stem uniqueness (ruling 6) — verified at plan time:** no `riverfarm_mill` map file exists under `data/maps/*/`, and `data/arenas.json` has no `riverfarm_mill` id. `WISceneCatalog._compose()` derives the map key from the **file basename** (`scene_catalog.gd:24`), so the file MUST be `riverfarm_mill.json`, not the spec's `mill.json`. Re-run the grep before writing: `ls wandering_inn_game/data/maps/*/ | sort` and `grep -n '"id"' wandering_inn_game/data/arenas.json`.

**Door placement (ruling 5) — hand-verified, and CORRECTED in fix round 1.** The windmill footprint blocks (19,4),(20,4),(21,4),(19,5),(20,5),(21,5); `riverfarm_windmill_prop` occupies (20,4) and `riverfarm_dock` occupies (20,6). **Door at [19,5]** (a blocked art cell — the exact `longhouse_door` precedent, which sits on blocked (11,7)), **`to_cell` [19,6]**.

**[19,5] has TWO legal approaches, not one.** Re-derived: of its cardinal neighbours, (19,4) is blocked and (20,5) is blocked, but **BOTH (19,6) and (18,5) are free** — (18,5) carries no `blocked`, no entity and no decor (the nearest decor is `riverfarm_rowboat` at [22,5]). The first draft asserted (19,6) was the only free cardinal neighbour; that was wrong and the `_comment` below is corrected accordingly. **Do NOT add blocking decor to close (18,5)** — two approaches on a village-edge door is fine, and a new blocked cell would be a live change to a heavily-pinned shipped map for cosmetic tidiness.

**The asymmetry is deliberate and must be written into the task:** a player who approaches from **(18,5)** enters the mill and, on exiting, arrives at **(19,6)** — *not* the cell they were standing on. `mill_exit`'s `to_cell` is a single fixed cell, so the "you come out where you went in" convention (`riverfarm_longhouse.json:267`) holds only for the (19,6) approach. (19,6) is chosen as the exit target because it is the approach the QA canonicals use and the one facing open ground; (18,5) sits against the tower's west face. Note this in the CHOICE-LOG entry — a playtester entering from the west WILL notice the one-cell shift.

**Neither approach is touched by any walked QA route** (re-derived per map for all eight `riverfarm_village`-touching scripts): `longhouse_walkthrough`'s 16-cell walked union is row 4 x7–13, column 7 y4–8 and row 8 x8–11; `thicket_cull_loop` pins (17,15)/(17,14); `regional_work_loop` pins (3,11)/(3,10); `riverfarm_walkthrough`/`riverfarm_fight`/`riverfarm_talk`/`riverfarm_skill` pin (13,5),(2,13),(2,12),(2,11),(10,9),(11,10),(11,8),(11,3),(7,10),(12,4),(12,10). **None of them is (19,5), (19,6), (18,5), (18,6) or (19,7)** — the (18,5)/(18,4) hits that turn up in `regional_work_loop` and `spine_reach` are on `pallass_forge`/`pallass_market`, a different map. Reachability of (19,6): open from (18,6) and (19,7); (20,6) is the dock entity and blocks, which is fine.

- [x] **Step 1: Load `wi-adding-a-scene`. Read `data/maps/riverfarm/riverfarm_longhouse.json` in full** — it is the structural template (biome `inn`, `floor_layers` with `"cells": "all"`, `walls.segments` with `from`/`to`/`cap`/`face`, `decor`, `ambience` preset `dust_motes`). **Perimeter walls are rendered by `walls.segments` and block implicitly — never double-list a wall cell in `blocked`.** `blocked` holds furniture cells ONLY, each mirrored by a `decor` entry.
- [x] **Step 2: Write `data/maps/riverfarm/riverfarm_mill.json`** to this layout spec (12×9 — under the 14×10 parlor yardstick, and under the spec's own ≤14×10 mill cap):

**Grid:** `{"width": 12, "height": 9}`. **Biome:** `"inn"` (the longhouse's own choice; no `data/biomes.json` edit).

**Walls (implicitly blocking, playable interior is x1–10 / y1–7):**
```
row 0: (0,0)-(11,0)      col 0: (0,1)-(0,8)      col 11: (11,1)-(11,8)
row 8: (1,8)-(5,8) and (7,8)-(10,8)     ← the gap at (6,8) is the exit door
```

**`blocked` (furniture only, each with a matching `decor` entry):** `[[5,4],[6,4],[3,6],[4,6],[7,2]]` — the millstone pair, two stacks of sacks, the hoist post. Every interior cell stays mutually reachable from (6,7): verify by eye on the grid before committing.

**Entities (7):**

| id | kind | cell | approaches (all verified free) |
|---|---|---|---|
| `mill_exit` | door | [6,8] | (6,7) |
| `mill_tallyman` | npc | [4,3] | (4,2)(4,4)(3,3)(5,3) |
| `mill_flood_stack` | prop | [8,3] | (8,2)(8,4)(7,3)(9,3) |
| `mill_granary_scavengers` | encounter | [9,6] | (9,5)(9,7)(8,6)(10,6) |
| `mill_wheel_pit` | prop | [1,6] | (1,5)(1,7)(2,6) |
| `mill_high_shelf` | prop | [10,2] | (10,1)(10,3)(9,2) |
| `mill_tally_sticks` | prop | [2,1] | (2,2)(1,1)(3,1) |

**Arrival cells, both directions, hand-verified:**
- Village → mill: `riverfarm_mill_door` (19,5) `to_cell` **[6,7]** — inside the mill, not blocked, no entity, one step north of `mill_exit`.
- Mill → village: `mill_exit` (6,8) `to_cell` **[19,6]** — the open cell a player who approached from the south stood on (the `longhouse_exit` `_comment`'s stated arrival rule, `riverfarm_longhouse.json:267`). **A player who entered from the west approach (18,5) exits one cell away from where they entered** — see the asymmetry note above; it is accepted, logged, and must not be "fixed" by blocking (18,5).

**Entity JSON (author in the file's 1-space-per-level style):**

```json
{
 "id": "mill_exit",
 "kind": "door",
 "cell": [ 6, 8 ],
 "display_name": "Outside",
 "sprite": "door",
 "to_map": "riverfarm_village",
 "to_cell": [ 19, 6 ]
}
```

```json
{
 "id": "mill_tallyman",
 "kind": "npc",
 "cell": [ 4, 3 ],
 "facing": [ 0, 1 ],
 "display_name": "The Tallyman",
 "sprite": "human_laborer",
 "observe": "A thin man with a hazel stick in each hand, laying them side by side against the light.",
 "talk_pool": [
  "Barley in, barley out. Anyone who says a mill is complicated has never run one.",
  "The wheel's pinned till the river's done rising. Everything else keeps working.",
  "Four counts I've done. The stick doesn't argue and neither do I."
 ],
 "conversation": "riverfarm_tallyman"
}
```

```json
{
 "id": "mill_flood_stack",
 "kind": "prop",
 "cell": [ 8, 3 ],
 "display_name": "The Flood Stacks",
 "sprite": "crate",
 "observe": "Grain sacks stacked at ankle height on a shed floor, with the river three weeks out.",
 "locked_toast": "Sacks stacked low and a season coming for them. Lifting them above the flood line is work, and work is a Skill you either have or you don't.",
 "skill_uses": {
  "basic_cleaning": {
   "accomplishment": "flood_prep_done",
   "toast": "[Basic Cleaning] — You clear the shed floor and stack every sack up off the boards. The count comes right the moment anyone can see all of it at once."
  },
  "basic_cooking": {
   "accomplishment": "flood_prep_done",
   "toast": "[Basic Cooking] — You feed the flood crew out of the mill's own pot, and they work the shed twice over for it. The count comes right in the doing."
  }
 }
}
```

`skill_uses` (the pantry-door consolidation, `inn.json:1473`) is used instead of a single `requires_skill`/`on_skill_use` so two class families reach the HELP route. **Validator `test_content.gd:731` requires every arm to carry BOTH `accomplishment` and `toast`** — both do. `basic_cleaning` is a starting skill (`scene_root.json:11`), so the HELP route is always reachable.

**`skill_hint_toast` is DELIBERATELY ABSENT here, and the pointer is folded into `locked_toast` (fix round 1).** `src/core/interactions.gd:150-157` only emits `skill_hint_toast` from the arm gated on **`requires_skill`**, which this entity does not carry (it gates on `skill_uses` instead). A plain interact therefore falls through to `_use_skill("", "mill_flood_stack")` and `src/core/wi_game.gd:418-425` emits `SKILL_UNKNOWN` + **`locked_toast`** — so a `skill_hint_toast` key here would be copy that can never render, paying census for a line no player sees. The shipped `inn.json` `pantry_door` has the same shape and is not evidence to the contrary (it returns earlier still, via `on_interact_accomplishment`). **Do not "fix" this by adding `requires_skill`** — that would stack a second gate on top of `skill_uses` and reroute which arm `field_skills.gd:62` takes. `hut_ward_scrap` (Task 4) DOES carry `requires_skill`, so its `skill_hint_toast` is live and stays.

```json
{
 "_comment": "encounter_when gates on the quest start so the corner is empty until the shortfall is a question. Interact-only (no trigger_radius) -- the mill is a working interior and an ambush on the way to the tallyman would cross every TALK/HELP canonical. on_victory is an Array so the route counter is the only thing banked.",
 "id": "mill_granary_scavengers",
 "kind": "encounter",
 "cell": [ 9, 6 ],
 "display_name": "The Granary Corner",
 "sprite": "bat",
 "beast": true,
 "observe": "Chaff scattered wide, sacks opened low down, and something breathing behind the last row.",
 "arena": "inn_cellar",
 "enemies": [ "granary_scavenger_a", "granary_scavenger_b" ],
 "allies": [],
 "on_victory": [ "granary_cleared" ],
 "encounter_when": { "requires": { "heard_flood_ledger": 1 } }
}
```

`arena`, `enemies`, `allies` and `on_victory` are **all four mandatory** (`test_combat_data.gd:116-117`) — `"allies": []` is required even though there is no ally. No `respawns`, so victory removes the entity permanently; no `scales` (a quest-feeding `on_victory` may never scale).

The three observables (each `on_interact_accomplishment` + a non-empty `toast`, per `_validate_props` `test_content.gd:1626`; none combines `sleep` with a bank):

```json
{
 "id": "mill_wheel_pit",
 "kind": "prop",
 "cell": [ 1, 6 ],
 "display_name": "The Wheel Pit",
 "sprite": "shaft_ladder",
 "observe": "A ladder down into a pit of black water, with the wheel standing still in it and the sluice pinned shut against the season.",
 "on_interact_accomplishment": "observed_mill_wheel_pit",
 "toast": "The pinned sluice carries three seasons of high-water scratches, and each one sits higher than the last."
}
```

```json
{
 "id": "mill_high_shelf",
 "kind": "prop",
 "cell": [ 10, 2 ],
 "display_name": "The High Shelf",
 "sprite": "library_shelf",
 "observe": "A shelf set higher on the wall than any shelf needs to be, with notches and years cut into the post beside it.",
 "on_interact_accomplishment": "observed_mill_high_shelf",
 "toast": "Somebody has cut a notch for every flood since before the village had a headman, and built the shelf a hand above the worst of them."
}
```

```json
{
 "id": "mill_tally_sticks",
 "kind": "prop",
 "cell": [ 2, 1 ],
 "display_name": "The Tally Sticks",
 "sprite": "chest",
 "observe": "A bundle of split hazel sticks hung on a nail, each notched down one edge.",
 "on_interact_accomplishment": "observed_mill_tally_sticks",
 "toast": "Split tallies. One half stays with the mill, one half goes home with the household, and neither can be altered alone."
}
```

**Sprite discipline — every id below was verified present in `data/sprites.json` at plan time:** `door`, `human_laborer`, `bat`, `crate`, `shaft_ladder`, `library_shelf`, `chest` (mill side) and `hearth`, `window_blue`, `shelf_bottles`, `hollow_glow_stone`, `mothbear` (hut side). **Both new doors use `door`** — `riverfarm_windmill` and `witch_cottage` are NOT used by this lane after fix round 1 (each is a 4×6 / 5×5-cell building sprite whose shipped instance is already on the map; see the sprite-fix boxes in Steps 3 here and Task 4 Step 3). **`shelf` and `sacks` do NOT exist — never use them.** Re-run the check before writing: `python3 -c "import json;d=json.load(open('wandering_inn_game/data/sprites.json'));d=d.get('sprites',d);print([k for k in ['door','human_laborer','bat','crate','shaft_ladder','library_shelf','chest','hearth','window_blue','shelf_bottles','hollow_glow_stone','mothbear'] if k not in d])"` — expect an empty list. **This lane adds ZERO `data/sprites.json` entries** — the most recent new interior (`seal_vault`, commit 14a8771) touched none, and a new sprite id would owe matching per-animation frame-count rows in `tests/test_sprite_registry.gd`.

**Light budget:** give the mill at most one `light` (a lantern on the tallyman's post is optional and can be skipped entirely). The ≤8-lights-per-map budget is a shipped convention (`witch_cottage_prop`'s `_comment`).

- [x] **Step 3: Append the village-side door entity to `data/maps/riverfarm/riverfarm_village.json`.** Read `longhouse_door` (:1009-1043) first and match its shape — **but NOT its sprite choice**, see the box below:

```json
{
 "_comment": "v0.16 #305: the mill's ground-floor door. [19,5] is inside the windmill's blocked footprint (the longhouse_door precedent). TWO free approaches, [19,6] and [18,5], neither on any walked QA route. mill_exit returns to [19,6] only, so a west-side entry exits one cell over -- deliberate. sprite `door`, never riverfarm_windmill: that art is 4x6 cells and is already drawn at [20,4].",
 "id": "riverfarm_mill_door",
 "kind": "door",
 "cell": [ 19, 5 ],
 "display_name": "The Mill",
 "sprite": "door",
 "tint": [ 0.74, 0.7, 0.62 ],
 "observe": "The mill's ground-floor door, set into the base of the tower on the river side. The sluice hums even with the wheel pinned.",
 "to_map": "riverfarm_mill",
 "to_cell": [ 6, 7 ],
 "on_enter_accomplishment": "observed_riverfarm_mill"
}
```

**SPRITE FIX (fix round 1) — `"sprite": "door"`, and NO decor row.** The first draft gave this entity `"sprite": "riverfarm_windmill"` plus a paired `decor {"sprite":"door","cell":[19,5]}` row. That would render **a second full windmill** on top of the shipped one: `riverfarm_windmill` is `frame_size [64,96]` = **4×6 cells**, anchor [0.5,0.917], and `riverfarm_windmill_prop` at [20,4] is the map's ONLY windmill art — a second tower one cell left and one down is near-total overlap. The `longhouse_door` precedent does **not** transfer: `riverfarm_longhouse` art exists on that map ONLY as the door entity, so it duplicates nothing. Here the door is a door: `door` is `render_scale` 0.5 and is exactly what the paired decor row would have drawn, so **the decor row is dropped** (keeping it would draw a second door on the same cell). `riverfarm_village.json` gets **one entity append and no decor append** from this task.

- [x] **Step 4: `data/moods.json` — add `moods.riverfarm_mill`, inserted immediately after the `witch_hollow` key** (the lane's ruling-C anchor). A new interior with no mood row renders flat identity-white at every phase (`src/world/atmosphere.gd:90-91`) and **no test catches it**. **Grade exemplar: `witch_hollow`'s own authored row** (`day [0.72,0.92,0.78]` / `dusk [0.40,0.58,0.50]` / `night [0.20,0.34,0.30]` / `vignette 0.50`, with a `_comment` explaining its green shade) — it is the region's one commented, deliberately-graded row and the only honest reference. **Do NOT calibrate against `riverfarm_longhouse`:** it has NO mood row at all, so it renders at identity white; the mill and hut rows below are the region's FIRST graded interiors, and "warmer/dimmer than the longhouse" would mean "warmer/dimmer than pure white", which is not a target. Working-interior key, warmer than the hollow's green, cool at night through the sluice:

```json
"riverfarm_mill": {
 "day": [ 0.82, 0.78, 0.68 ],
 "dusk": [ 0.58, 0.52, 0.46 ],
 "night": [ 0.34, 0.32, 0.34 ],
 "vignette": 0.42
}
```

- [x] **Step 5: `tests/test_content.gd` `LANDMARK_TOKENS` (:1344) — insert `"riverfarm_mill": ["mill", "riverfarm"],` immediately after the `"riverfarm_village"` row** (this lane's anchor). **Mandatory:** R1's `resolve` beat has all three producers inside `riverfarm_mill` while the giver stands on `riverfarm_village`, so `_validate_travel_beat_place_naming` (:1459) arms and hard-fails at :1475 without the row. The beat description in Task 1a contains "the mill by the river" — verify the token match once that splice lands.
- [x] **Step 6: `tests/test_fixture_coherence.gd` `MAP_REQUIRES` (:31) — insert `"riverfarm_mill": ["door_awakened", "riverfarm_attuned"],` immediately after the `"witch_hollow"` row** (this lane's anchor; identical values — the mill is only reachable through the village).
- [x] **Step 7: Run** `python3 wandering_inn_game/scripts/data_lint.py` (grid/cell in-grid, gate shapes) and the scene-dynamism advisory `godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd` (target composite ≥50; a <30 print is a loud advisory, not a gate).
- [x] **Step 8: Census** check; hold the commit until Task 5 supplies `heard_flood_ledger`'s producer (the encounter gate counter must be produced or `_validate_encounter_when` reds) and **Task 1a** splices `flood_ledger`. Commit order inside the R1 group: Task 3 work in the tree → Task 5 dialogue in the tree → **Task 1a splice** → one commit (Task 5 Step 6).

---

## Task 4: `witch_hut` interior + the hollow door

**Files:**
- Create: `wandering_inn_game/data/maps/riverfarm/witch_hut.json`
- Modify: `wandering_inn_game/data/maps/riverfarm/witch_hollow.json` (2 entities)
- Modify: `wandering_inn_game/data/moods.json`, `tests/test_content.gd`, `tests/test_fixture_coherence.gd`
- Test: `data_lint.py`, `res://tests/test_content.gd`, `qa/run_qa.sh witch_cottage_reachability`

**Interfaces:**
- Produces: map key `witch_hut`; counters `observed_witch_hut`, `ward_scrap_read`, `thicket_cleared`, `observed_hut_stoppered_jars`, `observed_hut_drying_rack`, `observed_hut_hearth_ash`, `observed_hut_shuttered_window`.
- Consumes: `line_stalker_a/_b` (Task 2); `heard_thicket_keeps` (Task 6) as the den's encounter gate.

**Ruling 3 is absolute:** the hut door is a **SEPARATE NEW entity at [1,7] with approach [1,8]**. `witch_cottage_prop` (cell [3,7]) and `qa/scripts/witch_cottage_reachability.json` stay **byte-untouched**. That script (issue #117) clicks cell [3,7], asserts the mouse route stops at [3,8] because "the cottage has exactly ONE legal cardinal approach cell", pins the exact toast twice and asserts `observed_witch_cottage` at counts 1 then 2. Converting the prop into a door destroys it outright.

**Cell verification (done at plan time, redo before writing):** (1,7) free, no entity, no decor; its only free cardinal neighbour is (1,8) — (0,7) is blocked, (1,6) is blocked, (2,7) is `hollow_offering_pot`. So the new door inherits the same single-approach shape, and (1,8) is reachable from (1,9) and (2,8). **(2,8), (3,8) and (4,8) are each pinned by a different QA script and must stay free — none of them is touched.** (2,2) and its approaches (2,1)/(2,3)/(1,2)/(3,2) are free and no script walks rows 1–4 of the hollow.

**Light budget trap:** `witch_cottage_prop`'s `_comment` states it "stays within the ≤8/map light budget (the only light this map ships)". **The new hut door carries NO `light` key.**

- [x] **Step 1: Read `data/maps/riverfarm/witch_hollow.json` in full**, including `witch_cottage_prop` (:385) and `leyline_stone` (:545) — the latter is the shipped `requires_skill: detect_magic` prop this lane's ward scrap must NOT duplicate.
- [x] **Step 2: Write `data/maps/riverfarm/witch_hut.json`** to this layout spec (10×8 — well under parlor scale, "small, wardwork-dense" per the spec):

**Grid:** `{"width": 10, "height": 8}`. **Biome:** `"inn"` (the longhouse's interior tile language; the mood row below carries the green shade — no `data/biomes.json` edit).

**Walls (implicitly blocking; playable interior x1–8 / y1–6):**
```
row 0: (0,0)-(9,0)      col 0: (0,1)-(0,7)      col 9: (9,1)-(9,7)
row 7: (1,7)-(3,7) and (5,7)-(8,7)      ← the gap at (4,7) is the exit door
```

**`blocked` (furniture only, each mirrored in `decor`):** `[[3,4],[4,4],[6,5]]` — the worktable pair and an upturned basket.

**Entities (6):**

| id | kind | cell | approaches (all verified free) |
|---|---|---|---|
| `witch_hut_exit` | door | [4,7] | (4,6) |
| `hut_ward_scrap` | prop | [7,2] | (7,1)(7,3)(6,2)(8,2) |
| `hut_stoppered_jars` | prop | [4,1] | (4,2)(3,1)(5,1) |
| `hut_drying_rack` | prop | [2,2] | (2,1)(2,3)(1,2)(3,2) |
| `hut_hearth_ash` | prop | [1,5] | (1,4)(1,6)(2,5) |
| `hut_shuttered_window` | prop | [8,5] | (8,4)(8,6)(7,5) |

**Arrival cells, both directions, hand-verified:**
- Hollow → hut: `witch_hut_door` (1,7) `to_cell` **[4,6]** — inside the hut, unblocked (the `blocked` set is (3,4),(4,4),(6,5)), no entity, one step north of `witch_hut_exit`.
- Hut → hollow: `witch_hut_exit` (4,7) `to_cell` **[1,8]** — the same open cell the player stood on outside to approach the door.

**The SKILL route's prop (ruling 4 — the single most load-bearing entity in this lane):**

```json
{
 "_comment": "R2 SKILL route. detect_magic is the requires_skill GATE and the arm banks ward_scrap_read ONLY -- it must never bank detected_wardwork. trapped_halls.json:355 states the Act V door deliberately withholds a fifth producer because it would cheapen the >=3 threshold its payoff variant reads (qa/fixtures/seal_reward_start.json:31 pins the value at 3). Reading this scrap teaches the same literacy without spending that budget.",
 "id": "hut_ward_scrap",
 "kind": "prop",
 "cell": [ 7, 2 ],
 "display_name": "The Boundary Scrap",
 "sprite": "hollow_glow_stone",
 "requires_skill": "detect_magic",
 "skill_hint_toast": "The scrap hums under the dust, and not the way dust hums.",
 "locked_toast": "A palm-sized shard of grey stone on the shelf, cut along one edge with marks you cannot read.",
 "on_skill_use": {
  "accomplishment": "ward_scrap_read",
  "lore": true,
  "toast": "[Detect Magic] — The shard is one link of a boundary that used to ring the whole thicket. It still pulls, faintly, along the exact line the deer refuse to cross. It was drawn to keep something in, and it has been failing at that for a very long time."
 },
 "observe": "A shard of grey stone on the shelf, set down carefully by someone who meant to come back for it."
}
```

**Four observables** (the spec asks ≥3; the hut is the exploration payoff room, so it gets four):

```json
{ "id": "hut_stoppered_jars", "kind": "prop", "cell": [ 4, 1 ], "display_name": "The Stoppered Jars", "sprite": "shelf_bottles", "observe": "A row of stoppered jars along the top shelf, their labels faded to a suggestion.", "on_interact_accomplishment": "observed_hut_stoppered_jars", "toast": "Every stopper is waxed and every jar is still full. Whoever kept this house left it ready and never came back for it." }
```

```json
{ "id": "hut_drying_rack", "kind": "prop", "cell": [ 2, 2 ], "display_name": "The Drying Rack", "sprite": "library_shelf", "observe": "A rack of bundled stems, dried long past any use.", "on_interact_accomplishment": "observed_hut_drying_rack", "toast": "Yarrow, mostly, and a great deal of it. Somebody kept this place stocked for a house they intended to come back to." }
```

```json
{ "id": "hut_hearth_ash", "kind": "prop", "cell": [ 1, 5 ], "display_name": "The Cold Hearth", "sprite": "hearth", "observe": "Cold ash banked neatly against the back of the hearth.", "on_interact_accomplishment": "observed_hut_hearth_ash", "toast": "The ash is banked the way you bank a fire you mean to wake in the morning. It has been cold for years." }
```

```json
{ "id": "hut_shuttered_window", "kind": "prop", "cell": [ 8, 5 ], "display_name": "The Shutter", "sprite": "window_blue", "observe": "One shutter, latched, with daylight coming through the slats in bars.", "on_interact_accomplishment": "observed_hut_shuttered_window", "toast": "Latched from the inside, and the hut was shut when you found it. You decide not to work that through any further today." }
```

```json
{ "id": "witch_hut_exit", "kind": "door", "cell": [ 4, 7 ], "display_name": "Outside", "sprite": "door", "to_map": "witch_hollow", "to_cell": [ 1, 8 ] }
```

**SPRITE FIX (fix round 1), same class as the mill door.** `witch_cottage` is `frame_size [80,80]` = **5×5 cells**, anchor [0.5,0.963], and `witch_cottage_prop` sits at [3,7]. A second `witch_cottage` at [1,7] is two cells away on the same row, so **3 of its 5 sprite columns overlap the shipped cottage** — one building rendered twice, not two buildings. The hut door therefore ships `"sprite": "door"` (`render_scale` 0.5), the same choice as the mill door, and the "second house" reading is carried entirely by `display_name` + `observe` copy. **No decor row is added on the hollow side either.** Shoot this pairing in a windowed frame **before the Task 4 commit**, not only at Task 10.

- [x] **Step 3: Append TWO entities to `data/maps/riverfarm/witch_hollow.json`** (hand edit, 1-space indentation, append at the end of `entities` — safe here because `witch_hollow.json` is EXCLUSIVE to this lane, unlike the shared files above; do not reorder or touch any existing row):

```json
{
 "_comment": "v0.16 #305 ruling 3: a NEW door, leaving witch_cottage_prop [3,7] and witch_cottage_reachability.json byte-untouched (that canonical pins the cottage's single approach [3,8] and its toast twice). [1,7]'s only free cardinal neighbour is [1,8]. sprite `door`, NOT witch_cottage: that art is 5x5 cells and would redraw the cottage two cells away. No `light`: the cottage prop is this map's only one.",
 "id": "witch_hut_door",
 "kind": "door",
 "cell": [ 1, 7 ],
 "display_name": "The Old Hut",
 "sprite": "door",
 "tint": [ 0.62, 0.7, 0.6 ],
 "observe": "A second, smaller house at the hollow's west edge, its roof half fallen in. The lintel is cut with a line of shallow marks, worn nearly smooth, and the door stands open on the dark.",
 "to_map": "witch_hut",
 "to_cell": [ 4, 6 ],
 "on_enter_accomplishment": "observed_witch_hut"
}
```

```json
{
 "id": "thicket_line_den",
 "kind": "encounter",
 "cell": [ 2, 2 ],
 "display_name": "The Den on the Line",
 "sprite": "mothbear",
 "beast": true,
 "observe": "Bracken pressed flat in a hollow under the northern trees, and the smell of something that has been eating well.",
 "arena": "witch_hollow",
 "enemies": [ "line_stalker_a", "line_stalker_b" ],
 "allies": [],
 "on_victory": [ "thicket_cleared" ],
 "encounter_when": { "requires": { "heard_thicket_keeps": 1 } }
}
```

Interact-only (no `trigger_radius`) so nothing ambushes the pinned hollow routes. Rows 1–4 of `witch_hollow` are walked by no canonical.

- [x] **Step 4: `data/moods.json` — add `moods.witch_hut`, immediately after `moods.riverfarm_mill`** (which Task 3 Step 4 inserted after the `witch_hollow` anchor, so both of this lane's rows sit together and no other lane's closing brace is touched). **Grade exemplar: `witch_hollow`'s authored row** — the hut is that map's interior, so it should read as the hollow's green shade brought indoors and darkened, cooler and dimmer than `riverfarm_mill`. Remember the region's shipped interiors (`riverfarm_longhouse`) ship UNGRADED, so there is no second reference to compare against:

```json
"witch_hut": {
 "day": [ 0.6, 0.7, 0.62 ],
 "dusk": [ 0.4, 0.48, 0.44 ],
 "night": [ 0.24, 0.3, 0.28 ],
 "vignette": 0.5
}
```

- [x] **Step 5: `LANDMARK_TOKENS` — insert `"witch_hut": ["hut", "hollow", "riverfarm"],` immediately after this lane's `"riverfarm_mill"` row.** R2's `resolve` beat has a same-map route (`herd_rerouted` on `riverfarm_village`, the giver's own map), so `_beat_needs_place_name` returns false and the check does not arm — the row is added anyway per ruling 6, so the table stays honest and a later re-gating of the TALK route cannot silently red.
- [x] **Step 6: `MAP_REQUIRES` — insert `"witch_hut": ["door_awakened", "riverfarm_attuned"],` immediately after this lane's `"riverfarm_mill"` row.**
- [x] **Step 7: Run** `data_lint.py`; then **run `qa/run_qa.sh witch_cottage_reachability headless --seed=9`** and confirm green — this is the specific proof that ruling 3 held. Then take the **pre-commit windowed shot** of `witch_hollow` around [1,7]/[3,7] and confirm the hut door and the cottage read as two separate objects (this is the sprite-fix proof and cannot wait for Task 10).
- [x] **Step 8: Census** check; hold the commit until Task 6 supplies `heard_thicket_keeps`'s producer and **Task 1b** splices `what_the_thicket_keeps`. Commit order inside the R2 group: Task 4 work in the tree → Task 6 dialogue in the tree → **Task 1b splice** → one commit (Task 6 Step 5).

---

## Task 5: R1 dialogue — the headman's hub + the tallyman

**Files:**
- Modify: `wandering_inn_game/data/dialogue/riverfarm_headman.json`
- Create: `wandering_inn_game/data/dialogue/riverfarm_tallyman.json`
- Test: `res://tests/test_dialogue.gd`, `res://tests/test_content.gd`, `data_lint.py`

**Interfaces:**
- Produces: `heard_flood_ledger` (quest start), `ledger_read_true` (TALK route), `flood_ledger_settled` (terminal, three routes).
- Consumes: quest id `flood_ledger` (**Task 1a**, which is spliced after this task's dialogue is in the working tree).

**THE OPTION-INDEX TRAP — verified, and the reason for every gate below.** `riverfarm_talk`, `riverfarm_skill` and `riverfarm_fight` all open the headman hub and press **`confirm` with no `move down`** — they select the FIRST VISIBLE option (steps 15 / 82 / 60 respectively). No script pins the hub's `options` array, but every one of them depends on which option is visible first. Two defences, both mandatory:

1. **Every new option is APPENDED at the end of the `options` array**, so no existing row's position changes.
2. **Both R1 and R2 start options are gated `requires {"accomplishment": {"price_of_a_favor_reported": 1}}`** — an accomplishment gate HIDES, and every crossing canonical renders the hub in a state where `price_of_a_favor_reported` is still 0 (the report leg's own press is what banks it, and the hub is rendered before the effect applies). The new rows are therefore invisible in every pinned state. This also reads correctly in fiction: the spec calls the headman's post-chain pools the hook, and both v0.16 threads open after his blight chain closes. **Log this as a design fork.**

- [x] **Step 1: Re-read `data/dialogue/riverfarm_headman.json` in full** and re-run the pin check before writing: `grep -rn 'riverfarm_headman' wandering_inn_game/qa/scripts/` and confirm no `"options"` payload pins that conversation (verified at plan time: `riverfarm_talk.json`'s three `options` pins are the portal menu and Eloise's shop, not the headman).
- [x] **Step 2: APPEND four options to the hub's `options` array** (after the existing "Remind me what needs doing about the witch?" row):

```json
{
	"text": "That ledger of yours. Still short?",
	"requires": { "accomplishment": { "price_of_a_favor_reported": 1 } },
	"hide_when": { "accomplishment": { "heard_flood_ledger": 1 } },
	"effects": [
		{ "quest": "flood_ledger" },
		{ "accomplishment": "heard_flood_ledger" }
	],
	"goto": "flood_brief"
},
{
	"text": "The tally's honest. Somebody's crop failed and they were ashamed of it.",
	"requires": { "accomplishment": { "ledger_read_true": 1 } },
	"hide_when": { "accomplishment": { "flood_ledger_settled": 1 } },
	"effects": [ { "accomplishment": "flood_ledger_settled" } ],
	"goto": "flood_reported_read"
},
{
	"text": "The flood work's done. The count came right in the doing.",
	"requires": { "accomplishment": { "flood_prep_done": 1 } },
	"hide_when": { "accomplishment": { "flood_ledger_settled": 1 } },
	"effects": [ { "accomplishment": "flood_ledger_settled" } ],
	"goto": "flood_reported_worked"
},
{
	"text": "Your shortfall had teeth. The granary corner's clear now.",
	"requires": { "accomplishment": { "granary_cleared": 1 } },
	"hide_when": { "accomplishment": { "flood_ledger_settled": 1 } },
	"effects": [ { "accomplishment": "flood_ledger_settled" } ],
	"goto": "flood_reported_cleared"
}
```

Softlock guard holds: the hub keeps "Just passing through." (`end: true`, neither key) and "Not much of a headman anymore, is there?" (neither key).

- [x] **Step 3: APPEND four nodes** to the graph:

```json
"flood_brief": {
	"speaker": "Former Headman",
	"text": "River comes up every spring, and every spring we count what we can carry above the line. This year the count's eleven bushels short and there isn't a thief in this village. That's worse than a thief. Go down to the mill, walk the tally with the tallyman, and bring me an answer I can live with.",
	"options": [
		{ "text": "I'll see to it.", "end": true },
		{ "text": "One more thing.", "goto": "hub" }
	]
},
"flood_reported_read": {
	"speaker": "Former Headman",
	"text": "Ashamed. Three seasons of it, and they'd sooner be counted light-fingered than counted unlucky. Then we don't say the name. Eleven bushels off my own share and the ledger balances, and the village can go on thinking whatever keeps it civil.",
	"options": [
		{ "text": "That's the right answer.", "end": true }
	]
},
"flood_reported_worked": {
	"speaker": "Former Headman",
	"text": "You did a week of my people's week in a day, and the count came right because somebody finally stood in that shed long enough to see all of it at once. I've been recounting a stack I couldn't see over. I'll take the lesson.",
	"options": [
		{ "text": "It counts better in daylight.", "end": true }
	]
},
"flood_reported_cleared": {
	"speaker": "Former Headman",
	"text": "Teeth. Eleven bushels of teeth. I'd rather it was vermin than a neighbour and I'm not proud of that either. Take something off the field board, and don't tell me what you found down there again.",
	"options": [
		{ "text": "Fair enough.", "end": true }
	]
}
```

Register check: short declaratives, dry self-indictment, agricultural nouns — the hub's own "I trust my knees more than most people" voice. One em-dash maximum per line (these use none).

- [x] **Step 4: Create `data/dialogue/riverfarm_tallyman.json`:**

```json
{
	"start": "hub",
	"nodes": {
		"hub": {
			"speaker": "The Tallyman",
			"text": "Mill's yours to walk. Mind the wheel pit; it's deeper than it looks and twice as unfriendly.",
			"text_variants": [
				{ "requires": { "accomplishment": { "ledger_read_true": 1 } }, "text": "Eleven bushels and a name I'm not saying out loud in my own mill. You'll keep it the same way, if you please." }
			],
			"options": [
				{ "text": "Walk the tally with me.", "requires": { "accomplishment": { "heard_flood_ledger": 1 } }, "hide_when": { "accomplishment": { "ledger_read_true": 1 } }, "goto": "tally_walk" },
				{ "text": "Just looking.", "end": true }
			]
		},
		"tally_walk": {
			"speaker": "The Tallyman",
			"text": "Right. Barley in, barley out, household by household. Every column adds but one, and that one's been short three seasons running and getting shorter.",
			"options": [
				{ "text": "Which household?", "goto": "tally_name" },
				{ "text": "Could be the count, not the crop.", "goto": "tally_count" }
			]
		},
		"tally_count": {
			"speaker": "The Tallyman",
			"text": "Four counts, and the last one with the headman's own stick alongside mine. It isn't the count. It's the crop.",
			"options": [
				{ "text": "Then whose crop?", "goto": "tally_name" }
			]
		},
		"tally_name": {
			"speaker": "The Tallyman",
			"text": "Not saying it aloud. But their entries are honest to the grain, and that's how you know. A thief rounds up. They round down and carry the shame home with them.",
			"options": [
				{ "text": "Their crop failed, and they let the village think worse.", "effects": [ { "accomplishment": "ledger_read_true" } ], "goto": "tally_truth" }
			]
		},
		"tally_truth": {
			"speaker": "The Tallyman",
			"text": "Three seasons of it. Tell the headman gently or don't tell him at all. He's a fair man on a good day and this is not one of his good days.",
			"options": [
				{ "text": "Gently, then.", "end": true }
			]
		}
	}
}
```

Traps observed: every node carries an unconditional `text` (a variants-only node is a guaranteed SCRIPT ERROR, `data_lint.py:198-202`); the banking option uses `goto`, not `end: true`, so effects apply before `DIALOGUE_ENDED`; the hub keeps an always-available exit.

- [x] **Step 5: Run `Task 1a` now** (splice `flood_ledger` after the `price_of_a_favor` anchor — every counter its beats read is produced by the work already in the working tree), then `python3 wandering_inn_game/scripts/data_lint.py`, `res://tests/test_dialogue.gd`, `res://tests/test_content.gd` — expect PASS on all three. R2's block is **not** in the tree yet, by design, so no R2 counter can red here.
- [x] **Step 6: Census** check; **commit** `feat(riverfarm): The Flood Ledger, the mill interior, and the tallyman` (this commit carries **Task 1a**, 3 and 5 together — a whole-file `quests.json` state from a single splice run, never a hunk-staged half-diff).

---

## Task 6: R2 dialogue — the hunter's hub

**Files:**
- Modify: `wandering_inn_game/data/dialogue/riverfarm_hunter.json`
- Test: `res://tests/test_dialogue.gd`, `res://tests/test_content.gd`, `data_lint.py`

**Interfaces:**
- Produces: `heard_thicket_keeps`, `herd_rerouted`, `thicket_answered`.
- Consumes: quest id `what_the_thicket_keeps` (**Task 1b**, spliced after this task's dialogue is in the working tree).

**Ruling 7, verified:** no crossing script pins the hunter's hub `options` array. `riverfarm_fight` opens `riverfarm_hunter` at step 27 and presses `confirm` at step 30 — first visible option, currently "[Ask him to come with you.]". **The R2 start option is APPENDED as the THIRD member of the 2-row array** and is `requires`-gated on `price_of_a_favor_reported`, so it is hidden in that fixture's state and the first-visible row is unchanged. Re-verify with `grep -rn 'riverfarm_hunter' wandering_inn_game/qa/scripts/` before writing.

**Ruling 1, applied:** the corusdeer herd stays. Corusdeer are a northern-Izril species and the floodplains-only placement in game data was itself a placement choice, so this is a deliberate species introduction to Riverfarm, not a canon break. The brief weaves the hunter's shipped lines in as local colour: his "Lost two lambs to something with thorns for teeth" and "Know that treeline better than the headman does. He'd rather not." are reused verbatim inside the new nodes, so R2 reads as the same man's ongoing year rather than a new thread bolted on. **Nothing contradicts those lines** — the thorn-toothed thing that took his lambs is left exactly as unresolved as it shipped.

- [x] **Step 1: APPEND four options to the hub `options` array** (after "Just passing through."):

```json
{
	"text": "The deer stopped at the treeline. Why?",
	"requires": { "accomplishment": { "price_of_a_favor_reported": 1 } },
	"hide_when": { "accomplishment": { "heard_thicket_keeps": 1 } },
	"effects": [
		{ "quest": "what_the_thicket_keeps" },
		{ "accomplishment": "heard_thicket_keeps" }
	],
	"goto": "thicket_brief"
},
{
	"text": "The line's a ward. An old one, gone sour.",
	"requires": { "accomplishment": { "ward_scrap_read": 1 } },
	"hide_when": { "accomplishment": { "thicket_answered": 1 } },
	"effects": [ { "accomplishment": "thicket_answered" } ],
	"goto": "thicket_reported_read"
},
{
	"text": "Fences are moved. The herd's got its road.",
	"requires": { "accomplishment": { "herd_rerouted": 1 } },
	"hide_when": { "accomplishment": { "thicket_answered": 1 } },
	"effects": [ { "accomplishment": "thicket_answered" } ],
	"goto": "thicket_reported_rerouted"
},
{
	"text": "Whatever was denning on the line isn't anymore.",
	"requires": { "accomplishment": { "thicket_cleared": 1 } },
	"hide_when": { "accomplishment": { "thicket_answered": 1 } },
	"effects": [ { "accomplishment": "thicket_answered" } ],
	"goto": "thicket_reported_cleared"
}
```

Softlock guard holds: "Just passing through." carries neither key.

- [x] **Step 2: APPEND six nodes:**

```json
"thicket_brief": {
	"speaker": "The Hunter",
	"text": "Corusdeer. Whole herd came down off the north road and stopped dead at the old line in the thicket. Wouldn't cross it, wouldn't spook, just turned and walked back the way they came. Deer don't hold a line unless something taught them to. I lost two lambs to something with thorns for teeth this spring, so you'll forgive me for not walking in there on my own.",
	"options": [
		{ "text": "Show me the sign.", "goto": "thicket_sign" },
		{ "text": "What's in there?", "goto": "thicket_topic" },
		{ "text": "I'll look into it.", "end": true }
	]
},
"thicket_sign": {
	"speaker": "The Hunter",
	"text": "Here. Hoof marks come up, stop, turn, and go back, all along one line you can't see from standing. Not one print past it in a mile of treeline. Whatever's holding them isn't teeth. Teeth leave a mess.",
	"options": [
		{ "text": "Then we move the fences, not the deer.", "effects": [ { "accomplishment": "herd_rerouted" } ], "goto": "thicket_rerouted" },
		{ "text": "I'll walk the line myself.", "end": true }
	]
},
"thicket_rerouted": {
	"speaker": "The Hunter",
	"text": "Warn the fields, shift two fences, and the herd keeps its road for the winter. That's the whole of it. Nobody thanks you for work they can't see afterward. The deer will, in their way.",
	"options": [
		{ "text": "Good enough.", "end": true }
	]
},
"thicket_topic": {
	"speaker": "The Hunter",
	"text": "Know that treeline better than the headman does. He'd rather not. There's a hut the far side of the hollow nobody's opened in years, and whatever's drawn on that line was drawn by whoever kept it. Start there if you're the reading sort.",
	"options": [
		{ "text": "Back up a step.", "goto": "thicket_brief" },
		{ "text": "Noted.", "end": true }
	]
},
"thicket_reported_read": {
	"speaker": "The Hunter",
	"text": "A ward. Somebody scratched a line in the dirt a hundred years back and the deer still read it better than I do. That's the first thing anyone's told me about that thicket that wasn't a guess.",
	"options": [
		{ "text": "It's failing, whatever it was.", "end": true }
	]
},
"thicket_reported_rerouted": {
	"speaker": "The Hunter",
	"text": "Fences before deer. My father would have said the same and then done the opposite. Herd's watering at the north bend now, where I can see them. I'll sleep better for it, which is more than the hollow's given me lately.",
	"options": [
		{ "text": "Sleep well.", "end": true }
	]
},
"thicket_reported_cleared": {
	"speaker": "The Hunter",
	"text": "Denning right on the line, of course it was. Line's still there and the deer still won't cross it, so we've learned exactly one thing and killed the other. I'll take one thing.",
	"options": [
		{ "text": "One thing's a start.", "end": true }
	]
}
```

- [x] **Step 3: Run `Task 1b` now** (splice `what_the_thicket_keeps` after `flood_ledger`), then `data_lint.py`, `res://tests/test_dialogue.gd`, `res://tests/test_content.gd` — expect PASS. Every counter both quests' beats read now has a producer.
- [x] **Step 4: Run** `res://tests/test_reachability.gd` — every `resolution_paths[].accomplishment` must resolve to a real producer.
- [x] **Step 5: Census** check; **commit** `feat(riverfarm): What the Thicket Keeps, the witch hut, and the line on the treeline` (carries **Task 1b**, 4 and 6 — again a whole-file `quests.json` state from one splice run).

---

## Task 7: Post-quest life — three reactive stages

**Files:**
- Modify: `wandering_inn_game/data/maps/riverfarm/riverfarm_village.json` (2 stage appends), `.../witch_hollow.json` (1 stage append)
- Test: `res://tests/test_content.gd`

**Interfaces:**
- Consumes: `flood_ledger_settled`, `thicket_answered`, `ward_scrap_read`.

**Rules that bind every append here:** `talk_pool_stages` is **last-satisfied-wins and permanent**, so each new stage goes **AFTER the last existing stage** in its array. Every stage needs a unique non-empty `id`, a **NON-EMPTY** `requires_accomplishment` (an empty one shadows everything below it forever), ≥1 non-empty String line, and the entity must also keep its base `talk_pool` (`test_content.gd:493-516`). Thresholds must be **ascending across stages sharing a counter** (`:579-593`) — none of the three below shares a counter with an existing stage, so that check stays inert.

**Shadow-out audit (mandatory, per `wi-adding-dialogue-and-quests`):**
- `riverfarm_headman` today runs `headman_delivery_seed` → `riverfarm_headman_thread_hollow` (`heard_price_of_a_favor`) → `riverfarm_headman_thread_neutral` (`blight_lifted`). The new stage keys on `flood_ledger_settled`, which can only bank after `price_of_a_favor_reported`, which can only bank after `blight_lifted`. So it wins strictly later than every existing stage and shadows nothing a player still needs. Correct.
- `riverfarm_hunter` runs `riverfarm_hunter_thread_hollow` → `riverfarm_hunter_thread_neutral` (`blight_lifted`). Same reasoning; `thicket_answered` is strictly later.
- `riverfarm_witch` runs exactly one stage, `riverfarm_witch_paid` (`blight_lifted`). The new stage keys on `ward_scrap_read` — a **different** counter, so the ascending check is inert, and it wins only for players who took R2's SKILL route. Players who took TALK or FIGHT keep her shipped paid-stage lines. Correct, and it is exactly the "the witch's post-chain pool gains one reactive line" the spec asks for.

- [ ] **Step 1: `riverfarm_village.json`, entity `riverfarm_headman` (:1282) — append AFTER `riverfarm_headman_thread_neutral` (ends :1328):**

```json
{
 "id": "riverfarm_headman_flood_ledger",
 "requires_accomplishment": { "flood_ledger_settled": 1 },
 "lines": [
  "Ledger balances. First time in three years it's balanced honest.",
  "River's due in a fortnight and for once I know exactly what's above the line.",
  "I've stopped recounting. Turns out that was most of the problem, {addr}."
 ]
}
```

- [ ] **Step 2: `riverfarm_village.json`, entity `riverfarm_hunter` (:1378) — append AFTER `riverfarm_hunter_thread_neutral` (ends :1414):**

```json
{
 "id": "riverfarm_hunter_thicket_answered",
 "requires_accomplishment": { "thicket_answered": 1 },
 "lines": [
  "Herd's wintering at the north bend. First year I've known where they'd be.",
  "Still don't walk that line after dark. Knowing what it is didn't make it friendly.",
  "Two lambs I lost this spring. Whatever took them, it wasn't the thing on the line."
 ]
}
```

The third line is the deliberate consistency stitch required by ruling 1 — it keeps the shipped lamb/thorn mystery open rather than retconning it into R2.

- [ ] **Step 3: `witch_hollow.json`, entity `riverfarm_witch` (:563) — append a SECOND stage AFTER `riverfarm_witch_paid` (ends :589):**

```json
{
 "id": "riverfarm_witch_ward_scrap",
 "requires_accomplishment": { "ward_scrap_read": 1 },
 "lines": [
  "So you found the old hut. Somebody drew that boundary long before me, and drew it kindly.",
  "A ward that asks is worth ten that shout. Mine ask. Sit, and I'll tell you why."
 ]
}
```

Register: hearth-warm, oblique, no witch-lore politics on screen — matching her shipped "The fields breathe easier. So do I. Tea?" **Do not touch her `visual_states` (:598-620)** — `riverfarm_walkthrough` pins the elder/young swap across a live phase crossing.

- [ ] **Step 4: Run** `res://tests/test_content.gd` (stage shape + ascending checks) and `data_lint.py`. Re-run `qa/run_qa.sh riverfarm_walkthrough headless --seed=9` to prove the witch's two-form read is untouched.
- [ ] **Step 5: Census** check; **commit** `feat(riverfarm): post-quest reactive stages for the headman, the hunter and Eloise`.

---

## Task 8: Shared test-table rows + quest ladder pins

**Files:**
- Modify: `wandering_inn_game/tests/test_quests.gd` (co-bank pins)
- Test: `res://tests/test_quests.gd`

**Interfaces:**
- Consumes: both quest blocks (Tasks 1a and 1b — this task runs after Task 6's commit, when both are in the tree).

`test_quests.gd:136-142` already enforces that every quest with ≥2 real rungs carries a `_resolution_order` — both blocks do. The pins below are the *co-bank* proofs the file keeps for `halls`, `door`, `crate`, `order` and `favor`; a new quest whose counters can co-bank owes its own.

- [ ] **Step 1: Read `tests/test_quests.gd:85-132`** and match the existing pin idiom exactly. **INSERT immediately after the `var order` (`wrong_order`) block and BEFORE the `price_of_a_favor` comment block** — Pallass anchors its own pins after `price_of_a_favor`, so anchoring there too would put two lanes on the same line. **Locals carry this lane's `r_` prefix:** `:90-132` is ONE continuous function body at a single indent level, so `var ledger` here and Pallass's `var ledger` for `ledger_eats_first` would be a **duplicate declaration** — a parse failure that reds the entire suite on the second merge, not a shadow.

```gdscript
	# v0.16 #305: both Riverfarm side quests co-bank freely (clear the granary,
	# then still walk the tally), so the ladder order is load-bearing the same
	# way price_of_a_favor's is. Ladder: read > worked > cleared.
	# Locals are r_-prefixed: this whole function is one scope and four lanes
	# append pins into it this wave.
	var r_ledger: Dictionary = WIQuests.quest_by_id(shipped, "flood_ledger")
	assert(String(WIQuests.resolved_path(r_ledger, {"granary_cleared": 1})["accomplishment"]) == "granary_cleared", "a fight-only flood_ledger run still records the granary")
	assert(String(WIQuests.resolved_path(r_ledger, {"granary_cleared": 1, "ledger_read_true": 1})["accomplishment"]) == "ledger_read_true", "cleared THEN read the tally records the READING -- the stronger claim wins")
	assert(String(WIQuests.resolved_path(r_ledger, {"flood_prep_done": 1, "granary_cleared": 1})["accomplishment"]) == "flood_prep_done", "cleared then worked records the WORK")

	# Ladder: read > rerouted > cleared.
	var r_thicket: Dictionary = WIQuests.quest_by_id(shipped, "what_the_thicket_keeps")
	assert(String(WIQuests.resolved_path(r_thicket, {"herd_rerouted": 1})["accomplishment"]) == "herd_rerouted", "a talk-only thicket run still records the reroute")
	assert(String(WIQuests.resolved_path(r_thicket, {"thicket_cleared": 1, "ward_scrap_read": 1})["accomplishment"]) == "ward_scrap_read", "killed the den THEN read the ward records the READING")
	assert(String(WIQuests.resolved_path(r_thicket, {"thicket_cleared": 1, "herd_rerouted": 1})["accomplishment"]) == "herd_rerouted", "killed then rerouted records the REROUTE")
```

- [ ] **Step 2: Run** `res://tests/test_quests.gd` — expect PASS.
- [ ] **Step 3: Confirm the three other shared-const rows from Tasks 3-4 are in the tree** (`LANDMARK_TOKENS` ×2, `MAP_REQUIRES` ×2) and that `POPULATION_FLOORS` is **untouched** — this lane only adds unconditional interactables (riverfarm_village 24 → 25, witch_hollow 23 → 25), and floors are minimums.
- [ ] **Step 4: Commit** `test(quests): co-bank ladder pins for the two Riverfarm side quests`.

---

## Task 9: QA — six canonicals, six fixtures, manifest, seed table

**Files:**
- Create: `qa/scripts/flood_ledger_talk.json`, `flood_ledger_help.json`, `flood_ledger_fight.json`, `thicket_keeps_talk.json`, `thicket_keeps_skill.json`, `thicket_keeps_fight.json`
- Create: `qa/fixtures/flood_ledger_talk_start.json`, `flood_ledger_help_start.json`, `flood_ledger_fight_start.json`, `thicket_talk_start.json`, `thicket_skill_start.json`, `thicket_fight_start.json`
- Modify: `qa/manifest.json`, `wandering_inn_game/AGENTS.md` (seed table), `tests/test_fixture_coherence.gd` (`COMBAT_BAND_FIXTURES`)
- Regenerate: `qa/manifest.json` `surfaces`, `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`
- Test: `res://tests/test_fixture_coherence.gd`, `qa/run_qa.sh`, `qa/ci_sweep.sh --touching`

**Interfaces:**
- Consumes: everything above.

**Fixture-first policy:** all six are fixture starts. All six must satisfy `test_fixture_coherence`'s monotone chains — `blight_lifted → riverfarm_attuned → door_awakened → {door_understood, recovered_anchor_stone, bought_catalyst, door_mounted, door_study_sleeps == 3}` — and `MAP_REQUIRES` for whatever map they stand on. **Base them on `qa/fixtures/riverfarm_fight_start.json`** (already Riverfarm-positioned, already level 10, already satisfies `riverfarm_village`'s MAP_REQUIRES) and add `blight_lifted` + `price_of_a_favor_reported` + `heard_price_of_a_favor` + the route's own prerequisites. `qa/fixtures/spine_reach_start.json` is the reference for what a `price_of_a_favor_reported`-carrying state looks like.

- [ ] **Step 1: Load `wi-writing-qa-scripts`.** Re-read the traps digest: `assert_event_logged`/`_absent` scan the WHOLE run, not since the last wait; a bare `wait_for_event ui_toast_rendered` never proves WHICH toast; pinning an `options` list compares the whole array exactly; `_comment` keys must NEVER go inside `payload_contains`; `assert_state` on a MISSING path ERRORS (use `assert_event_absent` for never-banked counters); JSON coordinates parse as floats so `[5.0,8.0] != [5,8]`; gray-band fights emit no `won_combat` (pin `victories`); never pin toast ORDER across `combat_started`. Fixtures are `"version": 5` (the skill doc's "version 3" is STALE — copy a shipped fixture, never the doc).
- [ ] **Step 2: Write the six fixtures.** Each: copy `riverfarm_fight_start.json`, set `current_map`/`player_cell`/`player_facing` (a 2-vector, never a string), set `classes`, add accomplishments. **Re-derive `rng_state` for every one** via `godot --headless --path wandering_inn_game --script res://tests/_derive_rng_state.gd -- 9` and paste the printed state — never hand-type; `RNG_STATE_MIN_MAGNITUDE` is 1e6 (`test_fixture_coherence.gd:378`).

The baseline `qa/fixtures/riverfarm_fight_start.json` carries `melee_hit: 18, spell_cast: 13, won_combat: 3` — **exactly warrior 5 / mage 5**. Any fixture that moves to `warrior 10` must move those counters too.

| fixture | start position | added accomplishments beyond the riverfarm_fight_start baseline | classes |
|---|---|---|---|
| `flood_ledger_talk_start` | `riverfarm_village` [11,10] | `blight_lifted`, `price_of_a_favor_reported` | warrior 5 / mage 5 (baseline counters unchanged) |
| `flood_ledger_help_start` | `riverfarm_village` [11,10] | + `heard_flood_ledger` | warrior 5 / mage 5 (baseline counters unchanged) |
| `flood_ledger_fight_start` | `riverfarm_mill` [6,7] | + `heard_flood_ledger`; **`melee_hit` raised 18 → 57** | **warrior 10, mage 0** (band) |
| `thicket_talk_start` | `riverfarm_village` [12,10] | `blight_lifted`, `price_of_a_favor_reported` | warrior 5 / mage 5 (baseline counters unchanged) |
| `thicket_skill_start` | `riverfarm_village` [12,10] | + `heard_thicket_keeps`; `player_skills` must include `detect_magic`; `spell_cast` raised to mage 7's requirement | mage 7 + warrior 3 (total 10, not band-gated) |
| `thicket_fight_start` | `witch_hollow` [2,3] | + `heard_thicket_keeps`; **`melee_hit` raised 18 → 57** | **warrior 10, mage 0** (band) |

**THE WARRIOR-10 TRAP (fix round 1 — this reds AFTER the scripts are already written if missed).** `tests/test_fixture_coherence.gd:337 _check_class_requirements` walks every held class level's `requires` in `classes.json`, and **warrior level 10 requires `melee_hit: 57`**. Every shipped warrior-10 fixture carries it (`thicket_cull_loop_start`, `ratici_fence_start`, `boulevard_night_footpads_start`, …). Both fight fixtures here go to warrior 10, so **both need `melee_hit: 57`**. Separately, `_check_combat_band` (`:308-317`) sums ALL class levels and demands the total equal the `COMBAT_BAND_FIXTURES` value — so with `warrior: 10` the fixture must hold **`mage: 0` / no mage entry**, or the total is 15 and the band assert fails in the other direction. Re-check each level's `requires` in `classes.json` against the fixture's counters before deriving `rng_state`; the analogous `spell_cast` requirement for `thicket_skill_start`'s mage 7 is the same class of trap.

`thicket_skill_start` must hold `detect_magic` legitimately: the skill is granted by `classes.json:82` (mage level 7, requires `spell_cast` 24) — the fixture's `classes` and its `used_skills`/`spell_cast` counter must make that class level reachable, or `test_fixture_coherence`'s impossible-class arm reds. Mirror whichever shipped fixture already fields `detect_magic` (grep `qa/fixtures/` for it) rather than inventing the numbers. It must also have `detect_magic` **on the field hotbar loadout**, because the script drives it with `press_field_skill` (below), which fails the run outright when the skill is not on the bar.

- [ ] **Step 3: `tests/test_fixture_coherence.gd` `COMBAT_BAND_FIXTURES` (:19) — insert `"flood_ledger_fight_start": 10,` and `"thicket_fight_start": 10,` immediately after the `"riverfarm_fight_start"` row** (this lane's anchor). The map is a whitelist (`:309` returns early on a miss), so this is opt-in — take it, because both fights are measured at `t3_warrior10` and an untagged fight fixture can silently drift off band. **The `10` is a TOTAL across all held classes**, which is why both fixtures drop mage to zero.
- [ ] **Step 4: Write the six scripts.** **Two driver facts settle the shapes below (fix round 1, both verified in `qa/test_driver.gd`):** (1) **`assert_event_absent` has NO window** — `:520-522` calls `_has_event(type, payload_contains)` over the WHOLE run; `from_start` exists only on `wait_for_event` (`:512` / `_wait_for_event` at `:810`). A "not yet banked at this point in the run" assertion is therefore **impossible** and any script needing one must be split. (2) **Use `press_field_skill {"skill": "<id>"}`** (`:160-168`), which resolves the bar slot from the skill id and fails loudly when it is not on the bar — **never `press hotbar_N`**, which silently drifts the moment a fixture's kit ordering changes. Every one opens with the fixture-start title idiom (`ui_title_gate_rendered` → confirm → `ui_title_rendered` → move down 1 → confirm → `game_loaded` → `world_ready` → `assert_state current_map` / `player_cell`). Route shapes:

  - **`flood_ledger_talk`** — headman start (teleport [11,10], move up, interact, `dialogue_started riverfarm_headman`, arrow to the new LAST visible option, confirm, `quest_started flood_ledger` + `heard_flood_ledger`) → walk out to the mill door (teleport [19,6], **move up** — the door sits at (19,5), directly north of the approach, and the cell is blocked so the step becomes a face — interact, `map_changed riverfarm_mill`, `assert_state player_cell [6,7]`; this is the canonical that pins the SOUTH approach, the one `mill_exit` returns to) → screenshot the interior → tallyman (teleport [4,4], move up, interact ×2, walk the tally to `ledger_read_true`) → **the three observables** (interact each, assert its counter and pin its toast text verbatim) → **the detect_magic gate-proof leg** is NOT here (this fixture has no `detect_magic`); instead assert `assert_event_absent combat_started` → exit door back (teleport [6,7], move down, interact, `map_changed riverfarm_village`, `assert_state player_cell [19,6]`) → headman report (teleport [11,10], move up, interact, arrow to the read-report option, confirm) → `accomplishment_recorded flood_ledger_settled` → `quest_beat_completed {id: flood_ledger, beat: 2}` → `quest_completed flood_ledger`.
  - **`flood_ledger_help`** — same skeleton, but at the mill use **`press_field_skill {"skill": "basic_cleaning"}`** on `mill_flood_stack`, assert `skill_used` + `flood_prep_done` + the exact `[Basic Cleaning]` toast, then the worked-report option. Also fire `basic_cooking` on the same prop if the fixture holds it, to prove the second arm (or `assert_event_logged skill_unknown` if it does not — pick one and pin it, do not leave it ambiguous). **This script is also the `mill_flood_stack` locked-toast owner:** before the skill press, a plain `press interact` on the stack emits `SKILL_UNKNOWN` + the entity's **`locked_toast`** (there is no `skill_hint_toast` on this entity — it carries no `requires_skill`, so that arm can never fire; see Task 3 Step 2). Pin the `locked_toast` text verbatim.
  - **`flood_ledger_fight`** — starts inside the mill; teleport [9,7], move up, interact, `combat_started`, `combat_autoplay {max_turns: 40}`, then `assert_state accomplishments.granary_cleared equals 1` (**not** a `won_combat` pin — gray-band fights emit none) → exit → report.
  - **`thicket_keeps_talk`** — hunter start (teleport [12,10], move right, interact ×2, arrow to the new start option), `thicket_brief` → `thicket_sign` → the reroute option → `herd_rerouted` → the rerouted-report option → `thicket_answered` → `quest_completed`. **This script ALSO owns two things moved off `thicket_keeps_skill` (fix round 1, decided here — not "at write time"):**
    1. **The hut door round trip** — teleport `witch_hollow` [1,8], move up (the door is at (1,7), directly north), interact, `map_changed witch_hut`, `assert_state player_cell [4,6]`; and back: teleport [4,6], move down, interact, `map_changed witch_hollow`, `assert_state player_cell [1,8]`. This is the canonical that proves both arrival directions for `witch_hut`.
    2. **The `hut_ward_scrap` gate-proof negative** — this fixture holds **no `detect_magic`**, so a plain `press interact` on the scrap takes the unknown-skill arm and renders its **`locked_toast`** (`interactions.gd:150-157` emits `skill_hint_toast` only when the player already KNOWS the `requires_skill`, which is the SKILL fixture's case, not this one). Pin the `locked_toast` text verbatim and assert **whole-run** `assert_event_absent accomplishment_recorded {id: "ward_scrap_read"}` — sound here precisely because this script never casts the skill at all.
  - **`thicket_keeps_skill`** — **POSITIVE-ONLY, by ruling.** hunter start → hollow → enter the hut (teleport [1,8], move up, interact, `map_changed witch_hut`) → **`press_field_skill {"skill": "detect_magic"}`** on `hut_ward_scrap`, assert `skill_used` + `ward_scrap_read` + the exact lore toast → **whole-run `assert_event_absent accomplishment_recorded {id: "detected_wardwork"}`** (ruling 4's proof; mandatory, and correct as a whole-run assertion because this run must never bank it at any point) → the four hut observables → exit → back to the hunter → read-report. **It carries NO locked-state negative**: the run casts the skill, so any "not yet banked" assertion would need a windowed `assert_event_absent`, which the driver does not have. Say so in the script's `_comment` and point at `thicket_keeps_talk` as the negative's owner.
  - **`thicket_keeps_fight`** — starts in the hollow at [2,3]; move up, interact, `combat_started`, `combat_autoplay`, `assert_state accomplishments.thicket_cleared equals 1` → hunter cleared-report.

  **Arrow-count discipline:** every "arrow to the new option" step counts **VISIBLE options only** in that fixture's exact state. Derive the count from a real run's `events.jsonl` (`ui_dialogue_shown` payload), never by reading the JSON and guessing.

- [ ] **Step 5: Register in `qa/manifest.json` FIRST, then the AGENTS.md table.** `ci_sweep.sh` hard-fails at startup if the two disagree. Six entries, `"seed": 9`, `"tiers": ["full"]` (the Riverfarm family ships full-only; no smoke), each with its `fixture` and a real `note`. **Insert them immediately after the `witch_cottage_reachability` entry** (this lane's anchor — not at the end of `scripts[]`, where all four lanes would collide). Leave `surfaces` for the generator.
- [ ] **Step 6: Insert six rows into the `wandering_inn_game/AGENTS.md` seed table immediately after the `thicket_cull_loop` row (:363)** — this lane's anchor, again not at the table's end. Match the shipped `| script | seed | purpose |` format, e.g. `| `flood_ledger_talk` | 9 (fixture `flood_ledger_talk_start`) | R1 TALK terminal path: headman start, the mill round trip, the tallyman's ledger read, three mill observables, report |`.
- [ ] **Step 7: Regenerate, in this commit:** `python3 wandering_inn_game/scripts/derive_qa_surfaces.py` (bare IS the write for that script), then **`python3 scripts/render_qa_notes.py --write`**, then **bare `python3 scripts/render_qa_notes.py`** as the check (`rc=0` + `PASS: QA notes match manifest`), then `python3 scripts/check_doc_drift.py`. Confirm `derive_qa_surfaces.py --check` exits 0. **A bare `render_qa_notes.py` alone regenerates NOTHING** — it is the check, and the #312 leak-check red is exactly what happens when the write step is skipped. **Merge-train:** `QA-SCRIPT-NOTES.md` is rendered from the WHOLE manifest, so it must be re-rendered at every train merge that brings in another lane's manifest rows; this lane's green render does not survive the next merge.
- [ ] **Step 8: Run each script individually:** `wandering_inn_game/qa/run_qa.sh <script> headless --seed=9`. A `missing result.json` with `rc=0` is a **RED**, never a pass. Read `qa_output/<script>/result.json` per script.
- [ ] **Step 9: Run `res://tests/test_fixture_coherence.gd`** — expect PASS on all six new fixtures.
- [ ] **Step 10: Census** check; **commit** `test(qa): six Riverfarm side-quest canonicals with fixtures and seed-table rows`.

---

## Task 10: Full re-gate, machine playtest, PR

**Settle the tree BEFORE launching a sweep** — a sweep launched while edits continue produces a mixed-state verdict; kill and relaunch.

- [ ] **Step 1: Load `wi-verifying-changes`. Run the full local gate order:**
  1. `python3 wandering_inn_game/scripts/data_lint.py` (this is NOT pytest; there is no `scripts/tests/test_data_lint.py` in this layout)
  2. `python3 scripts/comment_census.py --check`
  3. `python3 scripts/sync_agent_guidance.py` (guidance-mirror check)
  4. `python3 scripts/render_qa_notes.py --write`, then bare `python3 scripts/render_qa_notes.py` (the check), then `python3 scripts/check_doc_drift.py`
  5. `qa/run_qa.sh load_gate headless`
  6. every `tests/test_*.gd` under a 240s alarm, each verdicted on rc + `^PASS` + zero-noise grep
  7. `tests/sim_combat_batch.gd` and `tests/sim_class_paths.gd` under 600s alarms
- [ ] **Step 2: Targeted re-gate.** `qa/ci_sweep.sh --touching` for each shared surface, then run the union:
  - `data/maps/riverfarm/riverfarm_village.json` → `longhouse_walkthrough, regional_work_loop, riverfarm_fight, riverfarm_skill, riverfarm_talk, riverfarm_walkthrough, spine_reach, thicket_cull_loop`
  - `data/maps/riverfarm/witch_hollow.json` → adds `witch_cottage_reachability, trader_earn_loop`
  - `data/quests.json` → **20+ canonicals** via `MONOLITH_SYSTEMS` (GH#281): `cisterns_*, crate_*, door_chain_*, horns_dig_*, invrisil_disagreement_*, missing_recruit_loop, pallass_walkthrough, ...`. The `wi-writing-qa-scripts` claim that this maps to zero scripts is **out of date** — budget the time.
  - `data/combatants.json` → every combat-touching canonical at its pinned seed.
- [ ] **Step 3: Full sweep.** `qa/ci_sweep.sh` cannot run foreground in one Bash call — start it writing to a log, then poll with short foreground `sleep 60; tail -1 <log>` calls and read `rc=` from the log's own echo. Note that a full sweep runs `qa/flush_artifacts.sh` first and **WIPES prior windowed PNGs** — do the windowed pass AFTER the sweep, not before.
- [ ] **Step 4: Load `wi-machine-playtest`. Windowed shots (player eyes, not logic):**
  - the mill door on the village map at day and at dusk (does a `door`-sprite entity at the tower's base read as enterable next to `riverfarm_dock`, and is there exactly ONE windmill on screen?) — plus a frame from the **west approach (18,5)** as well as the south one, since both are legal
  - `riverfarm_mill` interior at day, dusk and night (mood row sanity — a flat white room means the mood row did not land)
  - the tallyman's talk_pool line and the ledger-walk dialogue at full width (copy-fit)
  - `witch_hut` interior at day and night, including `hut_ward_scrap`'s lore toast
  - the hut door beside `witch_cottage_prop` in `witch_hollow` — **the shipped cottage must appear exactly once**, with the hut reading as a small door at the hollow's west edge two cells away (this is the sprite-fix confirmation; a first pass of this shot is already taken at Task 4 Step 7)
  - both new fights on the board: `granary_scavenger_a/_b` on `inn_cellar` (do two `bat` rigs at 0.56 separate from each other and from the cellar floor?) and `line_stalker_a/_b` on `witch_hollow` (green-on-green separation). **These windowed reads ARE the legibility verdict for the four new ids** — `test_combat_visuals` never measures them (ruling F), so the VISUAL-LOG row states what was SEEN and must not quote a derived cell figure.
  - the headman's and hunter's hubs in the post-quest state (option count, no orphaned rows)
  Drain every finding to `docs/VISUAL-LOG.md`.
- [ ] **Step 5: Write `docs/CHOICE-LOG.md` entries** for every decision listed in this plan's rulings and forks.
- [ ] **Step 6: Open the PR** using `.github/PULL_REQUEST_TEMPLATE/issue-close.md`: `Closes #305`; `## Choices made` (option taken + rejected alternative + reason, one per CHOICE-LOG entry); `## Validation evidence` (exact command + one-line result per gate — never "everything passed"), **including the two new sim cells' MEASURED win rate and median rounds and the shipped `riverfarm_thicket_patch_t3_solo` rate beside them — that table, not the gate width, is this lane's region-band ordering proof (ruling A)**, and **this lane's absolute projected `_comment` character total (2,647 chars, measured) so the controller can sum the four lanes before the merge train (ruling B)**; `## Player-visible proof` (which windowed script/seed, what was checked by eye); `## New agent context` (the `on_skill_use` single-counter contract at `wi_game.gd:480`; the headman/hunter first-visible-option dependency in the three riverfarm canonicals); `## Deferred / follow-ups` (the leads rows below). **Head commit message contains `[ci-full]`.**

---

## Deferred to close PR

These rows are **correct and ready** but cannot ship in this PR: `test_content.gd:78` `_validate_leads` validates every `requires`/`hide_when` counter against `data/shipped_ids.json` (RELEASE 0.15.0), and `heard_flood_ledger` / `heard_thicket_keeps` do not exist in that freeze. Land them in the wave-close PR that follows the next `generate_shipped_ids.py` regeneration, or in the release-freeze step-0 commit itself.

```json
{ "id": "lead_flood_ledger", "requires": { "price_of_a_favor_reported": 1 }, "hide_when": { "heard_flood_ledger": 1 }, "lead_text": "The headman is still recounting a ledger that will not add up.", "place": "The village square, Riverfarm" },
{ "id": "lead_thicket", "requires": { "price_of_a_favor_reported": 1 }, "hide_when": { "heard_thicket_keeps": 1 }, "lead_text": "The hunter has been watching the treeline instead of the fields.", "place": "The village square, Riverfarm" }
```

Both `place` strings contain "riverfarm", which is a `LANDMARK_TOKENS["riverfarm_village"]` token — the `_validate_leads` place check passes. **Before landing them, re-run `_validate_leads` and confirm both counters are in the regenerated freeze.**

---

## Danger list

Every risk below has its mitigation baked into a step above; the step is named.

**From the Riverfarm recon:**

| # | Risk | Mitigation (step) |
|---|---|---|
| 1 | **Corusdeer are not a shipped Riverfarm species** — zero references in any `data/maps/riverfarm/*` file. | Ruling 1 keeps them as a deliberate introduction; Task 6 Step 1-2 weaves the hunter's shipped lamb/thorn/treeline lines in verbatim; Task 7 Step 2's third pool line keeps the lamb mystery open so nothing is retconned. Logged. |
| 2 | **There is no "scavenger rig family"** — both shipped scavenger encounters roster `goblin_raider ×2` at power_level 2.0, four bands under this stop. | Task 2 creates new distinct ids at `thicket_remnant`'s numbers with their own gated cell. `goblin_raider` is never referenced. |
| 3 | **`combatants.json` has no `render_scale`** — the fields are `combat_scale` (float) and `combat_tint` ([r,g,b]), and `thicket_remnant_a/b` carry neither. | Task 2 Step 2's drafts spell both fields out explicitly. |
| 4 | **Converting `witch_cottage_prop` into the hut door destroys `witch_cottage_reachability`** (issue #117 pins the single approach [3,8], the exact toast twice, and counts 1 then 2). | Ruling 3 + Task 4 Step 3: a SEPARATE new entity at [1,7]; Task 4 Step 7 re-runs that canonical as the explicit proof. |
| 5 | **The cottage cluster is saturated** — (2,7)/(3,7)/(4,7) are entities, (3,6)/(5,6) blocked, and (2,8)/(3,8)/(4,8) are each pinned by a different script. | [1,7]/[1,8] are outside the cluster entirely; verified free at plan time and re-verified in Task 4 Step 1. |
| 6 | **`longhouse_walkthrough` walks a real 16-cell path** across the village (row 4 x7-13, col 7 y4-8, row 8 x8-11). | Ruling 5's (19,5) door corner is outside every walked route; Task 3's placement note lists all eleven pinned cells checked against it, and re-derives that **both** free approaches — (19,6) and (18,5) — are untouched by all eight village-touching scripts. |
| 6b | **[19,5] has TWO approaches, not one** — (18,5) is free of blocked/entity/decor, and the first draft's `_comment` claimed (19,6) was the only one. A false trap comment ships into `data/`. | Task 3's corrected `_comment` names both cells; **no blocking decor is added**; the (18,5)-entry → (19,6)-exit one-cell asymmetry is written into the task, the CHOICE-LOG and the Task 10 windowed list. |
| 6c | **A door entity that reuses a BUILDING sprite renders the building twice.** `riverfarm_windmill` is 4x6 cells over a shipped windmill at [20,4]; `witch_cottage` is 5x5 over `witch_cottage_prop` at [3,7]. The `longhouse_door` precedent does not transfer (that map has no separate longhouse prop). | Both new doors ship `"sprite": "door"` (render_scale 0.5) and the paired decor row the mill door would have needed is DROPPED; Task 4 Step 7 takes a pre-commit windowed shot of the hollow pairing rather than waiting for Task 10. |
| 7 | **Shared files across four lanes** — `quests.json`, `combatants.json`, `moods.json`, `qa/manifest.json`, `LANDMARK_TOKENS`, `RIVERFARM_CELLS`, `MAP_REQUIRES`. | The File Ownership table declares every one APPEND-ONLY; `arenas.json` and `leads.json` are removed from the lane's footprint entirely (Task 2 rationale, leads-strip rule). |
| 8 | **`LANDMARK_TOKENS` will fire** the moment an R1 beat's producers all sit in `riverfarm_mill` while the giver stands on `riverfarm_village`. | Task 3 Step 5 adds the row in the same commit as the beat; the beat description already carries "the mill by the river". |
| 9 | **`detected_wardwork` threshold** — a fifth producer contradicts `trapped_halls.json:355` and cheapens the `>=3` payoff (`seal_reward_start.json:31` pins 3). | Ruling 4: `hut_ward_scrap` banks `ward_scrap_read` only; the `_comment` cites the design note; Task 9 Step 4 makes `assert_event_absent detected_wardwork` a **mandatory** whole-run assertion in `thicket_keeps_skill`. |
| 10 | **Bounty collision** — `riverfarm_thicket_patch` (17,13) + `bounty_standing_thicket_watch` already own "the thicket needs clearing", and `thicket_cull_loop` pins its cell and its 8-gold payout. | Ruling 9: nothing in this lane touches that entity, its counter, or the bounty. R2's fight is a NEW entity at witch_hollow [2,2] with new roster ids named `line_stalker_*`, not `thicket_remnant_*`. |
| 11 | **`hide_when` is AND-semantics** (`dialogue.gd:128`, cited in `riverfarm_witch.json:374`). | Every `hide_when` in Tasks 5-6 is single-key. |
| 12 | **Eloise carries exactly one stage today** — appending a second arms the ascending check. | Task 7 Step 3 gates the new stage on a DIFFERENT counter (`ward_scrap_read`), so the check stays inert; the shadow-out audit is written out in the task header. |
| 13 | **`river_wolf_pack` at (2,14)** is crossed day-negative by `riverfarm_walkthrough` and night-positive by `riverfarm_fight`. | Nothing in this lane lands on (2,12), (2,13) or (2,14). |

**From the cross-cutting recon:**

| # | Risk | Mitigation (step) |
|---|---|---|
| 14 | **Census margin is effectively zero AND it is shared four ways** (15.0% of a ≤15.0% limit, ~383 chars slack for the WHOLE wave — the `450 + 0.1765x` formula is the combined constraint, not a per-lane one). | Ruling B: this lane's budget is **112 + 0.1765 × new non-comment chars**, with a stated absolute projection (2,647 chars, measured) in the PR body; a census check closes every JSON-writing task; long rationale is pushed to QA `_comment`s and CHOICE-LOG; the census is re-run on the MERGED tree at every train merge and residual overshoot is the wave-close PR's. |
| 14b | **Two lanes declaring `var ledger` in `tests/test_quests.gd`'s single function scope is a PARSE failure**, not a shadow — the suite reds on the second merge. | Ruling C: `r_` prefix on every new local (`r_ledger`, `r_thicket`), and this lane anchors its pins after the `wrong_order` block while Pallass anchors after `price_of_a_favor`. |
| 14c | **Four lanes appending at the same last row** of `moods.json` / `quests.json` / `combatants.json` / `qa/manifest.json` / the AGENTS.md seed table = a designed-in four-way conflict on one line. | Ruling C anchors in the File Ownership table: moods after `witch_hollow`, quests after `price_of_a_favor`, combatants after `thicket_remnant_b`, manifest after `witch_cottage_reachability`, AGENTS.md after `thicket_cull_loop`. `splice_json.py` cannot insert mid-array, so the dry-run-then-hand-place procedure in File Ownership is used and logged. |
| 14d | **`docs/design/character-profiles.md` is SHARED, not any lane's exclusive.** | Ruling D. This lane writes nothing there (unnamed archetype); if that changes, fill the controller's pre-landed stub **in place** — EOF appends are banned for every lane. |
| 15 | **Leads counters must already be frozen.** | Leads-strip rule: zero `leads.json` rows; drafts deferred. |
| 16 | **Vacuous-gate lint fires on bare counter dicts** in `door_when`/`contains_when`/`portal_menu_when`/`fence_menu_when`; the allowlist is empty by design. | This lane writes none of those four gates. `encounter_when` uses the sanctioned `{"requires": {...}}` form in both encounter drafts. |
| 17 | **Every `kind:encounter` needs `arena`, `enemies`, `allies`, `on_victory` all present** — `"allies": []` is mandatory (the scene skill calls allies optional; that is STALE). | Both encounter drafts carry all four explicitly, with a note. |
| 18 | **Every non-pc combatant needs a positive `power_level`.** | All four drafts carry `power_level: 7.5`. |
| 19 | **Band windows are strictly disjoint and ordered — for the four LADDER RUNGS.** A new non-rung cell that borrows a rung's narrow window false-reds on noise (100 runs/cell → sigma ≈ 0.04), and the granary fight's arena (`inn_cellar`) was never measured at all. | Ruling A: both new cells gate at the **stop-cell** window **0.55–0.95** (`sim_combat_batch.gd:114`), never the rung window at `:111`. Ordering is evidenced by the measured medians recorded in the PR body (Task 2 Step 4). Task 2 adds NEW ids only and touches no shipped row; Step 6 runs the FULL batch to prove every other gated cell held. |
| 19b | **`test_combat_visuals` does NOT measure new ids** — `FIGURE_ROWS` has four entries and `audited` contains none of this lane's rigs, so the suite passes by exclusion. | Ruling F: never add these ids to `audited`; never put a derived figure number into a shipped `_comment`; the Task 10 windowed shots are the legibility read and the only claim the VISUAL-LOG row may make. |
| 19c | **`warrior 10` requires `melee_hit: 57`** (`classes.json`), and `COMBAT_BAND_FIXTURES` asserts TOTAL class levels == 10 — a warrior-10 fixture that keeps the `riverfarm_fight_start` baseline (`melee_hit: 18`, mage 5) reds `test_fixture_coherence` twice over, after the scripts are written. | Task 9 Step 2's table now carries `melee_hit: 57` and `mage 0` for both fight fixtures, with the trap written out above the table. |
| 20 | **Effect dicts are an `elif` chain** — a two-key dict silently drops one AND fails validation. | Every effects array in Tasks 5-6 is one-verb-per-dict. |
| 21 | **Adding a visible option to a shipped hub shifts index-driven scripts** (#172 cost 4 scripts, #220 cost 3). | Task 5's option-index trap section: append-only + accomplishment gating on `price_of_a_favor_reported` keeps every new row invisible in every pinned state, and both tasks re-run the grep first. |
| 22 | **Moods are not gated** — a missing row renders flat identity-white and no test catches it. **And the region's shipped interior (`riverfarm_longhouse`) has NO mood row**, so it is identity-white itself and cannot be used as a grade reference. | Task 3 Step 4 and Task 4 Step 4 add both rows against **`witch_hollow`'s authored, commented row** as the exemplar, and say plainly that these are the region's first graded interiors; Task 10 Step 4 shoots all three phases of both. |
| 22b | **`skill_hint_toast` on an entity with no `requires_skill` is dead copy** — `interactions.gd:150-157` only emits it from the `requires_skill` arm; a `skill_uses`-gated prop falls through to `SKILL_UNKNOWN` + `locked_toast`. | `mill_flood_stack` drops `skill_hint_toast` and folds the pointer into `locked_toast` (Task 3 Step 2); `hut_ward_scrap` keeps its own because it DOES carry `requires_skill`; `flood_ledger_help` pins the `locked_toast` that actually renders. |
| 22c | **`assert_event_absent` has no window** (`qa/test_driver.gd:520-522` scans the whole run; `from_start` belongs to `wait_for_event`), so "not banked YET" cannot be asserted mid-run. | Ruling: `thicket_keeps_skill` is positive-only with the mandatory whole-run `detected_wardwork` absence; the hut round trip and the `hut_ward_scrap` locked-toast negative move to `thicket_keeps_talk`, whose fixture holds no `detect_magic`. Decided in the plan, not "at write time". |
| 22d | **`press hotbar_N` is index-brittle** — the slot moves whenever a fixture's kit ordering changes. | Every skill press in this lane uses `press_field_skill {"skill": "<id>"}` (`test_driver.gd:160-168`), which resolves by id and fails loudly if the skill is not on the bar; `thicket_skill_start` must therefore field `detect_magic` on the bar. |
| 23 | **Fixture coherence monotone chains + `MAP_REQUIRES`.** | Task 9 Step 2's baseline is a shipped Riverfarm fixture; Tasks 3/4 add both `MAP_REQUIRES` rows; Step 9 runs the validator. |
| 24 | **Seed/RNG blast radius** — any combat-data edit can flip a canonical at its pinned seed. | Task 10 Step 2 re-gates every combat-touching canonical via `--touching data/combatants.json`; every new fixture's `rng_state` is derived, never typed. |
| 25 | **`docs/QA-SCRIPT-NOTES.md` is generated, and a BARE `render_qa_notes.py` does not regenerate it** — it only checks and returns 1 (`render_qa_notes.py:55-66`). The first draft's bare calls were no-ops that reproduce the #312 red they cite. | Ruling E: every invocation is `--write` followed by a bare run as the check (Task 9 Step 7, Task 10 Step 1.4, the GENERATED section, the verification checklist). The file is re-rendered at **every merge-train merge** as well, since `render()` walks the whole manifest. |
| 25b | **Commit sequencing vs. quest splices** — committing R1 and R2 separately while both quest blocks are already spliced would need hunk-level staging of `quests.json`, which the splice discipline forbids. | Task 1 is split into **1a** (spliced just before Task 5's commit) and **1b** (just before Task 6's), so each commit is a whole-file state from one splice run and `_validate_quests` is green at both. |
| 26 | **`test_content.gd` collects failures and suppresses PASS.** | Global Constraints' three-part verdict rule; every test step says "expect PASS" meaning all three signals. |
| 27 | **A full `ci_sweep.sh` strands a subagent** if run foreground, and it wipes windowed PNGs first. | Task 10 Step 3's log-and-poll idiom, and the explicit ordering note (windowed pass AFTER the sweep). |

---

## Verification gate checklist

Nothing in this lane may be called done until every line here is a recorded command with a recorded one-line result.

- [ ] `python3 wandering_inn_game/scripts/data_lint.py` → clean
- [ ] `python3 scripts/comment_census.py --check` → `rc=0`, DATA ratio ≤ 15.0%; **record this lane's absolute new `_comment` char total and compare it against the 2,647-char projection**
- [ ] `python3 scripts/sync_agent_guidance.py` → no diff
- [ ] `python3 scripts/render_qa_notes.py --write` → file rewritten, then bare `python3 scripts/render_qa_notes.py` → `rc=0` + `PASS: QA notes match manifest`, then `python3 scripts/check_doc_drift.py` → clean
- [ ] `python3 wandering_inn_game/scripts/derive_qa_surfaces.py --check` → `rc=0`
- [ ] `qa/run_qa.sh load_gate headless` → PASS
- [ ] Every `tests/test_*.gd`, individually: `rc=0` **AND** a `^PASS` line **AND** zero `SCRIPT ERROR|Parse Error|WARNING` — reported per script, never as "everything passed"
- [ ] `tests/sim_combat_batch.gd` full run → both new cells inside **0.55–0.95** with median rounds 3–12, **their measured rates and medians written down for the PR body**, **and every pre-existing gated cell still in band**
- [ ] `tests/sim_class_paths.gd` → PASS
- [ ] All six new canonicals green at seed 9, each with a real `result.json`
- [ ] `qa/ci_sweep.sh --touching` union re-gate green (riverfarm maps + quests.json monolith set + combatants.json)
- [ ] Full `qa/ci_sweep.sh` green (log-and-poll)
- [ ] Windowed machine-playtest pass complete, findings drained to `docs/VISUAL-LOG.md`

## Exit criteria

1. `flood_ledger` and `what_the_thicket_keeps` are both completable end-to-end on **all three routes each**, each route banking a distinct counter and each producing a distinct journal resolution line, proven by six green canonicals.
2. `riverfarm_mill` and `witch_hut` are walk-in only (no portal rows), each hosts at least one quest beat, each carries ≥3 non-quest observables with pinned toast copy, each has a `data/moods.json` row and a `LANDMARK_TOKENS` row, and both arrival directions are asserted in a canonical — **`flood_ledger_talk` owns the mill round trip, `thicket_keeps_talk` owns the hut round trip** (and the `hut_ward_scrap` locked-toast negative). Neither door ships a building sprite: both are `"sprite": "door"`, and neither adds a `decor` row.
3. Both new fights are gated in `RIVERFARM_CELLS` at the **stop-cell window 0.55–0.95** (`t3_warrior10`, `check_rounds`), their measured win rates and median rounds are recorded in the PR body beside `riverfarm_thicket_patch_t3_solo`'s as the band-ordering evidence, and no other gated cell moved.
4. The Former Headman, the Hunter and Eloise each gained exactly one reactive `talk_pool_stage`, appended last, keyed to a terminal (or, for Eloise, to the SKILL route counter), with the shadow-out audit written down.
5. `witch_cottage_prop` and `qa/scripts/witch_cottage_reachability.json` are byte-identical to `main`; `riverfarm_thicket_patch`, `thicket_remnants_culled` and `bounty_standing_thicket_watch` are untouched; `detected_wardwork` gained no fifth producer.
6. `data/arenas.json`, `data/leads.json`, `data/shipped_ids.json`, `data/sprites.json`, `scripts/generate_shipped_ids.py`, `tests/test_shipped_ids.gd` and everything under `src/` are untouched by this lane.
7. Census green, all generators re-run in-commit, PR opened with `[ci-full]` on the head commit and every CHOICE-LOG entry written.
