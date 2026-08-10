# Decision packet: #412 martial re-scope · #413 [Dangersense] · #404 lockpick name

> Status: **SIGNED OFF** (user, 2026-08-09): #412 table + cut-mode **Option A**;
> [Basic Repair] → helper L2; #413 rogue L4 + passive aura APPROVED; #404 name
> ruled **[Pick Lock]** (user's name, replacing proposed [Lockpicking]) as an
> ACTIVE skill — deliberate cast, not passive; Explicit-Skill-Use compatible.

One sitting, three decisions. Phase 2 (412-apply, #403 pockets, #413 build)
waits on this packet; Phase 1 (#414 steel-thread, #400 carried rows) is
already running and does not.

## 1. #412 — martial field-skill keep/cut/move table

Survey method: `classes.json` grants ∩ `field: true` entries in
`skills.json`. The martial field pool is entirely warrior's:

| Skill | Granted | Field semantics | Proposed | Rationale |
|---|---|---|---|---|
| [Greater Strength] | warrior L7 | force (`skill_gates` in deep_tunnels, mercantile_alleys, trapped_halls) | **KEEP** (ruled) | Force applications a fighter plausibly has. No data changes. |
| [Power Strike] | warrior L1 | `cuts: true`, sword-gated | **RETRACT field** (ruled) | Combat strike is not a field tool. Combat context untouched. |
| [Piercing Strikes] | warrior L1 | `cuts: true`, spear-gated | **RETRACT field** (proposed — DECIDE) | Same reasoning as [Power Strike]; not named in the ruling, so flagged rather than assumed. |
| [Basic Repair] | warrior L8 | `repairs: true` | **MOVE → helper L2** (ruled direction; L2 is helper's first empty grant slot) | Helper-class identity per Three Pillars. |

### The cut-mode fork (the one real design decision)

`cuts: true` holders are EXACTLY [Power Strike] and [Piercing Strikes].
Retracting both orphans the briar CUT mode — briar gates (wave-1 #398, and
the #403 wave-2 pockets about to be built) need ≥2 access modes, and cut is
the martial half of the burn/cut pair (`burn_counter`/`cut_counter` engine
support shipped in #398).

- **Option A (recommended):** retract both strikes; move the `cuts` carrier
  to **[Basic Swordwork]** (warrior L1, already shipped, currently
  combat-only) — add `field`+`cuts`. In-fiction: field blade-handling is a
  tool use, not a combat strike — exactly the "genuinely martial-flavored"
  bar the ruling sets. Briar cut mode re-anchors mechanically (warrior L1
  keeps kit diversity for gates).
- **Option B:** retract [Power Strike] only; [Piercing Strikes] stays the
  martial field cutter. Honors the letter of the ruling, but a spear
  combat-strike as the surviving field tool is the same smell the ruling
  names.

### Blast radius (enumerated for 412-apply; every file audited at apply)

- **[Power Strike] field refs:** `briar_arch_cut.json` (CASTS it as the cut
  mode — re-anchors to the Option A/B carrier), `briar_arch_locked.json`
  (absent-asserts + L5-proof comment re-derive), `martial_field_loop.json`
  (derived hotbar pins: armed bar slot 8, unarmed absence proofs),
  `field_skills_loop.json`, `tutorial_flow.json`, `hotbar_tab_loop.json`,
  `inventory_loop.json`, `item_use_loop.json`, `second_wind_loop.json`,
  `arc_flow.json`, `level_up_loop.json`, `defeat_ally_alive.json`,
  `journal_categories.json`, `class_evolution_loop.json`,
  `combat_move_input.json`, `defeat_reload.json` (most are combat-context —
  unaffected — but each is checked, not assumed).
- **[Piercing Strikes] field refs:** `briar_arch_locked`,
  `martial_field_loop`, `tutorial_flow`, `journal_categories`,
  `class_evolution_loop`, `field_skills_loop`, `inventory_loop`.
- **[Basic Repair] refs:** `martial_field_loop` (derived bar slot + two
  repair legs) — re-anchors to a helper-granted fixture or the legs move to
  a helper QA script.
- **[Greater Strength]:** KEEP ⇒ zero changes; gates listed above stay.

## 2. #413 — [Dangersense] spec

**Canon:** ATTESTED. Wiki *Skills Effect/D*: "Alerts the user when they are
in immediate danger." — ch **1.29** (Book 1, far under the Book 17 bar).
Variants exist later ([Dangersense (Ward)] 8.23) — not used.

**Already in the data:** `skills.json` has `dangersense` (combat-only
context today) and **warrior already grants it at L5**. This issue extends
it to the field, it does not invent it.

**Proposed spec:**
- **Form:** passive-while-held (Explicit-Skill-Use doctrine: tiresome
  actives become passives; [Even Footing] is the shipped passive precedent —
  follow its schema, no hotbar slot).
- **Mechanism:** render-layer warning region (overlay tint / edge markers)
  drawn from existing `encounter_when` proximity-trigger radii, visible in
  field mode only, gated on the skill being held. No new sim system — data
  radii already exist; this is presentation + a gate predicate.
- **Grants:** warrior L5 (already shipped — no change) + **rogue L4**
  (currently an empty grant slot; gives the martial AND Rogue exploration
  identity the ruling wants).
- **QA:** negative leg WALKS a route that skirts a revealed radius and
  asserts no `combat_started`; windowed read folded into the batch-close
  steel-thread run (its route crosses one ambush-trigger field by brief).

**Needs from you:** ACK on rogue L4 (warrior L5 is already live), and ACK
on passive-aura form.

## 3. #404 — lockpick [Skill] name

Wiki search came up EMPTY: *Skills Effect/L* has only protective locks
([Lock Door] 9.34 — also over the Book 17 bar); site search for
lockpicking/burglary surfaces only the Raskghar race page, no bracketed
[Skill]. **No attested lockpicking [Skill] at or below Book 17 exists to
cite.**

**Proposal (invented, needs explicit ACK per [Rope Work] precedent):**
**[Lockpicking]** — plain-named, tool-flavored, Rogue-kit. Alternative if
you want more voice: [Picklock's Fingers]. Until ACK'd, no wave-2 pocket
uses a locked-door third mode.

## Decisions requested (one reply covers all)

1. #412 table: sign off KEEP/RETRACT/MOVE as proposed? Cut-mode fork:
   **Option A** (recommended) or B?
2. [Basic Repair] destination: helper **L2** OK?
3. #413: rogue **L4** grant + passive-aura form — ACK?
4. #404: **[Lockpicking]** (invented) — ACK, or pick the alternative?
