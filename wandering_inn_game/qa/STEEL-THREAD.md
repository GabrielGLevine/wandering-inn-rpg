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

Reauthored 2026-08-12 against the retuned game (#437/#441/#439/#440): the
itinerary now carries a leveling diet that arrives at each act's climax in
band, and every fight runs on the competent policy. 2568 steps.

Measured headless wall time at seed 9: **~4 min** to the Act V warden
(red runs stall on timeouts). Latest run: `events_seen` **10509**, 2447
of 2568 steps green — see "Open red" below.

## Every fight runs `policy: competent` (ruling, 2026-08-12)

`combat_autoplay` steps in this script all carry `"policy": "competent"`,
which drives the PC through `WICombatPolicies` (`qa/combat_policies.gd`)
instead of `WICombatAI`. The instrument now models a **resource-using
player** — the same reference the bands are tuned against
(`docs/design/balance-bands-and-policy.md`).

This is not a nicety, it is what makes the thread able to measure
progression at all. [Mage] 3+ levels on `spell_cast`, which only tallies
on a PC cast **in combat**; the floor policy never casts, so no
continuous run under `dumb` can level a caster past 2 however long it
plays. The pre-reauthor thread's Act III climax fought at combined level
**2** for exactly that reason.

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

## PC trajectory at act boundaries (seed 9, reauthored)

| Boundary | Classes | Combined | Band | Gold | Waking |
|---|---|---|---|---|---|
| End Act I (`reached_liscor`) | warrior 1 | 1 | 1–2 | 2 | 1 |
| End Act II (`cisterns_reported`) | warrior 5, mage 2 | 7 | 4–6 | 10 | 3 |
| End Act III (`raskghar_sealed`) | warrior 9, mage 2 | 11 | 8–10 | 16 | 4 |
| End Act IV (`seal_descent_agreed`) | spearmaster 14, mage 6, diplomat 4 | 24 | 12–14 | 4 | 8 |
| At the Seal Warden | spearmaster 14, mage 6, diplomat 7, trader 2 | 29 | 14–16 | 4 | 10 |

Climax builds (the number the bands actually govern — levels resolve in
`sleep()`, so a climax is fought at the *previous* night's build):

| Climax | Fought at | Band | Result |
|---|---|---|---|
| I gate-road ambush | warrior 1 | 1–2 | win |
| II cistern nest (+ matriarch) | warrior 5 / mage 2 | 4–6 | win, round 3 |
| III raskghar scouts (+ pack leader) | warrior 5 / mage 2 | 8–10 | win |
| III awakened boss (+ third scout, with Relc) | warrior 5 / mage 2 | 8–10 | win |
| IV vault construct | spearmaster ~12 / mage 3 | 12–14 | win |
| IV ruin guardian | spearmaster 12 / mage 3 + core shard | — | win |
| V seal warden | spearmaster 14 / mage 6 / dip 7 / trader 2 | 14–16 | **LOSS, round 5, warden 6/142** |

### The diet, per act (what was added and why)

- **Act I** — unchanged. Verified green under `policy: competent`; the
  retuned two-raider ambush is still a win at warrior 1.
- **Act II** — **one added night and one added fight**. The old thread
  walked from Krshia's counter straight to the grate and met the retuned
  nest at warrior 3 / mage 1: a three-round death. The reauthor adds the
  street's `supplier_scavengers` (5,16) — authored side content the
  stitched route walked past — and then a night at the inn. The night is
  the whole fix: `melee_hit` 23 and `won_combat` 3 were already banked
  and *unspent*, because levels only resolve in `sleep()`. One night
  converts them to [Warrior] 5 + [Mage] 2. Cost: 1 fight, 1 sleep,
  ~130 walked cells.
- **Act III** — **nothing added**. The Act II night carries the act:
  scouts, warren mouth and the Awakened all clear at warrior 5 / mage 2
  with Relc kept. (The veto solo fork stays untaken; #439 measured it at
  0.06.)
- **Act IV** — **no fights added; two rewards finally worn.** After
  Olesm's fifteen the run equips the vault's `construct_core_shard`
  (hp+3, damage reduction 1) — which is what turns the ruin guardian
  from a round-2 death into a win. This is #437's finding 7 (the
  carried-but-unworn upgrade) applied as route.
- **Act V** — the amulet comes on at the descent (see below).

Gold ledger: Act IV opens at 36 (Olesm 5 + 15, Zevara's three back
bounties +17, Selys's once-per-waking board pick +5, the Act II supplier's
+2) and closes at 4, with Pallass's 46g and the two 18g travel-stones paid
in full. All movements are `GOLD/PACING`-tagged in-script. The Krshia
buyback now sells **only** the vault tonic (+8), not the healing draughts
— see the [Second Wind] finding below.

## Deliberate choices (see docs/CHOICE-LOG.md)

- Reward fork: kept (spine purchases total 54g; earning detours are
  logged in-script with `GOLD/PACING` comments and are themselves
  pacing findings).
- Quest forks: crate + cisterns by force (leveling counters), halls by
  Ksmvr's plates (talk), the favor mediated, Coyle exposed, the seal
  OPENED.
- Act V kit: resonance capacity grows to 3 at the catalyst attunement
  sleeps, so the descent swaps the core shard off for Zevara's
  `moon_bone_amulet` (2) beside the ruin guardian's
  `guardian_ward_fragment` (1) — +6 HP, +1 damage, 1 damage reduction,
  and [Invisibility] in the kit. Under #440 the cloak is no longer a way
  *around* the finale: the run casts it, walks the alcove's trigger
  radius unheard, and spends the stance on `sneak_ambush` — the first
  turn of round 1, pinned by both the ambush toast and
  `combat.round == 1` at the PC's opening turn.

## Open red: the Seal Warden (2026-08-12)

The run is green from the title gate through the two readings, the
watcher beat, the cloaked approach and the ambush — 2447 of 2568 steps —
and then **loses the warden at round 5 with the warden on 6 of 142 HP**.
The 121 unrun steps are the vault, anchor, tally, walk back, final sleep
and epilogue, unchanged from the previously-green shipped tail.

This is a balance finding, not a scripting one, and it is reproducible:

- The build that arrives is **spearmaster 14 / mage 6 / diplomat 7 /
  trader 2 — 29 combined levels and 47 max HP**. The band table's Act V
  row assumes 14–16 *focused* (spellsword-shape). #437's 0.77 was
  measured on that focused build with tuned gear; the real spine arrives
  with twice the levels and two-thirds the stat efficiency. **Breadth,
  not level count, is what the Act V band is actually asking for.**
- **The consolidation gap is structural.** Spellsword needs warrior 10 +
  mage 10. [Warrior] evolves into [Spearmaster] at 10 on
  `spear_skill_used` dominance — with Relc's spear in hand from Act I,
  that is the only reachable shape — and the consolidation reads
  *warrior*, so it can never fire. Mage reaches 6, not 10, because the
  competent policy only casts when the cast out-damages the swing and a
  1.4×/2.0×/2.6× spear kit always beats a level-6 frost bolt. No sane
  diet reaches spellsword 14 on this spine.
- **[Second Wind] eats the pack.** The policy's survive step is
  "[Second Wind] if in kit and affordable, *else* the best carried
  draught", with one survive action per turn. [Second Wind] has no
  cooldown and no once-per-fight bound, so it is *always* the pick and
  the draught branch is unreachable for any holder. The run carried two
  8-HP draughts into the warden and drank neither; it healed 8 twice
  from [Second Wind] instead and died 6 damage short. Give [Second Wind]
  a bound (already filed) and the same fight has 16 more HP in it.
- **The survive-first rule costs the kill.** On rounds 4 and 5 the policy
  spent 2 AP on [Second Wind] and had only 1 left, so it swung
  [Piercing Strikes] (1.4×, 18–21) where the unspent turn affords
  [Spear Flurry] (2.6×, 39). Either round-5 flurry ends the fight. That
  sub-optimality is the tuning reference behaving exactly as specified —
  and it is worth the finale.
- Measured alternatives, all still losses at seed 9: amulet + moonhide
  fetish (warden 14 HP left); amulet + ward fragment (6 left); the same
  with an added `gallery_vermin_nest` detour in Act IV (58–61 left — the
  detour's rng draws reshuffle the warden's stream, they do not raise
  the build). No purchasable armour closes it either: the economy funds
  the spine's 82g of mandatory purchases with 4g to spare, and the two
  armours in the game cost 20 (peddler gambeson, damage reduction 1) and
  24 (Krshia's jerkin, hp+4) — each worth about 5 HP across the fight,
  against a ~15 HP shortfall.

Re-seeding does not fix it and costs the ledger: seeds 1, 2 and 5 red
*earlier* (the Act II nest at 1 and 5; a gold pin at 2, because
`supplier_scavengers`' 2g loot is a 50% roll and every `GOLD/PACING` pin
is therefore seed-derived).

## Dropped/kept coverage vs the stitched album

Dropped (were teleport-only "tolerant legs", off the continuous spine):
garden_sanctuary, barracks, runners_guild interiors. Kept on-spine: inn_upstairs seam, sewers, deep tunnels,
ruin, riverfarm village/hollow/longhouse, invrisil boulevard/alleys/
enchanter shop, pallass market/forge, dungeon, vault. Night-watch wolf fight
replaced by the track leg (night phase unschedulable on a portal route).

Added by the 2026-08-12 reauthor: the street's `supplier_scavengers`
(Act II side fight), the Act II inn night, the Act IV outfitting beat
(core shard), the Act V descent kit swap, and the whole #440 warden
sequence (watcher beat → cloaked approach → ambush → post-fight choice).
Fights are now **12**, up from 8. Evaluated and left out:
`gallery_vermin_nest` (rank-scaled Act IV detour — it banks
`spear_skill_used` but did not move the level at the descent, and it
lengthens the run by 27 steps) and `kingslayer_den`.

New album beats: `04_act_ii_04b_supplier_crew`-era shots are covered by
the existing crate frames; added are
`07_act_iv_05b_core_shard_worn`, `08_act_v_00b_descent_kit`,
`08_act_v_05_the_watcher`, `08_act_v_06_cloaked_approach`,
`08_act_v_07_the_seal_warden`, `08_act_v_07b_warden_down` and
`08_act_v_05b_the_choice`.

## Authoring a new segment: checkpoints (GH#435)

The 2026-08-11 rebuild paid the whole prefix back on every fix — late-Act
iteration meant re-walking Acts I–IV, ~50s per green attempt plus 5–30s of
timeout stall per red, roughly ten times over the warden work. Checkpoints
remove that. They are **scaffolding**: derived from the continuous run
itself, used only to iterate, and gone before the proof run. This is not
the stitched-album mistake (which shipped fixture loads as *part* of the
run, breaking continuity and PC identity) — nothing here ever enters
`steel_thread.json`, and the grep gate stays the mechanical proof.

**1. Dump a checkpoint at the segment boundary.** No edit to
`steel_thread.json` — the flag checkpoints it from outside:

```bash
wandering_inn_game/qa/run_qa.sh steel_thread headless --seed=9 --checkpoint-at=1200
# QA_CHECKPOINT: step_1200 -> .../qa_output/steel_thread/checkpoint_step_1200.json (step 1199, street (29, 4))
```

A step landing mid-combat or mid-dialogue defers to the next quiet step
and says so (`QA_CHECKPOINT_DEFERRED`) — `WISave.serialize` captures
neither, so a checkpoint taken there would be a fixture that lies. The
in-script equivalent is the `dump_checkpoint {slot}` step action, which
*refuses* in those states instead of deferring (you chose the spot).

**2. Iterate the new segment as a scratch script.** Checkpoints are ordinary
WISave files — same format as `qa/fixtures/*`, `rng_state` rides along as a
String so seed continuity holds — and `fixture_save` accepts a **path** as
well as a bare fixture name, so the scratch script points straight at the
artifact and nothing lands in `qa/fixtures/` (where
`test_fixture_coherence` would validate a throwaway as a shipped story
position):

```json
{
 "fixture_save": "res://qa_output/steel_thread/checkpoint_step_1200.json",
 "starts_at_title": true,
 "steps": [ "…title gate → Continue…", "…the new segment…" ]
}
```

Name it `qa/scripts/tmp_*.json`, run it with `--fail-fast` so the first
divergence stops the run instead of the tail executing against wrecked
state, and iterate. Measured: the step-1200 resume above loads and asserts
in **~1.5s** against ~20–55s for the prefix.

**3. Splice the proven segment into `steel_thread.json`** and delete the
scratch script and its `qa_output/` directory.

**4. Purity proof:** one full continuous run, plus the grep gate above
(must print 0). Checkpoints never ship inside the final script.

### Answering questions without a run (GH#436)

Two instruments replace the deliberately-failing-`assert_state` probe:

```bash
# what the panel will actually show at this node, under THIS save
godot --headless --path wandering_inn_game --script res://qa/oracle.gd -- \
    --save=res://qa_output/steel_thread/checkpoint_step_1200.json \
    --query="visible_options erin_errand hub"
# route + paste-ready driver `move` steps, and the bump direction for a
# blocked (occupied) target cell
… --query="path inn 13,6 7,2"
… --query="field_bar"      # equipment-dependent; an equip renumbers hotbar_N
```

Answers arrive as one `ORACLE_JSON:` line. Other queries: `state <dot.path>`,
`known_skills`, `portal_rows`, `inventory`; `--query help` lists them.

Inside a run, the `dump_state {label}` action emits a `qa_state_dump` event
carrying the full snapshot, field bar, open-dialogue rows and combat roster
— readable from `qa_output/<script>/events.jsonl` in a **passing** run,
where the old probe idiom needed a failing one. Every failure line now
carries a compact `state={…}` suffix for the same reason.

## Known limitation

`events_seen` may vary between identical seed-9 runs; `combat_autoplay`
victory pins are the completability proof and may flake under extreme
timing variance. If a windowed run reds on a victory pin, re-run once
before triaging.
