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

## Recovery and capacity change (2026-10-05)

[Program #565](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/565) adds persistent HP/MP, actual-sleep refill, Inn/Skill-made/inventory food recovery, inventory/combat potions with AP and mana poisoning, and world vitals. [Plan](design/2026-10-05-persistent-vitals-recovery-plan.md) records lifecycle, save compatibility, proposed tuning and cutover evidence.

M2 now delivers #566 resource/saves → #567 world HUD and #568 potions/quantities/poisoning → #569 Inn/cooking recovery, with independent #570 capacity expansion. #512/#513/#453/#515 then validate earned attrition, economy, numerical balance and routine regressions. #571 activates the composed software loop; #516 retains human acceptance and selected gear-semantic delivery. No player build loses battle refills before readable vitals and reachable recovery exist.

M3 retains homecoming stories over the M2 services; M4 tactics consume the carried-resource/AP/poisoning baseline; M5 verifies resource/count/exposure migration and changed-build device/save-transfer evidence. Scope is expanded and final generic pacing/gear/journey verification follows recovery; no dates or new milestone are invented.

## Start here

Follow [#502's execution contract and current dispatch](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/502#immediate-dispatch-order). Preserve the active #564 art ownership and finish a safe checkpoint before conflicting writers. M1 software is merged through #551; #507/#508/#509 are closed. Remaining #511 and #504/#505/#506/#510/#253 observations stay attached to their original candidate. Independent M2 preparation can proceed while physical/user gates are unavailable.

Start staged #566 and independent #570, then #567/#568/#569, followed by earned-route/balance/economy/regression owners and #571. Bound compiler work to its existing golden exits; no new expansion is required for this recovery change. Browser emulation proves only its exercised route; physical-phone and human verdicts remain open until observed on the changed build.

## Preserved scope and decisions

- #494/#495 still decide equipment semantics; #514 implements them using #566 resources and #570 capacity. Capacity expansion is separately authorized and does not wait for the semantic model. Initial recommendation is 4→5 with three accessory positions; potion proposal is three safe doses per waking, fourth onward 4 HP loss. These values are tuning proposals, not additional user rulings.
- #485's six-set coverage and first-order name proposal already received GO. Reconcile remaining approved work; preserve specific canon/post-bar exceptions. Completion of all #452 tooling is not a prerequisite.
- #434 keeps its existing M3.6 golden gate and needs #542/#543's evidence corrections. Compiler M4 cannot dispatch until that exit is honestly met. #438 remains the compiler/caster acceptance umbrella. Continuous route authoring can proceed using existing tools.
- #524/#528 are dependency-ready but remain M4/M5 work. Readiness is not priority.
- #348/#452 retain ownership of their remaining work; reconcile shipped slices before implementing old briefs from scratch.
- #347 dynamic unique-class exploration remains deferred. #19 stays in M-STEAM behind its separate distribution gates.
- Native mobile apps, portrait-gameplay redesign, PWA/cloud saves and new regions are not committed by this roadmap.

## History

Remaining open work from the historical v0.19/v0.20 milestones moved into these
outcome milestones. Completed issues and PRs retain their original record.
The former local wave narrative is available in git history; do not use it as
the current work queue.
