# Pad Playtest Checklist (issue #18, M-STEAM)

**Owner: the user.** The automated harness cannot inject real
`InputEventJoypadButton`/`Motion` events (`qa/test_driver.gd` only ever
injects physical `InputEventKey`s through the InputMap — see
`docs/superpowers/plans/2026-07-07-controller-support-18.md`'s Global
Constraints), so nothing in this checklist has been machine-verified. Every
gate below is a physical-pad pass a human runs with a real Xbox-layout
gamepad (or a Steam Deck) plugged in — a Steam Deck or Xbox-layout pad is
assumed throughout; a different layout's face-button letters won't match
but the positions (bottom/right/left/top face button) will.

**What HAS been verified automatically** (so this checklist can focus on
feel, not plumbing): the InputMap bindings compile and load cleanly
(`load_gate` + headless smoke, zero warnings); every existing keyboard
canonical in `qa/ci_sweep.sh` (58 scripts) stays green byte-for-byte with
the pad bindings added; `tests/test_input_hints.gd` proves the keycap-hint
label table and device classification (including the stick deadzone edge)
in isolation. None of that proves a human can actually complete the game
with a controller in hand — that's what this checklist is for.

## Binding reference (S1's locked table — `project.godot`)

| Action | Pad | Keyboard (unchanged) |
|---|---|---|
| Move | D-pad or left stick | WASD / arrows |
| Interact | A | Space / E |
| Confirm | A | Enter |
| Cancel | B | Esc |
| Cycle target | LT (left trigger, past deadzone) | Tab |
| Inventory | X | I |
| Journal | Y | J |
| End Turn | Start | E (shares the key with Interact; A and Start are
  deliberately separate on pad — an ergonomics improvement over keyboard) |
| Hotbar slot select | LB (`slot_prev`) / RB (`slot_next`), then A to
  activate | number keys 1-9 (unchanged; `[`/`]` also cycle slots on
  keyboard now, additive) |

There is **no on-screen keyboard in v1** — character creation's name field
is scoped out loud below, not silently missing.

## How to read a "PASS" here

Each line is something you should be able to do **without ever touching the
keyboard or mouse**. If a step requires reaching for the keyboard, that's a
FAIL — note exactly which step and file it under issue #18 (or a follow-up
issue if #18 is already closed) rather than silently working around it.

## Checklist

### Title → New Game → the field
- [ ] Boot the game. The title shows "Press any key" — press any FACE
  button (A/B/X/Y) on the pad. The gate advances to the menu. (A stick
  wiggle must NOT advance it — if it does, that's a real bug: S2 excluded
  `InputEventJoypadMotion` from the gesture check on purpose.)
- [ ] Move the menu cursor with the d-pad or stick (Up/Down) between New
  Game / Continue / Quit. Confirm New Game with A.
- [ ] **Character creation, race step:** move with d-pad/stick, confirm
  with A. Repeat for the gender step.
- [ ] **Character creation, name step:** the field should already show
  "Traveler" as real (non-greyed) text. Press A without touching anything
  else — the game should start with the PC named "Traveler". (This is the
  intended v1 experience for a pad-only player: accept the default, no
  typing. Confirm you were never blocked here.)
- [ ] In the field: walk with d-pad/stick in all four directions. Confirm
  the PC sprite turns to face the direction you're pushing.
- [ ] Walk up to any NPC or prop and press A (Interact). Confirm something
  happens (a toast, a dialogue panel, or a "nothing here" beat).
- [ ] Open a conversation (talk to an NPC with dialogue). Move the option
  cursor with d-pad/stick Up/Down, confirm a choice with A. If a line has
  a "▼ more" continuation hint, confirm the hint glyph reads "A" (not
  "Enter") and that pressing A pages through it.
- [ ] Press X to open the inventory. Confirm it opens, move the cursor,
  confirm equipping an item works, press B to close it.
- [ ] Press Y to open the journal. Confirm it opens and scrolls, press B to
  close it.

### Shop / economy
- [ ] Find a shop/stall conversation (e.g. a market stall) and buy
  something using only A (confirm) / d-pad (move cursor) / B (cancel).
  Confirm the gold total updates and no keyboard was needed.

### Combat — the full turn loop
- [ ] Start a fight (a wild encounter, a story fight, or Relc's spar).
  Confirm the hotbar readout strip shows PAD glyphs once you've touched
  the pad (e.g. "A move, ... act, Start ends turn" instead of "Arrows
  move, number keys act, E ends turn" — if it still shows keyboard glyphs
  after you've clearly used the pad, that's the device-detection swap not
  firing, a real bug).
- [ ] **Movement:** step the active unit with d-pad/stick directly from the
  HOTBAR resting state (no separate "move mode" to enter).
- [ ] **Hotbar slot select (the pad-only idiom, S1):** press LB/RB
  (`slot_prev`/`slot_next`) and confirm a highlight moves across the
  hotbar slots. Press A to activate the highlighted slot — confirm it
  behaves exactly like pressing the matching number key would (Attack
  enters targeting, a skill enters targeting, Dash arms the confirm gate,
  End Turn ends the turn).
- [ ] **Targeting cycle:** with Attack or a skill selected and multiple
  valid targets in range, hold/tap LT to cycle between them. Confirm the
  targeted enemy changes and the readout updates.
- [ ] **Confirm an attack/skill:** press A to commit to the highlighted
  target. Confirm the attack/skill actually resolves.
- [ ] **Cancel out of targeting:** press B while aiming. Confirm you
  return cleanly to the HOTBAR resting state with no AP spent.
- [ ] **Dash confirm gate:** select Dash (via slot_prev/next + A, or its
  number key). Confirm the readout shows a confirm/cancel prompt with pad
  glyphs (A confirms, B cancels) rather than getting stuck. Confirm A
  actually dashes, and — on a separate attempt — B cancels with no AP
  spent.
- [ ] **Line-skill direction pick:** select a line-effect skill (e.g.
  Flame Jet/frost line, whichever the PC's class has). Confirm you can
  cycle the aim direction with LT and see the friendly-fire preview
  update, then confirm with A.
- [ ] **End Turn:** press Start from the HOTBAR resting state (not A —
  confirm A does NOT end the turn; only Start does, per S1's deliberate
  interact/end_turn split). Confirm the turn actually ends.
- [ ] Finish the fight (win or lose) and confirm the victory/defeat banner
  reads "— A" (not "— Enter") and A actually dismisses it.

### Sleep / save-load
- [ ] Trigger a sleep beat (usually via an in-inn bed prop, Interact/A).
  Confirm it plays through without needing the keyboard.
- [ ] Open the pause menu (however it's reached in the current build —
  confirm the reach-path itself is pad-navigable) and save manually.
  Confirm the save succeeds.
- [ ] From the title, Continue into that save using only the pad. Confirm
  the world loads back in and you're not silently dropped to keyboard-only
  controls anywhere.

## Known, deliberately scoped-out gaps (not bugs — don't file these)
- No on-screen keyboard for character-creation name entry (v1 scope; a
  pad-only player accepts "Traveler" or must reach for the keyboard to
  customize it).
- Nothing here proves Steam Deck-specific chrome (trackpad, back grips,
  gyro) — only the standard button/stick/trigger layout every Xbox-layout
  pad shares.

## If something fails
File it against issue #18 (or open a follow-up issue referencing #18 if
#18 is already closed) with: which step, what you expected, what actually
happened, and whether the readout/hint text was showing kb or pad glyphs
at the time (a stale-glyph bug and a broken-binding bug look different and
need different fixes).
