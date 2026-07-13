---
name: wi-debugging-playtest-reports
description: Use when a human playtest report contradicts green QA runs in the Wandering Inn RPG — "the door doesn't work", "I can walk through X", "nothing happens when I press Y" — or when any bug reproduces for a person but not for scripts.
---

# Debugging Playtest Reports

## Core principle
**When a human contradicts a green QA run, the human is right about the
experience and the QA is right about the logic — the bug lives in the gap.**
That gap is presentation, input, or perception. Find WHICH layer before
touching anything (no fixes without root cause).

## The layer-splitting procedure
1. **Prove the sim** — write a throwaway pure-sim probe (pattern below):
   construct `WIGame` directly, drive `move_player`/`interact`/state, print
   results. No autoloads needed; the sim is pure. If the sim is wrong, it's a
   real logic bug — stop here, fix in `src/core/**` through the machine.
2. **Prove the real input path** — a QA script with real key injection walking
   the exact reported scenario (assert `player_cell` after each move). QA
   injects genuine keyboard events; if this passes, input handling is fine.
3. **Then it's visual.** Capture windowed screenshots of the exact spots and
   READ them. Compare where things LOOK vs where they logically ARE. Measure
   pixels when eyeballing is ambiguous (PIL alpha-bbox scan of the sheet, or
   compare two same-frame references — never trust full-frame eyeballing with
   an offset camera).

## Known gap classes (check these first)
| Symptom | Likely cause |
|---|---|
| "Interact does nothing" but QA transitions fine | Player is a cell off from where they look — check sprite `anchor` vs frame padding (Body_A had 16px under-feet padding = a full cell) — or the target sprite is too small to find |
| "I can walk through X" | X is decor (non-blocking presentation), not an entity/blocked tile — solid-looking decor needs a blocked cell |
| "Standing ON a prop" | 2-cell-tall character occludes a 1-cell prop from below (correct y-sort, bad prop scale) |
| Works in QA, dead for humans | Tween/pacing code — presentation delay is 0 under TestDriver/headless, so QA literally cannot observe tween/bump behavior |
| Silent failure | Missing feedback affordance — every explicit input needs a visible response (it also localizes the NEXT bug report) |

## Pure-sim probe pattern (throwaway; delete after diagnosis)
```gdscript
extends SceneTree  # tests/probe_x.gd; run with --script, alarm-wrapped
func _initialize() -> void:
    var cfg := {"combatants": _j("res://data/combatants.json"), "classes": _j("res://data/classes.json"),
        "arenas": _j("res://data/arenas.json"), "quests": _j("res://data/quests.json"), "dialogue": {}}
    var g := WIGame.new(WISceneCatalog.compose(), _j("res://data/skills.json"),
        func(t, p): pass, 0, cfg)
    # drive g.move_player(...) / g.interact() / print(g.player_cell) here
    quit(0)
func _j(p: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(p))
```

## Rules
- Reproduce their exact report before theorizing; ask for the missing detail
  (which key, standing where) if you can't.
- One hypothesis at a time; the cheapest decisive evidence first.
- A plausible fix that helps is not necessarily the root cause — if the report
  recurs, go a layer deeper and measure (the door needed TWO passes: visibility
  fix, then the real anchor-offset root cause).
- Ledger the lesson + add the missing gap class to this table when you find a
  new one.

## Engine behavior in question? Read the source (user-sanctioned 2026-07-13)
When a bug hinges on what the ENGINE does (input ordering, PCK
enumeration, export flags, Control focus semantics), don't infer from
docs or probe blindly: `git clone --depth 1 --branch 4.7
https://github.com/godotengine/godot /tmp/godot-src`, grep the module,
cite file:line. Pin to the 4.7 branch — the installed engine is 4.7
stable.
