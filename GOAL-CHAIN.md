# GOAL — the full roadmapped chain (2026-07-06 →)

**Mission: execute the ratified ladder end-to-end, each milestone
closed clean (full gate + whole-branch opus review + user playtest
checklist) before the next opens. Never trade a clean close for
starting the next. The user gates every taste/canon/irreversible call
via the HANDOFF queue.**

## The chain, in order

**1. M-ARC (in flight — finish it):**
- Char creation (M-ARC §5): lane may already be complete — check the
  ledger; controller reads shots, commits, syncs.
- A2 Raskghar descent (plan `docs/superpowers/plans/2026-07-06-m-arc.md`
  Task A2; sprites via the v2 character pipeline per wi-art-and-sprites
  + docs/design/character-profiles.md Raskghar entry; WORKING sprites
  not statics — user directive).
- A3 climax chain (climax copy DRAFT → user taste gate before the
  milestone closes; party context+veto beat).
- A4 GDI epilogue + free play + arc_flow canonical.
- AF: full gate + VISUAL-LOG drain + opus whole-branch review + HANDOFF
  playtest checklist.

**2. CLEANUP (structural, no lanes live during it):**
- Rename `wandering_inn_game_v4/` → `wandering_inn_game/`: full path
  ripple (run_qa/ci_sweep/web scripts, workflows, CLAUDE.md files,
  manifest + bundle LAYOUT — rebuild + re-release the bundle on the
  assets repo after, since release.yml's overlay extracts by path),
  sync script excludes, docs. Full gate + a fresh tag-deploy proof
  after (the deploy is the riskiest consumer).
- Remove the godot-ai addon: `addons/godot_ai/`, the `_mcp_game_helper`
  autoload + plugin entry in project.godot, godot-ai-LICENSE.txt; the
  game_helper grep exemptions become dead — REMOVE them from
  ci_sweep/ci.yml/release.yml/wi-verifying-changes in the same pass
  (zero-warning discipline must hold with no exemptions); retire
  wi-godot-mcp via HANDOFF proposal (post-Fable sessions do NOT edit
  skills — library governance).
- Full sweep + smoke + public sync + one tag deploy = the exit gate.

**3. M-LEGIBILITY** (spec §2 of
`docs/superpowers/specs/2026-07-06-systems-depth-priorities.md`,
user-ratified): the coordinator AUTHORS the implementation plan first
(plans are design — top-model work, plan-time corrections header,
user skim if any call feels taste-shaped): item-card effect lines in
visible currencies, skill cards, the status glossary + first-encounter
toasts, the copy audit. NO raw stats, NO progress-toward — the
identity rules are absolute. Exit: gate + review + playtest checklist
("can you tell which armor is better WITHOUT feeling like a
spreadsheet?").

**4. M-GEAR** (spec §1): plan-author then execute — resonance costs +
capacity (opaque growth), 2-3 accessory slots, item lore lines,
new items through shop/loot/rewards, harness loadout cells for every
new equippable. Canon resonance framing wiki-verified. Depends on
LEGIBILITY's item cards.

**5. SKILLS WAVE** (spec §3+§4): plan-author then execute — the
overworld-impact pass on existing kits (freeze-to-cross water, burn
debris, threat-range reveal — each [Light]-bar: sim seam + presentation
+ windowed proof + canonical coverage) + gap-based new Skills (verbs →
wiki-verified canon Skills → class kits; every new Skill ships a
combat AND overworld read where sensible). Movement + stealth are the
priority verbs (user).

**6. SOCIAL PILLAR II**: needs a BRAINSTORM-level spec first (the
coordinator drafts a seed: what deepens repeatable social play beyond
pools — relationship arcs? re-armable persuasion? social quests?);
QUEUE the open design calls in HANDOFF for the user, execute only
after their ratification.

**7. M-DEPTH — LISCOR INTERIORS (user 2026-07-06; the scope rule
"depth-in-Liscor beats map sprawl" applied):** seed spec
`docs/superpowers/specs/2026-07-06-liscor-depth-seed.md` — the
Adventurer's Guild interior (Selys relocates behind the desk; Olesm's
haunt; THE REQUEST BOARD = the repeatable-bounty surface), the inn
upstairs (your room; the inn-as-home grammar the Garden hook needs),
+ one more interior (user picks: Krshia's shop / Watch barracks / the
Dark Cellar). Spec-ratify the open calls with the user → plan →
execute. Every interior ships a mechanical surface, never an empty room.

**8. THE EXPANSIONS (user-seeded, canon-anchored — each a content-wave-
class milestone; [Door of Portals] is the shared front door):**
- **8a. [Door of Portals] + [Garden of Sanctuary]** (the unlock
  mechanism first): the inn's magic door as the earned access gate to
  expansion maps + Liscor fast travel (door_when/act machinery scales);
  the Garden as an earned sanctuary space in the inn. Spec-brainstorm
  the earn conditions with the user (taste-gated), then plan + execute.
- **8b. Riverfarm — the Witch quest** (smaller scope than Invrisil:
  village map family, witches' canon, one multi-path quest chain).
- **8c. Invrisil — Brothers of Serendipitous Meetings** (big-city map
  family, hideouts, rogues, HUMAN enemies — the stealth/movement Skills
  from step 5 are load-bearing here; sequence after the Skills wave
  delivers them).
- **8d. Liscor Dungeon — with the Horns of Hammerad** (the M-ARC
  Raskghar seal-beat hook pays off; party context machinery fields the
  Horns; the demo's endgame content).
**8e. PALLASS (user-raised 2026-07-06; seed in
docs/design/city-identity-bible.md §Pallass):** the vertical machine
city — two tiers v1 via the Door; QUALIFY verb; scope call at boundary.

**8f. THE VOICE PASS (after 8d — the content chain's closer):** a
full audit of every player-facing string (dialogue, pools, observe/
friendly lines, lore, toasts, bounties, quest text) against the
character profiles + the voice-lint in wi-adding-dialogue-and-quests
(the anti-AI-tell list): opus-driven, per-character sweeps, fixes as
data edits, user spot-reads the diffs. Guards at every delivery
(writer self-check + reviewer hunt) run from now on — the pass
catches what guards miss.

**9. M-STEAM (user-seeded; unscheduled tail):** seed at
docs/superpowers/specs/2026-07-06-m-steam-seed.md — THE GATE is the
non-commercial promise (free-on-Steam recommended; any paid path needs
pirateaba's explicit permission FIRST — ⚑ user). Engineering center =
controller support (pad bindings + glyph hints + panel focus-nav);
then desktop presets, SteamPipe jobs, store assets. v1 ships no-SDK;
achievements later (accomplishment counters map 1:1).

Each expansion: spec (canon-heavy, user-gated) → plan → execute →
review → playtest, per the content-wave precedent (profiles for every
new character FIRST, three-path quest parity, direction cards per map).
Order 8a→8b→8c→8d→8e unless the user reorders at a boundary.

## The machine (unchanged, no exceptions)
- superpowers:subagent-driven-development: fresh implementer per task
  (Opus for judgment work), NO-COMMIT implementers, controller stages
  EXPLICIT lane-reported paths (never `git add -A` while a lane lives),
  per-task verification per wi-verifying-changes, whole-branch opus
  review per milestone.
- Briefs carry the FOREGROUND-ONLY verification mandate verbatim; a
  lane "standing by" for a notification is STALLED — resume it bluntly.
- Every commit leaves HEAD green; `scripts/sync_public_export.sh -m`
  (HEAD-based) after every public-relevant commit; deploys = tag push
  (wi-shipping has the whole playbook + every gotcha).
- Ledger (.superpowers/sdd/progress.md) per task; HANDOFF live;
  character profiles (docs/design/character-profiles.md) are the
  writing+generation contract; canon from wiki.wanderinginn.com, misses
  escalate flagged.

## Guardrails
- User gates (never resolve by implication): all taste/canon/copy
  flags, anything outward beyond the established tag-deploy loop,
  purchases, the §6 Social II design calls, resonance-capacity feel
  numbers if they turn taste-shaped.
- Identity rules absolute: stats hidden, opaque-until-sleep, visible
  currencies only, three-pillar parity, tune-data-never-sim.
- Balance: harness-gated; new gated cells 0.55-0.95 unless a
  user-directive precedent says measured-only; frontier escalations,
  never silent re-gates.
- PixelLab: v2 character pipeline for characters (working sprites, not
  statics); profiles drive prompts; windowed reads mandatory;
  subscription active (don't ration, do stop-on-pass).
- Post-Fable library governance: skills are READ-ONLY for non-Fable
  sessions — propose edits via HANDOFF "SKILL PROPOSALS" with evidence.

## Stop conditions (clean boundary + `=== SESSION STOP ===` ledger entry)
- A task red after 2 full fix loops → park w/ state dump, continue
  independent work.
- A spec/plan contradiction corrections don't cover → park the
  milestone, queue the question.
- Context/budget pressure → close the current task fully, stop entry,
  HANDOFF NEXT pointer.

## Reporting
Per milestone close: ledger entry + HANDOFF playtest checklist + a
short user-facing summary (commits, verdicts, queued calls). If a
session ends mid-chain, MORNING_SUMMARY-style handoff (≤1 page).
