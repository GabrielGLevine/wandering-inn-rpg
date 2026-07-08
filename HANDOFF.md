# Wandering Inn RPG Handoff

## RC DRIVE TO v0.4.0 — LIVE (2026-07-08; scope = through 8c, Steam OUT)

Landed today on this front: #38 roster collapse, #37 the inn's facade
(⚑ taste: it reuses Riverfarm's building family — say if the inn needs
a fully bespoke silhouette), #25 the Olesm chess match, 8c lane C2
(Invrisil combat data, Wilovan canon [Thug]). Main = a038170, composed
sweep 71/71 green, pushed.

**IN FLIGHT — three concurrent Codex lanes** (worktrees off a038170,
real-asset overlay in): **#22** [Invisibility] field verb,
**8c-C1** Invrisil maps/cast/arrival (Wilovan fronts, parlor guest
couch = the bed rule, portal row zero-code), **polish** #29+#30+#31+#45
(street readability, arena dressing incl. sewers water, VISUAL-LOG
drain, fixture rng_state hygiene). Then C3 "A Gentleman's
Disagreement" → CF (opus whole-8c review, Closes #12/#13).

**USER GATES before tag:** the four playtest checklists (#8, #9, 8b
below, 8c's arrives with CF) + the itch Vol-7 spoiler line (drafted in
chat — paste when ready). Then: verify release.yml fetches bundle-v4,
tag v0.4.0, watch the release, confirm the itch build boots.

## MILESTONE 8b COMPLETE — RIVERFARM SHIPS (2026-07-08; #10 + #11 closed; 70/70; opus FIX-FIRST→fixed→READY; rotation 4/4 + 2 fix waves)

