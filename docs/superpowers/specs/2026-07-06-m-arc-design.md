# M-ARC — The Demo's Story Arc (DESIGN, ratified)

Status: user-ratified 2026-07-06 (4 calls: Raskghar-tease climax;
landmark-quest act gates; context+veto party; GDI epilogue + free play).
Supersedes the seed (`2026-07-05-m-arc-seed.md`). F1 (the GDI cold open)
SHIPPED already (e424e62). Canon from wiki.wanderinginn.com throughout;
climax copy is user-taste-gated before ship (draft → morning review is
acceptable; unreviewed climax lore never ships silently).

## 1. Structure: three acts over the existing world

The acts are a quest-machinery layer (progress = pure function of
counters, the established architecture) + a journal act-line section.
Old saves land mid-act correctly by construction (acts derive from
counters they already hold).

- **ACT I — Arrival** (mostly exists): the GDI cold open (SHIPPED) →
  onboarding arc. GATE: first class gained + reached the street once
  (`classes any` + a street-arrival counter — trace what banks on first
  liscor entry; add a flavor accomplishment if none).
- **ACT II — Make a place for yourself** (the systems act): the four
  quests (errand, crate, cisterns, wrong_order) + classes/economy ARE
  the act. Journal act-line with 3-4 milestone beats keyed to
  accomplishments (results-only copy: "Liscor is starting to know your
  face."). GATE: 3 of the 4 quests completed + a second class gained
  (breadth bar — any second class: warrior/mage/helper/tactician/
  diplomat/barmaid/server all count).
- **ACT III — What stirs beneath** (new content, the climax chain):
  1. **The tremor beat**: post-Act-II sleep fires a world beat (Zevara
     summons you — the Watch found deep tunnels under the cisterns;
     dialogue chain w/ Olesm briefing).
  2. **The descent**: a NEW small `deep_tunnels` map below the sewers
     (cave family, darker pin, 1 route-fight vs Raskghar SCOUTS — new
     combatant pair, canon: hulking nocturnal dungeon-dwellers).
  3. **THE BOSS: an Awakened Raskghar** + 2 scout adds in a new
     `deep_warren` arena. Boss gimmick expressed in EXISTING machinery:
     high-HP bruiser + `slowed`-class status rider on its heavy swing +
     it FIELDS the moonlight-frenzy flavor as phased stats (data:
     phase-2 self-buff via... trace: no buff machinery exists — the
     honest v1 gimmick is positioning + adds + the slow rider; NO new
     sim effect types unless PF-adjudicated).
  4. **The seal beat**: victory → Zevara/Olesm resolution beats (the
     Watch seals the passage — "for now"; explicit Liscor-Dungeon
     expansion hook per the roadmap) → **the GDI epilogue**: gold-on-
     black (veil device): your classes/levels recounted, "the world
     keeps counting", "The story continues — wanderinginn.com" → fade
     back to FREE PLAY (post-game: encounters re-arm, quests replayable
     where designed, a Zevara post-game line).
- **Party (context + veto)**: the climax fields Relc (canon: Senior
  Guardsman; the met_relc ally mechanism generalized — a pre-descent
  dialogue beat where he joins, with a DECLINE option that lets you go
  alone [harder cell, measured]). Quest allies stay context-driven
  repo-wide; a free party picker is explicitly a future milestone.

## 2. Components

- Act layer: `data/quests.json`-family act definitions (counter-derived
  beats) + journal act-line (UI section per the skills-panel precedent).
- deep_tunnels map + deep_warren arena (C1 sewers idiom: dark pins,
  channel ambience, door_when gate on a new grate/passage in the sewers
  opened by the Act III trigger accomplishment).
- Raskghar art: PixelLab per the B recipes (scout + awakened variants —
  hulking, bear-wolf silhouette, moon-grey); combat_scale discipline
  (the Relc lesson: contained, feet-anchored).
- Boss cell: balance harness MEASURED + a GATED win band for the
  Relc-fielded comp (target ~0.6-0.75 w/ Relc, meaningfully harder solo
  — the decline-veto path is the hard-mode cell, measured-only).
- Epilogue: veil epilogue mode (F1's opener-mode precedent — third mode
  of one device).

## 3. QA

`arc_flow` canonical (act-gate assertions via journal payloads across
the whole arc — fixture-accelerated through Act II); `deep_descent`
(the descent + boss fight at a pinned seed) + a decline-path variant if
streams diverge (the C3 three-script precedent). Suite 41→43-44. Old
saves: act layer inert-correct (derives from counters) — save-compat
trace at the final review.

## 4. Non-goals

Multiple endings; Raskghar language/culture content (tease only); the
actual Liscor Dungeon (expansion milestone); Mrsha/Toren; New Game+;
free party selection (future milestone, banked).
