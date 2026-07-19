# b7 acknowledgment wave — design (2026-07-19, Fable; #207 #212 #213 #214 #201 #203)

Audit basis: 4-reader workflow sweep (full reports in the session
ledgered run wf_a2bbfb51-2f5; the load-bearing facts are restated here
so this doc executes standalone). Four PRs cover six issues — each PR
pairs issues that share one surface; deviation from strict
PR-per-issue noted per PR body.

## PR A — Relc presence (`issue/201-relc-presence`, closes #201 + #203)

Facts (verified): Relc has TWO field rows — floodplains (12,13),
permanent, no gates, carries relc_intro + the cleared_the_warren-gated
`brother_in_arms` stage; and the deep_tunnels cameo (13,4),
`present_when {reached_the_warren: 1}`, NO absent gate (stands there
forever post-clear). Relocation key: `awakened_boss.on_victory =
["cleared_the_warren"]` (deep_tunnels.json:269).

1. **#201 reposition**: cameo (13,4) → **(11,4)** — adjacent to the
   walkthrough lane cells (11,5)/(11,6); the audit's QA-safe seat list
   is (13,5)/(13,6)/(13,3)/(11,4)/(10,4); (11,4) is the one the route
   physically brushes. Keep facing toward the lane. His single
   dialogue line stays; no new counters (relc_descent_rewind pins an
   EXACT 8-key accomplishments dict — nothing new may bank).
2. **#203 departure**: add the `absent` arm on the cameo:
   `present_when {reached_the_warren:1}` + absent on
   `cleared_the_warren` — present only during the descent window. His
   permanent floodplains row (with the shipped post-clear
   brother_in_arms stage + relc_intro's cleared_the_warren options) IS
   the "returned to his post" state — no new row, no farewell copy
   needed beyond what shipped.
3. **QA re-derives (the risk center, capture-first)**:
   - deep_descent.json:346 `assert_event_count ui_entities_rendered
     {sprites:9, fallbacks:0} count:2` — re-derive: entry rebuild
     (cameo absent, 9) + post-reached reconcile (cameo added, 9);
     if a POST-CLEAR reconcile fires in-script the cameo now leaves
     (that render is 8) — the {9,0} count may survive at 2; trace the
     event stream, do not assume.
   - Lane asserts: (11,4) must not BLOCK any scripted move step —
     deep_descent/arc_flow route cells are (2,2)(2,4)(4,4)(4,3)(8,3)
     (9,3)(9,5)(11,5)(11,6)(12,6); (11,4) is on none of them.
   - delve_fight (fixture: cleared but NOT reached → absent either
     way), trap_placements_peek (fresh boot, absent; screenshot frame
     covers old (13,4) — note VISUAL-LOG if the shot shifts),
     relc_descent_rewind (fixture lacks reached — absent; (12,6)
     stays free; 8-key dict untouched).

## PR B — delivery acknowledgments (`issue/207-delivery-acks`, closes #207)

Census: ALL 13 delivery rows / 10 recipients are silent at the
recipient (pay/ack lives at Vess's turn-in only; arrival emits the
generic "Delivered: %s." toast). Mechanisms (the #172 pattern family):

- **NPC recipients** → one `talk_pool_stages` entry keyed
  `{delivered_<id>: 1}`, inserted per each pool's ordering _comment
  (LAST match wins; warm terminals must outrank; Erin's 25-stage block:
  insert AFTER the bed-nudge block, BEFORE her warm terminals).
- **Prop recipients** (krshia_stall, sewer_grate) → observe/visual
  override or toast swap gated on the counter (`_resolve_observe_text`
  when.counter idiom).
- **Standing rows** (dispatch_run, inn_hamper, barracks_kit):
  delivered_* re-banks every run and never resets — the ack line is a
  PERMANENT register shift, so write it as post-first-run familiarity
  ("the usual run" register), not a one-time thank-you.
- Copy bar: recipient's own voice per profiles, zero new counters,
  zero new options (pool stages + observes only — no pinned option
  list anywhere moves). Pool lines are speaker-pinned only in QA
  (text-safe); chatted/heard_gossip COUNT math is untouched by stage
  content. delivery_loop's pinned arrival toast is NOT edited.
- Verification: delivery_loop + runner_courier_loop + journal_history
  re-gates; one NEW canonical leg is NOT required (stages are
  text-level; the dialogue/social unit suites + a windowed read of two
  representative acks carry it). test_content cross-refs the new
  stage gates automatically.

## PR C — Beast-Tamer signposts (`issue/213-tamer-signposts`, closes #212 + #213)

Chain (verified): entry = soothed_a_beast:1; ONLY classless producer =
wounded_corusdeer prop (floodplains 33,9; its two interact toasts are
VERBATIM-pinned by beast_tamer_loop — do not edit them); the dog =
wolf_den prop (11,22), requires_skill lesser_bond (Tamer L3);
razorbeak_chick (8,23) same shape. wolf_den/razorbeak observe +
locked/hint toasts are UNPINNED (free copy).

1. **#213 (find the corusdeer)**: Krshia base-pool line (street.json
   Krshia talk_pool — base append is text-safe, rotation count math
   unchanged): a Silverfang-pragmatic pointer at the hurt corusdeer on
   the east rise. Plus wolf_den/razorbeak `locked_toast` extensions
   pointing back at "someone who tends hurt beasts" (in-situ
   telegraph for players who find the dens first).
2. **#212 (dog → bond path)**: Selys `talk_pool_stages` entry keyed
   `{soothed_a_beast: 1}` — post-first-soothe rumor pointing the new
   Tamer at the wolf pup in the western dens (the bond-skill path).
   Keyed on the chain's own entry counter: fires exactly when the
   player IS a prospective Tamer, per the issue's "after meeting the
   dog" intent read as after-entering-the-chain (adjudication:
   meeting the dog banks nothing; the nearest honest key is the
   chain entry — CHOICE-LOG).
