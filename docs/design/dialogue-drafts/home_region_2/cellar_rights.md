# cellar_rights_krshia.json + cellar_rights_sergeant.json — shared companion

**Narrative purpose:** "Cellar Rights" (spec §2) — the Dark Cellar pays off
as a two-sided civic dispute. Tone target: low-stakes municipal comedy with
real texture; nobody is wrong, which is the point. The [Diplomat] showcase.

## Canon cites
- Krshia's register per character-profiles.md (measured, "Hrr." sparingly —
  used 1x per node text max here, matching krshia_crate.json density).
- Silverfang clan pre-war Liscor commerce is canon-adjacent (Krshia's wiki
  entry: Silverfang tribe merchants embedded in Liscor a generation back);
  "my aunt's paw drew that kind before the last war" extends it. **OPEN
  (canon-extension):** Gnollish trade-signs as a marking system is our
  invention — plausible (Gnoll tribes are canon-literate traders), cite
  nothing specific. Verify no wiki contradiction at wiring.
- The sergeant is the shipped watch_crate.json voice (already in-game;
  no staging profile exists for him — his 3 voice notes are effectively:
  clipped lists, dry understatement, allergic to ceremony).

## Design decisions to review (OPEN)
- **Both sides can GIVE the quest** (both give-options fire
  `{"quest":"cellar_rights"}`; the second giver's is hidden by
  `heard_cellar_rights`). Verify quest-start is idempotent at wiring, or
  strip the quest effect from one side.
- **The survey path settles for KRSHIA regardless of who you report to**
  (the marks are older than the seal — evidence decides, not the audience).
  The sergeant conceding to precedent is his best scene; flagged in case
  the user wants a symmetric report-to-decide instead (muscle path already
  does report-to-decide).
- **Muscle path = reporter decides the winner** — clearing the vermin earns
  the right to call it. Deliberate asymmetry vs survey.
- Outcome accomplishments: `cellar_rights_settled` (shared terminal) +
  exactly one of `cellar_rights_krshia` / `cellar_rights_watch` /
  `cellar_rights_shared`. The spec's "resolution dresses the cellar per the
  winner" reads these three for visual_states.
- [Diplomat] gate on the mediate WIN (visible-locked tease) while the
  mediate ENTRY is accomplishment-gated (hidden until you've heard the
  OTHER side) — this is the one-gate-key-per-dict rule satisfied across a
  two-step chain, per the skill's lyonette_tip shape.

## Wiring notes
- MERGE into the existing krshia_crate.json / watch_crate.json hubs (new
  options + text_variants) — do NOT ship as second graphs; both NPCs
  already carry conversations and the option-order note in krshia_crate's
  `_comment` (first-visible-at-0 for confirm-at-0 scripts) applies.
- `cleared_cellar_squatters` — on_victory of a new `cellar_squatters`
  encounter (squatter-vermin, cellar arena; wi-adding-an-encounter lane).
- `surveyed_smuggler_marks` — an [Observe]-gated prop in the cellar
  interior (M-DEPTH surface), same shape as `studied_the_cellar`.
- Gate the whole hub cluster on the M-DEPTH "cellar cleared" state if one
  exists — the give options currently assume the Dark Cellar arc is done
  ("you cleared that cellar"); if M-DEPTH lands a terminal accomplishment,
  add it as the give-option's `requires`. **OPEN: exact gate id.**
- Quest beats suggestion: hear (`heard_cellar_rights`) → settle
  (`cellar_rights_settled`).

## Softlock audit
Both hubs: hidden options + ungated exit ✓. mediate nodes keep an ungated
back-out; the class-gated win is visible-locked, not hidden ✓. No
start_combat in either graph ✓.
