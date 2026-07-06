# The Wandering Inn Wiki — Mage-Line and Utility Classes/Skills

Research spike for the v4 game's spellcasting and civilian-class design. Source of truth:
thewanderinginn.fandom.com (mirrored content also served at wiki.wanderinginn.com — same
MediaWiki content, used interchangeably below since Fandom itself returned HTTP 402 to the
fetch tool in this session; all facts below were pulled from the wiki.wanderinginn.com mirror
plus Fandom search-snippet previews).

## 1. Mage-family class tree

**Base class:** `[Mage]` — "a Class within Innworld that is associated with Magic... regarded
as a foundational Class that can advance into specialized Classes." A `[Mage]`/`[Magus]` is a
general practitioner; `[Wizards]` are a related-but-distinct scholarly variant who lean on
prepared spells/wands/items rather than innate casting.

**Elemental specialization lines** (canon names, not invented):
- Fire: `[Fire Mage]` → `[Pyromancer]` → `[Inferno Mage]`/`[Inferno Pyromancer]`
- Ice: `[Ice Mage]` → `[Cryomancer]` → `[Arctic Cryomancer]` → `[Relicbound Arctic Cryomancer]`
- Others: `[Air Mage]`/`[Aeromancer]`, `[Water Mage]`/`[Hydromancer]`, `[Lightning Mage]`,
  `[Geomancer]`, `[Dark Mage]`/`[Umbralmancer]`, `[Light Mage]`, `[Glass Mage]`, plus niche
  variants `[Sand Mage]`, `[Gem Mage]`.
- `[Elementalist]` is a broader (non-single-element) evolution branch off `[Mage]` — a mage can
  go `[Mage]` → `[Elementalist]` → further specialize into e.g. `[Cryomancer]`/`[Ice Mage]`.
  ("This is only one of the many paths a mage may take.")
- Necromancy is its own major branch — `[Necromancer]`, with self-taught practitioners called
  "hedge-Necromancers" (see `[Hedge Mage/Wizard]` note below); necromancers are now the most
  common self-taught mage-type on Terandria/Izril per the wiki's Necromancers page.

**Higher/generalist forms:** `[Mage]` (starter) → `[High Mage]` (generalist, higher level) →
`[Grand Mage]` (educator tier, level 40+) → `[Grand Magus]` (near-apex) → `[Archmage]` (apex).
`[Archmage]` and `[Grand Magus]` are described as "the highest... apex of all [Mage] classes,"
with compound apex variants like `[Archmage of Death]`, `[Archmage of Sands]` tied to a
specific school.

**Spellcaster class variants:**
- `[Hedge Mage]`/`[Hedge Wizard]` — self-taught practitioner, arises where centralized magical
  education (e.g. Wistram) isn't accessible; explicitly a lower-prestige/self-taught label
  applied across schools (hedge-Necromancer, etc.), not a single fixed evolution slot.
- `[Shaman]` — a parallel (non-arcane) magic tradition, not a `[Mage]` evolution. Per the wiki,
  most species lean either toward arcane `[Mage]`-line magic or toward shamanic magic; only
  Humans, Centaurs, Garuda, and (formerly) Gnolls have an equitable mix of both traditions.
  `[Shaman]` has its own specialization list: `[Beekeeper Shaman]`, `[Chief Shaman]`,
  `[Dowser Shaman]`, `[Head Shaman]`, `[Keeper of the Pasts]`, `[Magic Paint Shaman]`, etc.

**Specialization mechanics — important constraint:** when a `[Mage]` transcends into a unique
class such as `[Necromancer]` or `[Cryomancer]`, they commit to that specialization; if they
later want to pursue a *different* magic type they "must begin with the `[Mage]` class again,
starting from Level 1." Leveling as a `[Mage]` is unusually slow relative to physical classes —
"even Archmages of Wistram have difficulty leveling" because it requires study AND practice of
high-power magic, not just fighting escalating foes.

**Class Skills vs. learned spells (the key mechanic for our game):** These are two distinct
sources of magical ability that both class as "spells" narratively but work differently:
- *Learned/studied spells* — the vast majority of what mages cast. "Most modern [Mages] learn
  spells akin to copying a template, without understanding how the spell actually works."
  These are acquired by study (a scroll, a teacher, a grimoire) independent of class level —
  a mage memorizes a limited roster of these prepared spells and can cast any of them at will
  once learned, but each costs mana and casting time to prepare/learn.
- *Class Skills* — abilities granted directly by leveling in a magic class (the `[Class] Level
  X: Skill]`-style notifications). These are "boxed" complete abilities that "prove less
  mana-intensive" than an equivalent custom-configured/cobbled-together spell, i.e. the class
  system hands out efficient premade versions of what a from-scratch caster could build by
  understanding magical theory directly.
