# CHOICE LOG (controller judgment calls — user defers by standing directive 2026-07-18)

Newest first. Each entry: the call, the alternatives, why. Choices that
change shipped behavior also live in their PR bodies; this is the
cross-release index of them.

## 2026-07-28 — v0.15 T3.1 guest arc-windows (three in-wave calls)

- **Zevara's window opens at `heard_the_deep_tremor`, NOT at
  `watch_runner_pointed`.** The spec's edge was verified against the
  something_beneath chain and the wider one was measured, because the inn map
  itself argues for it: `erin_thread_gate_runner` (inn.json) fires on
  `watch_runner_pointed` and says "A runner was asking after you. Captain wants
  you at the gate" — in the same room where the Captain may be sitting three
  cells away, and her inn register is contractually barred from mentioning the
  arc. The wider window was NOT taken because of what it costs: three fixtures
  shift seating (`inn_guests_full_start`, `_ext_start`, `_gate_start` all carry
  `watch_runner_pointed` with the arc unstarted), and restoring Zevara's live
  coverage — she is the roster member with no other QA leg anywhere — would mean
  banking `raskghar_sealed` AND `post_game` in three rotation fixtures, a
  cross-cutting flag that turns on leads, bounties, journal sections and a sleep
  GDI line inside canonicals that exist to prove seating. The residual gap is
  short and self-closing (the player is already walking to the gate), and both
  of Erin's later lines — the tremor thread and "TELL Zevara you came back up" —
  fall INSIDE the shipped window. Revert path: one token in GUEST_POOL_GATES +
  the matching row arm + those three fixtures.
- **Relc gets NO entry; his descent window was audited and does not
  reproduce.** `relc_descent_cameo` holds [reached_the_warren,
  cleared_the_warren) on deep_tunnels, and a player can reach the warren mouth,
  walk back up and sleep — so the double is real. It is not a DEFECT: every
  guest already stands at a permanent home post on another map (relc on
  floodplains, zevara at the gate, olesm/pisces/klbkch on street), so cross-map
  doubling is the shipped idiom, not the bug the ruling names. What made pisces
  and zevara defects was same-map: pisces's chair rendering EMPTY (pooled, both
  rows hidden, `pisces_mounting` holding him at (13,5) on the inn map itself)
  and Erin contradicting a seated Zevara in her own common room. Relc's row is
  ungated, so there is no ghost seat to close, and no inn line names him.
  Gating him would make a shipped ungated row gate-dependent for nothing.
- **Zevara takes the twin-row idiom rather than a third row or an OR in
  `present_when`.** `present_when` has no disjunction and the pisces pair
  already proves the pattern, so `zevara_inn_guest` became the BEFORE arm
  (absent heard_the_deep_tremor) and `zevara_inn_guest_returned` the AFTER arm
  (requires raskghar_sealed), sharing seat, sprite and conversation — and so the
  same once_per_waking serve key, safely, since `raskghar_sealed` implies
  `heard_the_deep_tremor` and the two can never co-render. Pisces needed NO row
  edit at all: his existing pair already states the window exactly; only the
  pool gate was missing. Belt-and-braces is now machine-enforced rather than
  asserted in prose — `test_content._validate_guest_gate_windows` derives the
  window from BOTH sides and fails on any disagreement, which is what a ghost
  seat is.

## 2026-07-28 — v0.15 A5 endings acknowledgment (five in-wave calls)

- **The seven completion lines ship as `""`-req resolution FALLBACKS, not as a
  new `complete_text` key.** `completed_quest_summary` already renders
  `"<title> — <path text>"` and falls back to `"— Complete."` only when
  `resolved_path` answers empty; a one-entry `resolution_paths` array with no
  `accomplishment` and no `grant` is exactly "this quest has one ending, here is
  how it reads". Zero engine change, zero new schema, and `test_quests`'
  `_resolution_order` guard stays quiet because it counts REAL rungs. Alternative
  rejected: a `complete_text` key — a second mechanism for the same sentence,
  and the first thing to rot when someone later gives one of these quests a
  branch. Revert path: delete the seven arrays.
- **The trapped-halls pacifist relabel SPLIT the fallback instead of swapping its
  grant.** The spec's finding is exact — the pacifist route pays
  `melee_hit`/`won_combat` — but the row carrying that grant was the `""`
  fallback, which caught the DISARM route ([Observe] + trap kit on the dart
  slit, which banks only `halls_cleared`) AND the fight, because the snare
  encounter banked only `halls_cleared` too. Swapping that one grant to
  `{sneaked_past_danger: 6, persuaded_someone: 2}` as written would have fixed
  the pacifist by mislabelling the fighter in the opposite direction, under a
  line still reading "You cleared the trapped halls yourself." So the fight got
  an id of its own (`cleared_halls_by_force`, named now, freezes at the tag) on
  `snare_nest_slot`'s `on_victory`, the fight keeps its old line and grant
  VERBATIM as a real rung, and the fallback becomes what it always actually
  described: the disarmer, with the spec's grant and a line that says what they
  did. Revert path: drop the new rung and the counter, restore the old two-row
  array.
- **Four Act V fixtures gained `cleared_halls_by_force`; three horns_dig ones
  deliberately did NOT.** Seven fixtures carried `halls_cleared` with no route
  counter. **`vault_construct_downed` is NOT the discriminator** — all seven carry
  it, because the vault boss sits BEHIND the halls and is reachable however you
  got through them, so it says nothing about which route did. The discriminator is
  evidence of the SNARE fight specifically, and the only such evidence these
  fixtures carry is `won_combat`/`melee_hit`/`victories`: `finale_merge` (6/57/7)
  and the three seal fixtures (3/18/4) have it, so naming the fight keeps their
  recorded ending byte-identical to what shipped. `horns_dig_start`,
  `horns_dig_plates_start` and `horns_residence_start` carry NONE of the three —
  zero recorded combat of any kind — so under the old data they were being told
  "You cleared the trapped halls yourself" and paid 12 melee hits and 2 wins they
  had never landed, which is precisely the unearned-outcome-text rule A1 exists to
  forbid. They now read the disarm line honestly. That asymmetry is the point, not
  an oversight.
- **The OR-producer beats are `complete_when_any`, a sibling key — not an
  ANY-of-Array `complete_when`.** Phase 3's ruling-1 guest gates take the
  Array-means-ANY shape, and reusing it here would have made one key mean two
  structurally different things in two files. A named sibling reads at the call
  site (`complete_when` AND, `complete_when_any` OR) and is purely additive: a
  beat without it evaluates exactly as before. `test_content`'s three quest arms
  now read BOTH keys through one `_beat_gate_counters` helper, so an alternative
  naming an unproduced counter, or one whose producer map the description never
  points at, still fails loud. Revert path: delete `_beat_met`'s `any` block and
  the two data keys.
