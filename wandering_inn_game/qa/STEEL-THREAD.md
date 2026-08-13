# Steel-thread playtest

Run from the repository root:

```bash
wandering_inn_game/qa/run_qa.sh steel_thread windowed --seed=37
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
band, and every fight runs on the competent policy. After #451 capped
[Counter Strike], the continuous combat draw was re-derived from seed 9 to
seed 37 and its loot-ledger/inventory pins were re-recorded from the live run.
**2569 steps are GREEN end to end at seed 37** — title gate to GDI epilogue,
Seal Warden included.

The verified #451 headless run recorded **11433 events**.

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

**Policy amendment, 2026-08-12 (controller), and what it did to this run.**
The survive step now prices the WORST single hit (`potential_damage` — top
face, skill multiplier, no miss discount), takes the largest heal
regardless of source (a +8 draught beats a +4 ward), and allows a second
survive action inside the death band; and #442 gave [Second Wind]
`once_per_fight`. Two visible consequences here, both of which moved
pins:

- The PC now actually **drinks in the delve**, so the pack that reaches
  Act IV is one item shorter. Every inventory-cursor count downstream
  (the outfitting beat, the Krshia buyback picker, the descent kit)
  shifted by one row and was re-derived off the oracle.
- The finale flipped. The same fight that died in round 5 holding two
  undrunk draughts became a win; after #451 it is re-derived as a
  **round-5 win at seed 37** (see the tape below).

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

## PC trajectory at act boundaries (seed 37, re-derived for #451)

| Boundary | Classes | Combined | Band | Gold | Waking |
|---|---|---|---|---|---|
| End Act I (`reached_liscor`) | warrior 1 | 1 | 1–2 | 2 | 1 |
| End Act II (`cisterns_reported`) | warrior 5, mage 2 | 7 | 4–6 | 12 | 3 |
| End Act III (`raskghar_sealed`) | warrior 9, mage 2 | 11 | 8–10 | 12 | 4 |
| End Act IV (`seal_descent_agreed`) | spearmaster 14, mage 6, diplomat 4 | 24 | 12–14 | 0 | 8 |
| At the Seal Warden | spearmaster 14, mage 6, diplomat 7, trader 2 | 29 | 14–16 | 0 | 10 |
| End of run (epilogue) | spearmaster 15, mage 6, diplomat 7, trader 2 | 30 | — | 0 | 11 |

Climax builds (the number the bands actually govern — levels resolve in
`sleep()`, so a climax is fought at the *previous* night's build):

| Climax | Fought at | Band | Result |
|---|---|---|---|
| I gate-road ambush | warrior 1 | 1–2 | win |
| II cistern nest (+ matriarch) | warrior 5 / mage 2 | 4–6 | win, round 5 |
| III raskghar scouts (+ pack leader) | warrior 5 / mage 2 | 8–10 | win |
| III awakened boss (+ two scouts + Sewer Bat, with Relc) | warrior 5 / mage 2 | 8–10 | win, round 4 |
| IV vault construct | spearmaster ~12 / mage 3 | 12–14 | win, round 7 |
| IV ruin guardian | spearmaster 12 / mage 3 + core shard | — | win |
| V seal warden | spearmaster 14 / mage 6 / dip 7 / trader 2 | 14–16 | **win, round 5, PC ends on 47/47 HP** |

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
buyback now sells **only** the vault tonic (+8) — the one item the policy
provably never reaches for, its `use_effect` being a `next_fight` buff
with no `heal` key. The remedy draught stays in the pack and is drunk in
round 3 of the finale.

**No further diet was added, deliberately.** The plan after the first
(red) pass was to take the pre-descent diet to band-top, spearmaster
15–16, to buy the missing ~20 HP. #442 plus the policy amendment bought
it instead, and a diet extension is not free: every added fight consumes
rng draws before `WICombat.new(..., rng.randi())`, which re-rolls the
finale's whole stream. That was measured — inserting a
`gallery_vermin_nest` detour in Act IV moved the warden's remaining HP
from 6 to 58–61 without moving the PC's level. Adding grind to a run
that is green at band FLOOR would have traded a proof for a coin flip.

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

## The Seal Warden, fight tape (seed 37 after #451)

**Win, 5 rounds, PC ends on 47 of 47 HP; warden 0 of 142.** The observed
event tape is compact: the warden's opening [Power Strike] reports 28 while
[Mana Shield] absorbs 17 and the equipped reduction takes another point;
the capped [Counter Strike] answers once for 14. [Second Wind] heals 8,
[Piercing Strikes] deals 20, the remedy tops the PC by 2, and [Spear
Flurry] deals 35. The warden then misses both its slam and next power
strike; [Triple Thrust] deals 36 and the final [Spear Flurry] deals 43 for
the kill. `combat_finished` records `{rounds:5, victory:true}`.

This is a deterministic canonical proof, not a replacement for the
100-seed tuning row. The viability harness independently measures the
level-14 Spellsword reference at 0.78 inside the window.

## Still open after the program

- **The consolidation gap is structural — filed-issue candidate.**
  Spellsword needs warrior 10 + mage 10. [Warrior] evolves into
  [Spearmaster] at 10 on `spear_skill_used` dominance — with Relc's spear
  in hand from Act I that is the only reachable shape — and the
  consolidation reads *warrior*, so **the evolution orphans the PC's
  spellsword eligibility permanently**. Mage reaches 6, not 10, because
  the competent policy only casts when the cast out-damages the swing and
  a 1.4×/2.0×/2.6× spear kit always beats a level-6 frost bolt. No sane
  diet on this spine reaches spellsword 14. Either consolidations accept
  evolved parents, or the Act V band stops being stated as a
  spellsword-shape.
- **Level count is not the Act V band.** The run arrives at 29 combined
  levels and 47 max HP against a band written for 14–16 *focused*;
  #437's 0.77 was measured on that focused build with tuned gear. The
  band wants focused-equivalent power, and should say so.
- **The economy has no room for armour.** It funds the spine's 82g of
  mandatory purchases with no gold to spare; the two armours in the game cost
  20 (peddler gambeson, damage reduction 1) and 24 (Krshia's jerkin,
  hp+4). A player who wants to be armoured for the finale has to skip
  something the spine needs.

Seed 37 is load-bearing and was selected from observed full-prefix runs,
not guessed. Seeds 1–7 and 9–36 fail before clearing the Act II nest; seed
8 clears it but loses to the Act IV construct. Loot rolls also make every
`GOLD/PACING` pin seed-derived.

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
wandering_inn_game/qa/run_qa.sh steel_thread headless --seed=37 --checkpoint-at=1200
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