- Net effect for a game design: a mage character's spell list is not purely level-gated. Some
  spells are class-Skill unlocks (tied to level/class evolution) and some are just "known
  spells" a mage picked up from a book/tutor regardless of level — a Level 5 `[Mage]` who
  studied hard can know a spell a Level 15 `[Mage]` doesn't, and vice versa.

## 2. Canon spells relevant to a low-level game

Formatting on the wiki's dedicated `Spells` and `Fire` pages is inconsistent about numbering
(some pages give a Tier, most low-profile spells are listed with no tier at all), so treat tier
numbers below as best-available, not universally confirmed for every entry.

**Ice/frost:**
- `[Ice Spike]` (Tier 3) — "Conjures and projects a spike of ice." Confirmed in Falene
  Skystrall's known-spells list.
- `[Ice Shard]`/`[Icy Shard]` (Tier 2) — conjures/projects an ice dart.
- `[Ice Lance]` (Tier 4) — conjures/projects a massive ice lance.
- `[Ice Floor]`/`[Icy Floor]` (Tier 2) — covers ground in slippery ice (control/utility, not
  direct damage).
- `[Frost Arrows]` (untiered) — conjures ice arrows.
- `[Frozen Wind]`/`[Frozen Winds]` (Tier 1) — conjures a freezing breeze (AoE/cheap).
- `[Frostbolt]` (untiered) — magical bolt that frosts on impact.

**Fire:** the wiki's `Fire` page organizes by explicit tier (0–7):
- Tier 0: `[Firespark]`, `[Heated Air]`, `[Hot Hands]`, `[Spark]`
- Tier 1: `[Flare Burst]`/`[Flareburst]`, `[Flick Fire]`
- Tier 2: `[Flame Bolt]`/`[Firebolt]`, `[Flame Jet]`, `[Flame Scythe]`, `[Flame Spray]`
- Tier 3: `[Fire Orbs]`, `[Fireball]`, `[Flame Arrow]`, `[Flaming Swathe]`, `[Fox Fire]`
- Tier 4: `[Flame Strike]`, `[Ray of Incineration]`, `[Siege Fireball]`
- Tier 5: `[Beam of Fire]`, `[Blackfire Fireball]`, `[Rivet-Lance of Flames]`
- Tier 7: `[Hellfire Pillar]`, `[Hurricane of Flames]`
- Untiered but canon and low-key: `[Firefly]` (a small conjured flame/light effect — Erin-tier
  parlor-trick spell, not a combat nuke), `[Flare Firefly]`. The page lists 100+ more fire
  spells with no assigned tier.
