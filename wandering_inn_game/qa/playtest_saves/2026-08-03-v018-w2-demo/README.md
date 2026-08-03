# System-bestowal prototype — 2026-08-03 (v0.18 W2, issue #347)

One state, five minutes, one question: **does being recognized land?**

This is the prototype from `docs/design/2026-08-02-dynamic-class-creation-spec.md`
(verdict: BUILD-REDUCED — authored classes selected by derived portfolio
predicates). The machinery derives and **logs**; it grants nothing. The
bestowal never reaches a player surface this wave, on purpose. What you are
judging is the **voice and the shape of the moment**, read off the log line —
the presentation (veil beat, copy, staging) is yours to rule on before anyone
builds it.

## Restore + launch — the flag is the whole point

The state ships as a QA fixture too, so the path to use is **Title → Playtest
States → `System Bestowal Demo`** (debug builds only). It installs into the
game's own dedicated `playtest` slot and loads it directly, so your saves are
untouched — nothing to copy, nothing to restore afterwards.

If you would rather come in through **Continue**, the target must be a slot
Continue actually scans, which is `auto` + `manual`/`manual_2`/`manual_3`
(`_newest_save_slot`, `src/ui/title_screen.gd`). `playtest` is **not** one of
them — copying there and pressing Continue silently boots your own newest save
instead, and the demo never loads. So this path OVERWRITES `manual`; back it up
first:

```bash
SAVES="$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves"
cp "$SAVES/manual.json" "$SAVES/manual.json.bak" 2>/dev/null   # no-op if you have none
cp "wandering_inn_game/qa/playtest_saves/2026-08-03-v018-w2-demo/system-bestowal-demo.json" \
  "$SAVES/manual.json"
```

The copy is the newest file afterwards, so Continue offers it. Restore with
`mv "$SAVES/manual.json.bak" "$SAVES/manual.json"` when you are done.

Launch **with the flag** — without it the table is never even read, and the
night is an ordinary quiet one:

```bash
WI_SYSTEM_BESTOWAL_LOG=1 /usr/local/bin/godot --path wandering_inn_game
# equivalent: /usr/local/bin/godot --path wandering_inn_game -- --system-bestowal-log=1
```

## Do

You wake in your leased room at the inn, already facing the bed. **Press
interact once** — that is the sleep. Nothing visible happens (correct: zero
player surface). Then press **F3** for the dev overlay and read the newest
line of the event tail:

```
system_bestowal_candidate id=system_bestowal_pacifist
```

The full line the sim logged, from the headless run of the same state:

```json
{"matched": true,
 "id": "system_bestowal_pacifist",
 "name": "Peacebinder",
 "arms": ["requires", "breadth", "absence", "excludes_classes"],
 "inputs": {"goblins_spared": 1, "heard_gossip": 3, "mediated_the_debt": 1,
            "persuaded_someone": 2, "resolved_wrong_order": 1, "won_combat": 2},
 "why": "You walked into quarrels that wanted blood, and left none behind you."}
```

The overlay's counters row under it is the same evidence from the other side:
this run talked its way through three quarrels, persuaded twice, and won two
fights ever — which is the ceiling the `absence` arm allows. One more victory
and this path closes (canon-true: paths close).

## Judge — the five things no agent can rule on

1. **The name.** `Peacebinder` is the proposal; the alternates in the table are
   `Gentle Hand` and `Quiet Diplomat`. Does any of them read as something a
   world would *name you*, rather than something a table offered? (All three
   are original noun phrases — wiki-checked 2026-08-03 against the canon class
   lists, no collision, so nothing here brushes the spoiler cutoff. They are
   proposals: a veto costs nothing, since no name has reached a surface.)
2. **The `why` line.** Second person, about the deeds, no progress language.
   Is that the register — the same unnamed voice that speaks in bracket lines
   under the sleep veil — or does it want to be colder and shorter?
3. **The trigger.** Three peaceful resolutions + two persuasions + gossip, with
   at most two lifetime victories. Does *that* portfolio deserve a class, and
   does it read as YOUR history rather than a checklist?
4. **Rarity.** Should this be reachable by a deliberate pacifist run (roughly:
   half of them), or should it be rarer than that — something most players
   only ever hear about?
5. **Staging.** The spec wants the real thing between the class-gain lines and
   the level chain, so the class arrives already at level 4–6 the same night
   ("you were already this thing; it just said so"). Is that the moment you
   want, or should the recognition stand alone with nothing else on screen?

## What is deliberately absent

- No class granted, no level chained, no toast, no veil line, no journal entry.
  The QA proof asserts those absences, so a leak reds a script.
- No `data/classes.json` record: the real feature makes these ordinary class
  rows with a `bestowed_by` block (spec §3.1). That file belongs to another
  lane this wave, so the prototype's table carries names only — no levels, no
  grants, no balance.
- No progress hint anywhere before the pillow. Opaque-until-sleep is the
  product here: the surprise IS the feature.
