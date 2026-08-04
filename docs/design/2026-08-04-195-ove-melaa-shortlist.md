# Audio shortlist — 149 candidates vs 45 shipped anchors

Source: `docs/design/audio-profiles.csv`. Regenerate: `python3 scripts/audio_shortlist.py docs/design/audio-profiles.csv`.

## Anchor calibration

- shipped music (40): energy min 0.119 / median 0.295 / max 0.392
- shipped music: centroid min 459.200 / median 1892.450 / max 3062.300
- shipped music: onset density min 0.072 / median 0.172 / max 0.333
- shipped ambience (5): rms min 0.050 / median 0.060 / max 0.109
- shipped ambience: onset density min 0.185 / median 0.332 / max 0.598

## Census

- stingers (<=3 s): 109
- jingles (3-10 s): 13
- 10-60 s: 17
- long (>60 s): 10

### Menu / title candidates (11 qualify)

- `Ove Melaa - Times` — 137.2 s, 76 BPM, rms 0.362, 857 Hz, onset 0.110 (1.35/s), major, energy 0.290
- `Ove Melaa - Psycho Behind The Keys` — 61.0 s, 123 BPM, rms 0.221, 316 Hz, onset 0.130 (0.31/s), minor, energy 0.273
- `Ove Melaa - High Stakes,Low Chances` — 106.0 s, 112 BPM, rms 0.163, 2312 Hz, onset 0.144 (4.67/s), minor, energy 0.237
- `Ove Melaa - Super Ninja Assasin` — 42.2 s, 92 BPM, rms 0.278, 2890 Hz, onset 0.164 (3.72/s), minor, energy 0.281
- `Ove Melaa - Italo Unlimited` — 65.7 s, 118 BPM, rms 0.381, 3538 Hz, onset 0.165 (7.10/s), major, energy 0.357
- _...6 more in the CSV_

### Jingles — major (success / level-up class) (4 qualify)

- `84` — 3.8 s, 144 BPM, rms 0.357, 2482 Hz, onset 0.129 (2.34/s), major, energy 0.361
- `42` — 5.9 s, 123 BPM, rms 0.260, 1533 Hz, onset 0.570 (4.25/s), major, energy 0.424
- `43` — 5.9 s, 83 BPM, rms 0.212, 1943 Hz, onset 0.066 (1.02/s), major, energy 0.209
- `108` — 5.5 s, 89 BPM, rms 0.110, 159 Hz, onset 0.088 (2.38/s), major, energy 0.171

### Jingles — minor (failure / night class) (9 qualify)

- `86` — 3.7 s, 136 BPM, rms 0.430, 1200 Hz, onset 0.264 (0.27/s), minor, energy 0.430
- `51` — 4.4 s, 129 BPM, rms 0.417, 1844 Hz, onset 0.500 (1.82/s), minor, energy 0.488
- `102` — 7.3 s, 99 BPM, rms 0.350, 3250 Hz, onset 0.084 (2.18/s), minor, energy 0.300
- `83` — 3.0 s, 152 BPM, rms 0.291, 2384 Hz, onset 0.122 (1.66/s), minor, energy 0.334
- `Ove Melaa - DrumLoop 1` — 8.6 s, 112 BPM, rms 0.268, 2365 Hz, onset 0.172 (3.94/s), minor, energy 0.298
- _...4 more in the CSV_

### Stingers — impact (<1500 Hz) (47 qualify)

- `110` — 0.6 s, 144 BPM, rms 0.595, 595 Hz, onset 0.318 (9.85/s), major, energy 0.536
- `111` — 0.6 s, 123 BPM, rms 0.497, 572 Hz, onset 0.318 (8.21/s), minor, energy 0.467
- `38` — 0.8 s, 118 BPM, rms 0.482, 1448 Hz, onset 0.313 (6.45/s), minor, energy 0.452
- `109` — 0.6 s, 118 BPM, rms 0.424, 327 Hz, onset 0.050 (1.64/s), minor, energy 0.344
- `47` — 1.4 s, 199 BPM, rms 0.334, 1199 Hz, onset 0.197 (3.54/s), minor, energy 0.425
- _...42 more in the CSV_

