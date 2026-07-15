# VISUAL-LOG Drain Design

**Date:** 2026-07-14
**Status:** User-approved
**Work item:** [GitHub issue #113](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/113)

## Purpose

Drain every unchecked entry from `docs/VISUAL-LOG.md` without hiding large
redesigns inside a polish pass. Bounded defects are fixed now, including all
bespoke art they need. Repo-wide rendering conventions and major interaction
redesigns become dispatch-grade follow-up issues. The log ends with zero
unchecked entries.

The controller demonstrated the required visual capability before design:
Godot 4.7 launched a real windowed QA run, the throwaway rock-crab probe
passed, and both full-resolution frames were inspected. The live crab failed
its boulder-mimicry read because its salmon-brown palette, small rounded
silhouette, and foliage/player occlusion remained plainly distinct from the
nearby neutral-grey boulder. The dialogue frame itself passed wrapping,
hierarchy, and choice visibility. The throwaway script was deleted and the
worktree returned clean.

## Goals

- Re-audit all twenty unchecked log entries against the current game.
- Fix every bounded visual, staging, copy, or QA defect.
- Generate and integrate every bounded bespoke-art need during this drain.
- Judge every player-visible result in a real windowed scene at gameplay
  scale.
- Preserve the data-driven scene and sprite architecture.
- Promote only the three approved broad redesigns, with enough evidence and
  acceptance criteria to execute them later without rediscovery.
- Finish with a fully green composed tree and no unchecked VISUAL-LOG entry.

## Non-goals

- Do not implement the board-picker interaction redesign.
- Do not implement field-readout collapse/expand behavior.
- Do not change the repo-wide blocked-cell rendering convention.
- Do not refactor unrelated presentation code or retune combat balance.
- Do not prefer public assets over better licensed or generated assets.

## Item Disposition

| Open entry | Disposition in #113 |
|---|---|
| Skill icons | Generate and integrate real icons for the remaining player-visible iconless skills; shrink the drift allowlist accordingly. Re-audit passive/enemy-only records and close only where no player-facing icon surface exists. |
| Rock crab | Replace or regenerate the live art so the field token and combatant read as the nearby boulder family while remaining legible when revealed. Verify next to the real floodplains boulder. |
| Dart slit and illusory-floor tells | Generate palette-matched Cemetery-family tells and integrate both states in `trapped_halls`. |
| Riverfarm witch/cottage overlap | Resolve through the smallest scene-safe position or sort correction that leaves interaction and route contracts intact. |
| Relc descent-veto cameo | Add a bounded walk-on/field presence at the warren-mouth beat using existing Relc art and the established dialogue-presence idiom. |
| Board/delivery picker | Promote to a dedicated issue; retain screenshots, affected canonical list, interaction constraints, and acceptance criteria. |
| Upstairs room zoning | Add an in-family rug, palette, or decor cue that distinguishes the player's space from Lyonette's locked room without clutter. |
| Sewer arena bat-like decor | Reproduce current combat readability first; remove, recast, or restage only the props that still compete with the live Sewer Bat silhouette. |
| Delivery board | Generate a bespoke indoor delivery board with a slips-and-strings identity distinct from the request board and no outdoor grass base. |
| Small-prop player occlusion | Add the narrowest reusable per-entity presentation override or scoped art correction needed for `bread_stall` and `lyonette_door`; do not globally bias their heavily shared sprite ids. |
| Guild notice wall | Generate a pinned-paper wall treatment distinct from both the request and delivery boards, then rebalance the local cluster only if the windowed read still feels dense. |
| Sparse combat arenas | Re-audit the partially dressed arenas windowed; add bounded biome-consistent off-grid dressing only where the current frame still reads empty. |
| Field readout collapse/expand | Promote to a dedicated interaction-design issue with input, accessibility, icon-recognition, and first-waking constraints. |
| Deep-tunnel threshold props | Generate distinct art for the fissure, cold hearth, gnaw pile, and warren mouth, preserving the dark cave palette and each prop's semantic silhouette. |
| Sewer nest ledge | Generate a broken-brick overlook lip that belongs to the sewer wall family. |
| Shield Spider | Generate a dedicated animated banded-carapace spider; replace the bat stand-in in field and combat surfaces. |
| Field blocked-cell rendering | Promote to a dedicated repo-wide rendering issue with multi-map visual acceptance and migration/performance risks. |
| Garden diagonal QA leg | Extend the canonical Garden route with an internal diagonal/Y-sort regression beat and windowed screenshot. |
| Terrain slow-expiry text | Add source-aware copy for the ice-floor reapplication case without weakening generic expiry behavior. |
| Ruin route readability | Put ruin-specific architecture on the route players and QA actually see, using bounded dressing or route framing rather than a biome-wide rebuild. |

Every row must finish as one of: fixed with before/after evidence; closed with
a current-state non-reproduction or already-fixed finding; or linked to one
of the three promoted issues. No fourth disposition exists.

## Execution Shape

### Wave 0 — Evidence audit

Capture current windowed evidence for every open surface before changing it.
This wave closes stale, duplicated, already-fixed, or non-reproducible items
without manufacturing unnecessary work. Keep screenshot artifacts outside
their normal `qa_output/<script>` directories before any later run can
clobber them. Record the exact current-state verdict in the log.

The audit also establishes the final file map and confirms which canonical
scripts cross every map or UI surface. It does not change gameplay.

### Wave 1 — Generated art

Produce and integrate the bounded art set: skill icons, rock crab, dungeon
trap tells, delivery board, guild notice wall, deep-tunnel props, sewer ledge,
and Shield Spider.

PixelLab is the primary bespoke-art resource. Use its character pipeline for
animated creatures and its prop/icon generation paths for static art. Follow
the repository ceiling of six candidates per subject. Candidate sheets are
only an intermediate artifact: the decision happens in the actual game scene.

Art selection is fidelity-first across licensed private packs, public packs,
existing sprites, and generated art. There is no preference for public art.
Licensing determines storage and shipping mechanics, not the quality choice:
redistribution-limited winners ride the private bundle and manifest; generated
or redistributable winners may be committed publicly. A weak generated result
never wins merely because it is new.

Every winning asset receives its required provenance/license note, import
sidecar, `data/sprites.json` record, expected animation-frame test row, and
consumer wiring. Do not hand-author `.tscn` files.

### Wave 2 — Scene staging

Resolve the witch overlap, Relc cameo, upstairs zoning, small-prop occlusion,
sewer-arena silhouette competition, remaining sparse-arena reads, and ruin
route readability.

Prefer presentation-only corrections when they solve the defect. If an entity
must move, re-check all four neighbor cells, interaction adjacency, door
landings, save compatibility, and every path-walking QA script crossing the
map. Solid-looking additions remain honest under the blocking contract.

Scene additions follow the established asset families and composition guide:
one semantic purpose per prop, contact grounding, restrained accents, and no
new clutter added merely to raise density.

### Wave 3 — Bounded presentation and QA

Implement terrain-aware slow-expiry wording through the existing status/event
copy seam so generic status expiry remains unchanged. Extend the Garden
canonical with one real internal diagonal route and a screenshot that can fail
on the documented Y-sort edge case.

Create the three promoted GitHub issues before #113 closes. Each body includes
the original symptom, screenshots, affected code/data/canonicals, explicit
non-goals, risks, and measurable acceptance criteria.

### Final composition

Run the composed verification gate, perform a final multi-scene windowed read,
update `HANDOFF.md` with only live follow-ups and user taste calls, and convert
all remaining VISUAL-LOG checkboxes to their final disposition. Land waves as
separate focused commits so regressions and art provenance remain attributable.

## Integration Contracts

### Art data flow

Generated or selected source image → correct public/private asset location →
Godot import sidecar → `data/sprites.json` → map/combatant/skill consumer →
sprite-registry test → windowed scene read.

The controller measures alpha bounds and feet/contact planes before setting
anchors. Pixel art stays nearest-filtered and lossless. Animated characters
must preserve identity across required directions and actions; static art is
acceptable only for props and icons.

### Scene data flow

Scene edits remain in `data/maps/<region>/<map>.json`. Presentation-only decor
does not leak into the sim. Blocking entities and moved encounter/NPC cells
remain visible to the existing sim data contract and therefore receive route,
reachability, and save-hazard checks.

### UI and copy data flow

Bounded UI work reuses current components, anchors, and containers. Do not add
one-off absolute coordinates to solve a reusable layout defect. Player-visible
events retain their domain event and rendered-confirmation surfaces. The
terrain-expiry change preserves generic fallback copy for every non-terrain
status source.

## Verification Matrix

| Surface | Minimum evidence |
|---|---|
| Every player-visible fix | Before/after windowed screenshots read by the controller; common-sense animation/icon/sound check |
| Sprite or icon data | Godot import; `test_sprite_registry`; affected consumer tests and canonical scripts |
| Skill icons | Iconless drift allowlist shrinks; every changed hotbar/journal surface captured windowed |
| Map/entity edits | `load_gate`; all crossing QA scripts; reachability, blocking, landing, and prior-save safety checks; scene dynamism report where dressing changes materially |
| Combat presentation | Relevant combat canonical at pinned seed; windowed board read; balance harness only if combat data—not presentation identifiers—changes |
| Garden QA script | Edited canonical plus one untouched script proving harness stability |
| Slow-expiry copy | Exact unit/event assertion plus `ice_floor_loop` windowed read |
| Licensed/private asset changes | Manifest and generated ignore-block consistency; bundle recut where required; `scripts/leak_check.sh` |

The final composed gate is: load gate, full canonical QA sweep, every
`tests/test_*.gd` suite, smoke, leak check, comment census, and final windowed
reads for every affected surface. Any `SCRIPT ERROR`, parse error, or warning
is a regression. The documented post-result windowed shutdown leak is judged
only by its established result/artifact rule.

## Failure Handling

- If a generated candidate fails palette, silhouette, scale, anchor,
  animation, or semantic purpose in-scene, reject it and iterate within the
  six-candidate ceiling.
- If no generated candidate clears the bar, use the best licensed in-hand
  asset. Do not lower the bar to preserve sunk generation work.
- If a bounded fix reveals a repo-wide mechanism change, stop that arm and
  promote it with evidence; do not silently expand #113.
- If a map move breaks a canonical path, derive the new route from the real
  blocking set and verify it live rather than patching step counts by guess.
- If an entry no longer reproduces, close it only with a current screenshot
  and a trace to the mechanism or prior commit that resolved it.
- Preserve all keeper screenshots before running any script or sweep that
  would clobber their `qa_output` directory.

## Exit Criteria

- `docs/VISUAL-LOG.md` contains zero `- [ ]` entries.
- Every original entry has a documented final disposition and evidence.
- The three broad redesigns exist as dispatch-grade GitHub issues.
- Generated and selected assets are integrated through the correct public or
  private shipping path, with provenance and registry coverage.
- All targeted and composed verification is green with zero in-run warnings.
- Final windowed review finds no clipping, occlusion, palette clash,
  semantically wrong animation/icon/sound, or placeholder-grade art on the
  changed surfaces.
- `HANDOFF.md` contains only live follow-ups, taste calls, and commands.
