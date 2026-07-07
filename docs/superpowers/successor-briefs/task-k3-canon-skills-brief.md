# Task K3: canon Skill names + the new Skills + the [Rogue]-line class — Skills wave

## Goal
The capability table becomes shipped, CANON-NAMED Skills granted through
classes; the K1/K2 provisional names go canon; [Observe] is renamed; the
whole skill roster is audited against the user's naming principle. Runs
AFTER K2b (the loadout must exist before kits widen).

## Plan text (verbatim, `docs/superpowers/plans/2026-07-06-skills-wave.md` Task K3)
**Files:** data/skills.json + classes.json — wiki-verify + ship: movement
([Quick Movement]-class: field = brief speed state [move-repeat rate],
combat = +move pool), stealth ([Stealth] per K2 — which class? rogue-line
doesn't exist: TACTICIAN fits canon-adjacent scouting or a new earned
[Scout] class via exploration counters — wiki-check, escalate the class
call if ambiguous), perception ([Keen Eye]-class: field = reveal hidden
interactables glow + threat-range overlay [the Battlefield Awareness
overworld read from spec §3], combat = accuracy-adjacent via existing
fields), plus 1-2 utility from the table. Icons via glyph pattern; effect
lines generated (L1).
**QA:** field_skills_loop extension + kit asserts; harness re-check if any
combat numbers.

## USER RULINGS THAT BIND THIS TASK (HANDOFF "RESOLVED 2026-07-07" — apply, don't re-flag)
1. **[Stealth]'s class home (ruling 4, SUPERSEDES the plan's Tactician/Scout
   text above):** stealth belongs to a **[Rogue]-line class** — EARNED (the
   action-driven model: guile/stealth accomplishment counters), canon-checked
   name (wiki-verify [Rogue] itself is attested; if not, the closest attested
   rogue-line class), NOT Tactician.
2. **[Mage] may separately get [Invisibility] as a spell (ruling 4):**
   K3-OPTIONAL second stealth verb. Wiki-verify the spell. If it needs new
   sim machinery beyond a status/visual on existing machinery, QUEUE it
   (⚑ HANDOFF entry with a recommendation) rather than force it.
3. **Canon Skill names: research and decide, wiki-cited (ruling 5).** Every
   verdict carries its wiki citation in the report.
4. **[Observe] renames (ruling 9):** action-verb names read as generic
   **SUPERSEDED BY THE DECIDED CANON PACKET (Fable, 2026-07-07):** the wiki
research is DONE — apply `docs/design/k3-canon-verdicts.md` verbatim (it is
the binding naming source; every verdict carries its cite). Headlines:
[Rogue] attested (stealth home); sneak→[Stealth] (ORIGINAL-flagged, family
grammar); frost_touch→[Snap Freeze]; kindle→[Firefly]; observe→**[Appraise
Foe]** — [Owl's Vision] was checked and REJECTED (attested, but canon
function is night-vision, not a person-read); icy_floor→[Ice Floor].
The paragraphs below describe the research method — retained for context
only; do not re-run the research.

actions, not Skills. The user's exemplar is **[Owl's Vision] — VERIFY it
   is attested canon before using**; otherwise the closest attested
   perception Skill.
5. **GENERAL NAMING PRINCIPLE (ruling 9): a Skill name must never read as a
   plain action verb.** Audit the WHOLE roster against this bar —
   explicitly including `basic_cleaning`, `basic_cooking`, and the
   observe-class names — and flag (⚑ with a recommendation each) any that
   should follow. Renames you can wiki-ground, ship; ambiguous ones, flag.

## Wiki verification method (the gear canon pass is the exemplar)
- Fetch pages with WebFetch against `https://wiki.wanderinginn.com/<Page>`
  (e.g. `/Skills`, `/Classes`, character pages). The Skills/Classes list
  pages are the fastest attestation check; character pages confirm usage.
- Annotate every claim the way
  `docs/design/gear-staging/item-lore-and-accessory-roster.md` does:
  inline `[CANON-VERDICT <date>: CONFIRMED/REWRITTEN/ORIGINAL-kept — <what
  the wiki actually says>]`. Misses/ambiguities escalate as ⚑ flags with a
  recommendation; never silently invent a canon-sounding name.
- Treat wiki.wanderinginn.com as the ONLY lore source of truth.

