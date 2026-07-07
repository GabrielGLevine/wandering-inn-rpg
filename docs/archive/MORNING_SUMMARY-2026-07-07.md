# Morning Summary — night of 2026-07-07 (Fable autonomous run)

**Four chain milestones moved in one night, all opus-gated, all synced,
public CI green throughout.** GOAL-CHAIN steps 3-6 are closed; step 7
(M-DEPTH) is 5/6 tasks in with DP5 finishing now. 56 canonicals (46 at
the night's start); zero red sweeps ever committed.

## Closed tonight (each opus/review-gated)

1. **Architecture track (consultant adoption, your hybrid ratification)**
   - CLAUDE.md slimmed 1667→421 lines (−75%); detail lives in
     `wandering_inn_game/docs/QA-SCRIPT-NOTES.md` + `ARCHITECTURE-HISTORY.md`;
     all 8 binding-stale audit findings fixed; top-level worktree rule updated.
   - **qa/manifest.json = the single source of truth** — ci_sweep parses
     it and drift-checks the CLAUDE.md table every run (break-tested).
   - **Mirror drift-bombs defused**: `WICombatBuild` shared pure home —
     the balance harness measures the shipped game BY CONSTRUCTION
     (byte-diff proof); `_bb_escape` unified into UIChrome.
   - **WIKeys const catalog** across src/core hot paths.
   - **THE wi_game EXTRACTION**: WIEconomy / WISocial / WIFieldSkills as
     injected pure sub-sims (2122→1876 lines); save shape byte-unchanged
     (serialize-diff proof); opus READY, its one fix-first applied (the
     gold-before-GOLD_CHANGED invariant).

2. **Skills wave (chain step 5) — opus READY TO SHIP**
   - K2 sneak state; K2b your slotted loadout (AUTO byte-parity proven);
     K3 canon names ([Snap Freeze], [Firefly], [Appraise Foe] —
     [Owl's Vision] checked and REJECTED: canon function is night-vision,
     not a person-read) + **the [Rogue] class** (earned via the crate
     WATCH path, circularity trap avoided); K4 ghost-skill wiring
     ([Second Wind] heals for real, move-pool passives live; icy_floor
     honestly queued with its [Ice Floor] cite).
   - The first BINDING machine-playtest rotation caught a systemic panel
     z-order class that 50 green sweeps missed — fixed (toasts above
     modals, echo reserved-height, barks clear on transitions).

3. **Social Pillar II (chain step 6) — opus READY, 0 blockers**
   - LINEAR stages on ALL 7 pooled NPCs — **Erin and Relc finally in**
     (21 scripts / 29 insertion points re-pathed, zero parks; the two
     tutorial routes hand-verified first). Stage-gated topics; earned
     perks (Krshia discount, Zevara bounty pointer, Selys board pick);
     the one sanctioned {gold, accomplishment} compound gate.
   - 18 ⚑ copy flags OPEN for your pass (HANDOFF SOCIAL-2 section).

4. **M-DEPTH (chain step 7) — DP1-DP4 committed, DP5 landing**
   - **DP1** Adventurer's Guild interior (Selys at the desk; review
     caught Renn fully occluded behind Ilvo — fixed + re-shot).
   - **DP2 THE REQUEST BOARD** — rotating zero-rng bounty slate,
     delta-since-accept (no pre-grind exploit), accept/turn-in/ABANDON
     at Selys. Review caught a HIGH: one-shot bounties could permanently
     soft-lock the board — fixed both ways (absolute-mode + abandon).
   - **DP3** inn upstairs + YOUR OWN BED. **DP4** Watch barracks
     (Sgt. Dresk Ashgrave, the dressed cell, Zevara's desk) + 2 stalls.
   - **DP5** (Runner's Guild + deliveries, Vess at the counter) survived
     an API-error kill mid-edit, resumed losslessly, finishing now.
     **DPF** (opus + rotation + close) is the remaining gate.

5. **Your directives landed same-session**
   - "No Killing Goblins" sign (canon wording ch. 1.18) + Relc's
     roof/road line (⚑ trimmed to fit) + Erin's "Sign stays up." variant;
     goblins_spared + the Rags arc seeded.
   - GDI copy applied verbatim as approved (the cold open, the
     ledger-voiced epilogue, the wasp-against-glass refusal).

## Your 5 playtest notes — triage (one already hotfixed)
1. **Field-skill legend clutter** → fix wave queued. Recommendation:
   REMOVE the always-on panel (the journal's loadout UI already carries
   the info); hold-key peek optional.
2. **Bottom-justified text in toasts/buttons** → systemic UIChrome
   vertical-alignment audit, same wave (title buttons = the exemplar).
3. **Relc suddenly tiny in combat** → static trace didn't land it
   (combat_scale applies once; frames uniform 124px) — empirical
   beat-by-beat repro lane queued.
4. **Lyonette tint + inn sprite variety** → PixelLab bespoke wave queued
   (red-HAIR Lyonette per canon; inn cast variety; park-only then wire).
5. **Lyonette dialogue bug** → two real defects found, one FIXED NOW:
   *"A princess who cannot count a grocery list"* was a canon IDENTITY
   LEAK — rewritten to *"I was raised to run a household larger than
   this inn, and I cannot count a grocery list."* (committed, pin moved,
   green). Her first bark also truncates mid-punchline ("...you may have
   it for…") — the 2-line bark budget rides the queued wave.

## ⚑ Queue (most consequential first)
- **v0.3.0 auto-tag: NOT taken.** M-DEPTH is mid-milestone and your
  playtest notes arrived — recommend tagging after DPF + the
  playtest-note wave. Everything committed is green.
- Social II: 18 copy flags + the CHESS unfulfilled-promise thread
  (Olesm/Erin pitch an unplayable match) + Krshia's discount going
  mechanically live before her grant line.
- Relc's trimmed sign line (vs the seed's exact copy).
- Skills-wave checklist: sneak feel, [Rogue] earn, loadout UX (AUTO
  blank markers), rename taste, [Second Wind] slot value.
- M-GEAR carryovers: gambeson 20g price; barracks "stern" grade subtlety.
- Queued honest debts: icy_floor + [Invisibility] (cited); Erin's meal
  perk + Relc's spar wager (need a per-waking dialogue seam);
  bounty_crab_cull (needs an encounter bank).

## Playtest checklists ready in HANDOFF
M-LEGIBILITY · M-GEAR · Skills wave · Social II (M-DEPTH's at DPF).

## Three most valuable next actions
1. **Close M-DEPTH** (DP5 loop → DPF opus + rotation) — then the v0.3.0
   tag question is live.
2. **The playtest-note wave** (your items 1-4 + the bark budget).
3. **Your taste passes** — everything ships flags-open by design; your
   pass converts them.

## Process notes
- Two API-error lane kills, both recovered losslessly by transcript
  resume. Four verification stalls; the STOP-WAITING jolt is 4-for-4.
- New institutional lessons (all in the skill library): the STOP-gate
  rule, fixture-first policy, the worktree merge-intersection rule, and
  the machine-playtest protocol — binding at every close, and it has
  caught real player-visible bugs at every single rotation so far.
