# Three Pillars / World-Skills — Design (v1) + Playtest-Content Slice

Status: **APPROVED by user 2026-07-04** (interactive brainstorm; all option
picks below are user decisions). Execution sequencing (user-approved):
M-FP → **slice** → M6.5 decomposition → M7 weapons → **Three Pillars
execution**. The slice is content-only and ships first because content is
now gating leveling playtests (user directive 2026-07-04).

## 1. Goal

The game must hit **Social · Combat · Puzzles/Exploration** without
overweighting combat (standing three-pillars mandate). Non-combat classes
level from real play using the M6 counter machinery unchanged; [Skills]
act in the world, not just in fights or dialogue gates. Playtest driver:
a player must be able to make *different kinds* of progress and feel the
split-penalty / evolution / consolidation systems react.

## 2. Class lines (user pick: Helper line + Tactician)

**Canon rule:** every class/skill name below is verified against the
Wandering Inn Wiki at content-authoring time; where a name misses, the
nearest canon class substitutes (flagged in the ledger). Candidate
fallbacks: [Helper]→[Worker]/[Assistant]; kit skill names re-sourced from
wiki skill lists.

### 2.1 [Helper] — second BASE class (peer of warrior)
- Granted like warrior: earliest qualifying non-combat accomplishment
  (first chore) — mirrors "action-driven, never chosen".
- **Counters** (banked via prop/NPC interactions, all opaque-until-sleep):
  `cleaned_table`-type (cleaning), `served_customer` (service),
  `delivered_item` (errands), `cooked_meal` (kitchen). Exact counter ids
  unify with existing `cleaned_the_inn` seam at plan time.
- **Kit:** level 1 folds in [Basic Cleaning] (already shipped). +2–3
  service skills from wiki lists (e.g. lesser stamina/tireless-type
  passive; a serving-speed skill). Kits stay small like warrior's.
- **Evolution at 10** (same dominance machinery): serving-dominant →
  **[Barmaid]** (canon, Lyonette precedent) / errand-dominant →
  **[Server]** or courier-flavored canon equivalent. Balanced → the M6
  Generalist path applies unchanged.

### 2.2 [Tactician] — EARNED multiclass (mage pattern)
- `gained_by`: MUST key off pre-class actions (mage/dusty-scroll
  precedent) — a plain-interact observation chain (e.g. studying the
  notice board / sewer grates) or the slice quest's skill-use path
  banking a `studied_*` accomplishment. NOT [Observe]-driven ([Observe]
  is Tactician's own grant — circular). Exact gate tuned at plan time
  against slice content.
- **Kit spans pillars deliberately:** [Observe] (field skill: info toast
  about the faced NPC/prop/encounter — flavor + hints, no stats/numbers,
  opacity rule applies), one combat positioning skill (e.g. a
  flank/reposition effect using existing combat sim verbs).
- Cerebral-pillar anchor; also the proof that one class can grant both
  field and combat skills.

### 2.3 Explicit non-goals (v1)
No Helper+Tactician consolidation content (machinery supports it; content
deferred until both lines demonstrably level in playtests). No third line.
No [Innkeeper] (Erin's identity; player earns toward it post-launch, if
ever).

## 3. Overworld hotbar (user pick — with facing-cell + ambient model)

- **Component reuse is a requirement, not an option:** the combat hotbar
  (UIChrome 52×52 slots, number keys, skill icons from sprites.json) is
  extracted/shared, not duplicated. This is the standardization directive
  applied; the M6.5 decomposition should extract it with this consumer in
  mind. Field mode shows known skills carrying a `field` tag.
- **Activation:** number key → skill applies to the FACED cell first
  (same raycast as interact): faced prop with a matching
  `requires_skill`/`on_skill_use` responds; faced NPC responds if the
  skill defines an NPC effect ([Observe]). No valid target → **ambient
  fallback** for self/aura skills ([Light]); otherwise the established
  refusal toast pattern.
- **Data:** `skills.json` entries gain `field: true` + optional
  `field_target` semantics. Prop data pattern (`requires_skill`,
  `on_skill_use`) is UNCHANGED — the hotbar is a new trigger for the same
  seam. Plain interact keeps working everywhere it does today.
- **Sim:** extends `WIGame.use_skill` (known-skills gate, [Light]
  precedent). New bus events + `ui_*_rendered` confirmations per QA-first
  rule.

## 4. Playtest-content slice (ships FIRST, right after M-FP F)

Content-only — uses TODAY'S interact pattern; zero dependency on the
hotbar or on M6.5. Purpose: leveling variety becomes humanly playtestable
now.

1. **Inn work-loop:** dirty tables re-dirty after sleep (respawner valve
   precedent), a serving/delivery interaction chain (Erin/Lyonette props +
   NPC handoffs) — Helper counters bankable in repeatable loops.
2. **Relc spar loop:** already landed (W2: persistent, re-fightable,
   `sparred_with_relc`) — the combat-counter valve. Slice adds nothing;
   listed as a pillar leg.
3. **One gate-district quest, THREE solution paths** (fight / talk /
   skill-use), each banking different counters, all reaching the same
   completion beat (errand fight-OR-intimidate precedent, +1 path).
   Setting uses the new district (Krshia's stall / Guild frontage / sewer
   grates are authored hooks). Flavor authored at plan time, wiki-checked.
4. **[Helper] class data** (base class + level 1–3 + counters) ships WITH
   the slice so the loop actually levels something. Tactician waits for
   the hotbar ([Observe] is its core).

Slice acceptance: a human can, in one session, level warrior via spar,
level Helper via chores, feel the split penalty, and see the quest resolve
three ways. QA scripts per loop + per quest path.

## 5. QA + balance

- Every loop/path: canonical QA script asserting domain event AND
  `ui_*_rendered` (work_loop, quest per-path scripts).
- Field-skill QA: hotbar activation script (Q-lane, when hotbar lands).
- **Pillar balance metric** = content audit, not sim harness: counter-
  banking opportunities per pillar reported at each milestone F gate.
  Combat balance harness unchanged.

## 6. Engine deltas (complete list)

| Delta | Where | Size |
|---|---|---|
| `field` tag + facing-cell/ambient dispatch | `skills.json` + `WIGame.use_skill` | small |
| Shared hotbar component | M6.5 extraction + field consumer | medium (mostly M6.5's) |
| Serving/delivery interaction chain | data + existing prop/NPC seams | content |
| Nothing else | sim/leveling/evolution/consolidation | zero — M6 machinery as-is |

## 7. Open items (resolve at plan time, not user-blocking)

- Wiki canon pass: [Helper]/[Server] names + kit skill names.
- Exact counter ids + Tactician `gained_by` gate values (balance-harness
  style volume check against slice loops).
- Quest flavor/text (content authoring, canon-checked).
- Whether [Observe]'s info toast needs a new bus event type or reuses
  `toast`.
