# Wandering Inn RPG Handoff

## Current release

**v0.12.1 SHIPPED 2026-07-19 (mobile hotfix: #196/#197/#202 + gold caps; deploys watched at tag). v0.12.0 2026-07-18, all three targets green** (Release: itch
html5 + Windows/Linux desktop, full QA on real assets; Pages deploy
green on the tag trigger). Prior: v0.11.1/v0.11.0/v0.10.0 (2026-07-18),
v0.9.0 (2026-07-17), v0.8.0 (2026-07-15) (run 29451275728 green: full QA on real
assets, itch html5 deploy, Windows+Linux desktop exports). Contents: #91/#118
Chronicle all-encounter victories (PR #120), #115 collapsible field readout
(PR #121), #119 verification hardening (PR #122), #114 scannable pickers
(PR #124), #76 footstep families + dialogue ducking (PR #125), #116
biome-aware blocked-cell props (PR #126), #102 comment restoration,
wi-delegating-to-codex + PR-per-issue-close conventions. 511 ids frozen at
0.8.0 (`victories` joined STRUCTURAL_LITERALS — see wi-shipping's new trap
note). Per-issue detail lives in the merged PR bodies (`gh pr list --state
merged`), not here.

## 🏃 RUNNING (2026-07-19, v0.13 wave day 1 — 7 PRs merged)
- **b4 #219 Grimalkin studies SHIPPED** (PR #239 → 48b23da): two
  board:false private study rows (accept at his hub via the `studies`
  node, turnin voice param — his arms verbatim-pinned), canonical
  `grimalkin_study_loop` seed 6 + fixture. Review wave (14/14
  confirmed): abandon-lockout hide_when killed, desk/paper matching
  (`turnin_is_foreign` — met foreign postings were consumed+paid at
  the wrong desk, both directions live-reproed), voice re-cut, three
  unit blocks. Study conditions ride #211's weighted counters BY
  DESIGN — flagged into the #211 taste read. Skill folds landed
  (facing vector, bool-gate hides, desk seam, hub-row index shifts).
- **#194 CLOSED** (god-file pair fully dissected): #227/#228/#229
  (wi_game 2345→2020: WIInteractions/WISleepBeat/WICombatBanking) +
  #231/#232 (world 1624→1435: WIEntityVisualFactory/WICameraController).
  Every seam byte- or pixel-identity-proven + reviewed.
- **#211 SHIPPED FLAG-ON** (PR #230): challenge-weighted leveling live —
  see Taste queue for the FEEL read; all knobs data.
- **#111 spec on main** — go/no-go pending (Taste queue).
- **b1 Rags SHIPPED** (PR #233 → 8f4dba8, closes #199): conduct-gated
  meeting, two-visit "The Chieftain's Price" (SUPPLY/BROKER/FIGHT, all
  real costs), widened mercy contract (back-away banks goblins_spared),
  `absent` gate arm + validators, Erin betrayal consequence, interim
  sprite (c3 bespoke in VISUAL-LOG). Whole-branch review's MAJOR
  (one-visit Invrisil shape) fixed pre-merge.
- **#217 parleys SHIPPED** (PR #234 → dc377b7): four talk-down arms
  (Beast Tamer/Detect Magic/permit/Charming Smile+staked bout), all
  dormancy-based (new `dormant_entity` effect — the review's HIGH:
  removal would have foreclosed four repeatable cull bounties).
- **b2 #218 Ratici's fence SHIPPED** (PR #235): rotating stock behind
  the Brothers' trust, Wilovan handoff, all economy guards proven.
- **b6 #221 fragment trade SHIPPED** (PR #236): trade-by-choice with
  the reviewer-live-reproed duplicate-grant HIGH fixed via a distinct
  setting item; grant-duplicate validator = ledgered follow-up.
- **b5 #220 Invrisil aftermath SHIPPED** (PR #237): Coyle answers both
  closes (pool stages harmonized to the shipped hub facts — the review
  caught a near-retcon), 7 passersby de-cloned, 3 shopfront observes.
- **b10 #204 ruin stone SHIPPED** (PR #238): order-enforced rune pair
  at the recovery beat, zero sim/combat changes, door-chain seeds all
  safe. CHOICE-LOG carries the ritual-vs-difficulty adjudication + the
  guardian-wake escalation offer (one word flips it).
- **b7 ack wave COMPLETE (2026-07-19, 4 PRs / 6 issues)**: #201/#203
  (PR #240 — Relc on the approach lane, leaves post-clear), #207
  (PR #241 — every delivery recipient acknowledges; standing
  familiarity stages promoted above warm terminals), #212/#213
  (PR #242 — Tamer signposts: Krshia pointer ×6 pools, den
  telegraphs, Selys signpost above her terminal, corusdeer observe),
  #214 (PR #243 — Detect hint cited as shipped (cellar_wardwork),
  [Open Doors] door_flavor arm with the openable-door predicate,
  pond_edge fishing affordance + the interact requires_item seam).
  Every PR: adversarially reviewed (workflow for b4, single agents
  under the CAUTION usage tier), fix waves applied, 26/26 units +
  147-script sweep + 6/6 checks READ. Skill folds: desk/paper seam,
  bool-gate hides, facing vector, hub-row index shifts, pool-stage
  shadow-out audit.
- **DAY-2 AFTERNOON RUN (guard re-banded 80/90/96 by user, tier OK)**:
  #200 boss music (PR #244), a7 #208 auto-slot (PR #245, review HIGH:
  item-pin AUTO collapse fixed), a9 #246 Import/Export Save (PR #248,
  review F1: title-export data-loss fixed), a6 #206 day pacing ×2
  (PR #249, 400/900 bands + the fixture/crossing pin wave; the
  reviewer's lantern MEDIUM refuted by probe). Branch protection ON
  (6 required checks; [ci-full] platform-enforced on PR heads). #247
  Friends-of-the-Inn spec on main (4 asks gate implementation).
  a3 #215, a4 #216 (all 3 slices — credits/volume, journal drag-scroll,
  line-skill tap-aim + playtest touch nav), a5 #205 dark-field
  legibility all SHIPPED. a5 is EYE-GATE: user FEEL confirm pending
  (before/after sent; VISUAL-LOG box open; one knob tunes, reversible).
  Remaining board: #195 listening queue (user), a8 journal tabs, c1-c6
  art, d1 post-read. In flight: #257 ci_sweep result.json hardening
  (closes #256 — the false-green class). Open follow-up: #256-adjacent
  grep-widen (bare ERROR: slips the SCRIPT ERROR|Parse Error|WARNING
  net). NEW BUGS filed: #253 Import Save mobile (web file-input flashes
  refusal — DEBUG TOMORROW per user).
- Spoiler bar reminders for b1: Rags early-volume-safe; "Magical Door".

## 📋 QUEUE (value order)

0b. **#247 Friends of the Inn (user idea)**: met canon NPCs rotate
   through the inn as servable guests — spec-first (context-aware
   dialogue: inn-specific lines, home-hub options REMOVED in inn
   context; home-row gating; per-NPC QA census), board row d1.
0. **#246 Import/Export Save — SHIPPED** (PR #248): Settings rows live,
   three platform arms, title-export dumps the Continue slot (the
   review's data-loss catch), non-destructive import. Web round-trip
   ask in the taste queue.

1. **Human playtest of v0.8.0** — ear-gated audio pass (footstep families
   inn→street→sewers, music dip under dialogue) + taste queue below.
2. **#111 safe project rename:** HOLD — keep `config/name="Wandering Inn RPG
   v4"` until save migration is deliberately designed and tested.
3. **#19 Steam:** HOLD — user-secret provisioning + #20 ruling.
4. **#123 canonical redesigns** (social_loop/garden_walkthrough/
   class_evolution_loop pre-hold the class their script earns) — post-release.
5. **Class/Skill expansion — SPEC READY, awaits user GO + one ACK:**
   `docs/design/class-expansion-spec.md` (Waves A+B, 445 lines) implements
   the proposal with §8 decisions already RULED (witch no-gate, [Flash
   Step] Necro L7 + Mage L11, Necro evo parked). Roster: [Runner]→
   [Courier], [Hedge Witch]→[Witch], [Necromancer], [Cook]→[Chef],
   [Scout] consolidation, mage [Detect Magic]/[Flash Step]. ONE pending:
   ACK [Eagle Eyes]'s AMBIGUOUS-lean-PASS name (keep vs ORIGINAL). On go,
   dispatch Wave A (data-only, zero engine risk) first. NOTE: user
   expected this spec 2026-07-19 and hadn't seen it — surface it.

## 👀 TASTE QUEUE (new this wave, user review)

- **a6 #206 PACING FEEL READ**: day is now ~2x (dusk 400, night 900
  actions — both doubled; only-dusk would have compressed the dusk
  window). One knob in data/moods.json — say the word and any band
  re-tunes in minutes.
- **#247 FRIENDS-OF-THE-INN SPEC READ (4 asks, defaults bold)**:
  docs/design/2026-07-19-d1-friends-of-the-inn-spec.md — roster (6),
  seat count (2), double-presence v1 adjudication (accept), pilot
  pair (Selys+Krshia). Implementation gates on this read.
- **a9 #246 CROSS-DEVICE ROUND-TRIP ASK**: Export Save / Import Save
  are live in Settings (PR pending). The web arms (itch html5 blob
  download + file picker) are traced-only in CI — do one REAL round
  trip when convenient: export on desktop, import in the browser (or
  reverse). Title-screen Export dumps the Continue slot; in-world
  Export dumps the live game.
- **b9 #200 boss music EAR-GATE**: deep_warren now plays
  battle_for_despair (bundle-top energy; the old moody track moved to
  the snare fight). Load the deep-descent playtest state, pull the
  boss — say the word if it reads wrong and the runner-up
  (battle_for_humanity) wires instead.
- **b9 #195 LISTENING QUEUE (~30 files)**: menu candidates ×3, jingles
  ×8, flagged stingers ×16, bed exceptions ×2 — ordered in
  docs/design/2026-07-19-b9-audio-selection.md. Survivors wire
  slot-by-slot as small PRs.

- **b1 Rags reads (3)**: (a) backing away from goblins now counts as
  mercy everywhere (garden leg pacifist-reachable) — flip = split the
  counters; (b) the conduct bar is "showed mercy once AND never hunted
  the camp" — say if the bar should be stricter/looser; (c) Rags's
  voice (1-4 word utterances; the sealed-node chess line is the one
  earned stretch) — windowed shots in the PR, or meet her live:
  gates are ~3 Erin chats + errand closed + one spare.

- **#211 leveling FEEL (flag is ON)**: pacing now pays adversity, not
  repetition — early real fights pay double, gray-band grinds pay ~0,
  quest closes are the big movers. EVERY knob is data
  (data/progression.json) and the pace harness re-measures in minutes;
  say the word to soften any curve. Numeric act-band gates lock after
  your read.

- **#111 GO/NO-GO (spec ready)**: rename to "Wandering Inn RPG" via
  first-boot save migration (Option A in the spec, §6) — GO dispatches
  implementation as a v0.13-window package; NO-GO keeps v4 name (a
  zero-risk itch-page-only cosmetic rename is available either way).

- **#92 Minor:** a heal consumable used at full HP still consumes
  (matches the skill precedent; honest "Healed 0 HP" toast). Want
  items to refuse-at-full-HP? Say so — small sim arm.
- **#87b feel notes:** coalesced multi-cell AI moves glide in a
  straight line (can cut a corner visually, windowed-only); enemy
  turns flow tighter with TURN_ENDED's breath removed. Both deliberate;
  flip if playtest reads wrong.
- **boulevard_duel_ring 0.92 win-rate** sits near the 0.95 GATED
  ceiling and reuses hired_blade_knife_a/b (shared with the warehouse
  quest, no inheritance) — any future retune of those thugs re-gates
  this cell by hand.

**Mobile re-test worth doing on v0.7.0:** the two blockers you reported
are fixed — sprite-tap now paths to a cardinal cell and interacts;
pause/journal/inventory open by tap; Settings rides the pause menu.

**USER queue standing:** itch mobile-friendly flag (if not yet ticked);
localization posture + demo boundary; #19 Steam secrets; the CHOICES
log below.

## ⚖️ CHOICES LOG (ultracode deference directive, 2026-07-11) — FOR USER REVIEW

Decisions I made under "don't block, record for review." Each reversible;
say the word and any flips.

1. **#66 tier table: self-adjudicated GO** (my own spec — fixed tiers
   T1-T5, over-tier-trivial-is-intended). Lane running.
2. **#61 spellsword 15-16: content-first** (author the entries + a
   capstone grant at 16; no sim cap). Wiki-attested name preferred,
   restrained invention sanctioned + flagged.
