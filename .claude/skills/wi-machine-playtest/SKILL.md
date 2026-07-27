---
name: wi-machine-playtest
description: Use after any wave touching a player-facing surface (sprites, panels, copy, maps, mood) and at every milestone close — plays the game with player eyes via windowed QA screenshots, as opposed to the logic-proving sweep.
---

# Machine-Driven Playtest

**Canonical protocol: `wandering_inn_game/qa/MACHINE-PLAYTEST.md`** — read
and follow it verbatim (isolation decision, script coverage matrix,
per-screenshot checklist, event-log copy diff, report format). This skill
is the loop-integration wrapper.

## When (binding, user-ratified 2026-07-07)
- After ANY wave that touched a player-facing surface — BEFORE claiming
  the wave done. The sweep proves logic; it is structurally blind to
  baked sheet artifacts, fold clipping, dark-scene legibility, and UI
  furniture accumulation (all four shipped green before this protocol
  caught them).
- At every milestone close: full rotation.
- ~15-20 min for a 6-8 script pass; rotate the subset, ALWAYS include one
  dark map, one panel-heavy script, one script covering the newest
  feature.

## Iron rules
- **Windowed verification ALWAYS runs on the real asset overlay (user
  directive 2026-07-20):** `scripts/fetch_private_assets.sh` + `--import`
  pass BEFORE any windowed read — placeholder art invalidates every FEEL
  judgment (legibility, overlap, mood). In a remote session, `gh` is
  absent: add the assets repo to the session (add_repo, needs user
  approval once) and pull the newest `bundle-vN` tarball via the
  authenticated proxy instead. Headless/event-level verification may
  run on placeholders.
- Dirty tree or mid-refactor session → detached worktree at a known-good
  commit (`git worktree add --detach /tmp/wi-playtest HEAD` + `--import`
  pass), never a mid-surgery tree. Remove the worktree when done.
- READ every PNG as a first-time player (the protocol's checklist);
  diff rendered text against the events.jsonl payload — a punchline that
  only exists in the payload is a bug.
- Findings ranked player-visible-first; every claim cites its screenshot;
  visual findings → docs/VISUAL-LOG.md; blockers → HANDOFF next-steps.

## Live data reload — the tuning loop (GH#278, 2026-07-26)
Content tuning (dialogue copy, balance numbers, map props) no longer
pays the relaunch tax. Every load rebuilds the sim from FRESH disk JSON
(`WISceneCatalog` resets inside `_make_sim`; sprites/moods/audio caches
reset on GAME_LOADED), so:
- **Windowed human loop:** edit `data/*.json` → pause → Save → Load →
  the surface re-renders with the new content, same state. No restart,
  no renavigate.
- **Scripted loop:** the `reload_data` TestDriver step (refuses in
  combat/dialogue/consolidation with a toast; `expect: false` pins the
  refusal). Canonical: `reload_loop`.
- Limits: repainted PNGs still need a reimport (ResourceLoader cache);
  id renames/removals are NOT migration-checked — value tuning only.

## Dev debug overlay (GH#279, 2026-07-26)
F3 (windowed, debug builds) / `toggle_overlay` QA step: read-only
sim-state panel — map/cell, live rng.state, counters (▲ = banked in the
last 20 events), quest beats, event tail, save-slot status. **FEEL
captures run overlay-OFF** (full-window screenshots; overlay-on = 
contaminated evidence). Overlay-on companion shots: separate, clearly
named captures when a finding needs the sim state pinned in-frame.
Human eye/ear-gate asks: an overlay-on screenshot turns "nothing
happens" reports into exact state snapshots.

## Targeted playtest requests (user directive 2026-07-17)
Any request for USER eyes/ears on a specific surface (an eye-gate, an
ear-gate, a taste call) MUST ship with a **prepared Playtest State**: a
named save/fixture the user loads that lands them AT the thing being
judged (right map, right cell, right counters, the feature armed) plus
a one-line "load X, do Y, judge Z" instruction. Never ask the user to
navigate there themselves — staging cost belongs to the agent. Fixture
authoring per wi-writing-qa-scripts; park the save under
playtest_saves/ with a dated name.

