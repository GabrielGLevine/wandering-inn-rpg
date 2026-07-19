# b9 audio — #200 boss re-pick (shipped) + #195 Ove Melaa shortlists (listen-gated)

Method: the #147 signal pass — librosa tempo / RMS(p95) / spectral
centroid / onset density / chroma-mode over every candidate, calibrated
against the 40 shipped music anchors. Energy score =
0.5·rms95 + 0.3·onset + 0.2·(tempo/200). Profiles for all 149 pack
files + 40 shipped tracks archived with the session; regenerate with
the script in the PR body (pure librosa, ~2 min).

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