3. **#63 witch = ELOISE** (canonically RESIDES in Riverfarm — the
   digest's decisive find; Mavika = threat register; Agratha noted as
   better-documented alternative). Invented-within-gap: warm brown
   eyes, sage/mauve palette, teacup prop (all flagged in profile).
4. **Klbkch sub-arm at 1x: ACCEPTED** (antennae+head carry the read;
   flag stays open if you disagree). Same standard applied to Ksmvr
   (whose four arms read cleaner).
5. **#33 Krshia discount: DIEGETIC-FIRST** (waits for her grant line —
   matches the project's diegetic doctrine).
6. **#34 Relc sign line: RESTORE THE SEED COPY IF it passes the new
   copy-fit validator**, else keep the trim (measurement recorded).
7. **#35: gambeson 20g CONFIRMED; barracks stern grade CONFIRMED;
   slot-full refusal line UPGRADED** to the over-capacity line's bar.
8. **#32 (the 18 Social II flags): CONFIRM-AS-SHIPPED across the
   board** with three exceptions — Selys board pick → REPEATABLE;
   Pisces perk → DEFERRED (needs real design, logged); Relc stage-3
   stays NEUTRAL (warmer variant locks out solo-veto players). All 5
   canon reveals stay OBLIQUE; Lyonette home topic stays OUT.
