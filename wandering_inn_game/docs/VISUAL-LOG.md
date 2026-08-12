# Visual log (game-scoped)

Insertion: tail — append new rows/dated sections at end of file; closing a
row deletes it in place. Root drain directive: `docs/VISUAL-LOG.md`.

- blink afterimage reads FAINT in windowed stills (blink_bypass_loop
  00_blink_streak) — mechanically proven + reduced-motion covered, but
  the streak could take one brightness/length step if playtest agrees
  (same family as the windup-overlay brightening precedent).

## 2026-07-17 — v0.10.0 release rotation

- **Vault post-fight interior reads borderline-dark** (delve_fight
  04_vault_won: player + chest near-invisible after the construct falls).
  The dungeon grade was user-calibrated at v0.9.0; the vault's post-combat
  lighting may want the same ~lift. Not a blocker — flagging for the next
  calibration pass.

## 2026-08-06 — #398-p2 collapsed gallery

- **Timber/beam sprite wanted for the fallen beam** (deep_tunnels
  `collapsed_gallery_beam`, cell (14,2)). It ships as `boulder` under a
  brown tint, and the #398-p2 review called that out: tint is not
  disambiguation, so a rock recoloured brown does not read as a fallen
  support beam next to a rubble plug and a tarred crate. Ask: one
  horizontal timber/beam prop at cave scale; the [Greater Strength] mode
  is the only one whose blocker has no sprite of its own.

## 2026-08-12 — #439 Act I-III climax retune

- **Two new combatant rows ride an existing sheet.**
  `shield_spider_matriarch` shares the `shield_spider` rig and
  `raskghar_pack_leader` shares `raskghar_scout`; each is separated from
  its base row only by a larger `combat_scale` (0.30 -> 0.42, 0.64 ->
  0.72) and a distinct `display_name`. Scale-plus-name is the same grade
  of tell as a tint, and unlike the roster's other sheet reuse
  (`ruin_warden`, `bat`) these two stand ON THE BOARD BESIDE the row
  they borrow from — the cistern nest fields two Shield Spiders and the
  Matriarch, the warren mouth fields a Scout and the Pack-Leader — so
  this is the disambiguation case, not the reuse-across-scenes case.
  Ask: one bulkier eight-leg silhouette for the Matriarch (a broader
  carapace reads at 16px) and one Raskghar carrying a visible mark of
  rank for the Pack-Leader. Until then the size step is doing work it
  cannot fully carry.

