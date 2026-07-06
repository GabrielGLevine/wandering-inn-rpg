# 8b — Riverfarm: The Witch Quest (DESIGN)

Status: user-seeded; Fable-authored with art/quest/dialogue direction.
Canon: Riverfarm = Laken's emerging village-town; WITCHES arrive in
canon (Belavierr arc adjacent — we use the VILLAGE-WITCH register, not
the Stitch Witch herself: too big for a side arc). Wiki-verify all
names at content time; invented walk-ons get profiles + flags.

## 1. Maps (2)

- **Riverfarm village** (~24x16): timber-and-thatch register — a
  different biome voice from Liscor's stone (art: warm wheat/loam
  palette, low fences, haystack props, a communal longhouse, the
  emperor's rising earthworks hinted at the north edge as DRESSING
  [Laken himself out of v1 scope — flag]). Direction card: "harvest
  light" — golden day, deep-blue nights, hearth-window glows.
- **The witch's hollow** (~12x10): off-village forest pocket — bent
  trees (sway shader), a cottage, herb rows, a ritual clearing.
  Card: "green shade" — cool underwood grade, firefly-dense dusk,
  ONE warm cottage light. The contrast IS the storytelling.

## 2. Characters (3, profiles-first)

- **The Witch** (invented walk-on, canon-registered: a hedge-witch of
  the old craft — name wiki-checked against minor witches; fallback
  original + flag): appears elderly-or-young by light (two idle
  variants swapped by phase — a WITCH read, cheap via visual_states).
  Voice: barter-speak — never asks twice, prices in favors.
- **A village headman** (harried, suspicious of witchcraft, warmer
  once helped) — quest giver.
- **A charmed villager** (the quest's pivot — speaks in borrowed
  cadence until freed; dialogue direction: their pool line REPEATS
  the witch's line verbatim, the tell).

## 3. Quest design: "The Price of a Favor" (3-path parity)

Village suffers a "blight" the headman blames on the witch. Truth:
a villager BOUGHT a favor and won't pay the price; the craft is
collecting interest.
- **FIGHT:** drive off the craft's collectors (animated-briar
  encounter — new combatant, plant-class; arena in the hollow).
- **TALK:** broker the debt — [Diplomat]-line mediation between
  witch and villager (persuaded chain; the witch accepts a
  RENEGOTIATED price: a year of hearth-tending).
- **SKILL:** pay it YOURSELF — a field-skill gauntlet (cook the
  offering [basic_cooking], light the threshold candles [[Light]],
  observe the true knot [[Observe]]) — the craft respects competence.
- All paths: the blight lifts (village visual_states brighten — the
  map itself is the reward readout); the witch's cottage becomes a
  VENDOR surface (herb-craft consumables — M-GEAR items).
- Arrival: via the Door (8a) — the door attunes AFTER a Riverfarm
  rumor beat at the Guild board (M-DEPTH's board seeds expansions).

## 4. Dialogue direction (keys)

- Witch: "You want the blight gone. I want what I'm owed. One of
  these is easy. …Sit. Tea first. The craft has MANNERS."
- Headman: "We don't truck with witches. …We didn't USE to. Everyone's
  something these days."
- Charmed villager (the tell): whatever the witch's current pool line
  is, verbatim, wrong register.

## 5. Encounters/QA/scope

Briar collectors (2 variants) + a night-only wolf pack on the village
edge (first NIGHT-GATED encounter — phase-conditional spawn, small sim
seam, flag). Canonicals: `riverfarm_walkthrough` + one per divergent
quest path (C3 precedent). Non-goals: Laken content; Belavierr;
witch as party member; >2 maps.
