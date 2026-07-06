# Systems Depth Priorities (user-directed 2026-07-06)

Status: user priorities superseding "Future systems"; Fable-authored
design w/ one embedded verdict (§2) awaiting user ratification. These
slot AFTER M-ARC unless the user pulls one forward.

## 1. M-GEAR — inventory + equipment depth

- **Resonance as the limiter (canon):** items carry a `resonance` cost
  (mundane gear 0; enchanted gear 1-3). The PC has a resonance CAPACITY
  (base 2-3; grows rarely — a milestone-feeling event, opaque until it
  happens). Equip anything, any combination, under capacity — no rigid
  slot matrix beyond the existing weapon/armor + new **accessory slots
  (2-3)**. Over-capacity refusal is diegetic: "The charm's hum turns to
  static against the sword's." Canon anchor: magical-item interference/
  resonance (wiki-verify exact framing at content time).
- **Item lore for environmental storytelling:** every item gains a
  `lore` line rendered in the inventory detail (where it came from, who
  made it, what it implies about the world — the gnollish hunting knife
  says something about Silverfang trade; the watch-issue gambeson about
  Zevara's budget). Found-items may carry provenance variants
  ("Pried from the sewer grate's hinges…"). Writing rides character/
  place profiles.
- **More items:** the shop + loot + quest rewards deepen with the new
  slots (charms, rings, tools). Balance via harness loadout cells (E6
  machinery exists).

## 2. M-LEGIBILITY — the explainable-mechanics sweet spot

**Verdict (recommendation): no raw stats needed — extend the VISIBLE
CURRENCY tier instead.** The playtest-approved visible tier is already
HP / MP / AP / damage numbers / move pool. Every mechanical fact the
player needs can be stated in those currencies:

- **Item cards** (inventory + shop): concrete effect lines — "+4 HP",
  "+1 damage on melee hits", "Reduces every hit taken by 1", "Resonance
  1". Comparison = reading two cards. No STR/DEX ever shown.
- **Skill cards** (journal + hotbar readout): cost + effect in visible
  currencies — "[Frost Bolt] — 1 AP, 2 MP. Damage 1d6. Slows."
- **A status glossary** (journal page + first-encounter toast):
  "Slowed — moves 2 fewer cells next turn (min 1)." "Guard open — the
  next hit against them deals +2." Every status/keyword gets ONE
  sentence in mechanics terms.
- **What stays hidden (unchanged, identity-critical):** raw attributes
  (STR/DEX/…), progress-toward, level-up math, dominance/evolution
  internals. The character himself stays a mystery; the TOOLS become
  legible. Canon-compatible: TWI characters know what their Skills do,
  not what their souls' numbers are.
- Copy audit: existing flavor-only descriptions gain effect lines
  (data pass); opacity rules re-checked per line.

## 3. Overworld Skill effects with perceivable impact (the [Light] bar)

Every fielded Skill should DO something visible in the world where
sensible. Candidates on existing kits (each = the [Light]-glow class of
implementation: sim flag/effect + presentation + QA):
- **[Frost Bolt] field-cast on water:** freezes a channel/pond cell
  into a crossable ice tile (sewers channels + the floodplains pond —
  traversal + secrets). Melts at sleep.
- **[Flame Jet]/fire skills:** light unlit campfires/sconces (real
  light anchors), burn debris-blocked passages (a new blocking-prop
  class: `burnable`).
- **[Battlefield Awareness]:** overworld — briefly reveals encounter
  threat ranges (the trigger_radius zones render as a fading overlay).
- **[Sweep the Tables]/cleaning line:** visible mess-state props
  (visual_states) beyond the dirty table.
- **[Observe]/[Charming Smile]:** already live; observe could
  additionally mark observed entities in the journal (knowledge log).

## 4. Gap-based Skill sourcing (capability-first)

Method: name the VERB we want, then wiki-source the canon Skill.
| Capability gap | Canon Skill candidates (verify) | Surfaces |
|---|---|---|
| Fast overworld movement | [Quick Movement], [Flash Step] | field sprint + combat reposition |
| Stealth / pass unseen | [Stealth], [Invisibility] (rogue lines) | sneak past trigger_radius encounters; combat escape/opener |
| Vertical/blocked traversal | [Lion's Strength] (jump/shove), burnable/freezable props (§3) | new map connectivity, secrets |
| Perception / secrets | [Keen Eye], [Detect Life] | hidden interactables glow; anti-stealth |
| Sustain / utility | [Repair], [Preserve], [Basic Healing] ([Healer] line?) | gear upkeep (M-GEAR tie-in), consumables |
| Social force | [Command], [Loud Voice] | new dialogue-check class |
New Skills arrive attached to CLASSES (existing arrival machinery), and
each ships with BOTH a combat and an overworld read where sensible —
the pillar-parity rule applied at the Skill level.

## Sequencing (proposal)

M-ARC finishes first (in flight). Then: **M-LEGIBILITY** (small, huge
comprehension payoff, unblocks honest evaluation of everything else) →
**M-GEAR** (resonance + slots + lore; wants legible item cards first) →
**§3/§4 as a Skills wave** (or folded into the next content expansion's
kits). Each gets the standard spec→plan→execute cycle with user gates.
