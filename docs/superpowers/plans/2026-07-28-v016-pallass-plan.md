# v0.16 "Region Depth" — Pallass Lane Implementation Plan

> Status: **ACTIVE** — issue #307, branch `issue/307-pallass-depth`. Progress ledger at `.lane-progress.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Pallass's two side quests — P1 "Tempered Standards" (forge commission, three real routes) and P2 "The Ledger Eats First" (bureaucracy comedy, three real routes) — plus two small walk-in interiors (`pallass_forge_hall`, `pallass_den_shop`) that host quest beats and pay off exploration after the quests close. Content-only: zero engine work.

**Authority spec:** `docs/design/2026-07-28-v0.16-region-depth-spec.md` (Pallass section, lines 103–134; binding shared conventions 160–182; verification 186–192). Where the controller rulings in *Global Constraints → Controller rulings* amend it, **the rulings win**.

**Issue:** #307 (Pallass). Sibling lanes: #305 Riverfarm, #306 Invrisil, plus the Floodplains slice — independent PRs, shared files listed below.

**Branch:** `issue/307-pallass-depth`
**PR title:** `Pallass depth: Tempered Standards + The Ledger Eats First, forge hall + den shop (#307)`

**Architecture:** Data-first Godot 4.7 under `wandering_inn_game/`. Quests/dialogue/maps/combatants are JSON; sim logic in `src/core/*.gd` (NOT TOUCHED by this lane); declarative QA scripts in `qa/scripts/` with hand-authored fixtures in `qa/fixtures/`.

**Tech stack:** Godot 4.7 headless for every gate; `python3` for `data_lint.py`, `comment_census.py`, `derive_qa_surfaces.py`, `render_qa_notes.py`, `splice_json.py`.

---

## Global Constraints

### Run discipline

