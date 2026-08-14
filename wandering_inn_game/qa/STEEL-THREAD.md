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

Re-verified 2026-08-13 (Lane D) on composed main after #448/#449/#450/#451:
still **PASS, 2569/2569 steps, zero failures**, twice at `--seed=37`. Event
counts observed **10950 / 10960 / 10962** across three runs — the ±12 jitter
is the known limitation below; the ~480-event drop from the #451-era 11433 is
the wave's own content landing, not a regression. Seed and step count are
unchanged. The class rows below were re-derived from that run — they MOVED
(see the dated note under the trajectory table).

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
  undrunk draughts became a win; after #451 it re-derived to a round-5 win,
  and after #438's warden move it is a **round-7 win at seed 37 on 1 of 47
  HP** (see the tape below).

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

## PC trajectory at act boundaries (seed 37, re-derived 2026-08-13, Lane D)

| Boundary | Classes | Combined | Band | Gold | Waking |
|---|---|---|---|---|---|
| End Act I (`reached_liscor`) | warrior 1 | 1 | 1–2 | 2 | 1 |
| End Act II (`cisterns_reported`) | warrior 5, mage 3 | 8 | 4–6 | 12 | 3 |
| End Act III (`raskghar_sealed`) | warrior 8, mage 4 | 12 | 8–10 | 12 | 4 |
| End Act IV (`seal_descent_agreed`) | spearmaster 16, mage 8, diplomat 4 | 28 | 12–14 | 0 | 8 |
| At the Seal Warden | spearmaster 16, mage 8, diplomat 7, trader 2 | 33 | 14–16 | 0 | 10 |
| End of run (epilogue) | spearmaster 16, mage 8, diplomat 7, trader 2 | 33 | — | 0 | 11 |

**These rows MOVED in the ≥434 wave** (previously warrior 5/mage 2 → 7,
warrior 9/mage 2 → 11, spearmaster 14/mage 6/dip 4 → 24, and 29/30 at the
last two boundaries). Gold and waking are UNCHANGED at every boundary and
the run is still green — only the leveling curve moved, faster on both
lines. Re-derived by checkpointing the live run (`--checkpoint-at`), not by
hand. **#438 UPDATE:** these boundary rows are unchanged again (the warden
move touches one fight, not the curve), but the sentence that used to
stand here — "the warden tape below is unchanged beat for beat" — no
longer holds and has been withdrawn: that tape is fully re-derived, see
its own section.

