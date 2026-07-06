# M6 Canon Class Taxonomy — TWI wiki grounding for action-driven classes

**Status:** Fable spike deliverable (M5 downtime, 2026-07-02). Synthesizes three wiki
research passes (`.superpowers/spike/wiki-{leveling-system,warrior-line,mage-utility}.md`
— full citations there; fetch via the `wiki.wanderinginn.com` mirror, Fandom 402s bots).
Direct input to the M6 spec. User-locked M6 mechanics this maps onto: opaque-until-sleep,
consolidation offered-at-sleep, ~20–25% split friction, tight ~8–12 class tree.

## 1. What canon hands us for free (use verbatim)

- **Sleep-gated announcements** — already our sleep beat. Canon: the *announcement* is
  sleep-gated; qualification is immediate. Matches opaque-until-sleep exactly.
- **10-level rhythm** — evolutions and capstone Skills land at 10-level intervals;
  off-interval class changes are canonically "substandard." → Evolution checks fire at
  levels 10/20/...; capstone = guaranteed strong Skill at each 10.
- **Weapon-focus evolution is literally canon's worked example** — "a [Warrior] might
  decide to solely focus on... a spear, which might result in them becoming a
  [Spearmaster]."
- **Multiclass friction is canon text, not our invention** — "easier for a person with
  one class to level than someone with multiple"; 2+ well-leveled classes rarely pass 30
  in any. Our ~20–25% target is a faithful mechanization.
- **Consolidation** — canon rules we adopt: secondary's Skills fold into the merged
  class; merged class levels via EITHER parent's actions; merged level can be lower than
  the sum (canon: can even lower cumulative level). Canon examples: [Warrior]+[Strategist]
  →[Commander]; [Barmaid]+[Princess]→[Worldly Princess] (Lyonette!); Rags→[Chieftain].
- **Leveling needs genuine challenge/passion** — grinding trivial fights shouldn't level
  (Erin never got [Tactician] from casual chess). → Counters only accrue from real
  encounters (balance-harness-relevant: no farming trivially-won fights; simplest rule:
  counters award only when the encounter was live — enemies could deal damage).
