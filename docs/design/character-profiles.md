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

## Ceria Springwalker (wiki-verified 2026-07-11; 8d A2)
- Canon Vols 1-7: Boreal half-Elf, 65, SHORTER than her teammates;
  pointed ears; dirty-blonde hair; pale-yellow eyes (a later "winter-
  pale blue-grey" shift exists but its volume is unpinned — use pale
  yellow); skin subtly more vibrant than human. RIGHT HAND: bare white
  bone from the wrist, blackened frostbite-like join — VOLUME 1 CANON
  (the Ruins of Liscor disaster; she is introduced already injured).
  SPEC CORRECTION: the circlet is Volume 8+ (Putrid One's) — MUST NOT
  appear; the spec's circlet note is superseded by this verification.
- v1 sprite contract: enchanted blue robes, wand in hand, blonde hair.
  The bone hand ships GLOVED/HIDDEN v1 per the spec's taste flag (note:
  it IS early canon — user may ungate it; the sprite reads fine either
  way since the wand hand can be the gloved one).
- Class display: [Cryomancer]. Voice: blunt, upfront, informal,
  zero pretension, gallows humor; the leader who sounds least like one.

## Yvlon Byres (wiki-verified 2026-07-11; 8d A2)
- Canon Vols 1-7: human, tall, heavily muscled; long golden hair; fair
  skin; faint scar on the LEFT side of her face. Eye color undocumented
  on the wiki — steel-grey chosen to fit the silver palette (invented-
  within-gap, flagged). ARMS: silver-steel and shapeable from Volume 6
  (the Adult Creler fight) — a V6-7 snapshot shows METALLIC ARMS
  honestly, not hinted; before that, plate armor fused to flesh (V3).
