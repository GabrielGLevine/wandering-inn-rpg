# Visual Next Level — strategy (user ask 2026-08-02)

The game reads "serviceable retro" rather than stunning. Diagnosis and
levers, ordered by felt-change per effort. Evidence: today's Codex/PixelLab
pipeline experiments (scratchpad codex-art/, results below) + the VISUAL-LOG
open rows + wave-2 triage's sprite-legibility findings (notes 6/12/14).

## Why it reads "serviceable"
1. **Patchwork coherence.** Four style families (PC16 backbone, CUSTOM-HD,
   ADMURIN, PIXELLAB-AI one-offs) mixed per-scene under policy but with no
   GLOBAL palette or light direction. Stunning pixel games (Sea of Stars,
   Eastward, CrossCode) run one curated palette + one lighting language.
2. **A static world.** Outside walk cycles, nothing moves: no foliage sway,
   no water animation, no torch flicker, no prop idles, no ambient
   particles. Life in pixel art is 90% motion.
3. **Flat light.** Contact shadows + a light budget exist, but no
   time-of-day grading; interiors and dusk read the same temperature.
4. **Landmark art below its narrative weight.** The ruins-is-a-rock class
   (notes 6/14, VISUAL-LOG hut row): story-critical objects rendered as
   64px squints. Sprite legibility is load-bearing by policy (name tags
   retired) — the art has to carry it and currently can't.

## The levers
1. **Palette unification pass** (highest coherence-per-effort). Map every
   shipped sheet onto one master ramp set (per-family ramp mapping, not
   naive quantize). Scriptable with PIL, verified by windowed before/after
   pairs, reversible. This alone moves "patchwork" → "one game".
2. **Time-of-day grading + light warmth.** CanvasModulate tint curves for
   day/dusk/night + warm point lights. The single cheapest mood lever in
   2D; the phase clock already exists in the sim.
3. **Motion layer.** Animated tiles (water, hearth, torches), a cheap
   vertex-sway shader on foliage, ambient particles per biome (leaves on
   the floodplains, dust motes indoors), 2-4-frame idles for hero props
   via PixelLab animate. Pairs with #335's feedback layer (action tells +
   affordance shimmer), which is visual life with gameplay teeth.
4. **THE NEW HERO-ART PIPELINE (proven today): Codex image gen →
   PixelLab /image-to-pixelart-pro.** Codex CLI has native image
   generation (feature flag stable+on). Painterly concept at 1024+ →
   pro-convert emits clean pixel art at ~160-190px logical with full
   composition fidelity — far beyond direct 64px generation. Hut + ruins
   both produced ship-grade candidates in one pass each. Use for
   landmarks, buildings, multi-cell set pieces, act cards, title art —
   integrated as a CUSTOM-HD-like family via render_scale. Pipeline
   details + traps folded into wi-art-and-sprites.
5. **Screen polish, last.** Subtle vignette, optional CRT (default off).

## Sequencing recommendation
Adopt lever 4 immediately as art practice (wave-2's art pass dogfoods it:
ruins seam sprite, rune-door, the hut). Bundle levers 1-3 as an
**Atmosphere Milestone** (v0.17 candidate alongside #335) — they are one
coherent "the world breathes" statement, and each is windowed-read
verifiable. Licensing note: gpt-image outputs are user-owned per OpenAI
terms; verify redistribution posture for the public repo before the first
shipped asset (bundle-tier until verified — two-tier policy applies).

## Experiment record (2026-08-02)
- Codex direct pixel art: good composition, pseudo-grid (needs true-pixel
  downscale; hut fine at 64, ruins muddy — grain too fine).
- Codex concept → /image-to-pixelart (standard, 64px): loses too much.
- Codex concept → /image-to-pixelart-pro: WINNER — hut 165px, ruins
  183x189px, both clean chunky pixel art, full fidelity. Gray bg needs
  keying (or request transparent concepts).
- PixelLab pixflux 64px baseline: stays the tool for SMALL props/icons.