- `[Fireball]` itself is Tier 3 per the Falene page ("Conjures and launches one or multiple
  balls of fire") — good reference point: Tier 3 ≈ "solid mid-power AoE damage spell," not
  entry-level.

**Barrier/shield:**
- `[Force Barrier]`/`[Forcewall]` (Tier 4) — force-field barrier/wall.
- `[Mana Barrier]` (Tier 4) — visible green barrier outlining the caster, blocks contact.
- `[Arcane Barrier]` (Tier 4) — general defensive ward.
- `[Force Shield]`/`[Forceshield]` (untiered) — protective spell, likely a lighter-weight
  version of Force Barrier.
- `[Forcewall: Bubble]` — a named sub-variant seen in Falene's list (untiered), suggesting
  spells can have named "flavors"/configurations under one base spell name.
- `[Stone Wall]`/`[Wall of Stone]` (Tier 3) — physical (not magical-force) wall, cheaper
  alternative for blocking line of sight/movement.

**Utility:**
- `[Light]` (Tier 0) — conjures a ball of light. Cheapest, most universal utility spell —
  good candidate for a starting-mage kit.
- `[Message]` (Tier 3) — two casters exchange messages across distance.
- `[Communication]` (Tier 4) — live two-way long-distance talk (heavier than Message).
- `[Repair]` (Tier 2) — repairs non-magical objects.
- `[Detect Magic]` (Tier 1 or 3, sources disagree) — senses magic in the area.

**Tier calibration takeaway for a low-level game:** Tier 0 (`[Light]`, `[Firespark]`,
`[Hot Hands]`) = trivial cantrip-equivalents suitable for a starting caster; Tier 1–2
(`[Frozen Wind]`, `[Ice Shard]`, `[Flame Jet]`, `[Ice Floor]`) = the actual "first real combat
spell" band; Tier 3 (`[Ice Spike]`, `[Fireball]`, `[Flame Arrow]`) is already a meaningfully
strong, established combat spell in canon (used by an adult Battlemage character, not a
novice) — worth knowing if the game wants to gate "Fireball"-tier effects behind more than
character-level-1 content.

## 3. Hybrid warrior-mage classes

- `[Spellblade]` — **real, held canon class**, described as "a variant on `[Spellsword]`" with
  Skills that specifically enhance an equipped artifact/weapon rather than granting independent
  spellcasting power. Confirmed holder: **Hilten Coroes**, `[Spellblade]`, a member of the
  Gold-rank adventuring team Glitterblade, whose Skills enhanced his carried flyssa (weapon).
  This makes `[Spellblade]` closer to "artifact-augmenting warrior with light magic," not a
  full second-caster class.
- `[Spellsword]`/`[Swordmage]` — the parent archetype: an explicit combination of `[Mage]` and
  `[Warrior]` progression, i.e., a true hybrid caster-fighter class line, of which
  `[Spellblade]` is one named variant/specialization.
- `[Battlemage]` — another martial-caster hybrid, notably held by **Falene Skystrall**
  (`[Pursuant Battlemage of Magic's Romance]`, Lv. 37, evolved from `[Battlemage of Charity]`
  Lv. 36) — a mage class built around rapid-casting many low-tier spells in combat rather than
  melee weapon use per se; still counts as a warrior-adjacent "in the fight, not behind the
  lines" mage archetype in the story.
- `[Arcane Warrior]` — named in the wiki's class-tree summary as another hybrid, less
  independently documented in the sources checked this session (needs a follow-up character
  citation if load-bearing for design).

## 4. Utility/civilian classes relevant to the game

**`[Innkeeper]` (Erin Solstice's line):**
- Erin's progression: `[Innkeeper]` Lv. 1 → 30, then `[Magical Innkeeper]` Lv. 30 → 49, then
  `[The Wandering Innkeeper]` Lv. 49 → 55 (her current class per the wiki as of research date).
  Other named `[Innkeeper]` evolutions exist as branches other characters/instances could take:
  `[Goblinfriend Innkeeper of Wonders]`, `[Shamanic Innkeeper]`, `[Famed Innkeeper of the
  Wizardly Home]`.
- Erin also holds/held several secondary classes simultaneously: `[Witch of Second Chances]` →
  `[Witch of Remorse]` (Lv. 24), `[Dancer]` → `[Dancer of Advent]` (Lv. 14), `[Singer]` (Lv. 6),
  `[Warrior]` (Lv. 2) — confirms multi-classing is canon-normal, not a game-only house rule.
- Generic `[Innkeeper]` Skills common to the class (not Erin-unique): `[Basic Cleaning]` /
  `[Advanced Cleaning]`, `[Basic Cooking]` / `[Advanced Cooking]`, `[Basic Crafting]` /
  `[Advanced Crafting]`, `[Crowd Control]`, `[Employee Skill]`, `[Quick Recovery]`. General
  class fluff: can conjure free food daily, boost staff productivity; more advanced holders get
  utility magic like improved guest sleep/illness recovery and even wards against offensive
  spells inside the inn.
- Erin's own notable named Skills (do NOT surface underlying stats in any UI per repo
  convention — these are flavor/ability names only): `[Immortal Moment]` (extreme
  subjective-time mental dissociation/focus, originally manifested as "playing chess for what
  felt like years" while retaining battlefield awareness), `[Wondrous Fare]` (cooking that
  produces alchemical-potion-like effects — e.g., temporary cold resistance, induced nostalgic
  hallucinations, hardened skin), `[Garden of Sanctuary]` / `[Magical Grounds]` (creates a
  dimensional garden space, lets mana regenerate naturally in the inn), `[Key of Reprieve]`
  (gained Level 47 in `[Magical Innkeeper]`, grants access to every past holder's `[Garden]`
  Skill), `[Pavilion of Secrets]`, `[Portal Door]` (500-mile linked doorway), `[Field of
  Preservation]`, `[Boon of the Guest]`, `[World's Eye Theatre]`. `[Basic Cleaning]` is the
  generic class Skill Erin also has, not something invented for her specifically.

**`[Barmaid]` / `[Princess]` (Lyonette du Marquin):**
- Lyonette is the 6th Princess in line for the Eternal Throne of Calanfer; her `[Barmaid]`
  class is treated by her royal family as beneath/unfitting a royal. She temporarily lost her
  `[Princess]` class (stopped "feeling like" a princess due to her occupation) and later
  regained status via a **consolidated** class, `[Worldly Princess]` — i.e., the game's canon
  supports class *consolidation* (merging two classes into one compound class) as a real
  mechanic, not just straight evolution chains.

**`[Receptionist]` (Selys Shivertail):**
- Selys is a Drake; her confirmed class progression is `[Receptionist]` Lv. 19 →
  `[Experienced Receptionist]` Lv. 27 → `[Vice Guildmistress]` Lv. 26, which later
  consolidates into a further guildmistress-tier class (`[Guildmistress of Northern Blades]`,
  Lv. 28, alongside her separate `[Relickeeper Heiress]` Lv. 22 status and combat-side classes
  `[Soldier]`/`[Warrior]`). So "Receptionist" is a real, leveled civilian class with its own
  named evolution (`[Experienced Receptionist]`), not just a job title — confirms the
  Innkeeper-adjacent civilian classes in our game (front-desk/service roles) have precedent for
  a full level-gated evolution chain, including eventual guild-leadership consolidation.

**`[Runner]`/`[Courier]` (delivery flavor):**
- `[Runner]` is the base delivery-profession class (Runner's Guild); `[Courier]` is not a
  separate class so much as the **highest rank** a Runner's Guild member can reach, requiring
  Level 30+ and exceptional proven reliability on dangerous routes — "not even a hundred are
  known on the whole continent of Izril," i.e., an extremely rare, mostly title/rank-based
  distinction rather than a mechanically distinct evolved class name.
- Milestone Skills flagged as roughly two-thirds-of-the-way-to-Courier markers: `[Double Step]`
  and `[Quick Movement]` — though the wiki notes speed Skills aren't strictly required; proven
  delivery performance under danger can also qualify a Runner for promotion.

## 5. Skill/spell naming and formatting conventions

- All Skills and spells are written in square brackets, e.g. `[Basic Cooking]`,
  `[Greater Strength]`, `[Ice Spike]` — this is the universal, invariant formatting across the
  wiki and (per its citations) the underlying webnovel text itself.
- Tier/power prefixes seen in canon: **Basic** (e.g. `[Basic Cooking]`, `[Basic Cleaning]`,
  `[Basic Crafting]`) as the entry rung, **Advanced** as the next rung up
  (`[Advanced Cooking]`, `[Advanced Cleaning]`), and **Lesser**/**Greater** as a separate
  relative-power pair used across various Skill families (e.g. implied `[Greater Strength]`).
  These prefixes are not universally applied to every Skill — many Skills have no tier prefix
  at all and are simply a unique compound name (`[Wondrous Fare]`, `[Key of Reprieve]`).
- Skills can **change/evolve into a differently-named advanced Skill** rather than just gaining
  a tier prefix — the wiki's own example: `[Power Strike]` can evolve into `[Minotaur Punch]`
  (a wholly renamed, more powerful skill), which is also attested on Erin's own page
  (`[Power Strike]` → `[Minotaur Punch]`, learned from Calruz).
- Numeric spell Tiers (Tier 0 through at least Tier 7 confirmed on the Fire spell page) are a
  separate axis from the Basic/Advanced/Lesser/Greater Skill-prefix convention — Tiers appear
  to apply specifically to studied/memorized **spells** (magic-school power bands), while
  Basic/Advanced/Lesser/Greater prefixes apply more to **class Skills** broadly (any class, not
  just mages).
- Compound/qualified class names are common at high level via **consolidation** (merging two
  classes, e.g. `[Worldly Princess]`) or **evolution with an appended epithet** tied to
  personal history (e.g. `[Pursuant Battlemage of Magic's Romance]`, `[Archmage of Death]`,
  `[The Wandering Innkeeper]`) — i.e. don't expect clean generic tier-name reuse at high levels;
  flavor text gets folded into the class name itself.

## Sources

- https://wiki.wanderinginn.com/Mages
- https://wiki.wanderinginn.com/Classes
- https://wiki.wanderinginn.com/Class:Mage
- https://wiki.wanderinginn.com/Spells
- https://wiki.wanderinginn.com/Fire
- https://wiki.wanderinginn.com/Falene_Skystrall
- https://wiki.wanderinginn.com/Skills
- https://wiki.wanderinginn.com/Erin_Solstice
- https://wiki.wanderinginn.com/Innkeepers
- https://wiki.wanderinginn.com/Selys_Shivertail
- https://wiki.wanderinginn.com/Lyonette_du_Marquin
- https://thewanderinginn.fandom.com/wiki/Mages (Fandom search-snippet preview only — direct
  fetch returned HTTP 402 in this session; content cross-checked against the wiki.wanderinginn.com
  mirror above)
- https://thewanderinginn.fandom.com/wiki/Archmage (search-snippet preview only, not directly
  fetched — see confidence notes)
- https://thewanderinginn.fandom.com/wiki/Couriers / https://wiki.wanderinginn.com/Runner's_Guild
- https://wiki.wanderinginn.com/Necromancers (referenced for hedge-Necromancer/self-taught note)
