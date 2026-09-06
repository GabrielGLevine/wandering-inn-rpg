# Roadmap

Insertion: head. Update current facts in place. GitHub milestones and issue
briefs own scheduling; merged PR bodies and git history preserve completed work.

The current user-directed roadmap is [#502](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502). It prioritizes
mobile parity, Rogue discovery, and purchase confirmation, then progression
trust, a living world, tactical identity, and release readiness.

## Outcome milestones

| Order | Horizon | Milestone | Acceptance gate |
|---|---|---|---|
| 1 | Now | [01 - Mobile parity and a clear first session](https://github.com/GabrielGLevine/wandering-inn-rpg/milestone/13) | [#511](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/511) |
| 2 | Next | [02 - Trustworthy progression across playstyles](https://github.com/GabrielGLevine/wandering-inn-rpg/milestone/14) | [#516](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/516) |
| 3 | Next | [03 - A living inn and a responsive world](https://github.com/GabrielGLevine/wandering-inn-rpg/milestone/15) | [#520](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/520) |
| 4 | Later | [04 - Tactical identity and coherent game systems](https://github.com/GabrielGLevine/wandering-inn-rpg/milestone/16) | [#526](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/526) |
| 5 | Later | [05 - Accessible, reliable release candidate](https://github.com/GabrielGLevine/wandering-inn-rpg/milestone/17) | [#530](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/530) |

Milestones are ordered outcomes, not date or version commitments. Each issue
contains scope, numbered acceptance criteria, dependencies, an execution role,
owned surfaces, and verification. Assign a named implementer and branch at
dispatch. `successor-ready` marks work that can start; `roadmap:blocked` marks
delivery prerequisites; `taste-gate` retains explicit user-held rulings.

## Start here

1. [Purchase confirmation #504](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/504): explicit price/confirm/cancel and protection against repeated input.
2. [Mobile parity matrix #503](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/503): iPhone Safari and Android Chrome against desktop; publish findings before dispatching repairs.
3. [Rogue discovery #508](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/508) plus [schema consumers #477](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/477): fresh-save acquisition, first useful Stealth action, and continued growth.
4. [Mobile save import #253](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/253) and [opening guidance #507](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/507).
5. Responsive layout, touch flows, message readability, and critical mobile lifecycle repairs; exact dependencies are in the GitHub index.

Real-phone checks require actual devices. Unavailable hardware does not block
diagnostics or repairs, but does block claiming mobile parity. Critical
background/resume, audio, keyboard, rotation, input and save defects belong to
M1; sustained performance optimization follows in M5.

## Preserved scope and decisions

- #494 and #495 decide equipment/resonance semantics; #514 implements the recorded rulings.
- #485 owns consolidation coverage/naming decisions. Current inventory is required; completion of all #452 tooling is not a prerequisite for preparing that decision.
- #434 keeps its existing M3.6 golden gate; compiler M4 cannot dispatch until that exit is met. #438 remains the compiler/caster acceptance umbrella. Continuous route authoring can proceed using existing tools.
- #348/#452 retain ownership of their remaining work; reconcile shipped slices before implementing old briefs from scratch.
- #347 dynamic unique-class exploration remains deferred. #19 stays in M-STEAM behind its separate distribution gates.
- Native mobile apps, portrait-gameplay redesign, PWA/cloud saves and new regions are not committed by this roadmap.

## History

Remaining open work from the historical v0.19/v0.20 milestones moved into these
outcome milestones. Completed issues and PRs retain their original record.
The former local wave narrative is available in git history; do not use it as
the current work queue.
