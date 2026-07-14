# Combat wave (#90 + #97) — plan (2026-07-12)

> Status: **DONE** — executed; retained as a design record.

Issues carry the scope; this doc pins the controller rulings, the lane
split, and the seam map (the architecture wave's lesson applied at
design time: enumerate every shared data source BEFORE dispatch).

## Pinned status semantics (#90 — ids are API the moment cwB
forward-references them)
- `burning` — end-of-turn tick on the holder (the ONE new resolver arm
  in wi_combat.gd; tick damage tuned by the lane against bands, start
  at 2). Re-application REFRESHES duration, never stacks.
- `weakened` — holder's OUTGOING damage x0.75 (round-expiring, rides
  expires_after_round).
- `guarded` — holder's INCOMING damage x0.75 (same machinery; the
  support arm's heal complement).
- `rooted` — holder's move_pool reads 0 while active; Dash refuses
  (the refusal surfaces the existing pool-empty path, no new UX).
- All four purge via `_purge_expired_statuses`; every application =
  a visible WIEffectText card (auto-generated — verify, don't assume).
- `invisible` stays un-pickable by AI (the existing flag; regression
  tooth required).

## AI arms (#90)
- `area_skill`: prefer blast/icy_floor when the ≥2-hit count (already
  computed) sees ≥2 targets.
- `support_skill`: heal/mana_shield the lowest-HP living ally
  (alive_allies_of's sort — the guard-profile precedent).
- Adoptions (data): warren caster → icy_floor; one Pallass enemy →
  flame_pillar; one guard-profile holder → heal. Every adoption
  re-runs its GATED band; a flipped pinned-RNG fixture leg re-derives
  via tests/_derive_rng_state.gd (the #83 playbook).

## Lane split + file ownership (the seam map)
- **cwA (sim+data, #90):** src/core/combat/** (resolver arm + AI
  arms), data/skills.json (applies riders on EXISTING enemy skills),
  data/combatants.json — EXISTING ids only (adoptions), harness band
  re-derives in tests/sim_combat_batch.gd (existing cells only),
  affected fixtures.
- **cwB (content, #97):** data/combatants.json — NEW ids only
  (append), data/maps/<region>/ (encounter placements — the split's
  first content payoff; regions are disjoint lane surfaces), sprites
  via the asset workflow (PixelLab v2 outputs are TIER-PUBLIC; any
  bundle-tier pack use = STOP and report for the manifest/bundle
  dance), NEW harness cells in sim_combat_batch.gd, new canonicals +
  manifest entries, docs/archive/staging/board-staging + generate_postings.py
  pool + regeneration.
- **SHARED FILES (object-level merge, controller reconciles):**
  data/combatants.json (cwA edits existing, cwB appends new),
  tests/sim_combat_batch.gd (cwA re-derives existing cells, cwB
  appends new cells), qa/manifest.json (cwB adds entries; surfaces
  re-derived by the controller at merge via derive_qa_surfaces.py).
- cwB forward-references cwA's status ids AS PINNED ABOVE when a new
  combatant carries a rider — the reconciliation rehearsal at merge
  runs a composed-tree fight exercising one cwB combatant applying one
  cwA status.

## Exit criteria
Every new/touched cell in-band (GATED where quest-grade); byte-identity
for untouched cells; the invisibility tooth; one canonical per region
proving a new encounter + its posting loop end-to-end; generator regen
diff reviewed; wiki names verified (Book-17 bar); windowed shots: an
enemy zoning the board (area arm) + one new combatant per region read
by the controller; composed gate + smoke tier.
