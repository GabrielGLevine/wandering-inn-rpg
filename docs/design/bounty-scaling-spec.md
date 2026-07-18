# Rank-scaled Guild bounties (#163) — spec

**Authority:** user directives 2026-07-17 (conditions AND payouts scale;
"regions already scale" corrected — nothing scales today) + the #163
issue thread (payout anchors derive from #92's price ladder). v0.11.0,
after #165. Autonomy directive applies; choices logged.

## Rank model

- Player rank derives from `WIProgression.effective_power(classes)` at
  the board interaction (read-only, no new state): **Bronze** below the
  power of a single L10 line, **Silver** below ~consolidation-tier power
  (L14 equivalent), **Gold** at or above. Exact thresholds derived at
  implementation from effective_power's own math (never hardcoded
  levels) and pinned in test_progression.
- Rank surfaces in posting copy only ("BRONZE-RANK NOTICE …") — no HUD.

## Scaled conditions + payouts (data)

- `bounties.json` records gain optional `tiers`:
  `{"silver": {"condition": {...}, "gold": N, "copy": "..."},
    "gold": {...}}` — base record IS bronze. `WIBounties.active_slate`
  resolves the player's rank tier at POST time; accepted bounties keep
  the tier they were accepted at (baseline snapshot unchanged).
- **Payout anchors, not hand gold**: each tier's gold = anchor item price
  × multiplier (crude_draught at bronze, tonic tier at silver/gold),
  resolved by the generator-style validator at test time — the data
  carries literal gold (no runtime lookup), the VALIDATOR enforces the
  anchor relation so #92 price moves fail loud here instead of silently
  drifting purchasing power.
- Monotonicity validator: same posting, higher rank never pays less;
  purchasing-power floor: top-tier combat bounty ≥ its expected
  consumable burn (2× mid-tier consumable). Can-fail proven.
- All three pillars tier (social/craft postings too) + standing orders
  scale per completion tier.

## Scaled encounters (the ONLY engine seam)

- Repeatable cull encounters (`respawns: true`) get opt-in
  `"scales": true`; at `start_combat`, enemy cfgs take bounded per-rank
  steps: Silver +25% HP +1 damage_mod, Gold +50% HP +2 damage_mod
  (constants in one place, sim-pinned). Story/boss fights NEVER scale.
- Sim: each scaled encounter × rank = a GATED cell (band 0.55-0.95
  against a rank-appropriate build). Bounded constants mean ~8 new cells,
  not a matrix explosion.

## Skill-check scaling (honest v1)

Threshold tiers on social/observation bounty conditions only (persuade 1
→ 3 → 5). No DC/roll system — if threshold scaling plays flat, a
check-roll system is its own future issue.

## Out of scope
Region scaling (authored tiers stay), non-gold currencies, bounty-board
UI rework, DC rolls.

## Verification
Registration matrix; tier resolution unit-pinned (rank boundaries, accept-
time tier lock, monotonicity + anchor validators can-fail); QA loop
`bounty_rank_loop` (fixture at Silver power: board shows silver copy,
accept → complete → silver payout; can-fail); sim cells; whole-wave
review; #154 reachability green.
