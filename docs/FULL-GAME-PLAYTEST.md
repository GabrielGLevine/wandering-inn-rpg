# Full-Game Playtest Script (v0.4.1 candidate)

A prescriptive top-to-bottom playthrough for a human tester. Follow in
order; each stage says what to DO, what SHOULD happen, and what to WATCH.
Expect 2.5–4 hours for the whole script; the stage boundaries are save
points, so it splits cleanly across sessions (Esc → save).

**Controls**: WASD/arrows move (hold to keep walking). Walk INTO a person/
prop/door to interact ("bump"). `I` inventory · `J` journal · `Esc` menu +
save/load · number keys = hotbar skills (field + combat) · in combat:
arrows move your unit, numbers act, `E` ends turn, Enter/Esc confirm/cancel
the Dash gate.

**Reporting**: note anything that makes you stop and squint — screenshot it
(Cmd-Shift-4 region). The bar: would a first-time player screenshot this to
mock it, or bounce off it? Rank findings when you send them: (1) would-
screenshot bugs, (2) friction/confusion, (3) what genuinely landed.

---

## Stage 0 — Title & New Game

1. Launch. Title screen: New Game / Continue / Playtest States (debug).
2. Start **New Game** → character creation: a 2×3 grid of animated
   sprites (Human/Drake/Gnoll × two builds). Pick a **Drake or Gnoll**
   (non-human catches more sprite bugs), name yourself.
   - WATCH: every card animating, no frame garbage; name accepted.

## Stage 1 — Tutorial (the inn, first morning)

