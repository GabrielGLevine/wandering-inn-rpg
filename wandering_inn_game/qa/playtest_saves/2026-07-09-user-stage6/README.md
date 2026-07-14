# User playtest save archive — 2026-07-09, Stage 6+ (v0.4.x playtest)

Snapshot of the live save slots taken after reaching the Garden during the
v0.4.x human playtest, preserved so this exact position can be rebuilt after
future fixes.

| file | slot | note |
|---|---|---|
| `auto.json` | auto | THE live position (save v5, `garden_sanctuary`, [Spellsword] 11) — **carries the pre-fix finding-47 state**: ghost [Warrior] 7 + [Mage] 10 re-granted beside [Spellsword]; the load-time retired-line sanitize (added same day) strips them on next load. |
| `playtest.json` | playtest | debug Playtest-States slot (save v5) |
| `manual.json` | manual | old manual slot (save v3 — exercises the v3→v5 migration chain on load) |

## Restore

Copy the wanted slot back and Continue (or load from the pause menu):

```bash
cp wandering_inn_game/qa/playtest_saves/2026-07-09-user-stage6/auto.json \
  "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG v4/saves/auto.json"
```

Saves are forward-compatible by design: `WISave.VERSION` migrations compose
on load (`_migrated`), and load-time class sanitation heals retired-line
ghosts — restoring this archive after any future fix is expected to Just
Work. If a future save-format change ever breaks the chain, this README +
the versioned JSON here are the rebuild spec.

NOT a canonical QA fixture: it lives under `qa/playtest_saves/`, outside
`qa/fixtures/`, because fixture-coherence standards do not apply to an
organic player save.
