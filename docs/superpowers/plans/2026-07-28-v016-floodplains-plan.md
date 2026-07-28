# v0.16 Floodplains Lane — F1 "The Price Kept" + the camp hollow

> Status: **ACTIVE** (v0.16 wave, dispatched 2026-07-28)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Floodplains slice of the v0.16 "Region Depth" wave: one three-pillar side quest (`the_price_kept`, giver Rags on the plains, offered ONLY on the peaceful terminal) and one small interior (`floodplains/rags_camp.json`, the camp hollow) that hosts two of its three route beats and stays open afterwards as an observable-rich room. Includes the game's FIRST goblin-ally fight.

**Authority spec:** `docs/design/2026-07-28-v0.16-region-depth-spec.md` §"Floodplains" (lines 136–158) + §"Shared conventions" (160–182). **Issue:** #308. Where the controller rulings in this plan amend the spec, the rulings win (each is flagged `RULING n` inline and carries a CHOICE-LOG entry).

**Branch:** `issue/308-floodplains-price-kept` (off `main`).
**PR title:** `Floodplains depth: "The Price Kept" + the camp hollow (#308)`

**Architecture:** Data-first Godot 4.7 under `wandering_inn_game/`. Quests/dialogue/maps/combat are JSON; sim logic in `src/core/*.gd` is NOT touched by this lane. Declarative QA scripts in `qa/scripts/` with pinned fixtures.

**Lane isolation:** `data/maps/floodplains/*` is this lane's exclusively. `data/maps/liscor/street.json` and `data/dialogue/krshia_crate.json` are touched by this lane ONLY (verify at merge-train time that no sibling region lane took Krshia).

---

## Global Constraints

### Copy rules (binding)

- **Book-17 bar** on every new line (`docs/design/spoiler-cutoff.md`). Rags is **pre-Vol-5 characterization ONLY** — one-to-four-word utterances, no articles, no fluency, intelligence in *what she chooses to say*, never in vocabulary (`docs/design/character-profiles.md` §Rags, lines 450–481). Krshia: measured, proud, Silverfang pragmatism; `", yes?"` preferred over a second `"Hrr."` in the same block; at most ONE `Hrr.` per block (profile lines 95–106).
- **"the Magical Door"** only — never the Vol-9 Skill name, never "second door". (No Door copy is expected in this lane; the rule still binds.)
- `{addr}` / `{Addr}` for any PC address, and ONLY inside a `text` key, a `talk_pool` entry, a `talk_pool_stages.lines` entry, or a `*toast` key (`ADDRESS_TOKEN_KEYS`, `tests/test_content.gd:627`). **NEVER** in `data/quests.json` — the unresolvable scan (`test_content.gd:630-636`) fails loud on a token there.
- **Register purity**: `data/dialogue/rags_inn.json` is the INN register. Manners, food, exits, the tables. NO war planning, NO tribe numbers, NO medicine trade, NO carved pawn (those live on the plains in `rags_meeting.json`). Its own `_comment` (`rags_inn.json:2`) is the contract.
- **No fetch-list copy**: beat descriptions point at *reach* and *what is needed*, never itemize objects.
- One em-dash per line maximum; most lines take zero. Lint all three dash forms (`—`, `—` escape, ASCII `--`) — `data/maps/**` mixes literal and escaped in the same file, so every grep sweeps both.
- Banned AI tells per `wi-adding-dialogue-and-quests` "Voice lint". Pool/stage lines are AMBIENT BARKS: 2 wrapped lines max (`tests/test_copy_fit.gd` `DIALOGUE_LINE_CAPACITY = 2`).

### Census budget (binding, margin is effectively ZERO — and it is SHARED four ways)

`python3 scripts/comment_census.py --check` from repo root. **MEASURED NOW: DATA = 15.0% (166,676 `_comment` chars / 1,113,728 total) against a `<= 15.0%` hard limit — 383 chars of slack.**

> **CONTROLLER RULING B (binding).** The published formula `C <= 450 + 0.1765 × N` is the constraint on the **WHOLE WAVE's combined addition**, not a per-lane allowance. Four lanes split it.
>
> **Budget rule for THIS lane:** new `_comment` chars **≤ 112 + 0.1765 × new non-comment chars**, measured over `wandering_inn_game/data/**/*.json` only.

**Projected for this lane: ~14,900 chars of new non-comment DATA** (map ~7k, dialogue ~3.5k, quest ~1.6k, combatants ~2.5k, moods ~250, street stage ~900) ⇒ budget **112 + 0.1765 × 14,900 ≈ 2,742 chars**.

> **PROJECTED ABSOLUTE `_comment` TOTAL FOR THIS LANE: 2,405 chars** (the fourteen `_comment` strings drafted in this plan, after the round-2 cut). This number goes in the PR body verbatim so the controller can sum the four lanes before the merge train starts. If authoring drifts above it, cut prose — do not re-derive the budget.

The round-2 cut already happened in this document: the four longest drafts (`rags_ally`, `camp_ground_press`, `plains_scavenger_a`, `the_price_kept`) are now **one-sentence trap notes**, and their rationale lives in `docs/CHOICE-LOG.md` and QA-script `_comment`s (both census-exempt). Three more (`camp_meat_rack`, the `rags_camp` map header, `rags_camp_mouth`) were trimmed the same way. Spend what is left at seams (the two-arm gate, the ally roster, the last-match-wins stage), never per entity.

**Free denominator, not comment:** `_resolution_order` is NOT counted — `comment_census.py:55-62` counts a key only when it starts `_` **and contains `comment`**. The 330-char note in Task 1 is pure denominator and stays.

**Measure at Task 6, not at Task 9.** By Task 6 every DATA edit this lane makes has landed; discovering a 500-char overshoot at Task 9 Step 2 means re-editing shipped JSON after the sweep settled.

**MERGE-TRAIN RULE (binding):** the census is a property of the MERGED tree, not of a branch. Re-run `python3 scripts/comment_census.py --check` **against the merged tree at every train merge**, not only inside this lane's own branch. Any final overshoot after the last merge is owned by the **wave-close PR**, not by this lane — but this lane designs to the 2,742 budget regardless.

### Sanctioned shapes (binding)

- **Gate shapes**: `requires`/`hide_when` single keys `skill` | `class` | `accomplishment` | `board_accepted` | `delivery_accepted` | `gold` | `once_per_waking` | `item` | `race` | `phase`. Only SIX two-key compounds: `{gold, accomplishment}`, `{accomplishment, once_per_waking}`, `{accomplishment, class}`, `{once_per_waking, item}`, `{accomplishment, skill}`, `{gold, item}` (`test_content.gd:1011-1062`). `hide_when` may NOT carry `once_per_waking`.
- **AND-SEMANTICS TRAP**: `requires.accomplishment` and `hide_when.accomplishment` are BOTH dicts evaluated as AND across every key (`src/core/dialogue.gd:105-109` iterates and returns false on the first shortfall; `_meets_hide_when` runs the same `_meets`). A multi-key `hide_when` hides only when EVERY key is met. **Every hide_when in this lane is single-key.**
- **Wrapped `*_when` gates**: `door_when` / `contains_when` / `portal_menu_when` / `fence_menu_when` MUST wrap counters in `"requires"` — a bare counter dict is VACUOUSLY TRUE and `VACUOUS_GATE_ALLOWLIST` is EMPTY BY DESIGN (`scripts/data_lint.py:50-53, :221-239`).
- **Effect dicts carry EXACTLY ONE verb** (`test_content.gd:1113-1119`); the runtime applier is an `elif` chain (`src/core/wi_game.gd:1071-1131`) so a two-key dict silently drops one. Author `[{...},{...}]`.
- `present_when` forms: `{requires}` / `{absent}` / `{phase}` / `{guest}`, combinable. FORBIDDEN on `kind: encounter` — use `encounter_when` (only `phase` / `requires` / `absent`).
- `start_combat` only on an `end: true` option. Effects + `end: true` fire `DIALOGUE_ENDED` BEFORE the effects apply.
- Every `kind: encounter` entity carries `arena`, `enemies`, `allies`, `on_victory` **explicitly** (`tests/test_combat_data.gd:116-117`) — `"allies": []` is mandatory when empty. Every non-pc combatant carries a POSITIVE `power_level` (`:126-138`).
- `scales` is FORBIDDEN on a one-shot story fight (`src/core/wi_game.gd:1748-1752`; `test_content.gd:1585-1610`).

### Counter freeze names (first-write discipline)

These four are the spec's freeze names and are written **verbatim** at first use — never renamed later:

`camp_trade_brokered` (TALK) · `camp_larder_filled` (HELP) · `camp_ground_held` (FIGHT) · `rags_price_kept` (TERMINAL)

Four further **data-derived** counters ride the shipped flavour/work idioms and freeze at the 0.16.0 cut with zero hand-adds: `camp_carry_jobs` (repeatable work, the `riverfarm_field_jobs` idiom), `eyed_the_camp_fire`, `read_the_hide_racks`, `saw_the_chieftains_seat` (observable props, the `eyed_the_forge_station` / `observed_riverfarm_cottage` idiom). Plus `chatted_with_camp_watch_goblin`, derived automatically from the NPC's `talk_pool`.

**NO hand-edit of `data/shipped_ids.json` — ever.** It is generated (`scripts/generate_shipped_ids.py`, `RELEASE = "0.15.0"`) at the tag cut. A brand-new counter absent from it is a non-event (`tests/test_shipped_ids.gd` only fails when a FROZEN id VANISHES). **No `STRUCTURAL_LITERALS` hand-add is owed by this lane** — every counter here is data-derived (dialogue `effects[].accomplishment`, entity `on_interact_accomplishment`, encounter `on_victory`, `talk_pool`).

### Verification and delivery

- Test runner: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/<file>.gd` from repo root. A failed `assert` HANGS a headless run forever — **alarm-wrap every godot call**: `perl -e 'alarm 120; exec @ARGV' -- <command>` (macOS has no `timeout`).
- A unit run is green only on **all three**: nonzero-exit check passes (exit 0), a `^PASS` line is present, and `grep -E 'SCRIPT ERROR|Parse Error|WARNING'` is EMPTY. `test_content.gd` collects failures and `quit(1)`s while suppressing PASS — never verdict from the last line.
- Load skills before the matching work: `wi-adding-dialogue-and-quests`, `wi-adding-a-scene`, `wi-adding-an-encounter`, `wi-writing-qa-scripts`, `wi-verifying-changes`, `wi-machine-playtest`.
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- **`[ci-full]` on the PR head commit** — the two heavy CI jobs (`sweep`, `web-parity`) run on pull requests, but the head commit carries the tag so any follow-up push re-runs them (`.github/workflows/ci.yml:22-31`).
- Shipped JSON is edited with `python3 wandering_inn_game/scripts/splice_json.py --file data/<f>.json --container <key> --record '{...}'` (placement proofs + byte-identity outside the splice). **Serializer round-trips are BANNED** (`json.dump` defaults `ensure_ascii=True` and rewrites every literal em-dash). Indentation differs per file: `quests.json` = TABS; `combatants.json` / `moods.json` / map files = 1-SPACE-per-level; `rags_inn.json` = TABS.
- **`splice_json.py` can only place at the container's TAIL** (`splice_json.py:148-154` inserts at the tail whitespace, array or dict mode alike). RULING C requires anchored inserts on the four-way-shared containers, so `quests.json`, `combatants.json` and `moods.json` are **HAND splices** at their named anchors, held to the same bar: exact indent match, byte-identity outside the inserted block, `git diff --stat` showing only the expected line delta.

---

## FILE OWNERSHIP

### Exclusive to this lane (own outright)

```
wandering_inn_game/data/maps/floodplains/floodplains.json     (camp mouth prop)
wandering_inn_game/data/maps/floodplains/rags_camp.json       (NEW)
wandering_inn_game/data/dialogue/rags_meeting.json
wandering_inn_game/data/dialogue/rags_inn.json
wandering_inn_game/data/dialogue/krshia_crate.json            (verify no sibling lane took Krshia)
wandering_inn_game/data/maps/liscor/street.json               (Krshia stage append ONLY)
wandering_inn_game/qa/scripts/floodplains_price_*.json        (NEW, 4)
wandering_inn_game/qa/fixtures/floodplains_price_*.json       (NEW, 4)
```

### SHARED — anchored inserts, merge-train resolves

> **CONTROLLER RULING C (binding): NEVER append at EOF / array-end on a four-way-shared file.** Four lanes appending after the same final row all rewrite the same closing line and conflict by construction. Each lane inserts **immediately after a NAMED existing row that no sibling lane touches**. This lane's anchors are named in the table below and repeated at the step that performs the edit.

| File | This lane's insert | ANCHOR (insert immediately after) | Conflict shape |
|---|---|---|---|
| `data/quests.json` | ONE quest object `the_price_kept`, **plus** the one-word region fix on `chieftains_price` (Task 1 Step 1) | **`chieftains_price`** (`:202-254`) — the sibling Floodplains quest, owned by no other lane | four lanes insert into one array |
| `data/combatants.json` | FIVE rows | **`rags`** (the Floodplains goblin roster's last row) | four lanes insert rows |
| `data/arenas.json` | **NONE** — reuses `boulder_flats` | — | — |
| `data/moods.json` | ONE row `moods.rags_camp` | **`floodplains`** (key 3 of 21) — NOT `pallass_forge`, the file's last key, which is Pallass's anchor | one row per new interior |
| `data/leads.json` | **NONE this PR** — see "DEFERRED TO CLOSE PR" | — | — |
| `qa/manifest.json` | FOUR script entries | **the `rags_gate_check` entry** (`qa/manifest.json:4342`) | four lanes insert entries |
| `tests/test_content.gd` | `LANDMARK_TOKENS` +1 row (`rags_camp`). `POPULATION_FLOORS` **untouched** | the other side-map rows | one const, four lanes |
| `tests/sim_combat_batch.gd` | TWO cells appended to `ENCOUNTER_CELLS`. **`total_cells` at :321 is NOT edited** — it sums `ENCOUNTER_CELLS.size()` | end of `ENCOUNTER_CELLS` (this lane is the only one adding an `ally` cell) | only a NEW const array would need :321 |
| `tests/test_fixture_coherence.gd` | `MAP_REQUIRES` +1 row (`rags_camp`); `COMBAT_BAND_FIXTURES` +1 row | the existing floodplains rows | one const, four lanes |
| `wandering_inn_game/AGENTS.md` | FOUR seed-table rows | **the `rags_gate_check` row** (`AGENTS.md:327`) | `ci_sweep.sh` hard-fails on drift vs manifest |
| `docs/design/character-profiles.md` | **SHARED (controller RULING D), but READ-ONLY for THIS lane.** Verified against the plan commit: the controller pre-landed **three** stubs — `## Forge Hall Apprentice` and `## Den-Shop Keeper` (Pallass) and `## Hedault` (Invrisil). **There is no Floodplains stub, and this lane writes nothing to this file.** It READS §Rags (450–481) as the binding voice bar for Task 2 Step 6 | n/a — **if a Floodplains stub is ever added, fill it IN PLACE; never append at EOF, and never touch a sibling lane's stub or the shipped `## Forge-Tier Smith` / `## Grand Lift Attendant` sections** | four lanes, one file, one EOF |
| `docs/CHOICE-LOG.md`, `docs/VISUAL-LOG.md` | appends | end of file | repo-root docs |