## Design decisions already made
- **Rename DISPLAY NAMES (+ descriptions), KEEP INTERNAL IDS.** Skill ids
  live in saves (`player_skills`), fixtures (`near_ambush_sneak` grants
  "sneak"/"observe"), QA scripts, classes.json grants, and the
  `entity_first_use` verb-prefix dedup keys — an id rename is a save-compat
  break needing a migration. Ids are never player-visible (verify with a
  grep that no UI surface renders a raw id). Update `data/skills.json`'s
  `sneak` `_comment` to close K2's rename item and disclose the id/display
  divergence there.
- **The [Rogue]-line earn must dodge two traps:**
  (a) **Circularity:** the `gained_by` counters must be bankable WITHOUT
  already having [Sneak] (which no shipped class grants until this task).
  Build the earn from guile-flavored actions that exist classlessly — trace
  what actually banks today (grep accomplishments in `wi_game.gd`/data:
  the cisterns SCOUT path, crate SKILL/TALK paths, `persuaded_someone`,
  etc.) and/or add ONE new bankable guile action if nothing fits; escalate
  the final `gained_by` dict as a flagged call in the report.
  (b) **Onboarding integrity (K2's carried constraint, named in the sneak
  `_comment`):** the mandatory tutorial ambush (`goblin_encounter_1`,
  trigger_radius 2) must stay mandatory for a fresh player. Trace that the
  earn conditions CANNOT be met before that ambush (class grants only land
  at sleep; write the trace in the report — this is the wave's named
  design-tension, resolve toward onboarding integrity).
- **quick_movement / battlefield_awareness are LANDMINES — check the ledger
  for K4 first.** At K2's close they were unwired ghost skills, suppressed
  in L1's formatter and deliberately excluded from the combat dispatch by an
  `ap_cost > 0` gate in `skill_effects.gd` + `effect_text.gd` (see
  `task-k2-sneak-report.md`). K4 (ghost-skill wiring) may have run on
  2026-07-07 night and changed all of that. READ the current files and the
  ledger before touching either skill; if K4 wired them, build on the wired
  shape; if not, K3's [Quick Movement]-class movement skill must NOT
  silently un-suppress them (new skill entries with `ap_cost > 0` ride the
  existing gate safely).
- **[Keen Eye] field read is the heaviest machinery item:** reveal-glow +
  threat-range overlay are presentation on existing precedents (PC-light
  glow / water-shimmer overlay / tint machinery in `world.gd`; the sim side
  is a pure state + event). If it demands a genuinely new seam, ESCALATE in
  the report rather than inventing one — the plan's standing rule.
- **Equip/unequip while sneaking (K2 fix-wave flag, K3 rules on it):**
  recommended ruling — NOT a sneak-break (the inventory panel is modal, no
  exploit path; no canon precedent either way). Implement the ruling as one
  test pinning the non-break + a one-line note in the K2 doc block
  (CLAUDE.md or QA-SCRIPT-NOTES.md, wherever that block now lives). Disclose.
- New Skills arrive ONLY through classes (`gained_by`/level grants —
  existing machinery); icons via the glyph pattern; effect lines generated
  by L1's `WIEffectText` (add `EXPECTED_SKILLS` pins in `test_effect_text`
  for every new/renamed entry — pin exactly what the formatter generates).

