# Content Wave v1 — Sewers, Three Characters, Two Quests (DESIGN)

Status: user-directed 2026-07-05 ("substantial content generation: new
quests, locations, characters"), scope Fable-pinned; night track C per
`NIGHT-GOAL.md`. Canon source: wiki.wanderinginn.com (NEVER the fandom
mirror); every name/detail wiki-checked at content time; misses escalate
with flagged closest-canon fallback.

## 1. Location: the Liscor Sewers (one new map)

- **Why:** canon-rich (Liscor's sewers are a real early-arc location),
  ties the EXISTING street `sewer_grate` entity (it becomes a working
  entrance — its eerie green glow finally pays off), gives the game its
  first dungeon-flavored map, and hosts quest 1.
- **Shape:** ~20×14 map, `cave` biome family (16px sheet in-tree),
  entered via the street `sewer_grate` (door mechanism; grate keeps its
  interact toast for pre-quest flavor, gains the transition once the
  quest opens it — `visual_states`/dialogue-gated, trace the door
  gating precedent), exit back up. 2 encounters: **Shield Spiders**
  (canon Liscor-area monster; new combatant pair — reuse spider stats
  family if one exists, else goblin-stat reskin with a distinct sprite
  from owned packs/PixelLab) + one rat-swarm-flavored trash pack
  (canon-plausible vermin; keep names generic-diegetic if wiki lacks an
  exact match — flag it).
- **Atmosphere:** `moods.json` sewers entry — dark time-invariant pin
  (cave_mouth precedent: ~[0.30,0.32,0.45], vignette 0.45); 1-2 light
  anchors (grate light-shafts, phosphor patches); `pond_glints`-class
  ambience on water channels. Direction card appended to the map cards
  doc.
- **QA:** `sewers_walkthrough` canonical (enter → traverse → interact
  set → encounter → exit), plus quest-path scripts (§3).

## 2. Characters (three, all canon, all wiki-checked)

1. **Olesm Swifttail** — Drake [Tactician], Liscor's council clerk.
   Placement: Guild frontage or gate district. Roles: talk_pool (chess +
   tactics flavor), `observe`/`friendly_line` strings, QUEST 1 GIVER
   (sewers survey — a [Tactician] wanting maps/counts is perfectly
   in-character), and a resonance beat with the player's own [Tactician]
   (one dialogue variant gated on `classes.tactician` — the first
   class-recognition moment in the game; opacity-safe, flavor only).
   Sprite: Drake — PixelLab gen (Track B) or tinted stand-in +
   VISUAL-LOG.
2. **Lyonette** — human [Barmaid] (early-arc Lyonette: haughty princess
   fallen far; wiki-check her Liscor-era state vs our timeline — if her
   inn employment postdates our slice, flag + ship her as a street
   presence instead). Roles: inn/street talk_pool (voice: wounded pride
   thawing), QUEST 2 GIVER (social quest), [Helper]/[Barmaid]-recognition
   variant (mirrors Olesm's beat for the service line).
3. **Zevara Sunderscale** — Drake Watch Captain. Placement: gate
   district. Roles: talk_pool (dry, overworked), gate/watch flavor
   authority (the gate_guard defers to her in one line), quest-1
   completion witness (the Watch cares what's under the streets),
   `persuaded_someone` surface (one persuade option — feeds [Diplomat]).

## 3. Quests (two, three-path parity per the Missing Crate precedent)

**Q1 — "Something in the Cisterns" (Olesm → sewers):** scavengers/
spiders nest under the market; Olesm wants it RESOLVED and DOCUMENTED.
- FIGHT: clear the nest encounter (combat pillar).
- TALK: convince Zevara to send a Watch sweep (persuade chain — banks
  `persuaded_someone`; social pillar).
- SKILL: [Observe] the nest from a safe ledge and bring Olesm the
  layout (exploration pillar — the first quest USE of observe; requires
  Tactician or gates gracefully on knowing observe).
- Rewards: gold (Track D), `quest_completed`, an Olesm follow-up beat.

**Q2 — "The Wrong Order" (Lyonette, inn/street social):** Lyonette
botched a supply order; fix it before Erin finds out.
- FIGHT-ADJACENT: intimidate/strong-arm the supplier's scavenger problem
  (reuses a street encounter).
- TALK: smooth it over with Krshia (persuade — social; ties the shop).
- SKILL: [Basic Cooking]/[Basic Cleaning] field-skill save (make the
  short order stretch — work pillar via field dispatch).
- Rewards: small gold + a Lyonette warmth beat (talk_pool line unlock —
  her pool gains a variant post-quest; the first pool-growth precedent).

Both quests: counter-derived per the quests architecture (progress is a
pure function of accomplishments), journal lines, explaining beats
(onboarding §9 discipline), all player-facing text opacity/stats-clean.

## 4. QA + sizing

- +3-4 canonical scripts (sewers_walkthrough + one per quest path where
  paths diverge structurally; path-per-script per crate precedent, but
  Q2's three paths may share one script with branches if event streams
  allow — night's call, documented).
- Expected-red exposure: street map edits (grate transition, new NPCs)
  touch gate_district_walkthrough's assertions; sleep re-arm interplay
  if Track A landed. Disclose + close per O5 discipline.
- Content=data throughout; the ONLY sim-adjacent risk is the
  grate-as-gated-door mechanism — trace the existing door/`hide_when`
  machinery first; if a gated-transition seam is genuinely missing,
  that's a SMALL sim task with unit coverage, disclosed.

## 5. Non-goals

No new combat mechanics; no Erin quest arc (M-ARC's job); no sewers
boss (M-ARC climax candidate); no Mrsha/Toren (sprite + behavior cost
too high for a night); no schedule/AI movement for the new NPCs.
