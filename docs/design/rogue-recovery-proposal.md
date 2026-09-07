# Rogue recovery after the gate-road fight

Decision for #508 acceptance 3. No acquisition change has been implemented.

The unregistered fresh-character diagnostic `probe_rogue_recovery_exhausted` at base `a1716c4e`
creates a character, earns Warrior and a spear, defeats the road goblins,
meets Klbkch, recovers the crate by force, returns through ordinary doors,
uses the drainage cut, crosses the cleared road and sleeps. Seed 7 completes
293 steps with both Rogue entry counters absent and no Rogue grant.
The same Watch options hide after guile recovery: the Light report in
`krshia_crate.json` records `found_the_crate`, which hides both options in
`watch_crate.json`. Its quest reward grants growth credit, not either Rogue
entry counter. This analogous branch is source-inspected; the fresh diagnostic
above exercises force. The drainage lead points at an exhausted producer in
both histories when the road encounter was already defeated.

## Proposed decision

Allow the existing drainage-cover crossing to earn `crossed_under_cover`
after the road encounter has been defeated. Treat the deliberate covered
traversal as the qualifying act, even on the cleared road.

- Require interacting with the authored cover prop during this waking, then
  walking into its authored crossing band. Using the prop alone earns nothing.
- Preserve one credit per crossing per waking, ordinary sleep acquisition,
  existing encounter removal, and the separate live-danger requirement for
  `sneaked_past_danger`. Never restore defeated enemies or grant Rogue directly.
- Keep the crossing available after force or guile recovery, sleep and reload.
  Assert no grant on a bare road crossing, a prop-only visit, or unrelated travel.
- Render a specific covered-crossing receipt; the journal keeps qualitative
  guidance. Desktop and phone-sized windowed reads verify both.

This changes the August 13 cover ruling from a live-threat crossing to an
intentional terrain traversal. #508 explicitly reserves acquisition-rule
changes for the owner, so this proposal needs a decision before implementation.
The code should derive the crossing geometry from the authored encounter even
when its runtime entity has been removed, without making it targetable again.

## Alternative within the existing acquisition rule

Add another authored cover prop beside the existing respawning night patrol,
using its unchanged live-threat and once-per-waking cover mechanism. Redirect
force/guile leads there. This preserves acquisition and respawn rules, but night
starts at action 900 and sleep resets the clock; there is no shipped wait-until-
night action. It offers eventual recovery with a substantial first-session
usability cost. Padded QA walking would prove mechanics, not discovery.

Changing a conversation-first daytime animal encounter into an ambush, making
the night patrol permanent daylight content, or respawning the defeated road
goblins changes additional gameplay and is not the recommended repair.
