# b4 Grimalkin's study loop — design (2026-07-19, Fable; #219, SEED 6)

Pallass's first optional content. Mechanism map (ledger 2026-07-19) found
three real constraints the issue's "no new code" claim missed; this doc
adjudicates them. Grimalkin voice: the shipped exam hub (measures
everything, contempt for imprecision, pays for data).

## 1. The three mechanism adjudications

1. **`board: false` row flag** (3 lines: `board_bounties()` skips
   flagged rows + validator accepts the key). Grimalkin's contracts are
   PRIVATE study postings — they never ride Liscor's guild rotation.
   Honest deviation from the issue's "no new code"; issue comment at PR.
2. **Single-slot respect**: the accept options gate
   `requires {"board_accepted": false}` (sanctioned bool) — a held
   board posting BLOCKS enrollment, with his refusal line carrying the
   fiction: "One ledger at a time. Finish what the board holds first."
   No silent eviction.
   **Implementation correction (2026-07-19, capture run 2):** the
   board_accepted bool gate HIDES in both directions (same as Selys's
   own hub — board_loop's comments say so; the doc's "visible-locked
   tease" assumption was wrong, and no refusal line renders). The
   single-slot proof became the PAIR of exact option-array pins
   (fresh hub shows the accept entry and not the turn-in; enrolled hub
   the inverse). Also: gate composition (slot bool + caster
   accomplishment) is not expressible in one option dict — the hub
   gained ONE slot-gated entry ("About the studies.") into a `studies`
   node whose per-row options carry the accomplishment gates. All
   sanctioned singles, no whitelist change.
3. **Turn-in in HIS voice**: `WIBounties.build_turnin_graph` gains
   optional `speaker`/`copy` params (defaults preserve Selys verbatim —
   byte-identical for every existing caller; the board-picker precedent
   for parameterized builders). Grimalkin's turn-in option
   (`open_board_turnin` + a per-call voice… the effect is parameterless)
   — CUT: his turn-in option instead gates
   `requires {"accomplishment": {"accepted_bounty_grimalkin_study_combat": 1}}`
   …NOT expressible cleanly (compound unsanctioned; accepted counter
   never resets). FINAL CUT: `open_board_turnin` effect gains an
   OPTIONAL string value = the turnin VOICE key ("grimalkin"), threaded
   through `_open_board_turnin_dialogue` → `build_turnin_graph(met,
   voice)`. Value-less `true` keeps Selys. Small, honest, validator
   updated. His turn-in option is visible-gated `{board_accepted: true}`
   (bool, sanctioned alone) — if the held posting isn't his, turn_in
   fails its condition and the graph's not-done arm renders his
   "measurements incomplete" copy, which is fiction-true even for a
   foreign posting ("I did not assign you that errand. Finish it
   elsewhere."). The not-done copy covers both honestly.

## 2. The two study rows (`bounties.json`, board:false)

- `grimalkin_study_combat`: condition `{won_combat: 3}` (delta), 14g.
  Copy: field-measurement framing ("three verified engagements, logged").
  Tiers: silver 5/22g, gold 7/30g (the rank machinery rides free).
- `grimalkin_study_casting`: condition `{spell_cast: 8}` (delta), 14g,
  silver 14/22g, gold 20/30g. Requires (row-level)
  `{learned_magic_from_pisces: 1}` — casters only; the combat row is
  unconditioned.
- giver: "grimalkin"; pillar: the study rows tag the SOCIAL pillar
  (his loop is participation, not slaughter — the kills themselves
  already pay combat XP; CHOICE-LOG flag).

## 3. Hub additions (pallass_grimalkin.json)

- Accept options ×2 (visible-locked on board_accepted=false gate,
  hidden… bool gates render VISIBLE-locked — fine, the tease teaches),
  each: accept_bounty + his enrollment line (goto measure node).
- Turn-in option: `{board_accepted: true}` → effects
  `[{open_board_turnin: "grimalkin"}]`.
- Hub `text_variants`: first-completion variant keyed
  `completed_bounty_grimalkin_study_combat` OR casting (two variants,
  ordered) — "Your numbers were... adequate. The Walled Cities thank
  you for your contribution to the literature."
- All new lines: his register (imperatives, measurements, zero warmth,
  one earned dash max).

## 4. QA

- `grimalkin_study_loop` canonical (Pallass fixture, casting build):
  enroll (accept event + slot state), spell_cast delta via a staged
  fight or field casts, turn-in (gold delta + HIS voice pin in the
  turnin graph = the voice-param can-fail), hub variant pin after.
- Gate twin arm inside the same script where possible: with a board
  posting held (fixture pre-accepts one), his accept option renders
  LOCKED (bool gate) — exact-pin.
- Board-purity leg: board_loop re-run must NOT show the study rows
  (the flag's can-fail — its slate pins already do this implicitly;
  verify board_loop crosses a slate the studies would have entered).
- Selys byte-identity: board_loop + bounty_rank_loop unchanged
  (builder default-param proof).

## 5. Execution order

1. board:false filter + turnin voice param + validators + units.
2. Rows + hub + variants (voice pass).
3. Fixture + canonical + re-gates (board_loop, bounty_rank_loop).
4. Full bar → review → PR closes #219 (issue comment: the two "no new
   code" deviations, both 3-line-class, both validator-guarded).