3. Follow the opening beats: Erin greets you; find **Relc** and take the
   spar. Combat tutorial fires (move pool vs AP, hotbar, End Turn).
   - WATCH: tutor panel text fits its parchment; the spar is winnable
     classless; combat readout shows HP/MP numerals (never STR/DEX
     anywhere — that's a bug if you see raw stats).
4. Post-spar: the gift beat, then the ambush beat, then you're pointed at
   the street. Do NOT rush out — first walk the inn:
   - Bump the **pantry door** (east wall): plain-door flavor toast for now.
   - Erin dialogue: options readable, no page opening mid-sentence.
5. **Sleep in your bed upstairs** (stairs → your bed, the pale cot in the
   nook). Sleep resolves classes: you should gain **[Warrior]** (from the
   spar) — class toast under the black veil.
   - WATCH: veil covers everything BEFORE the class toast; input dead
     during the hold.

## Stage 2 — Inn work loop & Helper

6. New day: do chores (dirty tables, the stew pot, deliveries Erin asks
   for). Aim for 3–4 distinct helpful acts, then sleep again → expect
   **[Helper]** (or a level) — remember: NO progress bars anywhere, ever;
   results only at sleep. If you see "3/12 uses" anywhere, that's a bug.
7. Open **J** journal: skills-by-class panel; cards reveal fully only
   after first use. Open **I** inventory: gear slots (weapon/armor/3
   accessories), gold line.

## Stage 3 — The street (Gate District)

8. Exit via the inn's south door to the street. Walk the district:
   Watch guards at the gate, **Selys**, **Krshia's stall**, the shop.
   - WATCH: street readability (paving vs walls), NPC feet on their
     tiles, name-free field (names only in dialogue headers).
9. **The Missing Crate** quest (from Selys/gate chatter): it has three
   solutions — FIGHT the scavengers at the cellar, WATCH (talk it
   through), or [Light]-study the cellar door (needs the Mage arc later).
   Pick FIGHT or WATCH now; note which you chose.
10. **Guild + boards**: enter the Adventurer's Guild (real door), browse
    THE REQUEST BOARD, accept a posting at Selys's desk, fulfill + turn
    in (gold pays out). Then the Runner's Guild: take a delivery slip,
    walk the parcel to its destination, get paid.
    - WATCH: a bounty you accept shows NO percent-progress anywhere;
      turn-in only lights up once genuinely done. ⚠ Do NOT sleep holding
      an undelivered parcel unless you want to see the failure beat
      (which is worth seeing once: parcel returns, no pay, Vess barks).

## Stage 4 — Pisces & the Mage arc

11. Find **Pisces** (inn, evenings). His arc: study beats → he teaches
    toward **[Mage]**. Earn it (sleep after his beats), then field
    **[Light]** from the hotbar in the dark.
12. Take [Light] to the **sewers** (grate in the street): the dark map.
    - WATCH: with no light you should feel blind but oriented by HP bars
      and the water channels; [Light] should carve a real readable circle.
      Find the vermin fight: can you locate both bats by SPRITE, not just
      their HP bars? (Known weak spot — report honestly.)
13. **Cisterns quest** (Quest 1 from Zevara/Watch): three paths again —
    FIGHT the nest, TALK Zevara around, or [Appraise Foe] the ledge.
    Pick the one matching your build; note it.

## Stage 5 — Economy, gear, social

14. **The Wrong Order** (Erin/Krshia inn quest): give→cook→report loop, or
    the TALK/FIGHT forks. One pass.
15. Spend your board/delivery gold at Krshia's: buy a weapon or accessory;
    equip it (I). Fight anything and confirm the kit changes (weapon-
    gated skills appear on the combat hotbar).
    - WATCH: resonance cap — try equipping 3 high-resonance accessories;
      the refusal should be a diegetic toast ("buzzes like a wasp"), not
      an error.
16. **Talk pools**: chat Krshia/Selys/Erin daily across 2–3 sleeps —
    lines rotate, and repeated genuine talking earns **[Diplomat]**-line
    progress. Stage lines shift as your accomplishments bank.

## Stage 6 — The Magical Door chain

17. Erin's flicker line fires when the chain arms (post-Act gate); the
    pantry door starts to matter. Report to Pisces: he offers three legs —
    FIGHT the rift vermin + ruin run, TALK him around, or [Observe] the
    doorframe runes. Do one leg → then buy Krshia's **resonant catalyst**.
    - **v0.4.1 CHECK**: once the chain starts, the pantry door should
      render as a small STONE ARCH (cool blue tint) — the same waystone
      prop as every region's anchor stone — not a plank door.
18. Sleep 3 more times (study beats — deliberately silent, only Pisces's
    lines shift). On the third: **the door awakens** — GDI's line under
    the veil.
19. Bump the awakened door: the **portal menu** opens (Liscor street
    first). Travel, then use the street anchor stone to come back.
    - **v0.4.1 CHECK**: the inn-side arch now glows warm gold with a
      light; arrivals NEVER trigger a fight or movement.

## Stage 7 — The Garden of Sanctuary

20. With Act III underway and 2+ major legs done, a qualifying sleep
    silently unlocks the garden; Erin acknowledges next morning. Enter
    via the garden door.
    - WATCH: perpetual day-bright inside even at dusk; the fountain,
      memorial hill, the bed under open sky (⚑ known taste question:
      does that bed read intentional to you, or misplaced? Say which).
    - No violence can occur inside — try to make something hostile
      happen; it shouldn't.

## Stage 8 — Riverfarm (Door expansion 1)

21. Portal → **Riverfarm** (attunes via the door chain). Walk the
    village.
    - **v0.4.1 CHECKS**: the crop plot = real plants (carrots/greens),
      NOT stacked containers with icons; NO wolf visible anywhere at
      day; the fenced field's SW area is clean.
22. **The Price of a Favor** (headman): give the offering, then head
    WEST past the fields — the hollow entrance is now a **sunlit trail
    gap between two trunks** at the treeline.
    - **v0.4.1 CHECK**: you find it without hunting. If you still walk
      past it, say so — that kills issue #49's signposting scope-call.
23. In the hollow: the witch (elder by day, young at dusk/night —
    cross a phase without sleeping to see both), the three-path fork
    (FIGHT the briars ×2 / TALK mediation via [Diplomat] / the SKILL
    gauntlet: cook → [Light] → [Observe]). Take a DIFFERENT kind of path
    than you took in Liscor quests. Village brightens on completion.
24. **Night wolves**: burn actions until night (walk around), approach
    the field's SW corner marker.
    - **v0.4.1 CHECK**: at night a WHOLE grey wolf stands there (head,
      four legs, tail — one animal, idling). Fight fires at radius 1;
      win with the Hunter if you did his come-along beat.
25. Sleep at the **guest cot** (north of the longhouse — yes, it's
    outdoors; issue #49 moves it inside a future longhouse interior).

## Stage 9 — Invrisil (Door expansion 2)

26. Portal → **Invrisil** (attunes via the Guild-board letter beat).
    Plaza scale-shock, crowd extras, Coyle's front, the alleys at night.
    - **v0.4.1 CHECK**: ambient crowd lines (unnamed speakers) start
      clean — no leading ": " on any bark.
27. **A Gentleman's Disagreement** (Wilovan): the game's first moral
    fork. Work ONE full path honestly — STEALTH ([Appraise Foe] the
    ledger), TALK (Cups' testimony — ⚑ known flag: this path currently
    costs nothing; tell us how unearned it feels, that calibrates issue
    #50), or FIGHT (Wilovan fielded as your ally — his hats-off beat
    differs per fork). Then choose EXPOSE or EXTORT at the confrontation.
    - **v0.4.1 CHECK**: the [Appraise Foe] ledger toast (STEALTH path) —
      six lines, ALL fully readable, nothing riding the parchment fold.
    - WATCH: after completion the alley footpads are gone permanently
      (safe passage — the Brothers' reward).
28. Sleep on the guest couch (⚑ known: it reads as a crate today —
    issue #49).

## Stage 10 — Act III arc (the finish)

29. Back in Liscor: the tremor beat → Zevara summons → Olesm briefing →
    the **Raskghar descent** (JOIN Relc for the boss) → the climax
    chain → the **seal** beat → epilogue under the veil.
    - WATCH: boss fight legibility (you vs Relc vs boss — nobody's
      sprite swallowed); journal Act panel advances; the epilogue's
      pacing (does the arc land emotionally? honest answer).
30. After the epilogue, free play: check your class screen (J) — by now
    you should have seen at least one **evolution offer** (level 10) or
    **[Spellsword] consolidation** if you ran Warrior+Mage. If offered
    earlier and you deferred, sleep once more to re-check re-offers.

---

## Wrap-up checklist (5 minutes)

- Esc → save, quit, relaunch, **Continue**: everything intact (gold,
  classes, quests, act state, door attunements)?
- Any toast/dialogue text you ever saw clipped, folded, or truncated?
- Any spot you were LOST about what to do next? Name the exact moment —
  those calibrate the signposting work.
- Three things that genuinely landed (so we don't break them).

Findings → tell Claude in-session or drop them in HANDOFF.md's next-steps;
screenshots welcome. Known open taste flags you'll brush against: fork
endings, hats-off delivery, Wilovan's downed rate, the inn facade's
Riverfarm family reuse, the charmed-villager echo tell, the brighten
strength, the garden bed.