- Test runner: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/<file>.gd` from repo root. **A failed `assert` HANGS a headless run forever** (`wandering_inn_game/AGENTS.md:15-18`); macOS has no `timeout`, so alarm-wrap every Godot call: `perl -e 'alarm 120; exec @ARGV' -- /usr/local/bin/godot --headless ...`.
- Grep EVERY run's output for `SCRIPT ERROR|Parse Error|WARNING`; zero known-harmless warnings ship. `test_content.gd` collects failures and `quit(1)`s while suppressing PASS — **never verdict from the last line**: require all three of nonzero-exit-check, a `^PASS` line, and a zero-noise grep.
- Skills to load at the named tasks: `wi-adding-dialogue-and-quests` (quests/dialogue), `wi-adding-a-scene` (maps), `wi-adding-an-encounter` (combat), `wi-writing-qa-scripts` (QA), `wi-verifying-changes` (before any green claim), `wi-machine-playtest` (windowed pass).
- **Worktree shadow:** an identical checkout exists at `.claude/worktrees/mq-foti-wave/`. Repo-root greps return doubled hits. Edit ONLY the top-level `wandering_inn_game/` tree.
- A fresh worktree needs `godot --headless --path wandering_inn_game --import` before any QA run.

### Copy rules (binding)

- **Book-17 bar** on all new material. The portal Skill's real name is Vol 9 — write **"the Magical Door"**, never anything else.
- `{addr}` / `{Addr}` for any address of the PC, and ONLY inside a `text`, `talk_pool`, or `talk_pool_stages.lines` key or a `*toast` key. A token in `data/quests.json` or `data/items.json` renders RAW and fails loud (`test_content.gd:630-636`).
- **Register purity:** the smith talks bench and spec, the attendant talks bells and counterweights, Grimalkin talks measurement. No lane character discusses another region's business, and nothing on the forge tier discusses Liscor politics.
- **No fetch-list copy:** beat descriptions point at a place and a person, never itemize objects.
- At most ONE em-dash per line. ASCII `--` renders as two literal hyphens; em-dashes hide as `—` escapes inside `data/maps/**` and QA scripts, so any dash lint must sweep BOTH forms.
- Copy budgets: `test_copy_fit.gd` holds DIALOGUE_LINE_CAPACITY 2, TOAST_TEXT_WIDTH 412.0, DIALOGUE_TEXT_WIDTH 656.0, PAGE_CHAR_BUDGET 200. Pool/stage lines are ambient barks — 2 wrapped lines max. Keep any single dialogue `text` under 200 chars or it pages (the `forge_runes` node's own `_comment` records a 204-char string splitting into a 12-char orphan page that read as a rendering fault).
- New characters need a `docs/design/character-profiles.md` voice block written BEFORE their dialogue (Task 0.1). `docs/` is census-exempt.

### Census budget (hard gate)

`python3 scripts/comment_census.py --check` from repo root is a leak-check CI job step. DATA sits at **15.0% against a 15.0% hard limit** — roughly 383 characters of slack at today's file size. Only `wandering_inn_game/data/**/*.json` counts; `qa/scripts`, `qa/fixtures`, `tests/`, and `docs/` are exempt.

**Budget rule for this lane (controller ruling B):** `new _comment chars <= 112 + 0.1765 * new non-comment chars`.

The `450 + 0.1765x` constant that the recon handed every lane is the WHOLE-WAVE slack solved from the real constraint `(166676 + C) / (1113728 + C + N) <= 0.15`. It is the budget for the COMBINED four-lane addition, not a per-lane allowance — four lanes each claiming 450 overspends the shared 383-char slack by ~1,350 chars and reds `leak-check` on the third and fourth merge. **This lane's share of the constant is 112 (450/4).**

- Measure with `python3 scripts/comment_census.py --check` **before every commit that touches `data/`**.
- **Projected absolute new `_comment` total for this lane: 2,977 characters** — measured directly off the 17 `_comment` strings drafted in this plan for `data/**` (5 map-entity, 2 dialogue-option, 2 dialogue-node, 2 graph-header, 1 combatant, 1 encounter, 2 quest, 2 carry/skill props). **State this number in the PR body** so the controller can sum the four lanes before the train starts. `_resolution_order` is NOT counted — `comment_census.py:54-60` counts only keys that both start with `_` and contain `comment`.
- **The 2,977 clears the lane budget only if this lane adds ≥ 16.2k new non-comment `data/**` characters** (`(2977 − 112) / 0.1765`). Two interiors, two quest blocks, ~19 dialogue nodes, four new tier entities, one combatant and two pool stages should land well past that, but **measure, do not assume**: at the first `data/`-touching commit, record actual `_comment_chars` and `chars` deltas and re-solve. If the measurement falls short, cut in this order (each is restatement of plan prose, none is a trap): the `forge_hall_door` cell note, the two `requires`-hidden hub-option notes (the same fact twice), the two quest-block notes. The traps that must NOT be cut: the encounter's INTERACT-ONLY note, the combatant's distinct-id / `ai:caster` note, the `once_per_waking`-books-per-entity note, and the `(leg index − 1)` note.
- **Merge-train rule:** `comment_census.py --check` is re-run on the MERGED tree at every train merge, not just on this branch. A green run here is not a green run after merge. Any final overshoot is owned by the wave-close PR, not this lane — but design to the 112 constant so it never arises.
- Long rationale goes into QA-script `_comment`s and `docs/CHOICE-LOG.md`, both census-exempt. Prefer ONE trap comment at the seam over per-entity prose. Re-measure after each data commit rather than at PR time.

### Sanctioned shapes only

- Gate families `door_when` / `contains_when` / `portal_menu_when` / `fence_menu_when` MUST wrap their counters in `"requires"`. A bare counter dict is VACUOUSLY TRUE and `VACUOUS_GATE_ALLOWLIST` is EMPTY BY DESIGN (`scripts/data_lint.py:50-53, :221-239`).
- Dialogue `requires` / `hide_when` accept only the whitelisted single keys (`skill`, `class`, `accomplishment`, `board_accepted`, `delivery_accepted`, `gold`, `once_per_waking`, `item`, `race`, `phase`) and exactly six two-key compounds. `hide_when` may NEVER carry `once_per_waking`.
- A `requires` accomplishment dict is **AND** over its keys. `hide_when` is likewise AND-semantics — it hides only when EVERY listed counter is met. There is no OR in a gate; author separate options instead.
- **Every effect dict carries exactly ONE verb.** The runtime applier is an `elif` chain (`src/core/wi_game.gd:1071-1131`), so a two-key dict silently drops one AND CONTENT_FAILs. Author `[{...},{...}]`.
- `start_combat` is legal ONLY on an option that also carries `end: true`.
- Every node needs BOTH `speaker` and `text`; a `text_variants`-only node is a guaranteed SCRIPT ERROR.
- Softlock guard: any node carrying a `hide_when` option OR an accomplishment-`requires` option must keep ≥1 option with NEITHER key.
- `present_when` is FORBIDDEN on `kind: encounter` — use `encounter_when` (`phase` / `requires` / `absent` only).
- Every `kind: encounter` entity must carry `arena`, `enemies`, `allies` AND `on_victory` explicitly. `"allies": []` is mandatory when there is no ally.
- Every non-pc combatant row must carry a POSITIVE `power_level`.

### Counter freeze discipline

Counters named in the spec ARE the freeze names, written correctly at FIRST write. `data/shipped_ids.json` is release-cut-only (`RELEASE = "0.15.0"`) — **never regenerate it in this lane**. Every counter this lane adds is data-derived (dialogue effects, `on_interact_accomplishment`, `on_skill_use.accomplishment`, `on_victory`, `talk_pool` → `chatted_with_<entity_id>`), so **zero hand-adds to `STRUCTURAL_LITERALS`** are needed; the release-time regen picks them all up. Verify this claim at Task 8.2 rather than assuming it.

**This lane's freeze list (22 counters):**

| Counter | Producer | Source |
| --- | --- | --- |
| `saw_the_failed_temper` | prop `forge_reject_bin` (pallass_forge) | lane-invented hook |
| `standards_commission_taken` | dialogue `pallass_forge_smith` | lane-invented quest-start marker |
| `read_the_examination_standard` | prop `forge_hall_standard_notice` | lane-invented |
| `temper_run` | prop `forge_hall_temper_bench` `on_skill_use` | **spec line 109** |
| `standards_brokered` | dialogue `pallass_forge_smith` | **spec line 111** |
| `golem_recalibrated` | encounter `forge_temper_golem` `on_victory` | **spec line 114** |
| `standards_tempered` | dialogue `pallass_forge_smith` | **spec line 115** |
| `read_the_lift_manifest` | prop `lift_manifest_slate` (pallass_forge) | lane-invented hook |
| `ledger_loop_started` | dialogue `pallass_lift_attendant` | lane-invented quest-start marker |
| `queue_notice_endorsed` | dialogue `pallass_market_clerk` | lane-invented (loop office 1) |
| `queue_notice_countersigned` | dialogue `pallass_forge_clerk` | lane-invented (loop office 2) |
| `loop_walked` | dialogue `pallass_den_keeper` (graph file; entity is `den_shop_keeper`) | **spec line 126** |
| `exemption_found` | prop `den_shop_consignment_file` `on_skill_use` | **spec line 128** |
| `shipment_leg_carried` | three `once_per_waking` carry props | lane-invented (HELP staging) |
| `shipment_carried` | dialogue `pallass_den_keeper` (graph file; entity is `den_shop_keeper`) | **spec line 130** |
| `ledger_unstuck` | dialogue `pallass_lift_attendant` | **spec line 131** |
| `eyed_the_slack_tub` | prop (forge hall observable) | lane-invented |
| `read_the_apprentice_slate` | prop (forge hall observable) | lane-invented |
| `eyed_the_pattern_wall` | prop (forge hall observable) | lane-invented |
| `eyed_the_den_spice_shelf` | prop (den shop observable) | lane-invented |
| `heard_the_den_hatchlings` | prop (den shop observable) | lane-invented |
| `read_the_den_family_slate` | prop (den shop observable) | lane-invented |

Plus two id-derived socials the engine builds from the ENTITY id, never the graph filename (`src/core/social.gd:26` `var counter_key := "chatted_with_%s" % id` where `id = String(target[WIKeys.ID])`; the release-time regen uses the same rule at `scripts/generate_shipped_ids.py:151`): **`chatted_with_forge_apprentice`** (entity `forge_apprentice`) and **`chatted_with_den_shop_keeper`** (entity `den_shop_keeper` — NOT `chatted_with_den_keeper`; `pallass_den_keeper` is only the graph FILE name, and every shipped social matches its entity id exactly: `chatted_with_lift_attendant`, `chatted_with_ksmvr_dig_camp`, `chatted_with_riverfarm_charmed_villager`).

Anything downstream that keys on it — a future `leads.json` row, a QA `accomplishment_recorded` pin, a `talk_pool_stages` gate — MUST use `chatted_with_den_shop_keeper`. A `requires` on a counter that no producer derives is permanently unmet, and `assert_state` on a missing path ERRORS rather than failing loud.

### Controller rulings (binding — each is logged to `docs/CHOICE-LOG.md` at Task 8.1)

1. **Interior map stems are `pallass_forge_hall` and `pallass_den_shop`.** The spec's `pallass/forge_hall.json` would give map key `forge_hall`, which is already the ARENA id in `data/arenas.json:2104` that the shipped `forge_calibration_golem` entity fights in. Namespaces are separate so nothing breaks mechanically, but `board_renderer.gd:445-448` resolves mood by arena id first then falls back to `moods[map_id]`, and `data_lint.py:73-80` keys maps by file stem globally. Deviation from the spec filename, logged.
2. **P1 FIGHT banks `golem_recalibrated` ONLY.** It must NOT bank `forge_golems_culled` — `data/bounties.json:357` `bounty_forge_golem_cull` completes on `forge_golems_culled >= 2`, so banking it would silently feed a repeatable Guild bounty. New encounter entity with its own id; new combatant id `forge_temper_golem` (roster-only convention: a distinct id IS the override; there is no per-encounter stat override). **The encounter is INTERACT-ONLY — it carries `conversation` and therefore must never carry `trigger_radius`** (see Task 1.4). Its band claim — measured strictly below the shipped forge golem at the same build — is carried by medians recorded in the PR body under wave ruling A, not by a narrow gate window; `forge_calibration_golem_t4_solo` must stay in its own measured window.
3. **P1's FIGHT closes the standing "no QA script fights forge-hall content" debt** (HANDOFF.md:86, docs/VISUAL-LOG.md:449-451). Its canonical must fight on the board for real and screenshot it — windowed list entry, not a headless-only proof.
4. **Grimalkin gets `text_variants` ONLY — never a new hub option.** Three QA scripts pin his hub option array (`grimalkin_study_loop.json` lines 22/39/55) and `pallass_peek.json:120` does index navigation on it.
5. **Every new hub option is gated on a counter its crossing fixtures do not hold.** `pallass_walkthrough` (fixture `near_pallass`) pins the attendant hub at 3 rows (script line ~1152) and the smith hub at 3 rows (line ~1258), and drives both with literal `move down N`. Explicit fixture ledger in Task 2.4.
6. **P2 fixtures derive from `spine_reach_start.json`** — the only shipped fixture holding `door_awakened` + `pallass_attuned` + `elevator_pass_stamped` together. Any fixture standing inside a new interior needs its `MAP_REQUIRES` row.
7. **P2 HELP lift staging is composed ONLY from existing primitives**: `once_per_waking` carry props + `variants` counter thresholds + repeated `door_when` transitions. The Grand Lift is a plain prop pair with one boolean gate (`src/core/interactions.gd:94-100`) — there is no staged/partial transit and none will be added.
8. **Post-quest reactive stages key on `standards_tempered` / `ledger_unstuck` ONLY** — never on `elevator_pass_stamped` or any counter implied by simply standing on the forge tier (the b7 shadow-out adjudication, `docs/CHOICE-LOG.md:349-361`: that gate is structurally always-met up there, so a stage keyed to it permanently shadows the base pool).
9. **Placement space is x1..x24 / y3..y8 minus occupied**, on both 26×11 tiers. Nothing on the perimeter lap rows/columns (`x=0`, `x=25`, `y=2`, `y=9`) that `pallass_peek` walks in full, and nothing on the `y=9` lane `pallass_walkthrough` and `pallass_round_trip` both traverse end to end.
10. **Do not fix AGENTS.md's stale (4,7) Pallass portal note in this lane** (close-PR hygiene). Just don't trust it — the live arrival is **(4,8)** (`data/portals.json:56-59`, rationale at `docs/CHOICE-LOG.md:407`).

### Commit / PR discipline

- Every commit message ends with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- The PR head commit message contains `[ci-full]` (the heavy `sweep` and `web-parity` jobs otherwise skip plain pushes; they always run on PRs, but the tag makes the head's own push run them too).
- PR body follows `.github/PULL_REQUEST_TEMPLATE/issue-close.md`: `Closes #307`, `## Choices made`, `## Validation evidence` (command + one-line result per gate), `## Player-visible proof`, `## New agent context`, `## Deferred / follow-ups`.

---

## FILE OWNERSHIP

### Exclusive to this lane (safe to own outright)

- `wandering_inn_game/data/maps/pallass/pallass_forge.json` — MODIFY
- `wandering_inn_game/data/maps/pallass/pallass_market.json` — MODIFY
- `wandering_inn_game/data/maps/pallass/pallass_forge_hall.json` — NEW
- `wandering_inn_game/data/maps/pallass/pallass_den_shop.json` — NEW
- `wandering_inn_game/data/dialogue/pallass_forge_smith.json` — MODIFY
- `wandering_inn_game/data/dialogue/pallass_lift_attendant.json` — MODIFY
- `wandering_inn_game/data/dialogue/pallass_market_clerk.json` — MODIFY
- `wandering_inn_game/data/dialogue/pallass_forge_clerk.json` — MODIFY
- `wandering_inn_game/data/dialogue/pallass_grimalkin.json` — MODIFY (text_variants only)
- `wandering_inn_game/data/dialogue/pallass_den_keeper.json` — NEW
- `wandering_inn_game/data/dialogue/forge_temper_golem.json` — NEW
- `wandering_inn_game/qa/scripts/pallass_*.json` (7 new) — NEW
- `wandering_inn_game/qa/fixtures/pallass_*.json` (6 new) — NEW

### SHARED — merge-train resolves

**Controller ruling C — named anchors, not "append at EOF".** Four lanes appending after the same final row is a designed-in four-way conflict on one line. Every shared append in this lane lands **immediately after a named row this lane does not share with another lane**. The anchor row is stated per file below and is binding: do not append at the end of the container unless the anchor IS the last row.

| File | This lane's edit | Anchor / discipline |
| --- | --- | --- |
| `data/quests.json` | 2 quest objects | Anchor: **immediately after the `price_of_a_favor` quest object** (Liscor's; no other lane touches it). TAB-indented; use `scripts/splice_json.py --container quests` |
| `data/combatants.json` | 1 row (`forge_temper_golem`) | Anchor: **immediately after the shipped `forge_golem` row** (the rig this one retints; no other lane touches it). 1-SPACE-per-level indent; use `splice_json.py --container combatants` |
| `data/arenas.json` | **none** — reuses shipped `forge_hall` | no edit, by design (ruling 3) |
| `data/moods.json` | 2 rows (`pallass_forge_hall`, `pallass_den_shop`) | Anchor: **insert after the `pallass_forge` key**. (Ruling C splits the four lanes: Floodplains after `floodplains`, Riverfarm after `witch_hollow`, Invrisil after `brothers_parlor`, Pallass after `pallass_forge`. `pallass_forge` is today's LAST key, so this lane is the only one that touches the closing brace.) |
| `data/leads.json` | **none in this PR** — see DEFERRED TO CLOSE PR | gating counters not yet frozen |
| `qa/manifest.json` | 7 entries in `scripts[]` | Anchor: **immediately after the `pallass_walkthrough` entry** (Pallass-owned; no other lane touches it). `surfaces` is GENERATED — never hand-edited |
| `wandering_inn_game/AGENTS.md` | 7 seed-table rows (table starts :201) | Anchor: **immediately after the `pallass_walkthrough` seed row**, matching the manifest order. `ci_sweep.sh` hard-fails on manifest/table drift |
| `tests/test_content.gd` | `LANDMARK_TOKENS` +2 rows (:1332-1363) | Anchor: **after the `pallass_forge` row** inside the const |
| `tests/test_content.gd` | `POPULATION_FLOORS` (:532-541) | **no change** — this lane only ADDS unconditional interactables |
| `tests/test_quests.gd` | co-bank ladder pins for the 2 new quests | Anchor: after the `price_of_a_favor` block. **Locals take this lane's `p_` prefix** — see the local-name rule below |
| `tests/sim_combat_batch.gd` | 1 gated cell appended to `BESTIARY_CELLS` | Anchor: **immediately after the `forge_calibration_golem_t5_sw14_solo` cell**. `total_cells` at :321 is `.size()`-derived — **VERIFIED: no manual update needed** |
| `tests/test_fixture_coherence.gd` | `MAP_REQUIRES` +2 rows (:31-53) | Anchor: **after the `pallass_forge` row** |
| `docs/design/character-profiles.md` | **FILL the two pre-landed stub sections IN PLACE** | See ruling D below |
| `docs/CHOICE-LOG.md` | ruling + fork entries | append |
| `docs/VISUAL-LOG.md` | drain the forge_hall board-screenshot item | edit the filed line |

**Controller ruling C — new test-file locals carry this lane's `p_` prefix.** `tests/test_quests.gd:90-132` is ONE continuous function body at a single indent level (`var halls` :90, `var door` :103, `var crate` :113, `var order` :123, `var favor` :129) — all co-bank pins share one scope, so a second `var ledger` from another lane is a duplicate DECLARATION, not a shadow, and GDScript refuses to parse the file the moment the second lane merges. This lane's locals are **`p_tempered`** and **`p_ledger`** (and `p_`-prefixed for anything added later). Riverfarm takes `r_`, Invrisil `i_`, Floodplains `f_`.

**Controller ruling D — `docs/design/character-profiles.md` is SHARED, not exclusive to any lane.** The controller pre-lands stub section headers in the plan commit; each lane **FILLS ITS OWN STUB SECTION IN PLACE and NEVER appends at EOF**. Verified present at plan time: `## Forge Hall Apprentice (v0.16 #307 STUB …)` at :516 and `## Den-Shop Keeper (v0.16 #307 STUB …)` at :521, with Invrisil's `## Hedault` stub at :525 after them. Replacing the stub body inside this lane's own two sections cannot conflict with Invrisil's edit to its own section. Any earlier language calling this file exclusive to one lane is superseded. `docs/` is census-exempt.

### NEVER

- **Never regenerate `data/shipped_ids.json`** — tag-time only, `RELEASE = "0.15.0"`.
- **Never hand-edit `qa/manifest.json`'s `surfaces` block** — `wandering_inn_game/scripts/derive_qa_surfaces.py` owns it; `--check` is FATAL on drift and `ci_sweep.sh` runs it every invocation.
- **Never hand-edit `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`** — `python3 scripts/render_qa_notes.py --write` generates it from the manifest; a forgotten regen after ANY manifest or QA-script `_comment` change reds leak-check (the #312 CI red). **Controller ruling E: the bare invocation does NOT write.** `scripts/render_qa_notes.py:55-66` only writes under `--write`; bare it compares, prints `QA NOTES DRIFT` and returns 1. So every regeneration in this plan is **`python3 scripts/render_qa_notes.py --write`, followed by a bare `python3 scripts/render_qa_notes.py` as the check** (rc=0 + `PASS: QA notes match manifest`). (`derive_qa_surfaces.py` is the opposite — a bare run IS the write, `scripts/derive_qa_surfaces.py:412-414`; leave those calls bare.) **Merge-train note:** `render()` walks the WHOLE manifest, so the file must be re-rendered at EVERY train merge that combines two lanes' manifest entries — a per-lane regen is necessary and not sufficient.
- **Never round-trip shipped JSON through `json.dump`** — `ensure_ascii=True` rewrites every literal em-dash. Hand-edit matching the file's own indent, or use `scripts/splice_json.py`.

---

## Task 0 — Preflight

### Task 0.1: Voice blocks for the two new characters

**Files:** Modify `docs/design/character-profiles.md` (census-exempt, **SHARED across all four lanes** — ruling D)

**Ruling D restated:** the controller pre-landed this lane's two stub section headers at the plan commit (`## Forge Hall Apprentice (v0.16 #307 STUB …)` :516, `## Den-Shop Keeper (v0.16 #307 STUB …)` :521), with Invrisil's `## Hedault` stub after them at :525. **Fill the two stub sections IN PLACE — never append at EOF.** Appending at EOF lands in the same region Invrisil's Hedault block targets and produces a conflict the anchors exist to prevent.

- [x] **Step 1:** Read the existing "Forge-Tier Smith" (:482) and "Grand Lift Attendant" (:501) blocks — match their format exactly. Then locate this lane's two STUB headers (:516, :521) and confirm the Hedault stub sits after them.
- [x] **Step 2:** **Replace the `## Forge Hall Apprentice` stub header and body in place** (drop the STUB parenthetical, keep the section where it sits) — entity `forge_apprentice`, original character: young Drake, third year, competent hands and no vocabulary for what she does right; describes failures precisely and successes vaguely; never self-pitying, never cocky; the standard is a fact to her, not an insult.
- [x] **Step 3:** **Replace the `## Den-Shop Keeper` stub header and body in place** — entity `den_shop_keeper`, original character: market-tier Drake matriarch running a family provisions den; warm where the tier is cold, but her warmth is transactional-plus — she feeds you AND charges you and sees no tension in it; hatchlings underfoot; her ledger is neat because it has to be, not because she loves it. Name the derived social counter in the block: **`chatted_with_den_shop_keeper`**.
- [x] **Step 3b:** `git diff --stat docs/design/character-profiles.md` — the diff must touch ONLY lines inside this lane's two sections. Any hunk at or past the Hedault header means the edit appended instead of filling.
- [x] **Step 4:** Commit `docs(profiles): forge hall apprentice + den-shop keeper voice blocks`.

### Task 0.2: Baseline the census and the gates

- [x] **Step 1:** `cd /Users/gabriel/wandering-inn-rpg && python3 scripts/comment_census.py --check` — record the exact DATA ratio and char counts as the lane's baseline in the PR body.
- [x] **Step 2:** `python3 wandering_inn_game/scripts/data_lint.py` — record green.
- [x] **Step 3:** `perl -e 'alarm 300; exec @ARGV' -- /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_content.gd` — record green (this is the "was it already red?" control).

---

## Task 1 — P1 "Tempered Standards": quest + forge hall interior

### Task 1.1: `pallass_forge_hall` interior map

**Files:**
- Create: `wandering_inn_game/data/maps/pallass/pallass_forge_hall.json`
- Modify: `wandering_inn_game/data/moods.json`
- Modify: `wandering_inn_game/tests/test_content.gd` (`LANDMARK_TOKENS`)
- Modify: `wandering_inn_game/tests/test_fixture_coherence.gd` (`MAP_REQUIRES`)

**Interfaces:**
- Produces: map key `pallass_forge_hall`; counters `read_the_examination_standard`, `temper_run`, `eyed_the_slack_tub`, `read_the_apprentice_slate`, `eyed_the_pattern_wall`, `chatted_with_forge_apprentice`.
- Consumes: nothing. Task 1.2 hangs the door on `pallass_forge`; Task 1.4 adds the encounter entity to this map.

**Full layout spec (12×9 — under the 14×10 parlor yardstick):**

```
grid: 12 x 9        biome: pallass_forge (existing; footstep stone, blocked_props [forge_station, crate])
walls.segments (sheet res://assets/tiles/pallass/tileset_slate_over_void_atlas.png, tile_px 16).
  EVERY segment PINS "face": [0, 0] — the value both shipped users of this atlas set
  (data/maps/pallass/pallass_forge.json and pallass_market.json are each
  {"from":[0,0],"to":[25,1],"face":[0,0]}). This is NOT optional decoration:
  tile_board_builder.gd:194-202 reads seg.get("face", null) / seg.get("cap", null) and
  DERIVES cap := face when cap is absent — with face absent too there is no authored tile
  at all and the run has nothing to draw. `cap` is left absent on purpose so it derives
  from face, exactly as both shipped Pallass tiers do.
   {"from": [0,0],  "to": [11,0], "face": [0,0]}      (north band)
   {"from": [0,1],  "to": [0,8],  "face": [0,0]}      (west)
   {"from": [11,1], "to": [11,8], "face": [0,0]}      (east)
   {"from": [1,8],  "to": [4,8],  "face": [0,0]}  and
   {"from": [6,8],  "to": [10,8], "face": [0,0]}      (south, leaving (5,8) for the exit door)
walkable floor: x=1..10, y=1..7, plus the door cell (5,8)
blocked (5 cells, each covered by authored decor -- the riverfarm_longhouse contract):
   [2,2] forge_station      [3,2] forge_station
   [2,4] barrel  (quench trough)
   [9,2] crate   (slag stack)
   [9,5] library_shelf (stock rack)
ambience: [{ "preset": "embers", "rect": [2, 2, 3, 2] }]
```

Wall segments auto-block — **never** double-list a segment cell in `blocked`. Every non-segment blocked cell above carries authored decor so `test_world_visuals._shipped_blocked_prop_contract_holds` sees `authored_covered` and does not demand a pool prop.

The wall SHEET is deliberately the slate atlas the two Pallass tiers already use, not the `pallass_forge` biome's own `tileset_brick_over_molten_atlas.png` (`data/biomes.json`): the hall reads as an interior cut into the same civic stone as the landing outside it, and reusing a sheet with a known-good `face` coordinate makes the windowed pass a CHECK rather than a discovery. If the windowed pass says the hall reads too cold against the embers ambience, the fallback is the molten atlas — but then its `face` must be pinned too, from a shipped user, before the swap.

**Entities (7):**

| id | kind | cell | surface |
| --- | --- | --- | --- |
| `forge_hall_exit` | door | [5,8] | → `pallass_forge` (15,4) |
| `forge_hall_temper_bench` | prop | [4,3] | SKILL route, `requires_skill: appraise_goods` |
| `forge_hall_standard_notice` | prop | [7,2] | banks `read_the_examination_standard` |
| `forge_apprentice` | npc | [5,4] | `talk_pool` (4 lines) |
| `forge_hall_slack_tub` | prop | [3,5] | observable |
| `forge_hall_apprentice_slate` | prop | [6,5] | observable |
| `forge_hall_pattern_wall` | prop | [10,3] | observable |

(Task 1.4 appends the `forge_temper_golem` encounter entity at [8,6].)

**Arrival cells, hand-verified both directions:**
- OUT→IN: player stands `pallass_forge` **(15,4)** — free (forge y4 occupies only x∈{9,17,18}), off every canonically asserted cell, off the lap rows/columns, off the `y=9` lane, off the molten seam (y=5, x13–17) — faces **up** to the door at (15,3), interacts, arrives `pallass_forge_hall` **(5,7)**: unblocked (walkable band y=1..7), unoccupied by any entity, directly north of the exit door.
- IN→OUT: from (5,7) faces **down** to `forge_hall_exit` at (5,8), interacts, arrives `pallass_forge` **(15,4)** — the same cell the player left from (the `longhouse_exit` / `parlor_to_alleys` offset convention).
- Save-compat: the new door entity at `pallass_forge` (15,3) blocks a previously-walkable cell. All four of its neighbours — (14,3), (16,3), (15,2), (15,4) — are free, so a prior-version save standing there is never trapped.

**Exact JSON drafts — entities:**

```json
{
 "id": "forge_hall_exit",
 "kind": "door",
 "cell": [5, 8],
 "display_name": "Back to the Tier",
 "sprite": "door",
 "to_map": "pallass_forge",
 "to_cell": [15, 4],
 "observe": "The hall door, propped with a wedge nobody has ever removed. Past it, the tier's noise resumes."
}
```

```json
{
 "_comment": "P1 SKILL route. requires_skill renders VISIBLE-LOCKED: a player without the arm still sees the route and takes TALK or FIGHT.",
 "id": "forge_hall_temper_bench",
 "kind": "prop",
 "cell": [4, 3],
 "display_name": "The Temper Bench",
 "sprite": "forge_station",
 "observe": "A billet clamped mid-process, the quench beside it, a gauge nobody has reset since the last failure. Somebody stopped here on purpose and did not come back.",
 "requires_skill": "appraise_goods",
 "skill_hint_toast": "Colour, count, quench. You can see there is an order to it. You cannot see the order.",
 "locked_toast": "Heat, metal, and a gauge you cannot read. Guessing here costs somebody a week.",
 "on_skill_use": {
  "accomplishment": "temper_run",
  "toast": "[Appraise Goods] — You read the grain off the colour, hold the count two beats longer than the slate says, and quench. The billet comes out with the standard's own answer in it."
 }
}
```

```json
{
 "id": "forge_hall_standard_notice",
 "kind": "prop",
 "cell": [7, 2],
 "display_name": "The Examination Standard",
 "sprite": "price_board",
 "observe": "A civic notice pinned at eye height, examiner's seal at the corner, the text underneath it read so often the ink has gone grey where thumbs land.",
 "on_interact_accomplishment": "read_the_examination_standard",
 "toast": "The standard does not measure how hard a blade comes out. It measures how it RECOVERS. Somebody up here has been failing the wrong test perfectly."
}
```

```json
{
 "id": "forge_apprentice",
 "kind": "npc",
 "cell": [5, 4],
 "display_name": "Forge Hall Apprentice",
 "sprite": "drake_patron",
 "tint": [0.52, 0.58, 0.66],
 "facing": "up",
 "observe": "A young Drake with her sleeves pinned back and a scorch on one forearm she has not stopped working long enough to notice.",
 "friendly_line": "She looks up for exactly as long as the count allows, then back down. From an apprentice on the clock, that is a warm welcome.",
 "talk_pool": [
  "Third year. Third year is when they stop telling you what you did wrong and start writing it down.",
  "I can make it hard. Anyone can make it hard. Making it come back is the part.",
  "Mind the tub, {addr}. It looks still until it isn't.",
  "The smith says the bench is hers till second bell. She also says that at third bell."
 ]
}
```

```json
{
 "id": "forge_hall_slack_tub",
 "kind": "prop",
 "cell": [3, 5],
 "display_name": "The Slack Tub",
 "sprite": "barrel",
 "observe": "Water gone grey with scale, a skin of oil across the top, and a scum line three fingers above the current level.",
 "on_interact_accomplishment": "eyed_the_slack_tub",
 "toast": "You touch the surface. Warm all the way down. This tub has not been cold in years, and the scum line says nobody has ever had time to change it."
}
```

```json
{
 "id": "forge_hall_apprentice_slate",
 "kind": "prop",
 "cell": [6, 5],
 "display_name": "The Practice Slate",
 "sprite": "inn_room_ledger",
 "observe": "A slate ruled into columns: heat, count, quench, result. The result column is chalked over so many times the surface has gone soft.",
 "on_interact_accomplishment": "read_the_apprentice_slate",
 "toast": "Forty-one attempts. Under the last one, in smaller writing than the rest: TRY THE OTHER WAY ROUND."
}
```

```json
{
 "id": "forge_hall_pattern_wall",
 "kind": "prop",
 "cell": [10, 3],
 "display_name": "The Pattern Wall",
 "sprite": "library_shelf",
 "observe": "Finished pieces racked in a grid, each with a civic tag wired to it. They are not for sale. They are the argument.",
 "on_interact_accomplishment": "eyed_the_pattern_wall",
 "toast": "Every piece on the wall passed. You count the tags: four different smiths, four different answers, one standard. Pallass framed the disagreement and hung it up."
}
```

**Mood row for `data/moods.json`:**

```json
"pallass_forge_hall": { "day": [1.06, 0.82, 0.64], "dusk": [1.06, 0.82, 0.64], "night": [1.02, 0.78, 0.60], "vignette": 0.48 }
```

(No test enforces a mood row — a missing one renders flat white at every phase via `src/world/atmosphere.gd:90-91`. This is a visual defect that would ship green, which is why it is a checkbox here.)

**`LANDMARK_TOKENS` row for `tests/test_content.gd`:**

```gdscript
	"pallass_forge_hall": ["forge hall", "forge tier"],
```

**`MAP_REQUIRES` row for `tests/test_fixture_coherence.gd`:**

```gdscript
	"pallass_forge_hall": ["door_awakened", "pallass_attuned", "elevator_pass_stamped"],
```

- [x] **Step 1: Load `wi-adding-a-scene`.** Read `data/maps/riverfarm/riverfarm_longhouse.json` end to end first — it is the small-interior template this file copies (walls/floor_layers/decor/ambience/entities order).
- [x] **Step 2:** Write `pallass_forge_hall.json` per the layout spec above. Floor layers: reuse the `pallass_forge` biome default (no override needed); add ONE overlay only if the windowed pass says the room reads flat.
- [x] **Step 3:** Append the mood row, the `LANDMARK_TOKENS` row, the `MAP_REQUIRES` row.
- [x] **Step 4: Run** `python3 wandering_inn_game/scripts/data_lint.py` — expect green (grid, in-grid blocked/entity cells).
- [x] **Step 5: Run** `res://tests/test_content.gd` and `res://tests/test_world_visuals.gd` alarm-wrapped — expect PASS + zero noise. `_validate_props` will red any `on_interact_accomplishment` prop missing a `toast`; `_validate_npc_interact_surface` will red an empty `talk_pool`.
- [x] **Step 6: Advisory (not a gate):** `godot --headless --path wandering_inn_game --script res://tools/scene_dynamism.gd` — new scenes target composite ≥50; under 30 prints a loud advisory. Record the number in the PR body.
- [x] **Step 7: Census check** `python3 scripts/comment_census.py --check`.
- [x] **Step 8: Commit** `feat(pallass): the forge hall interior (walk-in, observables, temper bench)`.

### Task 1.2: `pallass_forge` hooks — reject bin + hall door

**Files:** Modify `wandering_inn_game/data/maps/pallass/pallass_forge.json`

**Interfaces:**
- Produces: counter `saw_the_failed_temper` (gates the smith's new hub option, Task 1.3); the walk-in door to `pallass_forge_hall`.

**Cell justification (ruling 9 + the crowded-cell evidence):**

| new entity | cell | why this cell |
| --- | --- | --- |
| `forge_hall_door` | **[15,3]** | forge y3 occupies only x=2. Not in the 22-cell canonical-assert set for this map. Off the perimeter lap (`x=0/25`, `y=2/9`). Off the `y=9` lane. North of, and clear of, the molten seam (`y=5`, x13–17). Approach (15,4) free. Recon's own candidate. |
| `forge_reject_bin` | **[10,4]** | forge y4 occupies x∈{9,17,18}. (10,7) is canonically asserted; (10,4) is not. Sits one row-block north of the smith at (11,6), which is the fiction. Off laps and the y=9 lane. |

Neither cell is walked by `pallass_walkthrough` (its forge legs are the `y=9` lane, column 7 up to (7,6), column 11 up to (11,7), column 12), by `pallass_round_trip` (row 9 both tiers), by `regional_work_loop` (teleports to (18,5), bumps north to (18,4)), or by `pallass_peek`'s bounds laps.

```json
{
 "_comment": "v0.16 P1. Cell (15,3) is off every QA lap and assert set, and all four neighbours are open, so no prior save loading here is trapped by the new blocking entity. Full cell audit: the plan's Task 1.2 table.",
 "id": "forge_hall_door",
 "kind": "door",
 "cell": [15, 3],
 "display_name": "The Forge Hall",
 "sprite": "door",
 "to_map": "pallass_forge_hall",
 "to_cell": [5, 7],
 "observe": "A wide iron-strapped door standing open on its wedge. Past it: a working hall, and a heat that has its own weather."
}
```

```json
{
 "id": "forge_reject_bin",
 "kind": "prop",
 "cell": [10, 4],
 "display_name": "The Reject Bin",
 "sprite": "crate",
 "observe": "A civic bin beside the second bench, half full of work that never left the tier. Each piece has a tag, and every tag has the same examiner's seal on it.",
 "on_interact_accomplishment": "saw_the_failed_temper",
 "toast": "Nine blades in the bin, all from one hand, all failed on the same measure. Somebody up here is doing careful work and failing it the same way every time."
}
```

- [x] **Step 1:** Insert both entities into `pallass_forge.json`'s `entities` array, matching the file's 1-space-per-level indent. Do NOT reformat the file.
- [x] **Step 2:** Confirm `POPULATION_FLOORS["pallass_forge"] = 15` still holds — both entities are UNCONDITIONAL (no `present_when`), so the count RISES. No floor edit.
- [x] **Step 3: Run** `data_lint.py` + `res://tests/test_content.gd`.
- [x] **Step 4: Run** `wandering_inn_game/qa/ci_sweep.sh --touching data/maps/pallass/pallass_forge.json` — expect every listed script green (this is the crowded-cell proof).
- [x] **Step 5: Commit** `feat(pallass): the forge hall door and the reject bin that points at it`.

### Task 1.3: The smith's commission — `pallass_forge_smith.json`

**Files:** Modify `wandering_inn_game/data/dialogue/pallass_forge_smith.json`

**Interfaces:**
- Consumes: `saw_the_failed_temper` (1.2), `read_the_examination_standard` / `temper_run` (1.1), `golem_recalibrated` (1.4), quest id `tempered_standards` (1.5).
- Produces: `standards_commission_taken`, `standards_brokered`, `standards_tempered`.

**Gating ledger (ruling 5) — which fixture holds what:**

| crossing script | fixture | holds `saw_the_failed_temper`? | holds `standards_commission_taken`? | hub rows it sees |
| --- | --- | --- | --- | --- |
| `pallass_walkthrough` | `near_pallass` (banks the whole permit chain LIVE; never interacts `forge_reject_bin`) | **no** | **no** | **3** (unchanged pin at line ~1258) |
| every other Pallass canonical | — | no | no | n/a (none opens this graph) |

Both new options are `requires`-accomplishment gated, therefore HIDDEN (not visible-locked) until met. The hub's option array is unchanged in every shipped fixture state.

**Two new hub options** (append to the END of the existing `options` array, after `"I'll let you work."` — appending after the always-available exit keeps the exit row's index stable at 3 for the shipped 3-row state):

```json
{
 "_comment": "v0.16 P1 start. requires-hidden on saw_the_failed_temper (banked only by forge_reject_bin, which near_pallass never interacts), so pallass_walkthrough's 3-row hub pin and its index navigation are untouched.",
 "text": "Nine blades in your reject bin, all failed the same way.",
 "requires": { "accomplishment": { "saw_the_failed_temper": 1 } },
 "hide_when": { "accomplishment": { "standards_commission_taken": 1 } },
 "goto": "commission"
},
{
 "text": "About your commission.",
 "requires": { "accomplishment": { "standards_commission_taken": 1 } },
 "hide_when": { "accomplishment": { "standards_tempered": 1 } },
 "goto": "commission_report"
}
```

**Five new nodes:**

```json
"commission": {
 "speaker": "Forge-Tier Smith",
 "text": "You counted them. Good. My apprentice's hand is the steadiest on this tier and the examiner has failed her nine times running. One of us is wrong and it is not her.",
 "options": [
  {
   "text": "I'll take the commission.",
   "effects": [
    { "quest": "tempered_standards" },
    { "accomplishment": "standards_commission_taken" }
   ],
   "goto": "commission_brief"
  },
  { "text": "That sounds like your argument, not mine.", "end": true }
 ]
},
"commission_brief": {
 "speaker": "Forge-Tier Smith",
 "text": "Hall's through the door past the second bench. Run the temper yourself if you have the eye for it, or read the examiner's own notice on my wall and come tell me what it says. Watch the calibration rig either way. It has been drifting.",
 "options": [
  { "text": "I'll look at the hall.", "end": true },
  { "text": "Drifting how?", "goto": "commission_drift" }
 ]
},
"commission_drift": {
 "speaker": "Forge-Tier Smith",
 "text": "It walks its own tolerance and corrects late. On a slab that is a scratch. On a person it is a season. Do not stand where it corrects.",
 "options": [
  { "text": "Understood.", "end": true }
 ]
},
"commission_report": {
 "speaker": "Forge-Tier Smith",
 "text": "Well? Say it in the order it happened.",
 "options": [
  {
   "_comment": "TALK arm. Banks standards_brokered and goes on to the resolution -- brokering is a separate act from reporting it, which is why it does not bank the terminal itself.",
   "text": "[The standard measures recovery, not hardness. His own notice says so.]",
   "requires": { "accomplishment": { "read_the_examination_standard": 1 } },
   "hide_when": { "accomplishment": { "standards_brokered": 1 } },
   "effects": [ { "accomplishment": "standards_brokered" } ],
   "goto": "broker"
  },
  {
   "text": "[Show her the billet you ran.]",
   "requires": { "accomplishment": { "temper_run": 1 } },
   "effects": [ { "accomplishment": "standards_tempered" } ],
   "goto": "commission_settled"
  },
  {
   "text": "[Tell her what happened to the calibration rig.]",
   "requires": { "accomplishment": { "golem_recalibrated": 1 } },
   "effects": [ { "accomplishment": "standards_tempered" } ],
   "goto": "commission_settled"
  },
  {
   "text": "[Tell her the argument is settled.]",
   "requires": { "accomplishment": { "standards_brokered": 1 } },
   "effects": [ { "accomplishment": "standards_tempered" } ],
   "goto": "commission_settled"
  },
  { "text": "Still working on it.", "end": true }
 ]
},
"broker": {
 "speaker": "Forge-Tier Smith",
 "text": "Recovery. He has been failing her for coming back, and she has been chasing hardness because I taught her to. So he is right and I am right and she paid for both. Say the rest of it out loud, because I am not going to.",
 "options": [
  { "text": "Nobody was wrong. That was the whole problem.", "goto": "commission_report" },
  { "text": "She'll pass the next one.", "goto": "commission_report" }
 ]
},
"commission_settled": {
 "speaker": "Forge-Tier Smith",
 "text": "Then it is filed and it is finished. The bench is mine again until second bell.",
 "text_variants": [
  {
   "requires": { "accomplishment": { "golem_recalibrated": 1 } },
   "text": "The rig is honest again and my apprentice gets a fair reading. I will not thank you over a hot hammer. Take it as said."
  },
  {
   "requires": { "accomplishment": { "temper_run": 1 } },
   "text": "You ran it once and it came back. She has run it forty-one times and it came back too. Now the file says so. That is the difference and it should not have been yours to make."
  },
  {
   "requires": { "accomplishment": { "standards_brokered": 1 } },
   "text": "I have been arguing with that man for six years and it turns out we agreed the entire time. Do not repeat that. Especially to him."
  }
 ],
 "options": [
  { "text": "She earned it.", "end": true }
 ]
}
```

Variant order is deliberate: `text_variants` are LAST-MATCH-WINS, so a co-banking player lands on the TALK line — matching the resolution ladder in Task 1.5.

- [x] **Step 1: Load `wi-adding-dialogue-and-quests`.** Read the whole shipped file first; match its 1-space indent.
- [x] **Step 2:** Append the two hub options and the five nodes exactly as drafted.
- [x] **Step 3: Shadow-out audit (mandatory).** The two shipped hub `text_variants` (`forge_golems_culled`, `seal_resolved`) are UNTOUCHED and no new variant is added to `hub` — the smith's greeting is unchanged in every shipped state. Record this in the PR's "New agent context".
- [x] **Step 4: Softlock guard check.** `commission_report` keeps `"Still working on it."` with neither `requires` nor `hide_when`; `commission` keeps the decline. `hub` keeps `"What's the bench rated for?"`.
- [x] **Step 5: Run** `res://tests/test_dialogue.gd` + `res://tests/test_content.gd` + `res://tests/test_copy_fit.gd` — expect PASS. Copy-fit will red any `text` past the 200-char page budget.
- [x] **Step 6: Run** `qa/ci_sweep.sh --only pallass_walkthrough` and confirm the 3-row pin at line ~1258 still passes.
- [x] **Step 7: Census check.**
- [x] **Step 8: Commit** `feat(dialogue): the smith's commission, the broker, and the settle`.

### Task 1.4: The temper golem — combatant, encounter, parley, gated cell

**Files:**
- Modify: `wandering_inn_game/data/combatants.json` (APPEND one row)
- Modify: `wandering_inn_game/data/maps/pallass/pallass_forge_hall.json` (APPEND the encounter entity)
- Create: `wandering_inn_game/data/dialogue/forge_temper_golem.json`
- Modify: `wandering_inn_game/tests/sim_combat_batch.gd` (`BESTIARY_CELLS`)

**Interfaces:**
- Produces: `golem_recalibrated` (and NOTHING else — ruling 2).
- Consumes: `standards_commission_taken` (encounter window).
- Reuses shipped arena `forge_hall` (`data/arenas.json:2104`, 12×8, biome `pallass_forge`) — no new arena row. Reusing it is what lets P1's canonical close the "no QA script fights forge_hall" debt (ruling 3).

**Combatant row (append to `data/combatants.json`, 1-space-per-level indent, via `splice_json.py --container combatants`):**

```json
{
 "_comment": "v0.16 P1 FIGHT. Roster-only retint of forge_golem; a new context takes a NEW ID (:426/:468, no per-encounter override). ai:caster is required: the melee profile never casts flame_bolt. Measured strictly below the shipped forge golem at the same build.",
 "id": "forge_temper_golem",
 "power_level": 16.0,
 "display_name": "Calibration Rig",
 "sprite": "forge_golem",
 "combat_tint": [1.28, 0.74, 0.58],
 "side": "enemy",
 "stats": {
  "str": 17,
  "dex": 7,
  "con": 54,
  "int": 12,
  "wis": 8,
  "cha": 2
 },
 "weapon_die": 8,
 "damage_reduction": 4,
 "ai": "caster",
 "skills": [
  "flame_bolt",
  "power_strike"
 ]
}
```

No `combat_scale`: the rig reuses `forge_golem`'s sprite and scale unchanged.

**New-id figure bar — state this plainly and do not overclaim (controller ruling F).** `test_combat_visuals.gd` does **NOT** measure new ids. `FIGURE_ROWS` (:536-541) holds exactly four entries — `bat`, `briar_collector`, `briar_collector_deep`, `ruin_warden` — and `_board_cells` (:563-566) indexes it by sprite, so `forge_golem` is not measurable there at all; the bar runs only over the fixed `audited` array (:609-611), which contains no id from this lane. **`test_combat_visuals` passes this row BY EXCLUSION, not by measurement.** No id may be added to `audited` without first adding its sprite to `FIGURE_ROWS` with a re-derived row count, which this lane does not do. The legibility read for the rig is therefore the **windowed shots** (Task 4), not a number — and **no unverifiable figure number ships in any `_comment`** here. `combat_tint` rides `spr.modulate` and must settle back after the hit flash — the shipped contract, unchanged, and that IS asserted.

**Gated cell (append to `BESTIARY_CELLS` immediately after `forge_calibration_golem_t5_sw14_solo`, `tests/sim_combat_batch.gd:239-254`):**

**Controller ruling A — every new gated cell this wave uses `win_lo` 0.55 / `win_hi` 0.95, the shipped stop-cell precedent** (`sim_combat_batch.gd:53, :59, :63-64, :70-71, :79-81, :90, :101, :114, :145, :212-213` — the standing wave-scale window). A narrow window is a tuning target masquerading as a gate: it reds on seed noise and it encodes a claim the harness cannot defend. **Region-band ordering is proven by RECORDING MEASURED MEDIANS IN THE PR BODY, not by narrowing the window.**

```gdscript
	# v0.16 P1 (issue #307). Pallass's commission fight. Gated at the standing
	# 0.55-0.95 stop-cell window; the band claim -- measured strictly below the
	# shipped forge golem at the same build -- is carried by the medians
	# recorded in the PR body, not by the window.
	{"name": "forge_temper_golem_t5_sw14_solo", "arena": "forge_hall", "enemies": ["forge_temper_golem"], "build": "t4_spellsword14_party", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
```

`total_cells` (sim_combat_batch.gd:321) is computed from `.size()` on each const array — **verified: appending needs no manual `total_cells` edit.**

**Encounter entity (append to `pallass_forge_hall.json`) — INTERACT-ONLY, no `trigger_radius`:**

**Binding: `trigger_radius` is FORBIDDEN on this entity.** A parley-bearing encounter must be interact-only, because proximity triggering bypasses the conversation entirely:

- `src/core/wi_game.gd:326` calls `_check_trigger_radius()` after every real move; `:341-366` iterates encounters carrying `trigger_radius` and on a hit calls `start_combat(ent_id)` **directly at :365, never consulting `conversation`** (the in-file comment at :324-325 is explicit: "Encounters bypass confirms").
- The `conversation` arm exists ONLY on the INTERACT path (`src/core/interactions.gd:151-160`: `_start_dialogue` first, `_start_combat` as fallback).
- Every shipped encounter respects the split. Of 33 encounter entities across `data/maps/**`, **not one carries both keys**: `forge_calibration_golem`, `market_watchgolems`, `kingslayer_den`, `goblin_encounter_2`, `gallery_vermin_nest` all have `conversation` and NO radius; `seal_warden_alcove`, `boulevard_night_footpads`, `river_wolf_pack`, `goblin_night_patrol` all have a radius and NO conversation.
- Concretely fatal here: with the rig at [8,6] in a 12×9 hall whose walkable band is x=1..10 / y=1..7 and whose arrival cell is (5,7), every cell in (7..9, 5..7) sits inside radius 1. The natural (5,7) → y=7-lane path to the pattern wall at [10,3] crosses (7,7)/(8,7)/(9,7) and would fire the fight — ambushing the SKILL and TALK routes mid-crossing, killing the `pallass_standards_fight` canonical's `rig → parley → start_combat` leg, and making the authored parley graph dead content.

Interact-only is what makes `[Stand out of its correction and leave it.]` reachable and what keeps the SKILL and TALK routes genuinely non-violent — i.e. it is what the three-route parity claim rests on.

```json
{
 "_comment": "P1 FIGHT. INTERACT-ONLY: never add trigger_radius here -- wi_game.gd:365 calls start_combat directly and never reads `conversation`, so the parley dies and the SKILL/TALK routes get ambushed. on_victory is golem_recalibrated ALONE, never forge_golems_culled (that feeds a repeatable bounty). respawns/scales absent: a story fight is one-shot.",
 "id": "forge_temper_golem",
 "kind": "encounter",
 "cell": [8, 6],
 "display_name": "Calibration Rig",
 "sprite": "forge_golem",
 "tint": [1.22, 0.82, 0.68],
 "arena": "forge_hall",
 "conversation": "forge_temper_golem",
 "enemies": [ "forge_temper_golem" ],
 "allies": [],
 "encounter_when": { "requires": { "standards_commission_taken": 1 } },
 "observe": "A squat rig on three legs, gauges banked along its front, correcting its own posture a half-beat after it needs to.",
 "on_victory": "golem_recalibrated"
}
```

**Parley graph `data/dialogue/forge_temper_golem.json`:**

```json
{
 "_comment": "P1 FIGHT entry. forge_calibration_golem.json's decline-or-strike shape minus the talk-down arm: P1's non-violent answers are the bench and the broker, so a third bypass here collapses route parity.",
 "start": "confront",
 "nodes": {
  "confront": {
   "speaker": "Calibration Rig",
   "text": "The rig registers you, corrects a half-beat late, and registers you again. Its gauges swing past their own marks and settle wrong. Whatever schedule it keeps, it stopped keeping it a while ago.",
   "options": [
    {
     "text": "[Bring it back into tolerance the hard way.]",
     "effects": [ { "start_combat": "forge_temper_golem" } ],
     "end": true
    },
    { "text": "[Stand out of its correction and leave it.]", "end": true }
   ]
  }
 }
}
```

> **BINDING TASK-1.3 HANDOFF (deferred FIGHT arm).** `golem_recalibrated` has no producer until this task, and `test_reachability.gd` reds any dialogue `requires`/`text_variants.requires` on a zero-producer counter. So Task 1.3 shipped the smith's graph WITHOUT its two FIGHT-arm blocks. **Restore both in the SAME commit as the encounter**, into `data/dialogue/pallass_forge_smith.json`:
> 1. the `commission_report` option `"[Tell her what happened to the calibration rig.]"` (requires `golem_recalibrated` 1, effect `standards_tempered`, goto `commission_settled`), inserted between the `[Show her the billet you ran.]` and `[Tell her the argument is settled.]` options;
> 2. the `commission_settled` `text_variants` entry gated on `golem_recalibrated` ("The rig is honest again and my apprentice gets a fair reading. I will not thank you over a hot hammer. Take it as said."), inserted FIRST in the variant array (last-match-wins ladder: rig < temper < broker).
>
> Without them the FIGHT route cannot report and the quest's third resolution path is unreachable from dialogue, and NO gate says so.

- [x] **Step 0 (task-1.3 handoff):** Restore the two FIGHT-arm blocks in `pallass_forge_smith.json` per the block above, in this task's commit.
- [x] **Step 1: Load `wi-adding-an-encounter`.**
- [x] **Step 2:** Splice the combatant row: `python3 wandering_inn_game/scripts/splice_json.py --file data/combatants.json --container combatants --record-file <draft.json>`. The tool re-parses, asserts sibling count +1 and byte-identity outside the splice, and exits non-zero with the file UNTOUCHED on failure.
- [x] **Step 3:** Add the encounter entity + the parley graph + the gated cell. **`grep -n trigger_radius` the finished `pallass_forge_hall.json` — it must return NOTHING.** An entity carrying both `conversation` and `trigger_radius` ships green through every gate and only surfaces as a mid-crossing ambush in play.
- [x] **Step 4: Run** `res://tests/test_combat_data.gd` — asserts the positive `power_level`, the `arena`/`enemies`/`allies`/`on_victory` presence, and arena spawn reachability.
- [x] **Step 5: Measure the band, do not narrow the gate (ruling A).** `WI_CELL_COUNT_ONLY=1 godot ... res://tests/sim_combat_batch.gd` to get the count, then `WI_CELL_RANGE=LO:HI` on the new cell's index alone. **The GATE is 0.55–0.95 / rounds 3–12. The DESIGN target is a measured win strictly BELOW the shipped `forge_calibration_golem_t5_sw14_solo` median at the same `t4_spellsword14_party` build** — that ordering is the whole band claim, and it is proven by recording both medians side by side in the PR body, never by a narrow window. If the new rig measures at or above the shipped golem, raise `con` in steps of 4 and re-measure. If it falls near the gate floor, lower `con`. **Only `forge_temper_golem`'s own stats move; `forge_golem`, `watchgolem_*` and `seal_warden` are never retuned** (a retune there reds other lanes' rungs).
- [x] **Step 6: Re-verify the neighbours and record the medians.** Run the slice containing `forge_calibration_golem_t4_solo`, `forge_calibration_golem_t5_sw14_solo`, `seal_warden_t5_sw14_solo` and confirm each still reads inside its own (unchanged) window. Since no shipped row's stats changed, any movement is seed noise. **Record all four measured win rates and medians in the PR body** — that table IS the band-ordering evidence.
- [x] **Step 7: Run** the FULL `sim_combat_batch.gd` once, alarm-wrapped at 600s, as the gate.
- [x] **Step 8: Run** `res://tests/test_combat_visuals.gd` — expect PASS, and **state in the PR body that it passes BY EXCLUSION** (ruling F): `FIGURE_ROWS` has four entries and the `audited` array contains no id from this lane, so nothing here is measured. Do not report this run as a figure-legibility result; the windowed shots in Task 4 are that read.
- [x] **Step 9: Census check. Commit** `feat(combat): the calibration rig, Pallass's commission fight`.

### Task 1.5: `tempered_standards` in `data/quests.json`

**Files:**
- Modify: `wandering_inn_game/data/quests.json`
- Modify: `wandering_inn_game/tests/test_quests.gd` (co-bank ladder pins)

**Full quest block draft** (append to the `quests` array; **TAB** indent — this file is tabs, unlike combatants.json):

```json
		{
			"_comment": "v0.16 P1 (#307). complete_when_any is an OR beside complete_when (quests.gd:28-38). The FIGHT counter is golem_recalibrated, never forge_golems_culled, so this quest cannot feed bounty_forge_golem_cull.",
			"id": "tempered_standards",
			"title": "Tempered Standards",
			"region": "Pallass",
			"beats": [
				{ "id": "commission", "description": "Take the smith's commission through to an answer, in the forge hall past her second bench.", "complete_when": { "golem_recalibrated": 1 }, "complete_when_any": { "temper_run": 1, "standards_brokered": 1 } },
				{ "id": "report", "description": "Bring the smith the answer at her anvil, and let her file it.", "complete_when": { "standards_tempered": 1 } }
			],
			"_resolution_order": "WEAKEST CLAIM FIRST (resolved_path is last-match-wins). All three co-bank -- a player can fight the rig, run a billet AND read the notice in one visit -- so the STRONGER claim must be what the journal records. Ladder: brokered > temper > rig. Putting the rig down fixes an instrument; running one temper right proves the apprentice's work; brokering ends the six-year disagreement that made the work fail in the first place, which is the only outcome that survives the player leaving the tier.",
			"resolution_paths": [
				{ "accomplishment": "golem_recalibrated", "text": "You put the drifting calibration rig back inside its own tolerance.", "grant": { "melee_hit": 6, "won_combat": 1 } },
				{ "accomplishment": "temper_run", "text": "You ran the temper yourself, and the billet came back.", "grant": { "observed_things": 4, "deliberate_commerce": 2 } },
				{ "accomplishment": "standards_brokered", "text": "You proved the smith and the examiner had agreed all along, and got it in writing.", "grant": { "persuaded_someone": 3, "heard_gossip": 3 } }
			]
		}
```

**Landmark check:** `standards_brokered` is produced in `pallass_forge_smith`, whose map (`pallass_forge`) IS the giver map, so `_beat_needs_place_name` returns false for the `commission` beat and no landmark is strictly required. The description names "the forge hall" anyway, and the `LANDMARK_TOKENS["pallass_forge_hall"]` row from Task 1.1 covers it if the producer set ever narrows.

**`test_quests.gd` co-bank pins** (append after the `price_of_a_favor` block, ~line 132). **Locals carry this lane's `p_` prefix (ruling C)** — `tests/test_quests.gd:90-132` is ONE function body at a single indent level, so a bare `var tempered` / `var ledger` collides with a sibling lane's local as a duplicate DECLARATION and the file stops parsing on the second merge:

```gdscript
	# v0.16 P1: all three route counters co-bank in one visit to the hall.
	var p_tempered: Dictionary = WIQuests.quest_by_id(shipped, "tempered_standards")
	assert(String(WIQuests.resolved_path(p_tempered, {"golem_recalibrated": 1})["accomplishment"]) == "golem_recalibrated", "a fight-only commission still records the rig")
	assert(String(WIQuests.resolved_path(p_tempered, {"golem_recalibrated": 1, "temper_run": 1})["accomplishment"]) == "temper_run", "fought THEN ran the temper records the TEMPER")
	assert(String(WIQuests.resolved_path(p_tempered, {"temper_run": 1, "standards_brokered": 1})["accomplishment"]) == "standards_brokered", "ran it THEN brokered records the BROKERING -- the claim that outlives you leaving")
```

> **BINDING TASK-1.3 HANDOFF (deferred quest-start effect).** `test_content.gd:1122-1124` reds any dialogue effect starting a quest id absent from `data/quests.json`, so Task 1.3 shipped the smith's `"I'll take the commission."` option with only its `standards_commission_taken` effect. **Restore `{ "quest": "tempered_standards" }` as the FIRST entry of that option's `effects` array in the SAME commit that splices the quest block** (one verb per dict — it is a second dict, never a second key). Without it the quest never starts, the journal never shows it, and every gate stays green.

- [x] **Step 0 (task-1.3 handoff):** Restore the `{ "quest": "tempered_standards" }` effect dict in `pallass_forge_smith.json` per the block above, in this task's commit.
- [x] **Step 1:** Splice the quest block: `splice_json.py --file data/quests.json --container quests --record-file <draft.json>`.
- [x] **Step 2:** Add the `test_quests.gd` pins.
- [x] **Step 3: Run** `res://tests/test_quests.gd` (`_resolution_order` guard + the new pins) and `res://tests/test_content.gd` (`_validate_quests` cross-refs every `complete_when` counter against a real producer) and `res://tests/test_reachability.gd` (every `resolution_paths[].accomplishment` needs a producer).
- [x] **Step 4: Commit** `feat(quests): Tempered Standards, three real routes`.

### Task 1.6: Grimalkin's one line (text_variants ONLY)

**Files:** Modify `wandering_inn_game/data/dialogue/pallass_grimalkin.json`

**Ruling 4 restated:** no new hub option, ever. `grimalkin_study_loop.json` pins his hub option array at lines 22, 39 and 55; `pallass_peek.json:120` navigates it by index; `spine_reach` and `inn_guests_ext_loop` also touch him. `text_variants` never change the rendered option list.

Append ONE entry to the EXISTING `hub.text_variants` array (currently two entries keyed on `completed_bounty_grimalkin_study_combat` / `_casting`), placed **last** so it wins over the study lines for a player who has done both:

```json
{
 "requires": { "accomplishment": { "standards_tempered": 1 } },
 "text": "The forge tier settled its temper argument and my name is in the file twice. Understand: a blade that will not come back is a blade that never bent. Same measure as a squat. Depth, then recovery, then the file. State your business."
}
```

- [x] **Step 1: Shadow-shape audit (mandatory).** The gate `standards_tempered` is a NEW counter, so it cannot be held by ANY shipped fixture (`grimalkin_study_start`, `near_pallass`, `spine_reach_start`, `near_pallass_drake`) — no pinned-route script can match it, and the two study variants keep winning in exactly the states they win today. Record this in "New agent context".
- [x] **Step 2:** Verify the gate is not IDENTICAL to a shipped variant's gate (it is not — the two shipped gates are the study bounty counters). An identical gate would silently shadow forever.
- [x] **Step 3: Run** `res://tests/test_dialogue.gd`, `res://tests/test_content.gd` (VARIANT_KEYS whitelist: `text_variants` accepts only `_comment`/`requires`/`text`), `res://tests/test_copy_fit.gd` (this string is 246 chars — **confirm the page split reads cleanly or shorten it**; the node's own `_comment` records a 204-char string producing a 12-char orphan page).
- [x] **Step 4: Run** `qa/ci_sweep.sh --only grimalkin_study_loop,pallass_peek,spine_reach` — expect green.
- [x] **Step 5: Commit** `feat(dialogue): Grimalkin on recovery, squats, and the file`.

### Task 1.7: The smith's post-quest reactive stage

**Files:** Modify `wandering_inn_game/data/maps/pallass/pallass_forge.json` (entity `forge_smith`, `talk_pool_stages`)

**Ruling 8:** key on the TERMINAL `standards_tempered`, never on `elevator_pass_stamped` or anything the forge tier implies. **APPEND AFTER the last existing stage** — stages are last-match-wins and the existing ladder is `smith_golems_culled` (`forge_golems_culled`:1) then `smith_seal_resolved` (`seal_resolved`:1).

```json
{
 "id": "smith_standards_tempered",
 "requires_accomplishment": { "standards_tempered": 1 },
 "lines": [
  "She passed it this morning. Same hand, same steel, honest measure. Nothing else changed.",
  "The examiner sent the file up himself. He has never once walked up a flight for me.",
  "You did not make her better, {addr}. You made the reading true. That is the harder favor."
 ]
}
```

- [x] **Step 1: Shadow-out audit (mandatory).** For each reachable state, which stage wins? — golems-culled-only → `smith_golems_culled`; seal-resolved → `smith_seal_resolved`; P1 done → the new stage, permanently. That is intended: P1 is the tier's most recent news and the base pool is not GUIDANCE copy. Ascending-threshold rule (`test_content.gd:579-593`) does not apply — the three stages key on three DIFFERENT counters.
- [x] **Step 2:** Append the stage; keep the base `talk_pool` (an entity with stages MUST have one).
- [x] **Step 3: Run** `res://tests/test_content.gd` + `res://tests/test_copy_fit.gd` (pool lines are ambient barks, 2 wrapped lines max).
- [x] **Step 4: Commit** `feat(pallass): the smith's post-commission pool stage`.

---

## Task 2 — P2 "The Ledger Eats First": quest + den shop interior

### Task 2.1: `pallass_den_shop` interior map

**Files:**
- Create: `wandering_inn_game/data/maps/pallass/pallass_den_shop.json`
- Modify: `data/moods.json`, `tests/test_content.gd` (`LANDMARK_TOKENS`), `tests/test_fixture_coherence.gd` (`MAP_REQUIRES`)

**Full layout spec (11×8 — well under parlor scale):**

```
grid: 11 x 8        biome: inn  (existing; footstep wood, blocked_props [crate, barrel])
   -- the warm-timber counterweight to all that slate. Reuses the riverfarm_longhouse
      precedent (a regional interior taking the `inn` biome's tile language rather
      than its own region's) so NO new biome row is needed and test_audio_data's
      footstep_family contract stays honest.
walls.segments (sheet res://assets/props/free_pack/Interior_Walls_01.png, tile_px 16,
                cap [14,6], face [14,7] on the north run -- the longhouse values):
   [0,0] -> [10,0]
   [0,1] -> [0,7]
   [10,1] -> [10,7]
   [1,7] -> [3,7]  and  [5,7] -> [9,7]     (leaving (4,7) for the exit door)
walkable floor: x=1..9, y=1..6, plus the door cell (4,7)
blocked (5 cells, each covered by authored decor):
   [3,2] counter_left   [4,2] counter_mid   [5,2] counter_right
   [8,1] crate     (the shipment's empty space, until it isn't)
   [1,5] barrel
decor also (non-blocking): rug_tan [4,4], plant_pot [9,1], crystal_lamp [2,1] with a warm light
ambience: [{ "preset": "dust_motes", "rect": "all", "phase": ["dusk", "night"] }]
```

**Entities (7):**

| id | kind | cell | surface |
| --- | --- | --- | --- |
| `den_shop_exit` | door | [4,7] | → `pallass_market` (12,5) |
| `den_shop_keeper` | npc | [4,1] | conversation `pallass_den_keeper` + `talk_pool` |
| `den_shop_consignment_file` | prop | [7,2] | P2 SKILL, `requires_skill: appraise_goods` |
| `den_shop_receiving_dock` | prop | [8,5] | P2 HELP leg 3, `once_per_waking` |
| `den_shop_spice_shelf` | prop | [1,2] | observable |
| `den_shop_hatchling_bench` | prop | [2,5] | observable |
| `den_shop_family_slate` | prop | [9,3] | observable |

**Arrival cells, hand-verified both directions:**
- OUT→IN: player stands `pallass_market` **(12,5)** — free (market y5 occupies x∈{5,6,7,15,24}); not in the 21-cell canonical-assert set for this map (which holds (12,7), not (12,5)); off the perimeter lap and the `y=9` lane — faces **up** to the door at (12,4) (market y4 occupies only x∈{19,20}; canonical y4 asserts are (10,4) and (18,4)), interacts, arrives `pallass_den_shop` **(4,6)**: unblocked, unoccupied, directly north of the exit door.
- IN→OUT: from (4,6) faces **down** to `den_shop_exit` at (4,7), interacts, arrives `pallass_market` **(12,5)**.
- Save-compat: the new blocking door at market (12,4) has all four neighbours open.

**Exact JSON drafts — the three non-quest observables and the keeper:**

```json
{
 "id": "den_shop_keeper",
 "kind": "npc",
 "cell": [4, 1],
 "display_name": "Den-Shop Keeper",
 "sprite": "drake_patron",
 "tint": [0.78, 0.56, 0.42],
 "facing": "down",
 "observe": "A broad Drake behind a counter worn pale in two places, one where the coins land and one where her elbow goes. Both are hers.",
 "friendly_line": "She pushes a bowl of salted something across the counter at you without being asked, and takes the coin for it without apologising.",
 "talk_pool": [
  "Sit if you're sitting, {addr}. Standing customers make the hatchlings nervous.",
  "Fourth generation on this tier. Same permit number, four different clerks who each swore it was wrong.",
  "Everything on that shelf came up the lift. Everything. Including the shelf.",
  "I feed this quarter and I charge this quarter. Nobody has ever found that strange but visitors."
 ],
 "conversation": "pallass_den_keeper"
}
```

```json
{
 "id": "den_shop_spice_shelf",
 "kind": "prop",
 "cell": [1, 2],
 "display_name": "The Spice Shelf",
 "sprite": "shelf_bottles",
 "observe": "Jars in a rank, labels in a hand that got neater partway along the shelf and then went back to how it was.",
 "on_interact_accomplishment": "eyed_the_den_spice_shelf",
 "toast": "Half the jars are from tiers you will never have a permit for. The keeper does not explain how, and you decide not to ask in a city this fond of paperwork."
}
```

```json
{
 "id": "den_shop_hatchling_bench",
 "kind": "prop",
 "cell": [2, 5],
 "display_name": "The Low Bench",
 "sprite": "bench",
 "observe": "A bench cut down to knee height, three sets of claw-marks along the front edge at three different heights.",
 "on_interact_accomplishment": "heard_the_den_hatchlings",
 "toast": "Something small goes very still behind the bench, decides you are not interesting, and resumes an argument you cannot follow about whose turn it is."
}
```

```json
{
 "id": "den_shop_family_slate",
 "kind": "prop",
 "cell": [9, 3],
 "display_name": "The House Slate",
 "sprite": "inn_room_ledger",
 "observe": "The family's own board: who eats here on credit, and for how long. Names in chalk, never in ink.",
 "on_interact_accomplishment": "read_the_den_family_slate",
 "toast": "Eleven names carried. One of them has been carried for two years and has no repayment column at all. In Pallass, that is a document nobody filed."
}
```

**Mood row:**

```json
"pallass_den_shop": { "day": [1.0, 0.9, 0.76], "dusk": [0.98, 0.86, 0.72], "night": [0.92, 0.8, 0.68], "vignette": 0.3 }
```

**`LANDMARK_TOKENS` row:**

```gdscript
	"pallass_den_shop": ["den shop", "market tier", "pallass"],
```

**`MAP_REQUIRES` row:**

```gdscript
	"pallass_den_shop": ["door_awakened", "pallass_attuned"],
```

- [x] **Step 1: Load `wi-adding-a-scene`.** Re-read `riverfarm_longhouse.json`.
- [x] **Step 2:** Write the map with the entities above (the two quest props land in Task 2.4/2.5 — author them here in one pass to avoid a second map commit, but keep the commit message honest).
- [x] **Step 3:** Mood row + LANDMARK_TOKENS + MAP_REQUIRES.
- [x] **Step 4: Run** `data_lint.py`, `res://tests/test_content.gd`, `res://tests/test_world_visuals.gd`, `res://tests/test_audio_data.gd`.
- [x] **Step 5:** Scene-dynamism advisory; record the composite.
- [x] **Step 6: Census check. Commit** `feat(pallass): the den shop, the tier's warm room`.

### Task 2.2: `pallass_market` + `pallass_forge` hooks — the door, the manifest, the carry props

**Files:** Modify `pallass_market.json` and `pallass_forge.json`

**Cell justification (ruling 9):**

| new entity | map | cell | why |
| --- | --- | --- | --- |
| `den_shop_door` | pallass_market | **[12,4]** | market y4 occupies x∈{19,20}; canonical y4 asserts are (10,4)/(18,4). Off laps, off the `y=9` lane. Sits behind the stall row so the shop fronts the market. Approach (12,5) free. |
| `market_dray_rank` | pallass_market | **[16,4]** | same free row; the recon's alternate door candidate, now free because the door took (12,4). Two blocks east of the den shop door, which is the carry fiction. |
| `lift_manifest_slate` | pallass_forge | **[23,4]** | forge y4 occupies x∈{9,17,18}. Canonical forge asserts at x=23 are (23,6)/(23,7)/(23,9) — (23,4) is free. Sits on the landing side, in the attendant's own working column. |
| `lift_cargo_pallet` | pallass_forge | **[19,4]** | free (y4 occupies 9/17/18); canonical x=19 asserts are (19,7)/(19,8). One cell east of `forge_fetch_slips` (18,4), whose canonical approach is (18,5) — bump-north from (18,5) is unaffected. |

```json
{
 "id": "lift_manifest_slate",
 "kind": "prop",
 "cell": [23, 4],
 "display_name": "The Landing Manifest",
 "sprite": "price_board",
 "observe": "A slate of what the cage is carrying today, chalked by hour. Two lines have been rewritten so many times the slate has gone smooth under them.",
 "on_interact_accomplishment": "read_the_lift_manifest",
 "toast": "One crate of tin, den shop, market tier. Logged three cycles running and carried none of them. Beside it, in a tidier hand: HELD, QUEUE."
}
```

```json
{
 "_comment": "P2 HELP leg 1 of 3. once_per_waking books per ENTITY (`serve:<id>`), so three distinct props bank shipment_leg_carried three times in one waking. No lift affordance exists or is being added.",
 "id": "lift_cargo_pallet",
 "kind": "prop",
 "cell": [19, 4],
 "display_name": "The Held Pallet",
 "sprite": "crate",
 "observe": "A pallet strapped and tagged and standing exactly where it has stood for three cycles, one hand's width outside the loading square.",
 "on_interact_accomplishment": "shipment_leg_carried",
 "once_per_waking": true,
 "once_per_waking_toast": "The pallet is where you left it and the cage is where the bell says. Nothing moves again until the next shift.",
 "toast": "You get the pallet onto the loading square and the strapping squared. The attendant looks at it, looks at the bell, and says nothing, which is the whole permission you are going to get."
}
```

```json
{
 "_comment": "P2 HELP leg 2 of 3. variants resolve BEFORE this interact banks, so every carry-leg threshold is (leg index - 1): leg 2 gates on 1.",
 "id": "market_dray_rank",
 "kind": "prop",
 "cell": [16, 4],
 "display_name": "The Dray Rank",
 "sprite": "market_stall_wood",
 "observe": "A rank of low carts for hire, each chalked with a tier number and a rate, and a queue board nobody is standing at.",
 "on_interact_accomplishment": "shipment_leg_carried",
 "once_per_waking": true,
 "once_per_waking_toast": "The rank is empty until the next rotation. Pallass hires carts on a schedule too.",
 "toast": "You take a cart off the rank, walk the crate off the lift apron and across two blocks of very orderly stone, and nobody stops you once. The paperwork was never about the crate.",
 "variants": [
  {
   "when": { "shipment_leg_carried": 1 },
   "toast": "Second leg, same cart, same two blocks. The rank clerk marks it without looking up, which in Pallass is a commendation."
  }
 ]
}
```

**The dray rank's `when` is 1, not 2 — the (leg index − 1) rule.** `src/core/interactions.gd:129-138` resolves `variants` at :129-135 and only calls `_record_accomplishment(accomplishment_id, 1)` at :138, so a carry prop's variant sees the count BEFORE its own leg banks; `wi_game.gd:403-414` tests each variant with `_accomplishment_gate_met`, which is `count >= threshold` (`:892-896`). Carry order per `pallass_ledger_carry` is pallet (19,4) → dray rank (16,4) → dock (8,5), so at the dray rank the pre-bank count is **1**. A `when: 2` there can never fire and the base toast renders instead — the staged copy would be silently dead.

```json
{
 "id": "den_shop_door",
 "kind": "door",
 "cell": [12, 4],
 "display_name": "A Family Den Shop",
 "sprite": "door",
 "to_map": "pallass_den_shop",
 "to_cell": [4, 6],
 "observe": "A shopfront wedged between two civic frontages, the only door on this row with a hand-painted sign and something cooking behind it."
}
```

- [x] **Step 1:** Insert the four entities, matching each file's own indent.
- [x] **Step 2:** `POPULATION_FLOORS` for `pallass_market` (24) and `pallass_forge` (15) — all four are UNCONDITIONAL, so counts RISE. No floor edits.
- [x] **Step 3: Run** `data_lint.py` + `res://tests/test_content.gd` + `res://tests/test_world_visuals.gd`.
- [x] **Step 4: Run** `qa/ci_sweep.sh --touching data/maps/pallass/pallass_market.json,data/maps/pallass/pallass_forge.json` — the crowded-cell proof for both tiers.
- [x] **Step 5: Commit** `feat(pallass): the den shop door, the landing manifest, and two carry legs`.

### Task 2.3: The den keeper's conversation — `data/dialogue/pallass_den_keeper.json`

**Files:** Create `wandering_inn_game/data/dialogue/pallass_den_keeper.json`

**Interfaces:**
- Consumes: `ledger_loop_started`, `queue_notice_countersigned`, `shipment_leg_carried`.
- Produces: `loop_walked` (TALK office 3), `shipment_carried` (HELP sign-off).

```json
{
 "_comment": "v0.16 P2 (#307). Voice: character-profiles.md 'Den-Shop Keeper'. NEW graph on a NEW entity, so the loop and sign-off surfaces never ride a pinned hub.",
 "start": "hub",
 "nodes": {
  "hub": {
   "speaker": "Den-Shop Keeper",
   "text": "Come in, mind the small ones. If you're buying, the shelf is the shelf. If you're official, the counter is the counter and I've had a long month of counters.",
   "text_variants": [
    {
     "requires": { "accomplishment": { "ledger_unstuck": 1 } },
     "text": "The tin came up. Four cycles late and every stamp on it correct, which is the joke, {addr}. Sit down. You are eating something."
    }
   ],
   "options": [
    { "text": "Long month how?", "goto": "month" },
    {
     "text": "I'm here about a crate of tin.",
     "requires": { "accomplishment": { "ledger_loop_started": 1 } },
     "hide_when": { "accomplishment": { "ledger_unstuck": 1 } },
     "goto": "consignee"
    },
    { "text": "Just looking.", "end": true }
   ]
  },
  "month": {
   "speaker": "Den-Shop Keeper",
   "text": "My tin is in a queue. I am in the queue behind my tin. The office that holds the queue is also waiting on the queue, for its own supplies, which are also tin. I have stopped finding it funny and started finding it restful.",
   "options": [
    { "text": "That can't be how it works.", "goto": "month_two" },
    { "text": "Restful.", "end": true }
   ]
  },
  "month_two": {
   "speaker": "Den-Shop Keeper",
   "text": "It is exactly how it works and every single person in that chain is doing their job correctly. That is what visitors never believe. Nobody up here is lazy, {addr}. They are all precisely as careful as the last person who got blamed.",
   "options": [
    { "text": "Somebody has to be able to sign.", "goto": "hub" },
    { "text": "I'll leave you to it.", "end": true }
   ]
  },
  "consignee": {
   "speaker": "Den-Shop Keeper",
   "text": "I am the consignee. I can release it the moment somebody hands me a notice I am allowed to act on. Not a promise, not a word from the landing. A notice.",
   "options": [
    {
     "_comment": "TALK route terminal rung. Requires the countersigned notice, i.e. offices 1 and 2 walked in order.",
     "text": "[Hand her the countersigned queue notice.]",
     "requires": { "accomplishment": { "queue_notice_countersigned": 1 } },
     "hide_when": { "accomplishment": { "loop_walked": 1 } },
     "effects": [ { "accomplishment": "loop_walked" } ],
     "goto": "released"
    },
    {
     "_comment": "HELP route terminal rung. Three legs = the two carry props plus this shop's own receiving dock.",
     "text": "[Tell her the crate is already on her dock.]",
     "requires": { "accomplishment": { "shipment_leg_carried": 3 } },
     "hide_when": { "accomplishment": { "shipment_carried": 1 } },
     "effects": [ { "accomplishment": "shipment_carried" } ],
     "goto": "carried"
    },
    { "text": "I'll come back with something you can act on.", "end": true }
   ]
  },
  "released": {
   "speaker": "Den-Shop Keeper",
   "text": "Countersigned. By the office that was waiting on the queue, about the queue. I am going to have this framed and I am going to hang it where the hatchlings can see it.",
   "options": [
    { "text": "Everyone in that chain was right.", "end": true }
   ]
  },
  "carried": {
   "speaker": "Den-Shop Keeper",
   "text": "You carried it. Two tiers and three legs and no stamp on any of it. That is not how it is done and I am not going to say another word about it. Take the small jar. No, take it.",
   "options": [
    { "text": "It's tin. It was always just tin.", "end": true }
   ]
  }
 }
}
```

**STAGE-1 HANDOFF (added by the map stage, binding).** `test_content.gd:933`
reds any entity whose `conversation` names a graph that does not exist, so the
`den_shop_keeper` entity was authored in Task 2.1 **without** its
`"conversation": "pallass_den_keeper"` key. THIS TASK MUST ADD IT BACK:
append `"conversation": "pallass_den_keeper"` as the entity's last key in
`data/maps/pallass/pallass_den_shop.json` in the SAME commit that creates the
graph. Without it the keeper has only a `talk_pool`, both P2 terminal rungs
(`loop_walked`, `shipment_carried`) are unreachable, and nothing in the suite
says so.

- [x] **Step 0 (stage-1 handoff):** Add `"conversation": "pallass_den_keeper"` to the `den_shop_keeper` entity in `pallass_den_shop.json`.
- [x] **Step 1:** Write the graph. Softlock guard: `hub` keeps `"Long month how?"` and `consignee` keeps its plain exit.
- [x] **Step 2: Run** `data_lint.py` (start node present, every node has speaker+text, every goto resolves), `res://tests/test_dialogue.gd`, `res://tests/test_content.gd`, `res://tests/test_copy_fit.gd`.
- [x] **Step 3: Commit** `feat(dialogue): the den-shop keeper, consignee of one crate of tin`.

### Task 2.4: The attendant's quest — `pallass_lift_attendant.json`

**Files:** Modify `wandering_inn_game/data/dialogue/pallass_lift_attendant.json`

**Gating ledger (ruling 5) — which fixture holds what:**

| crossing script | fixture | holds `read_the_lift_manifest`? | holds `ledger_loop_started`? | hub rows it sees |
| --- | --- | --- | --- | --- |
| `pallass_walkthrough` | `near_pallass` (walks the chain live; never interacts `lift_manifest_slate`) | **no** | **no** | **3** (unchanged pin at line ~1152, and the `move down 1` at ~1156 still lands on `cycle`) |
| every other Pallass canonical | — | no | no | n/a (none opens this graph) |

**Two new hub options** (append to the END of the existing `options` array):

```json
{
 "_comment": "v0.16 P2 start. requires-hidden on read_the_lift_manifest (banked only by lift_manifest_slate, which near_pallass never interacts), so the 3-row pin and index navigation are untouched.",
 "text": "Your manifest says one crate of tin, three cycles held.",
 "requires": { "accomplishment": { "read_the_lift_manifest": 1 } },
 "hide_when": { "accomplishment": { "ledger_loop_started": 1 } },
 "goto": "ledger_pitch"
},
{
 "text": "About that crate.",
 "requires": { "accomplishment": { "ledger_loop_started": 1 } },
 "hide_when": { "accomplishment": { "ledger_unstuck": 1 } },
 "goto": "ledger_report"
}
```

**Four new nodes:**

```json
"ledger_pitch": {
 "speaker": "Lift Attendant",
 "text": "Four cycles, and it will be five. The permit office holds the queue and the office's own supplies are in it, so the office cannot clear the queue until the queue clears the office. Nobody may skip it. That includes the queue.",
 "options": [
  {
   "text": "Somebody should unstick that.",
   "effects": [
    { "quest": "ledger_eats_first" },
    { "accomplishment": "ledger_loop_started" }
   ],
   "goto": "ledger_brief"
  },
  { "text": "Then it waits.", "end": true }
 ]
},
"ledger_brief": {
 "speaker": "Lift Attendant",
 "text": "Three ways down, {addr}, and I will not tell you which. Walk the offices in order and get it in writing. Read the forms properly, if you read forms. Or put the crate on the cart yourself and carry it, which is not how it is done. The consignee is a den shop on the market tier.",
 "options": [
  { "text": "Which office starts it?", "goto": "ledger_brief_two" },
  { "text": "I'll find out.", "end": true }
 ]
},
"ledger_brief_two": {
 "speaker": "Lift Attendant",
 "text": "The stamp clerk on the market tier holds the entry side. The permit window holds the release side. The consignee signs last and cannot sign first. Down at the quarter bell.",
 "options": [
  { "text": "Down at the quarter bell.", "end": true }
 ]
},
"ledger_report": {
 "speaker": "Lift Attendant",
 "text": "Say it plainly. I have a cage to run in three minutes and I would like to run it happy.",
 "options": [
  {
   "text": "[The offices countersigned each other. It's released.]",
   "requires": { "accomplishment": { "loop_walked": 1 } },
   "effects": [ { "accomplishment": "ledger_unstuck" } ],
   "goto": "ledger_settled"
  },
  {
   "text": "[The exemption was in the forms the whole time.]",
   "requires": { "accomplishment": { "exemption_found": 1 } },
   "effects": [ { "accomplishment": "ledger_unstuck" } ],
   "goto": "ledger_settled"
  },
  {
   "text": "[I carried it down myself. It's on her dock.]",
   "requires": { "accomplishment": { "shipment_carried": 1 } },
   "effects": [ { "accomplishment": "ledger_unstuck" } ],
   "goto": "ledger_settled"
  },
  { "text": "Still working on it.", "end": true }
 ]
},
"ledger_settled": {
 "speaker": "Lift Attendant",
 "text": "Then the manifest is clean and the cage runs happy. Down at the quarter bell.",
 "text_variants": [
  {
   "requires": { "accomplishment": { "shipment_carried": 1 } },
   "text": "You carried it. Two tiers, on your own back, for a family that does not know your name. I have run this cage eleven years and watched a great many correct people wait. Ride free while I am on the gate, {addr}. That is the only thing I own to give."
  },
  {
   "requires": { "accomplishment": { "loop_walked": 1 } },
   "text": "You made the offices sign each other's paper. I am going to tell that story at every quarter bell for a month and it will be true every time."
  },
  {
   "requires": { "accomplishment": { "exemption_found": 1 } },
   "text": "It was in the forms. Four cycles, and it was in the forms. I am not angry, {addr}. I am going to be angry at the half bell, when I have time."
  }
 ],
 "options": [
  { "text": "Down at the quarter bell.", "end": true }
 ]
}
```

Variant order is deliberate — last-match-wins puts a co-banking player on the SKILL line, matching the P2 ladder in Task 2.6. The HELP line is the spec's "region's warmest line" and is placed first so it survives as the sole match on a pure-HELP run.

- [x] **Step 1:** Append the two options and the five nodes.
- [x] **Step 2: Shadow-out audit.** The shipped `hub` `text_variant` (`seal_resolved`) is untouched; no variant is added to `hub`.
- [x] **Step 3: Run** `test_dialogue`, `test_content`, `test_copy_fit`.
- [x] **Step 4: Run** `qa/ci_sweep.sh --only pallass_walkthrough` — confirm the 3-row attendant pin holds.
- [x] **Step 5: Census check. Commit** `feat(dialogue): the attendant's queue, and three ways out of it`.

### Task 2.5: The office loop — market clerk + forge permit clerk

**Files:** Modify `data/dialogue/pallass_market_clerk.json` and `data/dialogue/pallass_forge_clerk.json`

**Gating ledger (ruling 5):** both new options are `requires`-hidden on counters that no shipped fixture and no live canonical route banks. `pallass_walkthrough` (fixture `near_pallass`) drives both clerk hubs with index navigation but never starts P2, so `ledger_loop_started` is 0 and `queue_notice_endorsed` is 0 — neither option renders. Note that `pallass_walkthrough` does NOT pin either clerk hub's `options` array (its only pinned arrays are the portal menu, the attendant hub, and the smith hub) — the index navigation is the exposure, and gating removes it.

**Speaker strings are FROZEN in the drafts below — verified against the live graphs, do not re-derive.** `data/dialogue/pallass_market_clerk.json` uses `"speaker": "Tier Clerk"` on every node (`hub`, `stamped`); `data/dialogue/pallass_forge_clerk.json` uses `"speaker": "Forge-Tier Clerk"` on every node (`hub`, `tempering_sold`, `permit_intro`, `permit_filed_reaction`, `permit_status`, `collect_stamp`, `stamp_reaction`). The only speaker validation in the suite is PRESENCE (`tests/test_content.gd:959` `_check(node.has("speaker"), ...)`); `test_dialogue.gd` never compares speakers across a graph's nodes. So a wrong speaker ships green as a character who renames himself mid-conversation, and any QA pin authored as `payload_contains: {"speaker": ...}` from a wrong draft would be pinned to a string the run never emits.

**Market clerk (office 1) — append to the `hub` `options` array:**

```json
{
 "text": "There's a crate of tin held in your own queue.",
 "requires": { "accomplishment": { "ledger_loop_started": 1 } },
 "hide_when": { "accomplishment": { "queue_notice_endorsed": 1 } },
 "goto": "queue_entry"
}
```

```json
"queue_entry": {
 "speaker": "Tier Clerk",
 "text": "Held correctly. The entry side is mine and the entry side is clear. What is not clear is the release side, and I cannot endorse a release I do not hold. I can endorse that the entry is clean. That is a real document and it is not nothing.",
 "options": [
  {
   "text": "Then endorse the entry, and I'll take it up.",
   "effects": [ { "accomplishment": "queue_notice_endorsed" } ],
   "goto": "queue_entry_done"
  },
  { "text": "That is somehow worse than nothing.", "end": true }
 ]
},
"queue_entry_done": {
 "speaker": "Tier Clerk",
 "text": "Stamped, dated, and correct. Take it to the permit window. And do not say I sent you, because I did not, I endorsed.",
 "options": [
  { "text": "You endorsed.", "end": true }
 ]
}
```

**Forge permit clerk (office 2) — append to the `hub` `options` array.** Note the shipped clerk says "I only handle paper" in three separate nodes; the new copy stays inside that voice.

```json
{
 "text": "The stamp clerk endorsed the entry side. Countersign the release.",
 "requires": { "accomplishment": { "queue_notice_endorsed": 1 } },
 "hide_when": { "accomplishment": { "queue_notice_countersigned": 1 } },
 "goto": "queue_release"
}
```

```json
"queue_release": {
 "speaker": "Forge-Tier Clerk",
 "text": "I only handle paper, and this is paper, so we are finally in agreement about something. The release side is held because this office is waiting on its own supplies, which are in the queue. But an endorsed entry outranks a held release. That is the rule. Nobody has ever used it.",
 "options": [
  {
   "text": "Use it.",
   "effects": [ { "accomplishment": "queue_notice_countersigned" } ],
   "goto": "queue_release_done"
  },
  { "text": "Why has nobody used it?", "goto": "queue_release_why" }
 ]
},
"queue_release_why": {
 "speaker": "Forge-Tier Clerk",
 "text": "Because you have to walk to the other office first, and everybody assumes the answer is no. It is generally no. It is not no today.",
 "options": [
  {
   "text": "Then countersign it.",
   "effects": [ { "accomplishment": "queue_notice_countersigned" } ],
   "goto": "queue_release_done"
  }
 ]
},
"queue_release_done": {
 "speaker": "Forge-Tier Clerk",
 "text": "Countersigned. Take it to the consignee. She signs last, which is the only part of this that was ever simple.",
 "options": [
  { "text": "She signs last.", "end": true }
 ]
}
```

- [x] **Step 1:** Read both shipped graphs end to end; match the clerks' registers (the market clerk's is procedural-neutral; the permit clerk's is "I only handle paper").
- [x] **Step 2:** Append the options and nodes **exactly as drafted**, speaker strings included: `"Tier Clerk"` for the market clerk's two new nodes, `"Forge-Tier Clerk"` for the permit clerk's three. Confirm with `python3 -c "import json;d=json.load(open('data/dialogue/pallass_market_clerk.json'));print(sorted({n['speaker'] for n in d['nodes'].values()}))"` (and the same for `pallass_forge_clerk.json`) — each must print a ONE-element list after the edit.
- [x] **Step 3: Softlock guard:** both hubs already carry always-available options.
- [x] **Step 4: Run** `test_dialogue`, `test_content`, `test_copy_fit`.
- [x] **Step 5: Run** `qa/ci_sweep.sh --only pallass_walkthrough,pallass_peek,pallass_round_trip,spine_reach` — expect green.
- [x] **Step 6: Commit** `feat(dialogue): the queue that outranks itself, in two offices`.

### Task 2.6: `ledger_eats_first` in `data/quests.json` + the SKILL/HELP props

**Files:**
- Modify: `data/quests.json`, `tests/test_quests.gd`
- Modify: `data/maps/pallass/pallass_den_shop.json` (the two quest props, if not already authored in 2.1)

**The two den-shop quest props:**

```json
{
 "_comment": "P2 SKILL route. Visible-locked (requires_skill), so a player without the arm still sees the route exists.",
 "id": "den_shop_consignment_file",
 "kind": "prop",
 "cell": [7, 2],
 "display_name": "The Consignee's File",
 "sprite": "inn_room_ledger",
 "observe": "The shop's own copy of every form the crate has generated, in a stack tall enough to stand a cup on.",
 "requires_skill": "appraise_goods",
 "skill_hint_toast": "Forms, in an order. There is a shape to the order. You cannot see the shape.",
 "locked_toast": "Twelve forms about one crate. You get four pages in before the words stop meaning anything.",
 "on_skill_use": {
  "accomplishment": "exemption_found",
  "toast": "[Appraise Goods] — Form nine, clause four: perishable household stock is exempt from queue hold. Tin is not perishable. The salt packed WITH it is, and it is on the same manifest line. Four cycles, and the exemption was on the paper the whole time."
 }
}
```

```json
{
 "_comment": "P2 HELP leg 3 of 3. Variant `when` is (leg index - 1) = 2: variants resolve before this interact banks (interactions.gd:129-138).",
 "id": "den_shop_receiving_dock",
 "kind": "prop",
 "cell": [8, 5],
 "display_name": "The Receiving Dock",
 "sprite": "crate",
 "observe": "A cleared square of floor by the back wall with a chalk outline on it, the size of one crate, waiting since the first cycle.",
 "on_interact_accomplishment": "shipment_leg_carried",
 "once_per_waking": true,
 "once_per_waking_toast": "The dock is squared away for today. Whatever else moves, it moves tomorrow.",
 "toast": "You square the load onto the chalk outline. It fits the way a thing fits when somebody measured it a month ago and has been looking at the empty space since.",
 "variants": [
  {
   "when": { "shipment_leg_carried": 2 },
   "toast": "Third leg, last leg. The crate lands inside its own chalk outline and something in the back of the shop goes quiet, then very loud, then quiet again."
  }
 ]
}
```

**The rule, stated once and applied everywhere: every carry-leg variant threshold is (leg index − 1).** `variants` resolve BEFORE this interact's own bank (`src/core/interactions.gd:129-135` resolves, `:138` banks; `wi_game.gd:403-414` + `:892-896` test `count >= threshold`), so leg 1 gates on 0 (no variant needed — that is the base toast), leg 2 (`market_dray_rank`) gates on **1**, leg 3 (`den_shop_receiving_dock`) gates on **2**. If a fourth leg is ever added it gates on 3. Re-verify the ordering against `interactions.gd:120-145` at implementation time; if the bank ever precedes variant resolution, every threshold shifts by one together — never one prop alone.

**Full quest block draft** (append; TAB indent):

```json
		{
			"_comment": "v0.16 P2 (#307). Giver is on pallass_forge and every route resolves on pallass_den_shop, so the unstick beat must name the den shop (the travel-landmark check arms when no producer map is the giver map).",
			"id": "ledger_eats_first",
			"title": "The Ledger Eats First",
			"region": "Pallass",
			"beats": [
				{ "id": "unstick", "description": "Get the held crate to its consignee at the den shop on the market tier — by the offices, by the forms, or on your own back.", "complete_when": { "loop_walked": 1 }, "complete_when_any": { "exemption_found": 1, "shipment_carried": 1 } },
				{ "id": "report", "description": "Tell the lift attendant at the forge-tier landing that his manifest is clean.", "complete_when": { "ledger_unstuck": 1 } }
			],
			"_resolution_order": "WEAKEST CLAIM FIRST (resolved_path is last-match-wins). All three co-bank -- nothing stops a player carrying the crate AND walking the offices AND reading the forms. Ladder: exemption > loop > carry. Carrying it moves one crate and leaves the loop exactly as it was; walking the offices produces a countersignature that works ONCE; finding the exemption fixes the rule itself, so the next crate never enters the queue at all.",
			"resolution_paths": [
				{ "accomplishment": "shipment_carried", "text": "You carried the crate down two tiers yourself and put it on her dock.", "grant": { "observed_things": 3, "befriended_moments": 2 } },
				{ "accomplishment": "loop_walked", "text": "You walked the offices in order and made the queue countersign itself.", "grant": { "persuaded_someone": 3, "heard_gossip": 4 } },
				{ "accomplishment": "exemption_found", "text": "You found the exemption that had been on the paper the whole time.", "grant": { "observed_things": 5, "deliberate_commerce": 2 } }
			]
		}
```

**Beat-description dash form is load-bearing.** The `unstick` description above uses a real U+2014 em-dash, NOT ASCII `--`. `data/quests.json` has ZERO `--` in any `beats[].description` or `resolution_paths[].text` today, and 11 shipped beat descriptions use a real em-dash (e.g. `chieftains_price` beat `close`). ASCII `--` renders as two literal hyphens in the journal, and `test_copy_fit.gd` measures width and page budget only — **nothing in the suite lints dash form**, so this ships green and wrong if it slips.

**`test_quests.gd` pins** — locals carry this lane's `p_` prefix (ruling C; a bare `var ledger` collides with Riverfarm's `flood_ledger` pin in the same function scope and stops the file parsing):

```gdscript
	# v0.16 P2: all three co-bank; the rule-level fix must outrank the one-off.
	var p_ledger: Dictionary = WIQuests.quest_by_id(shipped, "ledger_eats_first")
	assert(String(WIQuests.resolved_path(p_ledger, {"shipment_carried": 1})["accomplishment"]) == "shipment_carried", "a carry-only run still records the carry")
	assert(String(WIQuests.resolved_path(p_ledger, {"shipment_carried": 1, "loop_walked": 1})["accomplishment"]) == "loop_walked", "carried THEN walked the offices records the LOOP")
	assert(String(WIQuests.resolved_path(p_ledger, {"loop_walked": 1, "exemption_found": 1})["accomplishment"]) == "exemption_found", "walked it THEN found the exemption records the EXEMPTION -- the fix that outlives the crate")
```

> **BINDING TASK-2.4 HANDOFF (deferred quest-start effect).** `test_content.gd:1122-1124` reds any dialogue effect starting a quest id absent from `data/quests.json`, and Task 2.4's own gate list includes `test_content`, so Task 2.4 shipped the attendant's `"Somebody should unstick that."` option with only its `ledger_loop_started` effect. **Restore `{ "quest": "ledger_eats_first" }` as the FIRST entry of that option's `effects` array in `data/dialogue/pallass_lift_attendant.json`, in the SAME commit that splices the quest block** (one verb per dict — a second dict, never a second key). Without it P2 never starts, the journal never shows it, and every gate stays green. This is the exact shape of the Task 1.3 → 1.5 handoff.

- [x] **Step 0 (task-2.4 handoff):** Restore the `{ "quest": "ledger_eats_first" }` effect dict in `pallass_lift_attendant.json` per the block above, in this task's commit.
- [x] **Step 1:** Add the two props (if not already in 2.1) and splice the quest block.
- [x] **Step 2:** Add the `test_quests.gd` pins.
- [x] **Step 3: Verify the landmark arm.** `unstick`'s producers are all on `pallass_den_shop`; the giver map is `pallass_forge`; so the description MUST contain a token from `LANDMARK_TOKENS["pallass_den_shop"]` — it contains "den shop" and "market tier". Confirm `test_content.gd`'s `_validate_travel_beat_place_naming` passes rather than assuming.
- [x] **Step 4: Dash sweep (the lint no gate performs).** The plan mandates a both-forms dash rule and nothing in the suite enforces it, so run it by hand over everything this lane wrote:
  - `grep -n -- '--' data/quests.json` → the two new quest blocks must contribute **zero** hits in any `description` / `text` / `title` value. (`_comment` and `_resolution_order` values are author notes, never rendered — `--` there is fine and is what the drafts use.)
  - `grep -rn -- '--' data/dialogue/pallass_*.json data/maps/pallass/pallass_*.json` → same rule: zero hits inside any `text`, `observe`, `toast`, `*_toast`, `talk_pool`, `friendly_line` or `lines` value.
  - `grep -rn -P '\\u2014' data/maps/pallass/ qa/scripts/pallass_*.json` → em-dashes hide as `—` ESCAPES inside `data/maps/**` and QA scripts; sweep that form too, and check the at-most-ONE-em-dash-per-line rule on every hit.
  - Any file touched by this step is re-run through `test_copy_fit` before commit — a dash swap changes rendered width.
- [x] **Step 5: Run** `test_quests`, `test_content`, `test_reachability`, `test_copy_fit`.
- [x] **Step 6: Census check. Commit** `feat(quests): The Ledger Eats First, three real routes`.

### Task 2.7: The attendant's post-quest reactive stage

**Files:** Modify `data/maps/pallass/pallass_forge.json` (entity `lift_attendant`, `talk_pool_stages`)

**Ruling 8:** key on `ledger_unstuck`. **APPEND AFTER** the single existing stage `attendant_seal_resolved` (`seal_resolved`:1).

```json
{
 "id": "attendant_ledger_unstuck",
 "requires_accomplishment": { "ledger_unstuck": 1 },
 "lines": [
  "Manifest's clean. First clean manifest since the frost, and I have checked it twice for the pleasure.",
  "Her boy rode up with a jar for me. I told him the cage takes twelve. He asked if it takes jars.",
  "Down at the quarter bell, {addr}. Same as always. It just goes down lighter."
 ]
}
```

- [x] **Step 1: Shadow-out audit.** seal-resolved-only → `attendant_seal_resolved`; P2 done → the new stage permanently. The base pool is flavour, not guidance, so permanent shadowing is acceptable and is the shipped Riverfarm-headman pattern.
- [x] **Step 2: Run** `test_content` + `test_copy_fit`; **commit** `feat(pallass): the attendant's clean-manifest pool stage`.

---

## Task 3 — QA

Load `wi-writing-qa-scripts` before the first script. **Registration order is binding:** `qa/manifest.json` entry FIRST (anchored after the `pallass_walkthrough` entry, ruling C) → the matching `wandering_inn_game/AGENTS.md:201+` seed-table row (anchored after the `pallass_walkthrough` seed row) → `derive_qa_surfaces.py` (bare = write) → `render_qa_notes.py --write` (ruling E; bare does NOT write) → bare `render_qa_notes.py` as the check. `ci_sweep.sh` hard-fails at startup if the manifest and the AGENTS.md table disagree.

### Task 3.1: Fixtures

**All six derive from `qa/fixtures/spine_reach_start.json`** (ruling 6) — the only shipped fixture carrying `door_awakened` + `pallass_attuned` + `elevator_pass_stamped` together, plus the full monotone backbone (`door_awakened` → `door_understood` / `recovered_anchor_stone` / `bought_catalyst` / `door_mounted` / `door_study_sleeps == 3`; every `*_attuned` → `door_awakened`; `invrisil_attuned` → `blight_lifted` + the `invrisil_attunement_stone` IN INVENTORY; `blight_lifted` → `riverfarm_attuned`). Copy the file, then edit — never hand-author from the skill doc (its `"version": 3` is STALE; every shipped fixture is `"version": 5`).

| fixture | current_map / cell | build | extra accomplishments | serves |
| --- | --- | --- | --- | --- |
| `pallass_depth_gates_start` | `pallass_forge` [23,5] facing [0,-1] | `{"warrior":5,"mage":5}`, skills `["basic_cleaning"]` | **none of the lane's counters** | gate-proof script |
| `pallass_standards_talk_start` | `pallass_forge` [15,4] facing [0,-1] | `{"warrior":5,"mage":5}` | `saw_the_failed_temper`, `standards_commission_taken`; `started_quests` += `tempered_standards` | TALK route |
| `pallass_standards_skill_start` | `pallass_forge_hall` [4,4] facing [0,-1] | `{"warrior":5,"mage":5}`, `player_skills` += `appraise_goods` | as above | SKILL route (proves `MAP_REQUIRES["pallass_forge_hall"]`) |
| `pallass_standards_fight_start` | `pallass_forge` [15,4] facing [0,-1] | `{"spellsword":14}` + `seal_open_start`'s gear (`gnollish_hunting_knife`, `leather_jerkin`, `hedge_ward_charm`, `hunters_fang_talisman`) | as above | FIGHT route |
| `pallass_ledger_offices_start` | `pallass_forge` [23,5] facing [0,-1] | `{"warrior":5,"mage":5}` | `read_the_lift_manifest`, `ledger_loop_started`; `started_quests` += `ledger_eats_first` | TALK + HELP routes |
| `pallass_ledger_skill_start` | `pallass_den_shop` [7,3] facing [0,-1] | `{"warrior":5,"mage":5}`, `player_skills` += `appraise_goods` | as above | SKILL route (proves `MAP_REQUIRES["pallass_den_shop"]`) |

- [x] **Step 1:** For each, copy `spine_reach_start.json`, edit `current_map` / `player_cell` / `player_facing` (a 2-VECTOR like `[0,-1]`, never a string) / `classes` / `player_skills` / `started_quests` / `accomplishments` / `gold`.
- [x] **Step 2: Derive every `rng_state`** with `godot --headless --path wandering_inn_game --script res://tests/_derive_rng_state.gd -- <seed>`. **Never hand-type one** — `test_fixture_coherence.gd:378-388` fails any state under magnitude 1e6 as hand-typed.
- [x] **Step 3:** Add `MAP_REQUIRES` rows if Tasks 1.1/2.1 have not already (`pallass_forge_hall` and `pallass_den_shop` — a fixture standing in a new interior otherwise passes VACUOUSLY).
- [x] **Step 4: Run** `res://tests/test_fixture_coherence.gd` — expect PASS. Monotone chains and `MAP_REQUIRES` both bite here.
- [x] **Step 5: Commit** `test(qa): six Pallass depth fixtures off spine_reach_start`.

### Task 3.2: The seven canonicals

All at **seed 9** (the shipped Pallass seed for every existing Pallass canonical) unless the fight needs a seed search.

| script | fixture | tiers | what it proves |
| --- | --- | --- | --- |
| `pallass_depth_gates_check` | `pallass_depth_gates_start` | smoke, full | **the gate-proof leg.** Smith hub renders exactly 3 rows; attendant hub exactly 3; both clerk hubs unchanged; both `requires_skill` props render `locked_toast`; `assert_event_absent` on every lane counter. |
| `pallass_standards_fight` | `pallass_standards_fight_start` | full | **ruling 3.** Walk (15,4) → door → hall → **walk to the rig and INTERACT** → parley → `start_combat` → `combat_autoplay` → victory → `golem_recalibrated` → back out → smith report → `standards_tempered`. The parley node must be asserted (`ui_dialogue_shown`) BEFORE any `combat_started` — that ordering is the proof the encounter is interact-only. **Board screenshot in the windowed pass.** |
| `pallass_standards_skill` | `pallass_standards_skill_start` | full | bench `on_skill_use` → `temper_run` → exit → smith report → `standards_tempered`. **Also the no-ambush proof:** this route walks the hall's y=7 lane past the rig at [8,6] (crossing (7,7)/(8,7)/(9,7), every one of them inside a radius-1 hit) with `standards_commission_taken` HELD, so the encounter is present — and `assert_event_absent` on `combat_started` proves no proximity trigger exists. |
| `pallass_standards_talk` | `pallass_standards_talk_start` | full | notice → `read_the_examination_standard` → smith `broker` → `standards_brokered` → report → `standards_tempered` → teleport to `pallass_market` (18,4) → Grimalkin's new hub `text_variant` asserted + screenshotted. |
| `pallass_ledger_offices` | `pallass_ledger_offices_start` | full | lift down → market clerk `queue_notice_endorsed` → permit clerk `queue_notice_countersigned` → den shop door → keeper `loop_walked` → lift up → attendant `ledger_unstuck`. |
| `pallass_ledger_carry` | `pallass_ledger_offices_start` | full | **ruling 7 proof.** Pallet (19,4) → lift → dray rank (16,4) → den shop → dock → `shipment_leg_carried` reaches 3 in ONE waking → keeper `shipment_carried` → lift up → attendant `ledger_unstuck`. |
| `pallass_ledger_skill` | `pallass_ledger_skill_start` | full | consignment file `on_skill_use` → `exemption_found` → exit → market walk → lift → attendant `ledger_unstuck`. |

**Script idioms that are binding here:**

- `assert_event_logged` / `assert_event_absent` scan the WHOLE run, not since the last wait.
- Option selection: the key is `"option"` and it is **1-BASED**; a wrong key silently no-ops. The safer arrow idiom is `ui_dialogue_shown` → `move down N` → `press confirm`, counting VISIBLE options only.
- Pinning an `options` list compares the WHOLE array exactly (`qa/test_driver.gd:967-984` `_loosely_equal` is element-wise with a size check) — pin the 3-row hubs deliberately in `pallass_depth_gates_check` and nowhere else.
- A bare `wait_for_event ui_toast_rendered` never proves WHICH toast — always pair it with a `toast` event whose `payload_contains.text` is the exact string.
- Never put a `_comment` key inside `payload_contains`.
- `assert_state` on a MISSING path ERRORS — for never-banked counters use `assert_event_absent`.
- JSON coordinates parse as floats: `[5.0, 8.0] != [5, 8]` in GDScript. Write integers.
- Gray-band fights emit NO `won_combat` under challenge weighting — in `pallass_standards_fight`, pin `accomplishment_recorded {"id": "golem_recalibrated"}` and `victories`, never `won_combat`.
- Never pin toast ORDER across `combat_started`.
- Before adding any driver action, `grep '"<action>"' qa/test_driver.gd` — duplicate arms silently SHADOW. (This lane needs no new driver actions.)

- [x] **Step 1:** Write `pallass_depth_gates_check` FIRST — it is the cheapest failure detector for every gating decision in Tasks 1.3/2.4/2.5.
- [x] **Step 2:** Write the remaining six. Use `teleport` freely for legs whose route is not the subject; walk for real where the route IS the subject (the door crossings, the lift transitions, the carry legs).
- [x] **Step 3: Register each** in `qa/manifest.json` (`script`, `seed`, `fixture`, `note`, `tiers`) and add the matching `AGENTS.md:201+` seed-table row in the SAME commit.
- [x] **Step 4: Regenerate both generated artifacts in the SAME commit as the manifest change (ruling E).** In order:
  1. `python3 wandering_inn_game/scripts/derive_qa_surfaces.py` — bare IS the write (`:412-414` returns `cmd_write()` on empty argv); expect `wrote surfaces for N script(s)`, rc=0.
  2. `python3 scripts/render_qa_notes.py --write` — **the `--write` is mandatory.** Bare it only compares and returns 1, so a bare-only call leaves `docs/QA-SCRIPT-NOTES.md` stale and reproduces the #312 leak-check red.
  3. `python3 scripts/render_qa_notes.py` (bare) — the CHECK: rc=0 and `PASS: QA notes match manifest`.
  4. `python3 scripts/check_doc_drift.py`.
  - **Merge-train:** `render()` walks the whole manifest, so this file must be re-rendered at every train merge that combines two lanes' manifest entries. A green run on this branch does not survive the merge on its own.
- [x] **Step 5: Run each script** with `wandering_inn_game/qa/run_qa.sh <script> headless --seed=9`. Re-derive every pin from the real run's `qa_output/<script>/events.jsonl` — never assume a pin. "missing result.json" with rc=0 is a RED, never a pass.
- [x] **Step 6:** If `pallass_standards_fight` loses at seed 9, seed-search (it is a real task, not a retune): try the Pallass canonical seeds first, and remember PC death is an immediate DEFEAT even with a living ally.
- [x] **Step 7: Commit** `test(qa): seven Pallass depth canonicals + manifest, seeds, surfaces`.

### Task 3.3: Crossing re-gate

- [ ] **Step 1:** `wandering_inn_game/qa/ci_sweep.sh --touching data/quests.json,data/combatants.json,data/maps/pallass/pallass_forge.json,data/maps/pallass/pallass_market.json,data/dialogue/pallass_grimalkin.json` — **budget real time: `--touching data/quests.json` alone now maps to 20+ canonicals** via MONOLITH_SYSTEMS (GH#281). The skill doc's claim that it maps to ZERO scripts is OUT OF DATE.
- [ ] **Step 2:** Expect green on at minimum: `pallass_walkthrough`, `pallass_peek`, `pallass_round_trip`, `pallass_race_peek`, `pallass_watchgolem_loop`, `regional_work_loop`, `grimalkin_study_loop`, `parley_talkdowns_loop`, `parley_gates_check`, `spine_reach`, `mixer_alchemist_loop`, `trader_earn_loop`, plus the `quests.json` monolith set (`cisterns_*`, `crate_*`, `door_chain_*`, `horns_dig_*`, `invrisil_disagreement_*`, `missing_recruit_loop`, …).
- [ ] **Step 3: Subagent sweep idiom** — a full `ci_sweep.sh` cannot run foreground in one Bash call (the harness promotes it to background and strands a waiting subagent). Start it writing to a log with its own `rc=` echo, then poll with short foreground `sleep 60; tail -1 <log>` calls. **Settle the tree BEFORE launching** — a sweep started while edits continue yields a MIXED-STATE verdict; kill and relaunch.

---

## Task 4 — Windowed machine playtest

Load `wi-machine-playtest`. **Note:** a full `ci_sweep.sh` runs `qa/flush_artifacts.sh` first, which WIPES prior windowed PNGs — take the windowed shots AFTER the last full sweep, or re-take them.

Windowed shot list (run each with `run_qa.sh <script> windowed --seed=9`):

- [ ] `pallass_standards_fight` — **the forge_hall board mid-combat** (closes `docs/VISUAL-LOG.md:449-451` and `HANDOFF.md:86`; the v0.15 T5.1 blocked-cover fix means the arena's cover props now come from `biomes.json` `blocked_props` = `[forge_station, crate]` — eyeball that they render).
- [ ] `pallass_standards_fight` — arrival inside `pallass_forge_hall` (mood, lighting, the embers ambience, no flat-white).
- [ ] `pallass_standards_fight` — the `forge_temper_golem` rig on the map at [8,6] (tint separation from `forge_calibration_golem` on the tier below).
- [ ] `pallass_standards_talk` — Grimalkin's hub with the new `text_variant` (page split legibility, per the `forge_runes` orphan-page lesson).
- [ ] `pallass_standards_skill` — the temper bench skill toast.
- [ ] `pallass_ledger_offices` — arrival inside `pallass_den_shop` (the warm-vs-slate contrast the whole room exists for) and the keeper at the counter.
- [ ] `pallass_ledger_carry` — the receiving dock's third-leg toast.
- [ ] `pallass_depth_gates_check` — both 3-row hubs, to see with human eyes that nothing new leaked into them.
- [ ] Drain every finding to `docs/VISUAL-LOG.md`; strike the forge_hall board-screenshot item there.

---

## Task 5 — Post-quest life (summary)

Both reactive stages ship in Tasks 1.7 and 2.7. Restating the contract for the reviewer:

- ONE stage per giver, APPENDED AFTER the last existing stage (stages are last-match-wins and the placement is permanent).
- Keyed on the quest TERMINAL: `standards_tempered` for `forge_smith`, `ledger_unstuck` for `lift_attendant`.
- **NEVER** on `elevator_pass_stamped` or any counter implied by standing on the forge tier — `docs/CHOICE-LOG.md:349-361`, the b7 shadow-out adjudication.
- Both entities keep their base `talk_pool` (an entity with stages MUST have one).
- The den keeper and the forge apprentice get NO stage (census discipline; both are new entities whose base pools are already the post-quest voice). Noted as a deferred nicety.

---

## DEFERRED TO CLOSE PR

### `data/leads.json` rows — BLOCKED, do not add in this PR

`test_content.gd:78-101` `_validate_leads` checks EVERY `requires` **and** `hide_when` counter against `data/shipped_ids.json`'s `accomplishments` list, and that file is release-cut-only at `RELEASE = "0.15.0"`. Both rows below gate on counters this lane INVENTS, so adding them now reds `test_content` until `shipped_ids.json` is regenerated — which is off-policy mid-wave.

**Verified:** `chatted_with_forge_smith`, `chatted_with_lift_attendant`, `elevator_pass_stamped` ARE shipped; `standards_commission_taken` and `ledger_loop_started` are NOT. The `hide_when` side is what blocks both rows.

Add these VERBATIM to `data/leads.json` in the v0.16 close PR, after `shipped_ids.json` is regenerated at the tag:

```json
{ "id": "lead_tempered_standards", "requires": { "elevator_pass_stamped": 1, "chatted_with_forge_smith": 1 }, "hide_when": { "standards_commission_taken": 1 }, "lead_text": "The smith's reject bin is filling up with work that should have passed.", "place": "The forge tier, Pallass" },
{ "id": "lead_ledger_eats_first", "requires": { "elevator_pass_stamped": 1, "chatted_with_lift_attendant": 1 }, "hide_when": { "ledger_loop_started": 1 }, "lead_text": "One crate of tin has been held on the landing manifest three cycles running.", "place": "The forge tier, Pallass" }
```

Both `place` strings contain "forge tier", already a token in `LANDMARK_TOKENS["pallass_forge"]`, so the `_description_names_place` arm passes.

### Other deferrals

- The stale `AGENTS.md:349` / `:352` note calling the Pallass portal arrival **(4,7)** stays stale in this lane (ruling 10). The live value is **(4,8)**. Fix it in close-PR hygiene.
- `test_combat_visuals.gd:548-560`'s eight legacy under-floor board figures remain filed for v0.16 triage; not this lane.
- Reactive `talk_pool_stages` for `den_shop_keeper` and `forge_apprentice` — nice-to-have, deferred on census grounds.

---

## Danger list

Every risk from the Pallass recon plus the cross-cutting risks that apply, each with the step that mitigates it.

| # | Risk | Mitigation (task step) |
| --- | --- | --- |
| D1 | **Option-array pins are EXACT.** `_loosely_equal` compares arrays element-wise with a size check, so one new visible row reds `pallass_walkthrough` line ~1152 (attendant) and ~1258 (smith), and `grimalkin_study_loop` lines 22/39/55. | Every new hub option is `requires`-accomplishment gated (HIDDEN, not visible-locked) on a counter no shipped fixture holds — ledgers in 1.3 and 2.4; Grimalkin gets `text_variants` only (1.6); proven by `pallass_depth_gates_check` (3.2) and re-gated in 1.3 Step 6, 2.4 Step 4, 2.5 Step 5. |
| D2 | **Index-driven navigation breaks SILENTLY** — a new row shifts every index below it and the run confirms the WRONG row, failing somewhere later. | Same gating; plus 2.5 Step 5 re-runs `pallass_peek` (which does `move down 1` on Grimalkin's hub) and `pallass_walkthrough`. |
| D3 | **Census is at the ceiling and the slack is SHARED, not per-lane** (~383 chars total across four lanes; a normal Pallass `_comment` is 300–800 chars). Four lanes each spending the 450 constant overspends by ~1,350 chars and reds `leak-check` on the third and fourth merge. | Ruling B: this lane's constant is **112**, not 450 (`new _comment chars <= 112 + 0.1765 × new non-comment chars`); projected absolute lane total **2,977 chars**, stated in the PR body so the controller can sum four lanes before the train; `comment_census.py --check` after EVERY data-touching commit (1.1/1.3/2.1/2.4/2.6) **and re-run on the MERGED tree at every train merge**; final overshoot is owned by the wave-close PR, not this lane. Long rationale goes to QA `_comment`s and CHOICE-LOG (both exempt). |
| D4 | **Name collision:** spec filename `forge_hall.json` → map key `forge_hall` = the shipped ARENA id; `board_renderer.gd:445-448` resolves mood by arena id first, `data_lint.py:73-80` keys maps by file stem globally. | Ruling 1: stems are `pallass_forge_hall` / `pallass_den_shop`; deviation logged (8.1). |
| D5 | **P1 FIGHT could silently feed `bounty_forge_golem_cull`** (`data/bounties.json:357`, completes on `forge_golems_culled >= 2`). | Ruling 2: `on_victory` is `golem_recalibrated` ALONE, on a NEW encounter entity with a NEW combatant id (1.4); the entity draft's `_comment` records why. |
| D6 | **Crowded cells** — `pallass_peek` walks full perimeter laps (`x=0/25`, `y=2/9`) on BOTH 26×11 maps; `pallass_walkthrough` and `pallass_round_trip` walk the `y=9` lane end to end; 21 forge + 21 market cells are canonically asserted. | Ruling 9 placement space; per-cell justification tables in 1.2 and 2.2; `--touching` re-gate of both maps at 1.2 Step 4 and 2.2 Step 4. |
| D7 | **P2's giver is behind the permit wall** (`lift_attendant` on `pallass_forge`, reachable only via `elevator_pass_stamped`), while the offices are on `pallass_market`. | Ruling 6: every fixture derives from `spine_reach_start`; `MAP_REQUIRES` rows added for both interiors (1.1/2.1/3.1). |
| D8 | **No staged-lift engine affordance** — the Grand Lift is one boolean-gated prop pair. | Ruling 7: three `once_per_waking` props + `variants` thresholds + repeated `door_when` transitions (2.2, 2.6); proven by `pallass_ledger_carry` (3.2). |
| D9 | **No `elevator_pass_stamped` reactive stage may exist on the forge tier** (b7 shadow-out, CHOICE-LOG:349-361). | Ruling 8: stages key on `standards_tempered` / `ledger_unstuck` (1.7, 2.7), each with an explicit shadow-out audit step. |
| D10 | **Stale doc:** `AGENTS.md:349/:352` says the Pallass portal arrival is (4,7); it is (4,8). | Ruling 10: do not trust it, do not fix it here; recorded in DEFERRED. |
| D11 | **Worktree shadow** at `.claude/worktrees/mq-foti-wave/` doubles every repo-root grep. | Global Constraints: edit only the top-level tree. |
| D12 | **Headless hang** — a failed `assert` hangs forever; the unit suite can print PASS while hiding a swallowed SCRIPT ERROR. | Alarm-wrap every Godot call; the three-part verdict (nonzero-exit + `^PASS` + zero-noise grep) in Global Constraints and Task 7. |
| D13 | **Vacuous-gate lint** fires on any `*_when` written as a bare counter dict; the allowlist is EMPTY BY DESIGN. | All `encounter_when` / gate dicts in this plan are wrapped in `"requires"` (1.4, 2.2); `data_lint.py` runs at 1.1/1.2/2.1/2.2. |
| D14 | **A narrow gated window is a tuning target masquerading as a gate** — it reds on seed noise and encodes a band claim the harness cannot defend. Retuning a shipped capstone to make one fit reds other lanes. | Ruling A: the new cell is gated at the shipped stop-cell window **0.55–0.95** with `check_rounds`, like every other wave-scale cell. Band ordering ("measured strictly below the shipped forge golem at the same build") is proven by **recording both measured medians in the PR body** (1.4 Steps 5–6), never by narrowing the window. Only `forge_temper_golem`'s own stats move; Step 6 re-verifies the neighbouring cells inside their own unchanged windows. |
| D27 | **A `conversation` encounter that also carries `trigger_radius` ships GREEN and ambushes the player.** `wi_game.gd:341-366` fires `start_combat(ent_id)` directly at :365 on a proximity hit and never reads `conversation`; the parley arm exists only on the interact path (`interactions.gd:151-160`). Nothing in the suite rejects the pair. | The `forge_temper_golem` encounter draft (1.4) carries NO `trigger_radius` — interact-only, the shape all 33 shipped encounters respect. 1.4 Step 3 greps the finished map for `trigger_radius` and requires zero hits; `pallass_standards_fight` asserts the parley node before any `combat_started`; `pallass_standards_skill` walks the y=7 lane past the rig with the encounter present and `assert_event_absent`s `combat_started`. |
| D28 | **A wrong `speaker` string ships green as a character who renames himself mid-conversation.** The suite validates speaker PRESENCE only (`test_content.gd:959`); no test compares speakers across a graph's nodes. | Task 2.5's drafts freeze the verified strings — `"Tier Clerk"` (`pallass_market_clerk.json`) and `"Forge-Tier Clerk"` (`pallass_forge_clerk.json`) — and Step 2 re-derives the per-graph speaker SET after the edit, requiring a one-element list each. |
| D29 | **Carry-leg `variants` thresholds are off-by-one traps.** `variants` resolve at `interactions.gd:129-135` BEFORE the interact banks at `:138`, so a threshold equal to the leg index can never fire and the staged toast silently never renders. | The stated rule is **(leg index − 1)**, applied to BOTH carry props: `market_dray_rank` `when: 1` (leg 2), `den_shop_receiving_dock` `when: 2` (leg 3), and to any future leg. `pallass_ledger_carry` (3.2) pins each leg's exact toast text, which is what makes a dead variant visible. |
| D30 | **ASCII `--` in player-facing copy renders as two literal hyphens** and NO gate lints dash form (`test_copy_fit` measures width and pages only); em-dashes also hide as `—` escapes inside `data/maps/**` and QA scripts. | The `unstick` beat description uses a real em-dash, matching the 11 shipped ones and the zero `--` occurrences in shipped quest copy. Task 2.6 Step 4 is an explicit dash sweep over both forms across every file this lane wrote, with a `test_copy_fit` re-run on anything it changes. |
| D31 | **`test_combat_visuals` does NOT measure new ids** — `FIGURE_ROWS` has four entries and `_board_cells` would KeyError on any other sprite; the bar runs only over a fixed `audited` array holding no id from this lane. Reading its PASS as a figure-legibility result is a false green, and baking a derived figure number into a shipped `_comment` is an unverifiable claim that also costs census. | Ruling F: the plan states plainly that the row passes **by exclusion**; no figure number appears in any shipped `_comment` (1.4's combatant `_comment` was trimmed to the provable claim); the legibility read is the windowed shot list in Task 4; nothing is added to `audited` without first adding its sprite to `FIGURE_ROWS` with a re-derived row count, which this lane does not do. |
| D32 | **Four lanes appending after the same final row** in `moods.json` / `quests.json` / `combatants.json` / manifest `scripts[]` / the AGENTS.md seed table / three test consts is a designed-in four-way one-line conflict; and two lanes declaring `var ledger` in the SAME `test_quests.gd` function scope is a duplicate DECLARATION that stops the file parsing on the second merge. | Ruling C: every shared append has a NAMED anchor row this lane does not share (FILE OWNERSHIP table) — `pallass_forge` in moods, `price_of_a_favor` in quests, `forge_golem` in combatants, `pallass_walkthrough` in the manifest and seed table, `forge_calibration_golem_t5_sw14_solo` in `BESTIARY_CELLS`, `pallass_forge` in `LANDMARK_TOKENS` / `MAP_REQUIRES`. New test locals take the `p_` prefix: `p_tempered`, `p_ledger`. |
| D33 | **`docs/design/character-profiles.md` is SHARED, not exclusive** — Pallass and Invrisil both write it, and an EOF append from either lands in the same region. | Ruling D: the controller pre-landed stub section headers at the plan commit; Task 0.1 FILLS this lane's two sections IN PLACE (never at EOF) and Step 3b diffs the file to prove no hunk reaches the Hedault stub. Listed in the SHARED table. |
| D15 | **Every combatant needs a positive `power_level`** and every encounter needs `arena`/`enemies`/`allies`/`on_victory` explicitly (`"allies": []` included). | Drafts in 1.4 carry all of them; `test_combat_data.gd` at 1.4 Step 4. |
| D16 | **Seed/RNG blast radius** — any combat-data change can flip a canonical at its pinned seed. | 1.4 Step 7 full harness; 3.3 crossing re-gate; every fixture `rng_state` derived via `_derive_rng_state.gd` (3.1 Step 2). |
| D17 | **Fixture monotone chains** reject any hand-authored fixture that skips a beat, and `MAP_REQUIRES` fails a fixture standing on a gated map without its counters. | Ruling 6 copy-from-`spine_reach_start`; `test_fixture_coherence.gd` at 3.1 Step 4. |
| D18 | **`text_variants` shadowing** — an appended variant with a gate IDENTICAL to a shipped one silently shadows forever; any matching variant beats base text. | Explicit shadow audits at 1.3 Step 3, 1.6 Steps 1–2, 2.4 Step 2 — every new gate is a NEW counter no shipped fixture can hold. |
| D19 | **Effect dicts are an `elif` chain** — a two-key dict silently drops one AND CONTENT_FAILs. | Every effects array in this plan is `[{...},{...}]`; `test_content` at each dialogue task. |
| D20 | **`QA-SCRIPT-NOTES.md` and manifest `surfaces` are GENERATED**; a forgotten regen reds leak-check (the #312 red) — and a BARE `render_qa_notes.py` does not regenerate anything, it only checks and returns 1, so a "regen" step written bare is a silent no-op. | Ruling E: 3.2 Step 4 and Task 7 step 3 both run `render_qa_notes.py --write` then bare as the check, alongside bare `derive_qa_surfaces.py` (which IS a write) and `check_doc_drift.py`, in the SAME commit; re-rendered again at every merge-train merge. |
| D21 | **`POPULATION_FLOORS` is a subtraction tripwire** — window-gating an existing unconditional interactable drops the count. | This lane only ADDS unconditional entities; explicitly checked at 1.2 Step 2 and 2.2 Step 2. No floor edits. |
| D22 | **Moods are not gated** — a missing `moods.<map_id>` row renders flat white at every phase and NO test catches it. | Mood rows are checkbox steps at 1.1 Step 3 and 2.1 Step 3, and eyeballed in Task 4. |
| D23 | **`--touching data/quests.json` maps to 20+ scripts**, not zero (the skill doc is stale). | 3.3 Step 1 budgets the time explicitly. |
| D24 | **A full sweep wipes windowed PNGs** (`flush_artifacts.sh`). | Task 4's header: windowed shots come AFTER the last full sweep. |
| D25 | **Save-compat:** a new blocking entity on a previously-walkable cell can trap a save loading there. | Both new doors' four neighbours verified open (1.1, 2.1 arrival sections). |
| D26 | **Shared files across four lanes** (quests, combatants, moods, manifest, AGENTS.md, three test consts, character-profiles, CHOICE-LOG, VISUAL-LOG). | FILE OWNERSHIP section: NAMED anchor rows per file (ruling C, see D32), `splice_json.py` for shipped JSON, in-place stub fills for character-profiles (ruling D, see D33), merge-train resolves; `shipped_ids.json` never regenerated here. |

---

## Task 6 — Choice log

### Task 6.1: Drain every fork to `docs/CHOICE-LOG.md`

- [ ] Append one entry per controller ruling applied — the lane rulings 1–10 **and** the wave rulings A–F (A: 0.55–0.95 gated cells with medians in the PR body; B: the 112 per-lane census constant and the projected lane total; C: named shared-append anchors and the `p_` local prefix; D: character-profiles filled in place; E: `render_qa_notes.py --write`; F: new ids are not measured by `test_combat_visuals`) — plus every design fork taken during implementation (map stems, biome choices, the ladder orders, the loop's two intermediate counters, the interact-only encounter shape, the leads deferral, cut/keep calls under census pressure). Never a user gate — the spec's line 180 is explicit.

---

## Task 7 — Verification gate (the `wi-verifying-changes` bar)

Load `wi-verifying-changes`. **Settle the tree first.** Run in this order and report PER SCRIPT — never "everything passed".

- [ ] **1. Structural data lint:** `python3 wandering_inn_game/scripts/data_lint.py` (from repo root). This is NOT pytest and there is no `scripts/tests/test_data_lint.py` in this layout.
- [ ] **2. Comment census:** `python3 scripts/comment_census.py --check` — must exit 0. Record the new DATA ratio.
- [ ] **3. Guidance + doc drift:** `python3 scripts/sync_agent_guidance.py`, then `python3 scripts/render_qa_notes.py --write` followed by a bare `python3 scripts/render_qa_notes.py` as the check (ruling E — bare alone never writes), then `python3 scripts/check_doc_drift.py`.
- [ ] **4. QA surface drift:** `wandering_inn_game/scripts/derive_qa_surfaces.py --check` — FATAL on any stale tag.
- [ ] **5. Load gate / headless smoke** per the skill's chosen set for a data wave.
- [ ] **6. Every `tests/test_*.gd`**, each alarm-wrapped at 240s, each requiring ALL THREE of: exit code checked, a `^PASS` line present, and a zero-hit grep for `SCRIPT ERROR|Parse Error|WARNING`. Minimum set that MUST be green: `test_content`, `test_dialogue`, `test_quests`, `test_reachability`, `test_combat_data`, `test_combat_visuals`, `test_fixture_coherence`, `test_copy_fit`, `test_effect_text`, `test_world_visuals`, `test_audio_data`, `test_portals`, `test_shipped_ids`.
- [ ] **7. `sim_combat_batch.gd`** alarm-wrapped at 600s, same three-part verdict. Record the new cell's win/median and the three neighbouring Pallass cells'.
- [ ] **8. Full `qa/ci_sweep.sh`** (all canonicals at pinned seeds), run via the log-and-poll idiom, `CI_SWEEP_TIMEOUT=300` if any script needs it.
- [ ] **9. Windowed pass** (Task 4) AFTER step 8, since the sweep flushes artifacts.
- [ ] **10. Re-run steps 1–2** immediately before opening the PR — a late `_comment` edit is exactly how the census tips.

---

## Exit criteria

- [ ] Both quests exist in `data/quests.json` with three REAL routes each (distinct fiction, distinct counters), `_resolution_order` notes, and weakest-first `resolution_paths`; `test_quests.gd` carries co-bank ladder pins for both.
- [ ] Both interiors exist, each ≤ parlor scale, each hosting ≥1 quest beat and ≥3 non-quest observables with real toast copy, each with a `data/moods.json` row, a `LANDMARK_TOKENS` row and a `MAP_REQUIRES` row, walk-in only (no portal surface — the carrier-vs-row audit in `test_portals.gd:32-65` never sees them).
- [ ] Both arrival cells hand-verified in BOTH directions; every new blocking cell has open neighbours.
- [ ] P1's FIGHT banks `golem_recalibrated` and nothing else; `bounty_forge_golem_cull` is provably unfed (`assert_event_absent` on `forge_golems_culled` in `pallass_standards_fight`).
- [ ] `forge_temper_golem` carries a positive `power_level`; its `BESTIARY_CELLS` cell is gated at the standing **0.55–0.95** stop-cell window with `check_rounds` (ruling A) and passes; the PR body records the measured win rate and median rounds for the new cell **beside** `forge_calibration_golem_t5_sw14_solo`'s at the same build, showing the new rig strictly below it — that table is the band-ordering evidence, not the window. No shipped combatant's stats moved.
- [ ] The `forge_temper_golem` encounter entity carries **no `trigger_radius`** (`grep -n trigger_radius data/maps/pallass/pallass_forge_hall.json` returns nothing); `pallass_standards_fight` asserts the parley node before `combat_started`, and `pallass_standards_skill` crosses the rig's radius-1 footprint with the encounter present and `assert_event_absent`s `combat_started`.
- [ ] `test_combat_visuals` is green and is reported as **passing by exclusion** (ruling F) — no id from this lane is in `audited`, no sprite was added to `FIGURE_ROWS`, and no figure number appears in any shipped `_comment`. The rig's legibility read is the windowed shots.
- [ ] Both clerk graphs report a ONE-element speaker set after the edit: `Tier Clerk` for `pallass_market_clerk.json`, `Forge-Tier Clerk` for `pallass_forge_clerk.json`.
- [ ] The Task 2.6 dash sweep is clean over both `--` and `—`-escape forms across every file this lane wrote; the `unstick` beat description carries a real em-dash.
- [ ] Both carry-leg variant thresholds follow (leg index − 1): `market_dray_rank` `when: 1`, `den_shop_receiving_dock` `when: 2`; `pallass_ledger_carry` pins each leg's exact toast, so a dead variant fails loud.
- [ ] `docs/design/character-profiles.md`'s two Pallass stub sections are filled IN PLACE, the STUB parentheticals removed, and the diff touches nothing at or past the Hedault stub (ruling D).
- [ ] Every shared append landed on its NAMED anchor row (ruling C), and the two new `test_quests.gd` locals are `p_tempered` / `p_ledger`.
- [ ] A QA script fights the `forge_hall` arena on the board and the windowed run screenshots it; `docs/VISUAL-LOG.md:449-451` and `HANDOFF.md:86` are struck.
- [ ] Grimalkin's hub option array is byte-identical to `main`; the smith and attendant hubs still render exactly 3 rows at `near_pallass`.
- [ ] Seven canonicals registered, surfaces regenerated, seed-table rows added, `QA-SCRIPT-NOTES.md` regenerated **with `render_qa_notes.py --write`** and verified with a bare run (ruling E) — all in the commits that changed the manifest.
- [ ] Both givers carry exactly one new reactive `talk_pool_stage`, appended last, keyed on the quest terminal.
- [ ] `comment_census.py --check` exits 0; `data_lint.py` green; every unit suite green on the three-part verdict; full `ci_sweep.sh` green.
- [ ] `docs/CHOICE-LOG.md` carries every ruling and fork; `data/leads.json` is UNTOUCHED and the two row drafts sit in this doc's DEFERRED section.
- [ ] PR opened against `main` from `issue/307-pallass-depth`, body per the issue-close template, head commit tagged `[ci-full]`, `Closes #307`.
