# hermit_antler_order.json — companion notes

**Narrative purpose:** the Runner's Guild delivery that becomes a story — the
Antler Order give-beat + all three resolution beats (spec §2 "The Antler
Order"). Tone target: quiet barter-ethics; the FIGHT resolution is the game's
gentlest moral consequence (paid less, not punished).

## Canon cites
- **Corusdeer** (wiki.wanderinginn.com/Corusdeer, fetched 2026-07-06):
  antlers "oaken brown at the coronet, cherry red at the tips"; horns stay
  reactive after removal, "igniting from a slight amount of friction";
  pulverized horn goes into matches and heat-generating potions; the
  adventurer guild pays "four silver for each antler." Lines built on this:
  the ember-at-dusk herd read, "friction wakes them, pack them apart," the
  winter stills, and the taken-antler price being "Guild rate. Four."
  (re-denominated to gold for our economy — flag below).
- **Shedding:** the wiki page does NOT confirm natural shedding (only
  hunting). Real cervids shed annually; the spec's shed-antler mechanic is a
  plausible extension. **OPEN (canon-extension flag):** shed corusdeer antler
  as gatherable is our invention on top of canon harvesting.
- "Shed velvet" in the remedy = antler velvet, real-cervid texture, no canon
  contradiction found.

## Invented / OPEN
- **"Sorven"** — ORIGINAL name for the profile's hermit-alchemist
  (staging profile says ORIGINAL+flag). Rename freely; no canon collision
  found in quick checks, but re-verify at wiring time.
- **Gold amounts** (2 delivery / 12 shed / 10 traded / 4 taken): sized
  against the D2 price bar (day's inn work ~4 gold, charm 5, jerkin 24).
  The 12/4 split IS the quest's ethics statement — keep the ratio even if
  the absolute numbers move. Taken=4 deliberately echoes canon's
  four-silver guild rate.
- **Positive-gold dialogue effect** `{"gold": N}`: only negative spends
  exist in shipped graphs (krshia_crate). Assumed symmetric — verify the
  effect applier at wiring time.

## Wiring notes (owned by implementation tasks, not this draft)
- `culled_corusdeer` — banked `on_victory` of the corusdeer herd encounter
  (herd scatters after, per spec §1).
- `gathered_shed_antlers` — banked by the shedding-ground micro-area prop
  ([Observe]-at-dawn beat, spec §2 SKILL path; phase-gating open).
- `traded_for_shed_antlers` — banked by a new option in Krshia's graph
  (requires `took_hermits_remedy`, trades `hermits_remedy` item away).
  Suggested Krshia line: "Hrr. The hermit's willowbark salve? My knees say
  yes before my pride finishes arguing. Antlers are in the back — take
  them, and tell him the trade stands next season too."
- `hermits_remedy` item id — needs an items.json entry (quest item, no
  combat stats).
- Quest `the_antler_order` beats suggestion: hear (`heard_antler_order`) →
  resolve (`antler_order_done`).
- The give-beat assumes the player CARRIES the delivery on first meet
  (no separate pickup accomplishment). If M-DEPTH's board wants to seed it,
  gate the delivery option on a board accomplishment instead — one-line
  change.

## Softlock audit
Hub has hidden options + ungated "Just passing." exit ✓. Every other node
has an ungated option ✓. No start_combat in this graph ✓.
