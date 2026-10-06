# Two remembered homecomings

Design deliverable for [#517](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/517).
Source snapshot: `b1c4b02bee71ba0b0926bf1c466ad7eab65a80e6`.
Branch: `issue/517-homecoming-design`. This specification changes no game content.
Implementation and emotional acceptance remain with #518 and #520.

The two arcs extend ordinary inn activities: Lyonette learns how the player
wants help, and an evening with a Watch guest establishes how the player wants
to return. Neither awards gold, items, recovery, classes, Skills, or a relationship
score. The later response changes because of a specific choice, without making
one choice the generous answer and the other a failure.

## Existing facts and integration boundaries

| Surface at the source snapshot | Constraint on this design |
| --- | --- |
| `data/dialogue/lyonette_tip.json`: `hub`, `order_brief`, `gratitude` | Wrong Order has force, negotiation, and cooking solutions. Require `wrong_order_reported`, not merely `resolved_wrong_order`, before the new activity. Existing reports and their 3 gold remain unchanged. |
| `data/maps/inn/inn.json`: `lyonette` at `[9,5]` | Lyonette is an existing resident without a guest gate. Use her existing approach at `[9,4]`; add no furniture, NPC, movement, or reserved collision cell. |
| `data/acts.json`: Act II `watch_calls`; Act III advance | `cisterns_reported` and `raskghar_sealed` are actual story outcomes. Use accomplishments, not equality to an act number: later returns must still work. |
| `data/dialogue/zevara_intro.json`: report option requiring `cleared_the_warren` | The report banks `raskghar_sealed`. Clearing the fight alone must not unlock the second payoff. |
| `data/maps/inn/inn.json`: `relc_inn_guest` `[1,5]`, `klbkch_inn_guest` `[11,5]` | Existing guest entities and off-duty conversations own the second arc. No spar, military briefing, Hive business, or dungeon report enters these conversations. |
| `src/core/inn_guests.gd`: `met_pool`, `GUEST_POOL_GATES`, `active_guests` | Current code is a two-person sliding window, not the accepted #371 party scheduler. Do not claim the new scheduling behavior exists. |
| `src/core/wi_game.gd`: `transition`, `bind_map_silent`; `src/core/save.gd` | Real transitions emit `map_changed`; save restoration binds silently. An actual departure marker needs a small future sim hook. Loading a save must not fabricate a journey. |
| `data/maps/inn/inn.json`: Erin's ordered talk-pool stages | Story relays use last-match-wins priority. These arcs never replace an Erin relay or append an always-winning warm bark. |

All game paths in this document are relative to `wandering_inn_game/`.
Coordinates describe this snapshot. Re-read the composed #564 map before #518:
preserve final art positions and rederive approaches instead of restoring these
coordinates over art. Existing permanent home posts on other maps are a shipped
convention; the design creates no additional simultaneous inn instance.

## Arc A: Lyonette sets the count down

Purpose: after the player quietly solves Wrong Order, offer a small choice about
sharing the remaining work. On a later homecoming, Lyonette uses that knowledge
to help the player settle in. Her pride appears in careful work and specific
attention, without revealing her title or origins.

### Beat sheet

| Beat and exact producer | Prerequisites and action | State transition | Dialogue and staging intent |
| --- | --- | --- | --- |
| A0, existing `lyonette_tip` report | Accept Wrong Order through `hub`; resolve a supported route; report through its existing option | Existing `wrong_order_reported >= 1` | Keep the shipped gratitude, payment, and exit. Do not replace the reward with the new scene. |
| A1, optional appended `lyonette_tip` hub option, proposed node `home_count_offer` | Reported; neither proposed choice counter set; player selects “Still counting the supplies?” | None on entry | At her existing position, Lyonette is checking the next order. Draft: “I have counted the barley twice. Would you read the number back to me?” The player can help, invite her to put it aside, or leave. |
| A2a, proposed `home_count_check` | Select “Read it out. I'll check with you.” | Set `home_count_checked = 1`, once | A short shared check, represented by dialogue, not a new economy minigame. Draft: “Yes. That is what I have. I shall leave the page alone now.” The PC has helped with the work rather than taking over her job. |
| A2b, proposed `home_count_sit` | Select “Put it down for a minute. Stay and talk.” | Set `home_count_company = 1`, once | Lyonette sets the count aside voluntarily. Draft: “A minute, then. You can tell me how your day has been.” Do not assert a particular quest solution or invent the player's account. |
| A3, next real departure to `floodplains` or `street` after either A2 choice | Leave through a supported door or unlocked Magical Door; upstairs and the garden do not count | Set `home_count_departed = 1`, once | No popup, task demand, or extra reward. A small future sim hook records travel; ordinary map rendering continues. |
| A4, later interaction with `inn#lyonette` | One choice, departure marker, `cisterns_reported >= 1`, and no `home_count_returned` | Selecting the optional return topic opens a choice-specific response; no terminal mutation on arrival | Check branch: “The order is counted. I checked the second column the way we did. You can put your bag down.” Company branch: “I've left the count for a minute. Sit with me, if you have time.” These are drafts, not final runtime strings. |
| A5, explicit closing choice after the response | Player selects “I'll stay a little.” or “I have to go. Thank you.” | Set `home_count_returned = 1`, once | Both accept the remembered gesture; no sitting animation, healing, time advance, or task completion is implied. Remove the one-shot topic afterward. Existing ordinary conversation remains. |

“Another time” at A1 ends without a choice flag or penalty. Re-entering A1 can
still choose either branch. Once chosen, the other branch is hidden; no repeat
credit accrues. Ordinary serve, meal, and work actions retain their own costs
and effects. The line about a bag is spoken staging, not an inventory operation.

Wrong Order's route flags can coexist. Do not infer a uniquely chosen method
from whichever flag is checked last, and do not make one path the canonical
memory. The new choice itself is the remembered event. A character who cooked
the order and later cleared the supplier still receives exactly the chosen A2
response, without an inaccurate retelling of the old quest.

### Reachable ordering and missed beats

- Early path: report Wrong Order → A1/A2 → leave the inn → complete/report the
  cisterns → return to Lyonette → A4/A5. Full travel and acquisition are required
  in #518's earned route, using the current supported Wrong Order solution.
- Late path: finish the cisterns first, then report Wrong Order and choose A2.
  No instant payoff: make one new real departure and return. The response only
  mentions the shared count or conversation, so it does not pretend the player
  just finished the cisterns or did the quests in the other order.
- Skip Wrong Order or leave it unresolved: A1 remains unavailable; the existing
  report and reminder continue normally. There is no new penalty or fake warmth.
- Finish later acts before returning: A4 remains eligible. Never gate it to
  `act_ii` exactly or consume it when an act advances.
- Lyonette is currently a permanent resident. If future content removes her,
  defer her response until she is actually present; do not spawn a substitute or
  put her words in Erin's mouth. If a future change removes her permanently,
  #518 must revise this dependency before shipping that change. Current source
  provides no such disappearance path, so the specified arc has a resident host.

## Arc B: An evening kept for you

Purpose: a Watch guest remembers whether the player wanted company or quiet,
then offers the same courtesy when the player returns. The inn remains an
off-duty space. The warren report is a pacing gate, never a subject for this
conversation, and no speaker claims credit for accompanying the player.

### Guest and knowledge contract

Consume #371's accepted party schedule: one eligible party per waking,
`[relc, klbkch]` as the Watch pair, filtered to actually met and eligible members.
Keep authored chair locations. If only Relc is met, he can host alone; if only
Klbkch is met, he can host alone. With both present, either entity can start the
same arc, but they share one choice and completion state. The other member
gets lines only while actually present. Never wait for the pair to become
complete before allowing a solo member's arc.

The existing `GUEST_POOL_GATES` currently excludes Zevara during her active
summons and Pisces during the Door mounting window, and applies other guest
eligibility rules. #371 must retain those member filters before selecting a
party. Relc/Klbkch have no corresponding current pool exclusion; do not invent
one or overwrite the accepted cross-map home-post convention. Any later active
quest absence from #371 is obeyed, never bypassed by a homecoming flag.

Lyonette explicitly hears and acknowledges the player's preference in the
setup conversation. This gives the permanent resident a valid fallback if the
original guest is absent later. A line by Lyonette uses the existing resident,
not a second entity, and has no implied teleport or walk across the room.

### Beat sheet

| Beat and exact producer | Prerequisites and action | State transition | Dialogue and staging intent |
| --- | --- | --- | --- |
| B0, met-member history | Meet Relc at `floodplains#relc`, or use Klbkch's existing plaza talk at `street#klbkch`; sleep as necessary until that party is active | Existing `chatted_with_relc` / `chatted_with_klbkch` and scheduler state | Meeting through the actual talk path matters. No fixture-only meeting and no required spar. |
| B1, appended optional topic in `relc_inn` / `klbkch_inn`, proposed node `home_evening_offer` | Initiator is present under #371; no choice or terminal counter | None merely from opening | Relc draft: “You keep standing there. Stay a bit. Want some company?” Klbkch draft: “You may stay here. I can continue the conversation, if you wish.” Ordinary serve/exit options remain accessible. |
| B2a, proposed `home_evening_company` | Select “Keep talking. I've had enough road for today.” | Set `home_evening_company = 1`, once; record the actual initiator as one of `home_evening_host_relc` / `home_evening_host_klbkch` | Relc discusses his meal; Klbkch continues his off-duty observations. No road itinerary or specific injury is asserted by the NPC. |
| B2b, proposed `home_evening_quiet` | Select “I'd like to stay. Quietly, for a while.” | Set `home_evening_quiet = 1`, once; record actual host as above | Relc draft: “All right. I'll get on with my dinner.” Klbkch draft: “Understood. I will stop asking questions.” Quiet is respected without disapproval or a lost reward. |
| B3, setup acknowledgment inside the same optional conversation, proposed `home_evening_note` | Choice made; if interrupted, expose this continuation at Lyonette as well as the original host while present | Explicit player continuation after Lyonette's line sets `home_evening_noted = 1`, once | Lyonette acknowledges the request directly: company, “I'll leave you a little time together, then”; quiet, “I'll keep the questions for later.” This is witnessed knowledge, not an assumed off-screen message. On every resumed B3 conversation, the PC explicitly repeats the preference to Lyonette before her acknowledgment, even if the original note never rendered. |
| B4, next real departure to `floodplains` or `street` after B3 | Noted flag is set; real transition occurs | Set `home_evening_departed = 1`, once | No instant close on the setup waking; upstairs, garden trips, loading, and mere UI reopening do not count as departure. |
| B5, a later optional return topic | Noted + departed + `raskghar_sealed >= 1`; no `home_evening_returned`; player interacts with actual original host, or with Lyonette when that host is absent | Open the branch-specific payoff without marking it complete yet | Relc/company: “There you are. I was saving the rest of this story.” Relc/quiet: “You're back. Go on, get comfortable. I'll leave you be.” Klbkch/company: “Welcome back. I have another observation, if you have time.” Klbkch/quiet: “Welcome back. You asked for quiet. I remember.” |
| B5 fallback, `inn#lyonette` | Same readiness; actual original host absent, regardless of another party or the other Watch member being present | Same shared payoff state | Company: “You asked for some company last time. I can spare a minute.” Quiet: “You asked for a quiet minute last time. Take it. I'll carry on here.” Her own B3 acknowledgment is the knowledge source. No absent guest speaks. |
| B6, explicit closing choice after B5 | Player stays or politely leaves | Set `home_evening_returned = 1`, once, shared by all entry points | Both choices preserve the response. No new food, sleep, recovery, companionship bonus, or automatic scene movement. All duplicate payoff entry points disappear. |

“Not tonight” at B1 leaves setup available on any later eligible visit and
banks nothing. Missing a party rotation loses no memory. If the original host
is absent for an entire later quest, Lyonette can deliver the payoff. If only
the other Watch member is present, that member must not pretend to remember a
conversation they did not hear; use Lyonette. Party arrival after completion
does not replay the response or imply that both guests were there at setup.

If the player seals the warren before first meeting either guest, B1–B3 still
work when a met member visits. Require the new departure and return afterward;
the response does not say “after the warren” or claim first-time relief. If the
player never reports the warren, ordinary guest conversation remains and B5
waits. The new arc never grants the report counter or redirects the main quest.

## State, interruption, and implementation contract for #518

All `home_*` names above are **proposed**, absent from this source snapshot.
Use existing persisted accomplishments for monotonic booleans, with exclusive
choice and host pairs. A new saved relationship subsystem or numeric meter is
unnecessary. Register keys in the authoritative catalog during implementation;
do not hand-edit generated indexes. Legacy saves have no new flags and acquire
no imagined preference. Coordinate any validation/migration requirements with
the resource work rather than allocating a save version here.

The small sim extension records each departure only after its prerequisite
choice/acknowledgment, from a real successful transition out of `inn` to
`floodplains` or `street`. It must preserve the old map before `transition`
binds the destination. A garden/upstairs detour alone is insufficient. Do not
attach this to the renderer, to a generic signal replay, to `bind_map_silent`,
or to imported save position. A rejected exit grants nothing. Existing world
interactions and portal travel must be audited for the common transition path.

Keep the two arcs independent: completing A does not start or close B. The
optional Lyonette topics can coexist in a fixed authored order; opening one
must not consume the other. Existing quest options and always-available exit
retain precedence. Prefer appended gated optional topics over replacing hubs
or talk-pool stages; rederive affected visible option pins explicitly.

Choice effects commit once through the production dialogue path. A reload
after a choice but before its response can recover the continuation from the
hub, including B3 at Lyonette. A payoff remains replayable until its explicit
closing choice; reading a page, closing the panel, or loading a save must not
silently bank completion. Replaying unfinished prose has no economy effects.
This requires a future persistence seam: `Game.save_manual`/export currently
refuse an active dialogue, and `Game._on_domain_event` does not autosave arbitrary
accomplishment changes or dialogue choices. #518 must add a narrowly scoped
post-effects checkpoint for these memory commits, through the Game adapter.
Complete the exclusive preference + actual host effects as one logical commit
before exposing it for saving. `dialogue_choice` and `dialogue_ended` are both
emitted before option effects finish; neither is a valid checkpoint trigger.
Likewise, bank departure before emitting the `map_changed` event whose listener
saves it. Coordinate this ordering with #566's ongoing autosave work.

The checkpoint persists monotonic memory, never the live dialogue walker.
On reload, recover the corresponding optional continuation from an ordinary
NPC interaction. The future checkpoint adapter must retain the last valid save on failure,
write through a temporary file and atomic replacement where supported, and
surface a failure instead of announcing success. These are new obligations:
current `Game._write_slot` silently returns on open failure and writes directly
to the destination. Coordinate this adapter work with the resource/save lane;
no claim of existing atomic file writes is made here. Do not claim a choice was
durable without a successful write. If browser background/load interrupts the last
choice, durable state is either the prior complete commit or the new complete
commit. It must never contain a preference without its required host, a switched
choice, or a half-completed terminal update. Test actual browser reload from
those checkpoint bytes; mid-dialogue manual saving is not a shipped capability.

The current `_build_dialogue_ctx` and `WIDialogue` gate vocabulary do not
expose actual guest presence. #518 therefore also needs a narrow pure derived
availability seam for these topics: resolve the original host from the persisted
exclusive host flags, query the same current inn entity-presence predicate used
by #371/world presentation, and combine that with the current source entity
and readiness flags. Feed the resulting topic availability into dialogue context
and its gate reader; refresh it on every node advance and on topic entry. Do not
persist absence counters or infer absence merely from whether the partner was
met. At Lyonette, B5 is available only when the original host is absent; at the
original host it is available only when that host is actually present. A B3
continuation at Lyonette remains available regardless of the host's presence.
The other Watch member cannot impersonate the original host. This is future
implementation scope, not a capability of the current accomplishment-only gates.

When the game shows an optional return topic, reevaluate actor presence and
readiness on entry. Do not interrupt combat, sleep/progression, a purchase
confirmation, another dialogue, or a mandatory story cue with an unsolicited
arrival scene. Use the existing dialogue renderer and speaker changes. No
cinematic system or blocking/tween behavior is specified by this design.

### Implementation slices and owned surfaces

1. Compose #371's party scheduler and its tests first; keep #518 dependent on
   the accepted guest rules, not a second temporary scheduler. Preserve art's
   final inn layout and resident/guest entities.
2. Add the accomplishment definitions, minimal real-departure hook, and
   derived topic-availability context/gate in pure sim (`dialogue.gd` included); test transition versus silent load, exclusivity, and exactly-once
   state. Serialize `wi_game.gd`, `src/core/game.gd` checkpoint wiring, shared catalogs,
   and save validation with #566–#570. Invoke the matching GodotPrompter domain skills before coding.
3. Add the optional dialogue nodes in `lyonette_tip.json`, `relc_inn.json`, and
   `klbkch_inn.json`, using existing entity IDs. Audit all visible-options pins
   and producer/consumer ordering. Do not move NPCs or revise Erin's relays.
4. Add earned route coverage and bounded state tests, then regenerate QA
   surfaces on the composed tree. Core work requires the full gates. Rendered
   confirmation and windowed observation are part of delivery, not this prose.

## QA and acceptance matrix

| Case | Actual input/history required in #518 | Expected domain, rendered, and state evidence |
| --- | --- | --- |
| A-check / A-company | Earn/report each Wrong Order solution across cases; choose A2; actual travel; earn/report cisterns; return | `dialogue_choice` and accomplishment state match exactly one preference; the later `dialogue_node` identifies that branch; `ui_dialogue_page_rendered` confirms the page, with the actual branch text verified by windowed read; closing commits one terminal flag. |
| A mixed method | Bank more than one old solution flag by real supported actions; select either new preference | No guessed method, switched choice, duplicated payment, or claim that only one old solution happened. |
| A late | Cisterns report first; A2 later; interact before and after real departure | No immediate payoff before departure; correct response on the subsequent return, including Acts IV/V. |
| B solo histories | Meet only Relc, then separate case only Klbkch; reach inn through real travel/sleeps | One selected party, only met members rendered; either guest starts the arc without inventing the other. |
| B paired history | Meet both in each order, sleep into their party, interact with either member | Both actual guest entities; one choice/host and one terminal state; second entry point cannot start a competing arc. |
| B quiet / company | Choose each branch, observe B3, depart, report the warren, return to original host | Exact corresponding response; no military/Hive lines or assumption the guest joined the delve; no recovery change. |
| B absent host | After B3, rotate original host out or exercise a real future quest exclusion; return when ready | No absent speaker or forced guest spawn; Lyonette remembers her explicit acknowledgment; later guest return does not replay completion. |
| B other member only | Original host absent; only the other member eligible | Other member does not falsely claim shared memory; Lyonette fallback remains reachable. |
| B late / report missing | Seal before setup; separate case clear the warren but do not report | Late setup needs new departure; clear-without-report leaves payoff pending. |
| Skip/refuse | Exit each offer; skip a party waking; leave a main quest unfinished | No preference or penalty, no forced quest advance, normal conversations and exits still usable. |
| Load/interrupt | Save/reload before choice, after choice, before B3, after B3, after real departure, during payoff, after close | Choice and original host stable; silent load never grants departure; pending continuation recoverable; completion never duplicates. |
| False departures | Upstairs and garden return, failed exit, reload in another map | No travel credit; a later successful inn→street/floodplains crossing supplies it. |
| Both arcs / busy UI | Both ready at Lyonette; inspect each topic; enter inn during normal story sequencing | No auto-open or masked main quest; either topic can finish first without consuming the other. |
| Occupancy / readability | Full inn resident population plus eligible party; phone-scale and desktop windowed reads | Single actual actor instance, player and exits visible, correct speaker/line/options, no clipping. Web touch and physical-device observations remain separate evidence. |

Interactive graphs emit `dialogue_node`; `dialogue_panel.gd` confirms the
page layout through `ui_dialogue_page_rendered` (page/pages/panel height/cap).
That receipt does not contain speaker, text, or options; pair it with the exact
node payload and a windowed read of the actual page and visible options. The
`dialogue_line` / `ui_dialogue_rendered` pair belongs to the ambient message
layer and is not proof that a graph page appeared. Assert each expected page,
including continuation pages, with the matching graph event and renderer.

For each delivered route preserve source/tree SHA, seed, real input sequence,
zero-noise exit and passing `result.json`, the actual domain event and matching
render event, and a screenshot read at the relevant line/options. Unit fixtures
may isolate ordering faults, but do not replace earned meeting, report, travel,
or scheduling evidence. #520 owns whether the scenes feel like returning home;
this design does not claim that emotional result from a beat sheet.

## Canon, voice, and review status

The story moments above are proposed game-authored interactions, not claims
that these scenes occur in the novel. They use already introduced characters
and shipped game outcomes. No new race, class, Skill, location, family reveal,
romance, character fate, or later-volume ability is introduced.

- Lyonette's residence/work at the inn and early appearance are supported by
  [her Wiki profile](https://thewanderinginn.fandom.com/wiki/Lyonette_du_Marquin)
  and [appearances](https://thewanderinginn.fandom.com/wiki/Lyonette_du_Marquin/Appearances),
  which locate her introduction in archived Chapter 1.31. Her existing repository
  profile controls the proud-to-sincere register; her private origin stays private.
- Relc is an early Drake guardsman per [his Wiki profile](https://wiki.wanderinginn.com/Relc),
  which lists archived 1.07 / rewritten 1.05. His partnership with Klbkch is
  supported by [Klbkch's relationships](https://wiki.wanderinginn.com/Klbkch/Relationships).
  Their inn visits are already attested in the Wiki's [Chapter 1.24 summary](https://wiki.wanderinginn.com/Chapter_1.24).
  This is enough pre-Book-17 grounding; later page sections supply no new facts
  to these scenes. No later body/form, title, or plot information is imported.
- Canon checks used accessible Wiki search-index results on 2026-10-05. Direct
  canonical profile fetches returned HTTP 403; the linked indexed Wiki excerpts
  support the limited facts above. Existing `character-profiles.md`, the
  `lyonette+ledger`, `relc`, and `lift+klbkch` voice cards, and the spoiler cutoff
  remain binding. Do not treat unseen Wiki sections as verified.
- [#371's accepted scope](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/371#issuecomment-5175519581)
  already establishes the Watch party, met-member fallback, and retained chairs.
  This design consumes that ruling; it does not reopen grouping or layout taste.

Draft lines are compact samples of intent for review, not approved final copy.
Keep Lyonette's concrete counting, Relc's unceremonious off-duty warmth, and
Klbkch's literal courtesy. Avoid theme speeches, secrecy jokes after gratitude,
or a repeated emotional slogan. Their existing off-duty register exclusions
apply to every branch.

#517 acceptance mapping: clauses 1–2 are the two beat sheets and exact memory
branches; clause 3 is the party/resident/absence contract; clause 4 is the limited
Wiki/cutoff audit; clause 5 is the implementation and QA matrix. Independent
review must check these claims against the stated snapshot. There is no new
canon exception requiring a ruling. Any later proposal that changes that scope
must be presented concretely before content implementation. Runtime, rendered,
windowed, physical-device, and emotional acceptance are all still unproven.
