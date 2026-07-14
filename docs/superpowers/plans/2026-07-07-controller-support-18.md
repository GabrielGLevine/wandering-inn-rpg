# Controller Support (issue #18, M-STEAM) — Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development
> via wi-running-the-machine. Dispatch-grade tasks (repo convention).

**Goal:** full gamepad play (Steam Deck target): pad bindings on the existing
15 actions, a device-aware hint layer, pad paths for the two keyboard-only
blockers, and a pad slot-selection idiom for the hotbars.

**Architecture (grounded in the 2026-07-07 input-surface map):** every panel
already navigates via `move_up/down/left/right` + `confirm`/`cancel` actions
on hand-rolled cursor ints — ZERO Godot focus-chain usage. Pad support is
therefore additive InputMap joypad events on existing actions (NOT the
`focus_neighbor` retrofit issue #18's body guessed — this plan corrects the
brief, evidence: no `focus_*`/`grab_focus` anywhere in src/). QA safety
proven: `qa/test_driver.gd` injects physical `InputEventKey`s through the
same InputMap — additive joypad events cannot desync it.

## Global Constraints

- Existing keyboard play byte-unchanged: every current canonical stays green
  with zero script edits (except S3's deliberate copy re-pins).
- Automated QA cannot inject real pad events — pad-specific verification is
  a DOCUMENTED manual pass (checklist deliverable) + unit coverage of the
  new helpers; flag this honestly, never claim automated pad proof.
- Stats never player-visible; no em-dash overdraft in any new/edited copy.
- New player-facing strings route through the hint layer (S3), never a
  second hardcoded keycap literal.
- File collision note: `data/arenas.json` is lane-β's (D2, 8a) until it
  merges — S3 (which edits its tutor_lines) runs LAST; controller resolves
  any残 conflict at merge.

### Task S1 — pad bindings + the hotbar slot-selection idiom

**Files:** `wandering_inn_game/project.godot` (InputMap), `src/combat/combat_screen.gd`
(`_input_hotbar` arm), `src/world/world.gd` (field-hotbar arm).

Bindings (additive `InputEventJoypadButton`/`Motion` on EXISTING actions):
`move_*` = d-pad + left stick (Motion, axis 0/1, deadzone 0.5 — the held-move
repeat already polls `is_action_pressed`, so sticks inherit grid-step
movement); `interact` = A (btn 0); `confirm` = A; `cancel` = B (btn 1);
`inventory` = X (btn 2); `journal` = Y (btn 3); `cycle` = RB (btn 10);
`end_turn` = Start (btn 6). (`interact`/`confirm` share A safely — their
consumers are context-disjoint per the surface map; `end_turn` deliberately
NOT on A, it shares key E with interact on keyboard but pad separates them —
an ergonomics improvement, note it.)

Hotbar slots (`hotbar_1..9` are number keys — no pad equivalent): NEW
actions `slot_prev` (LB, btn 9) / `slot_next` (RB conflicts with cycle —
use LT/RT as Motion axis 4/5? NO: keep it button-simple, `slot_prev`=LB,
`slot_next`=RT btn... decision LOCKED: `slot_prev`=LB(9), `slot_next`=RB(10),
and `cycle` MOVES to LT (Motion axis 4 > 0.5) — targeting Tab-cycle and
slot-cycling are different modes so RB double-use was tempting but a
mode-dependent button meaning is exactly what confuses Deck players).
Keyboard gets `slot_prev`/`slot_next` on `[`/`]` (additive, undocumented-in-
hints optional). In `_input_hotbar` (combat) and the world field-hotbar arm:
`slot_prev/next` moves a visible selection (`_bar_index` in combat — it
already exists and highlights; world grows a `_field_slot_index` mirroring
it) and `confirm` activates the selected slot exactly as `hotbar_N` would.
Number keys unchanged.

**Verification:** full ci_sweep (keyboard untouched proof) + new unit-less
manual checks deferred to S4's checklist; headless smoke; test_combat_visuals
still green (hotbar highlight semantics reused, not reinvented).

### Task S2 — the two hard blockers (title gesture + name entry)

**Files:** `src/ui/title_screen.gd` (`_is_gesture_event` L68-73 — add
`InputEventJoypadButton` [pressed] to the accepted classes; Motion excluded,
stick drift must not skip the title), `src/ui/char_creation.gd` (name step:
prefill the name field with the existing everyman default the QA auto-skip
uses; `confirm` with a non-empty field proceeds — a pad-only player accepts
or edits nothing; keyboard typing unchanged. NO on-screen keyboard in v1 —
scope it out loud in the report as the deferred nicety).

**Verification:** `title_flow` + `char_creation` canonicals green unchanged
(they inject keys); a new unit-level check is impractical for raw event
plumbing — S4's manual checklist covers "boot to game with pad only, never
touching the keyboard".

### Task S3 — device detection + the hint layer (runs LAST — arenas.json contention)

**Files:** NEW `src/ui/input_hints.gd` (`WIInputHints`, presentation-only:
tracks last-seen input device class via `_input` on a high-priority node —
`InputEventKey`/`Mouse*` → "kb", `JoypadButton`/`Motion`-past-deadzone →
"pad"; emits a bus event `input_device_changed` {device}; static
`label(action)` returns the device-correct glyph text, e.g. "Enter"→"A",
"Esc"→"B", "Tab"→"LT", "I"→"X", "J"→"Y", "E"→"Start" (end turn),
"Arrows"→"stick", "number keys"→"LB/RB + A"). Swap ALL 14 code-side keycap
strings (the surface map's list is exhaustive — char_creation 169/179,
title 110, message_layer 189/289, journal 368, dialogue_panel 106, game.gd
41, targeting_controller 249, combat_hud 417/423/433/437) to compose
through `WIInputHints.label()`. Panels re-render hints on
`input_device_changed`. DATA strings (6: arenas.json tutor_lines 393/403/
431/441, relc_intro.json 186/189): rewrite copy DEVICE-NEUTRAL (e.g.
"press 1. That's your arm" → "your first move. That's your arm" — Relc
teaching verbs, not keycaps; "(Press I after this.)" → "(Check your pack
after this.)") and RE-PIN every canonical that asserts the exact text
(relc_tutorial, tutorial_flow, status_first_encounter at minimum — grep
qa/scripts for the strings). Voice-lint the rewrites.

**Verification:** new `tests/test_input_hints.gd` (label table kb+pad, device
classification incl. deadzone edge); full ci_sweep with the re-pins;
windowed shot of a combat hint line (controller reads kb-mode rendering).

### Task S4 — the manual pad pass + close

**Files:** NEW `wandering_inn_game/docs/design/pad-playtest-checklist.md` (boot-to-victory with
NO keyboard: title gesture, char creation accept-default, walk/interact/
dialogue cursor, inventory/journal, shop buy, combat full turn incl. slot
select + targeting cycle + dash confirm gate + line-skill direction pick,
sleep, save/load via pause). HANDOFF playtest-queue entry (user owns the
physical-pad/Deck pass — the harness cannot inject pad events, stated
plainly). VISUAL-LOG any glyph-render nits. Whole-#18 review + `Closes #18`
landing commit.

## Self-review

- Brief coverage: bindings ✓(S1), hints swap ✓(S3), "focus-navigation" ✓
  (satisfied by additive bindings on the existing cursor actions — evidence-
  corrected from the brief's focus_neighbor guess), targeting/dash pad
  coherence ✓(S1 idiom + S4 checklist), keyboard-QA-untouched danger ✓
  (S1/S2 zero script edits; S3's re-pins are deliberate copy changes),
  no-keyboard-assumed Deck framing ✓(S2 blockers + S4 checklist).
- Name/type consistency: `slot_prev`/`slot_next`, `WIInputHints.label()`,
  `input_device_changed` used consistently above.