The first Door expansion is live: the village ("harvest light") + the
witch's hollow ("green shade"), the two-form Witch / headman / charmed
villager (the echo tell), "The Price of a Favor" 3-path quest converging
on one `blight_lifted`, the village BRIGHTENS as the reward readout
(bumped to 50/255 mean delta after the rotation read it faint), the
witch's herb vendor opens, and the arrival is the FIRST real exercise of
#8's anchor-stone contract — one portals.json row, zero code
(reviewer-verified). The composed review caught its milestone blocker
again: **Relc was teleporting into every Riverfarm fight** (fiction-
breaking, test-passing) — replaced by "The Hunter" (canon-attested
village [Hunter], Relc's exact kit so R2's tuned bands hold, a real
come-along beat). The rotation's blocker (narrated-but-invisible
threshold candles) + the night-witch legibility floor + the hollow-arena
identity + a bonus catch (night arena's bare black blocked cells) all
fixed on real art. bundle-v4 carries the licensed picks.

**PLAYTEST CHECKLIST (8b, the human gate):**
1. The ally, live: arrive solo via the Door, FIGHT path — does the
   Hunter's come-along beat read naturally (no teleporting guardsman)?
2. Night wolf arena windowed: grey wolf legible on the night grade?
3. The two direction cards day vs dusk — does the contrast tell the
   story (golden village / green-shade hollow, one warm window)?
4. The witch's two forms across a live phase crossing — same person?
5. The brighten payoff post-resolution — legible now? (⚑ TASTE: tuned to
   50/255; say if you want more/less.)
6. The vendor: 4 herb items, prices feel fair post-quest?
7. ⚑ TASTE: the charmed villager's echo — eerie, or does the flat
   verbatim repeat read as a bug? A register cue (delivery/prefix) is a
   cheap follow-up if it under-reads.

## PLAYTEST TRIAGE (controller, 2026-07-08 — findings are directives)

**HOTFIX WAVE — LANDED 2026-07-08 (all 6, windowed-verified; the #8/#9
human-gate playtests are UNBLOCKED):**
1. Bark 2nd-line fold clip (Erin's Garden reveal — THE #9 checklist-item-1
   line — + Watch Guard): the fold-inset measured-band treatment on
   line 2 (the known UI/BARK item, severity-bumped per the report).
2. Inventory opens with the cursor row scrolled out of view (gear_loop
   00) — ensure-visible × inset interaction.
3. PC invisible behind the Awakened Raskghar through the boss reveal +
   veto dialogue — the occlusion family INVERTED (oversized south-anchored
   sprite y-sorts over the PC at the story climax).
4. Friend/foe HP bars all green (design finding, cheap fix, huge
   legibility win): bar color keyed by side — color is the main free
   channel under stats-hidden.
5. "Turn:" glued to the first name (misreads as possessive) — separator.
6. QA: char_creation canonical gains a picker-grid screenshot step.

**MILESTONE-SCOPED (stays queued):** water-as-rectangles + ice payoff
(#29-31 polish wave, sewers-first); fire-pit vs scatter-rock mimicry;
twin street vendors same sprite; Relc's descent-veto walk-on cameo (8d's
descent content is the natural home); 4-line toast graze (watch);
tail-page dialogue open + page indicator (the standing taste pass).
**NO ACTION:** ObjectDB exit flake (documented class, 4th-7th sightings).
**CLOSED BY CURRENT HEAD:** the fountain-statue composite verification —
bundle-v3's windowed garden read on HEAD shows basin+statue rendering
(qa_output/garden_walkthrough/02_garden_day_bright_identity.png).
**PROTECT LIST (the report's "what lands"):** copy voice, Raskghar
silhouettes, dusk hearth-glow/dust motes, garden identity, every
legibility surface — regressions here are fix-first by definition.

## MILESTONE 8a COMPLETE — #9 CLOSED (2026-07-08; GF READY-TO-CLOSE, 66/66, bundle-v3)

The Garden of Sanctuary ships: unlock (act>=III + K=2-of-4, ALL FOUR legs
now producing — #26 goblins_spared + #39 sign_defended landed as
side-lanes), Erin's vine door, the day-bright sanctuary, the memorial
hill, rest parity. GF's rotation caught a REAL blocker: the Garden's
licensed art was manifested but never bundled (the wi-shipping order ran
backwards — controller miss) → six extracts cut, fountain statue
manifested (166 paths), **bundle-v3 released + fetched**, identity
re-verified on real art (green garden, sky-mist, fountain composite all
land). GF carries: observe-override doc tightening + empty-base-observe
trap comment → #44; sign_defended's producer is the MANDATORY tutorial
fight, so that leg is near-universal — the act gate carries the earn
weight (honest note, not a bug).

**PLAYTEST CHECKLIST (#9, the human gate):**
1. The unlock, cold: work + Wrong Order → the qualifying sleep reads
   ordinary; Erin's next talk surfaces the reveal unprompted. Earned
   surprise, or telegraphed?
2. The vine door at the inn — legible as new/special vs the pre-unlock
   bare wall?
3. Eyes-closed test on REAL art, incl. at dusk/night — unmistakable in
   2 seconds? No darkness ever, by eye?
4. The memorial hill read as a SET ([Appraise] each) — remembrance, or
   does the waiting goblin plinth read as a gap? (Its producer is live
   now — a merciful playthrough fills it.)
5. Rest parity at garden_bed — the flavor line next to a class-level
   sleep: natural or crowded?
6. Save/reload INSIDE the garden (the one code-traced-only seam).

## NEW USER DIRECTIVE (2026-07-07) → issue #37

The inn's floodplains exterior needs a DISTINCT visual identity (reads as
generic Liscor building today). Filed as #37 (art/polish, size:M) with the
canon levers (hilltop read, facade, sign placement, warm night window
light) + the licensing rails. SERIALIZES behind the 8a D-lanes
(sprites/skeleton contention); natural slot = right after DF, riding A1's
pick tables. PixelLab generations available (user-corrected) — bespoke facade gen is runnable when #37 dispatches.

## M-STEAM: #18 + #19 + #20 ALL CLOSED (2026-07-07) — one user gate left

**#18 controller support SHIPPED** (merge 3a708f6, 59/59 re-gate): pad
bindings on the action-driven nav, LB/RB+A slot idiom both hotbars, title
gesture + name entry pad paths, device-aware hint layer (14 code strings
+ 6 data strings re-pinned device-neutral). Review fix wave killed the
interact/confirm-share-A dispatch-order trap + GDI-veil overlap.
⚑ **USER GATE: the physical pad / Steam Deck pass** —
`docs/design/pad-playtest-checklist.md` (harness can't inject pad events).
**#19 shipped** (presets, gated SteamPipe CI, store assets — regenerated
on REAL art after the placeholder catch; `docs/steam/CHECKLIST.md` = your
Steam-account/secrets actions; trailer flagged undelivered). **#20
ratified: FREE on Steam.** M-STEAM remaining: your checklist actions +
the pad pass + trailer (needs new capture tooling).

## ART PRE-PRODUCTION COMPLETE (2026-07-07): all 4 regions delivered + merged

Four Fable art-director lanes (user directive: map art decoupled from
wiring) — ALL MERGED, mockups delivered to the user, leak_check clean
throughout. `docs/design/<map>-art/{direction,picks,pixellab-batch,
handoff}.md` per region; owned PixelLab outputs + licensed-mixed mockups
in `potential_assets/pixellab_2026-07-07_<map>/` (gitignored). ~53 of 761
generations spent total. Highlights: **Pallass** two-tier shelf grammar,
three-city HSV quarantine rows, 17 gens (⚑ slab-vs-slate tint call).
**Invrisil** floors + gold accents fully OWNED (public repo ships its
signature bundle-free), numeric quarantine 43°/25°/31°. **Garden** built
on the user's benchmark (dusk grade rejected under no-darkness),
`stoneify.py` mints memorial statues for 0 gens, memorial-on-the-hill
per canon Ch 7.11 (⚑ overruled controller's statue-in-water riff — user
may re-open); Fairy Forest user suggestion evaluated: 1 conditional
adopt (the natively-daylight Old Tree, if the wired map out-sizes one
screen), 11 reasoned rejects, ramp-remapping licensed art ruled OUT
(derivative-committing). **Riverfarm** full owned village set incl. the
8b witch cottage; user's farmstead benchmark verified achievable, drove
the river-dock frontage. Wiring tasks (#9, #10, #12, #16) consume the
per-region handoff.md files.

## M-STEAM OPENED CONCURRENTLY (2026-07-07): #20 RATIFIED, #19 + #18-prep running

**#20 CLOSED — RATIFIED: FREE on Steam, no monetization** (fan-work
posture; one-time $100 app fee = user). #19 lane running (worktree,
disjoint surfaces: export_presets + release.yml desktop/SteamPipe-skeleton
jobs gated on repo vars + docs/steam/ capsule set at exact sizes +
screenshots + USER-ACTION CHECKLIST incl. partner account/secrets; trailer
= flagged undelivered new capability, per the brief's no-silent-scope-down
rule). #18 (controller support): input-surface investigation running;
controller plan = Fable-authored next, then its own lane. #18/#19 files
are disjoint from every 8a lane by construction.

## #8 CLOSED — THE MAGICAL DOOR SHIPPED (2026-07-07; opus FIX-FIRST→fixed→READY; rotation 5/5 + fix wave; 64/64 + public CI green)

The full chain is live: Erin's flicker → Pisces 3-path consult (one
`door_understood`) → the Albez ruin recovery run (D2's real encounters)
→ Krshia's 35g catalyst → 3 opaque study sleeps → the GDI awakening →
the portal menu + Liscor fast-travel. `data/portals.json` is the ratified
anchor-stone-per-region contract — opus traced it: #10/#12/#16 add a row
+ their own attunement beat, zero code. WIPortals is STATIC (WIBounties
class, reviewer-ratified — the binding pattern for region modules).
DF caught: 1 composed-suite blocker (missing test pin — CI was RED,
fixed, CI green), 1 rotation blocker (PC/guardian sprite fusion — a
mismeasured shared `raskghar_awakened` anchor; fixed, deep_descent boss
windowed-verified unharmed), stale-toast class fix, rune-glow gen fired
honestly (4/4 rejected — target too small for legible runes; tint+light
ships, VISUAL-LOG carries the gap + candidates).

**PLAYTEST CHECKLIST (#8, the human gate):**
1. Fresh save → full chain in one sitting (each consult path on separate
   runs): 2 silent study nights ("You sleep soundly."), GDI line ONLY on
   night 3.
2. The GDI line windowed: "[The inn has a Door. The Door has opinions.]"
   gold-on-black, one line, no clipping (the one un-machined surface).
3. Fast-travel round-trip: door menu → street arrival → street stone →
   back. Glow reads? Arrival cells clear?
4. Save between sleeps 2-3, reload, finish — no lost/double night.
5. Lose the guardian fight on purpose, reload — progress survives,
   consult path switchable, no soft-lock.
6. Economy: is 35g affordable at act-III position without grinding?
7. Load a pre-#8 save: no errors, door reads default, chain startable.

## #8 STATUS: D1-D3 MERGED (62/62), D4 IN FLIGHT

Chain beats 1-3 LIVE on main: Erin's flicker beat, Pisces 3-path consult
(one door_understood), the ruin recovery run vs D2's real rosters, the
pedestal anchor stone, Krshia's 35g catalyst. 62 canonicals.
Olesm-assist scope-down: **BLESSED by user** (flavor-only stands). D4 (portals
module + awakening + fast travel) dispatching now; DF closes #8.

## #8 IN FLIGHT (2026-07-07): plan committed, 3 lanes running

Plan: `docs/superpowers/plans/2026-07-07-magical-door-8a.md` (lane-mapped).
Running now: D1 ruin map + flicker surface (α) ∥ D2 combat data (β) ∥
A1 asset prep incl. #9 garden pre-picks (γ). Then D3 chain → D4 portals →
DF close, serialized on shared files. potential_assets RESTORED locally
(63 packs, copied from the frozen archive — no download needed).
PixelLab: key+API verified; billing is GENERATION-count (subscription), not USD — the $0.00 usd-balance read was the wrong metric (user-corrected 2026-07-07). Generation is AVAILABLE: rune-glow inpaint + #37 inn facade are runnable now (specs in docs/design/8a-asset-assembly.md). If session dies: lane branches
carry commits; merge D1-first, re-gate merged tree.

## #7 RATIFIED + CLOSED (2026-07-07 user session) — 8a UNBLOCKED

Door = Pisces recovery chain in a NEW small Albez-flavored ruin map;
attunement = ruin anchor stone + Krshia catalyst (~30-40g); no Erin
gate; **anchor-stone-per-region is the ratified expansion-scaling
idiom** (8b/8c/8e each ship an attunement beat). Garden = Erin's
milestone: act >= III AND K-of-N of {inn work, goblins_spared, sign
defended, resolved_wrong_order} (K tuned at planning; spared never
solely gates); no-violence sim guard on the garden map. Binding text:
portals-garden spec SS5. **Issues #8/#9 are unblocked** — #8 planning
can start next session.

## #21 + #23 CLOSED — SHIP (2026-07-07, Fable; parallel worktree lanes, both reviewed + fix-waved)

**#21 [Ice Floor] LIVE** — the last ghost skill wired. Enemy-targeted cast
(reuses the existing spell-target UI — the feared "new cell-targeting mode"
proved unnecessary), 3×3 glaze around the target, walls excluded, friendly
fire real (the caster can ice their own feet on an adjacent cast); persists
2 rounds via new `WICombat.terrain` state; standing on/stepping onto ice
applies the existing `slowed` status (turn-start apply lands the penalty
THAT turn). Board overlay + `terrain_added/expired` + `ui_terrain_rendered`;
AI deliberately unaware (no enemy holds it; PC autoplay never casts — harness
A/B byte-identical). Card un-suppressed: "2 AP, 4 MP — glaze a 3×3 patch of
ground at range 3 for 2 rounds. Slows." Review caught 1 Critical (terrain
visuals dropped on AI-playback skip-forward — the zero-delay desync class,
invisible to QA by construction) — fixed + unit-pinned. 57th canonical
`ice_floor_loop`; overlay + standing-slow windowed-read by controller.
2 cosmetic VISUAL-LOG items added ("shakes it off" wording on terrain
expiry; readout truncation eats the trailing "Slows.").

**#23 per-waking dialogue seam LIVE** — `once_per_waking` (requires-ONLY
after the review fix — hide_when polarity was a latent landmine, now refused
at runtime + rejected by the content validator) + `bank_first_use` effect,
riding the existing `entity_first_use` dict. Erin's stage-3 meal ("Sit, eat.
Cook's orders.") grants NEW `well_fed` (+2 max HP folded into hp_mod until
sleep; mirrors light_active's lifecycle, additive save). Relc's stage-3 spar
wager pays 1g once per waking via the shipped next-talk idiom (no new
combat→dialogue bridge). 58th canonical `stage3_perks_loop` (both perks,
gone-same-waking, back-after-sleep). Review: 0C/1I/2M — Important fixed;
Minors logged (ledger): wager pins final gold not the gold_changed event;
save test round-trips the two new fields separately, not in one save.
Lane B's implementer died to an API kill mid-fix-report — fix commit was
already landed; controller re-ran the covering gates directly (the DP5
transcript-resume precedent, resolved cheaper).