9. **8d boss = construct** (you ratified); **8d B lane dispatched**
   without the gallery-door edit (controller carries it at merge).
10. **Gap-analysis workflow launched** (8 dimensions vs first-class
    RPG bar → judge → adversarial verify) — confirmed gaps become
    issues; dispositions logged here when it lands.
11. **[Flame Pillar]** name (wiki-attested 9.14VM) for the AoE spell;
    ships ICONLESS (all flame icons claimed — VISUAL-LOG).
12. **Old Tower Inn track re-homed** to a tavern-adjacent interior
    (62W lane picks guild vs runners and comments why).
13. **Wave-3 priority order (2026-07-12): #73 + #77 dispatched ahead of #76/#78-#81/#83** — picked for file-disjointness against the live 65/8dC3 lanes (#83 collides with C3's combat-AI arm, #81 with C3's skeleton_scene edits, #64 with 65's dialogue files; #80 is taste-gated). Audio (#76) deferred as controller-asset-pick-heavy.
14. **"What the Seal Kept" quest structure (drafted, lands post-C3)**: stipend SPLIT 5g advance / 15g on report (abandon has real cost); three-pillar halls routes each pay a real cost (FIGHT = HP, SKILL = a 3g trap_kit consumable, TALK = Ksmvr enters the vault fight weakened — fallback to a time cost if the hp-penalty isn't expressible on existing machinery); the C3 vault encounter gates on `horns_delve_started` (banked at Olesm's accept), party fields via `horns_party_formed` (Ceria's intro).
15. **Windup self-hit ruling (8dC3 review F1)**: the construct self-hit on 100% of slams (geometric certainty; 0.86 win rate leaned on ~15-33% self-damage; feed printed "Guardian Construct strikes Guardian Construct"). RULED: windup resolution excludes the CASTER (by actor id, not cell) + re-tune to band; allies in the blast still get hit. Deliberate asymmetry vs player-cast blast_damage (which keeps caster-cell friendly fire as a chosen risk) — documented in the doc comment. Flip = re-tune again.
16. **#77 taste-queue notes (review LOWs, accepted)**: (a) the active-unit brightness pulse (_highlight_actor) is NOT reduce-motion gated — it doubles as the whose-turn cue; gate it if you disagree. (b) At the 130% max text-scale step the combat readout can ride the parchment fold by ~1 line (bounded cosmetic overflow, crash-free) — inherent to keeping pixel rects unscaled; tighten the max step if it bothers.
17. **8dC1 FIGHT-route cost ruling**: review proved the snare fight's "cost = HP" was illusory (0.99 win/2 rounds, and combat HP doesn't persist to the field). RULED: roster-only fix — one tier-appropriate existing combatant added to the snare encounter, cell re-derived aiming GATED band; no stat changes to shipped combatants (protects ruin_guardian_w8's shipped band). Also: vault gate now requires the party formed (a solo player walking past the Horns hit a 4-party-tuned boss with no signpost — ordering accident, not designed hard-mode; awakened_boss's [I go alone] confirm+measured-solo-cell is the designed shape if you ever want a solo-vault mode).
18. **#83 con-retune ACCEPTED (deviation from the roster-only precedent, adjudicated on the merits)**: the ruin wards' guard adoption broke ruin_guardian_w8_relc's band (0.54, verified); the lane retuned the shipped boss con 28→24 rather than forfeit the adoption. Player-facing deltas for your awareness: the door-chain FIGHT leg genuinely plays differently (the old canonical seed now LOSES at ruin_court; re-derived), guardian-with-Relc 0.69→0.59 (harder, low-band), guardian solo 0.01→0.09, night wolves read safer (skirmisher wolves: 0.30→0.48 solo). Flip = drop the wards' guard profile instead.
19. **Yvlon placement + the hearth bench (playtest fix)**: my Ceria line referenced a couch the inn didn't have; the D2 lane parked Yvlon at the literal kitchen hearth between the cook-pots. RULED: bench decor added by the hearth's common-room side (parlor-couch precedent sprite) + Yvlon beside it — the line is now literally true. Flip = move/remove either.
20. **Windup overlay brightened without an in-fight windowed read** (mid-fight shots aren't stageable under combat_autoplay): old color was provably invisible on the vault grade (~13/255 delta); new (1.0,0.25,0.2,0.7) is ~2.5x. YOUR EYES: in the vault fight, is the red warning patch clearly visible the round before the slam?
22. **Rock-crab Relc-downed frontier (lane-24)**: relc_downed 0.83→0.62 at 0.93 win — the ~0.5 target is STRUCTURALLY infeasible in the 0.55-0.95 band for any single-melee roster vs warrior2+relc (melee AI focuses lowest-HP = Relc soaks by design; the measured frontier + two escape routes — per-cell band floor-raise or a windup cadence — documented in the combatant _comment for your ruling if 0.62 still reads wrong).
23. **The Permit Office (8e reconciliation ruling)**: the forge-permit clerk + Grimalkin's exam moved to a market-tier office beside the Grand Lift — the reconciliation review found the exam placed BEHIND the very gate it unlocks (a circular deadlock both lanes independently agreed on) and the stamp's producer had no host entity at all. His forge post ships as dressing. Flip = a pre-lift forge landing redesign.
24. **Papers-for-Pallass Stage 1 ships fee-only (10g)**: the plan's alternate completed-postings-record path needs an aggregate counter that doesn't exist — the lane STOPPED correctly; RULED not to build tracking machinery for one gate. The record path lands if/when an aggregate counter ships for its own reasons.
25. **The 46g Pallass chain on the compounding sink** (10+18+2 papers + 5+8+3 permit, atop invrisil's 18+18): each fee is in the sanctioned band and the 18g stone matches precedent exactly; the CUMULATIVE ~82g three-city travel spend is flagged for the economy ledger pass (also CHOICES-noted at #65). Your call whether mid-game income covers it without board-grinding.
26. **Grimalkin carries no race variants (D-phase)**: the examiner measures, the city profiles — the clerk + stallkeeper carry the Human-friction/Drake-local lines instead. Flip = add his variants.
27. **Haggling is opt-in (class pass)**: the review proved default-discount leaked [Bargain] onto civic fees, wagers, and free rumors — RULED: `haggle: true` opt-in, v1 carrier = the witch's shop only (Krshia's 'no discounts' line honored mechanically everywhere; Pallass/civic never). Thin surface accepted; #92's vendors expand it. Flip = re-mark carriers.
28. **The 50% sell rate ratified** (plan said ~40%; the shipped pre-existing Krshia buyback was 50% — churn-avoidance wins; #92 rebalances holistically).
29. **v0.5.1 cut to itch immediately after #106 lands** (standing don't-block deference): the itch "mobile friendly" flag (your step) is meaningless until a build with combat touch is actually live — v0.5.0 predates #106. Local butler path, same as v0.5.0. Flip = tell me to hold releases for your review first.
30. **Desktop mouse UX change rode #106 (review Minor, accepted)**: during targeting, a click that misses every candidate now CANCELS the aim (was a silent no-op) — the Esc-equivalence contract wants one consistent rule for tap and click. Flip = gate the cancel to touch-emulated events only.
31. **Shipped-boss softening, second round (#90 wave)**: the status riders re-broke two GATED bands; per the #83 roster-only playbook the lane changed two shipped stats — `ruin_guardian` con 24→20 (its SECOND post-ship nerf: 28→24 in #83; cumulative −8 max_hp) and `raskghar_awakened` weapon_die 5→4. Both harness-justified, full history in each record's `_comment`. Ratified: mechanics-variety > preserving a shipped boss's exact toughness. Flip = revert the stats and drop the corresponding riders/adoptions instead.
32. **Golem naming (#97 wave)**: the bestiary lane shipped "Forge Calibration Golem"/"Market Watchgolem" citing the wiki's Golems page — the review proved neither compound is attested (~50 named variants, none of these; no Pallass golems in canon at all) and a wiki-literate player would read them as fake canon. RULED: combat display_name = the attested "Stone Golem" (A/B suffix disambiguates); field names stay descriptive-but-honest ("Miscalibrated Golem", "Stone Golems"). The other four species' names verified clean. Flip = pick different attested variants (Iron/Wall Sentinel) or re-fiction the encounters.
33. **Horns Social II perks ship flavor-only (#89 wave)**: the charter said "one modest perk each"; the lane shipped three in-voice advice/flavor lines (Ceria ice-tip, Yvlon guard-advice, Ksmvr pantry-path) with zero mechanics. Krshia's stage-3 shop discount is the mechanical precedent, but three more mechanical perks pre-#92 = economy churn. RATIFIED flavor-only; #92's economy pass is the natural upgrade point. Flip = spec the three mechanics there.
34. **#92 R4 gate deviation (this wave, review-adjudicated CORRECT)**: the resonance-growth sleep hook gates on `door_awakened` (N=2), not the literal door_study_sleeps trio — same-sleep completion would have double-veiled and broken door_awakening's `lines:1` pin (traced). Flip = re-gate + re-pin.
35. **Stat-grammar softening executed repo-wide (your directive, 186366f)**: both CLAUDE.md files + three wi-* skills now carry the default-with-exceptions form; enforcement code (test_effect_text tripwires) unchanged.

## Commands

```sh
# Play (human)
/usr/local/bin/godot --path wandering_inn_game

# Agent verification (primary)
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<N>   # seed table in wandering_inn_game/AGENTS.md
/usr/local/bin/godot --headless --path wandering_inn_game --quit   # smoke; zero warnings tolerated
```

## Standing environment notes (windowed-exit flake)

- **Windowed QA runs intermittently (~1/3) print an ObjectDB/resource
  leak notice AT ENGINE EXIT after `QA_RESULT: PASS`** — audio teardown
  race, pre-existing (stash-verified on unmodified trees twice: M-FP F
  and M7 E4), never headless, results unaffected. Same family as the
  documented Godot 4.7 shutdown SIGABRT note below. Do not re-diagnose
  per task; grep discipline already exempts nothing — the notice appears
  AFTER the result line, so gates read it correctly as post-result noise
  only when verifying by result.json + in-run grep.

- Godot **4.7.stable** at `/usr/local/bin/godot` (homebrew, user-approved upgrade); 4.6.2 preserved at `/Applications/Godot4.6.app` for frozen v2 only.
- Web QA one-time deps installed: export templates (`~/Library/Application Support/Godot/export_templates/4.7.stable/`), Playwright chromium-headless-shell, `qa/web/node_modules/` (gitignored).
- `potential_assets/` is gitignored (asset licenses forbid redistribution) — never commit it.
- Every handoff records role, branch/base SHA, owned files, verification,
  conflicts, Git/windowed-QA operator, and next action. Provider sandbox
  capabilities are discovered per session; never infer them from a model name.
  zsh does NOT word-split unquoted vars — pass QA-script args explicitly.
  macOS has no `timeout` command.
- **Godot 4.7 rarely SIGABRTs at process shutdown** (macOS crash-report notifications; ~3 occurrences across hundreds of headless runs 2026-07-01→02, incl. one overnight pre-M4). Results/exit codes unaffected so far; user notified, cosmetic. If phantom QA FAILs ever appear with clean QA_RESULT lines, suspect this first (crash-at-exit → exit 134).

*(Older closed-milestone narrative — M0 through M6.5, M-FP, Onboarding O1-O5
build logs, M-BEAUTY, M7 weapons, and playtest triage predating 2026-07-05 —
archived verbatim: `the frozen-archive repo (GabrielGLevine/wandering_inn_rpg) at docs/archive/HANDOFF-archive-2026-07.md`; the 2026-07-11→13
wave/milestone sections pruned at v0.7.0 live in git history of this file.)*
