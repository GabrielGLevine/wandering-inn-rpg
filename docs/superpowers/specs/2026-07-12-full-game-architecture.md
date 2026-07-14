# Full-game architecture: what comes online past the demo (2026-07-12)

> Status: **ACTIVE DIRECTION**; foundation issues #99–#101 are implemented.
> The GitHub board owns remaining scheduling.

User direction: the project has been building toward a very robust DEMO;
this spec captures what expanding to the FULL GAME requires — what scales
as-is, what strains, the genuinely new workstreams, and the ordered first
moves. Companion issues: #99 (shipped-ids freeze), #100 (skeleton split),
and #101 (QA tiering), all filed the same day.

## 1. Holds at full scale — do not touch

- **The pure sim core + ObservableBus.** Injected config, event sink,
  seeded determinism. Full-game-grade now.
- **Content-as-data + the lane machine.** File-per-NPC dialogue, JSON
  quests/boards, worktree lanes + opus review + reconciliation rehearsals,
  the wi-* skill library. A full game is more cadence, not new process.
- **The validator lattice.** copy-fit / fixture-coherence / content
  cross-ref / balance harness / dynamism metric — linear, cheap, and the
  thing that keeps 10x content honest.

## 2. Strains — the architecture items

### 2.1 The shipped-ids freeze contract (URGENT AT DEMO SHIP)
Demo saves must load in the full game forever. The migration chain
(VERSION n + `_migrated`) is strong; the sharper constraint is ID
STABILITY: accomplishment counters, item ids, map keys, class/skill ids
present in ANY shipped save become permanent API. Policy: a shipped id is
never renamed or re-semanticized — only deprecated-and-mapped inside
`_migrated`. Mechanism: a freeze list (data/shipped_ids.json, generated
at each public release) + a validator arm that fails when a frozen id
disappears from its catalog without a migration mapping. The freeze list
is cut at every itch/Steam release tag.

### 2.2 Split skeleton_scene.json (the merge hotspot)
One ~13k-line file carries every map; it already serializes content lanes
(three merge hotspots this week). Target: `data/maps/<region>/<map>.json`
with a loader that composes them (preserving the current in-memory shape
so WIGame sees no difference — presentation/sim untouched). Migration is
mechanical (split + a glob loader + the validators re-pointed); the
payoff is permanent lane parallelism on content. Do it BEFORE the next
40 maps, not after.

### 2.3 QA tiering (the sweep-runtime ceiling)
98 canonicals sweep in ~10-15 min at 8 jobs; 300+ will not. Tiers:
- **smoke** (every push): load_gate + one canonical per subsystem
  (~12 scripts, <3 min).
- **full** (pre-merge/nightly): everything, sharded.
- **selective** (lane re-gates): manifest gains per-script surface tags
  (maps/fixtures/systems touched) → `ci_sweep.sh --touching <paths>`.
Balance harness likewise: shard cells, byte-identity diff per shard.

### 2.4 The counter namespace
Thousands of flat global accomplishment ids at full scale. Write down the
emerged conventions (`completed_bounty_<id>`, `serve:<entity>`,
`<region>_attuned`, quest-beat verbs) in wi-adding-dialogue-and-quests
and add a test_content prefix-discipline arm for NEW counters.

## 3. Decisions that get costlier every open week (USER)

- **Localization posture.** Strings are inline JSON; copy-fit measures
  ENGLISH pixels; cut-words-never-widen-UI collides with de/fr +30%.
  Decide: ever-localizing (→ start key-based string routing for NEW
  content now) vs firmly English-only (→ record it, keep the
  ergonomics). No default taken.
- **The demo boundary.** Exactly where the demo ends (content, level
  cap, region lock) — defines what the save-carryover contract covers,
  stops full-game work leaking into demo polish, and shapes the demo's
  ending as the full game's pitch. No default taken.

## 4. New workstreams past the demo

- **Steam SDK (#18, deferred):** achievements (map ~free onto
  accomplishments), cloud saves, Deck verification; GodotSteam = a
  native dependency changing the build/CI story. Scope when the demo
  date firms.
- **Long-arc planning:** the region/act ladder several milestones out
  (GOAL-CHAIN pattern extended); the 30-40h difficulty/economy spine —
  the economy ledger graduates from debt item to core tooling. The
  class-foundation queue (#93/#95/#96/#98) is the prerequisite: the
  game balances around Class + Skill progression (user directive).
- **Release engineering:** a `demo` release branch + hotfix flow the
  moment the demo has players; patch cadence; telemetry decision
  (even opt-in crash reporting changes the privacy story).
- **Asset pipeline automation:** bundle build+release in CI on manifest
  change; a standing art-pass cadence replacing milestone-only
  VISUAL-LOG drains.

## 5. Order of first moves

1. Shipped-ids freeze contract + validator (small; must exist before the
   first public demo save).
2. skeleton_scene split (unblocks lanes permanently).
3. QA tiering (before the sweep crosses ~20 min).
4. User decides: localization posture + the demo boundary (§3).
5. #18 Steam SDK scoping at demo-date firmness.
