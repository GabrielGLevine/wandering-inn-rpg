# Wandering Inn RPG Handoff

## 🛡️ USAGE GUARD LIVE (2026-07-12)
`scripts/usage_status.sh` = tier check (OK/CAUTION/WINDDOWN/QUIESCE, exit
0/10/20/30); PostToolUse hook injects tier CHANGES mid-flight; protocol in
wi-usage-guard skill. Check before every dispatch. QUIESCE = commit WIP
seams + HANDOFF update + wait-for-reset (session) or hard stop (weekly).

## 🔀 lane-19 landed (2026-07-12) — #19 was ALREADY DONE 07-07; this pass closed the real gaps

**Controller note for merge**: before building anything, this lane discovered
issue #19's substance already shipped 2026-07-07 (`7ab18c1`/`27676fe`, "M-STEAM
lane #18/#19" — export presets, `release.yml`'s `desktop-exports` +
`steampipe-upload` skeleton, `docs/steam/` capsules+screenshots) and is an
ancestor of `main`. **The GH issue was just never closed** — recommend
`gh issue close 19` with a pointer to `7ab18c1`/`27676fe` plus this commit.
Re-verified rather than re-built: macOS export (`export_presets.cfg`'s
`macos` preset) smoke-tested clean locally (templates were installed) —
exported `.app` boots `--headless --quit` with zero SCRIPT ERROR/Parse
Error/WARNING; import + `load_gate` + `combat_walkthrough` (seed 9) all
clean before and after this lane's edits.
**Two real gaps closed**: (1) `docs/SECRETS-SETUP.md` had NO Steam section
at all (the 07-07 lane put everything in `docs/steam/CHECKLIST.md` only) —
added the summary + pointer, matching the existing `BUTLER_API_KEY` entry's
style. (2) The capsule/screenshot set was 5 days stale — captured BEFORE
Riverfarm (`e1446cb`, 07-08), the Garden (`f37804a`, 07-07 later same day),
and the whole 8d dungeon/vault-boss arc (07-12, today) existed. Refreshed
both sets from real-overlay windowed QA runs against current content: inn
hearth, Riverfarm village, a `riverfarm_fight` combat moment, the Garden of
Sanctuary, and an Erin dialogue beat (`docs/steam/screenshots/`,
`docs/steam/capsules/` regenerated via `make_capsules.py`). **Disclosed, not
papered over**: tried the brief's suggested dungeon-fight-with-windup-overlay
shot (`delve_fight`'s vault boss) — the `trapped_halls`/vault interior reads
near-black, the SAME dark-legibility finding already on the 8d user-playtest
checklist below — substituted Garden + Riverfarm combat instead; swap it back
in once that lighting pass lands. USER-SESSION items unchanged from before:
Steam build-account secrets (`docs/SECRETS-SETUP.md`/`docs/steam/CHECKLIST.md`
§5), the capsule/screenshot picks, the trailer decision (§8, scoped-not-built,
unchanged this pass).

## 🌊 WAVE 3 SHIPPED (2026-07-12, pushed 0d1a010, CI GREEN) — closed #64 #65 #73 #77 #82

Five lanes, every one opus-reviewed (two FIX-FIRST cycles adjudicated + re-reviewed), composed gates: import + ALL 21 units + harness (73 cells) + full 87-script sweep, zero grep hits.
- **#65 witch-stone**: Invrisil attunement = Eloise's 18g stone post-blight_lifted (letter stays as signpost); Invrisil fixtures re-based onto the reachable chain + 3 new coherence-validator arms.
- **#73 scene-dynamism tool**: calibration contract PASS; singleton-group credit disclosed; folded into wi-adding-a-scene (score step 4 of every map edit); ruin_surface flagged under-dressed (VISUAL-LOG).
- **#77 settings+accessibility**: audio buses (UI→SFX routing bug fixed, provable headless), fullscreen, text-scale (budget-safe), reduce-motion (covers the #75 lunge/projectile family), controls reference, hint replay, settings.cfg. settings_loop = 87th canonical.
- **#64 skill-gates**: 6 persuades re-gated to [Charming Smile]/[Calming Touch]/[Appraise Foe] (acquisition bar proven identical), 3 principled survivors, anti-auto-win adjudicated all-honest; {accomplishment,skill} = 5th sanctioned compound; skill-library doctrine sections written.
- **#82 windup + 8d C3**: the telegraph mechanism (declare → frozen cells → next-turn-start resolution; [Dangersense] overlay — grant confirmed player-reachable at Warrior L5), vault arena + construct GATED 0.86/6r (max 9), 72/73 harness cells byte-identical to pre-wave main. CHOICES 15: caster excluded from own windup. Vault encounter DORMANT pending C1.

## 🌊 8d MILESTONE SHIPPED (2026-07-12, pushed 1e51bf8, CI GREEN) — closed #14 #15 #83

Full arc live: dungeon maps + traps → Horns recruit → three-cost halls routes → windup-telegraph vault boss → FIND beat → report → inn residence. E2 whole-branch review SHIP; machine playtest read by controller eyes (Yvlon/bench fix, dark-edge + overlay findings actioned); AI-variety profiles landed with the snare ward-id split. User playtest checklist + CHOICES 18-20 below.

## 🏗️ THE ARCHITECTURE WAVE SHIPPED (2026-07-12) — closed #99 #100 #101 #107

Four parallel lanes, each opus-reviewed (MERGE) with fix waves: **#99** shipped-ids freeze (460 ids frozen at 0.5.1 across 5 classes; deprecate-and-map via WISave.DEPRECATED_IDS with HONEST coverage — a mapped class without a real remap arm fails loud; the class remap now rewrites all four carriers; wi-shipping deploy step 0 = regenerate at every release). **#100** skeleton split (data/maps/<region>/<map>.json × 21 + WISceneCatalog composer + data/scene_root.json; deep-equal proven; sweep byte-green before/after; the reviewer ran a REAL web export proving pck enumeration — the one surface editor-mode sweeps can't see; region dirs = permanent content-lane parallelism). **#101** QA tiering (13-script smoke tier ~22s; `--tier`/`--touching` on ci_sweep.sh; surfaces auto-derived + drift-FATAL; always-on sweep-smoke CI job — would have caught this week's manifest incident by construction; harness sharding via WI_CELL_RANGE + harness_shard_diff.sh; CAVEAT: `--touching` is content-paths-only, src/** changes fall through to zero scripts — use --tier smoke minimum). **#107** Help pane (six sections via the Controls idiom, locks-clean, voice-passed; settings_loop pins updated with proof only it indexes those rows). **Two cross-lane seams caught at composition, neither by per-lane review**: 101's surfaces generator and 99's maps census both read the monolith 100 deleted — fixed by repointing to the composed catalog (shipped_ids.json byte-identical across the repoint). Lesson recorded: the reconciliation rehearsal must cover EVERY lane pair sharing a data source, not just pairs flagged at dispatch.

## 🍎 macOS EXPORT DELIVERED (2026-07-12, the architecture-wave build)

WanderingInnRPG-archwave-macos.zip cut off c1a198b, boot-smoked, delivered. Codesign = Built-in ad-hoc (user directive: no Apple Developer ID — preset `codesign/codesign=1` was already set; recipient right-clicks → Open on first launch to pass Gatekeeper).

## 🚨 GITHUB ACTIONS BILLING DEAD (2026-07-12) — USER ACTION

The wave push (c1a198b) went ALL-RED with zero steps run: "The job was not started because recent account payments have failed or your spending limit needs to be increased." EVERY push shows red CI until Billing & plans is fixed — including the new always-on smoke job, so push CI protects nothing right now. The wave itself is verified by the full local composed gate (22/22 units, 91-cell harness, 103-script sweep with the new drift gates, web parity, windowed reads) — main is healthy; the red is billing, not code.

## 🚢 v0.5.1 LIVE ON ITCH (2026-07-12, local butler; build #1791931, version 0.5.1)

Carries everything since v0.5.0: the full class-foundation wave (trio ladders, [Flame Dart], consolidation retune, [Innkeeper]/[Ranger], the [Trader]⇒[Merchant] line + sell + [Bargain], the Rogue trap kit with the disarm swap applied), #106 mobile web v1, the #105 web-runner rework, and the ported portal map-existence guard. Release gate: CI `[ci-full]` FULL GREEN twice (4a595bd, 75b6c63 — sweep + web-parity jobs genuinely ran), fresh export re-verified live (web combat_walkthrough + audio smoke on the exact shipped build; rotate overlay + virtual-keyboard flag confirmed in the html). Butler diff: 1.1 MiB patch. **USER ACTIONS NOW: (1) tick the itch dashboard's "mobile friendly" flag — the live build earns it as of this push; (2) hard-refresh and run the itch-audio checks from the adjudication section (mute toggle / console) on 0.5.1.** itch release notes: the v0.5.0 notes block below still covers the page copy; add one line for mobile: "Playable on phones in landscape — tap to move, tap to aim, tap to strike."

## 📱 #106 MOBILE WEB v1 SHIPPED (2026-07-12, merged 14bb9de) — closed #106

Combat is no longer touch-blind: tap-a-cell moves (adjacent = the arrow press, byte-identical; diagonal/far/pool-empty = honest no-ops), tap-a-candidate re-aims, a top-right Confirm chip = Enter, tap-elsewhere = Esc — all verbatim extractions of the keyboard branches (parity is structural, not parallel code). Name step: tappable Begin + `html/experimental_virtual_keyboard=true` (engine-key verified real). Rotate overlay: pure CSS in head_include, zero JS, clears on rotation. Hit targets widened (pause 24→36, settings 22→30, dialogue options 30px floor; input region only, copy-fit untouched; hotbar already best-of-set). QA: `combat_touch_input` canonical (103rd script; two-candidate re-aim proof pinned on dummy_b), Begin-click leg in `char_creation`, web runner green in default AND `--touch` modes, name-step/settings screenshots added permanently. Opus review MERGE + fix wave; composed gate on the merged tree: 21/21 units, 91-cell harness, 103-script sweep, 4 web combos, windowed reads (chip/Begin/settings/dialogue) all clean. **USER ACTION: v0.5.1 is live — tick the "mobile friendly" flag on the itch dashboard** (deliberately last — the flag advertises what the deployed build can do). Known honest limit: the click_* DSL drives engine `push_input`; real per-step browser-touch DSL remains future work (the `--touch` smoke proves genuine touch reaches the canvas).

## 🩹 INCIDENT: 93af9cd was a PARTIAL COMMIT — repaired 65a6d17 (2026-07-12)

93af9cd's message described the full class-wave reconciliation but the commit contained only the two staged-doc deletions — the six real files (skeleton disarm_trap swap, trap_canonical re-pin, near_sewers_trap fixture, manifest repair, CLAUDE.md row, project.godot) sat UNSTAGED. The composed gate had run green against the working tree, so the evidence was real but attached to a tree state that never landed; main carried an INVALID qa/manifest.json for the interim. Push CI could not catch it: the sweep + web-parity jobs are `[ci-full]` opt-in on push (units/smoke don't parse the manifest) — "CI: success" on a push is NOT sweep evidence. Found because lane-106 independently tripped over the broken manifest at its branch point. Repair: 65a6d17 lands the six files verbatim. **Two disciplines adopted**: (1) after every landing commit, `git status` must show zero tracked modifications before push; (2) any push whose only sweep evidence is local gets `[ci-full]` in the head-commit message.

