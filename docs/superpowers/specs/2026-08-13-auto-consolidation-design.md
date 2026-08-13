# Auto-consolidation — design (#472, user-ruled 2026-08-13)

> Status: **RULED (user)** on the WHAT; this spec pins the HOW. The two
> starred defaults (§3 chaining stand-in level, §4 once-per-sleep) are
> controller design calls under wave autonomy — implemented unless the
> user objects on #472.

## 0. The ruling

No player choice: consolidation fires automatically when qualified.
Binding constraints: (1) it never removes existing Skills (upgrades
allowed); (2) advancement paths for consolidated classes stay open —
a [Spellsword] (warrior×mage) can still level toward the warrior×
ice_mage target by meeting the ice_mage requirements.

## 1. Trigger and beat order

Consolidation resolves inside the sleep beat, after level-ups, exactly
where today's OFFER fired — but it now APPLIES instead of prompting.
The sleep beat's order becomes: level-ups → (at most one)
consolidation → ALL normal sleep banks (door_study_sleeps etc.) →
veil/announcement render. This fixes the #472 preemption half by
construction: the beat never returns early, so gating banks and a
consolidation land in the SAME sleep.

Player communication without choice: the sleep veil gains a
consolidation line (same voice as the current accept copy — "[X] and
[Y] merge into [Z]!"), plus a journal entry. The modal prompt UI and
`decline_consolidation()` are DELETED, `pending_consolidation` retires
(save migration arm bumps the version; fixture coherence drops states
that hold it).

## 2. The no-Skill-loss guarantee (static, lint-enforced)

The guarantee lives in DATA, checked at commit time — not a runtime
carry-over fold. New data_lint arm: for every consolidation row, for
every qualifying parent level pair (min_parent/min_combined up to the
parents' table maxes), the union of both parents' granted skill ids at
those levels must be covered by the target at its derived floor —
where "covered" means the same skill id via `inherits`, an own-table
grant, or a registered UPGRADE mapping (`upgrades: {old_id: new_id}`
on the target row; the [Skill] the player sees is strictly better —
same shape as the flavored-twin rule, and the upgrade pair is
validated to be cost/effect-dominant). [Spellspear]'s shipped inherits
already satisfies this shape; the arm's first run inventories any
existing gap the same way #454's validator did (gap → _exempt is NOT
allowed here — a coverage gap is a hard red, because it is player-
visible Skill loss).

## 3. Lineage credit — consolidated classes as line proxies

`check_consolidation` extension: a held consolidated class SATISFIES
either of its own `parent_lines` sides when another row asks for that
line. ★Default: the proxy stands in at the CONSOLIDATED class's
current level (not the consumed parent's frozen level) — the class
kept climbing, the lineage climbed with it. So [Spellsword] 16 +
ice_mage 10 qualifies a warrior-line × ice_mage row; the second
consolidation consumes [Spellsword] + ice_mage into the new target
per the standard rules (no-Skill-loss arm applies transitively, so
chained targets must cover the chain's union — the lint walks chains).
First-match ordering still governs (the #449 order pin generalizes:
narrower/evolved rows sit above the rows they carve out of — the
scaffolder checklist already carries this).

## 4. Cadence

★At most ONE consolidation per sleep. If a second row qualifies, it
fires at the next sleep. Rationale: veil readability, pin stability,
and it keeps the fixpoint trivially terminating (each firing strictly
reduces held-class count by one).

## 5. Blast radius

- `wi_game.gd`/`sleep_beat.gd`: prompt path deleted; apply path moved
  in-beat; once-per-sleep guard.
- `progression.gd`: proxy rule in `check_consolidation`; upgrade-map
  support in grant resolution if not already shaped.
- Save: `pending_consolidation` removed, migration arm.
- Canonicals: `spellspear_consolidation_loop` repinned (prompt steps →
  veil-line + journal asserts; the opaque-until-sleep lock stays — it
  is about WHEN resolution happens, unchanged); any fixture holding
  `pending_consolidation` migrates; steel thread unaffected (never
  qualifies — Lane D proved mage 8 < 10).
- Sims: none — consolidation timing does not change fight math; the
  spine roster reads `consolidations[]` which is unchanged in shape
  (plus optional `upgrades` key, ignored by the roster).
- #472 closes on this shipping.

## 6. Verification plan

Unit: beat-order (banks land in the consolidation sleep — the #472
regression), once-per-sleep, proxy qualification both directions,
upgrade-dominance validation, migration arm. Lint: coverage arm red on
a synthetic gap + on a synthetic non-dominant upgrade (both
gate-can-fail proofs). Canonical: repinned loop x2 + a chained-
consolidation loop once target B exists (the [Wild Sage]/[Skirmisher]
additions are natural test partners). Full sweep + preflight.
