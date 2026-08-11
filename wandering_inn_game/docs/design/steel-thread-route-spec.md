# Continuous Steel Thread — Route Spec

Derived 2026-08-11 from `data/acts.json`, `data/quests.json`,
`data/portals.json`, map entity payloads, and `src/core/sleep_beat.gd`.
This is the spine the continuous `steel_thread.json` implements: one PC,
no fixtures, no teleports; every transition is a walked door, a
`door_when` travel prop, or a Magical Door portal hop the run has earned.

Plan: `docs/superpowers/plans/2026-08-11-continuous-steel-thread.md`.

## Travel inventory (all in-game, all state-gated)

| Edge | Mechanism | Gate |
|---|---|---|
| inn ↔ floodplains / inn_upstairs | doors | none |
| floodplains ↔ street | door | none |
| street → sewers | `sewer_grate` (16,11) `door_when` | `heard_about_cisterns` opens it (grate-gate) |
| sewers ↔ deep_tunnels | `deep_fissure` (8,12) / `tunnel_up` | `heard_the_deep_tremor` |
| deep_tunnels → dungeon_approach | `warren_mouth` (12,5) door arm | `horns_delve_started` (requires `post_game`) |
| dungeon_approach ↔ trapped_halls | door pair | `horns_delve_started` chain |
| floodplains → ruin_surface | `ruin_door` (38,11) | `horns_dig_started` |
| inn/anchor stones → regions | `portal_menu` (pantry_door, street/riverfarm/invrisil anchor stones) | `door_mounted` for Liscor pair; `door_awakened` → Riverfarm; `invrisil_attuned`; `pallass_attuned`; `dungeon_attuned` |
| pallass_market ↔ pallass_forge | `grand_lift_*` (22,7) | `elevator_pass_stamped` |
| inn → garden_sanctuary | `garden_door` (3,8) | `garden_door_unlocked` |

## Act I — Arrival (gate: class ≥1 + `reached_liscor`)

| # | Beat | Site | Banks | Combat/Sleep |
|---|---|---|---|---|
| 1 | Title gate → title → creation | UI | — | — |
| 2 | Inn opener (Erin GDI), inn sign | inn | — | — |
| 3 | Relc classless spar | inn/floodplains tutorial arena | tutorial counters | FIGHT (tutorial) |
| 4 | First sleep → [Warrior] | inn_upstairs bed via `stairs_up` (1,8) — WALKED, old script teleported | `class_gained` warrior | SLEEP |
| 5 | Relc spear gift → equip | inn gift node | spear equipped | — |
| 6 | East gate road → ambush → Liscor | floodplains → street | `reached_liscor` | FIGHT (gate-road ambush) |

## Act II — Make a Place (gate: `reached_two_classes` + 3 quests done)