## Hazards for the executor (exact-pin enumeration BEFORE editing)
- Renaming a display name moves every pin quoting it. Grep `qa/scripts/`,
  `tests/`, `data/`, and the docs for the OLD display strings ("[Sneak]",
  "[Observe]", "[Frost Touch]", "[Kindle]", plus anything else you rename)
  — known hot spots: grants-listing class toasts (`social_loop` pins
  "[Diplomat] class gained! — [Charming Smile], [Calming Touch]";
  `field_skills_loop`'s Tactician grant lists [Observe]), `test_effect_text`
  EXPECTED_SKILLS, journal/journal_skills payloads, the field-readout rows,
  stealth_loop's readout text. Update pins in the SAME edit; disclose every
  move (old → new).
- Any new combat number or kit change = combat-data change: run the balance
  harness (`tests/sim_combat_batch.gd`) AND the seed check — re-run every
  combat canonical at its pinned seed; a red may mean a seed re-derivation
  (a real task, not a one-value edit).
- classes.json changes ripple into `wi-adding-a-class-or-skill` territory:
  new class = new grants toasts, journal grouping, possible consolidation
  interactions — read that skill's checklist if it's loadable; if not, the
  minimum is: grants listed in the class toast, journal shows the class
  group, sleep-beat earn proven end-to-end in QA.
- New canonicals are FIXTURE-FIRST (ratified 2026-07-07): a new script
  (e.g. a rogue-earn loop proving earn → sleep → grant → sneak fielded)
  starts from a `near_*` fixture, not a long organic route. Author the
  fixture against `WISave` shape and LOAD it in a run before trusting it.

## Binding constraints
- Canon names wiki-verified with citations; misses escalate flagged.
- Visible currencies; stats hidden; OPACITY (no detection numbers — sneak
  stays binary; no accuracy percentages on [Keen Eye], "accuracy-adjacent
  via existing fields" means existing opaque fields only).
- Sim purity; zero-warning; GDQuest style; additive events only.
- Voice lint every new player-facing string (banned-tell list in
  `.claude/skills/wi-adding-dialogue-and-quests/SKILL.md`; skill
  descriptions follow the one-sentence house shape — see K2's fix #1).
- Commit `*.uid` for any new `.gd`.

## Successor safety rails (spelled out — do not skip)
1. **Ledger first:** `tail -40 .superpowers/sdd/progress.md` — confirm K2b
   landed, and check whether K4 ran (it changes this task's ghost-skill
   handling, above).
2. **Exact-pin discipline:** grep before edit; same-edit pin updates;
   report every pin old → new.
3. **Script registration is conditional on ARCH-1:** if
   `wandering_inn_game/qa/manifest.json` EXISTS it is the single source for
   script → seed → fixture — register there per its convention. Otherwise
   register in BOTH `wandering_inn_game/CLAUDE.md` lists AND
   `qa/ci_sweep.sh`'s CANON, counts bumped everywhere. Count, never trust a
   hardcoded number (49 canonicals / 17 unit files at K2 close).
4. **Alarm-wrap every run** (failed asserts HANG; macOS has no `timeout`):
   `perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot …`; kill >2min
   runs, read partial output.
5. **Zero-warning grep:** `SCRIPT ERROR|Parse Error|WARNING` on EVERY run's
   output, units included; never `^PASS` alone.
6. **Windowed shots must be READ** ([Keen Eye]'s glow/overlay and any icon
   work are visual claims); `qa_output/<script>/` is clobbered per re-run —
   copy PNGs out immediately, then look at them.
7. **Worktree-merge intersection rule:** file-map intersection vs
   `git status` AND live-lane reports before any copy-merge; re-gate the
   merged tree; in doubt serialize.
8. **NO-COMMIT implementers;** controller stages explicit lane-reported
   paths; never `git add -A` while a lane is live.
9. **CLAUDE.md sections by NAME** (freshly slimmed — line numbers are dead);
   per-script routing detail may live in
   `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` if it exists.

## Verification (FOREGROUND, alarm-wrapped, sequential — never background
## a run and wait; notifications cannot reach you)
1. `--import` + load_gate + smoke.
2. Units individually, grep discipline: test_sim_core, test_combat_sim,
   test_effect_text (renamed + new pins), test_content (vocab sweep over
   all new copy), test_save, test_progression (new class), plus any suite
   whose pins you moved.
3. Balance harness if ANY combat number/kit changed; then every combat
   canonical at its pinned seed.
4. field_skills_loop (extended), stealth_loop, social_loop, journal_skills,
   tutorial_flow (onboarding-integrity regression), + the new canonical(s).
5. Full `bash wandering_inn_game/qa/ci_sweep.sh`.
6. Windowed: the reveal glow + threat overlay, the renamed skill names on
   the bars/journal; copy PNGs to
   `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/k3-shots/`
   and READ them.

## Report contract
- NO commit, NO git add. Full report to
  `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/task-k3-canon-skills-report.md`:
  the canon-verdict table (every name, citation, verdict), the [Rogue]-line
  design (gained_by dict + the onboarding-integrity trace + the circularity
  check), the naming-audit ⚑ list with recommendations, the [Invisibility]
  ship-or-queue decision, every pin moved, harness results if run, gate
  table, shot names.
- Return only: status, one-line test summary, concerns.