3. No new counters, no option changes (parley_gates_check +
   floodplains_bestiary_loop pin the corusdeer_range option list
   EXACTLY — untouched). Re-gates: social_loop, board_loop,
   bounty_rank_loop (gossip-count coupled), beast_tamer_loop,
   tamer_bond_loop.

## PR D — skill-flavor trio (`issue/214-skill-flavor`, closes #214)

1. **[Detect Magic] Door hint**: extend the shipped cellar-wardwork
   quartet idiom at the pantry door's existing detect surface
   (field_skills entity dispatch; precedent `pantry_door_runes` /
   `magic_water_solvent`) — the on_skill_use copy hints the Door's
   nature obliquely. SPOILER BAR: "the Magical Door" only; oblique =
   "old anchor-work, keyed somewhere else" register, never the Vol-9
   name or doors-of-many-places lore.
2. **[Open Doors] pantry joke**: smallest sanctioned surface that
   composes with (1) — implementer verifies whether the entity
   dispatch supports a second skill arm on the same target; if not,
   the joke rides `field_ambient` proximity or an adjacent runes-prop
   arm. test_effect_text PINS open_doors' EMPTY effect lines — do not
   add an effect block; flavor only.
3. **Fishing affordance**: one `pond_edge` prop on the floodplains
   pond edge (the freezable (10,17) bank), `requires_item
   fishers_handline` (archery_butt precedent: item-gated practice
   prop), `once_per_waking`, banks `went_fishing` + a flavor toast in
   the handline's existing lore register ("the water starts moving
   wrong"). NO catch item, no fishing system — the issue is
   affordance clarity (CHOICE-LOG). Lacking the handline: a hint
   toast pointing at Lism's shelf (its sole vendor).
4. QA: gear_loop's index-18 cursor pin (fishers_handline LAST in its
   fixture inventory) — the fixture is untouched (no new items).
   derive_qa_surfaces after the new prop. New pond_edge + detect/joke
   arms get canonical coverage via a small extension leg on an
   existing floodplains/inn script IF cheap; otherwise unit +
   windowed-read evidence (adjudicate at implementation, log choice).

## Order

A (riskiest QA re-derive first) → B (largest copy volume) → C → D.
Every PR: full three-check unit bar + full sweep + whole-branch
review + 6/6 checks READ before merge (standing rules).
