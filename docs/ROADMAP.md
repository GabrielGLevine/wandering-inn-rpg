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

## Now (2026-08-02): wave-2 in flight; three directions spec'd

#330 shipped (2026-07-29). A friend's 28-note playtest triaged same-day
(11 investigators) → CHOICE-LOG rulings → the wave-2 fleet is running
(sim + content lanes, #334; seam PR #340 merged). The user's three
strategic directions each landed a committed spec: skill cooldowns
(#337), Skills-tab redesign (#336), quest clarity (#338); plus the
feedback-layer issue (#335), tripwires parking lot (#339), and the
visual next-level strategy doc. NEW ART DOCTRINE: Codex concept →
PixelLab image-to-pixelart-pro (hero art, proven; six candidates
banked) and tint-is-not-disambiguation (user directive).

**User-held:** gossip-ladder scaling adjudication; the full-sitting
states; wave-2 ear-gate (Raskghar swap) + Pisces three-Horn deviation
ack; #195 audio listen; #134 Wave-D lore ruling; #253 user-deferred;
#19 HOLD; #140 flake reference.

## v0.17 plan (RATIFIED 2026-08-02, refactored HIGHLY PARALLEL per user
directive): six concurrent lanes, exclusive file ownership, one anchored
merge train, one release. Sequencing exists ONLY inside a lane where a
shared file forces it — no cross-lane waits.

**L1 — Journal/UI** (owns journal.gd, wi_game.gd UI-producer region
[_skill_entries/quest_summary siblings], quests.gd, settings_panel.gd +
wi_settings.gd, quests.json hint fields, their QA pins): #336 Skills-tab
redesign + AUTO 9-cap, THEN #338 quest-hints slice (same files — one
implementer, two slices).

**L2 — Combat/Dynamism** (owns wi_combat.gd, combat_ai.gd,
combat_hud.gd, combat_screen.gd, skills.json, the balance-cell bands,
test_combat_sim/test_combat_data/test_effect_text): #337 cooldowns per
spec — AI fall-through first, surgical set, full 141-cell re-author,
badge/tooltip UI. No other lane touches combat or balance data.

**L3 — Presentation/Feel** (owns message_layer.gd, world.gd, WIAmbience,
new shader/particle resources, audio.json, the acted-on data_lint
advisory): #324 dead-render root-cause FIRST (its fix unblocks bark
reliability), then #335 feedback layer phase 1 (action tell, affordance,
audio gap rows), then the Atmosphere presentation half — time-of-day
grading + motion layer. One lane because world.gd/message_layer are one
ownership zone; internally sequenced, externally parallel to everything.

**L4 — Art** (owns assets/**, sprites.json, map decor/visual rows):
VISUAL-LOG drain + tint-site audit (cauldron/hut/ruins/rune-door/
wardstone candidates banked) THEN the palette-unification pass over the
drained base. Hero-art pipeline per wi-art-and-sprites.

**L5 — Content riders** (owns dialogue data, dens/companion data +
the one companion code literal — declared exception, no L3 overlap):
#323 dead inn_settled re-gate + #332 companion dead-end.

**L6 — Docs/causality** (owns docs/): the story causality map,
agent-drafted → hand-verified → wired into wi-adding-dialogue-and-quests.

Merge-train notes: standard-setter rule applies (L3's new lint runs
against every sibling branch pre-merge); L2's re-authored bands are the
only balance authority — no sibling may touch combatants/arenas; L4
palette lands its sheet rewrites LAST in the train so every windowed
re-read happens once, on the composed tree.

v0.18 candidates: REMOVED from consideration (user directive
2026-08-02). #318/#134/#195 stay parked on the board behind their
existing gates; the roadmap plans nothing beyond v0.17.

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
