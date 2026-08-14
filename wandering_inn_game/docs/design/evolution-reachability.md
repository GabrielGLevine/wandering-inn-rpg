# Evolution reachability audit (issue #96)

USER PLAYTEST REPORT (2026-07-12, live): "I've hit the consolidation
threshold but I've never hit an Ice Mage or Fire Mage threshold." This
page is the evidence trail: the audit tool, the reachability table it
produced, the diagnosis, the fix taken, the fix **considered and
rejected** (with the exact data that killed it), and the content gaps
reported forward rather than retuned around.

## The audit tool

`tools/evolution_reachability.gd` — a pure `SceneTree` script, the
`tests/sim_combat_batch.gd` discipline (same `WICombat`/`WICombatAI`
construction, same data files, seeded, deterministic — verified
bit-identical across two full runs).

It never re-derives `WIProgression`'s gate math: every outcome comes from
calling `check_class_gains`/`check_level_ups`/`check_evolutions`/
`check_consolidation` verbatim, in the same order `wi_game.gd`'s real
`sleep()` calls them (class gains → level-ups → consolidation offer,
which **defers evolutions that sleep unless declined** → evolutions).

Per-fight accomplishment tallies are **not invented numbers** — each
"waking" runs a real seeded fight (`goblin_ambush`/`chieftains_raid`
compositions, the exact same ones `sim_combat_batch.gd` uses) via
`WICombat`, and only a genuine victory banks `action_tally` into
accomplishments (mirroring `combat_banking.gd::_bank_action_tally`'s victory-only,
trivial-exempt gate). A PC "policy" callable stands in for a human's skill
choice, because the shipped `combat_ai.gd` profiles under-represent several
playstyles this audit needed to test on purpose:

- `"melee"` hardcodes `power_strike` **by name** — it never calls
  `piercing_strikes`, so it can't represent a spear-focused warrior at all.
- `"caster"`'s line-skill branch (`_act_line`) only fires on a **≥2-enemy**
  aligned shot with no ally in the way — far stricter than a human
  choosing to cast a line skill at a single visible foe.

Each policy in the tool is a minimal scripted turn built from `WICombat`'s
own public API (`use_skill`/`attack`/`move_active`/`dash`) plus
`WICombatAI`'s pure pathing/afford helpers (reused, not re-derived), so a
profile can force "always try X" the way a real player would, including
flame_jet on a single foe (relaxed from the AI's own ≥2-enemy gate to ≥1,
no-ally-clipped).

**Kit simplification (documented, not hidden):** PCs are built via
`WIProgression.granted_skills` directly, without `WICombatBuild`'s
equipment weapon-gate filter — the same convention every un-gear'd row in
`sim_combat_batch.gd`'s own `BUILDS` table already uses. This is in scope
for a class-progression audit (not an equipment-availability one) and is
strictly *more generous* to the warrior axis than real play (see
"Structural finding 1" below) — it changes nothing for the mage axis,
since `frost_bolt`/`flame_jet` carry no `weapon` tag in `skills.json` and
were never equipment-gated in real play either.

Run: `/usr/local/bin/godot --headless --path wandering_inn_game --script res://tools/evolution_reachability.gd`

## The table

One fight per "waking" (a conservative, slow pacing estimate grounded in
the mage_unlock_loop QA canonical's own cadence — spar → sleep → ambush →
… → sleep → fight — roughly one fight per sleep in the early game). The
relative ordering between rows (does X resolve before or after Y) is
**invariant** to this constant: every profile's counters scale together
with waking count, so a faster or slower real pacing shifts every row's
waking number by the same multiple without changing which finding is true.

