# Roadmap (living doc — controller-owned, updated at milestone boundaries)

## Shipped (compressed ledger; per-issue detail in merged PR bodies)

- **v0.15 (merged, UNTAGGED) — 2026-07-28, Legibility & Life.** Five
  phases, PRs #310-#314, all `[ci-full]` green. A
  **delivery-layer / population / readability** triad: (1) the
  DELIVERY LAYER — 18 authored act-beat openings so every pending beat
  reads as a forward ask instead of a spoiled outcome, a Leads strip at
  every mainline seam, and a lossless lore queue with its own journal
  Lore tab (#310); (2) VIEWPORTS — the combat feed, journal rows and
  sleep veil re-budgeted so panels stop eating their last line, plus
  endings acknowledgment (#311); (3) guest ARC-WINDOWS (`GUEST_POOL_GATES`
  takes an ANY-of Array, windows derived from pool gate AND rows so the
  two cannot disagree) + a hygiene batch — dead fixture keys, the
  variant guard, `{addr}`/arrival lint arms, the em-dash sweep, the
  golem name split (#312); (4) the POPULATION pass — Pallass, Invrisil
  and the dig camp given working inhabitants and regional work props
  (#313); (5) READABILITY — arena scale/tint, rigs and per-map
  `lights_by_day` (#314). Four ENGINE wins came out of it, each worth
  more than its phase: the toast drain **defers** on an open modal
  (queue pauses, never drops), the dialogue fail-safe **nulls its
  walker** (one trip used to softlock movement, interact, inventory,
  journal and pause permanently), the lore queue is **lossless**, and
  the combat board got a **measured figure bar** — floor 1.25 cells /
  ceiling 3.55, with one stated measurement rule (`idle_side`, that
  animation's own sheet, alpha bbox height) after round 1's unstated
  rule let the bar pass subjects that were failing it. The shipped
  roster had never been computed: it spanned **20x**, 0.38 to 7.62
  cells. 28 new counters, ALL data-derived — zero new bare code
  literals, so the freeze cut is a regen with no hand-add (contrast
  v0.14's `finale_played`). The tag cut is user-gated.
- **v0.14 (merged, UNTAGGED) — 2026-07-27, the Main Quest wave.** The
  story line restructured end to end across nine phases: acts I–V
  reframed off the "post-game" framing, Act IV opening on the seal
  (#291); "The Dig" — the Horns door-retrieval quest backported to
  day one with the Liscor link (#297); the ordered
  Riverfarm→Invrisil→Pallass pilgrimage spine, Act V's three-path
  conclusion and the finale sequence that retires the epilogue (#299);
  a difficulty ladder stepping each pilgrimage stop one band above the
  last (#300). Friends of the Inn closed out with it: PR2a Olesm+Pisces
  (#293), PR2b Relc+Zevara (#294), roster to ten with four quest-gated
  guests — Klbkch, Rags, Wilovan, Grimalkin (#295). Ships #269 and the
  Act V arm of #270 (its Pallass-return B-side not taken, so
  `pallass_return_carved` never existed). 21 new counters derive from
  data; `finale_played` is the one bare code literal the freeze cut
  must hand-add. The tag cut itself is user-gated.
- **v0.13.0 — 2026-07-20, the Depth + Polish wave.** Project RENAMED
  ("Wandering Inn RPG") with verified save carry-over (#111, both
  rehearsals passed). #209 journal tabs, #247 Friends of the Inn
  pilot (Selys+Krshia servable guests), #225 interior floors, #123
  honest canonicals, and the complete art wave: #198 scroll split +
  repo-wide placement sweep, #222 stalls/benches/statue, #224 batch B,
  #210 bespoke Erin (canon Earth clothes), #223 rigs (Rags, Ceria with
  real cast frames, Ruin Warden combat rig), pantry-door consolidation
  (`skill_uses` multi-skill arms) + the dusty scroll's earned decipher.
  647 ids frozen.
- **v0.12.x — 2026-07-18/19.** God-file dissections (#194), #211
  challenge-weighted leveling (flag-on), b-wave content (Grimalkin
  studies, Rags meeting #199, parleys, Ratici's fence, fragment trade,
  Invrisil aftermath, ruin stone, ack wave), a-wave UX (boss music,
  auto-slot, Import/Export save, day pacing, dark-field legibility,
  credits/volume, tap-aim), mobile hotfixes.
- **v0.8.0–v0.11.x — 2026-07-15→18.** Chronicle, pickers, footsteps,
  economy pass (#92), rank-tiered bounties (#163), Second Wind grants
  (#165), Hedault enchanting (#142), class Waves A–D2, path-diversity
  harness, release automation. Earlier: git history.

## Now (2026-07-28): v0.15 in, v0.16 SPECCED not executed

The Main Quest plays start→finale and now READS while it plays — v0.15
closed the legibility gap the line had. Agent-actionable work is the
v0.15 follow-up batch (HANDOFF is the authority for both queues), then
v0.16 from its spec. User-held: **the tag cut (v0.14 and v0.15 are both
merged and untagged)**; the six-ask Playtest-State bundle at the top of
docs/VISUAL-LOG.md; web/#195 audio listen → wiring pass; #211 leveling
FEEL; 3 Rags reads; windup-overlay + rock-crab visual/band verdicts;
lore rulings #134 (Wave D classes) / #141 ([Priest]); user-deferred
#253 (mobile import picker); flake #140; #19 Steam HOLD.
(Two v0.14 user-gated items are now CLOSED by v0.15: the arc-window
guest-gate call shipped in P3, and Grimalkin's sprite re-measure was
REFUTED on measurement in P5 — the logged "2.3x Relc" was frame height,
his figure is 1.25x, exactly canon.)

## Next milestone: v0.16 Region Depth — SPECCED, NOT EXECUTED

The spec and its issues already exist; the next session implements from
them rather than re-designing:
`docs/design/2026-07-28-v0.16-region-depth-spec.md` + issues
**#305-#308**. Nothing in that spec has been built.

## Later candidates (pick on user word)

Note (user-corrected 2026-07-20): **Three Pillars already EXECUTED** —
not as a named milestone but distributed across the waves (38 field
skills + the overworld hotbar, Helper/Tactician first-class curves,
8 social canonicals, 46 puzzle-surface scripts; "talk/help/fight all
real" is the shipped doctrine every wave is held to). It stays a
STANDING GATE, not a future item.

1. **Audio wave** (#195 after the user listen + the deferred #76
   remainder): boss/biome coverage from the Ove Melaa pack.
2. **#253 mobile import fix** (fix candidates already in the issue) +
   a mobile-polish slice if playtests surface more.
3. **Wave D classes** (#134, after lore rulings) + #141.

(#269 FotI PR2 and #270's door continuation were the old 1 + 4 — both
shipped inside the v0.14 wave above, so the story-spine slot is empty
until the next big rock is picked.)

Recommendation: 1 whenever the listen lands; the wave's own follow-up
batch (HANDOFF) clears first either way.

## Parked / standing

- Necromancer evolution (user-parked at Wave A).
- [Natural Allies: X] cross-class canon (parked at D-2).
- Check-roll/DC system (file separately if threshold scaling proves
  insufficient).
- Renderer survey #140; Steam (#19, M-STEAM) on standing HOLD.
- PixelLab budget: ~$2.7 overage credits; icon backfills (D-1/D-2
  icons, [Flame Pillar] iconless) are cheap one-call items when wanted.

## Release discipline reminders

Freeze cut step-0: bump RELEASE in generate_shipped_ids.py, regen,
commit BEFORE the tag; grep new `record_accomplishment` literals
against STRUCTURAL_LITERALS in BOTH lists (the v0.8.0 `victories`
trap). **v0.15's inventory is already walked** — 28 accomplishment
adds, 0 removals in any of the five id classes, and the literal grep
came back IDENTICAL to v0.14.0, so this cut is a clean regen with no
hand-add (numbers in the v0.15 wave-close PR body). Bundle-latest check before tagging (`gh release list` on the
assets repo — prereleases never win Latest). Rename-era note: any
future config/name change repeats the #111 carry-over pattern
(WISaveMigration + the legacy_seed canonical are the template).
