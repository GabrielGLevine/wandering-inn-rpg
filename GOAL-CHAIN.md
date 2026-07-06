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
