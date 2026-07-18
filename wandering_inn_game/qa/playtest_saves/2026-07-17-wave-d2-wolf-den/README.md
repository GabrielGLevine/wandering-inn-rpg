# Prepared Playtest State — 2026-07-17, Wave D-2 wolf den (#156)

Eye-gate position for the [Beast Tamer]/[Druid] wave (per the 2026-07-17
targeted-playtest directive: every targeted playtest request ships with a
prepared state).

| file | slot | note |
|---|---|---|
| `playtest.json` | playtest | Beast Tamer 3 facing the floodplains wolf den (10,22 → 11,22), [Lesser Bond] on hotbar 1 (save v6) |

What to look at from here:
- Press hotbar 1: tame the pup → wolf follower visual trails the player.
- Walk east to the crab nest (21,16), cast again: the refusal joke.
- The wounded corusdeer (33,9): soothe interact + [Beast's Mending] casts.
- Any goblin fight fields the wolf player-side; sleep at the inn — the
  bond PERSISTS (contrast: a raised skeleton fades).

## Restore

```bash
cp wandering_inn_game/qa/playtest_saves/2026-07-17-wave-d2-wolf-den/playtest.json \
  "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG v4/saves/playtest.json"
```

NOT a canonical QA fixture: fixture-coherence standards do not apply here
(it mirrors `qa/fixtures/near_tamer_bond.json`, which does hold that bar).
