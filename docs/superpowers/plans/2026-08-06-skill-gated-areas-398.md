# Skill-Gated Areas wave-1 — implementation plan (issue #398)

> Status: ACTIVE. Spec (design authority):
> `docs/superpowers/specs/2026-08-05-skill-gated-areas-design.md` (merged
> onto this branch from `spec/skill-gated-areas`). Where this plan and the
> spec disagree, the spec's §5/§10 (deltas + kill criteria) win; execution
> briefs may correct stale plan text — briefs win over both.

**Branch:** `issue/398-skill-gated-areas` off main. **MERGE-ORDER
CONSTRAINT:** PR #402 (the #397 prose pass) touches the same five maps'
prose fields and merges FIRST; this branch merges main in after #402
lands and BEFORE any content lane dispatches (Phase 1 gate). Phase 0 +
art are disjoint from #402 and start immediately.

## Lane map + file ownership

- **Lane 0 (Phase 0, engine + registry — dispatch NOW):** D1 `cuts`
  property (skills.json field-tags on [Power Strike]/[Piercing Strikes];
  `cuts × cuttable → remove` rows in interactions.json — APPENDED, row
  order is load-bearing per test_interactions_table; reuse the
  remove_scorch outcome shape, sibling verb ONLY if toast/counter
  semantics diverge — K2), D5 `skill_gates` registry + the five lint arms
  (spec §3, arm 5 advisory; K4: no allowlist ever), D3 blink-over-water
  proof leg (zero-code expected; if LoS disagrees, STOP — finding goes
  back to the spec, not into engine edits), D4 M-ENDURE only if it is a
  one-arm diff in the interact path (cut first under pressure — spec
  ruling 5), [Flame Jet] `burns: true` (ruling 4). Owns: skills.json,
  interactions.json, data_lint.py + its self-tests, src/core only-if-D4,
  tests/{test_interactions_table,test_traversal_seams,+new}.gd. K1 gate:
  untouched traversal canonicals byte-identical (run the shipped
  freeze/burn/blink canonicals before + after, diff the event streams).
- **Lane A (art — dispatch NOW):** briar-wall blocking prop, distinct
  silhouette (never a tinted bush; tint-is-not-disambiguation), pack-first
  then PixelLab ($0.46 balance, ~$0.012/gen measured); P1 cache prop art
  if no pack region reads as a weather-sealed cache. Owns: assets/,
  sprites.json (anchored append), test_sprite_registry rows, ATTRIBUTION.
- **Phase 1 (AFTER #402 merges + Lane 0 lands + merged into branch):**
  five content lanes, one per pocket, maps fully disjoint:
  - **P1 floodplains** (pond island: island cells + cache + pond_guardian
    encounter; modes freezes / blink-r2 — the D3 proof leg becomes this
    lane's canonical).
  - **P2 sewers/deep_tunnels** (collapsed gallery: rubble + beam + tarred
    timber props; modes durable_picks / greater_strength / burns; distinct
    counters broke_through vs burned_through).
  - **P3 dungeon/trapped_halls** (warded vault: snare + pry + optional
    endure; vault loot + construct encounter).
  - **P4 invrisil/mercantile_alleys** (counting-room: M-SOCIAL dialogue
    option — the mandated social mode — + sneak timing + barred rear door
    banking noisy_entry with factor dialogue reaction).
  - **P5 ruin_surface** (briar arch: burns / cuts — first consumer of D1
    + Lane A's sprite).
  Shared files are INTEGRATOR-OWNED with anchored appends: items.json
  (each lane a NAMED loot row), combatants.json + sim_combat_batch.gd
  (each lane its own encounter block + cells, banded +2..4 per
  wi-adding-an-encounter), qa/manifest.json (append last under lane
  marker). Each lane: mode-A leg, mode-B leg (different build fixture),
  negative leg (refusal toast + reward unreachable), per spec §7.
  Dialogue for P4 lives in a mercantile/factor graph — P4 owns it alone.
- **Phase 2 (close):** reviews (adversarial, per lane) → fix waves →
  train (anchored) → composed gates → machine playtest (windowed: briar
  wall, island, vault, counting-room, arch) → §9 rulings copied into
  CHOICE-LOG → freeze-adjacent checks (new counters ride the next release
  cut) → wave-2 follow-ups filed (riverfarm pockets; lockpick canon-check
  ACK item) → PR w/ [ci-full], closes #398.

## Standing constraints (from the 390/396/397 session — briefs carry these)
- Census at the 15.0% DATA ceiling: every `_comment` paid for by a trim.
- Prose rules: new player-visible copy follows the narrator bible's
  functional register (plain, ≤2 sentences, zero closers) — #397's gates
  read these maps; hint/refusal toasts are functional register.
- No ui_entities_rendered sprite-count pins; destination asserts on any
  dialogue selection (cursor wraps); dialogue event order
  dialogue_started → dialogue_node → ui_dialogue_shown.
- Windowed runs serial; alarm-wrap godot DIRECTLY (never run_qa.sh);
  zsh does not word-split; read every verdict from its own rc.
- Sprite-key blast radius: any sprite repoint needs a consumer audit.

## Delegation (user directive 2026-08-06: leverage Codex)
Per wi-delegating-to-codex: **Codex (gpt-5.6-sol) implements Lane 0 and
the Phase-1 content lanes; controller verifies, reviews, merges.** Every
Codex brief carries numbered acceptance criteria + prove-it-can-fail
steps + "list every criterion you did NOT meet". Art stays Claude-side
(PixelLab MCP). Worktree discipline: nobody edits a worktree while a
Codex job runs in it — art gets its own worktree/branch.