- **The two postings wired were `cisterns` and `wrong_order` — the file's own
  vocabulary picked them.** `quests.json` calls these two "the cisterns/wrong_order
  two-beat shape ... a posting" in `what_the_seal_kept`'s comment, and they are
  the only two whose non-combat route banks its own counter and then waits for a
  REPORT to close the resolve beat: scouting the nest ([Appraise Foe] at the
  overlook ledge) and stretching the order in the inn kitchen. Both already had
  the route counter — `scouted_the_nest`, `stretched_the_order` — so this wired
  what exists and produced nothing new. Audited the other eight resolution-path
  quests the same way; every other route already reaches its beat directly.

## 2026-07-28 — v0.15 A4 fix round 1: the pan/tap slop threshold

- **`BODY_PAN_SLOP_PX := 4.0`, and the latch ACCUMULATES.** Fix round 1 caught
  that the first cut latched on the first motion event of ANY magnitude, which
  is fine for a mouse (a tap drifts 0px) and wrong for touch, where a finger
  never holds still: a 1px wobble between press and release would have eaten a
  legitimate tap, and the player would get NOTHING instead of the wrong thing —
  strictly worse than the bug being fixed. So the gesture now sums |dy| across
  its whole life and latches once the total passes a slop threshold. **No repo
  precedent existed for that number**, so it is argued rather than picked: it
  must clear the couple of px a resting finger produces, and sit well under the
  body's 20px row pitch so a pan cannot cross a whole row and still read as a tap
  on the row it lands in. 4px is the middle of that window and a quarter of a
  row. Probed at the four magnitudes that matter: a 1px-out-1px-back tap (2px)
  and a 3×1px jitter (3px) both still TAP; a 6×1px slow pan and a 40px flick both
  latch. Alternatives rejected: (a) a per-event threshold — a slow pan arrives as
  many small deltas and would never latch; (b) net displacement rather than
  absolute travel — an out-and-back pan nets ~0 and would toggle. Scrolling stays
  unconditional: a sub-slop wobble pans by those same few px, which is invisible,
  and still counts as a tap. Revert path: drop the const and the accumulator, and
  latch on `absf(dy) > 0.0` again.
- **The latch resets on open/close/tab-switch, not only on press.** A pan that
  ended outside the body, or on a tab the player then left, would otherwise sit
  armed and swallow the next tap — and a programmatic `meta_clicked` with no
  press behind it (how QA and any future scripted click arrive) would hit that
  stale flag with no gesture to blame. One `_reset_body_gesture()` helper, five
  call sites.

## 2026-07-28 — v0.15 A4 viewport correctness (four in-wave calls)

- **The combat feed's fold fix is a LAYOUT fix, not a budget re-cut.** The
  ledger's own diagnosis ("the viewport height is not a whole multiple of the row
  height") turned out to be wrong, and measuring said so: the capacity math in
  `_feed_text_capacity_height` already yields exactly four rows for the 122px
  panel and four rows are 77px against an 84px allowance. What actually broke was
  that the label was CENTRED in its MarginContainer — `size_flags_vertical` sits
  at SHRINK_CENTER by default, so the label rect was its content height parked in
  the middle of the inner area, and the block grew into the fold from both sides
  at once. Fix is `SIZE_FILL` + `VERTICAL_ALIGNMENT_TOP`, which makes the label
  agree with the doc comment that already claimed it was top-aligned.
  Alternatives considered and rejected: (a) budget the fold deficit TWICE, the
  toast panel's idiom — correct for a centred label, but it costs the fourth row
  (a centred 4-row block cannot clear a 30px fold in a 122px panel), and losing a
  row of feed is the same information loss the entry was filed about; (b) grow
  the panel for ordinary feed content — the feed band is disjoint-by-contract
  from the readout and the board above it, and growing it on every fourth line
  puts that contract in play for a cosmetic gain. Revert path: drop the two
  property assignments in `build()`.
- **The journal's line-boundary clip is a WRAPPER, not a measured
  `custom_minimum_size`.** The body needed to know its available height in order
  to quantize it, and the available height was its own EXPAND_FILL result — a
  cycle. Rather than measure-once-then-lock (which is order-dependent and rots if
  the panel ever resizes), the EXPAND_FILL moved to a plain Control slot and the
  body anchors full-rect inside it, so the dependency runs one way and the clip
  is idempotent on every resize. It also fails SAFE: if the metrics are
  unavailable the body fills the slot exactly as it did before. Revert path:
  return `size_flags_vertical` to the body and delete the slot.
- **The veil's line budget TIGHTENS before it evicts.** A wrap-aware budget has
  to answer "and what if the whole block still does not fit" — a real question
  now that the finale can carry three act presences, three region lines and a
  line per held class. Options were: drop lines (loses a level-up the player
  earned), shrink the font (breaks the one-typeface GDI device), or tighten the
  gaps. The ladder 18/14/10/6 buys three more rows before anything is lost, and
  eviction is last-resort and takes the OLDEST line — the one the player has
  already read — never the one being shown. Revert path: delete
  `_apply_line_budget` and restore the flat separation of 18.
- **A drag that PANS is no longer also a tap.** The line-boundary clip moved the
  journal body's release point by a few pixels and `field_skills_loop` went red:
  its drag-to-scroll now let go over the `[Basic Cleaning]` row and toggled it
  into the field loadout. RichTextLabel fires `meta_clicked` on button RELEASE
  over a meta region regardless of intervening motion, so this was a live
  player-facing bug the whole time — drag the Skills tab to read past the fold,
  and whatever row you happen to release on silently goes in or out of your
  hotbar. Fixed in the ENGINE side (a `_body_gesture_panned` flag set by motion,
  reset on every fresh press, consumed by the meta handler), NOT by re-aiming the
  QA script's drag: the script's pins encode the correct behaviour (a single
  `loadout: ["observe"]`) and were right all along. Revert path: delete the flag
  and its two guards.

- **`test_copy_fit` SOURCE-PARSES sleep_veil.gd's tables rather than mirroring
  them.** Every other surface in that suite reads data files; the veil's copy
  lives in GDScript consts, and a mirrored copy of a copy table rots the first
  time a line is reworded — silently, because a stale mirror still passes. The
  parse is narrow (quoted strings inside a named const block, accomplishment ids
  filtered by shape) and the NUMBERS are still pinned by drift tripwires, which
  is where drift actually hurts. It also measures with the **Header** variation's
  font, not the default label font: the veil draws through Header at 24 and
  measuring the wrong typeface would have made the whole gate decorative.
## 2026-07-28 — sewers_walkthrough toast timing: the SCRIPT gave, not the engine

