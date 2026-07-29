# Roadmap (living doc — controller-owned, updated at milestone boundaries)

## Shipped (compressed ledger; per-issue detail in merged PR bodies)

- **v0.16.1 — 2026-07-29, the playtest wave.** All 26 findings from the
  user's full sitting, same session as receipt, three PRs (#327-#329):
  ONE toast spec (housekeeping class, per-dequeue cap, ×1.5 hold,
  combat band closed, veil line — closes GH#325), [Light] as a toggle,
  the field readout's own composer, combat-beat audio on the playback
  clock, state-owned defeat music, biome-voice decoupling, the
  brew-and-sell economy exploit closed with yarrow-gated brewing (+ a
  hidden counter exploit found under it), the Hunter ruled a game
  hunter, mill-ramp entrance, the alley mouth as a real wall break,
  the fence fight's missing resolution beat, Cups gated, mothbears
  re-homed to the road, blade banding, pot tints, the Coyle sign — and
  the ART wave: bespoke Lady/Hedault/Coyle rigs + two shared civilian
  rigs + the sign for $0.26, with a pc_* sprite ban enforced by a
  mutation-proven registry gate.
- **v0.16.0 — 2026-07-28, Region Depth.** One session end-to-end
  (recon → 4 per-region plans → adversarial plan-verify, 42 findings
  fixed pre-dispatch → 20-agent lane fleet → anchored merge-train →
  close). Seven side quests with three-pillar parity (two each for
  Riverfarm/Invrisil/Pallass + the Floodplains slice), seven walk-in
  interiors, the game's FIRST goblin-ally fight (betrayal branch got
  its first live QA coverage), the Invrisil NOBILITY layer (the Lady,
  Reinhart ambients; full thread = #318), four bespoke camp sprites,
  the forge-hall board-fight debt closed, seven leads rows. 778 ids
  frozen — after the freeze pre-walk caught generate_shipped_ids
  missing `skill_uses` producers (patched before regen; zero removals,
  zero hand-adds).
- **v0.15.0 — tagged 2026-07-28, Legibility & Life.** Delivery layer
  (18 act-beat openings, Leads strip, lossless Lore tab), viewports +
  endings acknowledgment, guest arc-windows + hygiene, the population
  pass, readability (measured figure bar 1.25–3.55 cells; the shipped
  roster had spanned 20x). 697 ids frozen.
- **v0.14.0 — tagged 2026-07-28, the Main Quest wave.** Acts I–V off
  the "post-game" framing, "The Dig" backport, the pilgrimage spine,
  Act V's three-path seal conclusion + finale, FotI roster to ten,
  the difficulty ladder. 669 ids frozen (`finale_played` hand-add).
- **v0.13.0 — 2026-07-20, Depth + Polish.** The RENAME with verified
  save carry-over (#111), journal tabs, FotI pilot, interior floors,
  honest canonicals, the full art wave. 647 ids.
- **v0.12.x — 2026-07-18/19.** God-file dissections, challenge-weighted
  leveling, b-wave content, a-wave UX, mobile hotfixes.
- **v0.8.0–v0.11.x — 2026-07-15→18.** Chronicle, pickers, economy pass,
  rank-tiered bounties, Second Wind, Hedault enchanting, class Waves
  A–D2, release automation. Earlier: git history.

## Now (2026-07-29): four releases in two days; the board is clean

v0.14.0 → v0.16.1 all tagged with green Release/Pages runs. The Main
Quest plays start→finale, reads while it plays, and every region on the
map now holds real side content. The user's first full sitting produced
26 findings and all 26 shipped. Open board: 11 issues, every one either
scheduled (v0.17 candidates), user-gated, or a documented flake/hold.

**User-held:** the gossip-ladder scaling adjudication (the one item from
the sitting only the user can close — numbers in CHOICE-LOG's v0.16
close block); the remaining full-sitting states on the new build; #195
audio listen; #134 Wave-D lore ruling (absorbs #141); #253 stays
user-deferred; #19 Steam HOLD; #140 flake reference.

## Next milestone: v0.17 — pick on user word

Candidates, in rough value order:

1. **#318 Invrisil nobility thread** (Magnolia-adjacent, spec-first —
   her voice bar is the highest in the game; the v0.16 ambient layer is
   the down payment).
2. **#330 Beast Tamer dynamism + the no-treadmill audit** (the
   principle — "actions never exist solely to level a class" — is now
   law in wi-adding-a-class-or-skill; the audit will likely spawn
   follow-ups).
3. **Audio wave** (#195 after the user listen + boss/biome coverage).
4. **#323 dead inn_settled lines re-gate** (small, scoped).
5. **#134 Wave D classes** (after the lore ruling).
6. **#324 world_ready dead-render window** (global engine bug; needs a
   systematic-debugging session; on fix, the rendered-vs-seen caveat
   comes out of two skills).
7. **#253 mobile import** if the user un-defers.

Loose singles that ride any wave: #283 (vacuous portal gate
adjudication), the Krshia bespoke rig (owed from the art wave), the
VISUAL-LOG residuals (five art debts + the v0.16 close P3s).

## Parked / standing

- Three Pillars: EXECUTED and a STANDING GATE (every wave held to
  "talk/help/fight all real"), not a future item.
- Necromancer evolution (user-parked at Wave A); [Natural Allies: X]
  (parked at D-2); check-roll/DC system (file if threshold scaling
  proves insufficient).
- #280 scored FEEL bench: CLOSED not-planned; revival criteria in
  docs/design/2026-07-26-dev-arch-eval-275-280.md.
- PixelLab budget: ~$2.30 credits. Icon backfills stay cheap one-call
  items when wanted.

## Release discipline reminders

Freeze cut step-0: bump RELEASE in generate_shipped_ids.py, regen,
commit BEFORE the tag; grep new `record_accomplishment` literals
against STRUCTURAL_LITERALS in BOTH lists. **Producer-schema parity
(v0.16 lesson):** the generator and test_content must agree on what
counts as a producer — dry-run the walk and reconcile its ADD list
against the wave's planned counters before every regen; a new producer
schema lands in BOTH files in one commit. Bundle-latest check before
tagging. Merges: read the checks table as its OWN step first —
owner-auth merges bypass required checks (enforce_admins off). Any
future config/name change repeats the #111 carry-over pattern.
