# Quest Clarity — design spec (hint slice + causality map)

Status: SPEC — user direction 2026-08-02 ("Journal should say 'Go talk to
Pisces about the stone', with an option to turn hints off"). Recon:
wf_b87d9109 quest-clarity reader, verified vs main @ 7fe8b85. The feature
is ~70% shipped already; this spec covers the remaining slice and the
fresh adjudication it needs. The one hard DEFECT found (the attune beat)
ships in wave-2 immediately (CHOICE-LOG ruling 15), not here.

## What already exists (do not rebuild)
- quests.json beats carry authored person+place next-step prose, audited
  under the user-approved #148 Thread Legibility Spec.
- WIQuests.evaluate surfaces exactly the active beat; the Journal renders
  "<Title> (<Region>) — <active beat text>". The friend's target line
  already reads: "Bring Krshia's catalyst to Pisces, by the Guild steps
  on Market Street, and see how far the Door can reach."
- A settings toggle of exactly this shape ships end-to-end:
  field_hud/show_quest_thread (default OFF).

So the friend's complaint decomposes into: (a) beats whose prose points
at the WRONG completer (the attune defect — wave-2), (b) beats that are
narration rather than instruction (small audited set), (c) discoverability
of the journal line itself.

## Fresh adjudication (supersedes thread-legibility-spec §105-121 in part)
The owner has now asked for clarity-by-default with an immersion off
switch. Ruling: a NEW sparse per-beat `hint` field — a short imperative
line rendered as an indented sub-row under the quest line (Postings
indent precedent, journal.gd:914) — DEFAULT ON, gated by a new settings
row "Quest Hints" (cloned from reduce_motion, appended before "Back").
The existing field-HUD "Quest Thread" knob is untouched (stays
default-OFF). "No floating quest markers, ever" stands. The
anti-trivialization rule relaxes ONLY for the journal sub-row; relay
dialogue keeps WHO/WHERE-never-WHAT-TO-DO. This is a deliberate
supersession, logged in CHOICE-LOG when the slice ships.

## Rulings on the recon's open questions
1. Hint is SPARSE (option c): only beats whose description cannot carry
   the instruction get one — no doubling 60+ rows of copy.
2. Hints are STATIC strings; state-awareness comes from SPLITTING beats
   so each has one actionable condition (the attune fix is the
   template). No conditional hint evaluator.
3. Toggle scope: journal sub-rows only. The "Quest updated:" toast and
   Leads strip are untouched (the sim cannot read WISettings; gating
   the toast means message_layer suppression — not worth it).
4. where_the_door_reaches region beats stay EXCLUDED (authored
   vagueness; Leads already carry WHO/WHERE) — noting wave-2 already
   re-cut its invrisil beat under the amended "reach, never objects"
   rule (CHOICE-LOG ruling 2).
5. ui_journal_shown payload gains quest_line_texts + quest_hint_lines
   (additive, closes the count-only gap at journal.gd:486). Pin policy:
   hint array pinned in ONE dedicated canonical only.
6. chieftains_price/price narration-beat: re-cut to imperative in the
   slice's copy audit.
7. Tripwire: `_beat_needs_place_name`'s empty-producer early-out
   (test_content.gd:1478-1484) closes in wave-2 — code-banked beats must
   name their own completion condition.

## Implementation map (seams, from recon — all additive)
data `hint` key (policed free by _scan_player_strings; not `_hint`) →
quests.gd:60 evaluate carries it → sibling `quest_hint_lines()` in
wi_game (quest_summary shape untouched — field_hotbar:287 pins it) →
journal indented sub-row + snapshot in _open → settings row (three-site
wiring: _row_text/_refresh/_activate_row; settings_loop.json's "down x4
to Back" count shifts by one — re-pin) → copy tripwires (no %, no ` -- `,
no {addr} in quests.json ever) → landmark tripwire on any re-cut travel
beat. test_copy_fit has NO journal-body budget — the overflow check is a
windowed machine-playtest read, budget it.

## Note 26: the story causality map (separate deliverable)
The friend's structural ask ("map/pace the story manually; x-causes-y-
causes-z") is content architecture: a hand-curated
docs/design/story-causality-map.md tracing every act gate, quest chain,
accomplishment producer→consumer edge and region unlock, with the
dead-end/opacity audit wave-2 exposed (invrisil_attuned had ONE producer
named nowhere; dungeon_attuned's chain was accident-proof only). Build it
agent-drafted from data + hand-verified, then keep it a living doc wired
into wi-adding-dialogue-and-quests (new quests add their edges). It is
the durable cure for the class of bug wave-2 fixed twice.