Climax builds (the number the bands actually govern — levels resolve in
`sleep()`, so a climax is fought at the *previous* night's build):

| Climax | Fought at | Band | Result |
|---|---|---|---|
| I gate-road ambush | warrior 1 | 1–2 | win |
| II cistern nest (+ matriarch) | warrior 5 / mage 3 | 4–6 | win, round 5 |
| III raskghar scouts (+ pack leader) | warrior 8 / mage 4 | 8–10 | win |
| III awakened boss (+ two scouts + Sewer Bat, with Relc) | warrior 8 / mage 4 | 8–10 | win, round 4 |
| IV vault construct | spearmaster 10 / mage 6 | 12–14 | win, round 7 |
| IV ruin guardian | spearmaster 10 / mage 6 + core shard | — | win |
| V seal warden | spearmaster 16 / mage 8 / dip 7 / trader 2 | 14–16 | **win, round 5, PC ends on 47/47 HP** |

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
  converts them to [Warrior] 5 + [Mage] 3. Cost: 1 fight, 1 sleep,
  ~130 walked cells.
- **Act III** — **nothing added**. The Act II night carries the act:
  scouts, warren mouth and the Awakened all clear at warrior 8 / mage 4
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

## The Seal Warden, fight tape (seed 37 after #438)

**Win, 7 rounds, PC ends on 1 of 47 HP; warden 0 of 164.**

**THE SEED HELD.** #438 took `seal_warden` con 112 → 134 under the
2026-08-13 ruling's sanctioned frozen-block exception, which moves the
warden's max HP 142 → 164 and therefore re-rolls every draw in this fight.
The tape below is fully re-derived from the live run; the SEED is not. Seed
37 still clears all **2569 steps green, twice**, and no re-derivation was
needed — which is worth saying plainly, because a seed move here is the
expensive failure mode and this change came within one hit point of it.

The tape, observed: the warden's opening [Power Strike] reports 28 while
[Mana Shield] absorbs 17 and the equipped reduction takes another point;
the capped [Counter Strike] answers once for 14 (warden to 150). Round 2 is
a clean [Piercing Strikes] for 20 (130). Round 3 the remedy tops the PC by
2 and [Spear Flurry] deals 35 (95) while the warden misses twice. Round 4
[Triple Thrust] deals 36 (59). Round 5 [Spear Flurry] deals 43 (16), then
the warden lands BOTH swings for 13 and 20 and [Counter Strike] answers for
14 (2) — the PC is on 16. Round 6 passes with neither side connecting.
Round 7 the warden hits for 11 and 22, taking the PC to **1 HP**, and the
capped [Counter Strike] fires one last time for 12 to finish it at 0;
[Battle Momentum] triggers on the kill. `combat_finished` records
`{rounds:7, victory:true}`.

**The finale is a knife-edge now, and that is the point of the change.**
Before #438 the same seed won in 5 rounds without the PC ever dropping
below full — a climax that was not, in the event, a fight. It is now won on
the last exchange with one hit point standing. Note what closed the gap:
the last two rounds are carried entirely by [Counter Strike] reactions off
the warden's own hits, so the run survives by being attacked.

This is a deterministic canonical proof, not a replacement for the
100-seed tuning row. The viability harness independently measures the
level-14 Spellsword reference at 0.70 inside the window (0.78 before #438).

## Still open after the program

- **The evolved-parent half of the consolidation gap is CLOSED (#449).**
  The orphaning this section used to report — [Warrior] evolves to
  [Spearmaster] at 10 on `spear_skill_used` dominance (with Relc's spear
  from Act I, the only reachable shape) and the consolidation read
  *warrior* — is fixed: [Spellspear] consolidates spearmaster × mage at
  the same 10/21 gate. On this run the PC holds **spearmaster 16** at the
  descent, so the martial half of the gate clears with six levels to spare.
- **What is still open is the mage half — it is a diet gap, not a
  structural one.** Mage reaches **8**, not 10. Level 10 wants
  `spell_cast` 45; the run banks **35**, all of them ice (`ice_cast` 35,
  `fire_cast` 0). The competent policy casts only when the cast out-damages
  the swing, which on a spear kit means only at range, so casts cluster in
  ranged multi-foe fights (the two Invrisil alley fights bank 6 each with
  zero melee) and the single-boss climaxes bank none — `spell_cast` is
  frozen at 35 from the last Invrisil fight through the warden. **+10
  banked casts, all of which must land before the Act IV→V sleep**, is the
  whole remaining delta. Paying it is not free: added fights consume rng
  draws before `WICombat.new(..., rng.randi())` and re-roll the finale (the
  measured `gallery_vermin_nest` result below), and the offer that fires
  would preempt one Act V gating sleep — `sleep_beat.gd` returns at the
  consolidation offer BEFORE `door_study_sleeps`/`second_door_study_sleeps`
  bank, and a decline does not suppress the re-offer at the next sleep. A
  mage-10 variant therefore belongs to #434 M4's Mage run, which owns the
  variant layer, not to this thread.
- **Level count is not the Act V band.** The run arrives at 33 combined
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

## Regenerating this script from an itinerary (#434 M3.6) — NOT yet the path

The itinerary compiler (`scripts/itinerary/`) exists to make route-subject
scripts like this one recompilable instead of hand-maintained, and M3's exit
was to make `steel_thread.yaml` the canonical way to rebuild
`steel_thread.json`. **It is not that yet, and this section says so rather
than advertising a path that does not run.** Edit `steel_thread.json` by hand,
as before.

**What M3.5 closed.** The 2026-08-13 pre-M4 design note reopened §3.2 for
exactly two idioms and re-froze behind them, and §8's creation prelude got
built:

| Steps | Beat | M3.5 |
|---|---|---|
| 0–40 | Title gate, menu, creation (picker grid, Esc/tap round trip, name, difficulty, hints), GDI opener | **Built.** A `creation:`-keyed emitter prelude (§8). Reproduces all 41 steps exactly; the picker card index is derived from PC_OPTIONS' 2×3 grid, not written down. |
| 75–114 | Relc's spar, driven turn by turn | **Built.** `fight: {mode: driven, turns: [...]}`. Reproduces all 40 steps exactly. |
| 561–566, 2317–2322 | Journal reads | **Built.** `journal: {capture, act}`. Reproduces both, modulo the tolerance-class album hold. |

**What M3.6 closed (2026-08-13 amendment, five items).** All five are BUILT and
pinned in `scripts/itinerary/tests/test_m36_contract.py`, each with a mutation
red:

| Item | Shape | Status |
|---|---|---|
| 1 | `fight: {entry: dialogue}` — the board opens on a conversation's own confirm | **Built.** The fight node owns the walk; the emitter omits the approach press and the panel teardown. Reproduces 74–75. |
| 2 | Effect-derived event waits after a chosen option | **Built.** `effects` + quests.json joins, in `WIGame.dialogue_choose` order. |
| 3 | `turn_wait: false`, autoplay `beats:`, `expect_banks_after_dismiss`, `arena:`, `goto.via`, `ui_map_rendered` / `ui_gdi_epilogue_rendered` | **Built.** Reproduces 196–208 (minus one row, below), 2439, 2479–2480, and the epilogue tail. |
| 4 | Sneak lifetime (#440) in the ledger and the route planner | **Built.** A live stance suppresses the proximity refusal; a fight, a non-door interact and a sleep all drop it. Reproduces 2426–2428. |
| 5 | Node-level unknown-key rejection; fence arrival tracking | **Built.** A stray key beside a valid primitive is a `SchemaError`; the ledger's end position per node joins the pass-2 spine comparison. |

**THE "141" FIGURE IS REFUTED, RE-MEASURED.** 141 is how many
`accomplishment_recorded` / `quest_*` / `item_*` / `entity_removed` /
`gold_changed` rows this script carries **anywhere**. The rows the dialogue
planner derives are the ones a dialogue confirm announces, and the emitter has
TWO placements for them -- immediately, on a row that continues, and after the
teardown pair, on a row that closes (because `choose()` emits `dialogue_ended`
before the owner applies the effects):

| Reading | Rows | Sites |
|---|---|---|
| All rows of those types, whole script (the M3.5 figure) | 141 | — |
| Announced immediately, on a continuing row | 96 | 56 |
| Announced after the teardown, on a closing row | 9 | 4 |
| **Derivable total** | **105** | **60** |
| Not announced by a dialogue confirm | 36 | — |

The 36 split 26 prop-`interact`, 8 post-dismiss banking (steps 207, 388, 389,
500, 501, 1059, 1612, 1626 -- item 3's `expect_banks_after_dismiss`, now
built) and 2 sleep banks.

**A first pass of this census reported 94/55 and 47, and was wrong twice.** It
was a standalone scanner rather than a reading of the compiler's own model, so
(a) it raised its in-conversation flag only on a `wait_for_event
dialogue_started`, and the Ksmvr plates beat (872-877) opens without one, which
cost two rows and one site; and (b) it knew only the immediate placement, so
the nine closing-row announcements at 1040-1041, 1123-1125, 1950-1951 and
2149-2150 -- the exact shape `emit.py` emits for a closing row -- were filed as
non-derivable. The census is now derived from the emitter's placement rule and
that rule is asserted first, in
`test_m36_contract.py::test_the_emitters_placement_rule_is_what_defines_the_window`,
so inverting the placement reds before the count can drift again.

**M3.6 MERGED AS A PARTIAL MILESTONE.** Its five ruled items are built and
guarded; its EXIT is not met. The golden does not pass the tolerance differ,
this section is still not the path to regenerate this script, and M4 (the
Mage variant) stays blocked. What remains is tabled below.

**Where the golden stands.** `scripts/itinerary/steel_thread.yaml` now carries
the creation prelude plus **21 nodes covering shipped steps 0-217** -- the whole
of Act I, through the spar, the first night, the spear, the gate-road ambush
and the arrival in Liscor. That prefix compiles clean (replay self-check ok,
zero raw steps), compiles byte-identically twice, and **runs green headless at
seed 37, 232/232 steps**.

Two of its nodes are pure APPROACH STAGING (`act1.road.approach`,
`act1.stairs.approach`), and they are the lane's one authoring lesson worth
carrying forward. A proximity ambush springs on the step that enters its
radius, and a blocked door can be bumped from more than one side; in both cases
the router's shortest path picked a different edge than the corpus, which is a
different ARRIVAL and therefore net-class fatal. Naming the staging cell with an
ordinary `goto` fixes it inside the existing vocabulary -- there is no compiler
gap here, only an itinerary that had not said where to stand.

Against the shipped 0-217 the tolerance differ reports:

| Differ | Result |
|---|---|
| Pre-lane (`goldens.py` @ 7904953e) | `GOLDEN FAIL: 50 exact-class, 11 net-class, 8 tolerance-class, 25 tightening(s)` |
| M3.6 (two accounting fixes, below) | `GOLDEN FAIL: 47 exact-class, 5 net-class, 9 tolerance-class, 28 tightening(s)` |

**The differ was edited inside the milestone it gates, and that needs saying
plainly.** Two changes, both accounting rather than policy, neither touching
which CLASS is fatal:

1. **Gap carry-forward.** A gap is the walk before a spine step; an unmatched
   spine step used to have its gap dropped on the floor, so a walk sitting
   behind a compiled-only assert was compared to nothing at all. The invariant
   that makes this a strengthening is COVERAGE: every tolerance-class step now
   reaches exactly one comparison, pinned in
   `test_the_carry_forward_cannot_MASK_a_difference_because_it_drops_nothing`.
   Dropping movement from a comparison is a way to MISS a difference; carrying
   it forward can only add movement to one.
2. **Position pins align on their value.** Every `assert_state player_cell`
   was the same alignment token, so the matcher paired an arrival with
   whichever one it reached first. Severity is unchanged in every case: a pin
   whose value really differs is fatal as a mismatch under the old key and as
   a dropped claim under the new one, and the dropped-claim direction has its
   own mutation red.

Neither change is the tightening-class question below, which stays unanswered.

**An earlier version of this lane also had the emitter pin `assert_state
player_cell` after every walk leg.** It has been REVERTED: no M3.6 criterion
names it, and it could be removed with the whole suite green, which makes it
unguarded scope creep however good the numbers looked. What it was worth is
worth recording, because the class is real: the corpus carries **330** such
rows and the emitter carries them only after a map transition, so Act I's
exact-class count went 47 -> 23 with the pins in. That is a candidate for its
own scoped change, with its own guard, in a later lane.

**What blocks the rest is no longer language.** It is emitter IDIOM VARIANCE,
measured corpus-wide, plus two differ accounting weaknesses:

| Class | Corpus rows | Why it is fatal today |
|---|---|---|
| Shipped `assert_state player_cell` after a walk leg; the emitter pins only after a transition | 330 | Dropped claim -> exact-class |
| Conversation open: the compiler waits `dialogue_node` before `ui_dialogue_shown` (the replay self-check requires it, two reds bought the rule); 3 of 63 corpus opens do | 60 | Compiled-only `wait_for_event` |
| Destination node: the compiler always waits the row's own `dialogue_node`; 75 of 125 continuing confirms here do | 50 | Compiled-only `wait_for_event` |
| Pool line: the compiler also waits `ui_dialogue_rendered`; this script never does | 24 | Compiled-only `wait_for_event` |
| Sleep: the compiler waits `phase_changed` and pins `classes`; this script pins the class toast, `ui_toast_rendered {from_start}` and `ui_sleep_veil_rendered {lines}` | 5 sleeps | Both directions |
| `ui_inventory_shown {items: N}`: the emitter's wait carries no payload, which is LOOSER | 3 | §6.3 forbids a looser pin |
| `assert_event_logged` inside an autoplayed board (`ui_hotbar_rendered {slots}`) | 2 | Autoplay has no slot for an assert between the turn and the shot |
| `pickup`'s `"Got: <item>"` toast | 1 | The amendment's derivable list is deliberately toast-free |
| Differ: a trailing bump-to-face reads as movement in `_net` | 3 of the 5 net rows | The bump sets facing and moves nobody, but `_net` cannot know the target cell is blocked |
| Differ: repeated `press interact` anchors mis-pair | 2 of the 5 net rows | Every `press interact` is the same alignment token, so a compiled-only spine step slides the pairing |

**WHAT THE OPEN RULING WOULD AND WOULD NOT BUY.** §6.3's tightening allowance
covers only `assert_*` actions, so a compiled-only `wait_for_event` reads as an
exact-class fatal even where the compiled run is strictly the stricter one.
M3.5 reported this about the conversation-open `dialogue_node`; the M3.6
amendment did not rule on it. The question is whether "pins may be TIGHTER and
never looser" extends from `assert_*` to a compiled-only `wait_for_event`.

**MEASURED, inside the authored 0-217 window.** A YES reclassifies exactly
**12 of the 47** exact rows. Typed, from the differ's own output:

| Rows | Wait |
|---|---|
| 3 | `dialogue_node` (1 conversation-open, 2 destination) |
| 2 | `ui_dialogue_rendered` (pool line) |
| 2 | `map_changed` |
| 1 each | `class_gained`, `entity_removed`, `phase_changed`, `ui_inventory_selection_rendered`, `ui_sleep_veil_rendered` |

Only **5 of those 12** sit in the three dialogue-idiom classes tabled above;
the other 7 are the sleep, inventory and transition idioms making the same
kind of stricter claim. The ruling as phrased covers all 12 either way,
because it is about the ACTION and not about which idiom emitted it.

**ESTIMATED, corpus-wide: ~134 rows, and the number is an estimate.** It is
the count of corpus sites at which the emitter's three dialogue idioms WOULD
make a claim the shipped script does not -- 60 conversation opens that carry no
`dialogue_node` (of 63), 50 continuing confirms that carry no destination
`dialogue_node` (of 125), and 24 pool lines against the 0 `ui_dialogue_rendered`
waits this script contains. It is a projection from the corpus onto an
itinerary that **does not exist**: only steps 0-217 are authored, so no compile
has ever emitted those rows and nothing has measured them. The observed sample
is the 12 above. Treat 134 as an order-of-magnitude argument for why the
question is worth a ruling, and 12-of-47 as the only measurement.

**A YES is necessary and nowhere near sufficient.** Even inside the authored
window it leaves **35 exact and all 5 net rows**, and no ruling on tightening
touches them: the 330-row position-pin class (9 rows here), the sleep idiom
(7), the `items` pin, the in-autoplay hotbar assert, the pickup toast, and
alignment residue.

**The 5 net rows are not arrival divergences.** Three are the bump-to-face
`_net` artifact. The other two survive even though the compiled walk for that
leg is now step-for-step the corpus walk (`left 7, up 1, left 1, down 1,
interact` against shipped 147-152, and the inn crossing after it) -- the
differ pairs them with the wrong anchors because every `press interact` is the
same alignment token. That is a second differ accounting weakness, reported
rather than fixed: this lane has already edited the gate twice and a third
edit belongs to whoever rules on the class above.

Per §3.2 the vocabulary re-froze behind M3.6's five items, so everything above
is reported rather than patched around.

## Known limitation

`events_seen` may vary between identical seed-9 runs; `combat_autoplay`
victory pins are the completability proof and may flake under extreme
timing variance. If a windowed run reds on a victory pin, re-run once
before triaging.
