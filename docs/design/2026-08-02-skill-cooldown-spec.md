# Skill Cooldowns — design spec (v0.17+ milestone candidate)

Status: SPEC ONLY — scheduled against the v0.17 candidate list, not slipped
into a wave. Recon evidence: wf_b87d9109 cooldowns reader (2026-08-02),
file:line cites verified against main @ 7fe8b85.

## Why (user direction, 2026-08-02)
Canon: [Skills] run on cooldowns; spells are mana-constrained. Today the
game has NO cooldown concept anywhere (sole "cooldown" string in the tree
is audio.json's SFX throttle) and combat dynamism suffers: optimal play is
spamming the same biggest active every turn. The goal is dynamism — varied
turns — not canon literalism for its own sake.

## Ruling 1: surgical, not systemic
Full canon adoption (cooldowns REPLACE AP for Skills) rewrites the action
economy (MAX_AP 4 / ATTACK_COST 2 / DASH_COST 1) and invalidates all 141
gated balance cells at once. REJECTED. Instead: a per-skill optional data
knob `cooldown_rounds` applied surgically to the spam set — the
damage_mult ≥ x2.0 family (power_strike, devastating_slash, spear_flurry,
spellbound_strike…) and the big AoE/line nukes. Pattern: the skill gets a
1-2 round cooldown and in exchange a modest AP reduction or effect bump,
so turns alternate big-hit / basic-attack / reposition instead of
big-hit×N. MP-costed spells keep MP as their constraint (that IS the canon
split: the per-fight MP pool, CHOICE-LOG:2012, is the spell limiter).

## Ruling 2: symmetric, AI-first
Enemies get the same cooldowns (fiction + fairness). HARD PREREQUISITE,
proven by probe: WICombatAI.take_turn breaks on the first refused action —
flagging power_strike unavailable cost the goblin chieftain its WHOLE turn
(16 dmg → 0, 4 AP unspent). The AI work lands FIRST:
- `_can_afford` (combat_ai.gd:234) gains `combat.skill_available(...)`.
- `_act_melee`:70 and `_act_guard`:133 hardcode power_strike behind raw
  AP>=3 — patch explicitly; on cooldown they FALL THROUGH to
  `combat.attack(foe)`, never return-false.

## Ruling 3: mechanics
- STAMP in `spend_skill_costs` (wi_combat.gd:351-362) beside
  `_mark_skill_used` — never in `use_skill` (resolvers validate range/LoS
  AFTER the gate chain; stamping early burns cooldowns on refused casts).
- ABSOLUTE stamps: `cooldowns[actor][skill] = round_number + n`, matching
  the terrain/status expiry idiom (skill_effects.gd:246). No tick loops.
- CHECK in `use_skill` at ~:329 next to the once_per_fight gate; public
  `skill_available()` predicate shared by sim, AI, HUD.
- `snapshot()` carries the per-combatant cooldown map, sorted ids
  (determinism discipline of `_terrain_snapshot`).
- Windup skills stamp at RESOLUTION, not declaration (slam's cadence
  already encodes the intent).
- Item-use synthetic skills (items.gd:25-33) are EXEMPT — no default
  cooldown in spend_skill_costs, only data-driven.
- Nothing persists: combat state is never save-serialized; fresh WICombat
  per encounter clears everything.

## Ruling 4: scope exclusions
- NO field cooldowns this milestone. Field casts stay free (stated design,
  effect_text.gd:79-85); once_per_waking props already pace the overworld,
  and a per-sleep cooldown strands players in the two bedless regions.
- once_per_fight stays a distinct concept (2 skills); revisit unification
  after the system beds in. windup_cadence stays.
- No `kind: spell|skill` classification pass yet — the two proxies
  (mp_cost 18 carriers, element 12) disagree on 7 skills and nothing in
  this design needs the discriminator. Note for later: mp_cost presence is
  load-bearing in 3 places (max_mp grant, quick_cast, sleep-beat line).

## Ruling 5: readout is legal
A cooldown is a combat resource of the same class as AP ("2 rounds" on
the slot badge + tooltip clause). The opaque-until-sleep lock governs
PROGRESSION text, not combat resources. Rendering: badge in
`render_bar_slots`'s skill arm (combat_hud.gd:387-392, the MP-diamond
idiom), clause via `_slot_info_line` — whose record must be WIDENED (it
already drops "Once per fight."; that narrowing is fixed in the wave-2
prereq). Refusals ride ACTION_REFUSED with reason "cooldown" (shipped
rendering path, toast-spec copy).

## Prerequisites already shipped (wave-2, 2026-08-02)
- `skill_affordable` once_per_fight hole closed (spent skill rendered
  bright + entered targeting + silently no-oped).
- `_slot_info_line` record widened.

## Cost honestly stated
Every gated balance cell moves (all 141 — the spam set IS the win-rate
backbone); expect a full authoring pass on bands, plus
sim_progression_pace shift (fewer casts = fewer tallies) and
sim_class_paths counter-model updates. test_effect_text: 119 EXPECTED_SKILLS
rows re-pin. ~46 QA scripts reference skill events; 5 pin payloads;
invisibility_combat_loop.json:64's "no cooldown" comment dies. This is a
milestone, not a wave.

## Open for the milestone plan
Exact skill list + numbers (start: 6-10 skills, cooldown 1-2, AP -1 on
the 4-AP entries); whether ROUND_CAP 30 needs headroom; harness authoring
order (bands first vs data first).