- v1 sprite contract: silver plate, sword at hip, golden hair, both
  forearms reading METAL (the silhouette's must-show), face scar parked
  (sub-pixel at 30px).
- Class display: [Silversteel Armsmistress]. Voice: stiff, formal,
  unintentionally intimidating, renders any topic bland; blunt-kind.

## Ksmvr (wiki-verified 2026-07-11; 8d A2)
- Canon Vols 1-7: Antinium, former PROGNUGATOR of the Free Hive
  (elite command caste, Klbkch-trained, exiled as a "failure" —
  disciplined military bearing over Worker docility, laced with
  self-doubt). Four arms (the missing lower-right regrows via healing
  gel within the window — ship 4-arm). Chitin/eye color undocumented —
  use the Worker family's dark brown for caste consistency (flagged).
  Gear: crossbows + Forceshield Buckler + kris daggers.
- v1 sprite contract: the antinium_worker attempt-3 kernel ("four-armed
  ant man: TWO PAIRS...") + a gear harness/bandolier with a slung
  crossbow and small buckler — the equipment IS what separates him from
  a Worker at 30px. Same sub-arm legibility flag as Klbkch.
- Class display: [Skirmisher] (no "Brave", no level). Voice: formal,
  literal, "comrade" as address, clarifying questions about idioms;
  earnest, never jokey.

## Horns roster note (Vols 2-7, verified): Ceria (leader), Yvlon,
Pisces (ours already), Ksmvr — complete; no other members in-window.

## Eloise du Havin (wiki-verified 2026-07-11; #63 canon pass)
- Canon Vols 6-7 (first appearance 6.37E, in-window): human, elderly,
  SHORT, "surprising agility for her age" — stooped-but-spry. Grey
  locks. [Tea Witch]; craft/magic root = KINDNESS (her own words);
  Skills in-window: [Deft Hand], [Tea Gossip], [Tea Omens]; formerly
  [Lady] in Terandria. RESIDES IN RIVERFARM (confirmed — settled,
  with trading trips; the strongest possible fit for our vendor/
  mediator role). Signature: a FRIENDLY GREY witch hat with pressed
  tea leaves + embroidered flowers (grey and floral, NOT black-and-
  pointed-plain — the one wiki-sourced silhouette anchor).
- Invented-within-gap (wiki silent, flagged): warm brown eyes; soft
  sage dress + mauve shawl under the hat (tea-garden palette); a small
  teacup in hand (her craft output — extrapolated prop, flagged).
- v1 sprite contract: short elderly figure, the grey floral hat
  (must-read at 30px), sage/mauve warmth against Riverfarm's earth
  tones. REPLACES the shipped oversize generic witch (playtest
  finding 19).
- Voice: formal, aphoristic, gently moralizing — "Kindness asks
  questions." Never sharp; patience as pressure. (Alternative
  considered: Agratha [Witch Teacher] — better-documented palette but
  teacher-coded; Mavika — threat/gatekeeper register, wrong for a
  shopfront. Eloise's residence + tea-vendor craft won.)

## Wilovan (promoted + CORRECTED 2026-07-11; #17 audit find)
- Canon (wiki): GNOLL — a Gentleman Caller, [Thug]/[Ruffian]-line,
  broad, immaculate manners over real menace; hat-tipping courtesy.
  THE STAGING PROFILE SAID HUMAN — wrong; shipped rig (pc_gnoll_m) and
  wiki agree on Gnoll. This entry supersedes staging line 62.
- Voice contract (as shipped, audit-verified strong): "sir" address,
  apology-before-threat, "recover" never "steal", removes his hat
  plain-and-slow in respect. One dash per line (his `ways` node blew
  the budget — fix-lane item).
- Partner Ratici: SHIP APPROVED (user ruling 2026-07-16, #133) —
  grandfathered-safe by name (mid-Vol-7, spoiler-cutoff.md item 3); his
  Vol 8+ arcs stay out. Profile needed before his lane (wiki-verify:
  Drake, [Gentleman Thief] attribute 7.24 is the class-name ceiling;
  hats-off tell shared with Wilovan). Supersedes the 2026-07-11
  do-not-reference note.

## Ratici (wiki+primary-text verified 2026-07-16; #133 ship approval)
- Canon (all ≤ mid-Vol-7, primary-text checked): Drake, notably SHORT —
  the deliberate visual inverse of Wilovan's tall Gnoll bulk. Scale
  color NOT ATTESTED (art choice free — flag as invented-within-gap).
  Innocuous BROWN clothes (refuses noble dress, hates reading as
  lower-class — both at once); FLOPPY CAP accommodating his neck-spines
  (vs Wilovan's tall not-quite-top-hat). Hats-off tell attested from
  first appearance ("Don't make us take off our hats...").
- Class ceiling: [Gentleman Thief] (7.24, self-named). NEVER name
  [Aerial Dodge] — Vol-8 Skill (8.45 O) sitting UNCITED on his wiki
  page; verified absent from Vol-7 text. Shown-but-unnamed craft usable
  as flavor: plucks spells/illusions out of the air, leans out of a
  listening spell's path, reads a room's stash spots at a glance.
- Voice: fast and rough-edged under a gentleman's varnish — dropped
  g's ("Somethin'", "'Specially"), over-reaching fancy words used
  slightly wrong, clipped telegraphic register when reporting facts;
  semi-literate (reads slowly, a little self-conscious about Wilovan's
  vocabulary). Opens the MENACE while Wilovan opens the COURTESY.
  Never crude; the cap gets touched or adjusted where another man
  would show temper.
- Code (shared): courtesy to all (Miss/sir), debts cut both ways,
  never harm or steal from children (7.24), "serendipitous" as the
  Brotherhood codeword.
- v1 sprite contract: SHORT Drake in browns + floppy cap beside tall
  Wilovan; existing Drake NPC base + tint acceptable as flagged
  placeholder, PixelLab bespoke pass queued in VISUAL-LOG.
- DO-NOT-TOUCH (Vol 8+): Oteslia arc, casino job, Crimshaw's death,
  Wilovan's class reveal, nursery-rhyme verse 2, Rickel,
  Normen/Alcaz knighthood. Gray-zone (late Vol 7, past Book 17):
  guarding-Erin reveal (7.52), "until the hats come off" phrasing
  (7.56) — grandfathered TELL is fine, the full SAYING is not.

## Frazzled Drayman (profile added 2026-07-11; #17 audit find)
- OUR INVENTION (no canon figure) — the [Diplomat] system's free-entry
  persuade NPC (street 19,14). Voice contract, capturing what the
  shipped copy already does: harried, repetitive, caps-for-panic, zero
  malice — a man drowning in a small problem. Persuading him is
  FIRST-AID, not manipulation (the system's moral framing lives here).
  No dashes (caps carry the panic — the greet's triple-dash is a
  fix-lane item).

## Recruit Pell (profile added 2026-07-12; issue #81 'The Missing Recruit')
- OUR INVENTION (no canon figure) — a green Liscor Watch recruit,
  Dresk Ashgrave's own posting-seeded optional side quest (present_when
  entity, sewers, only exists once the quest starts). Sprite: `royal_soldier`
  reused (the Dresk/watch_guard precedent), pale grey-green tint,
  distinct from Dresk's rust-brown/Zevara's light-blue/Relc's teal-green.
  Voice: (1) nervy run-on sentences under real relief at being found;
  (2) embarrassed about the panic, deflects with a joke about the
  paperwork; (3) never a repeat character beyond this one quest — no
  further appearances planned.

## Grimalkin (wiki-verified 2026-07-07 corrections; promoted from staging
## at 8e Phase A, 2026-07-12)
- Canon: [Sinew Magus] L40+, Magic-Captain of Pallass, runs his own
  fitness/combat academy. **CORRECTED from an earlier draft**: MASSIVE
  Drake, **GREEN scales (not slate)**; canon attire is **TIGHT-FITTING
  clothing he strains and bursts by flexing** — NOT a sleeveless robe.
  Keep the ink-and-dumbbell props (his note-taking empiricism —
  measures everything).
- Silhouette contract (the 3 features the sprite must hold): (1) MASSIVE
  hyper-muscled build — the single tallest, widest Drake shipped
  (bigger than Relc); (2) green scales, distinct from Relc's teal-green,
  Zevara's light-blue, Klbkch's dark-brown-chitin non-Drake read; (3)
  clothing visibly straining over the muscle mass (the "bursts by
  flexing" tell) + a small notebook/quill prop — the "scholar's
  precision on a soldier's frame" register `docs/superpowers/plans/
  2026-07-12-8e-pallass.md` names for [Sinew Magus].
- Voice: fitness-empiricism — a drill-sergeant-on-steroids who
  genuinely cares; lectures in numbered points; respects effort,
  despises excuses.
- v1 role: bureaucratic-quest examiner beat + a talk_pool presence
  (8e v1 scope — full academy content deferred).
- **Generation prompt** (PixelLab v2 `create-character-pro`, derived
  verbatim from the silhouette contract above, `method:
  create_with_style`, `template_id: mannequin`, `view: low top-down`,
  132×132, `no_background: true`): "massive hyper-muscular Drake
  warrior-scholar, bright green scales, enormous bulging muscles
  straining and stretching a tight-fitting sleeveless training shirt
  about to burst at the seams, holding a small notebook and quill pen
  in one clawed hand, drill-sergeant physique, powerful wide stance,
  top-down RPG game character sprite, hard black outline, 16-bit pixel
  art". Character id + measured anchor/scale: see
  `assets/LICENSES/pixellab-ai-generated-verdict.md` "8e Phase A" entry.

## Tier clerk (ORIGINAL+flag; promoted from staging at 8e Phase A,
## 2026-07-12)
- OUR INVENTION (no canon figure) — the QUALIFY-verb bureaucrat who
  staffs Pallass's stamp-desks (market-tier arrival checkpoint, forge-
  tier permit/inspection chain). One rig reused at every desk (the
  civic-uniformity tell — same convention as `market_stall_pallass`'s
  identical stalls).
- Silhouette contract: **DESK-SHAPED** — deliberately distinct from
  every shipped Drake (Zevara: fitted Watch-captain armor; Olesm:
  slight scholar build; Relc/Grimalkin: huge). Trim build, but the
  READ is rigid and rectangular: a stiff, high-buttoned formal coat
  (boxy, not form-fitting) over a straight upright desk-official
  posture, a bronze guild sash across the chest, holding a stamp over
  an open ledger — the coat's own straight lines are what make him
  read as furniture-adjacent (a desk given legs), not a body type.
- Voice: titles-and-precision — "state your business and your
  sponsor"; warmth exists behind exact paperwork.
- v1 role: the market-tier arrival stamp + the forge-tier permit chain
  (8e v1 scope; no name — a civic role, not an individual, matching
  the city-identity bible's "uniformed everything" population read).
- **Generation prompt** (PixelLab v2 `create-character-pro`,
  `method: create_with_style`, `template_id: mannequin`, `view:
  low top-down`, 108×108, `no_background: true`): "trim Drake
  bureaucrat clerk, slate-blue scales, wearing a stiff rectangular
  formal coat buttoned high with a bronze guild sash across the chest,
  upright rigid desk-official posture, holding a rubber stamp over an
  open ledger book, neat precise paperwork official, top-down RPG game
  character sprite, hard black outline, 16-bit pixel art". Character
  id + measured anchor/scale: see
  `assets/LICENSES/pixellab-ai-generated-verdict.md` "8e Phase A" entry.
