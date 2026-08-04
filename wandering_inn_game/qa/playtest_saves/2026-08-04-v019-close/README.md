# v0.19 close — five reads (2026-08-04)

Everything here loads from **Title → Playtest States** (debug builds only). It
installs into the game's own dedicated `playtest` slot and loads it directly,
so your real saves are untouched — nothing to copy, nothing to restore.

Launch: `/usr/local/bin/godot --path wandering_inn_game`

The wave's thesis is one sentence: **the world answers the hand.** Every read
below is that sentence from a different angle. What I want from you is FEEL —
the gates are all green and prove nothing about whether it lands.

---

## 1. The property sandbox — the marquee, ninety seconds

**Load: `martial_field_armed`.** Floodplains, warrior 8, holding all five
martial verbs plus [Ice Floor] and [Flame Jet].

Cast [Ice Floor] on the pond, walk across it, then burn it back to water. Find
the scree chute up the east outcrop and bump into it *without* [Even Footing]
first — the refusal should tell you the ground is the problem, not that there
is a wall. Then cross it. Cook the corusdeer carcass on the periphery.

**The question:** does the world feel like it has properties, or like it has
scripted spots? If a verb you aimed produced nothing you could see, that is the
bug and I want to know which one.

## 2. The same sentence, mage-side

**Load: `sewers_property_seams`.** [Snap Freeze], [Firefly], [Light],
[Basic Cleaning].

Freeze one channel, cross, thaw it, watch it re-shut behind you. Burn the
debris. Clean the grime. Try the refusals on purpose: frost on a person, frost
on a lit hearth, kindle on water. **Those refusals are the vocabulary teacher**
— if any of them reads as a bug rather than as the world declining, say so.

The ice tile is bespoke as of this wave. It should read as fractured plate, not
as brighter water. Two earlier attempts shipped as a tint and were retracted.

## 3. The ambush, repaired

**Load: `near_defeat`** (or walk the floodplains ambush from `post_tutorial`).

Lose on purpose. You now wake where you fell with the fight undone, and
**walking away works on the first try** — the encounter stays live, but it will
not re-fire until you leave its radius and come back. The defeat text varies:
before Relc's spar it points you at him; after the spar but before you have ever
slept it points you at the bed.

**The question:** does the beat teach "walk away" without saying it? And is the
nudge line in-fiction, or does it read like a tutorial?

## 4. The inn, legible

**Load: `wrong_order_loop_start`** (kitchen) and walk upstairs for the bedroom.

Cold-read, no context: which one do you sleep in and which do you open? Which
pot cooks a stew, which is a range, which is a witch's kettle? All three kitchen
stations had one silhouette and three tints until this wave; both blind
playtests inverted the bed and the chest.

Then talk to any patron as a non-cooking build. The Serve option is still
locked — that is deliberate, cooking stays the gate — but it now tells you where
the pot is. **Ruling to confirm or overturn: a combat PC being shut out of the
Serve economy until they take a cooking Skill.** I said yes, signposted. The
alternative is a vendor route, which GH#334 already ruled against.

## 5. Faces — the six new rigs (added after the first draft of this brief)

**Load: any save.** Six characters stopped wearing other people's skins:

| who | wore | now |
|---|---|---|
| Selys (guild desk) | `citizen_f` — a HUMAN woman, green-tinted | a Drake |
| Octavia (Pallass market) | `citizen_f` — same human rig | a Stitch-girl |
| Ilvo (guild) | `tier_clerk`, a Pallass civic sash | a Liscor Drake |
| Krshia (street + inn) | the generic traveler rig + brown tint | her own |
| Wilovan (parlor + inn) | **`pc_gnoll_m` — the PLAYER'S OWN SKIN** | his own |
| Pisces (inn guest) | a hooded grey bust with no eye pixels | a face |

**The reads I want:** does Krshia land as a *merchant* now (the first generation
came back an armored brawler and was thrown out)? Does Wilovan read as the
Gentleman Caller — courtesy over menace? Is Pisces recognisably a smug young
necromancer rather than a hood?

**Known and deliberate:** Wilovan ships **idle-only**. He is a fielded combat
ally, so in the hired_blades fight his attacks fall back to the idle pose
instead of a swing. Nothing breaks; it just lacks flourish. Tell me if that
reads as broken rather than plain, and I'll generate his combat set (~6 gens).

## 6. A pot is a pot (#391)

**Load: `martial_field_armed` or any save with a cooking Skill.**

Cooking-family Skills used to be bound to SPECIFIC props. Now any pot answers
any cooking-family Skill. Try [Basic Cooking] on the inn's **witch kettle**
(6,2) — previously it only spoke to [Hedge Remedy] and you'd have walked to
Riverfarm for a pot that would talk to you. Then the stew pot (4,1): it must
still give its own authored line, not the generic one.

**The question:** does the generic line ("You get the pot hot, work with what is
in it, and it comes out food") feel acceptable as the *fallback*, or does it
flatten places that deserve their own words? Every prop can still override.

## 7. The leak is gone from the inn (#392)

**Load: any early save.** The hole in the common-room wall at (9,7) is no longer
there until the door chain arms it. Walk the room and confirm it now reads as a
room rather than as a puzzle you can't touch — and that nothing looks *missing*
where it used to sit.

## 8. Panels and the quiet things

**Load: any save.**

- Pause during a fight. The scrim is new; combat HP text should no longer read
  through "Abandon to Last Save". Alpha is 0.55, invented — it can move ±0.1 on
  your eye.
- Settings: the difficulty and quest-hint knobs now explain themselves, and the
  rows are reordered. Journal wraps are fixed.
- Inventory: **Resonance** is finally named where it bites. It was shipped,
  save-persisted and sleep-grown, and explained nowhere — all four blind
  playtests asked what it was.
- Field bar: a 3-state day/dusk/night glyph. Deliberately NOT a clock — no
  counts, no bar. If you can infer how many actions you have left from it, that
  is a bug and it violates opaque-until-sleep.

---

## What the machines already proved — do NOT spend eyes here

206/206 canonical scripts, 33/33 unit suites, data_lint, the comment census,
the dialogue voice gate and leak_check are all green, and the shipped-ids
freeze is re-cut. Logic is covered. **Everything above is asking for FEEL, taste
or a cold read — the things a green gate cannot see.**

Specifically already proven by machine, no need to re-check: the ambush no
longer re-fires when you walk away; `state_set` survives a save AND a sleep; an
absent encounter neither blocks nor ambushes; a cook gets a meal from the
kettle while the stew pot keeps its own line; the sign no longer blocks the
west inn door; no canonical seed flipped.

## The one thing I need a word on

**[Rope Work] is an invented name.** Canon's [Rope Arrow] is spoiler-blocked.
It shipped under the invented name so the wave would not stall, and it is pinned
by skill id everywhere, so renaming it is a one-string diff whenever you say so.

Also yours, not mine: **PixelLab is at $1.53 with zero subscription generations
left** (everyone assumed ~$2.70). Six bespoke NPC rigs are carried unfunded in
#390. A top-up is a money decision.

## Not in this wave, deliberately

#371 (inn visitor scheduling) and #388 (map talk_pool prose) went to v0.20 with
their scope measured and written down. #348 stays open on purpose: its close
condition is a **K5 discovery playtest** — a stranger plays and we measure
whether they FIND the property layer without being told. That verdict decides
whether slice 3 gets built at all.
