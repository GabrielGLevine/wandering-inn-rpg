# Depth wave (#87 + #91 + #92 + #76) — plan (2026-07-13)

Issues carry scope (gap-2 briefs, repo-verified). This doc pins lane
ownership + the two seams.

## Lane split
- **L87 (feel, presentation-only):** combat_screen.gd/combat_playback.gd
  (speed setting + beat coalescing + skip affordance), sleep_veil.gd
  (plain-sleep skip), message_layer.gd (toast rhythm), world.gd/main.gd
  (map fade), settings_panel.gd (the Combat speed row — APPEND-ONLY, the
  #107 pin discipline). Zero sim change; all canonicals byte-identical
  under _is_qa().
- **L91 (endgame loop):** data/bounties.json + deliveries (standing:true
  skip + post_game repeatable postings — APPEND-ONLY, rotation windows
  re-derived), 3-4 T3-T4 respawning encounters in region map files,
  harness cells (append), the Chronicle (journal end-page + title card;
  settings.cfg persistence, run-facts-only). OWNS bounties.gd; if the
  delivery retire filter lives in wi_game.gd, L91 gets a NARROW
  exception on that one function only.
- **L92 (economy):** the use_item verb (wi_game.gd + skill_effects —
  L92 OWNS wi_game.gd except L91's narrow filter exception),
  items.json consumables + ability accessories + res-3 tradeoff item,
  vendor restock/commission nodes (witch/forge/guild dialogue files —
  L92 owns these three), combat_build equipment merge, boss drops via
  roll_loot, harness cells (append).
- **L76 (ambience):** CC0 sourcing pass (redistributable = public tier,
  no bundle dance; licenses noted in assets/LICENSES), data/audio.json
  ambience rows + the `ambience` kind on its own bus in WIAudio (L76
  OWNS src/audio/wi_audio.gd + default_bus_layout.tres — a NEW Ambience
  bus goes in the LAYOUT, not runtime add_bus: the web-silence lesson,
  ee5cc61), footstep per floor-family variation if gaps remain.

## The two seams
1. **L91×L92 gold flow:** L91 sets repeatable bounty PAY, L92 sets sink
   prices — both must stay inside the shipped per-tier pay/price bands
   (the economy lens; conservative v1). Controller reconciles totals at
   merge; neither lane invents a new band.
2. **Shared appends:** sim_combat_batch.gd (L91+L92 cells),
   qa/manifest.json + CLAUDE.md (all four) — object-level merges,
   surfaces re-derived at composition.

## Locks in force
Stats never visible (gear mods are visible-currency text); opaque-until-
sleep (Chronicle = facts of THIS run, never a missed-content list); no
player-scaling on the fixed-tier encounters; every new bus via the
LAYOUT; append-only rotation pools; balance-gate every combat-relevant
item/encounter.

## Exit criteria
Post-game player has a real loop (standing routes + respawn fights +
repeatable postings at tier pay); gold has destinations (consumables,
commissions, restocks); the L12-L16 capstones have worthy targets; maps
have audible beds; the composed gate green (units, harness, sweep, web
smoke incl. the audio-output tooth).
