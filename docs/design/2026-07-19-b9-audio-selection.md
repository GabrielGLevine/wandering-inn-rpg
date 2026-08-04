# b9 audio — #200 boss re-pick (shipped) + #195 Ove Melaa shortlists (REJECTED at the ear-gate)

> **VERDICT (2026-08-04, user ear-gate): the Ove Melaa pack is out.**
> Nothing in the 27-file listening queue was worth wiring — not the
> menu scores, not the jingles, not any stinger cluster, not the bed.
> #195 closed on that judgement. **Do not re-profile or re-shortlist
> this pack.** The signal pass says only what a file measures, not
> whether it sounds like this game; the whole pack failing the ear
> after passing the numbers is the point. Anything below is retained
> as method, not as candidates.

Method: the #147 signal pass — librosa tempo / RMS(p95) / spectral
centroid / onset density / chroma-mode over every candidate, calibrated
against the 40 shipped music anchors. Energy score =
0.5·rms95 + 0.3·onset + 0.2·(tempo/200). Profiles for all 149 pack
files + 40 shipped tracks archived with the session; regenerate with
the script in the PR body (pure librosa, ~2 min).

> **CORRECTION (2026-08-04, #195).** The script was never in PR #244's
> body, and the profiles were archived with a session that is gone — so
> nothing below could be re-derived. The pass is now committed:
> `scripts/audio_profile.py` (measurement) and
> `scripts/audio_shortlist.py` (slot rules), with the full 194-file
> table at `docs/design/audio-profiles.csv` and the regenerated report
> at `docs/design/2026-08-04-195-ove-melaa-shortlist.md`. Read those as
> current; the numbers in this file are the 2026-07-19 originals, kept
> for the audit trail. Reproduction results in "What re-ran" below.

## #200 — deep_warren (Awakened Raskghar) re-pick: SHIPPED

The report holds in the numbers: `battle_the_final_of_the_fantasy`
ranks 7th/11 of the Battles bundle on energy (0.357) with the muddiest
centroid of the set (1845 Hz) and low onset density (0.22) — a mid
fight reading as a lull at the game's boss beat.

Pick: **battle_for_despair** — the bundle's top energy (0.418),
highest onset density (0.335), 152 BPM, bright 2655 Hz. The name fits
the warren. It was serving `trapped_halls_snare` (a trap-ambush
skirmish), which INHERITS `battle_the_final_of_the_fantasy` in the
swap — the moody low-centroid track fits a dark-corridor snare fight
better than a boss. Two-line swap in audio.json; event ids unchanged;
zero QA pins on either stream (verified: no script or suite references
either filename or the two `music_combat_*` ids).

EAR-GATE (taste queue): load the deep-descent playtest state and pull
the boss — say the word if despair reads wrong and the runner-up wires
instead: `battle_for_humanity` (0.407, 172 BPM — currently forge_hall).

## #195 — Ove Melaa shortlists (wire AFTER the user listen, per issue)

Census: 149 files → 110 stingers (≤3 s), 12 jingles (3–10 s), 11
loops, 9 full scores, 7 longer SFX. Attribution already cleared
(Credits + ATTRIBUTION.md, #147).

- **Menu / title candidates** (scores, ≤125 BPM, low onset, ≥40 s):
  1. `Orchestral/Times` (76 BPM, onset 0.12, warm 922 Hz — the
     strongest title-screen signal in the pack)
  2. `Orchestral/Heaven Sings` (123 BPM, 267 s — long-form menu bed)
  3. `Retro/Dark.ogg` (123 BPM, low RMS — a darker alternate)
- **Jingles** (AbstractSfx, 3–6 s): 33 (major — level-up/success
  class), 84 (major), 59/86/51 (minor — failure/night class),
  106/108/41 (minor, longer — quest-beat class).
- **Stingers** (110, clustered by centroid):
  - impact (<1500 Hz, 47): top rms 110/111/38/109 — hit/door-slam
    class; candidates for combat crunch and heavy interacts.
  - ui-foley (1500–3500 Hz, 49): 50/36/12/09/37 — clicks, pickups,
    page turns.
  - shimmer-magic (>3500 Hz, 14): 85 (loud), 14/15/53/54/52 — casts,
    wards, portal touches.
- **Ambient beds**: nothing qualifies at bed thresholds (the loops are
  drum-forward). Two exceptions worth the listen: `Dark Loop` (low
  RMS, 3 min — a dungeon tension bed candidate) and `Tube Ambient
  Loop` (601 Hz, dark drone — sewers/deep candidate despite hot RMS;
  would need volume_db trim).
- Not shortlisted: the Supa Powa / Snus / Trance loops (bright
  drum-machine character — off the game's acoustic register; listen
  only if a jingle-adjacent arcade moment ever needs them).

LISTENING QUEUE (user): the 3 menu candidates, 8 jingles, ~16 flagged
stingers, 2 bed exceptions — ~30 files, ordered above. Survivors wire
into audio.json slot-by-slot as small PRs.

## What re-ran (2026-08-04)

194 files profiled, 0 decode failures. Tempo, RMS p95 and spectral
centroid reproduce the 2026-07-19 numbers exactly (`battle_for_despair`
152 BPM / 2654.7 Hz / rms 0.3315 against the reported 152 / 2655 /
0.331 back-solved from its energy). Onset density does NOT: the
original normalization was never written down and no candidate
(mean/max, mean/p95, mean/p99, onsets/sec) reproduces both reported
values. The committed script pins it as **mean onset strength / its own
p99** — p99 rather than max so one stray transient cannot crush a
four-minute score. Energy scores therefore shift slightly; every claim
below was re-checked against the new numbers rather than assumed.

**Holds.** All three stinger clusters reproduce file-for-file in the
same order — impact 110/111/38/109, ui-foley 50/36/12/09/37, shimmer
85/14/15/53/54. `Times` is still the top menu signal (76 BPM, onset
0.110, the pack's warmest score). `battle_the_final_of_the_fantasy` is
still the muddiest of the Battles bundle at 1845 Hz, and still bottom
half on energy — the #200 rationale stands.

**Shifts.** `battle_for_despair` is 2nd on energy (0.385), not 1st;
`battle_for_nothing` tops the bundle (0.392, onset 0.237) under the
pinned metric. The gap is inside the metric's own uncertainty and
despair's other reasons (2655 Hz brightness, the name against the
warren) are unaffected — the shipped pick is not disturbed, but the
"top energy" wording above was overstated. Menu 2nd/3rd change hands:
`Heaven Sings` is busier than reported (onset 0.286) and drops behind
`Psycho Behind The Keys` (316 Hz, 61 s) and `High Stakes, Low Chances`.
Jingle mode calls moved at the boundaries — `33` reads minor and is
3.09 s (a stinger, not a jingle); `108` reads major.

**Two things the original missed.** `105` (92.9 s, rms 0.017, 118 Hz
drone) is the one file in the pack that clears the shipped-ambience bed
thresholds outright — the original concluded nothing qualified, and its
two hand-picked exceptions are worse: `Tube Ambient Loop` is 23 s and
hot (rms 0.444, onset 0.472), and **`Dark Loop` is byte-identical to
`Retro Scores/Dark.ogg`** — it was shortlisted twice as two candidates.
The pack is 142 unique tracks across 149 files: the whole
`AbstractPackSFX/BONUS` directory duplicates `Loops/`, and the Dark
pair spans FullScores and Loops. Dedupe before wiring.
