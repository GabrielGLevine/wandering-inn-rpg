# Wandering Inn RPG — Living Roadmap (here → launch)

> Owned by the project-lead agent per user directive (2026-07-02): think several milestones
> ahead during subagent downtime; milestone boundaries still get user feedback, playtests,
> and design discussion. Confidence decreases with distance — impending milestones are
> committed scope, far ones are direction. **Update this doc whenever a milestone closes or
> a long-lead decision lands.**

**North star (from v4 founding spec):** BG3-in-The-Wandering-Inn, built by a team of 1 +
agents. Canon from the wiki. [Skills] matter outside combat. The leveling system (action-
driven, sleep-beat, class evolution) is the game's identity.

**Working launch definition (ASSUMPTION — user to confirm):** a public, free itch.io **web
demo** (the wasm export pipeline already works and is QA'd every milestone), roughly 45–90
minutes of play, spanning an intro arc in Liscor. Steam/paid comes after demo reception,
out of roadmap scope for now.

## Milestone ladder

| # | Theme | Status / confidence |
|---|---|---|
| M0–M3 | Agent-QA loop, tactical combat, story spine, combat depth | SHIPPED |
| **M4** | Playtest fixes + asset integration (tiles/sprites/paced combat) | **IN FLIGHT** (T1–T6 approved, T7 executing) |
| **M5** | Demo feel: audio, game shell (title/continue), UI theme+font, motion juice | Seeded (`2026-07-02-m5-demo-feel-seed.md`); 4 open user questions; HIGH confidence |
| **M6** | Action-driven classes (the identity system): counters, evolution, non-linear multiclass, consolidation | Vision captured (`2026-07-02-progression-vision-action-driven-classes.md`); needs interactive brainstorm; HIGH confidence it's M6 unless user pulls a slice into M5 |
| M7 | Liscor content arc I: 3–5 new maps (Guild interior, market street, inn upstairs), 2–3 quest chains with fight/talk/skill paths, 4–6 canon NPCs, exploration-skill breadth (generalize the prop-interaction pattern) | Direction, MEDIUM confidence |
| M8 | Combat variety: enemy roster expansion (REQUIRES sprite sourcing resolved), 1–2 new class kits, terrain/status depth, encounter-design data tooling, difficulty options | Direction, MEDIUM confidence |
| M9 | Inventory & economy (IF confirmed — see open questions): gear slots, coin, Krshia's shop, loot from encounters | Direction, LOW confidence — genre expectation vs scope risk, needs a real design discussion |
| M10 | Demo packaging & launch: onboarding/tutorialization, web-build performance + polish, save-version migration discipline, external playtest rounds, itch page + trailer GIFs | Direction, HIGH confidence it's needed whatever the middle looks like |

Post-launch direction (not planned): episodic arcs tracking TWI volumes, more classes,
Steam evaluation.

## Long-lead decisions that influence CURRENT work

1. **Art identity / sprite sourcing (blocks M8, degrades M5).** Goblins, Cave Spider, Relc,
   spell VFX have zero in-hand coverage (M4 spec §0 parked it). Every milestone shipped
   with chip-placeholders deepens the eventual swap. Decide by end of M5: buy/verify
   external packs vs commission vs stylized-placeholder-as-aesthetic. Registry design (T6)
   keeps the swap data-only, so the cost of waiting is feel, not rework.
2. **Classes-before-content.** M6 (action-driven classes) rewrites what leveling means, so
   M5 must NOT over-invest in leveling-adjacent UI/copy, and M7 quest rewards should be
   authored as accomplishments (they already are) rather than XP-like constructs. This
   ordering is why content expansion sits at M7, not M5/M6.
3. **Web export is a first-class launch target.** Keep the every-milestone web-QA parity
   convention (M3 T8) green forever; treat wasm perf regressions as release blockers from
   M5 on (audio + tiles are the first real wasm weight).
4. **Save discipline.** WISave is versioned; from the first external playtest (M10 at
   latest) saves must migrate, not reset. Until then, version bumps stay cheap — but every
   schema addition (sprites/tints in M4 are inert to saves; inventory in M9 is NOT) should
   ask "what does the migration look like."
5. **Scope guard.** Team of 1. Depth-in-Liscor beats map sprawl; the demo is one town done
   convincingly. Reject milestone scopes that add breadth without closing a feel or
   identity gap.

## User decisions (2026-07-02, M4 close) — all open questions RESOLVED

1. **Launch definition CONFIRMED** (free itch.io web demo, ~1hr intro arc).
2. **Inventory/gear: post-launch.** M9 drops from the pre-launch ladder — quality initial
   launch sooner, gear layered in after. M7 quest rewards stay accomplishment-shaped.
3. **Art strategy:** creative reuse of in-hand packs first (Pixel Crawler Orcs read fine
   as goblins — user call, overrides the earlier mislabel concern); swap the Cave Spider
   for a mob we have good assets for (nothing mechanically special about it); user added
   packs closing major gaps (4-directional goblin pack ×3 variants, Tiny Swords UI/effects,
   Minifantasy SFX + full soundtrack + dialogue-voice audio); for true bespoke needs
   (Drakes, Gnolls) explore **AI sprite generation**, not commissioning.
4. **M6 design decisions locked** (see progression vision doc): opaque-until-sleep
   visibility, consolidation offered-at-sleep, ~20–25% split friction, tight ~8–12 class
   tree. M6 may be specced and executed autonomously.
5. **HARD CONSTRAINT: Fable access ends in ~1 week (≈2026-07-09).** Opus continues after,
   following a Fable-authored long-term plan. Therefore front-load design-heavy work:
   M5 spec/plan + M6 spec/plan + the **Fable→Opus handover plan** (roadmap M7+ fleshed to
   execution-grade, conventions, risk register) are this week's deliverables alongside
   as much supervised execution as fits.

## Ladder restructure (2026-07-03, user decision): equipment pulled forward

Inventory/items/equipment/economy — deferred to post-launch at M4 close — is
pulled forward. Rationale (user): (1) weapon-driven evolution is core to class
identity ([Warrior] -> [Blademaster] vs [Spearmaster] follows the wielded
weapon; M6's skill weapon-tags are the seam this plugs into); (2) it is a
complex base component best built while Fable leads.

Decisions: **weapons + slots first** (weapon/armor items, equip slots, weapon
gates usable skills -> tag accrual -> evolution eligibility, loot drops) as its
own milestone — economy (coins/shops at the Liscor market row) follows as a
separate milestone; **M6 finishes as designed** (equipment milestone then
rewires tag accrual to the wielded weapon as a planned amendment); nothing
pre-slipped to Opus — user directs pace and will call the handoff point.

New ladder: M6 classes -> **M7 weapons+equipment** -> M8 economy + content
integration (Floodplains/Liscor maps, Relc intro, tutorial) -> M9+ content
arcs. Presentation-layer decomposition stays queued post-M6, priority below
equipment.

## Strategic direction (2026-07-03, M7 spec approved + user thoughts)

M7 weapons+equipment spec **APPROVED** by user. Four standing directives landed alongside:

1. **Mage acquisition → Pisces quest, not the dusty scroll.** More canon-natural (Pisces
   Jealnv, Human [Necromancer] of the Horns, teaches magic). Replace the
   `mage.gained_by: used_magic ≥ 1` prop-scroll trigger with a quest completion gate (bank a
   `learned_magic_from_pisces`-style accomplishment; keep `gained_by` keyed to it so the M6
   evolution machinery is untouched). **Synergy:** Pisces slots into the Adventurer's Guild
   (Zone E of the just-designed Liscor gate district). CONTENT lane — lands with Liscor/quest
   integration, not M6. The scroll prop can retire or become flavor.

2. **Open-source the repo (gradual).** Direction, not an immediate task. **Critical-path gate =
   asset-license redistribution:** every asset shipped in `assets/` must carry a license that
   permits redistribution in a public repo (`potential_assets/` NEVER ships; it stays
   gitignored). An asset-license audit is the first open-source blocker — do it before any
   public push. Follow-ons: `CONTRIBUTING.md`, `LICENSE` (code), README with build/run/QA
   docs, code-of-conduct, clean-history check. Drive incrementally: keep CLAUDE.md/HANDOFF
   contributor-legible, keep the QA loop the front-door for contributors.

3. **God-file / presentation decomposition — CONFIRMED still scheduled.** It is **M6.5**, the
   standalone block immediately after M6 ships and before M7 lands more code in those files
   (see the mid-M5 amendment below). Covers `combat_screen.gd` (~1.6k) + field/arena builder
   duplication + snapshot/command surfaces; **`wi_game.gd` (sim god-file) is now also large
   and should be assessed in the same block.** Unchanged priority: it gates M7 content.

4. **Three-pillar balance — non-combat skills/classes are first-class (was cut from M7).** The
   game must hit **Social · Combat · Puzzles/Exploration** without overweighting combat.
   [Skills] must matter outside combat; non-combat **classes** ([Innkeeper], [Barmaid],
   [Cleaner], [Tactician] — canon) must level and grant out-of-combat skills. This dropped off
   when M7 was rescoped to weapons+equipment — it is NOT abandoned, it becomes its **own
   milestone** (working name **"Three Pillars / world-skills"**). **Foundation already exists
   and is deliberately reusable:** M6's counter-driven leveling is content-agnostic (accomplishment
   counters like `cleaned_the_inn`/`browsed_market`/`heard_the_sewers` already bank);
   [Light] already fires out-of-combat via the `use_skill` known-skills gate; the
   prop-interaction pattern (dirty_table→`cleaned_the_inn`) is the seam to generalize. So this
   milestone is mostly design + content + a generalized interaction/skill-check surface, not
   new leveling engine. Needs a brainstorm → spec. HIGH strategic priority; schedule around the
   content lane (candidate: pairs with or precedes the Liscor content arc so the town has
   social/exploration depth, not just fights).

**Ladder now:** M6 classes → **M6.5 decomposition** → **M7 weapons+equipment (approved)** →
{Three Pillars/world-skills, Liscor+Floodplains content arc, economy} sequenced by user →
packaging/launch. Open-source track runs in parallel (license audit first).

> NOTE: the milestone TABLE above is stale (predates the 2026-07-03 restructure — M4/M5 are
> shipped, M7 is weapons+equipment). The dated amendment sections are authoritative until a
> table refresh.

## AMENDMENT (2026-07-05 night): Onboarding + Three Pillars BOTH CLOSED SHIP; M-RELEASE build-out complete

One session: Onboarding rev closed (opus 0C/0I/3M; 31-script suite,
tutorial_flow canonical), Three Pillars closed (opus 0C/0I/1M;
32-script suite, field skills/hotbar/[Tactician]/[Observe]), M-RELEASE
R1-R5 all built (CI, fallback-art contract, release pipeline, community
docs, triage action). Ladder ahead: (1) user playtests (2 checklists in
HANDOFF) → fix waves; (2) M-RELEASE R6 public push once the user clears
its gates (re-attestations, pirateaba policy, repo/itch/secrets) + RF
review; (3) NEXT SPEC CANDIDATE: **Social pillar depth** (P5's audit
flag: dialogue banks are one-shot — social is now the thinnest
repeatable pillar); (4) next art pass: PixelLab Antinium/Drake walks
(key live), Pisces real sprite (Ninja Adventure CC0 sorcerers or
Elthen), prop picks from the owned PC themed packs.

## AMENDMENT (2026-07-05 later, user): M-RELEASE pulled CONCURRENT — build-out 4/7 shipped

User pulled spec/plan/implementation concurrent with the Onboarding rev
(docs-and-new-files-only lanes; zero collision by design). Same session:
all 8 ⚑ calls ratified (spec `2026-07-05-release-community-design.md`),
plan authored (`plans/2026-07-05-release-community.md`), asset audit DONE
(`.superpowers/sdd/fp-handoff/release-asset-audit.md` — registry has NO
art fallback, R2 rescoped to BUILD it; PC backbone/xDeviruchi/Minifantasy
FORBIDDEN at public bar; 7 packs need user re-attestation), and R1 (CI
gate) + R3 (tag release pipeline) + R4 (community docs) + R5 (forms +
Opus triage) SHIPPED. Remaining: R2 (post-O5), R6 public push (audit +
pirateaba-policy + USER gated), RF. User punch list: HANDOFF + R3 report.

## Ladder decision (2026-07-05, user): M-RELEASE queued after Three Pillars

Packaging/deployment/open-source/community becomes the post-Three-Pillars
milestone. Seed spec (user input + recommendations + the ⚑ open calls):
`docs/superpowers/specs/2026-07-05-release-community-seed.md`. Pillars:
CI on the existing QA gate (PR -> full sweep -> user approval -> wasm
deploy), browser-local saves recommended for the demo, the
non-redistributable-asset mechanism + HISTORY SCRUB question (the
standing audit gate, now urgent — extracts are committed), three
contribution lanes (technical PRs / form->Opus quest pipeline /
art+music with real pipeline specs). Brainstorm needs the user; the
asset audit can start earlier as a background task.

## Ladder decisions (2026-07-04 evening, second user session — content + fidelity directives)

- **Content now gates playtests (user):** one quest with one solution path
  cannot exercise the leveling framework. Fix approved: a **playtest-content
  slice** ships immediately after M-FP F (inn work-loop + Relc spar leg +
  ONE gate-district quest with 3 solution paths + [Helper] class data).
- **Three Pillars brainstormed + spec APPROVED:**
  `docs/superpowers/specs/2026-07-04-three-pillars-world-skills-design.md`
  (Helper line + Tactician; overworld hotbar, facing-cell + ambient;
  component reuse mandatory). Execution sequenced AFTER M7 weapons.
- **Runway (supersedes the morning lock):** M-FP → **slice** → M6.5
  decomposition → M7 weapons plan+execute → Three Pillars execution.
  Still fully autonomous.
- **M-BEAUTY added (user, 2026-07-04 night):** atmosphere systems +
  per-map art direction to the HLD/Stardew reference bar — spec
  `2026-07-04-beauty-atmosphere-design.md` (approved). Slots AFTER M7;
  floodplains-dusk pilot runs as live Fable+MCP look-dev with the user
  judging; Onboarding rev + Three Pillars re-sequence after the pilot
  verdict. Ladder: M7 → M-BEAUTY → Onboarding rev → Three Pillars.
- **Standing fidelity directives (user):** `docs/VISUAL-LOG.md` created —
  every milestone F drains it; text-wrap/readability/font/coordinate-tweaks
  are solved problem classes; common-sense checks (animation matches action
  — the spell-cast-swings-sword defect is logged); incremental work ships
  max-fidelity (best-candidate sprites, never rectangles). Folded into
  wi-art-and-sprites / wi-verifying-changes / wi-running-the-machine.

## Ladder decisions (2026-07-04, user session — autonomous-runway lock)

- **Runway while user is out:** finish M-FP (Floodplains integration Q1/Q2/F)
  → **M6.5 decomposition** → **M7 weapons+equipment: write the plan from the
  approved spec and EXECUTE it**, all autonomous. Three Pillars brainstorm and
  the {Three Pillars, content arc, economy} sequencing decision explicitly
  wait for a user session.
- **Journal "Path" (retrospective class history): DROPPED** — was an M6-close
  candidate; user cut it permanently. Journal stays quest-only.
- **Opaque-until-sleep hint tuning: parked** — M6 playtest never reached
  leveling; re-collect reactions next playtest before any hint pass.
- **M4.1 dialogue-gate policy audit** (in-conversation-action gating rule):
  scheduled into the M-FP Q1/Q2 window, not a content-arc rider.

## Ladder amendments (2026-07-03, mid-M5)

- **M6.5 (new, small): presentation-layer decomposition.** Consultant architecture
  review (2026-07-03, committed in repo docs via progress ledger reference) found the
  core sim architecture strong but the presentation layer accumulating god-object debt:
  `combat_screen.gd` ~1.6k lines owning board rendering + playback + targeting + HUD;
  field/arena builder duplication; UI reading sim internals instead of snapshot/command
  surfaces. Cheap wins (class_name/injection, WIDataRegistry, WIEvents consts) landed in
  M5; the real decomposition (BoardRenderer / PlaybackQueue / TargetingController /
  CombatHud split, shared TileBoardBuilder, snapshot+command surfaces) is DELIBERATELY
  deferred past M6 because M6's locked plan targets the current file layout. Schedule as
  a standalone task block immediately after M6 ships, before M7 content lands more code
  in those files.
- **E3 outcome:** environment quality bar (user showcase scenes) now has a repeatable
  machine: asset-catalog -> asset-index -> scene-assembly-guide ladder + walls-v2
  segments + scatter/shadows/facing engine support. M7 map production should budget
  L0-L3 rungs per new map (about half a day each with screenshot iteration).
- **Music:** loopable-edit rule discovered (loop_offset must be 0 for xDeviruchi
  Loopable variants). Unmined queued picks for M7+: Silent Forest (road maps), Shop
  (market), Decisive Battle 1 (Skinner/boss), Peaceful Night (sleep jingle stinger),
  Never Give Up (defeat stinger), Minifantasy goblin den/dance (goblin camp).

## Ladder amendments (post-M4-playtest)

- **M5 scope firmed** (playtest-driven): render rework is now the spine — 16px-native
  aesthetic, low-res viewport + integer window scaling (game FILLS the window; UI overlays
  instead of side-parking), smooth tweened movement; game shell incl. **main menu with
  quit-to-menu** (save/load testability); combat **hotbar** (icon-based skill selector,
  bottom of screen); audio (in-hand packs); enemy sprites (goblin pack + orc-as-goblin +
  spider replacement); theme/font. Feel priorities are holistic per user — no internal
  ranking, all lanes ship.
- M9 (inventory) → post-launch backlog. Ladder: M5 feel/presentation → M6 classes →
  M7 content arc → M8 combat variety → M10 packaging/launch.
