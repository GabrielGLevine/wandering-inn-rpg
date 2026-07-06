# Consultant prompt — M6 spec + plan adversarial review

(Repo access: read access to GitHub `main`. This review targets a milestone that will be
EXECUTED AUTONOMOUSLY — the user is unavailable for its playtest, and project leadership
hands from Fable to Opus mid-execution window. Your review is the last human-adjacent
gate before autonomous execution, so weight "will an executor without design judgment go
wrong here" above stylistic concerns.)

You are an external senior game-systems consultant. You reviewed this project's M5 spec
earlier (your findings: `docs/superpowers/consultant/2026-07-02-m5-spec-review.md`) —
all were accepted. This is the NEXT milestone: the game's identity system.

## Read, in order
1. `docs/superpowers/specs/2026-07-02-wandering-inn-m6-action-classes-design.md` — SPEC UNDER REVIEW
2. `docs/superpowers/plans/2026-07-02-wandering-inn-m6-action-classes.md` — its plan (review both)
3. `docs/superpowers/specs/2026-07-02-progression-vision-action-driven-classes.md` — the user's vision + locked decisions (AUTHORITY: the spec must not contradict this)
4. `docs/superpowers/specs/2026-07-02-m6-canon-class-taxonomy.md` — canon research the spec builds on
5. `wandering_inn_game_v4/CLAUDE.md` — architecture/QA conventions (binding)
6. Code as needed: `src/core/progression.gd`, `src/core/wi_game.gd` (sleep/resolve_combat), `src/core/combat/wi_combat.gd`, `data/classes.json`, `tests/sim_combat_batch.gd`

## Review targets
1. **Contradictions** — spec vs vision doc's locked decisions; spec vs taxonomy; spec vs
   plan; plan task boundaries vs the actual file layout.
2. **The math** (spec §2.4–2.5): w(L)=L^k split-friction — is "harness tunes k to hit
   20–25%" actually achievable with one scalar, or does the power gap depend on WHERE
   stats enter combat (hit/damage/HP) such that no single k lands the band? Consolidation
   ceil(0.67×sum): check edge cases (8+8? 12+12? does the merged level ever DROP below
   max(parents)? is that acceptable per canon/vision?). Trigger predicate (both ≥8,
   sum ≥18) — reachable in the stated demo band (~W10-12/M8-10 focused, ~7/7 split)?
   If a split build reaches 7/7 max, consolidation NEVER triggers — is that intended
   tension or a design hole? BE SPECIFIC about which numbers need what changes.
3. **The counter economy** (§2.1–2.2): liveness rule gameability (3-round stalling?),
   counter volumes vs demo content (errand + 3–4 fights + chores — enough melee_hit
   events to reach Warrior 10–12? sanity-check against a real fight's event counts if
   you can run one), the mid-fight-tally→bank-at-resolve design vs defeat (all counters
   lost on defeat — harsh with the defeat-reload flow? intended?).
4. **Evolution UX under opaque-until-sleep** (§2.3): dominance ≥60% + min-uses — can a
   player understand WHY they didn't evolve with zero progress feedback? Is the
   off-interval fallback (evolve later when dominance emerges) coherent with "10-cap
   consumed" bookkeeping? Find the state-machine holes.
5. **Migration** (plan T9): fighter→warrior rename — enumerate what breaks that the plan
   misses (saves, dialogue requires, QA scripts, combatants.json PC template, display
   strings, the M4.1 Lyonette content that reworked fighter gates...).
6. **Autonomous-execution risk**: which plan task would a competent-but-judgment-free
   executor most plausibly botch, and what one paragraph of added specificity would
   prevent it?

## Output format
- Verdict: sound / needs revision (+ blocking list)
- Findings by severity with spec/plan section refs + concrete failure scenarios
- The single highest-risk assumption in the whole design, and how you'd de-risk it cheaply
- Anything missing that autonomous execution will need

Be blunt. Wrong-but-specific beats vague-but-safe.
