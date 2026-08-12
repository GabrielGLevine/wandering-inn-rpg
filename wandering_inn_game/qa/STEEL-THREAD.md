# Steel-thread playtest

Run from the repository root:

```bash
wandering_inn_game/qa/run_qa.sh steel_thread windowed --seed=9
```

One continuous playthrough: a single PC from the title gate to the GDI
epilogue, in true act order, with every transition earned in-game. The
continuity contract is mechanical: the script contains **zero**
`install_fixture` and **zero** `teleport` steps —

```bash
grep -c '"teleport"\|"install_fixture"' wandering_inn_game/qa/scripts/steel_thread.json  # must print 0
```

Manual, non-sweep instrument; deliberately absent from `qa/manifest.json`.
Album lands in `wandering_inn_game/qa_output/steel_thread/`. Captures hold
240–300 frames; combat plays live through `combat_autoplay`. Rebuilt
2026-08-11 (user directive): the previous stitched album (6 fixture loads,
17 teleports, four incompatible PC iterations, regions played before the
warren) is superseded; git history retains it.

Measured headless wall time at seed 9: **~55s** (clean pass; red runs
stall on timeouts). `events_seen` across two consecutive runs:
9950 / 9954.

## What this instrument is for

Judging narrative pacing, leveling progress, reachability reasonableness,
and overall progression from a single realistic playthrough. The PC's
trajectory (classes/levels/gold at each act boundary, below) is itself a
deliverable — lumps, grinds, and dead spots are findings, not bugs to
hide.

## Ordered scene list (true act order)

1. Title gate, title menu, creation (drake_f, Silver, hints on)
2. Act I — Arrival: inn opener, inn sign, Relc's classless spar, first
   sleep → [Warrior], spear gift + equipment, gate-road ambush, Liscor
   arrival
3. Act II — Make a Place: Pisces' magic lessons, sleep → [Mage], Erin's
   errand (reward kept — the spine needs the coin), Krshia's crate
   (fight path), the cisterns nest (fight path), reports, sleep → tremor
   pointer
4. Act III — What Stirs Beneath: Zevara's summons, sewer fissure, deep
   tunnels, Raskghar scouts, warren mouth, Relc's veto, awakened boss,
   report, post-seal sleep
5. Act IV — What the Door Opened: the Watch-notice delve (Horns in the
   gallery, Ksmvr's plates, vault construct, the sealed door), report;
   Ceria's dig (ruin camp, guardian, rune plates, the reveal), the haul
   and the mounting; Pisces consult, Krshia's catalyst, three attunement
   sleeps → the Door awakens; Riverfarm (witch hollow, mediated debt,
   longhouse{, night watch — see Dropped/kept below}); Invrisil
   (Hedault's reading, the Brothers' job, Coyle exposed); Pallass
   (papers, Grimalkin's examination, forge tier); the descent ask
6. Act V — What the Seal Was Feeding: dungeon attunement sleep, the Door
   to the dungeon, the cleared halls, the two readings, the choice
   (opened), the Seal Warden, the vault, anchor, tally, the walk back,
   final sleep, GDI epilogue

## PC trajectory at act boundaries (seed 9)

| Boundary | Classes | Gold | Waking |
|---|---|---|---|
| End Act I | warrior 1 | 2 | 2 |
| End Act II | warrior ~2, mage 1 | 8 | 4 |
| End Act III | warrior 11, mage 2 | 14 | 5 |
| End Act IV | warrior 12, mage 2, diplomat 4 | 12 | 8 |
| End of run | warrior 12, mage 2, diplomat 7, trader 2 | 12 | 10 |

Act IV gold ledger (three forced earning detours, all `GOLD/PACING`-tagged
in-script): 14 → … → 12; Zevara back-bounties +17, Wilovan courier +25
(only unlockable after `brothers_job_done`), Krshia potion buyback +18
(autoplay never drinks — the potions were dead weight). Pallass costs 46g
end to end.

## Deliberate choices (see docs/CHOICE-LOG.md)

- Reward fork: kept (spine purchases total 54g; earning detours are
  logged in-script with `GOLD/PACING` comments and are themselves
  pacing findings).
- Quest forks: crate + cisterns by force (leveling counters), halls by
  Ksmvr's plates (talk), the favor mediated, Coyle exposed, the seal
  OPENED — with the warden passed by the alcove's authored sneak-past:
  the run equips Zevara's moon_bone_amulet ([Invisibility], known-while-
  worn per the 2026-08-11 ruling) rather than fighting a measured
  2.5×-overweight fight. Epilogue renders 14 GDI lines.

## Dropped/kept coverage vs the stitched album

Dropped (were teleport-only "tolerant legs", off the continuous spine):
garden_sanctuary, barracks, runners_guild interiors. Kept on-spine: inn_upstairs seam, sewers, deep tunnels,
ruin, riverfarm village/hollow/longhouse, invrisil boulevard/alleys/
enchanter shop, pallass market/forge, dungeon, vault. Night-watch wolf fight
replaced by the track leg (night phase unschedulable on a portal route).

## Known limitation

`events_seen` may vary between identical seed-9 runs; `combat_autoplay`
victory pins are the completability proof and may flake under extreme
timing variance. If a windowed run reds on a victory pin, re-run once
before triaging.
