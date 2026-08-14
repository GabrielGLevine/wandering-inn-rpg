# Equipment gaps — content design sketch (#438 ruling 6)

> Status: **DESIGN SKETCH for user taste-pass** (Fable, 2026-08-13).
> Implementation dispatches after the user marks rows GO/edit. The
> ruling: add missing gear across tracks (spear first) via vendors,
> encounter loot, trap/puzzle/sealed-area treasure, quest rewards, and
> Hedault upgrades of existing gear.

## 0. The measured gaps (why each row exists)

- **Spear track has NO T2+** — `relcs_spare_spear` (+1, the Act I
  tutorial gift) is the best spear in the game; the spellspear spine
  reads above-window mid-game purely because every other spine takes a
  weapon bump it cannot (#469 finding).
- **Bow track thins after `training_bow`** (G4 quantified the
  ranged_hit economy; the hardware side has one real bow).
- **Death-magic implements do not exist** (necromancer/deathknight
  spines run bare-handed casting).
- **Civil spines carry no statless-utility gear** (multiclass ruling
  makes them fight; nothing in the shops helps them survive doing it).

## 1. Proposed items (names wiki-verify at build; post-bar → clearance)

| Item | Track | Tier | Source (per the ruling's five channels) |
|---|---|---|---|
| Guardsman's Pike | spear | T2 | **vendor**: Pallass forge stock (fiction: Drake standard issue) |
| Hedault-Trued Spear | spear | T2.5 | **Hedault upgrade** of relcs_spare_spear (keeps the gift's identity — upgrade, not replace; the enchant-commerce loop finally touches a weapon) |
| Wyvernbone Lance | spear | T3 | **sealed-area treasure**: the #398 counting-room pocket or a ruin cache — pick at build against loot density |
| Recurve of the Watch | bow | T2 | **quest reward**: the bow-shaped fork of a Liscor Watch quest (drove_off_rags already pays ranged_hit — the hardware follows the fiction) |
| Ashwood Warbow | bow | T3 | **encounter loot**: razorbeak_nest or road_mothbears rare row (loot rng is private-seeded — no rng-doctrine blast) |
| Graveflame Focus | death implement | T2 | **vendor**: Invrisil enchanter (Hedault sells what respectable shops will not display) |
| Femur Rod (working name — needs a better one) | death implement | T3 | **treasure**: crypt_lich encounter loot (F1's own encounter pays its own track) |
| Weighted Apron | civil utility | T2 | **vendor**: Coyle & Sons (armor that reads as workwear; small con bump, no combat fiction break) |
| Runner's Sandals of the Second Wind (post-bar name risk — verify) | civil utility | T2.5 | **quest reward**: a delivery-line fork |

## 2. Balance rails (binding on the implementing lane)

1. Every new weapon lands in the sim's SPINE_WEAPONS ladder at its act
   band; re-measure the affected spines — the POINT is to close the
   spellspear mid-game ceiling (expect its act2-4 ceiling drifts to
   ease toward window as the other tracks get their bumps priced in;
   any row that LEAVES window from new gear is a STOP-and-report).
2. Prices per the shipped economy curve (the gold intervals the
   compiler's economy planner now models — cite comparable-tier
   prices in-data).
3. Loot rows use the private-seeded loot stream (economy.gd) — zero
   rng-doctrine blast; treasure placements in sealed areas ride
   existing gates (no new gating).
4. Hedault upgrade = the #458-era trust-loop shape: item + gold, both
   paths' contents identical if a quest alternative exists.
5. tint-is-not-disambiguation for icons; every item needs its
   registration matrix (shipped-ids at next release cut, effect_text,
   sprite registry).

## 3. Out of scope (explicitly)

No armor-track overhaul (separate future sketch if wanted); no
consumable economy changes (#432's cap lane owns meals); no T4+
"endgame" tier until Act VI content exists.
