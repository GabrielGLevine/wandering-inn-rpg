# CHOICE-LOG entries owed by #396 (fold at merge)

`docs/CHOICE-LOG.md` lives on `main`, so the #396 close wave writes its
entries here instead of editing a file the branch does not own. **Controller:
append these to the `## 2026-08-05 — 390/396/397 wave, mid-session rulings`
block, continuing its numbering (it ends at 13).** Two of them amend rulings
already in that block — keep the original ruling and the amendment both, the
supersession is the record.

14. **Quest replacement over reskin (#396 design ruling):** `what_the_thicket_keeps`
    was retired intact and `a_winter_of_teeth` written beside it rather than
    re-dressing the thicket quest as wolves — a reskin would have re-semanticized
    five shipped counters, and a legacy save mid-thicket had to stay completable
    forever.
15. **Briar ally removed, briar fight re-gated solo (#396, user ruling
    2026-08-05):** nobody local walks you to the hollow anymore, so
    `briar_collectors`/`briar_collectors_deep` lost their `allies`/`ally_requires`
    and the sim gates were re-derived at solo strength in `sim_combat_batch.gd`;
    `hunter_will_come` still fields the shepherd, but only at `river_wolf_pack`
    in the village.
16. **`hunter_will_come` reused, semantics preserved (#396):** the frozen counter
    keeps its exact meaning ("this NPC fields as your ally at the wolf-pack
    encounter") and the new watch ask REPLACES the come-along ask IN PLACE in the
    hub's option array — the cursor-pin rule, so no legacy fixture's visible row
    indices shift.
17. **The edge cohort loses the un-accepted thicket offer (#396, accepted cost):**
    a save that heard the thicket brief but never accepted it can no longer accept
    it (the offer row is gone; the report rows survive), because keeping a dead
    quest's offer alive for one cohort would have meant shipping two live offer
    rows on one hub forever.
18. **Pre-bank cohort gets a text_variant, not a gated offer (#396):** a new save
    can win `river_wolf_pack` before ever talking to the shepherd, so the hub
    carries a `survived_wolf_night` variant and the offer row stays normal —
    accept-then-immediately-resolve reads as intentional, and the spec's
    `watch_stood` fallback stays unfired unless a playtest verdict says the flow
    reads glitchy (close-wave playtest verdict: it does not).
19. **The offering pot is a GATED CONTAINER, not a variants swap (#396 Lane C —
    amends ruling 10):** ruling 10 chose the `variants` idiom; the shipped shape
    is `contains` + `contains_when {heard_the_makings}` with a `visual_states`
    filled-state observe (`anchor_stone_pedestal` + `memorial_plot` idioms).
    Same outcome ruling 10 wanted — the pot is never structurally hidden and is
    byte-identical until the quest opens it — reached with the mechanism that
    actually exists for containers.
20. **Retirement is a registry, not a deletion (#396 Lane D — implements ruling
    9):** `RETIRED_ACCOMPLISHMENTS` shipped, `test_content`/`test_reachability`
    honor it (counter retired, consumers legal, producers forbidden), and
    `test_reachability`'s nested retirement asserts now HALT with a red exit code
    instead of printing into a green run — the class of validator hole that made
    the registry necessary.
21. **Lamb pen gate dropped, as ruling 13 directed (#396 close wave):**
    `hunters_lamb_pen` is present unconditionally now; both new quests' copy
    points at "the lamb pen" and fresh saves never bank the retired quest's
    `thicket_answered`.
22. **One adjudicated voice pass, ten amendments to DRAFT-FINAL copy (#396 close
    wave):** the new card `docs/dialogue-voice-cards/riverfarm-shepherd+bark.md`
    indicted two announced prose triads (bible ban 7 — the corpus's only other
    enumeration, `rags_meeting`, deliberately miscounts), three buttons outside
    the file's one granted peak, one sentiment-then-deflect, one soft antithesis
    on a speaker whose grant is pinned in a legacy node, and Eloise's hard
    `, not` antithesis; the shepherd's file now carries TWO cohort-disjoint peaks
    (legacy "Fences before deer.", live "Wolves and me both…") and that split is
    ruled, not accidental.
23. **Two stale map voice baselines re-snapshotted as bookkeeping (#396 close
    wave, disclosed):** `floodplains.json` and `witch_hut.json` were red against
    `docs/dialogue-voice/baseline-maps` before this branch existed — PR #399
    (#390 art drain) changed `sprite` fields in them and never regenerated the
    maps baseline. Proven prose-identical (the whole diff is two sprite ids and a
    comment), so re-snapshotting launders nothing and the maps gate is CLEAN
    again for everyone downstream.
