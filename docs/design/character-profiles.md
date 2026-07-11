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

## Dresk Ashgrave
- Drake, Duty Sergeant (Liscor Watch barracks), stocky, deskbound-but-capable
  build.
- Rust-brown scales (distinct from Zevara's light-blue and Relc's
  teal-green), plain Watch duty tunic (no plate — a desk posting, not a
  gate post), a belt-slate and chalk stub always in hand.
- Voice: (1) clipped checklist cadence, talks in short procedural bursts;
  (2) dry, put-upon humor buried under duty-first bluntness (Zevara's
  register, junior — busy, not haunted); (3) unimpressed by heroics,
  visibly pleased by paperwork filed correctly.
- Canon check: ORIGINAL+flag — wiki-verified 2026-07-07
  (wiki.wanderinginn.com + fandom search): no minor named Liscor Watch
  duty-desk sergeant is attested. Two candidates surfaced and were both
  ruled OUT OF SCOPE by the same bar as Klbkch: **Sergeant Gna** is a 4th
  Company Liscorian ARMY captain (not Watch) and a recurring
  Fellowship-of-the-Inn character; **Jeiss Sielmark** is a named Senior
  Guardsman and Liscor Councilmember (3rd-best bladesman in the Watch,
  partnered with Beilmark) — too major to reduce to static barracks
  dressing, same reasoning as Klbkch's exclusion.
- Sprite: `royal_soldier` reused (the former street `watch_guard` flavor
  NPC, relocated into the new `barracks` interior and given a name/voice
  for M-DEPTH DP4), rust-brown tint. Not a new generation.

## Vess
- Drake, Street Runner clerk (the Runner's Guild counter, M-DEPTH DP5),
  teenage, wiry.
- Slate-grey scales, a strap-scarred satchel worn even behind the counter
  (the silhouette tell: a runner parked at a desk, not a clerk), a
  sweat-band she does not need indoors and wears anyway; perpetually
  mid-catch-of-breath.
- Voice: (1) clipped out-of-breath bursts, even standing still; (2)
  measures everything in legs and distances ("that's a two-leg run") and
  delivery jargon ("signed-for", "same-waking"); (3) borrowed Courier
  pride — Hawk-references, aspirational, never boastful about herself;
  lights up at speed talk.
- Canon check: ORIGINAL+flag (name canon-plausible, not canon; proposed by
  the board-staging lane 2026-07-06, promoted from
  character-profiles-staging.md at DP5 wiring). Hawk (Rabbit Beastkin
  Courier, Liscor, one of the fastest on Izril) is wiki-verified
  2026-07-06 and stays OFFSTAGE — a name she drops, never an NPC.
- Sprite: `pc_drake_f` rig reused (slate-grey tint [0.5,0.55,0.58]), not a
  new generation — the Renn/Ilvo/Yelra walk-on convention.

## The PC ("Traveler")
- Player-named at creation (M-ARC §5); race Human/Drake/Gnoll + gender
  cosmetic. Deliberately everyman; clothing = simple earth-tone
  traveler's tunic/trousers/belt (a nobody-yet — NOT armor) ACROSS ALL
  SIX VARIANTS — the outfit is the identity constant, the body varies.
- Canon guard: only Humans are Earth otherworlders — the GDI opener
  branches (Drake/Gnoll get a "starting over in Liscor" arrival).
- Sprite: 6 bespoke PixelLab v2 DIRECTIONAL + full-anim variants
  (idle/walk/slice/hit/death/cast ×3 facings): pc_human_m (= F2 body_a,
  104px), pc_human_f (104px), pc_drake_m/pc_drake_f (124px),
  pc_gnoll_m/pc_gnoll_f (108px). Integrated 2026-07-06.

## Antinium (ratified picks, awaiting a character)
- Worker = candidate s21; Soldier = s33
  (potential_assets/pixellab_2026-07-06/antinium_worker/). First
  integration target: Klbkch (Worker-origin Senior Guardsman,
  canonical [Diplomat]).

## Klbkch (wiki-verified 2026-07-10: wiki.wanderinginn.com/Klbkch)
- Canon, OUR ERA (Vol 1-7 body -- the slimmer two-armed Rite-of-
  Anastases rebirth form is later-volume, DO NOT use): Worker-shaped
  Antinium -- dark brown chitinous body, FOUR arms, antennae, large
  black bulbous eyes, mouth pincers; a PAIR OF SWORDS at his sides
  (the one visual that separates him from every other Worker).
  Senior Guardsman of Liscor's Watch, Relc's partner.
- Silhouette contract (the 3 features a 64px sprite must hold):
  (1) four-arm read -- at minimum the second pair as a clear sub-arm
  mass, flagged to user if illegible at scale; (2) antennae; (3) the
  twin sword hilts at the hips. Palette: chitin dark brown (near the
  Worker s21 pick), NO Watch armor over the chitin (canon: he wears
  his blades, not a uniform).
- Voice: precise, courteous, unfailingly calm; dry understatement.
  Never jokey. He manages Relc; he has time for people.

## Raskghar (M-ARC A2, GENERATED + INTEGRATED 2026-07-06)
- Canon (wiki.wanderinginn.com/Raskghar): "a cross between an upright
  bear and a lion", tower over Gnolls, hunched with long claws + sharp
  teeth, nocturnal subterranean ambush predators; normal ~Level-15
  warrior, an **Awakened** Raskghar (ate a Gnoll's heart) is permanently
  smarter + matches a Level-20 warrior; full-moon lucidity.
- **raskghar_scout** — hulking moon-grey bear-lion, shaggy, hunched
  knuckle-gait, fanged. Directional idle/walk/slice (PixelLab v2
  create-character-pro mannequin + animate templates, 124px frames).
  render_scale 0.7458 (field figure ~44px, towers over the PC/Gnolls);
  anchor [0.5, 0.7581]; combat_scale **0.4492** (~26.5px / ~1.66 cells,
  contained per the Relc lesson — windowed-verified in combat + field).
- **raskghar_awakened** (the BOSS) — larger, upright, moon-grey with a
  pale MANE + cold intelligent eyes (visibly the smarter alpha).
  Directional idle/walk/slice, 124px. render_scale 0.8065 (field ~50px);
  anchor [0.5, 0.7823]; combat_scale **0.4839** (~30px / ~1.9 cells, it
  looms while HP bars stay readable — windowed-verified in deep_warren).
- Combat: raskghar_scout = bruiser melee pair (str15/con20/die7);
  raskghar_awakened = high-HP bruiser (con44 → 64 HP) whose signature
  [Raskghar Maul] is a range-2 slowed-rider swing on the existing
  spell_damage+applies machinery (no new effect type), `caster` AI.
  Balance: sim_combat_batch.gd BOSS_CELLS, 0.72 win vs warrior2+Relc
  (gated 0.6-0.75), 0.04 solo (measured veto).
