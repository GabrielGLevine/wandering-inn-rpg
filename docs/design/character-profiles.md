# Character Visual + Voice Profiles (single source of truth)

Adapted from Claude-Code-Game-Studios' entity-registry/asset-spec idea
(github.com/Donchitos/Claude-Code-Game-Studios), fitted to this repo:
ONE profile per character; every sprite-generation prompt AND every
dialogue/pool/observe line derives from it. Wiki-verify before adding;
cite. **A generation or writing task that contradicts a profile is a
defect** (this file would have prevented the Lyonette blonde-vs-RED
miss, C2 2026-07-06).

Format: species/build · palette+silhouette (the 3 features a 64px
sprite MUST carry) · voice register (the 3 notes every line must hit) ·
canon cites · current sprite state.

## Relc Grasstongue
- Drake [Spearmaster]/Senior Guardsman; HUGE (8ft), broad.
- Teal-green scales, spear, Watch harness; reads big even contained
  (combat_scale 0.4).
- Voice: loud, cocky, friendly-menacing; bored by paperwork; genuinely
  kind under it. Wiki: Relc Grasstongue.
- Sprite: bespoke PixelLab v2 DIRECTIONAL + animated (idle/walk/slice;
  124px frames; combat_scale 0.3875 containment). Upgraded 2026-07-06.

## Erin Solstice
- Human [Innkeeper], early 20s, athletic-average.
- Brown hair ponytail, apron over commoner clothes, expressive.
- Voice: warm, chatty, runaway-optimist, chess-sharp under the babble.
- Sprite: citizen_f family stand-in (Pixel Crawler; bundle-tier).

## Pisces Jealnv
- Human [Necromancer], thin, pale, early 20s.
- Shabby-genteel WHITE robes w/ faded trim, hood, smug posture.
- Voice: haughty, precise, defensive about necromancy, brilliant
  teacher despite himself.
- Sprite: bespoke PixelLab v2 DIRECTIONAL + animated hooded white robe
  (idle/walk; 108px frames). Upgraded 2026-07-06.

## Lyonette du Marquin
- Human [Barmaid] (fallen [Princess] of Calanfer — NOT public), late teens.
- **Bright RED hair** (canon — never blonde), blue eyes, worn-but-fine
  dress, proud posture thawing.
- Voice: haughty→humbling arc; formal diction slipping into sincerity.
- Sprite: citizen_f pink-tint STAND-IN (upgrade queued — red hair
  mandatory).

## Olesm Swifttail
- Drake [Tactician], slight/slim, smaller than Relc.
- Sky-blue scales, clerk's vest, carries a rolled map/ledger.
- Voice: earnest, chess-obsessed, self-deprecating, quietly proud.
- Sprite: bespoke PixelLab v2 DIRECTIONAL + animated (idle/walk; sky-blue
  Drake clerk holding a rolled map; 112px frames). Upgraded 2026-07-06.

## Zevara Sunderscale
- Drake [Watch Captain], athletic, upright bearing.
- LIGHT-blue scales, Watch officer armor, stern set.
- Voice: dry, overworked, duty-first; persuaded by risk/duty arguments,
  never flattery.
- Sprite: bespoke PixelLab v2 DIRECTIONAL + animated (idle/walk; light-blue
  Drake in Watch officer armor; 112px frames). Upgraded 2026-07-06.

## Krshia Silverfang
- Gnoll [Shopkeeper], tall, broad, dignified.
- Brown fur, silver-fang necklace signifier, market stall context.
- Voice: measured, proud of her stock, Silverfang pragmatism; "Hrr."
  verbal tic used SPARINGLY.
- Sprite: stand-in (upgrade queued — Gnoll = tall hyena-folk).

## Selys Shivertail
- Drake [Receptionist] (Adventurer's Guild), average build.
- Green scales, guild desk context, unimpressed expression.
- Voice: dry, competent, secretly soft-hearted.
- Sprite: stand-in tint (upgrade queued).

## The PC ("Traveler")
- Human otherworlder, deliberately everyman; clothing = simple
  earth-tone traveler's tunic/trousers/belt (a nobody-yet — NOT armor).
- Sprite: F2 in flight (v2 8-dir animated directive).

## Antinium (ratified picks, awaiting a character)
- Worker = candidate s21; Soldier = s33
  (potential_assets/pixellab_2026-07-06/antinium_worker/). First
  integration target: Klbkch (Worker-origin Senior Guardsman,
  canonical [Diplomat]).

## Raskghar (M-ARC A2, to generate)
- Hulking nocturnal dungeon-dwellers; bear-wolf silhouette, moon-grey
  fur, knuckle-walking bulk; awakened variant = larger, upright, aware
  eyes. Wiki-verify details at generation time.
