# GOAL — v0.13 Depth + Polish Wave (charter, 2026-07-18)

Executes AFTER v0.12.1 ships (mobile hotfix: #196/#197/#202 + gold caps).
User directive: continue autonomously; judgment calls to docs/CHOICE-LOG.md;
user defers to recommendations to keep things moving. No user playtest gates
except the items marked USER-GATED below.

## Mission
Ship v0.13.0 as a significant depth + polish release: textures, visual
fixes, side quests, interiors/interactions, sprite & prop diversity,
mobile-input completeness, pacing, and the challenge-weighted progression
redesign. Plan of record:
**docs/design/2026-07-18-v0.13-depth-polish-wave.md** (18 packages, 3
file-ownership lanes). Board: issues #194–#225.

## Execution order
1. **#194a/#194b god-file seams FIRST** (lane a) — one seam per PR,
   byte-identical event streams at pinned seeds. Everything in lanes b/c
   that touches interact routing or banking waits for #194a.
2. **Challenge-weighted leveling (#211 + user directives in its comments)**
   — adversity-not-repetition: challenge weight (enemy power vs player
   power) on combat-sourced counters, per-encounter repetition decay,
   fractional banking (save VERSION bump + migration), and
   resolution-path-exclusive quest experience (diplomatic vs combat closes
   feed ONLY the resolving class line). Design doc + sim harness
   (progression-pace traces Act I→III) before data tuning. This is the
   wave's largest sim package — schedule right after #194a while the
   banking seam is freshly extracted.
3. **Lanes a/b/c in parallel** per the plan doc's dependency tables
   (mobile combat a3 + tap completeness a4; Rags b1 + Ratici b2 + parleys
   b3 + Grimalkin b4 + Invrisil aftermath b5 + Hedault b6 + ack/affordance
   wave b7 + audio b9 + ruin stone b10; art batches c1→c2, c3, c4→c5,
   floors c6). Same-file work = single implementer; lanes never share
   files.
4. **Pacing a6** (day ~2x, #206) and **hotbar auto-slot a7** (#208) are
   small and independent — slot into any gap.
5. Release mechanics at wave end (wi-shipping): rotation playtest, freeze
   cut, tag v0.13.0, watch all three deploy targets. Interim tags
   (v0.12.2…) allowed if hotfix-class findings land before the wave
   completes.

## USER-GATED (do not proceed without explicit go)
- PixelLab batch B fauna/icon items (VISUAL-LOG Wave D-2 standing gate).
- Dark-map legibility lift (a5): ships behind a prepared-save Playtest
  State for the user's windowed eye-read.
- #111 project rename and #19 Steam remain HOLD.

## Standing rules (unchanged)
- PR-per-issue on `issue/<n>-<slug>`; verified 6/6 checks table before
  merge; issue-close PR template; reviewer subagent per task with method
  hints; prove-gates-can-fail (mutation) for new QA surfaces.
- Full sweep + exit-code-aware unit bar before every push; the sweep's
  zero-SCRIPT-ERROR grep is part of the bar (standalone run_qa is not).
- New QA scripts register in qa/manifest.json + AGENTS seed table +
  `python3 scripts/render_qa_notes.py --write` (all three, or CI's drift
  checks red).
- Usage guard at dispatch/merge points (wi-usage-guard); Codex available
  for bounded implementation waves per wi-delegating-to-codex.
- CHOICE-LOG every adjudication; HANDOFF stays current-state; new traps
  fold into .claude/skills/wi-* (Fable-only edit rule stands until
  handover).
- Spoiler bar: Book 17 content ceiling, Vol 7 advertised; Rags is
  early-volume-safe; say "Magical Door", never the Vol-9 name.

## Definition of done
All 18 wave packages merged or explicitly deferred with CHOICE-LOG
rationale; #196–#214 user notes all closed or rolled into packages;
v0.13.0 tagged with all three deploy targets green; wave retrospective
appended to CHOICE-LOG; this file updated or retired.