### Stingers — ui-foley (1500-3500 Hz) (48 qualify)

- `50` — 0.4 s, 136 BPM, rms 0.417, 2192 Hz, onset 0.159 (2.73/s), minor, energy 0.392
- `36` — 1.5 s, 136 BPM, rms 0.411, 3189 Hz, onset 0.319 (5.82/s), minor, energy 0.438
- `12` — 0.9 s, 136 BPM, rms 0.408, 2909 Hz, onset 0.295 (13.38/s), major, energy 0.429
- `09` — 0.6 s, 235 BPM, rms 0.393, 1810 Hz, onset 0.137 (3.12/s), minor, energy 0.472
- `37` — 0.8 s, 215 BPM, rms 0.380, 1725 Hz, onset 0.083 (1.29/s), minor, energy 0.430
- _...43 more in the CSV_

### Stingers — shimmer / magic (>3500 Hz) (14 qualify)

- `85` — 1.9 s, 129 BPM, rms 0.525, 3953 Hz, onset 0.279 (2.08/s), major, energy 0.475
- `14` — 1.3 s, 123 BPM, rms 0.222, 4355 Hz, onset 0.144 (0.79/s), major, energy 0.277
- `15` — 0.8 s, 215 BPM, rms 0.202, 3868 Hz, onset 0.115 (1.19/s), major, energy 0.351
- `53` — 0.6 s, 123 BPM, rms 0.179, 3808 Hz, onset 0.354 (8.47/s), major, energy 0.319
- `54` — 1.0 s, 123 BPM, rms 0.176, 3786 Hz, onset 0.300 (14.11/s), minor, energy 0.301
- _...9 more in the CSV_

_Bed thresholds from the shipped ambience: rms <= 0.109, onset density <= 0.598._

### Ambient bed candidates (1 qualify)

- `105` — 92.9 s, 129 BPM, rms 0.017, 118 Hz, onset 0.097 (2.01/s), minor, energy 0.167

## Listening queue (27 files)

 1. [menu] potential_assets/EssentialGameAudiopackFixed/FullScores/Orchestral Scores/Ove Melaa - Times.mp3
 2. [menu] potential_assets/EssentialGameAudiopackFixed/FullScores/Orchestral Scores/Ambient Style/Ove Melaa - Psycho Behind The Keys.mp3
 3. [menu] potential_assets/EssentialGameAudiopackFixed/FullScores/Retro Scores/Ove Melaa - High Stakes,Low Chances.mp3
 4. [jingle-major] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/84.ogg
 5. [jingle-major] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/42.ogg
 6. [jingle-major] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/43.ogg
 7. [jingle-major] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/108.ogg
 8. [jingle-minor] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/86.ogg
 9. [jingle-minor] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/51.ogg
10. [jingle-minor] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/102.ogg
11. [jingle-minor] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/83.ogg
12. [stinger-impact] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/110.ogg
13. [stinger-impact] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/111.ogg
14. [stinger-impact] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/38.ogg
15. [stinger-impact] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/109.ogg
16. [stinger-impact] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/47.ogg
17. [stinger-uifoley] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/50.ogg
18. [stinger-uifoley] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/36.ogg
19. [stinger-uifoley] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/12.ogg
20. [stinger-uifoley] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/09.ogg
21. [stinger-uifoley] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/37.ogg
22. [stinger-shimmer] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/85.ogg
23. [stinger-shimmer] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/14.ogg
24. [stinger-shimmer] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/15.ogg
25. [stinger-shimmer] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/53.ogg
26. [stinger-shimmer] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/54.ogg
27. [bed] potential_assets/EssentialGameAudiopackFixed/Sound Effects/AbstractPackSFX/Files/AbstractSfx/105.ogg

_staged 27 files to potential_assets/_listen_195_