**New test-file locals carry this lane's prefix `f_`** (RULING C). The Task 8 Step 8 `test_dialogue.gd` arm declares `f_ctx`, `f_hub`, `f_opts` — never a bare `var ctx` / `var hub`, because Riverfarm, Invrisil and Pallass append into the same function bodies and GDScript rejects a redeclaration at parse time (it is not a shadow), reddening the whole suite on the second merge.

### NEVER

- **NEVER regenerate `data/shipped_ids.json`** — tag-time only.
- **`qa/manifest.json` `surfaces` blocks and `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` are GENERATED.** Never hand-edit. **CONTROLLER RULING E (binding): `python3 scripts/render_qa_notes.py` WITHOUT `--write` does NOT regenerate anything** — it renders in memory, diffs, prints `QA NOTES DRIFT` and returns 1 (`scripts/render_qa_notes.py:55-66`). Every invocation in this plan is therefore the PAIR:

```
python3 scripts/render_qa_notes.py --write     # writes
python3 scripts/render_qa_notes.py             # checks: rc=0 + "PASS: QA notes match manifest"
```

  `derive_qa_surfaces.py` is the opposite — a bare run IS the write (`scripts/derive_qa_surfaces.py:412-414`), and `--write` is explicit anyway in this plan. **MERGE-TRAIN NOTE: `QA-SCRIPT-NOTES.md` is rendered WHOLE from the entire manifest, so it must be re-rendered at EVERY train merge that combines two lanes' manifest entries** — not only inside this lane's own commit. A stale surfaces tag or an un-rendered notes file REDS `leak-check` (the #312 CI red).
- **NEVER touch the goblin sprite scales** — `goblin_raider` / `goblin_shaman` / `goblin_chieftain` are known sub-floor legacies awaiting their own windowed reads (RULING 5). New ally rigs reuse the sprites as-is. **RULING F: no figure number is quoted in any shipped `_comment`** — see Task 6 Step 7.
- **NEVER touch `data/maps/inn/inn.json` guest rows** — the roster array must stay byte-identical across all twelve rows. This lane's Rags work lives in `data/dialogue/rags_inn.json` only.

---

## Task 1 — quests.json: `the_price_kept`

**Files:**
- Modify: `wandering_inn_game/data/quests.json` (insert immediately AFTER `chieftains_price` — this lane's anchor per RULING C — plus a one-word fix ON `chieftains_price` itself)
- Test: `res://tests/test_content.gd`, `res://tests/test_quests.gd`

**Interfaces:**
- Produces: quest id `the_price_kept`; beat gates on `camp_trade_brokered` / `camp_larder_filled` / `camp_ground_held` / `rags_price_kept`.
- Consumes: nothing yet. **Tasks 2–6 supply every producer; they land in the SAME COMMIT or the suite reds** (`test_content.gd:1322-1329` unproduced-counter arm; `test_reachability.gd:50` zero-producer arm). See Task 7 Step 1 for the commit-order rule.

- [x] **Step 1: Read `data/quests.json` first, then FIX THE REGION CASING (one word, same PR).** The file is TAB-indented. `chieftains_price` (the sibling Floodplains quest) sits at :202-254 carrying `"region": "floodplains"` — verified the **only lowercase region value among the eight quests that carry one** (`Liscor` ×3, `Riverfarm`, `Invrisil`, `Pallass` ×2, `chieftains_price`). Journal display appends `" (Region)"`, so shipping `"Floodplains"` here and leaving the sibling lowercase renders **two differently-cased labels for the same region** to any player holding both.

  **Do NOT ship the split.** Edit `chieftains_price`'s value `"floodplains"` → `"Floodplains"` — a one-word change to a file this lane already touches, in this PR. Both Floodplains quests then group under one journal label, matching `Riverfarm` / `Invrisil` / `Pallass` / `Liscor`. Nothing mechanical reads the value (it is display-only), so the edit is inert beyond the label. Log it.

- [x] **Step 2: Insert this record IMMEDIATELY AFTER `chieftains_price`** — the anchor from FILE OWNERSHIP, NOT the end of `quests[]`. Three sibling lanes append at the array end; inserting after a Floodplains-owned row means the four edits never touch the same line. Hand splice matching TAB indent, byte-identity outside the insert (`splice_json.py` only appends, so it cannot place this):

```json
{
	"_comment": "v0.16 F1 (#308). TRAP: the offer's hide_when on drove_off_rags is SINGLE-KEY -- hide_when is AND across keys and the betrayal win banks both terminals.",
	"id": "the_price_kept",
	"title": "The Price Kept",
	"region": "Floodplains",
	"beats": [
		{
			"id": "resolve",
			"description": "Winter stores for the camp: broker a quiet run through Krshia's stall on Market Street, fill the hollow's larder beside the hunters, or hold its ground when the scavengers press.",
			"complete_when_any": {
				"camp_trade_brokered": 1,
				"camp_larder_filled": 1,
				"camp_ground_held": 1
			}
		},
		{
			"id": "report",
			"description": "Tell Rags it is done, out on the southern floodplains where she waits.",
			"complete_when": {
				"rags_price_kept": 1
			}
		}
	],
	"_resolution_order": "LAST-MATCH-WINS (WIQuests.resolved_path), so the array is ordered WEAKEST CLAIM FIRST and escalates: brokered (you paid Liscor to move it) -> larder (you carried and hunted for it) -> ground (you stood in the line beside them). A player who did all three keeps the strongest claim, matching missing_crate's guile/watch/force ladder.",
	"resolution_paths": [
		{
			"accomplishment": "camp_trade_brokered",
			"text": "You moved winter stores south on Silverfang carts, and nobody wrote down whose hands they went to.",
			"grant": {
				"persuaded_someone": 4,
				"heard_gossip": 5
			}
		},
		{
			"accomplishment": "camp_larder_filled",
			"text": "You hunted and hauled with the camp's own, and the racks were full before the frost.",
			"grant": {
				"befriended_moments": 4,
				"heard_gossip": 3
			}
		},
		{
			"accomplishment": "camp_ground_held",
			"text": "You stood in the line beside goblins, and the scavengers went elsewhere.",
			"grant": {
				"melee_hit": 8,
				"won_combat": 1
			}
		}
	]
}
```

**`complete_when_any` WITHOUT a sibling `complete_when` is valid and behaves as a pure OR** — verified at `src/core/quests.gd:28-38`: the `any` loop returns true on the first satisfied counter, and the empty-`all` branch falls through to `return any.is_empty()` (false) until one banks. The two shipped users (`cisterns`, `wrong_order`) pair both keys because their AND leg is a real second condition; F1's resolve beat has no such leg.

- [x] **Step 3: Verify the `_resolution_order` note exists and the array has 3 real rungs** — `tests/test_quests.gd:138-142` hard-fails a multi-rung quest without the note.
- [x] **Step 4:** No `test_quests.gd` co-bank pin is owed: F1's three route counters are mutually exclusive by route, and `rags_price_kept` co-banks with nothing. (If a later change makes two route counters co-bank, add the pin alongside the shipped halls/door/crate/order/favor arms at `test_quests.gd:100-132`.)
- [x] **Step 5: Do not run tests yet** — this file alone is red until Task 6. Continue.

---

## Task 2 — `rags_meeting.json`: the offer, the three report rungs, the post-quest hub arm

**Files:**
- Modify: `wandering_inn_game/data/dialogue/rags_meeting.json`
- Test: `res://tests/test_dialogue.gd`, `res://tests/test_content.gd`
- Re-gate: `qa/scripts/rags_meeting_loop.json`, `qa/scripts/rags_gate_check.json`

**Interfaces:**
- Consumes: quest id `the_price_kept` (Task 1); counters `camp_trade_brokered` / `camp_larder_filled` / `camp_ground_held` (Tasks 3, 5, 6).
- Produces: banks `rags_price_kept`; starts `the_price_kept`.

> **RULING 3 (binding):** the F1 offer gate is `requires {"accomplishment": {"rags_meeting_settled": 1}}` + **single-key** `hide_when {"accomplishment": {"drove_off_rags": 1}}` — the AND-semantics trap makes a two-key hide_when hide only when BOTH are held. This mirrors the shipped peaceful-only shape on `rags_inn_guest` (`data/maps/inn/inn.json:1199/:1202` and `src/core/inn_guests.gd:48`, which must never disagree).

> **INDEX-PIN TRAP (load-bearing, verified):** `qa/scripts/rags_meeting_loop.json`'s THIRD interact does a bare `click_dialogue_option option 1` against the settled hub, expecting `"(Leave them to their business.)"` to be the only visible row. Any new row inserted BEFORE it shifts that click onto the F1 offer, the script starts a quest instead of leaving, and `dialogue_ended` never fires. **Every new hub option in this task is APPENDED LAST in the `options` array**, after `"(Leave them to their business.)"`, which leaves every existing visible index byte-identical.

- [x] **Step 1: Read the whole file** (280 lines). Confirm hub `text_variants` currently ends with the `rags_meeting_settled` arm at :17-24 and the options array ends with `"(Leave them to their business.)"` at :118-121.
- [x] **Step 2: Append ONE hub `text_variant` AFTER the `rags_meeting_settled` arm** (last-match-wins, so this is the post-quest reactive arm and it outranks "Good trade. Plains quiet. Go safe."):

```json
{
 "requires": {
  "accomplishment": {
   "rags_price_kept": 1
  }
 },
 "text": "Winter came. Camp ate. Go safe."
}
```

**Shadow check:** `rags_meeting_loop` never banks `rags_price_kept`, so its pinned base/settled arms can never match this variant. Confirm by grepping the fixture: `grep -c rags_price_kept qa/fixtures/rags_gates_met_start.json` → 0.

- [x] **Step 3: Append ONE hub option, LAST in the array:**

```json
{
 "_comment": "v0.16 F1 offer. TRAP: APPENDED LAST because rags_meeting_loop's settled guard clicks visible option 1 blind -- every new row sits below the ungated exit. hide_when is SINGLE-KEY (it is AND across keys).",
 "text": "Winter's coming. What does the camp need?",
 "requires": {
  "accomplishment": {
   "rags_meeting_settled": 1
  }
 },
 "hide_when": {
  "accomplishment": {
   "drove_off_rags": 1
  }
 },
 "effects": [
  {
   "quest": "the_price_kept"
  }
 ],
 "goto": "winter"
}
```

- [x] **Step 4: Add FOUR new nodes** — `winter`, `winter_ways`, `winter_where`, `winter_kept`. (`winter_where` is a live `goto` target from `winter_ways`; an earlier draft of this header said "three" and omitted it.) All three report rungs live one node deep, so the HUB gains exactly ONE row:

```json
"winter": {
 "speaker": "Rags",
 "text": "Winter comes. Camp thin. Ask once.",
 "text_variants": [
  {
   "requires": {
    "accomplishment": {
     "camp_trade_brokered": 1
    }
   },
   "text": "Carts came. Gnoll kept quiet. Good."
  },
  {
   "requires": {
    "accomplishment": {
     "camp_larder_filled": 1
    }
   },
   "text": "Racks heavy. Hunters ate. Good."
  },
  {
   "requires": {
    "accomplishment": {
     "camp_ground_held": 1
    }
   },
   "text": "Ground held. They ran. Good."
  },
  {
   "requires": {
    "accomplishment": {
     "rags_price_kept": 1
    }
   },
   "text": "Paid. Not asked. Different."
  }
 ],
 "options": [
  {
   "text": "How do I help?",
   "goto": "winter_ways"
  },
  {
   "text": "Krshia's carts are moving south for you.",
   "requires": {
    "accomplishment": {
     "camp_trade_brokered": 1
    }
   },
   "hide_when": {
    "accomplishment": {
     "rags_price_kept": 1
    }
   },
   "effects": [
    {
     "accomplishment": "rags_price_kept"
    }
   ],
   "goto": "winter_kept"
  },
  {
   "text": "Your racks are full. I carried what I could.",
   "requires": {
    "accomplishment": {
     "camp_larder_filled": 1
    }
   },
   "hide_when": {
    "accomplishment": {
     "rags_price_kept": 1
    }
   },
   "effects": [
    {
     "accomplishment": "rags_price_kept"
    }
   ],
   "goto": "winter_kept"
  },
  {
   "text": "The scavengers won't press that ground again.",
   "requires": {
    "accomplishment": {
     "camp_ground_held": 1
    }
   },
   "hide_when": {
    "accomplishment": {
     "rags_price_kept": 1
    }
   },
   "effects": [
    {
     "accomplishment": "rags_price_kept"
    }
   ],
   "goto": "winter_kept"
  },
  {
   "text": "(Leave her to it.)",
   "end": true
  }
 ]
},
"winter_ways": {
 "speaker": "Rags",
 "_comment": "TRAP: three SEPARATE report rungs above, one per route counter -- requires.accomplishment is AND across keys, so one row naming all three would demand all three.",
 "text": "Three ways. Gnoll moves goods. Hunters need hands. Scavengers press hollow.",
 "options": [
  {
   "text": "Where's the hollow?",
   "goto": "winter_where"
  },
  {
   "text": "I'll see what I can do.",
   "end": true
  }
 ]
},
"winter_where": {
 "speaker": "Rags",
 "text": "South. Cut in turf. Two stones. Walk in, no steel.",
 "options": [
  {
   "text": "No steel.",
   "end": true
  }
 ]
},
"winter_kept": {
 "speaker": "Rags",
 "text": "Price kept. Goblins remember. Longer than Humans.",
 "options": [
  {
   "text": "Then we're square.",
   "end": true
  }
 ]
}
```

- [x] **Step 5: Softlock guard check** — `winter` carries `hide_when` and accomplishment-`requires` options, and its LAST option `"(Leave her to it.)"` carries neither key. `winter_ways` / `winter_where` / `winter_kept` carry no gated options at all. `_validate_hide_when_nodes_have_always_available_exit` (`test_content.gd:1144-1165`) is satisfied.
- [x] **Step 6: Copy pass against an EXPLICIT bar, not "read it aloud".** The bar is `docs/design/character-profiles.md` §Rags (450–481): *"EARLY Rags barely speaks the common tongue — one to four words, no articles, no fluency … NEVER fluent sentences, never exposition."* Check each new Rags line against all four clauses:
  - **≤4 words per clause.** `winter_kept` was drafted as `"Price kept. Goblins remember that longer than Humans do."` — a seven-word fluent comparative with a subordinate clause, and exposition about goblin memory. It is now `"Price kept. Goblins remember. Longer than Humans."`
  - **No articles.** `winter_ways` `"Scavengers press the hollow."` → `"Scavengers press hollow."`; `winter_where` `"Cut in the turf."` → `"Cut in turf."` Both were the profile's forbidden `the`.
  - Benchmarks to match, all shipped: `rags_meeting.json` `"Watch came. Goblins hurt. Not begging."` / `"This. Carved it. For medicine."` / `"Rags. Chieftain."`; `rags_inn.json` `"Hot. Good. ...Chieftain eats last. Always last."`
  - Narrator prose (`observe`, `toast`, `open_toast`, `display_name`) is NOT under this bar — it is the game's voice, not hers.
  - Zero em-dashes in the new lines; grep all three dash forms (`—`, the escape, ASCII `--`) before committing.
- [x] **Step 7: Run** `res://tests/test_dialogue.gd` (pure unit, should be green immediately) — expect PASS + zero noise. `test_content.gd` stays red until Tasks 3/5/6 land the producers.

---

## Task 3 — Krshia TALK surface (CREATED, not extended) + her reactive stage

**Files:**
- Modify: `wandering_inn_game/data/dialogue/krshia_crate.json` (2 hub options appended LAST + 1 new node)
- Modify: `wandering_inn_game/data/maps/liscor/street.json` (1 `talk_pool_stages` member appended AFTER `krshia_thread_door_neutral`)
- Test: `res://tests/test_dialogue.gd`, `res://tests/test_content.gd`

**Interfaces:**
- Produces: banks `camp_trade_brokered` (both arms) and `persuaded_someone` (skill arm only).
- Consumes: `rags_meeting_settled`.

> **RULING 2 (binding):** the spec's claim that F1's TALK "builds on the shipped `brokered_goblin_trade` thread" is **WRONG**. `brokered_goblin_trade` banks at exactly ONE site — the 6-gold BROKER rung inside `data/dialogue/rags_meeting.json:253` — and Krshia's dialogue, her npc row, and her stall prop never reference it. **This lane CREATES the Krshia surface.** Her new stage APPENDS AFTER `street.json:1690` (ten last-match-wins stages ending in a `door_awakened`-gated one that every post-door player holds — anything placed earlier is permanently outranked and silently dead, the nine-`*_inn_settled`-lines bug class).

- [x] **Step 1: Run the TWO-GREP DISCRIMINATOR before editing** (`wi-adding-dialogue-and-quests:349-352`; #172 cost 4 scripts, #220 cost 3). Do NOT enumerate pinners by hand — `grep -rln "krshia_crate\|krshia" qa/scripts/` returns **23 scripts**, not the six an earlier draft of this step listed (it misses `social_loop`, `inn_guests_gate_proof`, `dialogue_walkthrough`, `economy_loop`, `journal_history` and others). The cheap, complete discriminator crosses the counter against the hub:

```
grep -rl  rags_meeting_settled wandering_inn_game/qa/fixtures/     # A: who holds the gate counter
grep -rln krshia_crate         wandering_inn_game/qa/scripts/      # B: who opens the hub
```

**Verified at plan time: A returns EXACTLY TWO files — `inn_guests_ext_start.json` and `inn_guests_gate_start.json` — and neither of their scripts appears in B.** The intersection is empty, so no pinned option array on this hub can see either new row. **Re-run BOTH greps at implementation time** — a sibling lane may have added a fixture that holds the counter.

> **Why the rows are safe is PLACEMENT, not hiding.** Get the mechanism right or the next author reuses a false rule: `src/core/dialogue.gd:90-91` `_progress_gated` returns true for `accomplishment`, and `:122` **hides only when progress-gated AND UNMET**. In a state that DOES hold `rags_meeting_settled`, both new rows render **VISIBLE-LOCKED, not hidden** — the `{accomplishment, skill}` and `{gold, accomplishment}` compounds lock on the skill/gold leg while still occupying a visible index. So the load-bearing defence is that both rows are **APPENDED LAST**, below every existing index; the empty grep intersection is the belt, not the braces.

- [x] **Step 2: Append TWO options at the END of `krshia_crate.json`'s `hub.options` array** (currently 11 entries, indices 0–10; append as 11 and 12). This is the shipped `wrong_order` fork shape verbatim — a `{accomplishment, skill}` Diplomat arm plus a `{gold, accomplishment}` real-cost alternate:

```json
{
 "_comment": "v0.16 F1 TALK (#308). TRAP: both rows APPEND LAST -- once rags_meeting_settled is held they render VISIBLE-LOCKED, not hidden, so placement is what protects every index-pinned array on this hub.",
 "text": "The camp south needs winter stores. Move a quiet run for them. [Charming Smile]",
 "requires": {
  "accomplishment": {
   "rags_meeting_settled": 1
  },
  "skill": "charming_smile"
 },
 "hide_when": {
  "accomplishment": {
   "camp_trade_brokered": 1
  }
 },
 "effects": [
  {
   "accomplishment": "persuaded_someone"
  },
  {
   "accomplishment": "camp_trade_brokered"
  }
 ],
 "goto": "goblin_run"
},
{
 "text": "Stand the cost of a quiet run south myself. (8 gold)",
 "requires": {
  "accomplishment": {
   "rags_meeting_settled": 1
  },
  "gold": 8
 },
 "hide_when": {
  "accomplishment": {
   "camp_trade_brokered": 1
  }
 },
 "effects": [
  {
   "gold": -8
  },
  {
   "accomplishment": "camp_trade_brokered"
  }
 ],
 "goto": "goblin_run"
}
```

Both compounds are sanctioned ({accomplishment, skill} and {gold, accomplishment}) and are exactly two keys. `charming_smile` is the [Diplomat] L1 grant already used by this hub's `wrong_order` smooth-over row (`data/skills.json:361`), so the `persuaded_someone` producer stays Diplomat-only.

- [x] **Step 3: Add the `goblin_run` node** to `krshia_crate.json`:

```json
"goblin_run": {
 "speaker": "Krshia",
 "text": "Hrr. South. Grain, salt, hide-thread, and a cart that does not stop where anyone is counting. You will not say whose hands take it, and I will not ask, yes? I will price it as wool.",
 "options": [
  {
   "text": "That's all I'm asking.",
   "end": true
  }
 ]
}
```

One `Hrr.` in the block, one `", yes?"`, zero em-dashes. Register check: proud, pragmatic, does not moralise about goblins — she prices the risk and keeps the ledger clean.

- [x] **Step 4: Append ONE `talk_pool_stages` member to the `krshia` entity in `street.json`, AFTER `krshia_thread_door_neutral` (ends :1690)**:

```json
{
 "_comment": "v0.16 F1 (#308). TRAP: MUST sit below krshia_thread_door_neutral -- that stage gates on door_awakened, which every eligible player holds, so anything above it is permanently outranked and silently dead.",
 "id": "krshia_thread_goblin_run",
 "requires_accomplishment": {
  "camp_trade_brokered": 1
 },
 "lines": [
  "The carts went south and came back empty, yes? Do not tell me what they carried. I priced it as wool.",
  "Good — you. Come stand by the stall; you make the other customers braver. They think if you have not been bitten yet, they will not be.",
  "I sold honey-bread this morning and thought, that one would like this. So. There is a piece behind the counter. Do not tell the Watch I do favorites.",
  "You listen the way Gnolls listen. Whole ears. It is rarer in this city than good wool, and wool does not walk up to my stall twice a week.",
  "A corusdeer came down lame past the east rise. The Watch does not spend healers on beasts. Someone with patient hands could do that animal some good. Hrr."
 ]
}
```

- [x] **Step 5: Ladder-order check** — `test_content.gd:579-593` reds a later stage whose threshold on a SHARED counter is lower than an earlier stage's. `camp_trade_brokered` appears in no other stage, so no ordering constraint applies. Confirm the stage `id` is unique across the entity and `requires_accomplishment` is non-empty (`test_content.gd:493-516`).
- [x] **Step 6: Copy-fit** — every stage line must wrap in ≤2 lines (`tests/test_copy_fit.gd`). Line 1 is new; lines 2–5 are shipped verbatim and already pass. Run `res://tests/test_copy_fit.gd`.
- [x] **Step 7: Run** `res://tests/test_dialogue.gd` + `res://tests/test_copy_fit.gd` — expect PASS.

---

## Task 4 — The camp hollow: `floodplains/rags_camp.json` + the mouth + mood + landmark

**Files:**
- Create: `wandering_inn_game/data/maps/floodplains/rags_camp.json`
- Modify: `wandering_inn_game/data/maps/floodplains/floodplains.json` (one new prop)
- Modify: `wandering_inn_game/data/moods.json` (one row)
- Modify: `wandering_inn_game/tests/test_content.gd` (`LANDMARK_TOKENS` +1)
- Modify: `wandering_inn_game/tests/test_fixture_coherence.gd` (`MAP_REQUIRES` +1)
- Read only: `docs/design/character-profiles.md` §Rags — **SHARED file (RULING D); this lane has no stub in it and writes nothing to it**
- Test: `python3 wandering_inn_game/scripts/data_lint.py`, `res://tests/test_content.gd`, `res://tests/test_combat_data.gd`

**Interfaces:**
- Produces: map key `rags_camp`; counters `eyed_the_camp_fire`, `read_the_hide_racks`, `saw_the_chieftains_seat`, `camp_carry_jobs`, `chatted_with_camp_watch_goblin` (id-derived).
- Consumes: `rags_meeting_settled`, `drove_off_rags`.
- Tasks 5 and 6 add the `camp_meat_rack` prop and the `camp_ground_press` encounter to this same file.

> **RULING 6 (binding):** interior stem `rags_camp`; at most parlor scale; fire pit / hide racks / chieftain's spot observables (≥3 non-quest); mood row; LANDMARK_TOKENS row; MAP_REQUIRES row.

- [x] **Step 1: Load `wi-adding-a-scene`. Prove the stem is unique:**

```
grep -rn '"rags_camp"' wandering_inn_game/data/ wandering_inn_game/src/ wandering_inn_game/tests/
python3 -c "import json;print([a['id'] for a in json.load(open('wandering_inn_game/data/arenas.json'))['arenas']])" | grep -o rags_camp
ls wandering_inn_game/data/maps/*/
```

Expect zero hits (verified at plan time: no `rags_camp` map key, no `rags_camp` arena id). `WISceneCatalog.compose()` FATALs on duplicate MAP keys.

- [x] **Step 2: Place the camp mouth on `floodplains.json`.** Cell **(17,22)**. Justification, hand-verified against the map:
  - `floodplains` grid is 40×26 with 36 blocked cells; **the only blocked cell anywhere in x12–24 / y15–25 is (24,19)**.
  - Neighbouring entities: `rags_scouting_party` (16,21), `goblin_night_patrol` (10,21), `wolf_den` (11,22), `rock_crab_nest` (21,16). Nearest decor: `bush_green` (14,20), `tree_round` (22,18), `boulder` (24,19).
  - **(16,20) is FORBIDDEN**: `rags_meeting_loop` boots at (16,19) and `move south 1` onto (16,20) to face the encounter. A blocking entity there strands the shipped canonical mid-walk.
  - (17,22) is diagonally adjacent to Rags's rise, off that pinned lane, and has FOUR guaranteed-open neighbours — (17,21), (16,22), (18,22), (17,23) — satisfying the save-compat rule for a new blocking entity on a previously-walkable cell.
  - The wall segment `(20,25)→(30,25)` is well clear.

Append this entity to `floodplains.json`'s `entities` array:

```json
{
 "_comment": "v0.16 F1 (#308). TRAP: door_when is requires-ONLY, so the peaceful gate's absent arm has to live on present_when -- a betrayal win banks rags_meeting_settled too.",
 "id": "rags_camp_mouth",
 "kind": "prop",
 "cell": [
  17,
  22
 ],
 "display_name": "A Cut in the Turf",
 "sprite": "boulder",
 "tint": [
  0.62,
  0.66,
  0.55
 ],
 "observe": "Two low stones lean together where the ground folds away, and the grass between them is beaten flat by small feet. Smoke comes up thin and does not spread.",
 "present_when": {
  "requires": {
   "rags_meeting_settled": 1
  },
  "absent": {
   "drove_off_rags": 1
  }
 },
 "door_when": {
  "requires": {
   "rags_meeting_settled": 1
  },
  "to_map": "rags_camp",
  "to_cell": [
   5,
   7
  ],
  "open_toast": "You go down between the stones sideways, the way the flattened grass says to, and the plains close over the top of you."
 }
}
```

- [x] **Step 3: Create `data/maps/floodplains/rags_camp.json`.** Grid **12×9** — under the `brothers_parlor` 14×10 parlor ceiling (RULING 6), above the 10×7 longhouse. Biome `floodplains` (existing key — no `data/biomes.json` edit, no new tile language). 1-SPACE indent, matching the region's sibling files.

**Blocked set shape — the hollow's rim, 42 cells** (12 + 7 + 7 + 11 + 5; an earlier draft said 41, off by one): full row `y=0` (x0–11, **12**); full column `x=0` (y1–7, **7**); full column `x=11` (y1–7, **7**); full row `y=8` minus (5,8) which is the exit (x0–4 and x6–11, **11**); plus **5** interior solids paired to solid-reading decor — (1,1), (10,1), (1,7), (10,7) (rim boulders) and (3,6) (a supply crate). **THE BLOCKING CONTRACT: every decor sprite that reads solid is paired into `blocked`; `bush_green` follows the shipped floodplains precedent of walkable brush decor.** (`data_lint.py` checks in-grid-ness, not cardinality — the count is decoration that can only be wrong, so verify it or drop it.)

**Reachability, hand-walked (BFS from (5,7)):** the open interior is x1–10 / y1–7 minus the five solids minus the entity cells — **all 59 open cells are one connected region**, and every **non-door** entity has 3–4 open orthogonal neighbours. **The two-neighbour claim is scoped to non-door entities on purpose:** `rags_camp_exit` at (5,8) has exactly ONE open neighbour, (5,7), because it is set into the rim. That is the normal shape for a rim door (one approach lane) and is not a defect — but the invariant as originally stated ("every entity has at least two") was false for it.

```json
{
 "_comment": "v0.16 F1 (#308) the camp hollow. TRAP: rim boulders and the supply crate are decor AND blocked; bush_green stays walkable per the floodplains precedent. Walk-in only, no portals.json row.",
 "biome": "floodplains",
 "grid": {
  "width": 12,
  "height": 9
 },
 "blocked": [
  [0,0],[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[8,0],[9,0],[10,0],[11,0],
  [0,1],[0,2],[0,3],[0,4],[0,5],[0,6],[0,7],
  [11,1],[11,2],[11,3],[11,4],[11,5],[11,6],[11,7],
  [0,8],[1,8],[2,8],[3,8],[4,8],[6,8],[7,8],[8,8],[9,8],[10,8],[11,8],
  [1,1],[10,1],[1,7],[10,7],[3,6]
 ],
 "floor_layers": [
  {
   "sheet": "res://assets/tiles/floor_tiles_12/grass_01.png",
   "tile_px": 540,
   "variants": [
    [0,0]
   ],
   "cells": "all"
  }
 ],
 "decor": [
  { "sprite": "boulder", "cell": [1,1] },
  { "sprite": "boulder", "cell": [10,1] },
  { "sprite": "boulder", "cell": [1,7] },
  { "sprite": "boulder", "cell": [10,7] },
  { "sprite": "crate", "cell": [3,6] },
  { "sprite": "bush_green", "cell": [2,4] },
  { "sprite": "bush_green", "cell": [9,4] },
  { "sprite": "bush_green", "cell": [7,7] },
  { "sprite": "tree_round", "cell": [3,1] }
 ],
 "ambience": [
  {
   "preset": "dust_motes",
   "rect": "all",
   "phase": [
    "dusk",
    "night"
   ]
  }
 ],
 "entities": [
  {
   "_comment": "to_cell (17,21) is the SAME cell the player approached rags_camp_mouth from -- the longhouse_exit offset convention. Verified unblocked and unoccupied.",
   "id": "rags_camp_exit",
   "kind": "door",
   "cell": [
    5,
    8
   ],
   "display_name": "Back Up to the Plains",
   "sprite": "door",
   "to_map": "floodplains",
   "to_cell": [
    17,
    21
   ]
  },
  {
   "id": "camp_fire_pit",
   "kind": "prop",
   "cell": [
    4,
    4
   ],
   "display_name": "The Fire Pit",
   "sprite": "campfire",
   "observe": "A ring of river stones with a fire kept deliberately small. Someone has banked it low and swept the ash back, so the smoke goes up thin instead of out wide. Nothing about this fire wants to be seen from the road.",
   "on_interact_accomplishment": "eyed_the_camp_fire",
   "toast": "The wood is sorted by burn time in three piles. Somebody in this camp thinks two nights ahead."
  },
  {
   "id": "camp_hide_racks",
   "kind": "prop",
   "cell": [
    2,
    2
   ],
   "display_name": "The Hide Racks",
   "sprite": "request_board",
   "observe": "Green hides pegged out on a lattice of spear-shafts, scraped down to nothing on one side. The pegs are all different lengths, whittled to fit whatever the rack needed that day.",
   "on_interact_accomplishment": "read_the_hide_racks",
   "toast": "Every hide is stretched to the same tension. Whoever runs this rack does not let anyone else near it."
  },
  {
   "id": "camp_chieftains_seat",
   "kind": "prop",
   "cell": [
    9,
    2
   ],
   "display_name": "The Chieftain's Spot",
   "sprite": "boulder",
   "tint": [
    0.7,
    0.72,
    0.6
   ],
   "observe": "A flat stone at the high end of the hollow, worn smooth in one small patch. It faces the way in. There is no cushion, no cover, and nothing near enough to hide behind.",
   "on_interact_accomplishment": "saw_the_chieftains_seat",
   "toast": "From here you can see the cut in the turf, the fire, and everyone's hands at once. It was not chosen for comfort."
  },
  {
   "_comment": "Regional repeatable work, the riverfarm_field_board idiom (once_per_waking + gold + variants) at the Riverfarm 2-gold day-rate.",
   "id": "camp_carry_yoke",
   "kind": "prop",
   "cell": [
    8,
    5
   ],
   "display_name": "A Carrying Yoke",
   "sprite": "crate",
   "observe": "A shoulder yoke cut for someone half your height, propped against a stack of empty baskets. The baskets go out full and come back full of something else.",
   "on_interact_accomplishment": "camp_carry_jobs",
   "once_per_waking": true,
   "once_per_waking_toast": "The baskets are all out. Nothing left to haul until they come back.",
   "gold": 2,
   "toast": "You shorten the yoke by two notches and spend the morning hauling water and cut brush. Somebody presses coin into your hand at the end without looking up.",
   "variants": [
    {
     "when": {
      "camp_carry_jobs": 3
     },
     "toast": "The yoke has been left out on your side of the fire. Nobody says anything about it, and nobody moves it back."
    }
   ]
  },
  {
   "id": "camp_watch_goblin",
   "kind": "npc",
   "cell": [
    2,
    6
   ],
   "display_name": "A Goblin on Watch",
   "sprite": "goblin_base",
   "facing": "right",
   "observe": "A goblin sitting where the light from the cut in the turf lands, sharpening something that is already sharp. It has not looked directly at you once.",
   "talk_pool": [
    "Chieftain said walk in. So. You walked in.",
    "Fire small. Smoke thin. Road sees nothing. Good fire.",
    "You eat first, we eat after. Chieftain eats last. That is order.",
    "Winter counts us. We count back."
   ]
  }
 ]
}
```

**Observable audit (RULING 6, ≥3 NON-QUEST):** `camp_fire_pit`, `camp_hide_racks`, `camp_chieftains_seat` are pure observables with real toast copy and zero quest coupling — three, as required. `camp_watch_goblin` (talk_pool) and `camp_carry_yoke` (repeatable work) are two further non-quest surfaces. Post-quest the room keeps all five plus the meat rack.

- [x] **Step 4: Arrival cells, hand-verified BOTH directions** (no runtime code validates `to_map`/`to_cell` — a bad door strands the player silently):
  - **In:** `floodplains` `rags_camp_mouth` (17,22) → `rags_camp` (5,7). (5,7) is inside the grid, absent from `blocked`, and holds no entity ✓ (nearest entity is the exit door at (5,8)).
  - **Out:** `rags_camp` `rags_camp_exit` (5,8) → `floodplains` (17,21). (17,21) is inside the 40×26 grid, absent from `blocked` (only (24,19) is blocked in that whole quadrant), and holds no entity ✓ (nearest: `rags_scouting_party` at (16,21), `rags_camp_mouth` at (17,22)).
  - **Prove it in play**, not on paper: the Task 8 QA scripts walk both crossings.
- [x] **Step 5: Mood row — INSERT AFTER THE `floodplains` KEY, not at EOF.** `data/moods.json` has 21 keys and `pallass_forge` is the LAST; all four lanes appending there would each have to comma the same closing brace, i.e. a designed-in four-way conflict on one line. Per RULING C this lane's anchor is **`floodplains`** (key 3) — Riverfarm takes `witch_hollow`, Invrisil `brothers_parlor`, Pallass `pallass_forge`. `moods.json` is 1-SPACE-per-level indented.

  Content: a dug hollow reads warmer and more enclosed than the open plains (`floodplains` day is identity white, vignette 0.4; `witch_hollow` is the enclosure precedent at vignette 0.50):

```json
"rags_camp": {
 "_comment": "Sheltered hollow: rim-shaded warm-dim at noon, firelight only after dusk. Vignette 0.52 sits just above witch_hollow's 0.50.",
 "day": [
  0.86,
  0.82,
  0.72
 ],
 "dusk": [
  0.58,
  0.46,
  0.36
 ],
 "night": [
  0.34,
  0.26,
  0.22
 ],
 "vignette": 0.52
}
```

**No test enforces this row** — `src/world/atmosphere.gd:90-91` falls back to identity white, so a missing row is a VISUAL defect that ships green. It is mandatory here.

- [x] **Step 6: `LANDMARK_TOKENS` row** in `tests/test_content.gd` (append inside the const, near the other side-map rows):

```gdscript
	# 2026-07-28 (#308, F1): the camp hollow. `the_price_kept`'s resolve beat is
	# produced on street + rags_camp while the giver sits on floodplains, so the
	# beat arms _validate_travel_beat_place_naming and a missing row here is a
	# HARD fail (test_content.gd:1475), not a soft one. Region token per the
	# 2026-07-26 widening.
	"rags_camp": ["hollow", "camp", "floodplains"],
```

The `resolve` beat description contains both "Market Street" (a `street` token) and "the hollow's larder" (a `rags_camp` token) — `_description_names_place` needs only ONE match across the union, but carrying both keeps it honest if a route's producer map moves.

- [x] **Step 7: `MAP_REQUIRES` row** in `tests/test_fixture_coherence.gd` (append inside the const):

```gdscript
	# 2026-07-28 (#308): the camp hollow sits behind rags_camp_mouth's own
	# door_when, whose only key is rags_meeting_settled -- a fixture standing
	# in there without it is a position no player can occupy.
	"rags_camp": ["rags_meeting_settled"],
```

- [x] **Step 8: Run the structural lint** — `python3 wandering_inn_game/scripts/data_lint.py` from repo root. It checks grid presence/positivity, every `blocked` and entity cell in-grid, and the `*_when` wrapped-requires arm. Expect zero findings. **NOTE: this is NOT pytest and there is no `scripts/tests/test_data_lint.py` in this repo layout.**
- [x] **Step 9: Scene dynamism (advisory, not a gate)** — `perl -e 'alarm 120; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd`. Target composite ≥50 for the new scene; <30 prints a loud advisory and means the room is a brown box — fix before spending a windowed shot (low c1 = pull decor from more than one asset-pack family).
- [x] **Step 10: Do NOT write to `docs/design/character-profiles.md` (RULING D).** The file is SHARED across all four lanes and is exclusive to none — but verified against the plan commit, the controller pre-landed only three stubs (`## Forge Hall Apprentice`, `## Den-Shop Keeper` for Pallass; `## Hedault` for Invrisil) and **none for Floodplains**. `camp_watch_goblin` is an anonymous four-line `talk_pool` bark surface, not a named recurring character, so it does not earn a profile block. **This lane's only interaction with the file is READING §Rags (450–481)** as the Task 2 Step 6 voice bar. If a Floodplains stub is added later, fill it IN PLACE — never append at EOF, and never touch a sibling lane's stub.
- [x] **Step 11: Commit deferred** — Tasks 5 and 6 add two more entities to this same file; the whole map lands in one commit at Task 7.

---

## Task 5 — HELP route: carry jobs + the assisted hunt, without touching the shipped hunt surfaces

**Files:**
- Modify: `wandering_inn_game/data/maps/floodplains/rags_camp.json` (one prop)
- Test: `res://tests/test_content.gd`, `python3 wandering_inn_game/scripts/data_lint.py`

**Interfaces:**
- Produces: banks `camp_larder_filled`.
- Consumes: `camp_carry_jobs` (Task 4's yoke) and `corusdeer_culled` (**shipped and frozen** — `data/shipped_ids.json:446`, produced by `corusdeer_range`'s `on_victory` on `floodplains.json:1517`).

> **RULING 8 (binding):** the HELP route reuses the shipped corusdeer/hunt surfaces where natural **without breaking their pins**. The design here achieves that by **reading** `corusdeer_culled`, not by editing `corusdeer_range` or `wounded_corusdeer` at all — zero risk to `floodplains_bestiary_loop`, `parley_gates_check`, `parley_talkdowns_loop`, `beast_tamer_loop`, `bestiary_peek`, or `bounty_corusdeer_cull`.

- [x] **Step 1: Verify the crossing canonicals BEFORE relying on the counter** (trust-but-verify; do not touch the surfaces):

```
grep -rn "corusdeer" wandering_inn_game/qa/scripts/ | head
grep -rn "corusdeer_culled" wandering_inn_game/data/bounties.json wandering_inn_game/data/shipped_ids.json
python3 -c "import json;d=json.load(open('wandering_inn_game/data/maps/floodplains/floodplains.json'));print([e for e in d['entities'] if e['id']=='corusdeer_range'][0])"
```

Confirm `corusdeer_range` still banks `corusdeer_culled` on victory and that this lane changes nothing about it.

- [x] **Step 2: Add the meat rack** to `rags_camp.json`'s entities:

```json
{
 "_comment": "v0.16 F1 HELP (#308). present_when.requires is AND across keys, which is the intent: haul here, cull a corusdeer on the plains, come back. Reads the frozen corusdeer_culled -- never edits corusdeer_range.",
 "id": "camp_meat_rack",
 "kind": "prop",
 "cell": [
  9,
  6
 ],
 "display_name": "The Drying Rack",
 "sprite": "barrel",
 "present_when": {
  "requires": {
   "camp_carry_jobs": 1,
   "corusdeer_culled": 1
  }
 },
 "observe": "A rack of split poles standing empty over a bed of ash, waiting on the season the camp cannot count on.",
 "on_interact_accomplishment": "camp_larder_filled",
 "toast": "You hang what you brought back and cut it down thin the way the old one shows you, and by the time the light goes the rack is heavy for the first time this year."
}
```

- [x] **Step 3: Validator check** — `_validate_props` (`test_content.gd:1626-1643`): `on_interact_accomplishment` requires a non-empty `toast` ✓; the prop does NOT combine `sleep` with `on_interact_accomplishment` ✓. `_validate_present_when` (`:749-801`): shape is `{requires}` only, both counters have real producers (the yoke; `corusdeer_range`) ✓.
- [x] **Step 4: Reachability check** — (9,6) is inside the grid, absent from `blocked`, and its neighbours (8,6), (9,5), (9,7), (10,6) are all open. Because the entity is `present_when`-gated it is intermittently walkable; that is safe (no player can be standing on it when it appears — the two gating counters can only bank while the player is elsewhere or at another cell).
- [x] **Step 5: Do not commit yet** — Task 6 adds the encounter to the same file.

---

## Task 6 — FIGHT route: the first goblin-ally fight

**Files:**
- Modify: `wandering_inn_game/data/combatants.json` (FIVE new rows, inserted after the `rags` row — RULING C anchor, hand splice)
- Modify: `wandering_inn_game/data/maps/floodplains/rags_camp.json` (one encounter entity)
- Modify: `wandering_inn_game/tests/sim_combat_batch.gd` (TWO cells appended to `ENCOUNTER_CELLS`)
- Modify: `docs/VISUAL-LOG.md` (one row)
- Test: `res://tests/test_combat_data.gd`, `res://tests/test_combat_visuals.gd`, `res://tests/sim_combat_batch.gd`

**Interfaces:**
- Produces: banks `camp_ground_held` (+ `won_combat`).
- Consumes: `rags_meeting_settled` (ally gate + encounter gate).

> **RULING 1 (binding):** allies are **EXACTLY TWO** new `side: "player"` records — `rags_ally` (the rags rig cloned stats-appropriately) and `goblin_spear_ally`. **Two, not three:** every arena has exactly 4 `player_spawns`, and `start_combat` appends a tamed companion only when `allies.size() + 2 <= player_spawns.size()` (`src/core/wi_game.gd:1713-1718`) — a third authored ally would silently drop a [Beast Tamer] player's wolf, with the fixed "A crowded field" toast, in the game's marquee ally fight. `ally_requires` is `{rags_meeting_settled: 1}` ONLY. **Relc must NOT appear in `allies`** — every other floodplains encounter uses `allies: ["relc"]` + `ally_requires: {met_relc: 1}` (`floodplains.json:1190/1225/1262/1445/1469`) and the rags fixtures already hold `met_relc`, so a copy-paste puts the Watch's Senior Guardsman in the goblin line. `ally_requires` is also ALL-OR-NOTHING (`wi_game.gd:1697-1701`), so mixing Relc with goblins under one gate is impossible anyway.

> **RULING 5 (binding):** goblin sprite scales are NOT touched in this lane. `goblin_raider` / `goblin_shaman` / `goblin_chieftain` are documented legacies awaiting their OWN windowed reads (`HANDOFF.md:63-67`; the doc comment at `tests/test_combat_visuals.gd:548-560`, which is prose, not an assertion, and names COMBATANT ids rather than sprites). New ally rigs reuse the sprites as-is with no `combat_scale` key. **Per RULING F, no figure number is quoted in shipped data or in the VISUAL-LOG row** — the new ids are outside `FIGURE_ROWS` and outside `audited`, so nothing measures them (Task 6 Step 7).

- [x] **Step 1: Load `wi-adding-an-encounter`.** Read `data/combatants.json` head and tail — it is 1-SPACE-per-level indented, unlike `quests.json`. Read the shipped ally rows (`relc` :21, `klbkch` :62, `riverfarm_hunter` :84, `wilovan` :761, `wolf_companion`) for the ally-tuning idiom.
- [x] **Step 2: Insert FIVE combatant rows IMMEDIATELY AFTER the `rags` row** — this lane's RULING C anchor, not the end of `combatants[]` (three sibling lanes append there). Hand splice: `splice_json.py` can only place at the tail. `combatants.json` is 1-SPACE-per-level indented, unlike `quests.json`. Every row carries a POSITIVE `power_level` — the single most-forgotten field (`test_combat_data.gd:126-138`); HP derives from `con` and no `hp` field exists anywhere.

**The rationale for each of these five rows lives in `docs/CHOICE-LOG.md`, not in the shipped JSON** (census, RULING B). What survives in the file is the one trap a future editor can actually trip on.

```json
{
 "_comment": "v0.16 F1 (#308). TRAP: a combatant id holds exactly ONE side, so the enemy `rags` row cannot be reused -- this is a distinct id, and the distinct id IS the override.",
 "id": "rags_ally",
 "power_level": 5.5,
 "display_name": "Rags",
 "sprite": "rags",
 "side": "player",
 "stats": {
  "str": 8,
  "dex": 16,
  "con": 14,
  "int": 14,
  "wis": 12,
  "cha": 10
 },
 "weapon_die": 5,
 "ai": "skirmisher",
 "skills": [
  "quick_slash"
 ]
},
{
 "id": "goblin_spear_ally",
 "power_level": 3.0,
 "display_name": "A Goblin with a Spear",
 "sprite": "goblin_base",
 "combat_tint": [
  0.82,
  0.95,
  0.78
 ],
 "side": "player",
 "stats": {
  "str": 11,
  "dex": 10,
  "con": 14,
  "int": 6,
  "wis": 7,
  "cha": 5
 },
 "weapon_die": 5,
 "ai": "melee",
 "skills": []
},
{
 "_comment": "v0.16 F1 (#308). TRAP: NOT the footpad rigs -- their LOW-lethality contract belongs to the Invrisil alley band, so this is a distinct id at the Floodplains T1 band.",
 "id": "plains_scavenger_a",
 "power_level": 3.0,
 "display_name": "Plains Scavenger",
 "sprite": "human_laborer",
 "combat_tint": [
  0.86,
  0.78,
  0.62
 ],
 "side": "enemy",
 "stats": {
  "str": 10,
  "dex": 9,
  "con": 12,
  "int": 6,
  "wis": 6,
  "cha": 6
 },
 "weapon_die": 4,
 "ai": "melee",
 "skills": []
},
{
 "id": "plains_scavenger_b",
 "power_level": 3.0,
 "display_name": "Plains Scavenger",
 "sprite": "human_laborer",
 "combat_tint": [
  0.8,
  0.74,
  0.6
 ],
 "side": "enemy",
 "stats": {
  "str": 9,
  "dex": 11,
  "con": 12,
  "int": 6,
  "wis": 6,
  "cha": 6
 },
 "weapon_die": 4,
 "ai": "melee",
 "skills": []
},
{
 "id": "plains_scavenger_lead",
 "power_level": 4.5,
 "display_name": "The Band's Lead",
 "sprite": "human_laborer",
 "combat_tint": [
  0.9,
  0.7,
  0.55
 ],
 "side": "enemy",
 "stats": {
  "str": 13,
  "dex": 10,
  "con": 18,
  "int": 7,
  "wis": 7,
  "cha": 8
 },
 "weapon_die": 5,
 "ai": "melee",
 "skills": [
  "power_strike"
 ]
}
```

**These stats are a DRAFT tuned to the Floodplains band (`goblin_raider` 2.0 → `rags` 5.5). The harness is the numbers authority, not this document — Step 5 measures and Step 6 re-tunes.**

- [x] **Step 3: Add the encounter entity** to `rags_camp.json`:

```json
{
 "_comment": "v0.16 F1 FIGHT (#308). TRAP: allies is EXACTLY TWO by arena capacity -- 4 player_spawns and start_combat appends a tamed companion only at allies.size()+2 <= spawns, so a third ally benches a Beast Tamer's wolf.",
 "id": "camp_ground_press",
 "kind": "encounter",
 "cell": [
  7,
  3
 ],
 "display_name": "Scavengers at the Rim",
 "sprite": "human_laborer",
 "tint": [
  0.86,
  0.78,
  0.62
 ],
 "observe": "Three of them stand on the lip of the hollow where it is easiest to come down, looking at the racks and doing arithmetic. Nobody in the camp is pretending not to have noticed.",
 "arena": "boulder_flats",
 "enemies": [
  "plains_scavenger_a",
  "plains_scavenger_b",
  "plains_scavenger_lead"
 ],
 "allies": [
  "rags_ally",
  "goblin_spear_ally"
 ],
 "ally_requires": {
  "rags_meeting_settled": 1
 },
 "on_victory": [
  "won_combat",
  "camp_ground_held"
 ],
 "encounter_when": {
  "requires": {
   "rags_meeting_settled": 1
  }
 }
}
```

`arena: boulder_flats` is the shipped floodplains-biome 12×8 arena (`rock_crab_nest`'s own) — **no `data/arenas.json` edit is owed by this lane.** `respawns` is absent, so the entity is REMOVED permanently on victory.

- [x] **Step 4: Append TWO gated cells to `ENCOUNTER_CELLS`** in `tests/sim_combat_batch.gd` (the ONLY array with a per-cell `"ally"` key; `ally` resolution at :478, `gated := cell.has("win_lo")` at :522). **`total_cells` at :321 is NOT edited** — it already sums `ENCOUNTER_CELLS.size()`.

> **CONTROLLER RULING A (binding):** every new `sim_combat_batch` gated cell in this wave uses **`win_lo: 0.55` / `win_hi: 0.95`** — the shipped stop-cell precedent (`tests/sim_combat_batch.gd:59`, `rags_scouting_party_t1_solo`). **Do NOT narrow the window to "prove" the region band.** Band ordering is proven by **recording the MEASURED MEDIANS in the PR body**, not by a tight gate: a narrow window turns ordinary RNG drift into a red CI on somebody else's PR, and it asserts a verdict the harness was never asked for.

```gdscript
	# v0.16 F1 (#308): the camp-ground press, the first goblin-ALLY fight.
	# The harness fields ONE ally per cell; the shipped encounter fields TWO,
	# so both cells measure a strictly HARDER field than a player ever sees.
	# Window is the shipped stop-cell precedent (0.55-0.95 + the 3-12 round
	# gate), at warrior2, the build the region's gates open at. The measured
	# medians -- not this window -- are what place these fights in the
	# Floodplains band; they are recorded in the PR body (RULING A).
	{"name": "camp_ground_press_t1_rags_ally", "arena": "boulder_flats", "enemies": ["plains_scavenger_a", "plains_scavenger_b", "plains_scavenger_lead"], "build": "warrior2", "ally": "rags_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "camp_ground_press_t1_spear_ally", "arena": "boulder_flats", "enemies": ["plains_scavenger_a", "plains_scavenger_b", "plains_scavenger_lead"], "build": "warrior2", "ally": "goblin_spear_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
```

- [x] **Step 5: Measure cheaply, then fully.** Get the cell count and slice-run only the new cells:

```
WI_CELL_COUNT_ONLY=1 perl -e 'alarm 120; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
WI_CELL_RANGE=<lo>:<hi> perl -e 'alarm 600; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
```

(`WI_CELL_RANGE` is 0-based inclusive; the two new cells are the last two of `ENCOUNTER_CELLS`.)

- [x] **Step 6: Re-tune to land IN band.** Order of levers, cheapest first: (a) enemy COUNT/composition selection, (b) `plains_scavenger_lead`'s `con`, (c) `weapon_die`, (d) `power_level` last (it is challenge-weighting, not lethality). **Aim for the MIDDLE of the window (~0.70–0.85 on the single-ally cells), not the ceiling** — the shipped fight adds a second ally, so a single-ally reading of 0.94 means real play sits above the window's spirit. **Record the measured win rate and median rounds for BOTH cells in the PR body** (RULING A), alongside the shipped Floodplains cells they are being ordered against. **Do NOT bake the numbers into a shipped `_comment`** — that is census spend on a figure nothing re-verifies, and the PR body is where the band ordering is actually reviewed.
- [x] **Step 7: Figure-height bar — what it actually measures (RULING F).** State this plainly, because the reverse claim was in the round-1 draft and is false:
  - `tests/test_combat_visuals.gd:536-541` `FIGURE_ROWS` holds **exactly four sprites** — `bat`, `briar_collector`, `briar_collector_deep`, `ruin_warden`. `_board_cells` (:563-566) indexes `FIGURE_ROWS[cfg["sprite"]]` directly, so a sprite absent from that dict is a **KeyError, not a pass**.
  - The `BOARD_FIGURE_MIN_CELLS` / `MAX` bounds are asserted **only over the hard-coded `audited` array** (:605-619: the `camouflage` list plus `cave_spider`, `ruin_guardian`, `seal_warden`, `ruin_ward_a/_b`, `snare_ward_a`). **No new id from this lane is in it.**
  - Therefore: `rags`, `goblin_base` and `human_laborer` are **not measured by this test at all**. `test_combat_visuals` **passes by EXCLUSION** for every id this lane adds. Run it and expect PASS — but do not read that PASS as a legibility verdict.
  - **No id may be added to `audited` without FIRST adding its sprite to `FIGURE_ROWS` with a freshly derived row count** (alpha-bbox height over the animation's frames), or the test crashes instead of failing.
  - The 0.96 / 1.00 / 1.07 goblin numbers live in a **doc comment** at :548-560, not in an assertion, and that comment names COMBATANT ids, not sprites. **Quote no figure number in any shipped `_comment`** (RULING F).
  - **The legibility read for these three new rigs is the WINDOWED SHOT** (Task 9 Step 9 shot 4), not this test.
- [x] **Step 8: VISUAL-LOG row** — append to `docs/VISUAL-LOG.md` (the repo-root 2,426-line file that carries the sprite-scale history, NOT the 13-line game-side one):

> **2026-07-28 (#308, v0.16 Floodplains) — three new rigs ship UNMEASURED by the board-figure bar.** `goblin_spear_ally` reuses `goblin_base`, `rags_ally` reuses the bespoke `rags` rig, and `plains_scavenger_a/b/lead` reuse `human_laborer` — all with NO `combat_scale` key, so their board figures are byte-identical to what ships today. **None of these sprites is in `FIGURE_ROWS` and none of these ids is in the `audited` array**, so `test_combat_visuals` does not measure them; it passes by exclusion. No figure number is asserted or claimed here. Filed for the goblin-scale triage pass alongside `goblin_raider` / `goblin_shaman` / `goblin_chieftain`, each of which needs its own windowed read before its scale moves (HANDOFF.md:63-67). The FIRST evidence about these rigs' legibility is this PR's windowed machine-playtest shot of the `camp_ground_press` board — including whether the three `human_laborer` scavengers, which ship near-identical warm tints (0.86/0.78/0.62, 0.80/0.74/0.60, 0.90/0.70/0.55) on one board, separate by eye. Nothing in the suite checks that: the tint-uniqueness assert at `tests/test_combat_visuals.gd:544-556` covers only the hard-coded `camouflage` list.

- [x] **Step 9: Run** `res://tests/test_combat_data.gd` (arena spawn reachability, encounter key presence, ally/enemy id resolution, positive power_level) — expect PASS.

---

## Task 7 — Producers + gates land together; the inn reactive line; commits

**Files:**
- Modify: `wandering_inn_game/data/dialogue/rags_inn.json`
- Test: `res://tests/test_content.gd`, `res://tests/test_reachability.gd`, `res://tests/test_dialogue.gd`, `res://tests/test_inn_guests.gd`

> **RULING 7 (binding):** `camp_trade_brokered` / `camp_larder_filled` / `camp_ground_held` / `rags_price_kept` are produced AND gated in the SAME COMMIT. `test_reachability.gd:50` fails loud on any gate consuming a counter no effect banks; `test_content.gd:1322-1329` does the same for quest beats.

> **RULING 4 (binding):** `rags_inn.json`'s reactive line is a `text_variants` entry keyed on `rags_price_kept` on the `greet` node. **It is that node's FIRST AND ONLY variant, and the base `text` stays unconditional** (a variants-only node is a guaranteed SCRIPT ERROR, `data_lint.py:198-202`). Verified: the whole 18-line file carries no `text_variants` anywhere and its nodes are `greet` / `offduty` / `served`, each with a bare `text` — **there is no "settled arm" in this file to append after.** (An earlier draft of this ruling carried an "appended AFTER the existing settled arm" clause; it is struck. **That placement rule belongs to `rags_meeting.json`**, Task 2 Step 2, where the settled arm really does exist at `data/dialogue/rags_meeting.json:17-24` and last-match-wins makes append-order load-bearing.) Register-pure: manners, food, exits. **Pre-Vol-5 Rags bar is ABSOLUTE.**

- [x] **Step 1: Commit the producer/gate set as ONE commit.** Stage together: Task 1 (quests.json — the new quest AND the `chieftains_price` region-casing fix), Task 2 (rags_meeting.json), Task 3 (krshia_crate.json + street.json), Task 4 (rags_camp.json + floodplains.json + moods.json + the two test consts), Task 5 (meat rack), Task 6 (combatants.json + encounter + harness cells + VISUAL-LOG). Nothing before this point is independently green.

Commit message:

```
feat(floodplains): "The Price Kept" -- three routes, the camp hollow, the first goblin-ally fight (#308)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

- [ ] **Step 2: Read `data/dialogue/rags_inn.json` in full** (18 lines, TAB-indented, one-line node style). Note the `greet` node's shipped text and that the file's `_comment` is the register contract.
- [ ] **Step 3: Add `text_variants` to the `greet` node ONLY**, keyed on the terminal:

```json
"text_variants": [ { "requires": { "accomplishment": { "rags_price_kept": 1 } }, "text": "You again. Camp ate. ...Still count doors. Habit, not you." } ]
```

Register audit: doors, food, habit. No war, no tribe numbers, no plan, no medicine, no carved pawn. One-to-four-word clauses. Zero em-dashes. The one ellipsis matches her shipped `offduty`/`served` cadence.

**Shadow check:** this is the node's ONLY variant, so it shadows nothing; the base `text` stays the arm every pre-terminal player sees. `inn_guests_ext_loop` / `inn_guests_gate_proof` pin the BASE greet line — confirm their fixtures (`inn_guests_ext_start`, `inn_guests_gate_start`) do NOT hold `rags_price_kept`:

```
grep -c rags_price_kept wandering_inn_game/qa/fixtures/inn_guests_ext_start.json wandering_inn_game/qa/fixtures/inn_guests_gate_start.json
```

Expect 0 for both. If either is nonzero, the pinned base line is dead and the script must be re-derived.

- [ ] **Step 4: Do NOT touch `data/maps/inn/inn.json`.** Her guest row's two-arm window (`requires rags_meeting_settled` / `absent drove_off_rags`, `:1199`/`:1202`) and its code twin `src/core/inn_guests.gd:48` are unchanged and must never disagree. The inn guest roster array is byte-identical across twelve rows and is not this lane's to move.
- [ ] **Step 5: Run** `res://tests/test_inn_guests.gd` + `res://tests/test_dialogue.gd` + `res://tests/test_copy_fit.gd` — expect PASS.
- [ ] **Step 6: Run the counter-integrity trio** — `res://tests/test_content.gd`, `res://tests/test_reachability.gd`, `res://tests/test_quests.gd`. All three must now be green (all producers landed in Step 1). Verify each on the three-part bar: exit 0, `^PASS` present, zero `SCRIPT ERROR|Parse Error|WARNING`.
- [ ] **Step 7: Commit**

```
feat(dialogue): Rags's inn register answers the kept price (#308)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

---

## Task 8 — QA: four canonicals, four fixtures, manifest, seed table, generated docs

**Files:**
- Create: `qa/scripts/floodplains_price_talk.json`, `floodplains_price_help.json`, `floodplains_price_fight.json`, `floodplains_price_gate_proof.json`
- Create: `qa/fixtures/floodplains_price_talk_start.json`, `floodplains_price_help_start.json`, `floodplains_price_fight_start.json`, `floodplains_price_betrayal_start.json`
- Modify: `qa/manifest.json`, `wandering_inn_game/AGENTS.md` (seed table), `tests/test_fixture_coherence.gd` (`COMBAT_BAND_FIXTURES` +1)
- Regenerate: `qa/manifest.json` surfaces, `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`

- [ ] **Step 1: Load `wi-writing-qa-scripts`.** Fixture-first policy applies: all four are fixture starts. Note the traps: `click_dialogue_option` takes `"option"`, **1-BASED** (a wrong key silently no-ops); `assert_state` on a MISSING path ERRORS (`test_driver.gd:874` `_fail("assert_state: path not found")`) — so a missing-key probe can NEVER be a passing proof, and a counter path must be spelled in full (`accomplishments.<id>`, not `<id>`); comment keys NEVER go inside `payload_contains`; a bare `wait_for_event ui_toast_rendered` proves nothing about WHICH toast; `player_facing` is a 2-VECTOR, never a string; JSON coordinates parse as floats.

  > **THE WHOLE-RUN-SCAN TRAP, and its fix.** `assert_event_absent` is implemented as `if _has_event(type, payload_contains): _fail(...)` (`qa/test_driver.gd:520-522`) and `_has_event` iterates **the entire `_events_seen` array from index 0** — there is no cursor. So a **BARE-TYPE** `assert_event_absent` on any event the script itself emitted earlier is **guaranteed to red**, no matter where in the step list it sits. Two legal escapes, both used below:
  > 1. **`assert_event_count`** (`test_driver.gd:523-526`, `_count_events` + an exact `count`) — the right shape for "this happened exactly once, and not again".
  > 2. **A payload-filtered `assert_event_absent`** — `payload_contains` narrows the scan to a value the run genuinely never emitted (e.g. `{"id": "the_price_kept"}` on `quest_started`).
  >
  > Every `assert_event_absent` in these four scripts must be one of those two. Audit them before running: bare-type asserts on `dialogue_started`, `combat_started`, `accomplishment_recorded`, `map_changed` are all self-inflicted reds.
- [ ] **Step 2: Author the fixtures by COPYING `qa/fixtures/rags_gates_met_start.json`** (`"version": 7`; the skill doc's `"version": 3` and the cross-recon's "5" are both stale — copy the shipped file, never the doc). Required per-fixture deltas:

| fixture | current_map / cell | accomplishments added on top of the rags template | started_quests | inventory / gold |
|---|---|---|---|---|
| `floodplains_price_talk_start` | `street`, beside Krshia (approach cell facing her at (13,2)) | `met_rags:1`, `chatted_with_rags:1`, `rags_price_named:1`, `helped_rags_tribe:1`, `rags_meeting_settled:1` | `["chieftains_price","the_price_kept"]` | gold **12** (the 8g alternate must be affordable) |
| `floodplains_price_help_start` | `floodplains`, standing beside `corusdeer_range` | same as above | same | gold 20 |
| `floodplains_price_fight_start` | **`rags_camp`, (5,7)** | same as above | same | gold 20, `rusty_sword` equipped |
| `floodplains_price_betrayal_start` | `floodplains`, **(16,19)** facing `[0,1]` | **NONE** — byte-identical accomplishments to `rags_gates_met_start` (pre-settle, all encounter gates met) | `[]` | as template |

  - Every fixture carries `classes: {"warrior": 2}` (the region's shipped band) and `met_relc`, or `_check_post_tutorial` fails.
  - **`rng_state` is DERIVED, never hand-typed**: `perl -e 'alarm 60; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/_derive_rng_state.gd -- <seed>` prints `seed=N -> state=M`. `RNG_STATE_MIN_MAGNITUDE = 1_000_000` (`test_fixture_coherence.gd:378-388`) rejects anything smaller as hand-typed.
  - **DERIVE-THEN-RUN-UNTIL-WIN, for BOTH fight fixtures (binding).** Deriving an `rng_state` is not enough: a gated cell at `win_lo 0.55` means **5%–45% of seeds LOSE**, and on a loss `WICombatBanking.resolve` takes the else branch and emits `GAME_OVER`, so the victory counter never banks and the script's `wait_for_event accomplishment_recorded` **times out**. The fixture's `rng_state` — not the manifest `seed` — governs the combats, so the outcome is a property of the fixture and must be pinned by observation:
    1. Derive `rng_state` from seed *k* (start at 9).
    2. **Run the script that fights on it, end to end**, and read `result.json`.
    3. If the fight loses, derive from seed *k+1* and repeat.
    4. **Record the chosen seed AND the observed outcome in that fixture's own `_comment`** — e.g. `"derived from seed 11; camp_ground_press WON at this rng_state (verified 2026-07-28). A re-derivation must re-verify the win or the script times out on accomplishment_recorded."` (`qa/fixtures/**` is census-exempt, so this note is free.)

    Owed by **both**: `floodplains_price_betrayal_start` (drives `rags_scouting_party`, whose shipped cell `rags_scouting_party_t1_solo` is gated at 0.55–0.95, `tests/sim_combat_batch.gd:59`) **and** `floodplains_price_fight_start` (drives `camp_ground_press`, a brand-new 3-enemy encounter with no measured cell at all until Task 6 Step 5 runs). Do this AFTER Task 6's tuning has settled — a re-tune invalidates the observed outcome and the loop must be re-run.
  - **Monotone-chain coherence:** `rags_meeting_settled` implies the meeting happened — carry `met_rags` and `rags_price_named` and exactly ONE peaceful rung (`helped_rags_tribe`). Never carry `drove_off_rags` alongside `helped_rags_tribe`.
  - `floodplains_price_fight_start` stands on `rags_camp`, which is why Task 4 Step 7 added the `MAP_REQUIRES` row — the fixture's `rags_meeting_settled` satisfies it.
- [ ] **Step 3: `COMBAT_BAND_FIXTURES` row** in `tests/test_fixture_coherence.gd` — pins the tuned build the Task 6 cells were measured at, and fails in BOTH directions:

```gdscript
	# 2026-07-28 (#308): the camp-ground press was tuned at warrior2, the build
	# the Floodplains gates open at and the build its sim_combat_batch cells use.
	"floodplains_price_fight_start": 2,
```

- [ ] **Step 4: `floodplains_price_talk` — the TALK terminal path.** Steps: title Continue idiom (`ui_title_gate_rendered` → confirm → `ui_title_rendered` → move down 1 → confirm → `game_loaded` → `world_ready` → `assert_state current_map` = `street`) → bump-move into Krshia's cell to face her (never trust `player_facing`) → interact (pool line) → interact (hub) → count the VISIBLE options and select the 8-gold alternate → `wait_for_event accomplishment_recorded {"id": "camp_trade_brokered"}` → `wait_for_event dialogue_node {"speaker":"Krshia"}` on `goblin_run` → close → `assert_state gold` (the exact ledger, 12 → 4) → `teleport {"map":"floodplains","cell":[16,20]}` → interact → hub → select the F1 offer row → `winter` → select the trade report rung → `wait_for_event accomplishment_recorded {"id":"rags_price_kept"}` → `wait_for_event quest_completed {"id":"the_price_kept"}` → `assert_event_absent accomplishment_recorded {"id":"camp_ground_held"}` (route purity) → `assert_state accomplishments.persuaded_someone` (the grant deposited 4 + 0 from the gold arm).
  **Derive every cursor index from a REAL run's `events.jsonl`, never from the authored JSON order** — hidden options shift the visible list.
- [ ] **Step 5: `floodplains_price_help` — the HELP route including the assisted hunt.** Steps: fixture boot on `floodplains` → walk into `corusdeer_range`, `combat_autoplay` → `wait_for_event accomplishment_recorded {"id":"corusdeer_culled"}` → `teleport` to (17,21) → interact `rags_camp_mouth` → `wait_for_event map_changed {"map":"rags_camp"}` → `assert_state current_map` = `rags_camp` → **`assert_event_logged ui_map_rendered` with the exact `floor_cells`/`blocked_cells` counts read off the run** (the standard render-confirmation idiom) → interact `camp_carry_yoke` → `wait_for_event accomplishment_recorded {"id":"camp_carry_jobs"}` + `gold_changed` delta 2 → **prove the meat rack was ABSENT before both gates and PRESENT after** (`ui_entities_rendered` count before/after, or `assert_event_absent` on its toast before the yoke) → interact `camp_meat_rack` → `wait_for_event accomplishment_recorded {"id":"camp_larder_filled"}` → exit door → `assert_state current_map` = `floodplains`, `player_cell` = (17,21) → walk to (16,20), interact, report rung → `rags_price_kept` + `quest_completed`.
- [ ] **Step 6: `floodplains_price_fight` — the ally fight.** Steps: fixture boot INSIDE `rags_camp` at (5,7) → walk to face `camp_ground_press` → interact → `wait_for_event combat_started` → **the POSITIVE roster proof** (below) → `combat_autoplay` → `wait_for_event accomplishment_recorded {"id":"camp_ground_held"}` → **`assert_state accomplishments.victories`** → exit → report → `rags_price_kept` + `quest_completed`.

  **The roster proof is POSITIVE ONLY — there is no working way to assert an absent combatant.** Both mechanisms the round-1 draft prescribed are dead ends: a bare-type `assert_event_absent combat_started` reds on the run's own `combat_started` (whole-run scan, Step 1), and a missing-key probe via `assert_state combat.combatants.relc` **fails on path-not-found** (`test_driver.gd:874`), i.e. it fails exactly when it should pass. `WICombat.snapshot()` (`src/core/combat/wi_combat.gd:693-711`) exposes `order` (the turn order array) and `combatants` keyed by id with a `side`, so pin the roster from both ends:

```json
{"action": "assert_state", "path": "combat.combatants.rags_ally.side",         "equals": "player"},
{"action": "assert_state", "path": "combat.combatants.goblin_spear_ally.side", "equals": "player"},
{"action": "assert_state", "path": "combat.order", "contains": ["rags_ally", "goblin_spear_ally"]},
{"action": "assert_state", "path": "combat.order", "equals": ["<pc_id>", "rags_ally", "goblin_spear_ally", "plains_scavenger_a", "plains_scavenger_b", "plains_scavenger_lead"]}
```

  The `contains` arm proves the two goblins were fielded; the **exact `equals` pin of the full SIX-id order is the Relc guard** — if `allies: ["relc"]` is ever copy-pasted in (D3), or a tamed companion is appended, the array is no longer those six ids in that order and the script reds loud. **Derive the exact order (including the pc's id and the initiative sort) from a REAL run's `events.jsonl`/`result.json`, never from the authored arrays**; `equals` goes through `_loosely_equal`, so element order matters. The feed's `_announce_allies` line is presentation; the state is the contract.

  **The victory counter path is `accomplishments.victories`, NOT `victories`.** `WIGame.snapshot()` (`src/core/wi_game.gd:2177-2221`) has no top-level `victories` key — it is banked as an ordinary accomplishment (`src/core/combat_banking.gd:111` `_record_accomplishment.call("victories", 1)`) and surfaces under the `accomplishments` dict at :2187. A bare `"path": "victories"` hard-fails on path-not-found. The reason for pinning it at all stands: a gray-band win deposits `won_combat` **fractionally** under challenge weighting (`combat_banking.gd:128-129`) while every other `on_victory` id banks integer at :131, so `victories` is the counter that reads the same under both flag states. **Any other bare counter name used as an `assert_state` path in these four scripts takes the same `accomplishments.` prefix.**

  **Never pin toast ORDER across `combat_started`** — pre-combat queue depth is wall-clock and varies with host frame rate. Pin delivery with `from_start` + a generous timeout.
- [ ] **Step 7: `floodplains_price_gate_proof` — the betrayal branch (RULING 3, and the branch has ZERO live QA coverage today).** Steps: `floodplains_price_betrayal_start` boot at (16,19) → move south 1 → interact → hub `"You. The one who didn't kill."` → select `"(Draw steel.)"` → `wait_for_event dialogue_ended` **THEN** `wait_for_event combat_started` (the effects+`end:true` event-order trap) → `combat_autoplay` → `wait_for_event accomplishment_recorded {"id":"drove_off_rags"}` → `wait_for_event accomplishment_recorded {"id":"rags_meeting_settled"}` (proving BOTH terminals bank, which is the whole reason the gate is two-armed) → walk back to (16,20) → interact → **the second-interact proof (below)** → **`assert_event_absent quest_started {"id":"the_price_kept"}`** (payload-filtered: this id is never emitted in this run) → walk to (17,21) and interact toward (17,22) → **`assert_event_absent map_changed {"map":"rags_camp"}`** (payload-filtered; the camp mouth's `present_when.absent` arm holds, so a betrayer never gets in) → **`assert_event_absent accomplishment_recorded {"id":"rags_price_kept"}`** (payload-filtered).

  **The second interact CANNOT be proven with a bare `assert_event_absent dialogue_started`.** This script opens Rags's dialogue itself three steps earlier — that is what `(Draw steel.)` is selected from — so a whole-run scan for `dialogue_started` finds the run's OWN event and reds (Step 1's trap, which the round-1 draft flagged and then violated). The encounter entity IS removed permanently on victory (`wi_game.gd:1988-1989`); prove it with a count, or with a payload filter on the node:

```json
{"action": "assert_event_count", "type": "dialogue_started", "count": 1}
```

  — the pre-fight open being the only one in the whole run. Equivalent alternate, if a later edit ever adds a second legitimate open: `{"action":"assert_event_absent","type":"dialogue_node","payload_contains":{"speaker":"Rags","text":"Good trade. Plains quiet. Go safe."}}` (the settled hub line this state would otherwise render).
- [ ] **Step 8: Belt-and-braces unit arm for the `hide_when` itself.** The betrayal branch removes the entity, so the live script cannot render the settled hub with `drove_off_rags` held. Add ONE arm to `tests/test_dialogue.gd` (read its existing ctx idiom first) feeding accomplishments `{rags_meeting_settled: 1, drove_off_rags: 1}` at `rags_meeting`'s `hub` and asserting the F1 offer row is NOT in `current_options()`, plus the mirror case (`drove_off_rags` absent → row present). This is the can-fail pair the script cannot reach. **Every local this arm declares carries the `f_` lane prefix** (`f_ctx`, `f_hub`, `f_opts`) per RULING C — three sibling lanes append into the same function bodies in the same test files, and a duplicate `var` in one continuous function scope is a **parse error, not a shadow**, which reds the whole suite the moment the second lane merges.
- [ ] **Step 9: Register all four in `qa/manifest.json`, INSERTED AFTER THE `rags_gate_check` ENTRY** (`qa/manifest.json:4342`) — this lane's RULING C anchor, not the end of `scripts[]`. Entry shape `{"script","seed","fixture","note","tiers","surfaces"}`. `seed: 9` for convention on all four; **the fixture `rng_state` — not this seed — governs the combats, and for the two fight fixtures that state is the one pinned by the derive-then-run-until-win loop in Step 2.** `tiers: ["full"]` for all four, matching every other Floodplains canonical (none are in `smoke`). **Write `surfaces` as `{}` or copy a sibling's shape and then REGENERATE — never hand-author it.**
- [ ] **Step 10: Add four rows to `wandering_inn_game/AGENTS.md`'s "Canonical QA seed table", INSERTED AFTER THE `rags_gate_check` ROW** (`AGENTS.md:327`) — the same anchor as the manifest, so the two stay adjacent and no sibling lane's rows interleave. Row shape:

```
| `floodplains_price_talk` | 9 (fixture `floodplains_price_talk_start`) | v0.16 F1 (#308): TALK route -- Krshia's 8g quiet run banks camp_trade_brokered, then the report to Rags closes the quest |
| `floodplains_price_help` | 9 (fixture `floodplains_price_help_start`) | v0.16 F1 (#308): HELP route -- corusdeer cull + camp carry job arm the drying rack, camp_larder_filled, then the report |
| `floodplains_price_fight` | 9 (fixture `floodplains_price_fight_start`) | v0.16 F1 (#308): FIGHT route -- the first goblin-ALLY encounter (rags_ally + goblin_spear_ally fielded), camp_ground_held, then the report |
| `floodplains_price_gate_proof` | 9 (fixture `floodplains_price_betrayal_start`) | v0.16 F1 (#308): betrayal branch -- drove_off_rags banks BOTH terminals, the F1 offer never appears, the camp mouth stays shut (the exclusion's can-fail proof) |
```

`ci_sweep.sh` HARD-FAILS at startup if this table and the manifest disagree.

- [ ] **Step 11: Regenerate BOTH generated artifacts, in the SAME commit:**

```
python3 wandering_inn_game/scripts/derive_qa_surfaces.py --write
python3 scripts/render_qa_notes.py --write      # RULING E: the bare call does NOT write
python3 scripts/render_qa_notes.py              # the check: rc=0 + "PASS: QA notes match manifest"
python3 scripts/check_doc_drift.py
python3 wandering_inn_game/scripts/derive_qa_surfaces.py --check
```

A stale `surfaces` tag or an un-rendered `docs/QA-SCRIPT-NOTES.md` REDS the `leak-check` job — that was the #312 CI red, and calling `render_qa_notes.py` without `--write` reproduces it exactly (`scripts/render_qa_notes.py:55-66`: it renders in memory, diffs, prints `QA NOTES DRIFT`, returns 1). **`QA-SCRIPT-NOTES.md` is rendered WHOLE from the entire manifest, so it must be re-rendered at every MERGE-TRAIN merge that combines two lanes' manifest entries — this lane's own commit is necessary, not sufficient.**

- [ ] **Step 12: Run each new script** and read its `result.json`:

```
wandering_inn_game/qa/run_qa.sh floodplains_price_talk headless --seed=9
```

Output lands in `wandering_inn_game/qa_output/<script>/` and is CLOBBERED by any re-run. **"missing result.json" with rc=0 is a RED, never a pass.**

- [ ] **Step 13: Commit**

```
test(qa): four canonicals for The Price Kept, incl. the untested betrayal branch (#308)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

---

## Task 9 — Re-gate, machine playtest, PR

- [ ] **Step 1: SETTLE THE TREE FIRST.** A sweep launched while edits continue produces a MIXED-STATE verdict; kill and relaunch. Commit everything before this task.
- [ ] **Step 2: Census RE-check** — `python3 scripts/comment_census.py --check` from repo root; must return 0. **This is the SECOND measurement, not the first: the binding one already happened at the end of Task 6**, when the last DATA edit landed. Compare the lane's actual `_comment` total against the **2,405 projection / ~2,742 budget** from Global Constraints and carry the real number into the PR body. If it overshoots, cut `_comment` prose (move rationale to a QA-script `_comment` or `docs/CHOICE-LOG.md`, both census-exempt) — never cut player copy, which is the budget's own denominator. **Re-running this on this branch alone is NOT the gate:** the census is a property of the merged tree, so it is re-run at every merge-train merge, and post-train overshoot is the wave-close PR's to own (RULING B).
- [ ] **Step 3: Structural lint** — `python3 wandering_inn_game/scripts/data_lint.py`. Zero findings.
- [ ] **Step 4: Guidance mirror + doc drift** — `python3 scripts/sync_agent_guidance.py`, then `python3 scripts/render_qa_notes.py --write` **followed by a bare `python3 scripts/render_qa_notes.py` as the check** (RULING E — the bare call alone only diffs and returns 1), then `python3 scripts/check_doc_drift.py`. (The `leak-check` job runs all of these.)
- [ ] **Step 5: Every unit suite.** Loop `tests/test_*.gd` under a 240s alarm; each must give exit 0 + a `^PASS` line + zero `SCRIPT ERROR|Parse Error|WARNING`. Report PER SCRIPT, never "everything passed". Minimum attention: `test_content`, `test_reachability`, `test_quests`, `test_dialogue`, `test_combat_data`, `test_combat_visuals`, `test_copy_fit`, `test_fixture_coherence`, `test_inn_guests`, `test_shipped_ids`.
- [ ] **Step 6: Full balance harness** — `res://tests/sim_combat_batch.gd` under a 600s alarm, unsharded, once, as the gate. Both new cells inside the 0.55–0.95 window with median rounds 3–12; **no pre-existing cell may move** (this lane adds new ids only and retunes nothing shipped). **Copy the two measured win rates and medians into the PR body** — per RULING A that record, not a narrowed window, is what places these fights in the Floodplains band.
- [ ] **Step 7: Targeted re-gate.** Run `qa/ci_sweep.sh --touching` against each shared surface this lane changed:

```
qa/ci_sweep.sh --touching data/quests.json
qa/ci_sweep.sh --touching data/maps/floodplains/floodplains.json,data/maps/floodplains/rags_camp.json
qa/ci_sweep.sh --touching data/dialogue/rags_meeting.json,data/dialogue/rags_inn.json,data/dialogue/krshia_crate.json
qa/ci_sweep.sh --touching data/maps/liscor/street.json
qa/ci_sweep.sh --touching data/combatants.json
```

**`--touching data/quests.json` now maps to 20+ canonicals** (`cisterns_*`, `crate_*`, `door_chain_*`, `horns_dig_*`, `invrisil_disagreement_*`, `pallass_walkthrough`, …) via `MONOLITH_SYSTEMS` (GH#281) — the skill doc's "maps to ZERO scripts" line is OUT OF DATE. Budget the time. Named scripts that MUST be green: `rags_meeting_loop`, `rags_gate_check`, `inn_guests_ext_loop`, `inn_guests_gate_proof`, `stages_loop`, `crate_light`, `crate_talk`, `wrong_order_talk`, `pallass_walkthrough`, `door_chain_fight`, `floodplains_bestiary_loop`, `parley_gates_check`, `parley_talkdowns_loop`, `beast_tamer_loop`, `goblin_night_patrol_loop`, `regional_work_loop`.

- [ ] **Step 8: Full sweep, polled not blocked.** A full `ci_sweep.sh` cannot run foreground in one Bash call — the harness promotes it to background and a waiting agent is stranded. Idiom: start it writing to a log with its own `rc=` echo, then POLL with short foreground `sleep 60; tail -1 <log>` calls. A full sweep runs `flush_artifacts.sh` first, which WIPES prior windowed PNGs — take screenshots AFTER, not before.
- [ ] **Step 9: Machine playtest (windowed), `wi-machine-playtest`.** Shot list:
  1. `floodplains` at (17,21) — the camp mouth PRESENT (settled fixture) and ABSENT (`rags_gate_unmet_start`, the can-fail pair).
  2. `rags_camp` on arrival at (5,7), day — read the hollow for brown-box, rim legibility, and whether the fire pit reads as the focal point.
  3. `rags_camp` at dusk and at night — the mood row is the whole point; if it renders flat white the row did not take.
  4. `camp_ground_press` combat board mid-fight — **the first goblin-ally board in the game, and the ONLY legibility evidence that exists for five new rigs** (RULING F: none of them is in `FIGURE_ROWS` or `audited`, so no test measures them). Explicit read list:
     - Are `rags_ally` and `goblin_spear_ally` separable from the enemy scavengers?
     - Is the goblin figure legible beside a human rig at all — this is the first windowed read of `goblin_base` on a board, and it is evidence, not a number to quote.
     - **Are the THREE `human_laborer` scavengers separable FROM EACH OTHER?** They share one silhouette and ship near-identical warm tints (0.86/0.78/0.62, 0.80/0.74/0.60, 0.90/0.70/0.55) on one board. Nothing in the suite catches this — the tint-uniqueness assert at `tests/test_combat_visuals.gd:544-556` covers only the hard-coded `camouflage` list, which contains none of them. If they read as one mass, re-tint before merge.
     - Does the ally-announce line read right?
  5. The `winter` dialogue node with all three report rungs visible (a synthetic all-routes state) — cursor legibility with five visible options.
  6. Krshia's hub with both F1 rows visible — option-list length and the `[Charming Smile]` visible-locked render.
  Drain every finding to `docs/VISUAL-LOG.md`.
- [ ] **Step 10: CHOICE-LOG.** Append every entry from this plan's "Choices logged" list to `docs/CHOICE-LOG.md` before opening the PR.
- [ ] **Step 11: PR** per `.github/PULL_REQUEST_TEMPLATE/issue-close.md` — `Closes #308`, `## Choices made` (options taken + rejected alternatives with reason), `## Validation evidence` (exact command + one-line result per gate), `## Player-visible proof` (which windowed script/seed, what was checked by eye), `## New agent context` (TRAPS/CONTRACTS added with `file:symbol`), `## Deferred / follow-ups` (the leads row below). **`[ci-full]` in the head commit message.**

  **Three things this lane's PR body MUST carry for the merge train:**
  1. **The measured medians and win rates** for `camp_ground_press_t1_rags_ally` and `camp_ground_press_t1_spear_ally`, next to the shipped Floodplains cells they are ordered against (RULING A — the window is deliberately the wide shipped precedent, so the PR body is the only place the band ordering is evidenced).
  2. **This lane's absolute `_comment` char total** (projection 2,405; report the measured figure) so the controller can sum the four lanes before the train starts (RULING B).
  3. **The derived seed and the observed WIN outcome** recorded for `floodplains_price_fight_start` and `floodplains_price_betrayal_start` (Task 8 Step 2).

---

## Post-quest life (spec §"Post-quest life": every giver gets ≥1 reactive surface keyed to the terminal)

| Surface | Mechanism | Key | Placement rule |
|---|---|---|---|
| **Rags (the giver)** | `rags_meeting.json` hub `text_variants` — Task 2 Step 2 | `rags_price_kept` (TERMINAL) | APPENDED AFTER the `rags_meeting_settled` arm; last-match-wins means anything earlier never renders |
| **Rags (inn register)** | `rags_inn.json` `greet` `text_variants` — Task 7 Step 3 | `rags_price_kept` (TERMINAL) | the node's first variant; base `text` stays unconditional |
| **Krshia (TALK-route surface)** | `street.json` `talk_pool_stages` member — Task 3 Step 4 | `camp_trade_brokered` (route) | APPENDED AFTER `krshia_thread_door_neutral` (`street.json:1690`), the `door_awakened`-gated stage every eligible player holds; carries its four warm lines verbatim so the warm register survives |

**The giver has NO npc entity anywhere in the repo** (`rags_meeting.json:2`) — her conversation hangs off the `rags_scouting_party` ENCOUNTER, so the `talk_pool_stage` mechanism is structurally unavailable for her. The hub `text_variant` is the equivalent register, and the inn variant is her second. Logged as a deliberate substitution.

---

## DEFERRED TO CLOSE PR — the Leads strip row

**Leads-strip rule:** `test_content.gd:78-101` `_validate_leads` checks every `requires`/`hide_when` counter against `data/shipped_ids.json`'s frozen `accomplishments` list, and that file is release-cut-only (`RELEASE = "0.15.0"`). F1's natural `hide_when` key is `rags_price_kept`, which is NEW and therefore **not frozen** — a row shipped in this PR fails `test_content` immediately. **No `data/leads.json` edit lands in this PR.**

Draft row, to be added by the v0.16 CLOSE PR (after the 0.16.0 freeze regenerates `shipped_ids.json`):

```json
{ "id": "lead_camp_winter", "requires": { "rags_meeting_settled": 1 }, "hide_when": { "rags_price_kept": 1 }, "lead_text": "Rags stood on the rise the whole time you were leaving, and did not sit down.", "place": "The southern floodplains" }
```

Note the shape constraint recorded in `data/leads.json:2`: every row MIRRORS its target dialogue option's own `requires`/`hide_when` **exactly**. The F1 offer row's real gate is `requires {rags_meeting_settled: 1}` + `hide_when {drove_off_rags: 1}`; the leads schema has no `absent` arm and `hide_when` is single-key, so the row above trades the betrayal arm for the terminal arm. **That divergence must be re-adjudicated at close** — either accept it (a betrayer briefly sees a lead pointing at an entity that no longer exists) or add a second lead-schema arm. Flagged, not decided here, because the row cannot ship in this PR either way.

---

## Danger list

Every risk below has its mitigation baked into a numbered step.

### From the Floodplains recon

| # | Risk | Mitigation (step) |
|---|---|---|
| D1 | **No goblin-ally combatant exists.** Every goblin row is `side: "enemy"`; one id holds one side, so `rags` cannot be reused. | Task 6 Step 2 creates `rags_ally` + `goblin_spear_ally` as `side: "player"` records; Task 6 Step 9 runs `test_combat_data` (ally-id resolution). |
| D2 | **Arena capacity is 4.** A third ally silently benches a [Beast Tamer]'s wolf with the fixed "crowded field" toast. | RULING 1: exactly TWO allies (Task 6 Step 3). |
| D3 | **Relc will field against the goblins if the region's ally idiom is copy-pasted** (five floodplains encounters use `allies: ["relc"]` + `met_relc`, which the rags fixtures already hold). | Task 6 Step 3's explicit two-name `allies` array + `ally_requires: {rags_meeting_settled: 1}`; Task 8 Step 6's **exact `equals` pin of the full six-id `combat.order`** — an absent-assert cannot prove this (bare-type absent reds on the run's own event; a missing-key `assert_state` fails on path-not-found), so the proof is positive. |
| D4 | **The betrayal branch has ZERO live QA coverage** — `drove_off_rags` is pinned only by `test_inn_guests.gd:121-127`. | RULING 3: `floodplains_price_gate_proof` (Task 8 Step 7) plus the unit can-fail pair (Step 8). |
| D5 | **Stale spec assumption:** F1 TALK "builds on the shipped `brokered_goblin_trade` thread" — that thread does not exist. | RULING 2: Task 3 CREATES the surface; Step 1 re-verifies the pinners. |
| D6 | **Krshia's `talk_pool_stages` is crowded** — ten last-match-wins stages ending in a `door_awakened` stage every post-door player holds; anything earlier is silently dead (the nine-`*_inn_settled` bug class). | Task 3 Step 4 appends AFTER `street.json:1690` and carries the warm lines forward; Step 5 runs the ladder-order check. |
| D7 | **Shared-file contention at the merge train** (`quests.json`, `combatants.json`, `moods.json`, `qa/manifest.json`, the AGENTS.md seed table, `character-profiles.md`, `street.json` if a sibling lane took Krshia). | RULING C: **anchored inserts, never EOF/array-end appends** — `chieftains_price` / `rags` / `floodplains` / the `rags_gate_check` manifest entry and seed row; RULING D: `character-profiles.md` is SHARED and this lane is READ-ONLY on it (no Floodplains stub was pre-landed); `f_` prefix on every new test local; Task 3 Step 1 re-greps for sibling-lane Krshia edits. |
| D8 | **A new map is three coupled edits beyond the map file** (MAP_REQUIRES, LANDMARK_TOKENS, mood) and `to_map`/`to_cell` are validated by NOTHING at runtime. | Task 4 Steps 4–7 (both arrival cells hand-verified + all three coupled edits); Task 8 Steps 5–6 walk both crossings live. |
| D9 | **Five new rigs ship with ZERO automated figure/tint coverage.** `rags`, `goblin_base` and `human_laborer` are absent from `FIGURE_ROWS` (four entries) and every new id is absent from the `audited` array, so `test_combat_visuals` passes **by exclusion**, not by measurement — and its tint-uniqueness assert covers only the hard-coded `camouflage` list, so three same-silhouette scavengers in near-identical warm tints ship green. | RULING 5 + RULING F: no scale is touched, **no figure number is quoted anywhere shipped**, Task 6 Step 7 states the exclusion plainly, Task 6 Step 8's VISUAL-LOG row records "unmeasured", and **Task 9 Step 9 shot 4 is the only evidence** — with the three-scavenger separation on its explicit read list. |
| D10 | **New counters gated before they are produced** → `test_reachability.gd:50` fails loud. | RULING 7: Task 7 Step 1 lands producers and gates in ONE commit. |
| D11 | **`scales` on a story fight** is validator-forbidden. | Task 6 Step 3 omits the key entirely and says so in the `_comment`. |
| D12 | **Last-match-wins everywhere** (hub `text_variants`, `talk_pool_stages`, `resolution_paths`). | Task 1 (weakest-first ladder + `_resolution_order`), Task 2 Step 2 (variant appended last), Task 3 Step 4 (stage appended last). |
| D13 | **`rags_meeting_loop`'s settled-state guard clicks visible option 1 blind** — any new hub row above the exit hijacks it. | Task 2's INDEX-PIN TRAP note: every new hub row is appended LAST; Task 9 Step 7 re-runs the script. |
| D14 | **(16,20) is the pinned approach cell** for `rags_meeting_loop`'s `move south 1`. | Task 4 Step 2 places the camp mouth at (17,22), off the lane, with four open neighbours. |
| D15 | **A betrayer could walk into the camp** — `door_when` is `requires`-only and the betrayal win banks `rags_meeting_settled` too. | Task 4 Step 2 puts the two-arm peaceful gate on `present_when` (which supports `absent`) and keeps `door_when` as the traversal gate; Task 8 Step 7 proves it live. |

### Cross-cutting risks that apply here

| # | Risk | Mitigation (step) |
|---|---|---|
| X1 | **Census margin is 383 chars for the WHOLE WAVE**, and the published `450 + 0.1765x` formula is the combined-addition constraint, not a per-lane allowance — four lanes each claiming it overspends by ~1,350 chars and reds `leak-check` on the third or fourth merge. | RULING B: this lane's constant is **112**, budget ≈2,742, **projection 2,405 stated in Global Constraints and in the PR body**; the four longest `_comment`s were cut to one-sentence trap notes at plan time; measured at the end of Task 6 and re-checked at Task 9 Step 2; **re-run on the MERGED tree at every train merge**, with post-train overshoot owned by the wave-close PR. |
| X2 | **`leads.json` counters must already be frozen.** | DEFERRED TO CLOSE PR section — no leads edit ships here. |
| X3 | **`LANDMARK_TOKENS` will fire for the new interior** and a missing row is a HARD fail at `test_content.gd:1475`. | Task 4 Step 6. |
| X4 | **`POPULATION_FLOORS` is a subtraction tripwire** — window-gating an existing unconditional interactable drops a pinned count. | This lane gates NO existing entity: the camp mouth and the meat rack are NEW `present_when` entities, and `floodplains` carries no floor row. Verified — `POPULATION_FLOORS` is untouched. |
| X5 | **Vacuous-gate lint** on any bare-dict `*_when`. | Task 4 Step 2's `door_when` wraps `requires`; Task 4 Step 8 runs `data_lint.py`. |
| X6 | **Portal arrival lint / carrier-vs-row audit.** | No `portals.json` row is added — the camp is walk-in only (spec §172), which keeps the audit trivially green. Floodplains carries no portal row today either. |
| X7 | **`sim_combat_batch` has no Floodplains array**, and only `ENCOUNTER_CELLS` supports a per-cell `ally`. | Task 6 Step 4 routes both cells through `ENCOUNTER_CELLS`, which also means `total_cells` at :321 needs NO edit (one less shared-file collision). |
| X8 | **Band windows are strictly disjoint** — new fights must be NEW encounters with NEW roster ids, never retunes of shipped capstones. | Task 6 Step 2 adds five NEW ids and retunes nothing; Task 9 Step 6 confirms no shipped cell moved. |
| X9 | **Every encounter needs `arena`/`enemies`/`allies`/`on_victory` explicitly**; every non-pc combatant needs a positive `power_level`. | Task 6 Steps 2–3 carry all four keys and five power_levels; Step 9 runs `test_combat_data`. |
| X10 | **Effect dicts are an `elif` chain** — a two-key dict silently drops one AND fails validation. | Every `effects` array in Tasks 2, 3 is split one-verb-per-dict. |
| X11 | **Grant-duplicate force-consume** — an option consuming gold/item while granting a duplicate id force-consumes for nothing. | No F1 option grants an item. The 8-gold arm consumes only gold and grants only a counter. |
| X12 | **Adding a VISIBLE row to a shipped hub** shifts every index-driven crossing script. | Task 3 Step 1's grep + the verified finding that no Krshia-pinning fixture holds `rags_meeting_settled`; Task 2's append-last rule for the Rags hub. |
| X13 | **Fixture monotone chains + `MAP_REQUIRES`.** | Task 8 Step 2's coherence rules; Task 4 Step 7's `MAP_REQUIRES` row. |
| X14 | **Seed/RNG blast radius** — any combat-data edit can flip a canonical at its pinned seed. | Task 9 Step 7's `--touching data/combatants.json` re-gate; `rng_state` derived via `tests/_derive_rng_state.gd`, never hand-typed. |
| X15 | **Stale skill docs:** `--touching data/quests.json` → 20+ scripts (not zero); fixtures are `"version": 7`, not 3. | Task 9 Step 7 and Task 8 Step 2 both state the corrected fact. |
| X16 | **`test_content.gd` suppresses PASS while collecting failures** — never verdict from the last line. | Global Constraints' three-part green bar, restated at Task 9 Step 5. |
| X17 | **`QA-SCRIPT-NOTES.md` / manifest `surfaces` are GENERATED**, and **`render_qa_notes.py` WITHOUT `--write` writes NOTHING** — it diffs and returns 1, so a bare call is a no-op that leaves the file stale and reproduces the #312 `leak-check` red it was meant to prevent. | RULING E: every invocation is `--write` then a bare call as the check (Task 8 Step 11, Task 9 Step 4, the checklist). **Plus a merge-train step: the file renders WHOLE from the manifest, so it is re-rendered at every merge that combines two lanes' entries.** |
| X21 | **Four-way append collisions on shared containers** — `moods.json` (all four lanes at `pallass_forge`, the last key), `quests[]`, `combatants[]`, `manifest.scripts[]`, the AGENTS.md seed table, and `character-profiles.md` at EOF (three lanes hold stubs there; this one writes nothing); plus duplicate `var` locals in one continuous `tests/*.gd` function scope, which is a **parse error**, not a shadow. | RULING C/D: named anchors per lane (this lane: `floodplains`, `chieftains_price`, `rags`, the `rags_gate_check` manifest entry and seed row); `character-profiles.md` stub FILLED IN PLACE, never appended at EOF; every new test local prefixed `f_`. |
| X18 | **A full sweep in one Bash call strands a subagent**, and it wipes prior windowed PNGs. | Task 9 Step 8's poll idiom + screenshots-after ordering. |
| X19 | **Fresh worktrees need `godot --headless --import`** before any QA — a warm `.godot` from another branch is not sufficient. | Run it once immediately after creating the branch/worktree, before the first QA run. |
| X20 | **Alarm-wrap every godot call** — a failed `assert` hangs headless forever; macOS has no `timeout`. | Global Constraints; every godot invocation in this plan is wrapped. |

---

## Verification gate checklist (the `wi-verifying-changes` bar)

Run in this order; report PER COMMAND with its one-line result. Never "everything passed".

- [ ] `python3 wandering_inn_game/scripts/data_lint.py` → zero findings
- [ ] `python3 scripts/comment_census.py --check` → exit 0, DATA ≤ 15.0%, and this lane's `_comment` total at or under **2,405** (budget 112 + 0.1765 × new non-comment ≈ 2,742); the number goes in the PR body
- [ ] `python3 scripts/sync_agent_guidance.py` → clean
- [ ] `python3 scripts/render_qa_notes.py --write` **then** `python3 scripts/render_qa_notes.py` → rc=0 + `PASS: QA notes match manifest` (the bare call alone never writes), then `python3 scripts/check_doc_drift.py` → clean
- [ ] `python3 wandering_inn_game/scripts/derive_qa_surfaces.py --check` → clean
- [ ] `qa/run_qa.sh load_gate headless` → PASS with a real `result.json`
- [ ] Every `tests/test_*.gd` under a 240s alarm → exit 0 **and** `^PASS` **and** zero `SCRIPT ERROR|Parse Error|WARNING`
- [ ] `tests/sim_combat_batch.gd` (600s alarm, unsharded) → both new cells inside the 0.55–0.95 shipped-precedent window with median rounds 3–12; no shipped cell moved; **measured medians recorded in the PR body** (RULING A)
- [ ] `qa/ci_sweep.sh --touching …` for all five shared surfaces → green
- [ ] Full `qa/ci_sweep.sh` (polled) → green, `rc=0` read from the log's own echo
- [ ] Headless smoke boot → clean
- [ ] Windowed machine playtest, six shots, read by eye → findings drained to `docs/VISUAL-LOG.md`

## Exit criteria

1. `the_price_kept` is startable ONLY from the peaceful terminal, and the betrayal branch is proven — live — to never see the offer and never enter the camp.
2. All three routes bank distinct counters, complete the quest, and resolve weakest-claim-first with a `_resolution_order` note. Both Floodplains quests carry `"region": "Floodplains"` — the journal renders ONE region label, not two casings.
3. `rags_camp` renders at day/dusk/night with its own mood, hosts two quest beats and five non-quest surfaces (three of them pure observables with real toast copy), and both door crossings are walked live in a canonical.
4. The camp-ground fight fields exactly two goblin allies (proven by an exact `equals` pin of the full six-id `combat.order`, which is also the Relc guard), no `scales`, and lands mid-window on both single-ally harness cells with its medians recorded in the PR body.
5. Three reactive surfaces (Rags's hub, Rags's inn register, Krshia's stall) render for a player who finished the quest, and none of them shadows shipped copy.
6. Four new canonicals green at their pinned seeds; the manifest, the AGENTS.md seed table, and both generated artifacts agree.
7. Every gate in the checklist above is green, the census is under the limit, and every ruling and design fork is in `docs/CHOICE-LOG.md`.

---

## Choices logged (copy to `docs/CHOICE-LOG.md` at Task 9 Step 10)

The canonical list ships with this plan (the lane's `choice_log_entries`). It now also carries the entries created by the round-2 review, which MUST be logged even though they are corrections rather than design forks:

- **RULING A** — new `sim_combat_batch` cells use the wide shipped-precedent window 0.55/0.95; band ordering is evidenced by measured medians in the PR body, not by a narrowed gate.
- **RULING B** — the census constant is **112**, not 450 (the 450 is the whole-wave slack, split four ways); the four longest `_comment` drafts were cut to one-sentence trap notes and their rationale moved here.
- **RULING C** — anchored inserts (`chieftains_price`, `rags`, `floodplains`, the `rags_gate_check` manifest entry and seed row) instead of array-end appends, and the `f_` prefix on new test locals.
- **RULING D** — `docs/design/character-profiles.md` is SHARED, not Invrisil-exclusive; verified that the controller pre-landed no Floodplains stub, so this lane is READ-ONLY on it (§Rags is the voice bar) and appends nothing at EOF.
- **RULING E** — `render_qa_notes.py --write` then a bare check; re-rendered at every merge-train merge.
- **RULING F** — no shipped `_comment` quotes a board-figure number; `test_combat_visuals` passes by exclusion on every new id.
- Plus the round-2 content corrections: the `chieftains_price` region-casing fix, the Rags voice-bar rewrites (`winter_kept` / `winter_ways` / `winter_where`), and the derive-then-run-until-win seed discipline on both fight fixtures.

See the PR's `## Choices made` section for the same list with rejected alternatives.