| profile | target | outcome | waking (level) | consolidation cross-check | final banked tally |
|---|---|---|---|---|---|
| `mage_default_caster` (un-optimized, shipped "caster" AI) | mage | REPLACEMENT → [Ice Mage] | 11 (L10) | — | won_combat 11, spell_cast 47, **ice_cast 47, fire_cast 0** |
| `mage_mono_ice` (deliberate frost_bolt) | mage | REPLACEMENT → [Ice Mage] | 11 (L10) | — | spell_cast 46, ice_cast 46, melee_hit 4 |
| `mage_mono_fire` (deliberate flame_jet) | mage | **NEVER** (150 wakings) — **since CLOSED by R2's flame_dart, re-measured REPLACEMENT at waking 31; see "Content gap CLOSED" below** | stuck at L6 | — | won_combat 115, melee_hit 293, spell_cast 22, fire_cast 22 |
| `mage_deliberate_balanced` (frost/flame alternating **intent**, 50/50) | mage | REPLACEMENT → [Ice Mage] | 26 (L10) | — | spell_cast 45, ice_cast 42, fire_cast 3 (93% ice despite 50/50 intent) |
| `warrior_sword` (shipped "melee" AI) | warrior | REPLACEMENT → [Blademaster] | 23 (L10) | — | sword_skill_used 44, melee_hit 57 |
| `warrior_spear` (deliberate piercing_strikes) | warrior | REPLACEMENT → [Spearmaster] | 24 (L10) | — | spear_skill_used 61, melee_hit 58 |
| `warrior_hypothetical_mixed` (sword/spear alt. — **not reachable in real play**, see below) | warrior | REPLACEMENT → [Spearmaster] | 20 (L10) | — | spear_skill_used 28, sword_skill_used 17 |
| `archer_bow` (deliberate power_shot at range) | archer | REPLACEMENT → [Sharpshooter] | 80 (L10) | — | bow_skill_used 64, ranged_hit 58 |
| `helper_serve_mono` | helper | REPLACEMENT → [Barmaid] | 55 (L10) | — | served_customer 55 |
| `helper_deliver_mono` | helper | REPLACEMENT → [Server] | 55 (L10) | — | delivered_item 55 |
| `helper_deliberate_balanced` (serve/deliver alt., 50/50) | helper | **GENERALIST** (after the fix; was NEVER) | 109 (L10) | — | served_customer 54, delivered_item 55 |
| `helper_cleaner_only` (levels via cleaned_the_inn alone) | helper | **NEVER** (150 wakings) | L10 reached, 0 dominance-axis uses | — | cleaned_the_inn 150, served_customer 0, delivered_item 0 |
| `mixed_mage_warrior` (THE user's profile: 50% warrior-sword, 25% ice, 25% fire, decline every offer) → **mage** | mage | REPLACEMENT → [Ice Mage] | **39** (L10) | offered at waking **21** (→ [Spellsword] L12) | spell_cast 46, ice_cast 42, fire_cast 4 |
| `mixed_mage_warrior` → **warrior** | warrior | REPLACEMENT → [Blademaster] | 20 (L10) | (same offer as above) | melee_hit 58, sword_skill_used 19 |

Raw run: `tools/evolution_reachability.gd`'s own stdout (deterministic,
verified twice-identical, zero SCRIPT ERROR/WARNING).

## Diagnosis

### The hypothesis to test, and what actually held up

The issue's own hypothesis was: *"mixed play feeds consolidation strictly
faster than any single evolution axis, and/or the frost/fire axis counters
are fed by too few skills."* The table confirms the **first half** cleanly
and **falsifies** the second half:

**Axis-counter widening: falsified.** Every ice/fire skill already tallies
its element correctly (`_tally_skill_use`, `wi_combat.gd`) —
`frost_bolt`/`ice_shard`/`icy_floor` → `ice_cast`;
`flame_jet`/`flame_scythe`/`flare_burst`/`flame_pillar` → `fire_cast`.
There is no missing tally wiring anywhere in the mage kit. `flame_bolt`
(the only OTHER fire-tagged, single-target skill that exists in
`skills.json`) is never granted to any player class — its description
("A hissing dart of **goblin** fire") marks it as enemy-only flavor
(goblin casters), not a player Mage skill; granting it to the player would
be a canon violation, not a data fix.

### Structural finding 1: warrior's axis is naturally exclusive; mage's is not

