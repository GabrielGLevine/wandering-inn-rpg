# Chronicle Design

> Status: **DONE**

## Goal

Preserve one results-only record of the latest completed run outside save data,
then show it as the journal's final section and a compact title-screen card.

## Approaches considered

1. **Pure facts → presentation persistence (selected).** `WIGame` derives a
   plain fact dictionary. `WIMain` captures it when `post_game` is banked and
   before returning to title. `WISettings` persists that dictionary in
   `settings.cfg`; journal and title render it. This keeps the sim pure and the
   cross-run record outside `save.gd`.
2. **Settings autoload reads `Game.sim`.** Fewer call-site lines, but it breaks
   `WISettings`' autoload-free testability and couples settings to runtime game
   state.
3. **Store the card in save metadata.** Rejected: New Game may replace save
   slots, and #91 explicitly requires cross-run persistence outside `save.gd`.

## Record contract

`WIGame.chronicle_facts() -> Dictionary` returns schema `1` with:

- `name`: sanitized protagonist name;
- `race`: title-cased protagonist race;
- `classes`: held class display names and levels in class-catalog order;
- `quests_completed`: completed authored quests in this run;
- `victories`: the run's `won_combat` accomplishment count;
- `sleeps`: `times_slept`;
- `ending`: `The seal holds. Liscor counts you among its own.`

These are achieved facts only. The card never names unvisited regions,
unearned classes, missing quests, percentages, or progress toward anything.

`WISettings.record_chronicle(facts)` stores a deep copy under
`[chronicle] latest` in `user://settings.cfg`. `latest_chronicle()` returns a
deep copy or `{}` when absent/invalid. New Game does not clear this section.

## Capture and rendering

- `WIMain` records when `accomplishment_recorded{id:post_game}` arrives. It
  also records a post-game sim immediately before `swap_to_title()`, so later
  free-play facts replace the earlier snapshot without depending on save I/O.
- The journal appends a `Chronicle` section only when the current run has
  `post_game`. It renders current-run facts, not a previous run's record.
- The title creates a non-interactive parchment card without changing `ROWS`,
  row indices, cursor movement, or selectable-row counts. It renders the latest
  persisted record after the gesture gate opens the menu.
- Both surfaces emit `ui_chronicle_rendered` with `surface` plus the complete
  fact dictionary. Existing `ui_journal_shown` and `ui_title_rendered` payloads
  retain their current fields and ordering.

## Layout and accessibility

The title card uses a container-built 420×150 panel anchored bottom-left, clear
of the centered menu and top ribbon. Copy is four bounded lines: heading,
identity, class line, ending/results line. The journal uses its existing
scrolling `RichTextLabel`; Chronicle is the last section. Text-scale steps,
keyboard/gamepad focus, mouse targets, and title rows are unchanged because the
card is read-only and `MOUSE_FILTER_IGNORE`.

## Verification

- Unit tests pin fact derivation, catalog ordering, exact ending, settings
  round-trip, deep-copy behavior, and absence before recording.
- A focused `chronicle_loop` loads a completed fixture, opens the journal,
  quits to title to capture, starts New Game, quits again, and proves the title
  card survived while all `title_flow` row counts remain unchanged.
- Windowed reads cover journal and title at 100% and 130% text scale.
- `title_flow`, `journal_history`, `arc_flow`, `settings_loop`, load gate, smoke,
  and the full composed sweep remain green.
