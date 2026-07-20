# Roadmap (living doc — controller-owned, updated at milestone boundaries)

## Shipped (compressed ledger; per-issue detail in merged PR bodies)

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

## Now (2026-07-20): board fully user-gated

Nothing agent-actionable is open. User-held queue (HANDOFF taste
queue is the authority): web/#195 audio listen → wiring pass; #211
leveling FEEL; 3 Rags reads; windup-overlay + rock-crab visual/band
verdicts; lore rulings #134 (Wave D classes) / #141 ([Priest]);
user-deferred #253 (mobile import picker); flake #140; #19 Steam HOLD.

## Next milestone candidates (v0.14 — pick on user word)

Note (user-corrected 2026-07-20): **Three Pillars already EXECUTED** —
not as a named milestone but distributed across the waves (38 field
skills + the overworld hotbar, Helper/Tactician first-class curves,
8 social canonicals, 46 puzzle-surface scripts; "talk/help/fight all
real" is the shipped doctrine every wave is held to). It stays a
STANDING GATE, not a future item.

1. **Friends of the Inn PR2+** (#247 follow-through): the remaining
   four guests (Olesm/Pisces/Relc/Zevara), one pair per PR; consider
   phase-gating guest serves to evening (the Helper-pace flag from
   PR #261's review).
2. **Audio wave** (#195 after the user listen + the deferred #76
   remainder): boss/biome coverage from the Ove Melaa pack.
3. **#253 mobile import fix** (fix candidates already in the issue) +
   a mobile-polish slice if playtests surface more.
4. **Door-chain continuation** (content): door_awakened → the next
   story beat; the scroll_secret thread now points at it naturally.
5. **Wave D classes** (#134, after lore rulings) + #141.

Recommendation: 1 + 4 as the v0.14 core (follow-through + the story
spine), 2 riding whenever the listen lands.

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
trap). Bundle-latest check before tagging (`gh release list` on the
assets repo — prereleases never win Latest). Rename-era note: any
future config/name change repeats the #111 carry-over pattern
(WISaveMigration + the legacy_seed canonical are the template).