## 🌊 THE CLASS-FOUNDATION WAVE SHIPPED (2026-07-12, pushed 93af9cd; completed 65a6d17 — see incident above) — closed #93 #95 #98

The user's foundational directive executed as one design pass: full ladders for the stagnant trio (no class dead-ends before its evolution point), Sharpshooter's grants, [Flame Dart] ([Fire Mage] reachable at waking 31 — was NEVER — cast-parity with ice proven 45/45 vs 46/46), the consolidation retune + coupled T3 reference rework (warrior 10 + gear; three cells in-band with ZERO combatant retuning; the race inverted: evolution 20 vs offer 39), [Innkeeper] + [Ranger], the [Trader]⇒[Merchant] line on the generalized sell mechanism with display==charge [Bargain] + opt-in haggling (CHOICES 27/28), the Rogue trap kit + six placements. 9+1 bisectable commits (cfA) + cfB, 4-dimension review + reconciliation rehearsal (which resolved the vendor double-insertion + supplied the exact 2-conflict merge recipe), all four new ladders reachability-proven. The reconciliation's line-union manifest damage was caught and repaired pre-gate (lesson: JSON conflicts get OBJECT-level resolution, never line union). Fresh macOS build cut off this tree + delivered (the friend-playtest refresh). NEXT per schedule: #106 mobile v1.

