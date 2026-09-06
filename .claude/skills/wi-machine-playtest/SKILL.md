---
name: wi-machine-playtest
description: Inspect a player-facing change through windowed gameplay and prepared playtest states.
---

# Machine-driven playtest

Read and follow `qa/MACHINE-PLAYTEST.md`; this skill routes it into delivery.
Run a windowed read after every player-facing wave and a representative rotation
at milestone close. Include the newest feature plus dark, map, and panel-heavy
surfaces as relevant; use the manifest and protocol rather than a fixed script
count.

Use the current private asset overlay and import it before judging art, mood,
overlap, or readability. If the working tree is mid-edit or dirty outside the
task, inspect a known exact tree in an isolated worktree. Capture evidence before
a later QA run or sweep replaces `qa_output`.

For each screenshot, read what a first-time player can actually see: intended
content present, text matches event payload, hierarchy and wrapping, art/action
semantic fit, scale/anchor/layering, dark-scene contrast, interaction affordance,
and placeholder quality. For map work, compare every drawn solid and invisible
blocked cell against map data, test doors from both sides, and capture separated
times to catch static NPCs. A screenshot cannot prove blocking by itself.

Keep the debug overlay off for feel captures. Use a separately named overlay-on
shot when state context helps diagnose the result. Live data reload is suitable
for value/copy tuning through save/load when the current implementation allows
it; image changes still require import, and ID migrations need full validation.

Rendered events and screenshots do not prove timing or input modality. For
touch, distinguish native emulated click, browser touchscreen tap, and physical
device observation. For animation/tween acceptance, preserve production delay
and capture motion/frame timing; TestDriver zero-delay paths are insufficient.

When the user must judge eyes, ears, or taste, prepare a named save/fixture that
lands at the surface and provide one line: load X, do Y, judge Z. Do not ask the
user to navigate there. Record visual findings in `docs/VISUAL-LOG.md` and live
blockers in `HANDOFF.md`; fix clear in-scope defects before closure.
