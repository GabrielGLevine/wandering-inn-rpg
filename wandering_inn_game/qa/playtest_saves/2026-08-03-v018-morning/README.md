# Morning queue — v0.18 wave-1 verdicts (2026-08-03, one sitting)

Every ask ships with a prepared state or a one-page read. Load lines
assume the windowed game (`/usr/local/bin/godot --path wandering_inn_game`).

## Picks (paper reads, ~15 min)
1. ~~**Martial exploration Skills**~~ **DECIDED 2026-08-04 on user
   directive ("get them on the board so they're not lost") — this item no
   longer blocks.** Picks made and filed: **#380** funds [Even Footing],
   [Greater Strength], [Broader Shoulders], [Durable Picks],
   [Bar Fighting] + the [Ice Floor] grant. Split out on distinct
   blockers: **#381** [Basic Repair] (needs #348 slice 2), **#382**
   [Rope Work] (INVENTED name — the one thing still wanting your ACK),
   **#383** [Flame Jet]→corpse package. Tier C stays behind #335.
   Rationale in CHOICE-LOG "2026-08-04 — board hygiene". All revocable;
   read #380 if you want to overrule the slate rather than the doc.
2. **[Perfect Reduction]** — CHOICE-LOG v018-close #4. Spec fenced it as
   dialogue color; W5 shipped it as an Alchemist L14 grant with an
   ATTESTED 6.39 citation. KEEP THE GRANT or RESTORE THE FENCE (reversal
   is one row + a cell re-run either way).

## Eye/ear states (~20 min)
3. **#347 bestowal FEEL** — load `playtest_saves/2026-08-03-v018-w2-demo`
   slot, sleep once, read the logged bestowal + why-line (debug overlay
   F3 shows it). JUDGE: does "Peacebinder" land as something a world
   would NAME you? Alternates in the demo notes (Gentle Hand, Quiet
   Diplomat). Also: rarity target (deliberate-pacifist-reachable ~50%
   at horizon 50, or rarer?) and migration timing (classes.json next
   wave, or another dev-only taste wave?).
4. **Moods eye-items** (art-feel-review/v017-r2-moods/fix_after/): (a)
   riverfarm longhouse vignette 0.4 — the pass's only day-frame change;
   (b) pallass_forge lamps burn at noon, pallass_market's deliberately
   do not — sky-test-derived, overrule either; (c) den_shop classified
   sky-bearing on a 0.02 grade delta (flagged, unedited).
5. **New classes in play** — load any save, Settings→difficulty as you
   like; the Alchemist/Druid canonicals' windowed sets are under
   qa_output/ after any sweep; or just play a fight and read the
   cooldown badges (now tinted).
6. **#350 lease gate** — CHOICE-LOG v017-close #14: the lease gates on
   visited_own_room (walk upstairs once), not story progress. Confirm
   or name a different gate.

## Standing (unchanged)
Full sitting (14 states), Raskghar third-strike ear-gate, #195 listen,
gossip-ladder adjudication, #253.

## Appendix — the [Ice Floor] paste block (CHOICE-LOG v018-close #8)
Lands with your picks (needs a granting class + three authored lines +
the bespoke ice tile per the P1 ordering constraint):
```json
{"id": "ice_floor", "display_name": "[Ice Floor]", "icon": "icon_frost_bolt",
 "contexts": ["exploration"], "field": true, "freezes": true,
 "freeze_toast": "<authored>", "field_ambient": "<authored>",
 "description": "<authored>"}
```