| # | Beat | Site | Banks | Combat/Sleep |
|---|---|---|---|---|
| 7 | `the_errand`: Erin package → Selys | inn → guild | `package_delivered`, `errand_decided` | — |
| 8 | Second class: `dusty_scroll` (inn 12,7) → sleep | inn | frost line skill; `class_gained` mage (donor: `mage_unlock_loop`) | SLEEP |
| 9 | `missing_crate`: Krshia stall → south square → resolve → report | street | `found_the_crate`, `crate_returned` (guile ladder preferred — no seed risk) | optional fight, avoid |
| 10 | `cisterns`: grate-gate → sewers nest → report Olesm | street → sewers → guild | `heard_about_cisterns`, `resolved_the_cisterns`, `cisterns_reported` | scout path preferred |
| 11 | (floodplains frost field beat en route: [Snap Freeze] pond crossing + cache — keeps old album's Act-"field skill" scene, on the way to a sleep) | floodplains | pond cache | — |

## Act III — What Stirs Beneath (gate: `raskghar_sealed`)

| # | Beat | Site | Banks | Combat/Sleep |
|---|---|---|---|---|
| 12 | Sleep fires tremor pointer (`_maybe_fire_tremor_pointer`) → `something_beneath` auto-starts | inn sleep | `heard_the_deep_tremor` via Zevara at gate | SLEEP |
| 13 | Zevara summons | street gate | `heard_the_deep_tremor` | — |
| 14 | Fissure delve | sewers `deep_fissure` → deep_tunnels | `found_the_fissure` | — |
| 15 | Scout fight → warren mouth → Relc veto → boss | deep_tunnels | `cleared_the_warren` | FIGHT ×2 (scouts, awakened boss) |
| 16 | Report Zevara | street gate | `raskghar_sealed` | — |
| 17 | First sleep after seal | inn | `post_game` | SLEEP |

## Act IV — What the Door Opened (gate: `lattice_forge_rune` + `seal_kept_reported` + `price_of_a_favor_reported` + `brothers_job_done`)

| # | Beat | Site | Banks | Combat/Sleep |
|---|---|---|---|---|
| 18 | `what_the_seal_kept`: delve invitation (`horns_delve_started`, post_game-gated) | guild/inn (exact trigger verified at build) | `horns_party_formed` at gallery (ceria_intro) | — |
| 19 | Trapped halls with Horns | deep_tunnels `warren_mouth` → dungeon_approach → trapped_halls | `halls_cleared` (Ksmvr plates or disarm — low seed risk) | maybe FIGHT |
| 20 | Vault guard → seal door | trapped_halls | `vault_construct_downed`, `seal_kept_found` | FIGHT (construct) |
| 21 | Report Olesm; Horns take inn corner | guild → inn | `seal_kept_reported` | — |
| 22 | `horns_dig`: Ceria invitation (gates on `seal_kept_reported`) → ruin east | inn → floodplains `ruin_door` → ruin_surface camp | `horns_dig_joined`, `pedestal_breached`, haul → `door_mounted` | dig fight optional path |
| 23 | `door_that_goes_elsewhere` (auto-starts): Pisces consult → Krshia catalyst → deliver → attunement sleeps | street (Guild steps, Krshia stall), inn | `door_understood`, `bought_catalyst`, `catalyst_delivered`, `door_awakened` | SLEEP ×2+ |
| 24 | `where_the_door_reaches` auto-starts (Pisces) | street | — | — |
| 25 | Door → Riverfarm: village, night watch wolves, witch hollow (Eloise), longhouse; `price_of_a_favor` mediate → report headman | riverfarm_village, witch_hollow, riverfarm_longhouse | `lattice_witch_lore` (riverfarm_witch), `blight_lifted` (mediated), `price_of_a_favor_reported`; Eloise travel-stones → `invrisil_attuned` | FIGHT (wolf night watch) |
| 26 | Door → Invrisil: boulevard, Hedault reading (enchanter shop — ON-spine), alleys, `a_gentlemans_disagreement` (scout → corner Coyle → report Wilovan at parlor) | invrisil_boulevard, enchanter_shop, mercantile_alleys, brothers_parlor | `lattice_hedault_reading`, `coyle_operation_found`, `merchant_fate_decided` (exposed path — no fight), `brothers_job_done` | — |
| 27 | `papers_for_pallass`: Selys sponsor → Krshia stone → Door → stamp clerk | guild, street, pallass_market | `pallass_sponsored`, `pallass_attuned`, `pallass_entry_stamped` | — |
| 28 | `forge_tier_permit`: file → Grimalkin exam → stamp; lift up; forge tier + calibration-rig parley + forge-hall fight | pallass_market permit office, grand lift, pallass_forge(_hall) | `forge_permit_filed`, `grimalkin_examination_passed`, `elevator_pass_stamped`, `lattice_forge_rune` (pallass_grimalkin) | FIGHT (forge hall) |
| 29 | Return to Pisces | street Guild steps | `seal_descent_agreed` | — |

## Act V — What the Seal Was Feeding (gate: `seal_resolved`)

| # | Beat | Site | Banks | Combat/Sleep |
|---|---|---|---|---|
| 30 | `dungeon_attuned` banks in sleep (needs `door_awakened` + `heard_pisces_second_door`) | inn sleep (sleep_beat.gd:166) | `dungeon_attuned` | SLEEP |
| 31 | Door → dungeon_approach → trapped_halls (WALKED — old script teleported at step 631) | dungeon | — | — |
| 32 | Rune-door reading with Pisces | trapped_halls seal door | `read_the_seal_runes`, `read_the_feeding_ward` | — |
| 33 | Resolve: OPEN path (matches old album: warden + vault) | trapped_halls | `seal_opened` → `seal_resolved` | FIGHT (Seal Warden) |
| 34 | Vault, anchor, tally, walked return | seal_vault → trapped_halls → out | vault beats | — |
| 35 | Final sleep → epilogue | inn | epilogue render event | SLEEP |

## Build trajectory (expected)

Warrior (Act I) → +Mage via scroll+sleep (Act II) → levels through Act
II–III fights → spellsword consolidation when floor reached (14 —
verify when `pending_consolidation` fires; handle the consolidation UI
in-script the turn it appears, since `reload_data` refuses during
pending consolidation). Late fixtures (`seal_open_start`) show
spellsword 14 as the intended endgame shape — the continuous run's
actual trajectory is ITSELF a deliverable (user judges leveling pace).

## Resolution-path choices (log to CHOICE-LOG at Task 6)

Guile/scout/mediate/expose picked wherever a fork exists EXCEPT
spine-mandated fights — minimizes seed risk and keeps combat count at
the 8 pinned fights: tutorial spar, gate ambush, warren scouts, warren
boss, vault construct (likely), wolves night watch, forge hall, Seal
Warden. Seal resolution = `seal_opened` (matches old album's
warden/vault beats).

## Known holes to resolve at build time (not blockers)

- Exact `horns_delve_started` trigger surface (guild vs inn dialogue).
- `a_winter_of_teeth` (night-watch wolves) start trigger — proximity vs
  quest start; the fixture name suggests a prepared night state, the
  continuous run must arrive at night or trigger organically.
- Whether `vault_construct_downed` has a no-fight alternative (spec
  says fight is one of three paths; take whichever keeps `seal_kept_found`).
- `witch_hollow` entry gating from riverfarm_village (walked door).
- Epilogue's exact event name (old script tail is the donor).