## 🔊 ITCH AUDIO REPORT ADJUDICATED (2026-07-12)

User reported total silence on the itch build. Verdict after a full trace: THE SHIPPED BUILD IS HEALTHY — the local repro was a runner artifact (Playwright route interception starves AudioWorklet fetches in EVERY version; #105 filed to fix the runner + add a real-server audio smoke). Against a real server the v0.5.0 build initializes audio cleanly and the PCK carries all files. User-side checks handed over: the itch embed's own mute toggle (persists per user), a hard refresh (butler in-place updates vs cached index.js), then browser-console errors if still silent. Web QA asserts audio EVENTS only — audible output currently untested by automation (disclosed).

## 🚢 v0.5.0 SHIPPED TO ITCH (2026-07-12, local butler path)

Pushed at the planned seam (post lanes 96+80, pre class-foundation/architecture). The composed release gate: ALL 21 units + the 80-cell harness + the full 100-script sweep, CI green on 43a0132. Leak check clean; bundle-v6 = the Latest badge.

**RELEASE NOTES (itch summary — copy below is page-ready):**
- TWO NEW REGIONS: the Liscor dungeon reopens — delve the trapped halls with the Horns of Hammerad and face what guards the second door. And Pallass, the machine city: two tiers, posted prices, permits, and a certain Magus who measures everything.
- The world reacts: day and night change what people say, a few regulars go home after dark, night roads carry real danger, and news of your deeds travels.
- Combat: bosses now telegraph their heaviest blows ([Dangersense] pays off), enemies fight smarter (skirmishers, guards, cowards), damage numbers + aim previews + status pips.
- Systems: three save slots with a proper defeat flow, full settings (audio buses, text scale, reduce-motion, controls reference), journal history + lore collection, mouse support everywhere.
- Classes: [Archer] joins with a full bow kit; skill-gated dialogue ([Charming Smile], not '(Diplomat)'); Helper's Generalist path unstuck.
- Sound: skill SFX, stingers, a vault boss theme, and music that ducks under conversation.
- Plus: the request/delivery boards doubled, discovery rewards, two new optional quests, a lore-note thread, and dozens of fixes from live playtests.

**Known-for-next**: the class-foundation wave (#93+#95+#98 — the consolidation race is diagnosed and pinned), then the full-game architecture track (#99-#101).

## 🚢 RELEASE POINT SET (user, 2026-07-12): v0.5.0 to itch

CUT AFTER lane-96 (evolution audit) + lane-80 (reactivity) land — BEFORE
#93 class churn + the #99-#101 architecture track. Local butler path
(NO release tag — Actions freeze until ~2026-07-31); bundle-v6 already
current. Contents since v0.4.0: 8d dungeon+Horns arc, 8e Pallass,
settings/accessibility, save slots + defeat interstitial, journal
history/lore, mouse everywhere, audio v1, AI variety, skill-gate rework,
crab/mini-quests/lore thread, + the two landing lanes. Controller runs
wi-shipping at the seam.

## 🔄 THE NEXT QUEUE (2026-07-12, post-8e) — user directives + gap-round-2

**Shipped since 8e:** the six-item debt sweep (pushed 1b1eddd, CI green — board_rumors copy-fit corpus, {item:id} validation, serving_tray's unbounded +1g farm daily-gated with a QA tooth, drake lines proven live via pallass_race_peek, pallass MAP_REQUIRES coherence arms, duck-depth reset).
**USER DIRECTIVES FILED (5, all on the board):** #95 [Rogue] trap kit + game-wide trap placements; #96 evolution reachability audit (your Ice/Fire-Mage-never-triggered report — LANE RUNNING); #97 bestiary expansion for the posting machine; #98 [Trader]⇒[Merchant] economy line; #93 amended+elevated with your class-foundation framing (more consolidations, the stagnant Diplomat/Rogue/Tactician trio).
**GAP-ROUND-2 FILED:** #87-#94 (6 analysts + opus judge, all claims repo-verified; the judge's full rejected-list in the workflow journal). Notables: defeat currently rewinds MORE than the fight (the interstitial copy is literally false — #88); the journal's aspiration text names six classes that don't exist (#93); 19/50 skills iconless (#94).
**EXECUTION ORDER (docs/ROADMAP.md):** #96 audit → #93+#95+#98 as ONE class-foundation design pass (Fable-grade design; the reachability table is its input) → #90+#97 as one combat wave (statuses need carriers) → #87 pacing → #88 save safety → the rest. Architecture track (user-approved): #99 freeze / #100 skeleton split / #101 QA tiering behind the class queue (spec: docs/superpowers/specs/2026-07-12-full-game-architecture.md). TWO DECISIONS FOR YOU (spec §3): localization posture; the demo boundary.
## 🌊 8e PALLASS SHIPPED (2026-07-12) — closes #16 at push

The third city, one session end-to-end: A (owned Wang tilesets ratified under quarantine; Grimalkin + tier-clerk rigs, PixelLab v2, measured anchors) → B+C (stacked-band tier maps, dynamism 76.5/71.6; THE PERMIT OFFICE ruling dissolved the reconciliation review's circular deadlock — the exam sat behind the gate it unlocks, a failure mode both lanes independently agreed on and no per-lane review could see; the race key = _meets' 7th gate, text-variants-only, visible-locked; portal rows now map-existence-guarded after the live-crash Critical) → D (controller voice: Grimalkin's measured register — 'adequate. From me, that is not an insult.' — deliberately race-variant-free, CHOICES 26) → E1 (pallass_walkthrough: 207 steps, the full live route with exact gold ledger, 97/97) → E2 whole-branch: SHIP (economy adjudicated WITH numbers — the EXTORT fork alone nearly funds the 46g chain; comment-hygiene finding fixed; drake-line live coverage = optional follow-up). Controller windowed reads: quarantine PASS (market slate/forge industrial-heat), office composition PASS, molten channel within budget.

**8e USER PLAYTEST CHECKLIST:**
1. Papers for Pallass live: Selys 10g → Krshia stone 18g → portal → arrival stamp 2g; fees deduct, journal advances.
2. The permit chain: file 5g → Grimalkin's exam 8g → stamp 3g → the lift opens (locked before, open after).
3. Race read: a DRAKE and a HUMAN PC at the checkpoint clerk + stallkeeper — friction vs assumed-local; GNOLL gets the clean base line.
4. Economy: take Invrisil's EXPOSE fork (0g) — can you still afford the 46g chain by arrival without grinding?
5. Third-city distinctness: market (cool slate) + forge (industrial warm) vs Liscor/Invrisil/Riverfarm.
6. Grimalkin: massive green examiner beside the office window — does he read canon, without swallowing the clerk?
7. Save after the exam, before the stamp → reload → 'About that stamp.' still offered, lift still locked.

## 🌊 WAVE 5 SHIPPED (2026-07-12, pushed 1848890, CI GREEN) — closed #24 #85 #86

Three small lanes, all opus-reviewed: #85 mouse for the last two keyboard-only panels (consolidation modal + char-creation grid; NAME step's missing clickable commit = INFO for a future Begin control); #86 the sync_assets manifest-overlay guard (dry-run default, per-path force, normalization — both review hardenings applied; 15 dead body_a rows removed, 145 legitimate bundle-map rows kept under guard) + the Super Dialogue verdict file; #24 the Rock Crab slice (dr-8 identity, informed-consent confirm conversation with the armor telegraph — review caught a startable-but-hopeless fight for fresh PCs; Relc-downed frontier = CHOICES 22; bundle-v6 released with the baked crab recolor). 95-script sweep green.

**8e PALLASS IN PROGRESS**: plan at docs/superpowers/plans/2026-07-12-8e-pallass.md (rulings recorded on #16). lane-8ea (art phase: tile verdict + Grimalkin + clerk rigs) RUNNING — one stall nudged (the PixelLab background-wait pattern). B/C lanes dispatch after the controller reads the contact sheets (palette quarantine vs Liscor/Invrisil).
**lane-19 RUNNING** (the unblocked #19 slice: presets, inert SteamPipe scaffolding, capsule candidates + screenshots from the real overlay, the trailer scoping note). **USER-SESSION items**: Steam build-account secrets (docs/SECRETS-SETUP.md gains the section this lane), the capsule/screenshot picks, the trailer decision, #80's taste-gate, the CHOICES log (22 entries).

## 🌊 WAVE 4 LANDED LOCAL (2026-07-12) — all 5 lanes merged; final sweep running pre-push

Push closes #78 #79 #81 #84 (#76 stays open for ambient beds). Every lane opus-reviewed; FIX-FIRST cycles on 81 (the frozen-cache unbounded gold pump — gold now rides the variants resolver so the met-gate variant zeroes a one-shot discovery; Pell walks home on report; Drake curse fixed) and fixes-taken on 78 (defeat reveal skippable + the 1-based click DSL tooth) and 79 (the even-base-stat trap comment). Notable: 81's dynamism tool caught a real placement regression mid-lane and forced a relocation — the #73 metric earning its keep on its first content wave. New follow-ups: #85 (mouse for consolidation prompt + char-creation grid), #86 (sync_assets raw-pack landmine + Super Dialogue verdict file). Skill-library additions this wave: the overlay-blindness iron rule (wi-verifying-changes) + the DIALOGUE_ENDED event-order trap (wi-adding-dialogue-and-quests). CHOICES 21 (wordless-voice-only) recorded.

## 🔄 WAVE 4 dispatch notes (superseded)

- **lane-78** #78 save/defeat UX (metadata prefer-derivation, defeat interstitial over the existing flow, index-pin discipline).
- **lane-79** #79 journal communication (opaque-until-sleep binds everything; WIEffectText routes all mechanical lines).
- **lane-81** #81 exploration/optional content (existing seams only; wiki-grounded lore; dynamism-score gate on map edits; owns skeleton_scene this wave).
- **lane-84** #84 QA-teeth (click coverage: inventory/pickers/journal-as-shipped/locked-option no-op/settings row; QA-only, production bugs disclosed not fixed).
- **lane-76** #76 audio — dispatched after the controller scoping pass (census posted as the binding asset contract on the issue). CHOICES 21: **wordless-voice-only ruling** — the Dillon Becker spoken colloquial lines are deferred as a taste-gate even for Erin (canon-plausible for her, but spoken English clips under a text-dialogue game is a build-level taste call, yours); wordless hurt/death/shout sets sanctioned for all combatants (CC BY 4.0 — credit line required if shipped).
- **lane-84 MERGED** (#84 closes at push): click teeth over inventory/journal/dialogue (locked no-op + index-shift proofs non-vacuous per review); consolidation prompt + char-creation grid found KEYBOARD-ONLY (real production gap) → filed #85.
- **lane-76 MERGED (partial)**: review MERGE conditional — executed: bundle-v5 RELEASED on the assets repo (3 xDeviruchi tracks; the oggs had to be copied from the lane worktree into main's overlay first — gitignored files never ride a merge). #86 filed: sync_assets.py's pre-existing raw-pack body_a rows can stomp the curated overlay (the landmine the lane hit and misdiagnosed — its 'pre-existing/git-stash-confirmed' claim was FALSE; overlay-blindness lesson folded into wi-verifying-changes). #76 stays OPEN for ambient beds + bark identity hooks. Minors logged: no duck-depth reset on reset/load; no first-match-wins ordering guard in test_audio_data; Super Dialogue verdict file missing (in #86).
- **D2 MERGED** (present_when gate — reviewer named the STOP-letter miss, adjudicated the artifact as what the STOP would have approved; 3 LOW follow-ups applied: same-map-producer doc constraint, present_when banned on kind:encounter, seal-kept chain coherence arms).
- **E2 whole-branch review: SHIP** — cross-cutting traces all clean (gate web no-deadlock, boss-slot retirement save-proof, defeat walk-back bounded, difficulty spine honest, no bad interaction with the interleaved #64/#65/#73/#77 merges). Its MEDIUM (warren_mouth living-warren flavor reachable post-game) + machine-playtest findings FIXED and committed (see CHOICES 19/20). LOWs logged: snare fought solo right after "Four of us" (context-ally convention, taste queue); the two post-game arcs land in either order by design (writing is defensively neutral).
- **Machine playtest (6 windowed scripts, controller-read)**: riverfarm stone-leg + portal menu CLEAN; inn pre-quest negative CLEAN; Horns residence fixed (CHOICES 19) then re-read CLEAN; trapped_halls at the dark-legibility edge → VISUAL-LOG + your checklist.
- **lane-83 (AI variety)**: review FIX-FIRST — MAJOR: the snare cost eroded AGAIN (guard wards cluster, 0.94) → snare-specific melee ward clones (fix wave RUNNING); con-retune ACCEPTED (CHOICES 18).

**USER PLAYTEST CHECKLIST (8d, for your next session):**
1. The vault fight: is the red danger patch clearly visible the round before the construct's slam (CHOICES 20)? Does the slam FEEL telegraphed with [Dangersense], and fair without it?
2. trapped_halls: too dark on your monitor? (VISUAL-LOG carries the dark-edge read; the tells work adjacent but the wide read is near-black.)
3. The three-route halls choice: does each cost feel real (fight HP+risk / 3g kit / Ksmvr at 17 HP in the vault)?
4. Horns at the inn post-quest: placements + voices read right? (Ceria table / Yvlon hearth-bench / Ksmvr two-exits corner by the pantry door.)
5. Klbkch/Ksmvr sub-arm legibility eyeball (carried from wave 2).
6. The CHOICES log (now 20 entries) — flag anything to flip.
**QUEUE (usage-gated, ~58% at dispatch):** #83 enemy-AI variety (surface free post-C3 — next slot), 8d D2 residence pools + E2 whole-branch review + VISUAL-LOG drain (milestone close), #76 audio, #78 save/defeat UX, #79 journal, #80 (taste-gate), #81 exploration, #84 QA-teeth, #24, DEBT: board_rumors copy-fit corpus gap, economy ledger pass (18g+18g stack), {item:id} effect validation, QA-SCRIPT-NOTES stale prose.

- **lane-65 (/tmp/wi-65)**: #65 witch-stone — invrisil_attuned banking moves from the Guild-board letter beat (stays as signpost) to an Eloise-sold anchor stone, post-blight_lifted vendor stock, 15-20g band. QA: portal menu excludes Invrisil pre-purchase / includes post.
- **lane-8dc3 (/tmp/wi-8dc3)**: 8d C3 — the #82 windup mechanism per the controller sim spec (issue comment = binding), vault arena (>= 4 player spawns — the plan's spawn-ceiling trap), vault_construct slam tuned to a GATED T4-party cell. Encounter may land DORMANT (C1 wires the gate) — disclosed split sanctioned in the brief.
- **lane-73 (/tmp/wi-73)**: #73 scene-dynamism tool — issue body = binding spec; calibration contract (pre-feedback brothers_parlor bottom decile; gate plaza/garden/inn upper half) IS the verification. Tool-only lane.
- **lane-77 (/tmp/wi-77)**: #77 settings + accessibility — audio buses (incl. the UI-bus-ignores-SFX-slider bug), fullscreen, text-scale step (copy-fit-safe or STOP), reduce-motion gate, controls reference off WIInputHints, replayable hints, settings.cfg idiom. New settings_loop canonical.
- CI green on 8f84f74; #17 closed. Closed as already-shipped-by-wave-2: #67 copy-fit, #69 Klbkch companion, #70 [Archer], #71 AoE.
- Controller drafting 8d Phase D Horns dialogue in scratchpad (parked — C3 owns skeleton_scene.json until merge).
- **lane-65 reviewed FIX-FIRST** (fix wave dispatched back to the lane): four Invrisil fixtures encode a now-unreachable state (invrisil_attuned without blight_lifted/stone) + coherence validator gains an invrisil_attuned⇒blight_lifted arm; double-buy retire gets a QA pin. Deferred minors → DEBT: (1) board_rumors `copy` strings invisible to test_copy_fit (pre-existing corpus gap, widened by the lengthened letter); (2) economy: Invrisil access now a mandatory 18g sink stacked after the 18g catalyst, no measured-playthrough basis — wants a ledger pass; (3) test_content never validates `{item: id}` effects against the items catalog (pre-existing) — QA-teeth candidate.
- **lane-73 MERGED to main (local)** — opus verdict MERGE; calibration contract PASS (pre-feedback parlor 19/20 bottom decile; gate plaza #1/inn #4/garden #7; current parlor 59.44 > pre-feedback 54.58). Review's MEDIUM disclosed-and-committed: garden_sanctuary's upper-half placement depends on its singleton region group (in-region axis = flat 0.85 CREDIT, unmeasured) — report now carries a 'What this metric cannot see' section + the gaming-vector trap comment at the 0.85 branch. Re-gate on main: import clean, tool byte-identical, spot unit green. #73 closes at push. NOTE for wi-adding-a-scene skill (controller edit, pending): run the tool on new/edited maps, target >=50, breakdown tells you what to add. Observation kept: ruin_surface (50.77) scores BELOW the pre-feedback brown box — genuinely under-dressed, VISUAL-LOG candidate.

## 🌊 WAVE 2 OF ULTRACODE SHIPPED (2026-07-12) — 6 more lanes landed

ALL MERGED at 86/86 + ALL units green (every lane opus-reviewed; every
FIX-FIRST applied + re-gated):
- **#70 [Archer]**: the ranged class is live — weapon-range+LoS attack
  seam (melee byte-identical), bow ladder (peddler 8g / Krshia 18g),
  archery-butt earn (class earnable without a kill), kit on existing
  effect types, [Sharpshooter] evolution. Review caught bow hits
  double-feeding [Warrior]'s melee_hit — fixed + toothed.
- **#84 mouse menus**: every panel clickable, one-dispatch verified.
  OPEN for the QA-teeth follow-up (inventory/picker/journal clicks).
- **8dC2 Horns combat**: Ceria/Yvlon/Ksmvr ally entries + construct
  stat seed + the first 4-ally harness cells (PC-death assert). C3
  spawn-ceiling trap written into the plan.
- **dlgwave (#74+#17+#63)**: travel signposting standard (place-named
  beats + validator + remind-me recaps + journal region suffix); the
  full voice-fix set (Krshia Hrr at 3 corpus-wide, Pisces contraction-
  free, Coyle eerily calm, 11 hub exits differentiated, 0 'Actually -
  one more thing.' left); ELOISE live in Riverfarm (entity swap =
  finding-19 scale fix) + Former Headman (placing line kept OBLIQUE —
  review caught the lane naming Laken; restored to controller copy).
- **#72 posting generator**: board 9→18 bounties, 5→10 deliveries via
  the offline grammar; review caught alley_cull dead-ending after the
  Wilovan quest close (mode→absolute) + the generator's kill rule now
  scans dialogue remove_entity effects.
- **#75 combat readability**: aim previews derived from the sim's own
  functions (cannot lie), impact damage numbers, attack connection
  (adjacency-gated lunge/projectile), status pips, active-unit marker,
  duplicate-name dedup. LOW fast-follow: status-pip skip-desync arm.
- Composition reds fixed en route: cups_debt_chit pin, stages_loop/
  d2_shop_shot bow-row pin (a bad 3-way merge resolution — mine).

**QUEUE:** #82 telegraphs + 8d C1/C3/D (the construct fight — C3 trap
noted), #65 witch-stone, #64 skill-gates (last dialogue pass), #73
scene-dynamism, #76-#81/#83 gap waves, #84 QA-teeth.

## 🚢 HUB SHIPPED (2026-07-11, pushed ab21ea3, CI GREEN) — 8 issues closed

The 62W hub merge landed: all 13 world hotfixes (inn stairs in the
herringbone corner — windowed-read ✓; music revert; ambush one-shot;
the night-pacing fix that HAD NEVER SHIPPED now genuinely 200/450;
guardian anchor src fix), reconciled against 5 later merges (the
invrisil_walkthrough graft: 62W's burst re-pin + #68's stage-1 detour
compose, PASS). 8dB dungeon merged (both maps + traps + dungeon_peek,
85/85; illusory-floor mouse tell-leak disclosed in-data). Eloise rig
landed. Full gates: ALL unit suites + 85/85 sweep + windowed reads.
CLOSED at push: #32 #33 #34 #35 #61 #62 #66 #68.

**RUNNING:** lane-dlgwave (#74 signposting + #17 voice fixes + #63
Eloise/Former-Headman wiring — controller-authored lines in the brief),
lane-70 finisher (Archer — resumed from WIP), lane-84 (mouse menus).

**QUEUE:** 8d C1 (quest — after dlgwave settles quests.json), C2
(Horns combat entries + 4-ally bands — free surface, next slot), C3
(construct + #82 windup mechanism — spec in #82), D (Horns dialogue,
controller); #65 witch-stone (after dlgwave's riverfarm files settle);
#64 skill-gates audit (LAST dialogue pass); #72 (post-#66 ✓ — tier
table shipped, dispatchable); #73 scene-dynamism tool; gap issues
#75-#83 by priority (75 combat readability first — pairs with #82).
## 🔬 GAP ANALYSIS LANDED (2026-07-11, ultracode workflow) — 37 confirmed → #74-#84

51-agent workflow (8 dimension analysts → judge dedup/rank → per-gap
adversarial verify vs repo+backlog+locks): 42 ranked, 37 CONFIRMED,
3 REJECTED with evidence (autosave cadence = protection already
adequate; consolidation-consequences = opaque-until-sleep lock
violation; Invrisil-boulevard-sparse = stale census, #68 already
densified it), 2 unverified (verifiers lost to the session reset;
folded into batches anyway as small items).

FILED (thematic batches, not 37 singles): #74 travel signposting (THE
top gap — the user's own ruin hard-stall is its evidence; S, first),
#75 combat readability (aim preview/damage numbers/connection/status
marks/turn clarity), #76 audio identity, #77 settings+accessibility,
#78 save/defeat UX, #79 journal+progression communication, #80 world
reactivity (taste-gate on NPC presence scope), #81 exploration+
optional content, #82 boss telegraphs (+[Dangersense] payoff — FEEDS
8d C3), #83 enemy AI variety, #84 mouse menus (DISPATCHED as a lane
immediately — free surface).

CHOICES: batching over singles; #74 sequenced first post-hub (its
dialogue files collide with the 62W merge); #82 explicitly coupled to
the 8d construct so the boss ships WITH the telegraph language.

## 🔄 QUIESCENT STATE (2026-07-11, session limit) — RESUME MAP

Main is GREEN and PUSHED (every merge swept; last composed re-gates
targeted — run ONE full sweep + ALL units before the next push).
All four in-flight lane branches pushed to origin as backup.

**MERGED + LOCAL on main (unpushed commits exist — push after full
gates):** #68 rework (+review FIX-FIRST: stage-1 gate closes the
bypass), #69 Klbkch companion, #71 [Flame Pillar], #67 copy-fit
(+minors), #61 spellsword top-end, #32-35 rulings lane (reviewed
MERGE — closes those 4 issues at push), voice-audit structural fixes,
8d Phase A art (Horns/construct/Klbkch-slice rigs + Eloise profile),
CHOICES log, 8d plan updates.

**AWAITING REVIEW VERDICT (branches pushed, committed, DO NOT merge
without the verdict):**
- lane-62w (11f7c83): ALL 13 world hotfixes + guardian-anchor src fix.
  Review was re-dispatched (misfire #8) — RE-DISPATCH FRESH on resume
  (brief in this session's log; 6 trace priorities incl. the
  board_renderer idle-fallback DP2 adjudication). THE MERGE HUB:
  reconciles skeleton vs 5 later main merges; then full sweep + ALL
  units + windowed reads (inn layout, village grade, guardian
  adjacency) + batched push closing #62.
- lane-66 (077d8f5): T3 tier retune. Review dispatched late — verdict
  unknown; re-dispatch if absent.

**WIP SNAPSHOTS (implementation incomplete — resume the lane agent's
checklist, do NOT merge):**
- lane-70 (Archer): seam + kit edits visible; canonical/harness
  unverified. Spec = the binding comment on #70.
- lane-8db (dungeon Phase B): biomes/moods/skeleton/sprites edits
  visible; peek canonical unverified. Charter = plan doc Phase B.

**RUNNING WORK LOST WITH SESSION (restart these):** the gap-analysis
workflow (rerun: workflows/scripts/rpg-gap-analysis-wf_630d4e7b-296.js
via Workflow scriptPath); Eloise char gen COMPLETE server-side (char
717c7f2a — download zip, integrate per the Horns recipe); construct
anims already integrated.

**QUEUE after the hub merge:** voice-fix copy lane (#17 dispositions
in the issue comment), #63 Eloise exec (profile+gen ready; Former
Headman rename; witch scale), #65 witch-stone, #64 skill-gates lane,
#72 (post-66), #73 scene-dynamism tool (spec in issue), 8d C/D.

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
23. **The Permit Office (8e reconciliation ruling)**: the forge-permit clerk + Grimalkin's exam moved to a market-tier office beside the Grand Lift — the reconciliation review found the exam placed BEHIND the very gate it unlocks (a circular deadlock both lanes independently agreed on) and the stamp's producer had no host entity at all. His forge post ships as dressing. Flip = a pre-lift forge landing redesign.
24. **Papers-for-Pallass Stage 1 ships fee-only (10g)**: the plan's alternate completed-postings-record path needs an aggregate counter that doesn't exist — the lane STOPPED correctly; RULED not to build tracking machinery for one gate. The record path lands if/when an aggregate counter ships for its own reasons.
25. **The 46g Pallass chain on the compounding sink** (10+18+2 papers + 5+8+3 permit, atop invrisil's 18+18): each fee is in the sanctioned band and the 18g stone matches precedent exactly; the CUMULATIVE ~82g three-city travel spend is flagged for the economy ledger pass (also CHOICES-noted at #65). Your call whether mid-game income covers it without board-grinding.
26. **Grimalkin carries no race variants (D-phase)**: the examiner measures, the city profiles — the clerk + stallkeeper carry the Human-friction/Drake-local lines instead. Flip = add his variants.
27. **Haggling is opt-in (class pass)**: the review proved default-discount leaked [Bargain] onto civic fees, wagers, and free rumors — RULED: `haggle: true` opt-in, v1 carrier = the witch's shop only (Krshia's 'no discounts' line honored mechanically everywhere; Pallass/civic never). Thin surface accepted; #92's vendors expand it. Flip = re-mark carriers.
28. **The 50% sell rate ratified** (plan said ~40%; the shipped pre-existing Krshia buyback was 50% — churn-avoidance wins; #92 rebalances holistically).
29. **v0.5.1 cut to itch immediately after #106 lands** (standing don't-block deference): the itch "mobile friendly" flag (your step) is meaningless until a build with combat touch is actually live — v0.5.0 predates #106. Local butler path, same as v0.5.0. Flip = tell me to hold releases for your review first.
30. **Desktop mouse UX change rode #106 (review Minor, accepted)**: during targeting, a click that misses every candidate now CANCELS the aim (was a silent no-op) — the Esc-equivalence contract wants one consistent rule for tap and click. Flip = gate the cancel to touch-emulated events only.
22. **Rock-crab Relc-downed frontier (lane-24)**: relc_downed 0.83→0.62 at 0.93 win — the ~0.5 target is STRUCTURALLY infeasible in the 0.55-0.95 band for any single-melee roster vs warrior2+relc (melee AI focuses lowest-HP = Relc soaks by design; the measured frontier + two escape routes — per-cell band floor-raise or a windup cadence — documented in the combatant _comment for your ruling if 0.62 still reads wrong).
17. **8dC1 FIGHT-route cost ruling**: review proved the snare fight's "cost = HP" was illusory (0.99 win/2 rounds, and combat HP doesn't persist to the field). RULED: roster-only fix — one tier-appropriate existing combatant added to the snare encounter, cell re-derived aiming GATED band; no stat changes to shipped combatants (protects ruin_guardian_w8's shipped band). Also: vault gate now requires the party formed (a solo player walking past the Horns hit a 4-party-tuned boss with no signpost — ordering accident, not designed hard-mode; awakened_boss's [I go alone] confirm+measured-solo-cell is the designed shape if you ever want a solo-vault mode).
18. **#83 con-retune ACCEPTED (deviation from the roster-only precedent, adjudicated on the merits)**: the ruin wards' guard adoption broke ruin_guardian_w8_relc's band (0.54, verified); the lane retuned the shipped boss con 28→24 rather than forfeit the adoption. Player-facing deltas for your awareness: the door-chain FIGHT leg genuinely plays differently (the old canonical seed now LOSES at ruin_court; re-derived), guardian-with-Relc 0.69→0.59 (harder, low-band), guardian solo 0.01→0.09, night wolves read safer (skirmisher wolves: 0.30→0.48 solo). Flip = drop the wards' guard profile instead.
19. **Yvlon placement + the hearth bench (playtest fix)**: my Ceria line referenced a couch the inn didn't have; the D2 lane parked Yvlon at the literal kitchen hearth between the cook-pots. RULED: bench decor added by the hearth's common-room side (parlor-couch precedent sprite) + Yvlon beside it — the line is now literally true. Flip = move/remove either.
20. **Windup overlay brightened without an in-fight windowed read** (mid-fight shots aren't stageable under combat_autoplay): old color was provably invisible on the vault grade (~13/255 delta); new (1.0,0.25,0.2,0.7) is ~2.5x. YOUR EYES: in the vault fight, is the red warning patch clearly visible the round before the slam?

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