- **The two post-combat `ui_toast_rendered` waits became `from_start` scans at
  `timeout_sec: 20`; message_layer was not touched.** PR #310's canonical sweep
  went red on `sewers_walkthrough` alone — both waits timing out at
  `cursor=189` — and the same failure was already ledgered as
  QA/SEWERS-WINDOWED-TIMING (P2, `50cbf6b`) for windowed runs. The engine is
  correct: `_restore_banked_toasts` kicks a drain and the queue is lossless.
  What is machine-dependent is WHICH SIDE of `combat_started` a given
  narration renders on. Toast holds are wall-clock
  (`QA_TOAST_HOLD_HEADLESS_SECONDS` 0.05s) while the driver's steps are
  frame-paced, so faster frames burn less wall time between the cast and the
  fight and leave MORE of the queue pending for `_bank_toasts` to catch.
  Measured at seed 9: this laptop headless renders 3 pre-combat and banks 4;
  windowed (and a loaded 4-job CI runner) renders 7 pre and 1 post. A
  cursor-ordered forward wait can only see the banked half, so it reds the
  healthy regime. `from_start` scans the whole log with the cursor untouched,
  placed unchanged AFTER `ui_combat_hidden`: the assertion is now "by the time
  the board has closed, both narrations have rendered", which is exactly the
  GH#304 regression (4 of 7 payloads NEVER delivered at 23aca0b) and holds in
  every pacing regime.
- **Alternatives rejected.** (a) Just raise `timeout_sec` — does nothing: on a
  slow runner the toasts already rendered BEHIND the cursor, so a forward scan
  never finds them however long it waits. (b) `assert_event_absent` /
  dropping the render proof — deletes the only end-to-end evidence for the
  fix. (c) Emit a `toasts_banked` event so the script could gate on the bank
  count (the ledger's own suggestion) — that is an engine change to a god-file
  another branch owns, for a property that is an artifact of frame speed
  rather than behavior. The bank/restore branch that genuinely needs pinning
  (`_restore_banked_toasts` kicking a drain when `_toast_draining` is false)
  already has deterministic, frame-rate-free coverage in
  `tests/test_message_layer.gd`, which is the right home for it.
- **Revert path:** drop `"from_start": true` from the two waits in
  `qa/scripts/sewers_walkthrough.json` and restore `timeout_sec: 5`. That
  re-pins post-combat ordering and re-breaks CI + windowed.

## 2026-07-28 — v0.15 A3 toast survival + Lore capture (four in-wave calls)

- **`_pending_sticky` and `_first_wake_hint_pending` DELETED from
  message_layer, not kept alongside the lossless queue.** Both existed only to
  re-add a specific text after `_clear_toast` wiped the queue; with no wipe
  left they are write-only state, and write-only state rots into a false
  contract. The `sticky` PAYLOAD key stays as the sim-side authored signal
  ("this line must not be lost", still pinned in test_sim_core) — the renderer
  no longer special-cases it because nothing is lost. Alternative considered
  and rejected: re-purpose `sticky` to mean "PLAYER_MOVED may not cut this
  toast's hold short". Real and tempting (the Watch-runner pointer is exactly
  the line a player steps past), but it changes display TIMING across 166
  canonicals for a problem the brief did not scope. Revert path: restore the
  two vars and the `_queue_toast(text, record, sticky)` third parameter.
- **Quest-lifecycle toasts are NOT lore-tagged.** "New quest: X" / "Quest
  updated" / "Quest complete" are the largest sticky set, but they are already
  durable in the journal's Quests + Acts sections; tagging them would fill the
  Lore record with tracking chatter and bury the world's own lines. Lore means
  "a fact about the world you were told once".
- **The tagged set is 16 surfaces, one thread.** The wardwork quartet's four
  [Detect Magic] reads (pantry_door, warded_seam, leyline_stone,
  anchor_socket) + the pantry [Observe] rune read; the Act V seal door's five
  reads and its `detected_wardwork >= 3` lattice payoff; the two arc-start
  arrival narrations (dungeon_approach, ruin_surface); the pedestal's "A DOOR —
  unhung" reveal; the Watch-runner pointer. Deliberately UNTAGGED: the
  anchor_socket `pedestal_unsealed` variant (an action, not a reading — its
  outcome is already a quest beat) and the seal door's repeat-read filler line.
