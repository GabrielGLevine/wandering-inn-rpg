# Onboarding Rev — Design (user-directed, playtest 2026-07-04 late)

Status: **APPROVED by user 2026-07-04** (user-designed via playtest directives
4/5/13/17/18 + ambush addendum; controller-codified; user reviewed the written
spec). Scheduled per §7: after M7 weapons. Balance items (8/9) land EARLIER in hotfix wave A and are
not part of this spec.

## 1. Classless start (directive 5)

- The PC starts with **NO class and no combat skills**. Combat hotbar
  shows Attack / Dash / End Turn only (no skill slots) until a class
  grants some.
- **Relc gives the PC their weapon** during the tutorial intro. Until M7
  ships real weapon items, this is a flavor beat + accomplishment
  (`received_weapon`-style); after M7 it becomes an actual equip.
- **Warrior is EARNED at the first post-spar sleep:**
  `warrior.gained_by: {sparred_with_relc: 1}` — the spar already banks
  exactly that counter (trivial suppresses all tallies), so the gate is
  clean with zero new machinery. Warrior L1 grants the existing 4-skill
  kit, which is what makes Ambush-as-part-2 teachable.

## 2. Tutorial part 1 rev — the spar (directive 4)

- **Training dummies deal ZERO damage and do not act** (no block
  mechanics exist, so they have no reason to move — user). Implementation
  seam: dummy combatant data gets a no-op AI profile / zero weapon die;
  if the AI layer needs an "inert" profile, that is a small sim-adjacent
  addition, flagged at plan time.
- New/changed tutor beats: an explicit **attack prompt** beat ("1, then
  Enter — hit it."), and beats explaining **[Power Strike]** and
  **[Piercing Strikes]** — but per §1 the PC has no skills during part 1,
  so the skill-explain beats MOVE to part 2 (Ambush). Part 1 teaches:
  move, attack, dash, end turn, sleep-to-grow.

## 3. Tutorial part 2 — the Goblin Ambush (directives 5 + walk-around fix)

- After the post-spar sleep grants [Warrior], Relc walks the player into
  `goblin_encounter_1` as tutorial part 2: tutor_lines on the REAL fight
  explaining skill use ([Power Strike]/[Piercing Strikes] now on the
  hotbar), fielding Relc (met_relc already banked by the intro).
- **PROXIMITY TRIGGER (user directive, late addendum):** encounters are
  currently interact-only and can be walked around — the road to Liscor
  must have a GENUINE ambush. New encounter field `trigger_radius: N`
  (Chebyshev): entering any cell within N of the encounter starts the
  fight (engine: a proximity check on the move path in `wi_game.gd` —
  free of the M6.5 refactor's file set). The ambush placement + radius
  must make every path to `liscor_gate` cross a trigger zone — no
  corridor. Non-tutorial encounters keep interact-only unless data says
  otherwise.
- **QA blast radius (why this lands HERE):** a mandatory trigger re-paths
  every canonical script that crosses the road (they currently skirt the
  encounters). Folding the trigger into this spec's execution gives ONE
  re-path window (Q1-style, budgeted in the plan) instead of two.
- Difficulty bar (directive 8, tuned in hotfix wave A ahead of this
  spec): a naive dash-forward player survives; winning comfortably wants
  Relc's skill advice. Relc himself is a high-level [Spearmaster] —
  visibly stronger than the PC, never killed by two goblins (directive
  9, also wave A).

## 4. Mage from Pisces (directive 13, reaffirms 2026-07-03 standing directive)

- The Dusty Scroll retires as the mage trigger (may stay as flavor).
  Pisces (Human [Necromancer], canon — Adventurer's Guild frontage, Zone
  E) teaches magic: a conversation/mini-tutorial banks
  `learned_magic_from_pisces`; `mage.gained_by` keys to it. The beat
  explains magic (MP, casting, lines) — the magic explainer the scroll
  never gave.
- **Class-gained toasts list the granted skills** (directive 17): "[Mage]
  class gained! — [Light], [Frost Bolt]…" (exact copy at plan time;
  results-only, no numbers — opacity rule intact).

## 5. Krshia quest discovery (directive 17, interim form)

- Pre-[Light]: interacting with the Dark Cellar shows "Too dark to see
  anything." (hotfix wave A ships this toast).
- With the grants-listing class toast (§4), the player can INFER the
  cellar wants [Light] — discovery, not instruction.
- Full version (pitch-black cellar interior lit by hotbar-cast [Light])
  belongs to the Three Pillars overworld-hotbar milestone (already
  spec'd there).

## 6. Helper visibility (directive 18)

- Helper L1's grant is invisible (lesser_stamina = passive no-op). Swap:
  **L1 grants [Basic Cooking]** (stew pot comes alive the moment Helper
  is gained — immediate visible payoff), lesser_stamina moves to L3.
  Threshold table otherwise unchanged.

## 7. Sequencing (controller recommendation, user to confirm)

The weapon-from-Relc beat presupposes weapon items → **this spec executes
AFTER M7 weapons+equipment** (interim flavor-only weapon would ship a
beat we'd immediately rewrite). Ladder: M6.5 (in flight) → M7 weapons →
**Onboarding rev** → Three Pillars. Wave A balance/UX fixes and §5's
interim toast land NOW regardless. §6 (Helper L1 swap) is data-only and
rides wave A too.

## 8. Open items (plan time)

- Classless player who slips past Relc and engages the ambush: dies and
  defeat-reloads (acceptable teaching moment?) vs. Relc intercept beat vs.
  road gating. Recommend: accept death-teaches for now; revisit at the
  next playtest.
- PC-death-= -defeat (directive 7) is a separate small sim change (post-
  D4 UI wave) but interacts with part 2 (Relc alive when PC drops must
  not mask defeat) — coordinate.
- Party building (directive 14): standing brainstorm agenda, not this
  spec.

## 9. ADDENDUM (M7 playtest, 2026-07-05): systems need EXPLANATION

Playtest verdict: all M7 systems WORK but nothing teaches them — the
equip flow went undiscovered (footer hint insufficient alone). Binding
additions to this spec's beats:
- **Relc's gift beat gains an inventory tutorial line**: after handing
  the spear, Relc tells the player how to equip it ("Pack. I key. Put
  it in your hand before you swing it." — exact copy at plan time,
  Relc-voiced), and part 2 doesn't start until the spear is equipped
  (or Relc comments if you face him still sword-armed — soft gate,
  decide at plan).
- Same principle everywhere this spec touches: every new system gets
  its explaining beat (magic via Pisces §4 already does this; audit the
  rest at plan time).
- INTERIM (ships in M-BEAUTY R3, before this spec executes): a one-time
  "Press I — your pack" toast on the first ITEM_GAINED, so the current
  build's players can find the feature at all.
- Other playtest notes deferred here by the user land at plan time.