`power_strike` (`weapon: "sword"`) and `piercing_strikes`
(`weapon: "spear"`) both route through `WICombatBuild.weapon_gated_kit`,
which keeps **only** the skill matching the single equipped weapon slot —
a real player physically cannot field both in the same fight. Warrior's
Replacement axis is therefore forced toward ~100% dominance the moment a
player commits to *any* weapon, with zero deliberate min-maxing required
(`warrior_sword`/`warrior_spear` both resolve cleanly by waking 23-24).

`frost_bolt` and `flame_jet` carry **no** `weapon` tag — both are
simultaneously available regardless of equipment, always. There is no
natural exclusivity pulling a mage toward one element the way a weapon
slot pulls a warrior toward one weapon.

`warrior_hypothetical_mixed` (a **counterfactual**, not reachable in real
play — modeled only by skipping the equipment gate the same way every
un-gear'd `sim_combat_batch.gd` `BUILDS` row already does) shows that even
a hypothetical sword/spear alternator still resolves dominance reasonably
cleanly (62% spear share by waking 20, cheaper AP cost letting it fit
twice a turn) — underscoring that mage's problem isn't "two damage skills
existing," it's the *complete absence* of anything forcing a choice.

### Structural finding 2: flame_jet's line shape starves fire_cast even under deliberate play

`frost_bolt` is a plain single-target `spell_damage` skill (any visible
foe, range 4). `flame_jet` is the ONLY pre-evolution fire active, and it's
a `line_damage` skill (must line up a direction with a foe in it, and
without hitting an ally). In the shipped 1-3 enemy compositions
(`goblin_ambush`/`chieftains_raid`), that geometry constraint is brutal:

- `mage_mono_fire` (deliberately attempts flame_jet **every** possible
  action, falling to melee only when it truly can't line up a shot) banks
  only 22 fire_cast in **150 fights** (0.15/fight) — versus
  `mage_mono_ice`'s 46 ice_cast in just **11** fights (4.2/fight), a
  ~28x throughput gap. Mage never even reaches level 10 (spell_cast 45
  needed) under this profile.
- `mage_deliberate_balanced` alternates its own INTENT 50/50 every waking,
  yet the realized tally is 42 ice / 3 fire (93% ice) — the intent can't
  overcome the skill's own low landing rate.

This is **not** a threshold problem: no `dominance_share`/`min_uses` value
would make Fire Mage fair, because the real bottleneck is throughput
(banked fire_cast per waking), not the dominance bar's height. This is an
**earn-surface / skill-design content gap**, reported below, not retuned.

### The smoking gun: the consolidation race (THE user's exact scenario)

`mixed_mage_warrior` — a player genuinely splitting combat time between
warrior actions and both mage elements (50% warrior-sword, 25% ice, 25%
fire) — gets **offered [Spellsword] at waking 21**, while mage's own
Replacement doesn't resolve until **waking 39** (roughly 2x later) and
warrior's resolves right around the same time as the offer (waking 20).
The offered state (`warrior ≈ level 10, mage ≈ level 10`, combined ≈ 21)
lands almost exactly on the shipped `qa/fixtures/near_consolidation.json`
fixture's own hand-authored position (`mage: 7, warrior: 6`) — this is not
a contrived edge case, it's the ordinary shape of "trying both classes."

Consolidation's gate (`min_parent_level: 6`, `min_combined_level: 13`,
`data/classes.json`) requires roughly **half** of either parent's own
`evolution.at_level` (10) — a structural, not incidental, gap. Accepting
the offer **erases both parents** (`accept_consolidation`), and
[Spellsword] has no `evolution` block of its own (a `SPARSE TABLE`,
levels 9-16 only) — so accepting the first offer **permanently forecloses**
ever reaching [Ice Mage], [Fire Mage], [Blademaster], or [Spearmaster] for
that character. A player who takes the first appealing named-hybrid offer
(as most players would, with no signal that it's foreclosing anything —
opaque-until-sleep by design) never sees a single-line evolution again.
This is the user's report, exactly.

## The fix taken (smallest honest, evidenced, zero collateral)

**`data/classes.json`: `helper.evolution` gained `balanced_grants:
["soothe_clientele", "sweep_the_tables"]`.**

`helper_deliberate_balanced` proved Helper had the *same* dominance
problem as mage's balanced case (share 0.50 < 0.6) but **no** Generalist
fallback at all (mage's `balanced_grants: ["ice_shard", "flare_burst"]`
already existed) — a genuinely mixed Serve/Deliver player used to sit in
permanent, unrewarded Waiting forever. One representative field skill per
target (`soothe_clientele` from [Barmaid]'s own L10 kit, `sweep_the_tables`
from [Server]'s), mirroring mage's exact one-skill-per-target convention.
Both are `field: true`/exploration-only (no `ap_cost`/`effect` combat
shape) and Helper never appears in any GATED `sim_combat_batch.gd` cell at
evolution-eligible levels (`warrior2_helper2` is measured-only at
`helper: 2`, far below `at_level`) — **zero combat-balance surface**,
purely additive. Re-verified live: `helper_deliberate_balanced` now reads
GENERALIST at waking 109 instead of NEVER (see table above).

No other threshold in `mage`/`warrior`/`archer`/`helper`'s `evolution`
blocks was touched — the table shows every mono/near-mono profile already
resolves cleanly (waking 11-80), so `dominance_share`(0.6)/`min_uses`(12)
are not the bottleneck for realistic single-focus play.

## The fix considered and REJECTED: retuning consolidation's thresholds

The obvious data-only fix for the consolidation race is raising
`min_parent_level`/`min_combined_level` so neither parent line can be
swept into [Spellsword] before it's had the same chance to evolve on its
own — concretely, `min_parent_level: 10` (matching each parent's own
`evolution.at_level`) and `min_combined_level: 21` (so a truly-balanced
50/50 split can't undercut a single parent's L10 floor; minimal qualifying
pair (10, 11) → merged level 14, re-deriving [Spellsword]'s `SPARSE TABLE`
floor from 9 to 14 per the `wi-adding-a-class-or-skill` skill's own
convention).

This was **built, tested, and reverted** after an empirical check:

- The T4 boss-balance contract this floor feeds
  (`vault_construct_t4_party`, gated 0.55-0.95 win rate / 3-12 median
  rounds) **holds** at the new floor: a spellsword built at level 14 reads
  win_rate 0.91 / median 5 rounds. No boss retune needed there.
- But `t3_spellsword9` (the SAME class of build, just at level 9) is also
  the reference build for **three separate GATED T3 encounters**
  (`briar_collectors_t3_spellsword9_hunter` 0.55-0.95,
  `briar_collectors_deep_t3_spellsword9_hunter` 0.55-0.85,
  `hired_blades_t3_spellsword9_wilovan` 0.6-0.8, all in
  `tests/sim_combat_batch.gd`). Bumped to level 14, all three read
  **above 0.88** — outside every one of their bands, trivializing content
  that was deliberately tuned against the T3 "expected build ≈ spellsword
  9" (`docs/design/region-tiers.md`, a **ratified** design table, issue
  #66, 2026-07-11).
  [Record note, 2026-08-05 (#396 Task 6): the two briar cells cited above
  no longer exist — the hollow fields no ally, so every `_hunter` briar
  cell was deleted. Their solo successors are
  `briar_collectors_t3_warrior10_solo` and
  `briar_collectors_deep_t3_warrior10_solo`. The finding stands as
  recorded; only two of the cell names it cited are gone.]

Raising consolidation's floor high enough to meaningfully close the race
therefore requires re-tuning at least three encounter rosters (and
possibly revisiting the ratified T3 tier's own "expected build" number) —
genuine content-balance work with its own gate discipline, not a
progression-threshold value. **Reported to #93** rather than executed
here: the recommended values (`min_parent_level: 10`,
`min_combined_level: 21`, floor 14) are pinned above so a future retune
pass doesn't have to re-derive them, but the T3 roster re-tune is a
prerequisite, not an afterthought.

## R3 EXECUTED (class-foundation pass, #93/#95/#96, 2026-07-12): the fix
## landed, prerequisite cleared

The retune above is no longer rejected-pending — the class-foundation
pass's R3 ruling executed it, WITH the coupled T3 rework this page's own
empirical check said was the prerequisite. `data/classes.json`'s
`consolidations[0]`: `min_parent_level` 6→10, `min_combined_level` 13→21
(the exact pinned values above); `spellsword`'s `SPARSE TABLE` floor
9→14 (re-derived from the same formula this page already walked).

**The T3 coupling, resolved differently than either option this page
weighed** — not "re-tune the three rosters" and not "leave the
consolidation race broken": the T3 tier's own **reference build**
changed instead. "Spellsword ~9" (the ratified issue #66 tier
expectation) is now structurally unreachable — consolidation can never
land below level 14 — so a real T3-arriving player is a MONO warrior at
the tier's own level ceiling (10), not a consolidated hybrid at all. The
three GATED encounters (`briar_collectors_t3_*`, `briar_collectors_deep_
t3_*`, `hired_blades_t3_*`, `tests/sim_combat_batch.gd`) were re-derived
GATED at a new `t3_warrior10` build (warrior 10, the SAME T3 gear basis
`t3_spellsword9`/`t3_warrior9` already established) — **all three landed
inside their EXISTING bands on the first attempt, zero roster/stat
changes to any shipped combatant**:

| encounter | band | old (t3_spellsword9, now measured) | new (t3_warrior10, GATED) |
|---|---|---|---|
| `briar_collectors` | 0.55-0.95 | 0.94 | **0.93** |
| `briar_collectors_deep` | 0.55-0.85 | 0.79 | **0.73** |
| `hired_blades` | 0.6-0.8 | 0.76 | **0.75** |

The old `t3_spellsword9`/`t3_warrior9`-gated/measured cells were NOT
deleted — they lost their `win_lo`/`win_hi` and became measured
historical baselines (the "Off-tier baselines" convention,
`docs/design/region-tiers.md`), so the before/after delta stays visible
in `sim_combat_batch.gd` rather than lost to git blame. T4's own shipped
`vault_construct_t4_party` gate stayed PINNED to `t4_spellsword11_party`
(a working, tuned boss fight — R3's own ruling was not to re-tune it
over a reachability-only floor change); a `t4_spellsword14_party`
MEASURED companion cell was added at the real new floor and reads
0.91/5 median rounds — matching THIS page's own "built, tested" finding
above almost exactly, re-confirming that number rather than contradicting
it.

**The re-run proof (`tools/evolution_reachability.gd`, re-run verbatim,
deterministic, zero SCRIPT ERROR/WARNING):**

| profile | target | outcome | waking (level) | consolidation cross-check |
|---|---|---|---|---|
| `warrior_sword` | warrior | REPLACEMENT → [Blademaster] | 23 (L10) | — |
| `mage_mono_ice` | mage | REPLACEMENT → [Ice Mage] | 11 (L10) | — |
| `mixed_mage_warrior` (decline every offer) → **warrior** | warrior | REPLACEMENT → [Blademaster] | **20** (L10) | (same offer as below) |
| `mixed_mage_warrior` (decline every offer) → **mage** | mage | REPLACEMENT → [Ice Mage] | **39** (L10) | offered at waking **39** (→ [Spellsword] L15) |

**The inversion, read directly off this table:** under MONO play, both
axes still resolve early and cleanly (warrior 11-24 wakings, mage 11-26
— unchanged from the original table, since neither single-class profile
ever qualifies for a consolidation offer at all). Under MIXED play (THE
user's exact original scenario — 50% warrior-sword, 25% ice, 25% fire),
the warrior HALF now evolves into [Blademaster] on its own at waking 20 —
**before the consolidation offer ever appears**, the opposite of the old
table's "offered at waking 21, mage's own Replacement not until waking
39" race. The offer itself now surfaces only at waking 39, against an
ALREADY-EVOLVED swordsman (continued mono investment pushed it to level
12 by then: `merged = max(ceil(2*22/3), max(12,10)) = 15`, matching the
logged L15 offer) and a mage just reaching its own L10 threshold — co-
arriving with mage's OWN Replacement, not preempting it by 18 wakings.
A mixed player now sees BOTH single-line payoffs (Blademaster genuinely
held, Ice Mage's own evolution resolving the same beat) before ever
facing the consolidation choice, exactly the exit criterion this pass
set: "evolution-first under mono play; consolidation at 14+ for mixed."

Re-verified alongside: `class_evolution_loop`/`generalist_loop` (both
single-class fixtures — `near_evolution.json`/`near_generalist.json`
hold only `{"warrior": 10}`/`{"mage": 10}`, no second parent line, so
`check_consolidation` can never fire regardless of threshold; both
canonicals re-ran BYTE-IDENTICAL, no fixture edit needed — confirmed,
not assumed). `near_consolidation.json`/`pending_offer.json` (the two
fixtures that DO hold both parent lines) were re-based to `{"warrior":
11, "mage": 10}` (sum 21, the new boundary, matching this page's own
`(11,10) → 14` derivation) — `consolidation_flow`/`consolidation_reload`
re-derived and green; the DECLINE leg's own toast changed honestly (both
parents now individually clear `evolution.at_level`, so declining
re-triggers a real per-class "Waiting" outcome for each — two toasts,
not the old fixture's "You sleep soundly." fallback, since that
class-below-at_level shortcut no longer applies to either parent).

## Content gap CLOSED: Fire Mage's earn surface (R2 executed, #93 —
## measured 2026-07-12, review wave)

Per "Structural finding 2" above, Fire Mage was never blocked by a
threshold — it was blocked by `flame_jet` (the only pre-evolution fire
active) being line-shaped, landing at ~1/28th `frost_bolt`'s rate even
under maximally deliberate play. The class-foundation pass's R2 ruling
executed design direction 1 from this page's original report: **[Flame
Dart]** (`flame_dart`, single-target `spell_damage`, fire, range 4) on
mage's L2 grants — frost_bolt's fire twin, at a disclosed cost premium
(2 AP / 3 MP vs frost_bolt's 1 AP / 2 MP; see the skill's own
`skills.json` `_comment`). The audit tool's `mage_mono_fire` policy now
forces `flame_dart` (the same `_policy_force_spell` shape `mono_ice`
uses for `frost_bolt` — equal casting terms), and **the measured row
inverted from NEVER to a clean Replacement**:

| profile | outcome | waking (level) | final banked tally |
|---|---|---|---|
| `mage_mono_fire` (deliberate flame_dart) — **was NEVER, stuck L6** | REPLACEMENT → **[Fire Mage]** | **31** (L10) | won_combat 24, melee_hit 44, spell_cast 45, **fire_cast 45** |
| `mage_mono_ice` (unchanged, for comparison) | REPLACEMENT → [Ice Mage] | 11 (L10) | spell_cast 46, ice_cast 46, melee_hit 4 |

**The "fire ≈ ice" exit criterion, with numbers:** at evolution, the
mono-fire tally is **45 fire_cast / 45 spell_cast** — cast-for-cast
parity with mono-ice's 46/46. The earn-surface hole is closed: every
deliberate fire cast now banks, exactly as ice always did. The remaining
waking gap (31 vs 11) is NOT residual earn-surface asymmetry but two
priced-in, disclosed structural differences: (a) `flame_dart` is a mage
**L2** grant while `frost_bolt` is L1 — mage L2 gates on `won_combat: 3`,
so the fire purist melees the first ~3 wakings before the kit arrives;
(b) flame_dart's deliberate AP/MP premium buys fewer casts per fight on
a low-level MP pool. Both were explicit R2 design choices (fire as the
slightly-later, slightly-pricier element), not bugs — and the dominance/
min_uses math treats the two axes identically from the first cast.
The `mage_deliberate_balanced` and `mixed_mage_warrior` profiles
deliberately still cast `flame_jet` for their fire share: they model the
pre-R2 shipped-kit shape, and their measured rows anchor the R3
inversion proof above — re-pointing them would silently re-derive that
committed evidence (their rows re-ran byte-identical in this wave's
re-run, confirming the mono_fire change touched nothing else).

## Every evolution/consolidation target audited

Post-R1/R4/R5 (class-foundation pass), the evolution-carrying set grew:
`mage` (Replacement×2 + Generalist), `warrior` (Replacement×2), `archer`
(Replacement, single-axis), `helper` (Replacement×2 + Generalist, the
fix above), **`tactician`/`diplomat`/`rogue` (R1) and `trader` (R5) —
each single-axis Replacement onto its own leveling counter** — plus the
consolidations (`spellsword`, and R4's `innkeeper`/`ranger`).
`sharpshooter`/`swordsman`/`spearmaster`/`ice_mage`/`fire_mage`/
`barmaid`/`server`/`strategist`/`emissary`/`infiltrator`/`merchant`
carry no `evolution`/`consolidations` block of their own (terminal or
evolution-only targets), confirmed by a full scan of `data/classes.json`.

**The four new ladders, audited (review wave 2026-07-12 — chore-style
profiles at 1 counter/waking, a conservative floor since every one of
these counters can bank more than once per waking in real play; see
`_simulate_chore_profile`'s doc comment):**

| profile | target | outcome | waking (level) | final banked tally |
|---|---|---|---|---|
| `tactician_observer` (1 observed_things/waking) | tactician | REPLACEMENT → [Strategist] | 55 (L10) | observed_things 55 |
| `diplomat_social` (1 gossip + 1 befriend/waking) | diplomat | REPLACEMENT → [Emissary] | 36 (L10) | heard_gossip 36, befriended_moments 36 |
| `rogue_sneak` (1 sneaked_past_danger/waking) | rogue | REPLACEMENT → [Infiltrator] | 36 (L10) | sneaked_past_danger 36 |
| `trader_commerce` (1/waking, class EARNED mid-run at counter 5) | trader | REPLACEMENT → [Merchant] | 68 (L10) | deliberate_commerce 68 |

All four resolve as clean single-axis Replacements — no dominance
stalls, no NEVER rows (each `targets` key IS the class's own leveling
counter, so reaching L10 structurally implies min_uses meta-satisfied;
the 2-keys-1-target trap this pass designed around never arises). The
diplomat row is notable: its level table compound-gates on BOTH
`heard_gossip` AND `befriended_moments`, so the profile banks both — a
one-counter diplomat stalls on the OTHER counter's level gate, which is
the authored intent (a Diplomat who never befriends anyone isn't one),
not a reachability bug: `heard_gossip` alone still drives the evolution
axis once levels arrive. Trader's row includes its own `gained_by` walk
(class earned mid-run at deliberate_commerce 5, wakings 1-4 classless) —
the only profile in the audit that models class ACQUISITION, not just
the ladder.

## Re-verification (original, Helper-fix-only — see "R3 EXECUTED" above
## for the later, larger re-verification)

Since the executed fix was purely additive at the time
(`helper.evolution.balanced_grants`, a new key on an existing block — no
threshold, no level-table, no skill-effect change), `class_evolution_loop`,
`generalist_loop`, and `consolidation_flow` (all mage/warrior-only
scenarios) were structurally untouched: re-run green, byte-identical
positions. No `sim_combat_batch.gd` cell exercises Helper at an
evolution-eligible level, so the balance harness needed no re-run for this
change specifically.

**SUPERSEDED for `consolidation_flow`/`consolidation_reload` by the class-
foundation pass R3 (2026-07-12, "R3 EXECUTED" section above)** — the
consolidation threshold retune that section executes changes
`near_consolidation.json`/`pending_offer.json`'s own held levels (no
longer byte-identical to this original state), and the "Every evolution/
consolidation target audited" section just above this one is now a
historical snapshot of the PRE-R1 catalog — R1 (the same pass) gave
`tactician`/`diplomat`/`rogue`/`sharpshooter` real `evolution` blocks of
their own (see `docs/superpowers/plans/2026-07-12-class-foundation.md`),
so that sentence no longer holds for the current catalog. Left unedited
above as the audit trail of what #96 originally scoped; this note is the
correction.
