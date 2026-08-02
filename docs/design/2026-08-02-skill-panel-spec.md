# Skills Tab Redesign — design spec (build-ready)

Status: SPEC — user direction 2026-08-02 ("Skills list is a big long
hodgepodge; need passive/active/combat/exploration clarity"). Recon:
wf_b87d9109 skill-ui reader, verified vs main @ 7fe8b85. Scope: REBUILD
THE SKILLS TAB BODY, not a new panel (a standalone panel costs ~6 wiring
files vs 1; the journal already gives modal exclusivity, chip, chrome).

## The measured problem (real 7-class save, 2026-07-09-user-stage6)
- 46 rendered rows for 28 distinct skills — 18 duplicates from the
  spellsword inherits-closure walked per-group (`[Dangersense]` ×3).
- Grouped by CLASS only; contexts/ap_cost/field metadata that already
  drives both hotbars is ignored by the journal.
- The ✓ affordance lies on 41 of 119 catalog entries: 25 combat passives
  + 16 exploration-inert skills can be checked, ride hotbar_loadout, and
  appear on no bar ever. Checking one duplicate row flips all its twins.
- 30 of 119 descriptions sit behind an unsatisfiable used_skills reveal
  gate (fixed independently in wave-2, ruling 13).

## Rulings
1. CATEGORY is the outer axis; class becomes per-row provenance. Four
   buckets, derivable TODAY with zero schema change (dual-context skills
   appear once, in their primary-use bucket, with a "both" badge):
   - Combat — Active (contexts∋combat AND ap_cost>0) ......... 45
   - Combat — Passive (contexts∋combat, no ap_cost) .......... 25
   - Exploration — Active (field:true) ....................... 38
   - Exploration — Passive (rest) ............................ 16
2. DEDUPE with provenance suffix (" — Warrior L1" / " — Warrior, Mage").
   Budget: re-pin 4 QA scripts that pin skill_count, re-derive
   field_skills_loop/journal_history cursor indices (R1/R2 in recon).
3. DERIVE in the sim, once: enrich `_skill_entries` (wi_game.gd:1701)
   with `category`/`slottable`/`bar`/`ap_cost`/`mp_cost`/`icon` keys
   (seam 1a — array shape unchanged, payload pins survive). A data_lint
   check asserts the derivation agrees with the two existing hotbar
   filters (combat_hud.gd:336, wi_game.gd:978) — three copies of the
   rule collapse toward one in a follow-up, not the same commit.
4. CHECKBOX only on slottable rows (Combat-Active + Exploration-Active).
   Passive rows render a category glyph instead — the honest shape.
   Non-uniform rows are fine; `_clip_body_to_line_boundary` keeps its
   single-pitch assumption because rows stay one text line each.
5. PRE-REVEAL rows show name + category + icon; effect/description stay
   behind first use. (Category is not progression info; the reveal
   convention keeps its teeth where they matter.)
6. Navigation: one flat cursor through the categorized list (no second
   axis needed); category headings are non-focusable text rows.
   `_flatten_skill_ids` moves in lockstep with the new render order —
   it is the blast-radius epicenter (R1), treat re-pinning as part of
   the task, not fallout.
7. Effects glossary stays at the tab bottom, retitled "Effects you've
   seen" with the one-line per-fight framing (note 10 cure).
8. Esc-closes-journal ships in wave-2 independently (note 2).
9. The >9 field-slot ceiling: AUTO bar caps at 9 (currently uncapped —
   slot 10 is keyboard-unreachable, reproduced on the same save);
   the redesigned tab IS the curation tool that makes exceeding 9 the
   player's explicit choice. Own issue, same milestone.

## Contract traps to honor (from recon, all cited)
- ui_journal_shown payload: ADD keys only (R5); skill_groups heading
  strings stay, category headings ride a NEW payload key (R4).
- bb_escape on every display_name (R6). 4px tap/pan slop semantics if
  rows ever become Controls (R7). RichTextLabel scroll-reset semantics
  (R8); body_rect anchor for drag/tap drivers (R9).
- Loadout semantics: never filter hotbar_loadout on load (test_sim_core
  :2871 pins silent-drop); never "initialize" the loadout — that
  converts AUTO players to CUSTOM permanently (:2860, :2893).
- Emit-order contract: loadout_toggle → loadout_changed →
  ui_field_hotbar_rendered → ui_journal_loadout_rendered, synchronous
  (field_skills_loop pins the sequence).

## Sequencing
Before #134 Wave D lands (Druid adds 6 field skills — the 46-row case
worsens and more players cross the 9-key ceiling). Sized: one focused
wave (sim enrich + renderer rebuild + 4-6 QA re-pins + one new canonical
asserting category grouping + windowed machine-playtest read).
