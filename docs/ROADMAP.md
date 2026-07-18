# Roadmap (living doc — controller-owned, updated at milestone boundaries)

## v0.10.0 — shipping now (2026-07-17)

| item | state |
|---|---|
| #152 Raskghar entry pacing (+#157 correction) | merged |
| #154 reachability validator | merged |
| #155 Wave D-1: [Mixer]→[Alchemist] + Pallass alchemists | merged (PR #159) |
| #148 thread legibility (4 tiers per ruling) | merged (PR #161) |
| #156 Wave D-2: [Beast Tamer]+[Druid], companion_source seam | merged (PR #162) |
| #160 path-diversity harness + funnel gates in CI | merged (PR #164) |
| #92 economy pass (delta-first, five slices) | lane in flight |
| Release mechanics | full rotation → user gates → freeze cut → deploy |

## v0.11.0 — SHIPPED 2026-07-18 (all targets)

- **#165 Second Wind wave** — extend every pure evolution line to ~L16
  (the #160 funnel fix, option 1 per user ruling). One late grant per
  line at the Book-17 bar; sim + path-harness re-gates.
- **#163 level-scaled Guild bounties** — rank-tiered postings
  (Bronze/Silver/Gold), scaled repeatable encounters, conditions AND
  payouts scale; payout anchors derive from #92's price ladder
  (hard dependency edge: #92 → #163). Story/boss fights never scale.
- **#142 Hedault enchanting** (rides the #92 gear-ability shapes).
- **#141 [Acolyte]/[Priest]** — lore-gated; needs canon adjudication
  before implementation.
- **#147 music sourcing** — user acquisition; integrate whatever lands.

## Parked / standing

- Three Pillars spec (approved 2026-07-04) — executes after M7 items
  above; social/combat/puzzle parity is a standing gate on every wave.
- Necromancer evolution (user-parked at Wave A).
- [Natural Allies: X] cross-class canon (parked at D-2).
- Check-roll/DC system (out of #163 v1 scope — file separately if
  skill-check scaling by thresholds proves insufficient).
- PixelLab art passes (user-gated budget): D-1 five icons, D-2 eight
  icons + pup/chick/wounded-corusdeer poses, Antinium/Drake walks.
- Renderer survey #140.

## Release discipline reminders

Freeze cut step-0: grep new `record_accomplishment` literals against
STRUCTURAL_LITERALS in BOTH lists (v0.8.0 `victories` trap; recurred at
D-2, caught in review). `tended_beasts` is already listed. Bundle-latest
check before tagging (`gh release list` on the assets repo).