**Merged-tree re-gate: 16/16 unit suites + 58/58 ci_sweep green, zero grep
hits; windowed reads clean (both new dialogue lines render full, no fold
bleed; "Earned 1 gold." toast lands beside Relc's line).**

**TASTE QUEUE — RESOLVED (user rulings 2026-07-07 late session):**
1. `well_fed` +2-max-HP-until-sleep: **BLESSED as shipped.**
2. Erin's "+2 HP" meta-flavor line: **KEEP.**
3. Relc's wager line: **BLESSED.** The #8 Olesm-assist-as-Pisces-flavor
   scope-down: **BLESSED** (no Olesm nod needed).
4. [Ice Floor] feel: still needs actual play (rides the #8/#21 playtest).
**POST-8a DIRECTION RATIFIED: 8b Riverfarm as the main lane** (Witch
chain, village map, the FIRST anchor-stone attunement beat proving #8's
region contract) **with #26 goblins_spared + #39 sign_defended as small
parallel side-lanes** (they restore the Garden gate's 4-leg freedom AND
seed the Rags runway).

Last updated: 2026-07-07 (**UNIFIED REPO — this public repo is now THE working repo** (local: ~/wandering-inn-rpg); commits are public on push; licensed assets overlay via scripts/fetch_private_assets.sh; leak_check is CI job 1; the old private repo is a frozen archive. Full gate 56/56 green post-transition with the overlay. v0.3.0 LIVE on itch. Board state: interlude #2-#5 + honest debts #27/#28 + cleanup #36 all closed; 8a gates on issue #7 (USER SESSION); spoiler cutoff ratified (Book 17 bar / Vol 7 advertised, docs/design/spoiler-cutoff.md). External PRs: wi-handling-prs skill. User queue: #7 session, taste #32-#35, itch page spoiler line.)


## SOCIAL-2 — the 18 open copy/design flags (LINEAR stages, Phases A-D LANDED 2026-07-07)

Build narrative (Phase A/B/C/D landed detail) archived verbatim:
`the frozen-archive repo (GabrielGLevine/wandering_inn_rpg) at docs/archive/HANDOFF-archive-2026-07.md` §SOCIAL-2. Tracked as GitHub
issue #32 (the ruling-gathering session for these 18 flags).

**The 18 ⚑ flags — SHIP OPEN per the brief (defaults implemented above;
every recommendation below is the STAGED one, none re-litigated):**

*Conditions (6, feel check — all shipped as the staged `chatted_with_* ≥ N`
AND-legs, unchanged):* Erin stage 2 (`errand_decided` + 2 wakings) —
**BUILT, live now.** Erin stage 3 (`resolved_wrong_order` + 4 wakings) —
**BUILT, live now.** Relc stage 2 (`sparred_with_relc` + 2 wakings) —
**BUILT, live now.** Relc stage 3 (`cleared_the_warren` + 3 wakings,
**plus the `relc_joined_descent` warmer-variant call** — staged rec:
shipped the NEUTRAL condition, not the warmer one that locks out
solo-veto players) — **BUILT, live now** (the warmer variant stays an
open pick). Krshia stage 3 (`crate_returned` + 4 wakings) — BUILT, live
now. Olesm stage 3 (`cisterns_reported` + 3 wakings) — BUILT, live now.
Do these read as story beats or chores? All 7 NPCs' stages are now live —
this is fully observable in actual play.

*Perks (8, shape check):* Erin's daily meal — **BUILT 2026-07-07 (issue
#23)**: the per-waking seam landed; the meal grants `well_fed` (+2 max
HP until sleep — ⚑ see the #21/#23 taste queue above, the staged "HP
restore" had no field-HP target). Relc's spar refinement — **BUILT
2026-07-07 (issue #23)**: the WAGER beat shipped (stage 3, 1g once per
waking; status-quo re-offer untouched). Krshia's discount — BUILT
(prices above). Selys' board pick — BUILT as the ONE-TIME pointer variant
(staged rec: "cleanest v1"); the repeatable-board alternative is still
open if you want it instead. Pisces' proposal (drill vs. gift vs. strike)
— BUILT NOTHING per the staged instruction (no spec default); still fully
open. Olesm's chess beat — the option + frame ship; the real match/wager
is STILL a follow-up writing task, not started. Zevara's bounties —
BUILT. Lyonette's optional perk — ships PERK-LESS (staged default).

*Canon reveals (5, all shipped OBLIQUE per the staged default — none
warmed):* Krshia's necklace/spellbook plan — OBLIQUE, live now (never says
"spellbook"). Zevara's Eresc/Antinium oath topic — BUILT (Phase B),
OBLIQUE, no Eresc/Antinium named ("the dead were the kind the city didn't
mourn"). Relc's "people I left in it" — **BUILT, live now** (Phase C),
OBLIQUE per the staged default: no daughter, no Embria named (V5 canon,
hard rail) — the warmer "family thing" variant stays OFF by default, in
`relc_stages.md` if ever wanted. Erin's home topic (otherworlder-adjacent
oblique: "can't get there by walking, I did the math on walking") —
**BUILT, live now** (Phase C), kept strictly oblique per the staged
default — no Earth, no "another world" claim. Lyonette's optional home
topic (princess-adjacent) — UNBUILT, default OUT per the staged rec (ship
it only if you want it).


## M-DEPTH CLOSED — SHIP (2026-07-07 — Fable; opus READY TO SHIP, 0 fix-first)

Liscor has interiors: the Adventurer's Guild (Selys at the desk, THE
REQUEST BOARD with the full bounty lifecycle incl. abandon), the inn
upstairs (your own bed), the Watch barracks (Sgt. Ashgrave, the cell),
the Runner's Guild (Vess, the delivery loop riding the same core).
56 canonicals. Opus verified the whole-milestone seams: bounty+delivery
held simultaneously by design, the 4-map mood/save/door matrix clean,
the economy effort-gated with no runaway loop, Selys's 6-option worst
case still navigable. Rotation findings all friction-tier (VISUAL-LOG +
GH issues).

**PLAYTEST CHECKLIST (M-DEPTH):**
1. Walk the guild cold: does the board read as THE thing to check?
2. Take a bounty, sleep, come back — does delta-since-accept feel fair?
3. Accept a delivery, dawdle past the deadline — does the sleep-fail
   read as honest (the slip warned you) or as a gotcha?
4. Vess + Dresk first impressions (new NPCs, new voices).
5. Your own bed: worth the stairs? (Flavor-only by design.)
6. The picker: does paginating through postings feel okay, or does the
   header-question hoist (opus's optional polish) feel needed?

## PLANNING TRANSITION (2026-07-07, user directive) — GITHUB IS THE PLAN

Milestones (10, the chain rungs) + labels live on
github.com/GabrielGLevine/wandering-inn-rpg; a 35-issue set (each body =
a dispatch-grade brief) is being authored now. ROADMAP.md is a pointer +
history; skills route positioning/dispatch through `gh issue view`.
⚑ ONE USER ACTION: `gh auth refresh -s project,read:project` (browser
flow) to enable the Projects board — Issues/Milestones work without it.

## SOCIAL PILLAR II CLOSED — SHIP (2026-07-07 night — Fable; opus READY TO SHIP, 0 blockers)

LINEAR relationship stages on ALL 7 pooled NPCs (Erin + Relc finally in —
21 scripts / 29 insertion points re-pathed, zero parks), stage-gated hub
topics, visible-currency perks (Krshia discount, Zevara bounty pointer,
Selys board pick), the one sanctioned {gold, accomplishment} compound
gate. 51 canonicals. 18 ⚑ copy flags OPEN (per-flag recommendations in
the SOCIAL-2 section below) + two review notes: the CHESS
unfulfilled-promise thread (Olesm/Erin pitch a match that isn't playable
yet — the follow-up writing task should land before players dig that
deep) and Krshia's discount going mechanically live before the diegetic
grant line (tighten to heard_krshia_plans if you prefer diegetic-first).
Erin's daily-meal perk + Relc's spar wager honestly UNBUILT (need a
per-waking dialogue seam — queued).

**PLAYTEST CHECKLIST (Social II):**
1. Talk to Krshia across 4+ wakings — does the relationship DEEPENING read
   through the pool lines alone (milestone, not meter)?
2. Earn the discount — does "friend's price" feel earned? (And: should the
   discount wait for her to SAY it first? — the coupling note above.)
3. Erin + Relc first-talks — do the barks land in-voice at the panel's
   truncation length?
4. Chase Olesm's chess pitch to the dead-end — how bad is the tease?
5. Any stage jump feel unearned/abrupt (LINEAR pacing check)?

## SKILLS WAVE CLOSED — SHIP (2026-07-07 night — Fable; opus READY TO SHIP)

K1 traversal seams, K2 sneak state, K2b slotted loadout (your ratified
model), K3 canon names + the [Rogue] class, K4 ghost-skill wiring (3/4 —
icy_floor + [Mage] [Invisibility] queued honestly with cites). 50
canonicals via qa/manifest.json. The first BINDING machine-playtest
rotation caught a systemic panel z-order class all sweeps missed — fixed
(toasts above modals at layer 12; echo reserved-height; barks clear on
dialogue/combat/map).

**PLAYTEST CHECKLIST (Skills wave):**
1. Sneak past the ambush, break it by poking something — does the
   translucency + soften/straighten toast pair read?
2. Earn [Rogue] via the crate WATCH path — does the earn feel connected
   to the guile act? Is [Stealth]'s 1 AP combat use worth a slot?
3. Loadout: assign/unassign in the journal — does the hint line teach it?
   AUTO mode's blank markers vs the hint (known UX nit) — annoying?
4. The renames: [Snap Freeze], [Firefly], [Appraise Foe] — do they read
   as Skills a resident would name? ([Owl's Vision] was checked and
   rejected: canon says it's night-vision, not a person-read — your
   exemplar principle applied, different answer.)
5. [Second Wind] mid-fight — does a self-heal verb change your turns?
6. The sign out front + Relc's roof/road line (⚑ trimmed to fit — read
   vs the seed copy) + Erin's "Sign stays up." variant.

## RESOLVED 2026-07-07 (user rulings — night run: apply, don't re-flag)

1. **Capacity-refusal copy:** staging §C candidate 4 — "It buzzes once
   against the others, like a wasp against glass, and will not settle."
   (canon-truest: Dissonance's warning sign is vibration). Swap the
   `_CAPACITY_REFUSAL_TOAST` const + re-pin gear_loop/test_sim_core's exact
   quotes. Slot-full line keeps G1's plain-practical placeholder unless a
   better one falls out naturally.
2. **Interference diction:** hum/static stays as house flavor in lore +
   Krshia's stock line; the refusal moment itself is the vibration line.
3. **Sneak toasts:** keep "You soften your step." / "You straighten up."
4. **[Stealth] class home — USER RULING, supersedes the Tactician rec:**
   stealth belongs to a **[Rogue]-line class** (earned, canon-checked name —
   wiki-verify [Rogue] itself; guile/stealth accomplishment counters per the
   action-driven model), NOT Tactician. A **[Mage] may separately get
   [Invisibility] as a spell** — treat as a K3-optional second stealth verb
   (wiki-verify; if it needs new sim machinery beyond a status/visual, queue
   it rather than force it).
5. **K3 canon Skill names:** Fable researches and decides (wiki-cited).
6. **Krshia's 4th "Hrr.":** keep — distinctive trait, user not fussed.
7. **Phosphor pendant 0.3 loot rate:** approved.
8. **Moon-bone trophy (unwearable tease):** approved.
9. **[Observe] rename:** yes — action-verb names read as generic actions,
   not Skills. Rename to a canon-verified Skill-sounding name ([Owl's
   Vision] is the user's exemplar — VERIFY it's attested canon before using;
   otherwise the closest attested perception Skill). **GENERAL K3 PRINCIPLE
   (user):** never confuse a Skill name with a plain action — canon checks
   exist for exactly this; prefer Skill-sounding canon names across the
   whole naming pass (audit basic_cleaning/basic_cooking/observe-class names
   against this bar, flag any that should follow).
10. **M-ARC climax copy: APPROVED** (flag closed). But the **GDI epilogue
    (7 lines) feels cheesy** — rewrite queued (Fable-drafted copy staged at
    docs/design/gdi-copy-staging.md; night run applies + re-pins arc_flow's
    lines:7 count if it changes).
11. **GDI opener: de-race-ify.** One strong opener for all races — drop the
    Human/Drake/Gnoll branches; lean the "Class: none. Skills: none." system-
    readout vibe. Fable-drafted copy staged (same staging doc); apply + update
    char_creation's opener pins (payload race key may stay, copy converges).
12. itch AI-disclosure toggle: checked by user; they revisit settings before
    un-drafting. No agent action.
13. Dialogue naming calls (Sable/Coyle/witch): re-flag WITH recommendations
    when M-DEPTH content is reached.

## M-GEAR execution log (2026-07-06/07 — Fable)

- **G1** d813970: resonance capacity (default 2) + three accessory slots, pure
  sim; two diegetic refusals (slot-full vs over-capacity — copy is placeholder,
  ⚑ pick final lines from docs/design/gear-staging/ §C, canon note: Dissonance's
  warning sign is artifacts SHAKING, a vibration line would be most canon-true);
  review loop caught + fixed a dup-accessory double-count before any accessory
  existed to exploit it.
- **G2** (next commit): all 19 items carry lore (canon-checked: Magical
  Dissonance BY NAME, Council, ruins, Silverfang trade, Celum, Raskghar
  lucidity); 7 new accessories + 2 tools; Krshia's stall split with a 6-buy
  "charms" node (her stock line carries the Dissonance warning diegetically);
  moon-bone amulet = resonance-3 TROPHY from the seal beat, unwearable until
  capacity grows (deliberate tease, ⚑ confirm you like it); watch_token rides
  the cisterns TALK resolution; phosphor_pendant loots off shield_spiders.
- **G3** 9a28baf: inventory UI — accessory rows, lore on cards, "Resonance N/M"
  header, refusal echoed in-panel (the toast hides behind the open panel);
  fixed two PRE-EXISTING bugs the trace exposed (accessory equip-toggle never
  worked; double-toast risk); 48th canonical `gear_loop`.
- **G4** 298b868: 5 measured harness cells (max-legal kit, solo-tutorial twin
  0.61 — theoretical ceiling, shop unreachable pre-tutorial; dr-2 stack; hp+5
  stack; moon-bone labeled capacity-unreachable). E6 baselines byte-identical.
- **GF: M-GEAR CLOSED — READY TO SHIP** (opus whole-branch: 0 Critical /
  0 Important / 2 Minor, both fixed at close — stale refusal echo now clears
  on cursor move; doc count). Save-compat matrix, dialogue gating, OPACITY,
  and every cross-task seam verified clean. Public synced 20e5545. Your open
  gates: refusal copy pick (§C of the gear staging doc; canon-truest =
  vibration/shaking), phosphor_pendant's 0.3 loot rate, moon-bone trophy
  confirm. Playtest checklist below.

*(Note: the "your open gates" line above pre-dates the RESOLVED-2026-07-07
block — items 1/7/8 above resolved refusal copy, phosphor rate, and
moon-bone respectively. Kept verbatim: GitHub issue #35 cites this G1
entry directly for the still-open slot-full-line pick.)*

**PLAYTEST CHECKLIST (M-GEAR — run after GF closes):**
1. Does resonance read as a MAGIC rule (Dissonance) or a videogame budget?
2. Buy the wax-sealed ward with the charm equipped, then try the fang —
   does the refusal moment land? (Copy is placeholder — pick finals from
   docs/design/gear-staging/ §C; canon-truest option = a vibration/shaking
   line.)
3. Lore pass: any keeper? any groaner? (19 lines, all in the inventory cards.)
4. The moon-bone amulet trophy (seal beat): does "can't wear it YET" read as
   a tease or a bug?
5. Krshia's charms counter: does the stall split feel natural? Her stock
   line carries the Dissonance warning — too on-the-nose?

**⚠ GHOST SKILLS (L5 finding, needs your awareness):** `second_wind`,
`icy_floor`, `quick_movement`, `battlefield_awareness` have NO sim
implementation — casting [Second Wind] spends 2 AP and does nothing; the
move-cell passives never apply. All four are reachable (Warrior L3/L4,
ice_mage L10, Tactician L1). The LF fix wave suppresses their generated
effect lines (cards read as flavor until wired — no false promises); REAL
wiring is queued as a Skills-wave task (needs the balance harness + seed
re-checks since a move-pool passive changes autoplay pathing). If you'd
rather de-grant them until wired, say so — that's a class-data churn call.

*(Note: K4 has since wired 3 of these 4 — `second_wind`/`quick_movement`/
`battlefield_awareness` are live per the SKILLS WAVE CLOSED section above;
`icy_floor` remains the one honestly-skipped ghost skill, tracked as
GitHub issue #21, which cites this exact section.)*

**PLAYTEST CHECKLIST (M-LEGIBILITY — run after LF closes):**
1. Pick between two armors WITHOUT opening a wiki — could you?
2. Did any surface feel like a spreadsheet? (The bar: mechanics visible, soul intact.)
3. Did any Skill's effect surprise you after reading its card?
4. **Field readout panel (bottom-left, always-on, one row per field skill): keep,
   or too much permanent screen furniture?** (New L3 surface, taste call.)
5. Krshia post-thinning: does she still sound like Krshia with 3 Hrr instead of 11?

## THREE PILLARS CLOSED — SHIP (2026-07-05 — Fable; opus 0C/0I/1M)

P1-P5 + PF visual wave, range 85394de..7b61863; 32-script suite
(`field_skills_loop` new canonical). Field skills are first-class verbs
(number-key hotbar, interact-parity proven byte-equal), [Tactician]
earned via the cellar seam, [Observe] on 13 entities, service L10
grants filled, exploration pillar re-audited thin→rich. Review report:
`.superpowers/sdd/fp-handoff/tp-final-review.md`.
- Minor logged: [Observe] banks observed_things EVERY press (no
  per-entity dedup) — degenerate but reward-empty (tactician L2-12
  grant nothing); fix = first-observe-per-entity when next touched.
- Ship-with-note: old studied_the_cellar saves gain [Tactician] at next
  sleep (mage-seam mechanism, benign).
- Watch: field bar at 8/9 slots for a maxed multiclass.
- P5 flag for a future milestone: **Social is now the thinnest
  repeatable pillar** (dialogue banks are one-shot).
**PLAYTEST CHECKLIST (Three Pillars):**
1. Does the overworld hotbar feel like combat's (grammar transfer)?
2. Is [Observe] delightful or noise? (13 canon-voiced strings; press it
   on Relc, Erin, the dummies, the sewer grate.)
3. Does [Tactician]'s arrival read EARNED (study the cellar → sleep)?
4. [Observe]'s name: keep vs [Owl's Vision] (canon call, queue item 5) —
   **note: already resolved** per RESOLVED-2026-07-07 item 9 (renamed).
5. Pillar-balance gut check: fight less, clean/observe/talk more — does
   non-combat play feel first-class?

*(Kept-unsure — items 1/2/3/5 above have no explicit later playtest
verdict on record; carried forward rather than archived. Controller:
confirm whether subsequent milestones' continued play implicitly
answers these before re-running the checklist.)*

## ONBOARDING REV CLOSED — SHIP (2026-07-05 — Fable; opus 0C/0I/3M)

Final review verdict SHIP (`.superpowers/sdd/fp-handoff/of-final-review.md`).
Trigger×defeat×reload composed-defect hunt came back safe-by-construction.
Minors (no fix needed to ship): pre-O3 dev saves re-show the gift node once
(dedup'd, cosmetic); a classless player who skips Relc can defeat-loop the
mandatory ambush (spec-accepted "death-teaches" — WATCH in the newcomer
playtest, escape = meet Relc).

## ONBOARDING REV O1-O5 SHIPPED (2026-07-05 — Fable); OF gate in flight

Classless start / Relc arms+teaches / proximity ambush tutorial part 2 /
Pisces teaches magic / grants-listing class toasts. 31/31 canonical
sweep green (new `tutorial_flow` is the arc's own proof); opus
whole-branch review running. **PLAYTEST CHECKLIST (the cold-start test —
ideally hand it to someone who's never seen it):**
1. Does the classless open read as "I am nobody yet" rather than broken?
   (3-slot hotbar, no skills in journal.)
2. Relc's spar → sleep → "[Warrior] class gained! — [Basic Swordwork]…"
   toast: does the grant list land as a reward moment?
3. The gift beat: does "press I… the weapon you carry decides which of
   your moves come with you" actually teach equipping? Did you equip the
   spear without being stuck?
4. Walking the gate road: does the ambush firing WITHOUT a button press
   feel like an event, not a bug? Do the part-2 tutor beats read?
5. Pisces at the Guild frontage: haughty-but-brilliant? Does [Mage]
   arriving at sleep after his lesson feel earned?
6. Night street + campfires (OF read: gorgeous) — readability check in
   combat at night still open from M-BEAUTY.

*(Kept-unsure — same as Three Pillars above: no explicit later playtest
verdict on record for this checklist; carried forward rather than
archived.)*

## M-RELEASE OPENED CONCURRENTLY (2026-07-05 — Fable) + USER QUEUE

Spec ratified (8 decisions: MIT; browser-local saves; private-bundle+
fallback art w/ fresh-history re-init; DCO + CC-BY/MIT asset license-in;
label-gated drafts-only Opus triage; itch+GitHub; user-only merges,
tag-driven deploys; parley gate KEEP) — `docs/superpowers/specs/
2026-07-05-release-community-design.md` + plan `docs/superpowers/plans/
2026-07-05-release-community.md`. Asset audit DONE:
`.superpowers/sdd/fp-handoff/release-asset-audit.md`. KEY CORRECTION:
sprite registry has NO missing-sheet fallback (hard-asserts) — R2
rescoped to BUILD it. FORBIDDEN-at-public-bar: Pixel Crawler backbone,
xDeviruchi music, Minifantasy SFX. R1 (ci.yml) + R5 (forms/triage) built
as parallel lanes; R4 docs (LICENSE/README/CONTRIBUTING×2/COC/
ATTRIBUTION) authored by Fable. R2 gated on O5-landing; R6 (public push)
gated on user.

**R6 UPDATE (2026-07-06 00:50): REPO LIVE + CI FULLY GREEN.**
github.com/GabrielGLevine/wandering-inn-rpg (PRIVATE) — pushed by Fable
under explicit user authority; CI run 3: smoke + 13 units + 32-script
sweep + web parity ALL SUCCESS on a cold runner with fallback art. Two
real defects caught by run 1 and fixed same-session (fallback frame
counts; latent PF icon unit red). Remaining user UI config: Actions
secrets (ANTHROPIC_API_KEY, BUTLER_API_KEY, PRIVATE_ASSETS_TOKEN), itch
project + butler key, v* tag-protection ruleset, flip-to-public call.
Sync procedure: copy changed files into ../wandering-inn-rpg-public,
commit, push (export script is init-only now).


*(R6 push-day state — repo-created/secrets/tag-protection instructions — archived: superseded, the repo has been live+public since. `the frozen-archive repo (GabrielGLevine/wandering_inn_rpg) at docs/archive/HANDOFF-archive-2026-07.md` §R6-STATE.)*


**USER QUEUE (M-RELEASE additions):**
1. Re-attest at PUBLIC-REPO bar (shipping ≠ redistributing sources), per
   audit report §2: goblin-pack family, Bat_Fur, topdown_floor_tiles_12,
   Tiny Swords (no terms files); Admurin's Freebies (no-standalone-
   redistribution clause); PixelLab Relc output (ToS unverified).
2. pirateaba fan-works policy check before any public push (docs frame
   the project non-commercial fan work throughout).
3. R3/R6 user actions when reached: private assets repo, itch project +
   API key, repo secrets, tag protection, DCO app.
4. ASSETS — RESOLVED 2026-07-05 (user review of the research): Pixel
   Crawler themed packs were ALREADY OWNED and are in potential_assets/
   (Castle/Cave/Cemetery/Desert/Fairy Forest + more) — the "$20 buy" rec
   is moot; prop sourcing (sewer grate, cauldron, open chest, dummy) can
   proceed from in-hand packs. User also added: Cute_Fantasy_Free,
   Pixel_16_interiors_v2_free, Ninja Adventure full zip; catalog pass
   DONE 2026-07-05. ⚠️ CATALOG FLAG: **Cute_Fantasy_Free's license is
   NON-COMMERCIAL free-tier** — contradicts the blanket attestation; do
   not use its art without explicit sign-off (or buy the paid tier).
   Ninja Adventure full = CC0, incl. Shaman/Sorcerer NPCs (Pisces
   stand-in upgrade candidates). **PixelLab API key at docs/pixellab_api_key.txt
   (gitignored)** — unlocks Antinium + top-down Drake walk generation
   (ToS: outputs user-owned + redistributable). REMAINING open buy:
   Elthen lizardfolk/gnoll/mage ~$3-5 each (canon species battlers +
   native Cast frames) — still user's call. CC0 audio on disk (Junkala +
   Kenney trio).
5. [Observe] NAME CALL (P3 canon escalation): [Observe] is NOT a
   canonical bracketed Skill (wiki-verified; TWI has no generic inspect
   skill by design). Shipped under the spec-approved name; recommended
   canon rename [Owl's Vision] — localized data change if you want it.
   ([Battlefield Awareness] verified canon via Olesm.) **Note: [Observe]
   was RENAMED** per RESOLVED-2026-07-07 item 9 — this queue line is
   historical.
6. Tactician save-compat (PF adjudication, lean ship-with-note): old
   saves with studied_the_cellar=1 gain [Tactician] at next sleep with
   zero new action — benign toast+autosave, M7's ship-with-note precedent.
ANTINIUM SPRITES RATIFIED (user 2026-07-06): s21 = Worker, s33 =
Soldier (potential_assets/pixellab_2026-07-06/antinium_worker/).
Integrate when an Antinium character lands — Klbkch is the natural
first (Worker-origin Senior Guardsman, canonical [Diplomat] anchor).
DIALOGUE-DRAFT TASTE CALLS (Fable drafts 2026-07-06, report
task-dialogue-drafts-report.md): (a) Brothers lieutenant naming —
original "Mister Sable" vs canon Gnoll Wilovan (profile said human;
drafts lay out 3 options); (b) Invrisil expose-vs-extort endings both
drafted — pick or keep the fork; (c) the witch stays UNNAMED
(recommended — don't spend Eloise); (d) climax copy draft ⚑ still
awaiting your pass (specs/2026-07-06-m-arc-climax-copy-draft.md).
Standing queue: charm-as-armor lore; [Helper] canon name; M-BEAUTY +
held-move + night-combat-readability playtest.

## Commands

```sh
# Play (human)
/usr/local/bin/godot --path wandering_inn_game

# Agent verification (primary)
wandering_inn_game/qa/run_qa.sh <script> headless --seed=<N>   # seed table in v4 CLAUDE.md
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
- Subagent lane: Codex sandbox cannot write `.git` or open windows — Codex implements + verifies headless, controller verifies on real env and commits. zsh does NOT word-split unquoted vars — pass QA-script args explicitly. macOS has no `timeout` command.
- **Godot 4.7 rarely SIGABRTs at process shutdown** (macOS crash-report notifications; ~3 occurrences across hundreds of headless runs 2026-07-01→02, incl. one overnight pre-M4). Results/exit codes unaffected so far; user notified, cosmetic. If phantom QA FAILs ever appear with clean QA_RESULT lines, suspect this first (crash-at-exit → exit 134).

*(Older closed-milestone narrative — M0 through M6.5, M-FP, Onboarding O1-O5
build logs, M-BEAUTY, M7 weapons, and playtest triage predating 2026-07-05 —
archived verbatim: `the frozen-archive repo (GabrielGLevine/wandering_inn_rpg) at docs/archive/HANDOFF-archive-2026-07.md`.)*
