# #571 / #513 mandatory-fee audit

Read-only content audit on main `79177b01` (2026-10-07), for #513 criterion 2
("every mandatory fee is recoverable"). Paths are under `wandering_inn_game/data/`.
All 70 negative-gold effects are dialogue effects, plus `fence_stock.json`.
The Act IV gate (`acts.json:41`) requires `lattice_forge_rune`,
`seal_kept_reported`, `price_of_a_favor_reported` and `brothers_job_done`.

## Mandatory fees (82g; 80g with [Bargain])

| Fee | Gold | Where | Gate it opens |
|---|---|---|---|
| Resonant catalyst | 18 | `dialogue/krshia_crate.json:674` | `door_awakened` → Riverfarm portal, price_of_a_favor |
| Invrisil travel-stone | 18 (16 with [Bargain]) | `dialogue/riverfarm_witch.json:301` | `invrisil_attuned` → brothers_job_done, lattice reading |
| Pallass sponsorship | 10 | `dialogue/selys_delivery.json:425` | `pallass_sponsored` |
| Pallass stone | 18 | `dialogue/krshia_crate.json:699` | `pallass_attuned` |
| Entry stamp | 2 | `dialogue/pallass_market_clerk.json:69` | forge-clerk permit |
| Forge permit | 5 | `dialogue/pallass_forge_clerk.json:174` | Grimalkin exam |
| Grimalkin exam | 8 | `dialogue/pallass_grimalkin.json:24` | `grimalkin_examination_passed` |
| Lift pass | 3 | `dialogue/pallass_forge_clerk.json:219` | `elevator_pass_stamped` → `lattice_forge_rune` |

Conditionally mandatory, each with a free route (fight, sneak, rune read or
[Charming Smile]):
- Coyle testimony, 1+1 then 10 (`invrisil_fixer.json:39–137,315`);
- Pisces talk, 5 (`pisces_magic.json:546`);
- Act II social fees, 2/3/2;
- the Tactician entry, which checks for 2g on hand without spending it.

The seal "kept fed" route costs 12 (`olesm_intro.json:268`).
**To verify:** the audit reports that this route skips `seal_warden_downed`. That
would contradict the 2026-08-12 ruling that the warden fight fires on every
descent before any ending resolves. Surfaced for a ruling; not changed in #571.

Everything else is optional: shops, enchanting, the fence, Erin's meal, the
room ledger, wagers, donations, the scribe and the broker. Beds are free.

## Gold that can pay them

- **Repeatable, no Skill needed:** the Selys board pick, 5g per waking
  (`once_per_waking`, cleared at sleep); standing deliveries, 2/3/2g with no
  per-waking cap; request-board bounties (1–5g at bronze); the serving tray (1g);
  regional slates and boards (2–3g). Pallass forge slips (2g) only pay after
  the lift pass.
- **Repeatable, Skill-gated:** cleaning, served meals, snares, bank loads, the
  lift overlook.
- **One-shot:** errands, Zevara, Olesm, caches and bounties. The road goblins
  pay 2g once and are retired afterwards. The optional Invrisil one-shots pay
  25 + 25 + 30, or 40 via the Coyle extortion route.

## Findings

1. **No hard soft-lock.** Every mandatory fee is reachable from a repeatable,
   Skill-free producer.
2. **The steepest grind is Pallass.** The Rogue journey paid all 82g within its
   142g spent, but took the 46g Pallass chain from optional Invrisil one-shots
   (80g). Without those, the chain costs about nine wakings of Selys picks.
   Pallass has no Skill-free income before the lift pass.
3. **Fragile net.** If the Selys pick became one-shot, the fallback would be the
   rotating 3-slot board and deliveries.

## Imperfect-spend variant to exercise (lane F)

- Arrive at the catalyst, the Invrisil stone and the Pallass chain near 0g.
- Skip the optional Invrisil one-shots; expose Coyle instead of extorting him.
- Recover only through the Selys pick, deliveries and boards, with the road
  goblins already retired.
- Log every waking spent on recovery in the ledger.
