# Task SOCIAL-2: relationship progression (LINEAR stages) — Social Pillar II (ASSEMBLY task)

## Goal
NPCs visibly EVOLVE through ordered stages (the Lyonette-thaw model
generalized): per-NPC ordered stage lists that swap talk pools, unlock
deeper dialogue topics, and land ONE final-stage perk in visible
currencies. NO points, meters, hearts, or numbers — the NPC just changes.
THE COPY IS ALREADY WRITTEN, VOICE-LINTED, AND CANON-CHECKED — assemble it
verbatim; do not rewrite it (the G2 assembly precedent).

## Single source of content
`/Users/gabriel/wandering_inn_rpg/docs/archive/staging/social-2-staging/`:
- `stage-tables.md` — the master per-NPC tables (conditions, pools,
  unlocks, perks) + the machinery note + the ⚑ roll-up. READ IT FIRST.
- `{erin,relc,krshia,selys,pisces,olesm,zevara}_stages.json` — real
  talk_pool_stages / dialogue-option shapes, parse-clean. Lift VERBATIM;
  strip the `staging_note`/`_flag`/`_comment*` annotation keys (controller
  notes, not content).
- One `.md` voice/canon companion per NPC (register rails + hard canon
  rails — e.g. Pisces' forbidden list; read before touching that NPC).
- `lyonette_stages.md` — the retrofit note (rename, not rewrite).
Staging report (shape decisions + canon findings):
`.superpowers/sdd/fp-handoff/task-social2-staging-report.md`.

## Spec text (verbatim core, `docs/superpowers/specs/2026-07-06-social-pillar-2-design.md`)
- Each arc NPC has 2-3 ORDERED STAGES ... A stage advances when its
  specific, authored condition is met — a milestone, not a meter ...
  Conditions are existing counters read as simple thresholds/flags — the
  talk_pool_post gate machinery generalized to a per-NPC ordered stage list.
- Per stage: the talk_pool swaps, 1-2 dialogue options unlock (deeper
  topics), and the FINAL stage grants one small mechanical perk in visible
  currencies ...
- NEVER shown as numbers/bars/hearts. The NPC just changes.
- No decay, no points, no gift-scoring.
Non-goals v1: approval meters/points; romance; companion recruitment;
warmth decay; faction reputation; >3 stages per NPC.
QA (spec §2): one `stages_loop` canonical driving one NPC base→final +
stage-derivation units (pure, the acts precedent).

## THE ⚑ RULE: the 18 flags SHIP OPEN
Implement exactly the staged DEFAULTS; every ⚑ stays an open user flag
(one HANDOFF entry each, with the staged recommendation — check HANDOFF's
"RESOLVED" blocks first so you don't re-flag anything already ruled):
- Conditions (6): ship the staged `chatted_with_* ≥ N` AND-legs as written.
- Perks (8): ship spec defaults where staged as authorable; Relc = status
  quo (his spar already re-offers — the wager refinement stays flagged,
  unbuilt); Pisces has NO spec default — build NOTHING, flag the proposal;
  Lyonette ships PERK-LESS (her optional rest stays flagged, unbuilt).
- Canon reveals (4): the OBLIQUE versions are what's staged — ship those;
  every warmer variant is OFF by default (Relc's "family thing" stays out —
  Embria is a hard V5 canon rail; Krshia never says "spellbook"; Pisces'
  hard rails are absolute; Zevara names no Eresc/Antinium).

## Execution phases (LINEAR — each phase independently green before the next)

### Phase A: the seam + the Lyonette retrofit (reference implementation)
- New data shape `talk_pool_stages`: ORDERED array of
  `{id, requires_accomplishment, lines}`, LAST met entry wins (ascending
  authoring — the visual_states/classes.json level-table convention).
  Conditions evaluate through the shipped multi-key AND gate
  (`_accomplishment_gate_met` — it lived in `wi_game.gd`; the ARCH-4
  extraction may have moved social logic into a WISocial sub-sim: GREP for
  the function, do not trust old line numbers).
- Lyonette's shipped `talk_pool_post` is a one-entry instance: retrofit =
  express her thaw in the new shape, ZERO copy changes, generalize the C4
  unit test. Keep `talk_pool_post` reading working OR migrate her data —
  implementer's call, disclosed; other NPCs' shipped `talk_pool`s are
  stage-1 as-is (no data change for stage 1, per the tables).
- Units: stage derivation is pure — unmet → base, first met → stage 2,
  both met → last-wins, unordered authoring rejected or normalized
  (disclose which).

### Phase B: assemble the 5 already-pooled NPCs (Krshia, Selys, Pisces, Olesm, Zevara)
- Their `chatted_with_<id>` counters accrue TODAY (pools shipped) — stages
  go live the moment the seam lands. Lift `talk_pool_stages` + the
  `dialogue_unlocks` (hub options + nodes) verbatim into the NPC data /
  `data/dialogue/*.json` files each staging JSON names.
- New counters (each banked on the option that reads it, effects on
  OPTIONS never nodes — house shape): `heard_krshia_plans`,
  `claimed_bounty_{crate,cisterns,warren}` (Zevara's perk), optional ones
  only if their flagged features ship (they don't, v1).
- **Zevara's perk (watch-bounty access) is authorable now** — pure
  `requires`/`hide_when` dialogue shapes, drafted in `zevara_stages.json`.
- **Krshia's perk (shop −1..2g) is authorable now BUT is the pin hazard of
  the whole task:** stage-gated duplicate buy options at the lower price +
  `hide_when`-retired full-price rows SHIFT VISIBLE OPTION INDICES.
  `economy_loop`, `d2_shop_shot`, `crate_light` (and anything else — grep
  `qa/scripts/` for the shop/charms node option texts) pin exact
  size-exact option arrays. The staged discount is gated on
  `chatted_with_krshia: 4` + `crate_returned` — verify NO canonical script
  ever reaches that state (they almost certainly don't; prove it, don't
  assume it) so the shipped pins hold; the discount then only needs NEW
  coverage in `stages_loop`. Disclose the analysis either way.

### Phase C: the Erin/Relc pool landing + re-path wave (THE cost item — own controller loop)
- Erin and Relc have NO shipped pools (S2 deferral); every
  `chatted_with_erin`/`chatted_with_relc` condition is dead until their
  pools land. The authored copy is preserved VERBATIM in
  `.superpowers/sdd/fp-handoff/task-s2-social-report.md`
  §"Dropped-but-authored" — lift it, do not rewrite it.
- S2 measured the blast radius: **~28 canonical reds (Erin 12, Relc 22).**
  ENUMERATE FIRST: grep `qa/scripts/` for every script whose first
  Erin/Relc talk of a waking will now absorb a pool `dialogue_line`. The
  S4 re-path idiom fixes each: an added `wait_for_event dialogue_line`
  (payload_contains the speaker/text) + a SECOND `interact` for the real
  graph. Where a script's re-path is heavy, consider converting it to a
  fixture start instead (FIXTURE-FIRST is now ratified policy) — disclose
  per script.
- Run this as its own wave with its own full-sweep gate. If budget dies
  here, phases A+B+D still shipped coherently (Erin/Relc stage rows stay
  dormant data — harmless, disclosed).
- Then assemble Erin/Relc stage tables (verbatim from staging).

### Phase D: the per-waking perk seam + Erin's meal
- ONE small seam, built once: per-waking dedup on a dialogue surface via
  `entity_first_use` verb-prefix (the S3 idiom that gates [Observe]/
  [Charming Smile]). Erin's daily meal (spec default: small HP restore,
  "sit, I'm testing a recipe" — copy staged) is its v1 consumer. Relc
  wager / Pisces drill / Lyonette rest DO NOT ship (flags, above) but the
  seam is deliberately shaped so they're pure data later.
- Selys' perk ("first pick at the board"): staged v1 = a one-time vetted
  job pointer (gold on completion) via a stage-gated option — IF M-DEPTH
  DP2's board exists by execution time, prefer wiring the pointer at the
  board surface (check the ledger); otherwise ship the staged dialogue
  shape. Olesm's chess perk: the option + frame node ship (staged); the
  match copy itself is flagged as its own follow-up writing task — do not
  improvise the chess scene.

### QA (with phase B, extended in C)
- `stages_loop` canonical, FIXTURE-FIRST: fixture pre-banks all-but-one
  condition leg for ONE NPC (Krshia is the cheapest live choice:
  `crate_returned: 1, chatted_with_krshia: 3`), then the run banks the
  last leg for real (one first-talk-of-waking), proves the pool SWAP
  (exact staged line), the unlocked hub option (present after, and
  `assert_event_absent`-style proof it was absent before — options are
  VISIBLE lists, mind the index math), and the perk surface. Register per
  rail 3 below. Stage-derivation units ride Phase A.

## Binding constraints
- Copy verbatim from staging (voice-linted + canon-checked; the hard
  canon rails in the companions are ABSOLUTE). Strip annotations.
- OPACITY: no numbers/bars/hearts anywhere; progress must never leak
  (unlocked options are hidden-until-met via `requires`, the M4 gating
  split; a locked deeper topic is INVISIBLE, not greyed).
- Visible currencies only in perks (gold, HP, a meal — never a stat).
- Zero-warning; GDQuest style for any code; sim purity (stage derivation
  is pure state reading).

## Successor safety rails (spelled out — do not skip)
1. **Ledger first:** `tail -40 .superpowers/sdd/progress.md` — confirm
   where the K-wave ended and whether anything social-adjacent moved.
2. **Exact-pin discipline:** grep `qa/scripts/`, `qa/fixtures/`, `tests/`
   for every option text / option array / toast / counter you touch;
   update pins in the SAME edit; report every pin old → new. Dialogue
   option indices are the classic trap (visible lists shift when options
   hide/appear).
3. **Registration conditional on ARCH-1:** if
   `wandering_inn_game/qa/manifest.json` exists it is the single source of
   truth for script → seed → fixture — register `stages_loop` there per
   its convention; else BOTH `wandering_inn_game/CLAUDE.md` lists AND
   `qa/ci_sweep.sh`'s CANON, counts bumped everywhere. Count, never trust
   a hardcoded number.
4. **Alarm-wrap every run** (failed asserts HANG godot forever; macOS has
   no `timeout`): `perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot …`;
   kill >2min runs and read partial output.
5. **Zero-warning grep** on every run: `SCRIPT ERROR|Parse Error|WARNING`;
   never `^PASS` alone.
6. **Windowed shots READ by eyes** (the stage-2 pool line + an unlocked
   topic on screen); `qa_output/<script>/` clobbers per re-run — copy
   PNGs out immediately.
7. **Voice lint anything you are forced to compose** (connective option
   labels etc. — should be nearly nothing): banned-tell list in
   `.claude/skills/wi-adding-dialogue-and-quests/SKILL.md`, register per
   `docs/design/character-profiles.md`. Staged copy is already linted —
   keep it byte-true through assembly.
8. **Worktree-merge intersection rule:** file-map intersection vs
   `git status` AND live-lane reports before any copy-merge; re-gate the
   MERGED tree; in doubt serialize. Phase C's wide script edits make this
   task a serialize-by-default candidate.
9. **NO-COMMIT implementers;** controller stages the explicit paths each
   lane reports; never `git add -A` while a lane is live.
10. **CLAUDE.md sections by NAME** (slimmed); per-script routing detail may
    live in `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` if it exists —
    put the re-path notes where the existing per-script notes live.

## Verification (FOREGROUND, alarm-wrapped, sequential — never background
## a run and wait; notifications cannot reach you)
Per phase: load_gate + smoke → the touched units individually (grep
discipline) → the touched canonicals at pinned seeds → full
`bash wandering_inn_game/qa/ci_sweep.sh` before calling the phase green.
Phase C's gate is the FULL sweep by definition (that's what it re-paths).
Windowed `stages_loop` at close: the swapped pool line + the unlocked
topic; PNGs to
`/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/social2-shots/`,
READ them.

## Report contract
- NO commit, NO git add. Full report per phase (or one cumulative) to
  `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/task-social2-report.md`:
  files touched, the seam shape as landed, the Lyonette retrofit diff
  summary, the Krshia-discount pin analysis, the Phase-C red set
  (enumerated → re-pathed/fixture-converted, per script), every pin moved,
  the 18-flag HANDOFF entries written, gate tables, shot names.
- Return only: status, one-line test summary, concerns.
