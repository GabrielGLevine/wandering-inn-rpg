# a9 — Import/Export Save in Settings (#246; user directive 2026-07-19)

Goal: two Settings rows. **Export Save** dumps the Continue-slot save
to a file the player keeps; **Import Save** picks a file, validates,
installs to the Continue slot. Cheap backup + cross-platform transfer
(itch html5 ↔ desktop), zero server infrastructure.

## Mechanism map (recon verified)

- Save truth: `Game.SAVE_DIR = user://saves`, Continue slot =
  `manual.json`; `Game.load_slot(slot, reason)` is the validating
  loader (routes `WISave.apply()` — version window 2..7 + migration +
  per-key type guards). Import reuses ALL of it: parse file →
  `WISave.apply()` on a probe/game → only on success write the file
  bytes to `user://saves/manual.json` (or apply directly + save).
  **Non-destructive contract: a failed import leaves the existing
  slot byte-identical.**
- Settings surface: `settings_panel.gd` `ROWS` const —
  **append-only contract**: the only index pins live in
  `qa/scripts/settings_loop.json` and update alongside (the file's own
  comment says so). Add "Export Save" / "Import Save..." rows; place
  before "Back" and re-derive settings_loop's pinned indices in the
  SAME commit.
- Export payload: the RAW slot JSON. Save-editing is a feature, not an
  exploit (single-player); `apply()`'s guards are the firewall. No
  signing. Suggested filename `wandering-inn-save-<times_slept>.json`.
- Import failure notice: its OWN copy ("That file isn't a Wandering
  Inn save this build can read.") — never the title screen's
  misleading "older version" line (the b4 trap).

## Platform seams

- **Web (PROTOTYPE FIRST — the real risk)**: `JavaScriptBridge` is
  already used (game.gd:134 QA seed read).
  - Export: build a Blob + anchor-click download via
    `JavaScriptBridge.eval` (no callback needed — fire and forget).
  - Import: create `<input type=file>`, read via FileReader, hand the
    text back through a `JavaScriptBridge.create_callback` — the
    async seam; the panel shows a "waiting for file" state and must
    survive cancel (no callback ever fires).
- **Desktop**: `DisplayServer.file_dialog_show` native save/open
  dialogs (macOS/Windows/Linux export templates); fallback to
  Godot `FileDialog` if the native call errors.
- Feature detect at row-render time: `OS.has_feature("web")` picks the
  path. If the web import half proves unshippable in-window, ship
  desktop + web-export only and HIDE the web import row (not greyed),
  follow-up issue.

## QA / verification

- Unit (test_save or test_sim_core): export-format → import-validate →
  `apply()` equivalence vs a direct slot load; corrupted file, wrong
  version, wrong-typed field → each refuses, notice copy returned,
  slot file untouched (byte-compare).
- settings_loop: new rows pinned (indices re-derived same commit).
- Web parity CI: headless Chromium job at minimum proves the new rows
  render and the export eval path doesn't crash; the true
  file-dialog round trip is a HUMAN gate (taste queue: real
  cross-device round-trip ask).
- Windowed read of the panel with the new rows.

## Execution order

1. Sim/core seam: export string getter + import validator
   (pure, unit-first — no UI).
2. Desktop dialogs + rows + settings_loop re-pin + notices.
3. Web bridge pair (export blob, import file-input callback).
4. Full bar → review → PR closes #246; taste-queue round-trip ask.
