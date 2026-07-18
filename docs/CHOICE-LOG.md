# CHOICE LOG (controller judgment calls — user defers by standing directive 2026-07-18)

Newest first. Each entry: the call, the alternatives, why. Choices that
change shipped behavior also live in their PR bodies; this is the
cross-release index of them.

## 2026-07-18 — #163 rank-scaled Guild bounties (implementation adjudications)

- **Rank boundaries derived from effective_power, never hardcoded levels**:
  Bronze < power of a single L10 line (== 10.0 by construction); Silver <
  power of a two-L10-line build (the spec's "14-equivalent consolidation" —
  two L10 lines merge to L14 — whose UN-consolidated power is 10*2^(1/k) ≈
  15.64); Gold at/above. `WIProgression.power_rank`; both edges pinned in
  test_progression.
- **Payout anchor relation** (validator, consumes #92's ladder): silver.gold
  a multiple of crude_draught's price (the entry rung), gold.gold a multiple
  of tonic_of_the_clear_eye's price (the tonic tier); monotonic; combat
  top-tier ≥ 2× mending_draught (purchasing floor). Chose crude-for-silver /
  tonic-for-gold (both anchor items referenced, economically sane silver
  rungs) over a flat tonic-multiple-for-both (would 8× a work bounty at
  silver). All three arms + the price-move coupling proven can-fail.
- **10 postings tiered across all pillars** (fight/social/work/explore +
  standing orders); every base (bronze) record kept BYTE-IDENTICAL so every
  bronze-rank QA loop stays green — the rank register surfaces in the
  silver/gold copy overrides.
- **Only 2 encounters scaled (4 GATED cells), not 4 (8 cells)**:
  gallery_vermin_nest (T4) + forge_calibration_golem (T5) have no live QA
  loop fighting them, so scaling is regression-free. kingslayer_den /
  market_watchgolems were EVALUATED but their loops run at silver-rank
  spellsword11 fixtures that can't clear the scaled fight at the pinned seed;
  they stay unscaled until rank-aware loop fixtures land (a follow-up).
  Steps FIXED by spec (silver +25%HP/+1dmg, gold +50%HP/+2dmg), one site
  (WIBountyScaling), mirrored in start_combat + sim_combat_batch.
- **accepted_bounty_tier = one additive save field** (get-default "", no
  VERSION bump — the board fields' own precedent); the accepted tier locks at
  accept and turn-in pays it regardless of later rank shifts.

## 2026-07-18 — public-demo deploy gap (friend-playtest triage)

- **pages.yml gains a release-tag trigger** (was manual-dispatch only, an
  Actions-budget choice): the GitHub Pages demo sat at v0.7.0 while itch
  had v0.10.0, and the README points players at Pages — a playtester hit
  the 3-release-old build. One run per tag is within the budget the
  manual-only rule protected. Immediate catch-up dispatch fired.
- Friend-playtest triage: 4 issues filed (#169 web glyphs/filtering,
  #170 message pacing+scrollback, #171 onboarding affordances, #172 copy
  wave) — all folded into v0.11.0 scope per the discretionary-work goal.

## 2026-07-18 — v0.11.0 Second Wind spec adjudications (#165)

- **beast_master's attested pick [Lesser Bond] rejected on id collision**
  (shipped as the tamer's L3 tame verb; shipped ids never rename) — the
  researcher's Redfang-voiced ⚑ORIGINAL fallback [Sworn Fang: Ride
  Together] ships instead.
- **[Server's Prescience] goes to BARMAID** (Drassi's attestation is
  barmaid-line inn work); server takes ⚑ORIGINAL [Swift Service] — one
  attested name cannot serve two sibling lines.
- **D-1's "Xif skills are dialogue color only" fence RELAXED** for earned
  late grants: [Perfect Reduction] becomes the alchemist L14 bench-cast
  (crude → tonic). Shared skill names across holders are canon-normal;
  the fence protected D-1 scope, not exclusivity.
- **One grant per line at L14, L15/16 rows empty**: the funnel fix is the
  LEVELS (stat growth), not kit inflation; second grant tier deferred to
  demand.
- v0.10.0 shipped on the autonomy directive with #167 fixes, no re-gate.

## 2026-07-18 — v0.10.0 gate fixes (#167) and ship ruling

- **Ship v0.10.0 after #167 fixes without a further user playtest** — USER
  DIRECTIVE (not a controller choice; recorded for the timeline).
- **Raskghar arc gets a real journal quest (`something_beneath`)** rather
  than a longer-lived toast or forced-modal: quests are the game's durable
  direction surface; every side errand already had one and the main spine
  did not. Toast stays as the nudge. Mid-arc saves backfilled at load.
- **Pantry-door legibility fixed with gated copy on the DOOR itself**
  (observe override + interact-toast variants + one window-gated Erin
  follow-up option) rather than new markers/UI: keeps the no-floating-
  markers rule; the door is the natural place players re-check.
- **Garden pre-unlock cell: entity absent via `present_when` + cell
  unblocked** — user directive; wall-dressing (#151) retired. The at:0
  hidden visual_state left in place as redundant belt-and-braces.
- **`gate` added to street LANDMARK_TOKENS** instead of bending Zevara's
  copy toward "market": the gate IS her canonical post and existing copy
  already says "at the gate" throughout.
- **Wounded corusdeer: strengthened tint only** (0.6/0.52/0.47); the real
  fix (lying pose) stays PixelLab/user-gated per the art budget.

## 2026-07-17 — v0.10.0 wave calls (index of PR-recorded choices)

- Erin's VERBAL garden reveal masked in real play — accepted; the door's
  earned-appearance is the signpost (PR #161).
- [Spellsword] funnel root-caused to table ceilings; fix = extend pure
  lines (#165, user-ratified option 1); merge-formula surgery rejected.
- Kingslayer boss drop is accessory-only (respawning bounty = farm risk);
  crude_draught price stays 4 (validator-consistent, churn not worth it)
  (PR #166).
- Room purchases live on their own register surface, never on pinned
  dialogue hubs (PR #166 incident writeup).
- Bounty payout scaling (#163) anchors to the economy price ladder, not
  hand-tuned gold — hard dependency edge #92 → #163.