- **FIX ROUND 1 — the tag was inheritable, and leaked across surfaces.** Review
  caught that BOTH resolvers accumulate (`_resolve_skill_use_effect` copies
  every non-`when` key off each satisfied variant; `_interact_container`
  defaults each variant to the running value), so an untagged variant under a
  tagged arm silently inherited `lore: true`. Three arms the log had already
  ruled untagged were in fact tagged in the shipped build, plus a fourth the
  new lint found: anchor_socket's `pedestal_unsealed` unseal, seal_kept_door's
  repeat-read filler, and anchor_stone_pedestal's migrated-save open arm. All
  three now declare `"lore": false` explicitly, and `_validate_lore_flags`
  makes the drift impossible: **if any arm on a surface is lore-tagged, every
  variant on that surface must declare the key** — absent is a content failure.
  The migrated-save arm ("the anchor stone. The Horns left nothing else
  behind") is ruled NOT lore on its merits too: it is a pickup confirmation
  for a player who already has the Door hanging in his inn, not a revelation.
- **Containers get their own `open_lore` key, not the entity's `lore`.** A prop
  can be a container AND a plain interact target — anchor_stone_pedestal serves
  locked-plinth flavour until `contains_when` opens — and round 0 read one
  entity-level `lore` for both, which measurably tagged the locked flavour line
  ("The seal is broken and the Horns are already down the gap…") as durable
  lore in a real horns_dig_flow run. `open_lore` pairs with `open_toast`
  exactly as `lore` pairs with `toast`, so the two beats can never share a
  flag. The event PAYLOAD key stays `lore` either way.
- **No cap on `lore_notes`.** The set is bounded by authored copy and deduped
  by exact text, so a cap would only ever silently drop the OLDEST fact — the
  exact failure the feature exists to fix. Revisit if a future data pass tags
  a repeatable generated line.

## 2026-07-28 — v0.15 A2 leads: two PLAN-DATA corrections (controller rulings)

The brief's leads.json block was verbatim plan data and shipped verbatim; review
found two of its four rows wrong against the shipped dialogue. Both corrected
by controller ruling — the plan was the defect, not the implementation.

- **`lead_survey` gates on `post_game`, not `raskghar_sealed`.** Olesm's survey
  option (`olesm_intro.json`) requires `post_game: 1` and hides on
  `horns_delve_started: 1`; `post_game` banks at the first sleep AFTER the seal
  (sleep_beat.gd). A lead on `raskghar_sealed` therefore lit one whole waking
  early and pointed at an option the player could not see — a pointer to a
  refusal, which is worse than the empty page A2 exists to fix. General rule
  adopted and written into leads.json's own `_comment`: **a lead row mirrors
  its target option's `requires`/`hide_when` exactly.** All six shipped rows
  were audited against their options; the other five already matched. arc_flow
  now pins BOTH sides of that window (`lead_lines: []` at the seal,
  `[survey]` after the sleep) so the refusal window cannot reopen.
- **`lead_capstone` deleted; three capstone-ARM rows in its place.** It gated
  on one lattice piece (`lattice_witch_lore`) while pointing at Pisces's
  descent ask, which needs all three — so it fired two pieces early, and what
  it pointed at (return to Pisces) is the spine quest's own final beat, already
  in the Quests list. The real playtest gap is upstream: closing a region
  chain while the spine runs ARMS that stop's capstone conversation, and
  nothing anywhere said so. `lead_witch_ear` / `lead_hedault_eye` /
  `lead_forge_ledger` each mirror their stop's option gate exactly
  (region terminal AND `spine_started`, hidden by that stop's lattice
  counter). Net: 4 rows -> 6, no new counters, no new quests.
- **One copy polish on the ruling's draft.** `lead_forge_ledger` shipped as
  "Grimalkin has been about to say something since your papers were stamped."
  rather than the draft's "The forge tier keeps its wards fed on a schedule.
  Someone up there will say why." Two reasons: "wards fed" is Act V's reveal
  vocabulary (`read_the_feeding_ward`, "What the Seal Was Feeding") and this
  line is read mid-Act-IV — the same class as `the_reach_mapped`'s logged
  leak; and the other two rows name their NPC (Eloise, Hedault), so naming
  Grimalkin keeps the strip's grammar uniform. Question-not-answer holds, no
  component named (the spine's no-fetch rule).
- **`leads.json` joins `PLAYER_STRING_FILES`** so the house copy lints
  (attribute tokens, percent-toward, dev-provenance citations) scan
  `lead_text`/`place`. Proven can-fail with a planted `(Task 2.3)` and a
  planted `CON` — both flagged, one per arm.
- **spine_reach carries the capstone-arm proof.** Its existing post-bank
  journal open now pins `lead_lines` too, and a 4-step read-only leg ahead of
  Pisces pins the spine lead present — so the vanish crosses a real bank in
  one run. That page is also the observed WORST CASE for the A4 scroll budget:
  **4 concurrent leads** (survey + all three capstones), 8 rendered lines with
  wrapping, which pushes Quests and Completed entirely below the fold. The
  ledger estimate of 8 lines was right; the concurrency was 3, actual is 4
  (a player who never took the survey keeps that row while all three
  capstones arm).

## 2026-07-28 — v0.15 A2 Leads strip (task 1.2) + T1.1 carried items

- **`active_leads()` is a pure derivation on `_combat_config["leads"]`, nothing
  persisted.** A `seen_leads`/`dismissed_leads` save field was the alternative
  (it would allow "hide this pointer"), and it was rejected: a lead is defined
  by two counters, so a saved copy can only ever DRIFT from them (the leads
  vanish on their own quest-start counter, which is exactly the state a save
  would duplicate). No save VERSION bump, no migration arm, and a migrated
  v0.14 save shows the correct strip the first time it opens the journal.
  Revert = delete the method, the catalog load, and the journal's section.
- **`hide_when` is the ABSENT gate, not a second `requires`.** Extracted
  `WIGame._absent_gate_met` and pointed the two pre-existing copies
  (`_present_gate_met`, `_encounter_gate_met`) at it rather than writing a
  fourth inline loop — same 4 lines, three sites, one seam to state the
  ">= threshold shuts it" trap at. Behavior-preserving (full suite + the
  touched canonicals green, presence/encounter gates included).
- **The strip publishes RENDERED rows (`lead_lines`), matching
  `act_beat_lines`.** Pinning ids would have been more stable across copy
  edits, but the whole finding is that the player had no words to read — so
  the QA pin is the words, place included. Cost accepted: polishing a lead
  reds three canonicals (whole-list match); re-pin from a run.
- **Marker glyph `· ` shared with pending act beats.** Deliberate: both mean
  "not yet yours". A distinct glyph would imply a distinct mechanism the
  player has no way to learn.
- **The brief's "extend arc_flow at the three seams" read as "extend the
  canonical AT each of the three seams".** arc_flow physically reaches only
  seam 1 (it ends at the seal), so seams 2 and 3 landed on the canonicals
  that already stand there: `horns_dig_flow` (journal open BEFORE the
  invitation shows the dig lead, a second open after `horns_dig_started`
  banks pins `lead_lines: []` — the appear/vanish pair proven in one live
  run) and `door_awakening` (the awakening sleep completes the door quest,
  and the same page now carries the spine lead). Alternative — a new
  fixture-start canonical per seam — buys the same proof for three manifest
  rows and three seeds. All three are read-only journal detours.
- **T1.1 CARRIED-1 closed: `arc_flow` gets the `act_beat_lines` pin + windowed
  journal shot the T1.1 brief named for it.** T1.1 swapped that pin to
  `raskghar_entry_loop` unlogged (an Act III page for an Act IV pin — the
  Act III fixture was standing in the more interesting spot, but the swap was
  a substitution, not a superset). Both now exist: raskghar_entry_loop keeps
  the Act III opening pin, arc_flow gains Act IV's 7-pending list on the seam
  page, and its `05_journal_sealed` shot was read windowed.
- **T1.1 CARRIED-3, outcome markers: added the `you have <verb>` FORMS, not a
  bare "walked".** The gap the review found is an auxiliary between pronoun
  and verb (`the_reach_mapped`'s own text reads "you have walked all of it",
  which the shipped `you walked` entry misses); the same evasion exists for
  read/took, so all three have-forms ship together. Bare "walked" was
  rejected — it would red an honest forward line ("nobody has walked it
  since"), and the ban is on second-person BANK verbs, not the verb stem.
  No shipped opening trips any of the 7 entries (arm proven can-fail).
- **T1.1 CARRIED-4, `render_beats` emptiness is now tested STRIPPED.** A
  whitespace-only `opening` used to render a bare "· " row — a marker
  pointing at nothing, which is worse than the hidden beat the policy
  promises. Unit case pins it (proven can-fail).

## 2026-07-28 — v0.15 A1 pending-beat openings (task 1.1)

- **Render policy lives in `WIActs.render_beats`, not in journal.gd.** The
  journal's pending branch could have chosen `opening`/`text` inline (2 lines,
  no new API). Chose a derivation-side helper returning `[{id, achieved,
  line}]` because the "outcome text never renders unearned" rule is a CONTENT
  contract that must be unit-testable without a UI: test_acts now proves the
  drop-vs-fallback behaviour directly, and any future beat surface (leads
  strip, finale recap) reads the same policy. Revert = inline the three lines
  at journal.gd's beat loop and delete the static.
- **An opening-less PENDING beat is dropped; an opening-less BANKED beat
  keeps rendering its text.** Alternative (render an empty `· ` row) leaks
  "there is a beat here you haven't earned" without saying anything; hiding
  is the spec's own fallback and the only choice that cannot leak. All 18
  shipped beats author an opening, so the drop path is defense-in-depth —
  test_content now REQUIRES an opening on every beat rather than treating it
  as optional, so no future beat can ship invisible.
- **All 18 draft openings shipped verbatim.** Audited each against its beat's
  `when` counter and that counter's quest chain before accepting. The two
  that looked mis-assigned are correct: `the_door_opens` (door_awakened)
  opens on the DIG east because horns_dig -> door_mounted -> catalyst ->
  attune is that counter's chain, and horns_dig's own spoiler rule forbids
  naming the door before the haul beat — so the opening literally cannot
  mention the Door. `the_horns_home`'s "somewhere to put their feet up" was
  the one line considered for a rewrite (it poses the question but points at
  no place); kept, because pointing is the Leads strip's job (A2) and a
  rewrite would have invented delve fiction to do A2's work in A1's voice.
- **Outcome-marker list normalized to 4 lowercase entries** matched
  case-insensitively: `settled`, `you read`, `you took`, `you walked`. The
  brief's 5-entry list carried "You settled" (subsumed by `settled`) and
  mixed case (defeated by any recasing). No draft trips the list; "settling"
  and "Settle it" pass by design — the ban is on past-tense BANK verbs, not
  the verb stem.
- **New journal payload key `act_beat_lines`** (the exact rendered rows,
  marker included) so the spoiler rule is machine-checkable end-to-end, not
  only by screenshot. `act_beats`/`act_beats_achieved` keep their old
  count semantics, so no existing pin moved. Pinned in 4 canonicals:
  climax_seal (Act IV, 7 pending — the VISUAL-LOG itinerary leak),
  seal_open (Act V, 3 pending), spine_reach (Act IV, 5 banked + 2 pending),
  raskghar_entry_loop (Act III, 2 pending). Cost accepted: polishing a
  shipped opening now reds those 4 scripts (whole-list match) — that is the
  copy freeze working, re-pin from a run.
- **raskghar_entry_loop gains a read-only journal open.** No canonical
  opened the journal anywhere in Act III, so the wave's own act-page
  re-shots had a hole; that fixture is the only one standing in Act III with
  both beats pending. Alternative (a new canonical) costs a manifest entry
  and a seed row for one screenshot.

## 2026-07-18 — #147 music intake calls

- Listening pass = inline signal analysis (tempo/RMS/brightness/mode vs
  shipped anchors) after two Opus dispatch misfires; two placement swaps
  made on the numbers, not names (night wolves = fast-minor; brightest
  major to daytime fields; darker cave track deeper).
- Attribution via Settings Credits panel (user ruling): Ove Melaa
  verbatim line + fan-work disclaimer; formal credits screen deferred.
- Boss arena takes the Battles finale cue, replacing a reused junkala
  track; the common goblin fight gets the public-tier cynicmusic battle
  so bundle tracks stay on the bigger fights.

## 2026-07-18 — v0.11.0 ship + environment fix

- **github-pages environment gains a v* tag deployment policy** (via API):
  the new tag trigger's first firing was rejected by the main-only rule
  the environment shipped with. Structural pair to the pages.yml trigger.
- v0.11.0 shipped same-day as v0.10.0 under the autonomy directive; all
  wave adjudications above.

## 2026-07-18 — #163 rank-scaled Guild bounties (implementation adjudications)

- **Rank boundaries derived from effective_power, never hardcoded levels**:
  Bronze < power of a single L10 line (== 10.0 by construction); Silver <
  power of a two-L10-line build (the spec's "14-equivalent consolidation" —
  two L10 lines merge to L14 — whose UN-consolidated power is 10*2^(1/k) ≈
  15.64); Gold at/above. `WIProgression.power_rank`; both edges pinned in
  test_progression.
- **Payout anchor relation** (validator, consumes #92's ladder): silver.gold
  a multiple of crude_draught's price (the entry rung), gold.gold a multiple
  of tonic_of_the_clear_eye's price (the tonic tier); monotonic; combat
  top-tier ≥ 2× mending_draught (purchasing floor). Chose crude-for-silver /
  tonic-for-gold (both anchor items referenced, economically sane silver
  rungs) over a flat tonic-multiple-for-both (would 8× a work bounty at
  silver). All three arms + the price-move coupling proven can-fail.
- **10 postings tiered across all pillars** (fight/social/work/explore +
  standing orders); every base (bronze) record kept BYTE-IDENTICAL so every
  bronze-rank QA loop stays green — the rank register surfaces in the
  silver/gold copy overrides.
- **Only 2 encounters scaled (4 GATED cells), not 4 (8 cells)**:
  gallery_vermin_nest (T4) + forge_calibration_golem (T5) have no live QA
  loop fighting them, so scaling is regression-free. kingslayer_den /
  market_watchgolems were EVALUATED but their loops run at silver-rank
  spellsword11 fixtures that can't clear the scaled fight at the pinned seed;
  they stay unscaled until rank-aware loop fixtures land (a follow-up).
  Steps FIXED by spec (silver +25%HP/+1dmg, gold +50%HP/+2dmg), one site
  (WIBountyScaling), mirrored in start_combat + sim_combat_batch.
- **accepted_bounty_tier = one additive save field** (get-default "", no
  VERSION bump — the board fields' own precedent); the accepted tier locks at
  accept and turn-in pays it regardless of later rank shifts.

## 2026-07-18 — public-demo deploy gap (friend-playtest triage)

- **pages.yml gains a release-tag trigger** (was manual-dispatch only, an
  Actions-budget choice): the GitHub Pages demo sat at v0.7.0 while itch
  had v0.10.0, and the README points players at Pages — a playtester hit
  the 3-release-old build. One run per tag is within the budget the
  manual-only rule protected. Immediate catch-up dispatch fired.
- Friend-playtest triage: 4 issues filed (#169 web glyphs/filtering,
  #170 message pacing+scrollback, #171 onboarding affordances, #172 copy
  wave) — all folded into v0.11.0 scope per the discretionary-work goal.

## 2026-07-18 — v0.11.0 Second Wind spec adjudications (#165)

- **beast_master's attested pick [Lesser Bond] rejected on id collision**
  (shipped as the tamer's L3 tame verb; shipped ids never rename) — the
  researcher's Redfang-voiced ⚑ORIGINAL fallback [Sworn Fang: Ride
  Together] ships instead.
- **[Server's Prescience] goes to BARMAID** (Drassi's attestation is
  barmaid-line inn work); server takes ⚑ORIGINAL [Swift Service] — one
  attested name cannot serve two sibling lines.
- **D-1's "Xif skills are dialogue color only" fence RELAXED** for earned
  late grants: [Perfect Reduction] becomes the alchemist L14 bench-cast
  (crude → tonic). Shared skill names across holders are canon-normal;
  the fence protected D-1 scope, not exclusivity.
- **One grant per line at L14, L15/16 rows empty**: the funnel fix is the
  LEVELS (stat growth), not kit inflation; second grant tier deferred to
  demand.
- v0.10.0 shipped on the autonomy directive with #167 fixes, no re-gate.

## 2026-07-18 — v0.10.0 gate fixes (#167) and ship ruling

- **Ship v0.10.0 after #167 fixes without a further user playtest** — USER
  DIRECTIVE (not a controller choice; recorded for the timeline).
- **Raskghar arc gets a real journal quest (`something_beneath`)** rather
  than a longer-lived toast or forced-modal: quests are the game's durable
  direction surface; every side errand already had one and the main spine
  did not. Toast stays as the nudge. Mid-arc saves backfilled at load.
- **Pantry-door legibility fixed with gated copy on the DOOR itself**
  (observe override + interact-toast variants + one window-gated Erin
  follow-up option) rather than new markers/UI: keeps the no-floating-
  markers rule; the door is the natural place players re-check.
- **Garden pre-unlock cell: entity absent via `present_when` + cell
  unblocked** — user directive; wall-dressing (#151) retired. The at:0
  hidden visual_state left in place as redundant belt-and-braces.
- **`gate` added to street LANDMARK_TOKENS** instead of bending Zevara's
  copy toward "market": the gate IS her canonical post and existing copy
  already says "at the gate" throughout.
- **Wounded corusdeer: strengthened tint only** (0.6/0.52/0.47); the real
  fix (lying pose) stays PixelLab/user-gated per the art budget.

## 2026-07-17 — v0.10.0 wave calls (index of PR-recorded choices)

- Erin's VERBAL garden reveal masked in real play — accepted; the door's
  earned-appearance is the signpost (PR #161).
- [Spellsword] funnel root-caused to table ceilings; fix = extend pure
  lines (#165, user-ratified option 1); merge-formula surgery rejected.
- Kingslayer boss drop is accessory-only (respawning bounty = farm risk);
  crude_draught price stays 4 (validator-consistent, churn not worth it)
  (PR #166).
- Room purchases live on their own register surface, never on pinned
  dialogue hubs (PR #166 incident writeup).
- Bounty payout scaling (#163) anchors to the economy price ladder, not
  hand-tuned gold — hard dependency edge #92 → #163.

## 2026-07-18 — rank-aware fixture follow-up closed won't-do

- Attempted scaling the two repeatable culls (kingslayer_den,
  market_watchgolems) to bounty-tier steps with rank-matched geared
  fixtures. Ground truth from standalone win-rate probes through
  WIBountyScaling.scale_enemy: kingslayer silver 26/50 caster-AI,
  21/40 melee-AI; watchgolems silver 45/50 caster-AI but **15/40
  melee-AI** — and QA autoplay drives the PC as melee, which is why
  the loop failed at every seed while the caster probe said 90%.
- Ruling: both culls stay fixed-difficulty (the original lane call,
  now with numbers). Branch reverted wholesale; nothing merged.
  Re-open conditions logged on #163: ally support at those sites, or
  caster-aware PC autoplay (v0.13 QA-infrastructure candidate).
- Bonus catch during the revert: the #147 gen_asset_ignores.sh regen
  never made it into PR #188 — 10 licensed battle_*.ogg sat unignored
  on main (untracked, so leak_check stayed green; a git add -A would
  have leaked them). Regenerated + committed direct to main (9fc3e46).
  Lesson folded into wi-shipping's bundle-order step: verify the
  gitignore diff is IN the PR diff, not just the working tree.

## 2026-07-18 — v0.12.0 queue closes + two re-sequencing calls

- #184 shipped as PixelLab gate set + wall tiles DERIVED from the gate art
  (castle pack rejected for the curtain wall: interior palette can't match).
  User's mid-task directive ("give the rest of the wall the same texture
  detail as the new gate") satisfied by cropping cap/face tiles from the
  gatehouse sprite itself — palette match by construction.
- #172/#171/#170 all closed (PRs #191/#192/#193): Selys retirement nodes,
  paren-styled action options (square-bracket encounter confirms left as a
  distinct pinned surface), first-waking controls hint (pending-until-
  rendered pattern — the naive queue was eaten by the first map change),
  biome-voiced empty interacts, About section with disclaimer +
  wanderinginn.com + No Killing Goblins pre-order links (user directive),
  combat blow-by-blow feeding Recent Messages FROM the HUD's existing feed
  composer (review pass killed my parallel composer — one source of copy).
- **Re-sequenced out of v0.12.0, both logged as issues**: the god-file
  dissection pair (#194 — a ~700-line extraction is the wrong last change
  before a freeze and the right first change after one) and the Ove Melaa
  selection pass (#195 — attribution already cleared, wiring is any-cycle
  content work). Ship the release on polish, open v0.13 on the refactor.

## 2026-07-18 evening — v0.13 wave planned + v0.12.1 hotfix cut

- User defined the wave (depth+polish) and streamed 19 playtest notes;
  every note is an issue (#196-#214), the two mobile progression
  blockers + journal noise + the infinite-gold exploit went straight to
  a hotfix branch (PR #226) rather than waiting for the wave.
- Infinite-gold adjudication: dirty_table keeps an UNLIMITED counter
  (the Helper curve requires same-day repeat cleans — work_loop pins
  proved gating the prop breaks a shipped progression) and gets a
  daily-tip gold cap instead; the 7 snare/snag/overlook props take the
  whole-prop daily gate. Economy re-priced in work_loop's pins.
- Discovery ran as a 38-agent workflow: 5 auditors → 32 high-impact
  claims → adversarial verification killed 4 (notably "guardian
  fragment is inert" — it's a real accessory, so SEED 2 trades by
  choice). Plan of record: docs/design/2026-07-18-v0.13-depth-polish-
  wave.md; board issues #215-#225; #194 god-files stay first.
- QA-infrastructure lessons banked: the dialogue panel's QA
  jump-to-last-page contract hid a whole surface from gates (added
  page events + qa_real_paging opt-out; mutation-verified); standalone
  run_qa doesn't grep SCRIPT ERROR but the sweep does; three scripts
  were sweep-orphans (registered; sweep 136→139).

## 2026-07-19 — v0.13 wave day 1 (Fable)

- **#111 rename**: spec recommends Option A (first-boot COPY-migration +
  rename in one release; legacy dir kept as rollback; desktop→Pages→itch
  order). Full options + engine citations in the spec; GO/NO-GO is yours
  on issue #111. No implementation until you answer.
- **#211 design adjudications** (doc §8, each reversible): enemy power =
  authored `power_level` field (NOT statline-derived); below-band fights
  gray-out to a 0.15 scale (not hard zero — `trivial` stays the only
  zero); old saves migrate with empty fractional accumulators (no
  retroactive credit); non-combat pillars stay raw-counted in v1
  (your directive); quest resolution grants skip repetition decay.
- **#194a seam engineering calls** (PR-recorded, flagged here for
  visibility): board/delivery/portal glue and _roll_loot stayed in
  WIGame; combat/_pending_encounter clear AFTER banking resolve (sync
  handlers read sim.combat); detector sets for seam byte-diffs must
  include work_loop/social_loop (only class-gain carriers) — the
  mutation lens proved level_up_loop alone is blind to that arm.
- **#211 implementation refinement (2026-07-19)**: challenge weight
  applies ONLY to combat action-tally counters + the literal
  `won_combat`; `victories` (chronicle) and specific on_victory quest
  ids stay integer-unconditional — fractional quest ids would break
  their gates (design doc §1 updated in place). Also: enemies missing
  `power_level` yield a NEUTRAL 1.0 weight (rollout-safe until the
  authoring pass lands).
- **#211 step-2 review fixes (2026-07-19, all landed pre-flag-flip)**:
  (1) enemy power lookup keys on TEMPLATE_ID (duplicate roster members
  get suffixed runtime ids — the review proved every multi-enemy fight
  would have silently neutralized); (2) repetition decay keys on a new
  integer `fought_<encounter_id>` counter, enabled-path only (the
  first-on_victory key was global for won_combat-first encounters AND
  stopped counting under gray grinds); (3) wrong-typed fractional_bank
  now rejected pre-mutation like every sibling save field. ADJUDICATED
  (review LOW-5): bounty "win N fights" conditions + erin_errand's
  won_combat gate become adversity-scaled when the flag flips —
  ACCEPTED as coherent (bounties reward real fighting; Act-I par
  fights weigh ~1.0 so the errand gate is unaffected in practice);
  flip = exempt those readers explicitly.
- **#211 power_level authoring (2026-07-19)**: 53 fields spliced from
  the delegated proposal (scratchpad/power-level-proposal.md reasoning
  preserved in git history of this entry's commit); four flags
  adjudicated — raskghar_awakened 9.0 MECHANICAL reading (canon-L20
  flavor loses to harness placement), rift_vermin T2 anchor (T4 reuse
  understates conservatively), golems base-stat values (rank-scaling
  interplay = follow-up if Pallass pacing reads wrong), relc 14.0
  directed. pc carries NO power_level (live-derived) — tripwired.
- **#211 whole-branch review adjudications (2026-07-19)**: MEDIUM-1
  FIXED — the cisterns scout grant deposited ranged_hit 4, minting
  [Archer] from a bladeless close (exclusivity violation); now deposits
  observed_things (the Tactician counter the ledge path actually
  exercises). MEDIUM-2 FIXED — WI_PACE_WEIGHTED=0 force-off arm restores
  the legacy-path regression proof post-flip. LOW-2 RECORDED: grant
  chunks cross persuade-bounty absolute conditions + innkeeper/diplomat
  requires_any in one close (coherent — the close IS persuasion; flip =
  exempt bounty conditions from grant deposits). LOW-3 RECORDED:
  adversity ratio is PC-power vs enemy-power, ally-blind (Relc-carried
  fights pay full) — matches the authored formula; revisit = party-
  adjusted ratio. LOW-1 RECORDED: no shipped canonical proves in-fight
  *_skill_used growth under the flag (milestone fixtures pre-qualify);
  the pace harness covers the deposit path — a dedicated at-par tally
  canonical is queued as a follow-up.
- **b1 Rags design adjudications (2026-07-19, doc §refs)**: back-away
  now banks goblins_spared too (outcome-based mercy — Erin's sign cares
  that goblins LIVE; garden leg becomes pacifist-reachable, ruled
  thematically correct); conduct bar v1 = goblins_spared>=1 AND never
  hunted the camp (fought_chieftains_raid==0) — the sign-defense fight
  stays forgivable (self-defense in canon terms); quest title/problem
  ("The Chieftain's Price", medicine-after-Watch-sweep) are
  invention-within-gap, flagged; FIGHT close pays a deliberately small
  grant (ambushing a parley is not adversity).
- **b1 whole-branch review wave (2026-07-19)**: MAJOR-1 FIXED — quest
  restructured to a true two-visit shape (settle behind leave-and-return;
  BROKER's Liscor fiction now literal); MEDIUM-2 FIXED — settled-state
  hide_when everywhere + third-visit canonical guard (kills the net-zero
  pawn/commerce pump); MEDIUM-3 FIXED — both when-validators sanction +
  cross-ref `absent` (typo-mutation-proven); MEDIUM-4 split — Erin's
  hardened lines SHIPPED (early-positioned so main-thread relays outrank,
  H1 lesson), camp talk-pool DESCOPED to the c3 follow-up; LOW-5 SUPPLY
  grant de-minted (handing medicine ≠ persuasion — kills the Diplomat
  auto-mint; BROKER keeps persuaded 4, brokering IS persuasion); LOW-6
  betrayal settles via on_victory (win-only; lose/flee leaves the quest
  open — flip = settle on defeat too); LOW-7 sprite stays 0.09 with
  corrected comments (0.08 failed the eye-read; c3 owns the true
  silhouette). ALSO: the shared-file checkout trap fired live during the
  validator mutation probe (wiped the uncommitted on_victory hunk,
  caught same-minute by re-grep) — the ledger rule held.
- **b2 #218 adjudications (2026-07-19, design §5 + review)**: trust gate
  = `brothers_job_done` (the #133 arc close) + `eyed_the_stash`
  doorbell; ~1.4× fence premium, buy-only v1, no buyback (all 8 records
  verified loss-making on resale, [Bargain] can't touch the node); two
  uniques (gray feather, parlor coin), flavor-tier. Review wave:
  phosphor pulled from the pool (Wilovan's shelf sells it — a fence
  copy made his 20g click a deterministic gold-for-nothing no-op;
  replaced with the traveler charm, sold nowhere else); patter
  contraction pass (Ratici drops g's — his parlor talk-pool is the
  register contract); hub line first-person; Wilovan hands trusted
  players to the chest (shelf dead-end retired). Fence pool gains
  bounty-style static validation (code-built graphs bypass the
  dialogue validators).
- **b10 #204 adjudications (2026-07-19)**: the recovery-beat gate is
  RITUAL, not difficulty — a cold press costs one toast and the 2-plate
  order is trial-solvable in ≤3 presses; the real costs remain the
  shipped unseal convergence (fight OR persuade). The issue's "too
  easy" is answered with ceremony + readable feedback + a [Detect
  Magic] payoff. Escalation if you want real teeth: a wrong press
  wakes the guardian early — say the word. Also: dead-guardian pedestal
  fiction fixed via toast variant; fixture monotone-chain rule for the
  new counters deferred (the coherence validator whitelists chains —
  #122 grandfather precedent; follow-up ledgered).
- **b4 #219 adjudications (2026-07-19)**: Grimalkin's study contracts
  are PRIVATE postings (`board: false` — they never ride Liscor's
  rotation; slate purity proven by board_loop's unchanged pins) with
  the SOCIAL pillar tag (participation pays, the kills themselves
  already pay combat XP). Two "no new code" deviations, both
  3-line-class: the board:false row flag, and an optional string value
  on `open_board_turnin` = the turnin VOICE key (value-less keeps
  Selys byte-identical — unit-pinned all four voice×met arms; his MET
  arm has no canonical crossing, so the unit pin is its only
  executable proof). Design-doc correction: the board_accepted bool
  gate HIDES both directions (no visible-locked tease exists) — the
  single-slot proof is the mutual-exclusion option-array pin pair, and
  the slot+caster gate composition routes through a `studies` node
  (one gate per option dict, no whitelist change). Payouts re-anchored
  16/24/32 by the multiple-of-4 validator. Lean canonical scope:
  delta-completion/payout/tiers are the shipped board machinery's own
  proofs (board_loop/bounty_rank_loop re-run green) — the study loop
  pins only the NEW surfaces (accept-at-hub, slot exclusion, voice).
- **b4 #219 review-wave adjudications (2026-07-19, 14/14 confirmed
  findings)**: (1) accept options' hide_when on accepted_bounty_*
  KILLED — those counters never reset, so accept-then-abandon
  permanently retired a study (live-reproed); the hub's
  board_accepted:false slot gate already prevents double-accept, and
  delta rows are repeatable by design. (2) Desk/paper matching added:
  a MET foreign posting was consumed and paid at the wrong desk
  (live-reproed both directions — road_cull paid under Grimalkin's
  "Adequate", a met study paid under "I'm the Guild"). Machine key =
  the board flag itself (giver is display prose corpus-wide);
  foreign paper renders a refusal arm, never consumes. Selys foreign
  + private-abandon lines added; all arms unit-pinned. (3)
  Challenge-weighted counters vs "three engagements": ACCEPTED AS
  DESIGN — #211's weighting applies to every combat bounty (road_cull
  identically); fresh at-level fights deposit 1.0 each so the nominal
  contract is honest, and starving on grinds/stomps IS Grimalkin's
  fiction ("I will know if you perform for the ledger"). Flagged into
  the #211 leveling-feel taste read. (4) Voice: his hub variant
  cloned Selys's "I'm the Guild" cadence — rewritten in his register;
  study-row copy/giver re-cut to the corpus signature convention
  (prose giver with voice note, no em-dash signature). (5) Variant
  shadowing (casting greeting wins for a both-studies completer)
  ACCEPTED — one greeting slot, later-match-wins is the shipped rule.
  Coverage: casting-row gate negative proof + lockout regression +
  both completion variants now unit-pinned on the SHIPPED graph.
- **b7 #207 adjudications (2026-07-19)**: recipient acks are pool
  STAGES (permanent registers). Review found the one-shot acks
  near-dead on the ordinary path (the board window forces deliveries
  to times_slept>=1, when warm-terminal gates are usually met).
  Resolution: STANDING-run familiarity stages promoted ABOVE the warm
  terminals (permanent-vs-permanent — the courier familiarity is the
  more specific register; active story threads still outrank), so the
  ordinary path DOES acknowledge; one-shot acks stay lowest-priority
  and render only in the pre-terminal window (accepted shadow-out —
  a months-later "it arrived!" would be worse). Selys/Olesm one-shot
  acks accept the same shadow (no standing rows there). Prop acks:
  stall = toast variant (observe is a Tactician grant — an
  observe-only ack would be class-gated); grate = observe override
  (its toast is door-blocked post-cisterns).
- **b7 #212/#213 adjudication (2026-07-19)**: "after meeting the dog,
  rumor toward the bond skill" — meeting the dog banks nothing, so the
  Selys rumor keys on soothed_a_beast (the Tamer chain's own entry):
  it fires exactly when the player IS a prospective Tamer. In-situ
  telegraphs ride the dens' locked_toasts (unpinned copy) pointing
  back at tending hurt beasts; the find-the-corusdeer pointer is a
  Krshia base-pool line (rotation append, text-safe — pool pins are
  speaker-only). The pinned corusdeer interact toasts are untouched.
- **b7 #212/#213 review-wave adjudications (2026-07-19)**: signposts
  are GUIDANCE, so shadow-out that was acceptable for #207's flavor
  acks defeats these — fixes: the corusdeer pointer now ALSO rides
  Krshia's five unpinned warm/neutral stage pools (the base-pool copy
  was near-dead once any stage armed; fair_weight untouched, its idx
  pin holds), the Selys signpost repositioned ABOVE her warm terminal
  (mid-game soothers hear it; story threads still outrank), and the
  trigger-site hint is the corusdeer's own observe extension (its
  interact toasts stay verbatim-pinned). Accepted staleness, bounded:
  the pup rumor persists briefly after taming (no taming-specific
  counter exists and the PR bars new ones); the pointer persists
  after the class is earned. Copy fixes: "Hrr." corpus form,
  "looked in on" (soothed_a_beast attests the visit, not the splint),
  signpost id prefix (thread_ implies a paired neutral retire).
- **b7 #214 adjudications (2026-07-19)**: (a) the [Detect Magic] Door
  hint is ALREADY SHIPPED — cellar_wardwork (13,5) beside the pantry
  door is the detect quartet and its read copy already states the
  Door's nature obliquely ("bound this cellar's door long before it
  learned to go elsewhere"); no change, cited on the issue. (b) the
  [Open Doors] joke is a skill-level `door_flavor` key + a small
  field_skills fall-through arm on door-shaped targets (a data key,
  not an effect block — test_effect_text's empty-effect pin holds);
  fires on any door by design, the pantry door included. (c) fishing
  = ONE item-gated bank prop (pond_edge, on the pond's water-wall
  cell so it reads as reeds; the freezable (10,17) stays clear), no
  catch item, no fishing system — the issue is affordance clarity.
  The interact arm gained the String|Array requires_item gate the
  bench path already had (absent key = met — every shipped prop
  byte-identical; unit-pinned both ways).
- **a7 #208 adjudication (2026-07-19)**: hotbar capacity has never
  been a constant — the bar renders whatever the loadout yields. The
  auto-slot cap is set at 9: the number-key hints are the bar's honest
  affordance, and slot 10+ has no key. AUTO mode (empty loadout)
  already shows every field skill, so auto-slot only touches CUSTOM
  loadouts; selection stays manual (a full bar never grows). Two call
  sites (sleep end, consolidation accept) reconcile a known-before
  snapshot — new field skills only, LOADOUT_CHANGED auto:true.
- **a6 #206 adjudication (2026-07-19)**: both thresholds doubled
  (dusk 200→400, night 450→900) — the directive names the day, but
  "night still arrives too fast" is the second complaint and scaling
  only dusk would have COMPRESSED the dusk window against night.
  Seven night fixtures re-based 500→1000 actions (500 would read as
  DUSK under the new bands — their canonicals' night semantics held).
  Five sized in-run crossings re-derived with documented math
  (atmosphere_check, garden, riverfarm ×2, invrisil); the riverfarm
  seed-searched fight held (no-op interacts consume no rng). FEEL
  read queued: the doubling is data (moods.json) — one knob to
  re-tune on the word.
