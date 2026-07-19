# a8 — Journal tabs (#209) execution plan (2026-07-19, Fable)

The journal outgrew one scroll (Act / Quests / Completed / Postings /
Skills / Chronicle / Recent Messages in a single RichTextLabel — the a5
windowed shot shows it overflowing). Split into three tabs. This doc
turns the issue's feared "~40-script pin wave" into a bounded, mostly
mechanical change; execute it fresh (not at the tail of a marathon).

## The de-risking finding (READ FIRST)

`UI_JOURNAL_SHOWN`'s payload (journal.gd:330-353) already carries EVERY
section's data — `quest_lines`, `completed_quest_lines`, `skill_groups`,
`class_aspirations`, `skill_count`, `posting_*`, `delivery_*`,
`recent_count`, etc. — **independent of what's visually shown**. QA
scripts assert these PAYLOAD FIELDS, not the rendered layout.

**So if the tabbed journal keeps emitting the SAME full payload on
open, the ~20 scripts that only assert payload fields DON'T change.**
The pin wave is not 40 scripts — it is the ~3 that drive the *visible
body* or the *skill cursor*:

Census (23 scripts open the journal; grouped by exposure):
- **UNCHANGED — payload-field asserts only** (keep emitting full
  payload; optionally add `active_tab:"quests"`): board_loop,
  bounty_rank_loop, chronicle_loop, crab_cull_loop, delivery_loop,
  inventory_loop, level_up_loop, thicket_cull_loop, journal_skills,
  + the ~13 that just wait `ui_journal_shown`/toggle.
- **CHANGED — drive the SKILL cursor** (must switch to the Skills tab
  before cursoring): **field_skills_loop**, **journal_history**
  (`ui_journal_loadout_rendered` + `cursor_index`).
- **CHANGED — drive the visible BODY** (drag-scroll, a4 #216 slice 2):
  **journal_history**'s new drag leg — re-target to the tab whose body
  overflows (Skills or History), or assert scroll on the Skills tab.

Net: ~2-3 scripts get real edits; the rest are no-ops or a one-field
add. The hardened sweep (#256/#258, merged today) now FAILS a
quit-mid-run or bare-`ERROR:` script, so a botched journal canonical
can't false-green — the exact safety net a pin wave needs.

## Tab layout

Three tabs (the issue's minimum), each a slice of the current body:
1. **Quests** (default): Act header/beats + Quests + Completed +
   Postings. The "what am I doing now" surface.
2. **Skills**: the Skills section + the cursor/loadout swap mechanism.
   The ONLY interactive tab (cursor only navigates when it's active).
3. **History**: Chronicle facts + Recent Messages. The "what happened"
   surface (also emits `UI_CHRONICLE_RENDERED` as today).

## Implementation

- Split `_build_body_text` into `_build_quests_tab` /
  `_build_skills_tab` / `_build_history_tab` (each returns its text +,
  for Skills, the cursor_line). The active tab's text → `_body_label`;
  the drag-scroll (a4 #216) is unchanged.
- Tab bar: 3 labels above the body; keyboard `move_left`/`move_right`
  (or a `tab` action) switches; TAP the labels (rect hooks + a
  `click_journal_tab` driver action, mirroring the credits/playtest tap
  pattern shipped this session). Default = Quests on every open.
- The skill cursor (`_cursor_index`, `_flat_skill_ids`) is LIVE only on
  the Skills tab; `move_up`/`move_down`/`confirm` route to the tab
  switcher on non-Skills tabs, to the cursor on Skills. Reset the
  cursor when leaving/entering the Skills tab.
- Payload: keep every current field; ADD `active_tab` and emit
  `UI_JOURNAL_SHOWN` on tab switch too (so QA can assert the visible
  tab) — but the section-DATA fields stay full/tab-independent so
  existing pins survive.
- Panel size: the body shrinks (one tab's worth), so it likely fits
  WITHOUT the drag-scroll on Quests/History; Skills may still scroll
  for a large kit — keep drag-scroll.

## QA

- `journal_history`: after open (Quests default), add a tab-switch to
  Skills BEFORE the existing skill-cursor leg (the loadout pins move
  behind that switch); re-target the drag-scroll leg to the Skills tab
  (or History) body. Its full-payload assertion on `ui_journal_shown`
  is unchanged.
- `field_skills_loop`: same — switch to Skills before the cursor leg.
- NEW small canonical `journal_tabs_loop` (or fold into journal_history):
  open → assert `active_tab:"quests"` → tap each tab → assert
  `active_tab` flips + the tab's own body pin → keyboard switch parity.
- Everything else: re-run the sweep; the ~20 payload-only scripts
  should pass untouched (if any fail, it's a payload regression, not a
  pin — fix the payload, not the pin).

## Order

1. Split builders + tab state/switcher (no QA yet) → boot clean.
2. Tab bar + keyboard/tap switching + rect hooks + driver action.
3. Re-pin journal_history + field_skills_loop (the 2 cursor scripts);
   add journal_tabs_loop.
4. Full sweep — confirm the ~20 payload-only scripts pass untouched.
5. Windowed read of all three tabs. Review (skill-cursor-only-on-Skills
   contract, tab-switch event, default-tab-on-reopen). PR closes #209.