- **Naming conventions:** brackets always; Basic/Advanced + Lesser/Greater are SKILL
  prefixes; numeric Tiers 0–7 belong to studied SPELLS; evolved Skills can fully rename
  ([Power Strike]→[Minotaur Punch] — canon's own example).

## 2. Playable class tree (M6 ship set — 9 classes + 1 consolidation)

```
[Warrior] ──(sword focus @10)──> [Swordsman]        (→ [Swordmaster] post-demo)
     │  ───(spear focus @10)──> [Spearmaster]        (Relc's class — ally resonance)
     │
     └──+ [Mage] consolidation offer ──> [Spellsword]
     
[Mage] ────(ice focus @10)────> [Ice Mage]           (→ [Cryomancer] @20, post-demo band)
     └─────(fire focus @10)───> [Fire Mage]          (→ [Pyromancer] @20)
     └─────(balanced @10+)────> stays [Mage]         (generalist: broader kit, → [High Mage] @30)
```

Ship set: [Warrior], [Swordsman], [Spearmaster], [Mage], [Ice Mage], [Fire Mage],
[Spellsword], plus NPC-held [Innkeeper] (Erin), [Receptionist] (Selys),
[Barmaid]/[Princess] (Lyonette flavor). Next-tier names ([Swordmaster], [Cryomancer],
[Pyromancer], [High Mage]) appear in data as aspiration text only.

**[D] decisions embedded (USER-APPROVED 2026-07-02):**
1. **PC base class renames [Fighter]→[Warrior]** (save-version bump + data migration).
   Canon: [Fighter] is explicitly the *civilian, unarmed-leaning* alternate track (Axe/
   Fist/Knife Fighters) — a sword-swinging PC is a [Warrior]. Cost is one migration;
   fidelity gain is the entire tree hanging off the canon root.
2. **Consolidation target is [Spellsword], not [Spellblade].** Canon: [Spellblade] is a
   [Spellsword] *variant* whose Skills enhance an equipped artifact (we have no gear
   system); [Spellsword] is the true Warrior+Mage hybrid archetype. The vision doc's
   [Spellblade] example becomes the post-launch gear-era evolution of [Spellsword].
3. Mage evolutions use canon's TWO-step ladder ([Ice Mage] before [Cryomancer]) — the
   demo's level band (≤~15) reaches step one; step two ships as data for M7+.

## 3. Action-counter taxonomy (sim events → counters → classes)

| Counter | Source event (exists today?) | Feeds |
|---|---|---|
| `melee_hit` | attack_resolved hit=true by PC (exists) | [Warrior] |
| `sword_skill_used` / `spear_skill_used` | skill_resolved for skills tagged `weapon: sword/spear` (tags NEW in skills.json) | evolution pick at Warrior 10 |
| `spell_cast` | skill_resolved with mp_cost>0 (exists) | [Mage] |
| `ice_cast` / `fire_cast` | element tags on skills (frost_bolt=ice, flame_jet=fire) | evolution pick at Mage 10 |
| `damage_dealt` / `won_combat` | exists | level thresholds (both classes) |
| `used_magic`, `cleaned_the_inn`, quest counters | exist (M2/M3) | class gains, content gates |

Evolution rule at each 10-cap: dominant weapon/element counter ≥ 60% share and ≥ N uses
→ evolve (replacement semantics: new class inherits level, keeps granted Skills, kit
extends); else stay base (balanced [Mage] gets the generalist bonus instead). Numbers
are harness-tuned, not hand-picked.

## 4. Non-linear scaling + consolidation math (harness targets)

- Per-class power contribution weight `w(L) = L^k` normalized; harness tunes `k` so a
  5/5 split lands 20–25% behind a pure 10 in the standard matrix. Start k≈1.35.
- Consolidation offer: at sleep when both parents ≥ 8 and combined ≥ 18 (tunable).
  Merged level = ceil(0.67 × (L_a + L_b)) — reproduces the vision's W9+M12→S14 example
  exactly (21 × 0.67 → 14.07 → 14, ceil edge checked in tests). Skills fold in; merged
  class levels from either parent's counters (canon rule). Offer is refusable and
  re-offered at later sleeps (user-locked).
- Leveling pace: keep current compressed thresholds; make each 10-cap a visible spike
  (guaranteed strong Skill per canon cadence).

## 5. Skill kits (canon names only — no invented names without wiki backing)

- [Warrior] band: [Power Strike] (have), [Quick Movement] (canon, Ksmvr/Runner-attested
  — maps to our Dash flavor), [Second Wind] (canon: stamina restore → HP recovery skill),
  [Dangersense] (canon: danger alert → passive, telegraph AI intents in playback).
- [Swordsman]: [Quick Slash] (canon, Ksmvr), [Flash Cut] (canon, Numbtongue),
  [Devastating Slash] (canon, documented effect).
- [Spearmaster]: [Piercing Strikes] (canon, Ksmvr), [Lunge] — NOT wiki-verified, use
  Relc's documented spear kit instead when M6 authors it (his page has a full list).
- [Mage] band: keep frost_bolt/flame_jet/mana_shield/quick_cast (all canon-adjacent:
  [Frostbolt], [Flame Jet] Tier 2, [Mana Barrier] family, quick-cast ≈ [Battlemage]
  rapid-casting flavor); add [Light] (Tier 0 cantrip, out-of-combat utility — the
  Skills-outside-combat pillar).
- [Ice Mage]: [Ice Shard] (T2), [Icy Floor] (T2 — terrain control, fits our grid).
- [Fire Mage]: [Flame Scythe] (T2), [Flare Burst] (T1).
- [Spellsword]: folds both kits + one signature (canon [Spellsword] specifics are thin —
  author ONE new skill with a disclosure note, or use [Keener Edge] (canon, Yvlon)).
- Defensive/tank flavor exists in canon but is fragmented ([Shield Captain] etc.) — no
  tank class in the ship set; [Iron Scales] (canon, Relc's!) can be Relc's data flavor.

## 6. Hooks noted, NOT built in M6

- **Studied spells vs class Skills duality** (canon: mages learn spells from
  scrolls/books independent of level, capped at +20 levels above highest class). Our
  Dusty Scroll is already this pattern. M7+ hook: scroll-taught spells as loot/content.
- Skill self-creation ([Death Before Dishonor]), comma classes, de-consolidation
  (Jelaqua), circumstantial classes ([Wounded Warrior]) — flavor reserves, out of scope.
- Erin's Skill list + level history = ready-made M7 content vein (documented in the
  mage-utility spike file).

## 7. Confidence notes

Everything above traces to wiki citations in the three spike files EXCEPT: [Lunge]
(flagged invented — do not use), [Arcane Warrior] (unverified), the exact
Windfist consolidation chain (unresolved character). The spike files also list checked-
and-ruled-out names ([Bash], [Charge], [Iron Guard] etc. do NOT exist in canon under
those names) — M6 content authors must not use them.
