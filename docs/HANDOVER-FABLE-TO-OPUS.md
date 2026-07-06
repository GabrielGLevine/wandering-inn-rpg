# Fable → Opus Handover Plan

**Written 2026-07-02 by the Fable project lead; Fable access ends ~2026-07-09.** This is
the long-term operating plan the user asked Fable to set so Opus can continue as project
lead afterward. It complements — never replaces — the living docs: `HANDOFF.md` (session
state), `docs/ROADMAP.md` (milestone ladder + decisions), `.superpowers/sdd/progress.md`
(execution ledger), per-milestone specs/plans in `docs/superpowers/`.

## 1. Operating model (keep it exactly)

1. **Machine per milestone:** brainstorm (interactive when user available; delegated
   with [D]-flagged calls when not) → spec → **external-consultant adversarial review of
   controller-authored specs** (validated: it caught 5 real blockers in M5) → plan with
   parallelism-first LANES + per-task file-ownership lists → subagent-driven execution
   (Codex implementer lane: sandbox can't commit/open windows; HOME=/private/tmp prefix)
   → per-task reviewer with fix→re-review loops → **mandatory Opus whole-branch final
   review** → human playtest gate.
2. **Iron rules learned the hard way** (each cost a real incident): controller NEVER
   edits the worktree while a Codex job runs; verify staged diff content before claiming
   a fix landed; every sprite/tile region or scale pick gets a controller-read windowed
   screenshot; zsh doesn't word-split unquoted vars; QA drives dialogue by VISIBLE index;
   presentation pacing is always 0 under TestDriver/headless.
3. **Reviewers earn their cost.** Give them method hints ("pixel-crop the regions",
   "diff the actual commit", "measure font metrics") — the M4/M5 catches all came from
   reviewers who verified instead of read.
4. **The balance harness is the design authority for numbers.** Tune data, never sim.
5. **QA-first is the identity of this repo.** Every player-visible feature ships with a
   bus event + `ui_*_rendered` confirmation + script assertion. Humans gate FEEL only.
6. Keep `HANDOFF.md` live mid-session; ledger every task completion + lesson.
7. **The project skill library (`.claude/skills/wi-*`) is READ-ONLY for you** (user
   mandate 2026-07-04: only Fable edits it). Route work through it; when you find a
   gap or error, write a "SKILL PROPOSALS" note in HANDOFF.md with evidence — never
   edit the skills directly.

## 2. State at handover (updated 2026-07-04; HANDOFF.md + ledger are the live truth)

- M0–M5 ALL SHIPPED. M5 CLOSED 2026-07-03 (Opus final review zero Critical; ship fix
  `74791f4` bumped save VERSION→2 + title Continue feedback); windowed baselines
  recaptured 14/14; architecture cheap-wins (class_name/injection, WIDataRegistry,
  WIEvents) and F1 audit review-clean.
- M6 (action classes) FEATURE-COMPLETE + WHOLE-BRANCH REVIEW-CLEAN + POLISH-PASSED
  (2026-07-04 overnight, Opus autonomous run, range `b3572cc..0d5d24f` — see §8):
  T0–T9 + F1 all shipped; the whole-branch review's one Important finding
  (generalist grants never reached the combat kit) fixed + QA-proven `b8b4c75`.
  Player base class is now `warrior` (fighter deleted, saves remap, T9). Gate:
  19 QA scripts + 12 units + smoke zero-warn + balance harness in-bounds + web
  parity. PENDING: the human playtest (first blockers found+fixed `e65754c` —
  see §8 lesson 1) and two MORNING DECISIONS in HANDOFF (journal hints,
  chieftains_raid difficulty). Check the ledger before assuming this current.
- Parallel controller lane: Floodplains world-map integration (consultant design +
  Relc road-intro addendum received; L0 unreachable-integrated `da89286`; Liscor gate
  + Relc tutorial adjudicated, needs a writing-plans pass).
- Architecture DECOMPOSITION (M6.5 in ROADMAP) is deliberately queued AFTER M6 — do
  not restructure combat_screen/world before M6 ships.
- Wiki canon research: `docs/superpowers/spike/wiki-*.md` + the taxonomy doc. Canon
  source is the `wiki.wanderinginn.com` mirror (Fandom 402s bots).
- Asset workflow (BINDING, user-mandated 2026-07-03): `docs/asset-catalog.md` (choose)
  → `docs/asset-index.md` (paths/dims) → `docs/scene-assembly-guide.md` (assemble,
  L0–L4 ladder, 8 principles) — never load pack PNGs into context to browse. Licensing
  settled tree-wide; only Super Dialogue pack needs a credits line (Dillon Becker,
  CC BY). Goblin pack solves goblins. NEW 2026-07-03/04: **ADMURIN family** (Admurin's
  Freebies multi-pack, cataloged `0e54abd`) closes the skill-icon, pixel-font, and
  general-RPG-icon gaps + wolves/golem/caster/chests; license OK for game use but has
  a no-AI-training clause. **Relc/Relc1** (`potential_assets/Relc{,1}/`) are AI-gen
  Drake sprites (PixelLab mannequin template, 128px, 8 rotations, NO animations yet) —
  the M5 F2 Drake exploration landing; NOT in the catalog yet — catalog entry + user
  style verdict + anim generation are open work before use. Gnoll/Antinium remain the
  hard racial sprite gaps.
- Playtest checklist accumulating in HANDOFF.md "M5 late-session status" — fullscreen
  verdict, music seams (title_theme custom cut unresolved), hotbar/movement feel, UI
  chrome readability, environment feel vs the user's showcase bar.
- **Cheap delegate model (user-provided 2026-07-04):** `Qwen/Qwen3-Coder-30B-A3B-Instruct`
  via the SiliconFlow API; key at `docs/siliconflow_api_key.txt` (gitignored — never
  commit). Quality below Sonnet: suitable for mechanical, tightly-bounded tasks
  (renames, fixture generation, mechanical ports) with reviewer coverage; NOT for
  design, sim-core edits, or anything needing repo context judgment.
- **gdUnit4 evaluated 2026-07-04 — verdict: do not adopt now.** The "plain SceneTree
  scripts, no GUT/gdUnit" convention in v4 CLAUDE.md is deliberate and stands. The 12
  unit suites cost ~2s each (~24s serial), nearly all engine startup; gdUnit4 would
  collapse that to one process but costs porting all suites to GdUnitTestSuite, an
  addon inside load_gate's every-script scope, 4.7-compat verification, and process
  churn mid-M6. Unit tests are also the minor share of verification here — the QA
  playtest scripts (which gdUnit4 does not cover) are the primary tool. Free speedup
  if wanted: run the 12 suites as parallel shell jobs (~24s → ~3s wall). Revisit
  gdUnit4 at M10 when CI (GitHub Actions, XML reports) becomes real.

## 3. The ladder to launch (with what "done" means)

- **M5 demo feel** — done when a stranger can play title→errand→fights→save→continue
  with sound, hotbar, smooth 16px world. Human playtest gates it.
- **M6 action classes** — done when the harness proves the 20–25% split gate, evolution
  and consolidation work opaque-until-sleep, and the playtest says focus-vs-split feels
  fair. Spec is total; trust it.
- **M7 Liscor content arc I** — 3–5 maps, 2–3 quest chains with fight/talk/skill paths,
  4–6 canon NPCs (wiki-grounded; Erin's Skill list in the spike files is a content
  vein). Needs a real brainstorm with the user (content taste = user territory).
- **M8 combat variety** — enemy roster breadth on the M6 systems; encounter-design
  data tooling; difficulty options.
- **M10 packaging/launch** — onboarding, wasm perf, save-migration discipline, external
  playtest rounds, itch page. Launch = free itch web demo (~1hr intro arc), confirmed.
- Post-launch: gear/inventory (user decision), mouse support, more arcs.

## 4. Risk register (watch these)

1. **Render rework (M5 R-lane) is the highest-variance work in the pipeline.** The R1
   spike verdict (SubViewport input forwarding) determines difficulty. If R-lane slips,
   consultant's cut order stands: stretch items die first, shell lane survives at all
   costs (save/load testability has been the #1 recurring playtest complaint).
2. **Seed churn:** M6 changes combat data → every canonical QA seed may need
   re-derivation. Budget a seed-search task; the table lives in v4 CLAUDE.md.
3. **Opaque-until-sleep** is the one user-accepted design risk — collect playtest
   feedback verbatim; a hint-tuning pass is pre-approved as an M7 candidate.
4. **License gates:** goblin/Tiny Swords/audio packs each need recorded verdicts before
   shipping; unclear → ask the user, never assume.
5. **Context economy:** this repo's sessions run long. Use file handoffs (briefs,
   reports, review packages), background waits, and the asset index. Compaction is
   survivable BECAUSE the ledger + HANDOFF are disciplined — keep them so.

## 5. What the user cares about (observed, one week of dense collaboration)

- Canon fidelity is non-negotiable (wiki over invention; they caught orc-vs-goblin).
- They notice FEEL fast (jumpy motion, clunky Dash→Move) — playtest findings are
  directives, not suggestions; triage them into hotfix-vs-milestone immediately.
- They want a mutual roadmap, decisions surfaced as short option sets, and autonomy
  between decision points. Ask few, sharp questions; never re-ask settled ones.
- Raw stats stay hidden. HP/damage numbers are fine. This has been violated by accident
  before — check every new UI string.
- They will give you new asset packs and expect creative reuse before purchases.

## 6. First actions for the post-Fable session

1. Read `HANDOFF.md` → this file → `docs/ROADMAP.md` → the ledger tail.
2. Finish whatever M6 task is mid-flight (the ledger names it; T7–T9 + F1 + the Opus
   whole-branch final review were the remainder as of 2026-07-04), then the M6 human
   playtest gate. Budget the F1 seed re-derivation (risk register §4.2).
3. Then the Floodplains integration lane (plan needs writing) and the M7 content
   brainstorm — M7 needs the user in the room (content taste = user territory).
4. Keep the consultant convention for any spec you author — the user brokers it.

## 7. Deferred handover idea (user, 2026-07-02)

Before Fable's week ends, consider packaging the operating model as a **Claude skill**
(`.claude/skills/` in this repo) for Opus to inherit — the machine's process rules
(§1–§2 above) as an invocable skill rather than prose. Don't over-engineer early;
fold in the remaining week's learnings first. Target: last day of Fable access.

## 8. Learnings from the first Opus-as-coordinator run (2026-07-04 overnight, reviewed by Fable)

The autonomous night (T7→T9→F1→whole-branch review→polish capstone, 16 commits)
was a SUCCESS overall: machine discipline held (every task implement→green→
review→fix→commit), the ledger/HANDOFF stayed live through compactions, the
whole-branch review caught a real ship-blocking bug (generalist grants never
reached the combat kit), and a screenshot-read polish pass caught a real toast-
clipping bug QA couldn't see. Verdict: Opus can run the machine unattended.
The failures are the instructive part:

1. **The polish capstone verified what it was told to look FOR, and still missed
   what a stranger hits in 30 seconds.** The morning playtest was blocked by a
   ~9×11px door sprite (render_scale 0.25), an entity label floating a row above
   its sprite, and a SILENT empty-interact — while the capstone dutifully checked
   "map linkage" (data: door → valid cell ✓) and "icon sizes" (hotbar ✓). Root
   pattern: **QA asserts logical state, so pure-visibility/discoverability
   defects are structurally invisible to it** — and a checklist-driven agent
   pass inherits the same blindness unless it explicitly role-plays a first-time
   player. Fix shipped `e65754c`; standing rules going forward: (a) every
   interactable's sprite must read at glance-size (fills most of its cell or
   gets a marker); (b) every explicit player input produces visible feedback
   (INTERACT_NOTHING now toasts); (c) polish passes must include a COLD-EYES
   WALKABOUT — approach each interactable the wrong way on purpose, screenshot,
   and ask "would a stranger find this?"
   **Addendum (same morning): the first plausible presentation fix wasn't the
   root cause.** Fable's visibility fix (`e65754c`) helped but the door was
   still unusable — the actual root cause was Body_A/Citizen_F carrying 16px
   (exactly one cell) of transparent padding under the feet, drawing every
   character ONE CELL above its logical cell (`440a48a`, anchor 0.75). The
   user's second repro ("Nothing there" toast while facing it from every side)
   was the decisive evidence. Lessons: feedback affordances pay off immediately
   (the new toast is what localized the bug); and when a human contradicts a
   passing QA run twice, believe the human and go measure pixels.
2. **Mixed blocking semantics read as bugs.** Interactable furniture = blocking
   entities, but E3 decor is non-blocking presentation — a solid-looking center
   table you can walk through. Any decor that reads solid needs a blocked tile
   (done for inn (7,6)/(3,2); audit street/cave when touched next).
3. **Subagent reviews can MISFIRE (garbled boilerplate, 0 tool uses).** The T9
   review returned the skills-directory dump. Opus correctly detected it, did
   not trust it, and deferred that surface to the whole-branch review instead of
   re-dispatching blind. Rule: check a review result actually engaged (tool
   uses > 0, findings reference real files) before acting on it.
4. **The charter file pattern works.** NIGHT-GOAL.md (prime directive, iron
   rules, stop/queue gates, ordered sequence, morning-handoff contract) +
   ledger-tail-as-position + self-paced loop survived multiple compactions with
   zero drift. Reuse it for any future unattended run. The queue-for-morning
   discipline also held — taste/canon/balance calls landed in HANDOFF MORNING
   DECISIONS with recommendations instead of being guessed.
5. **Meta-review note (Fable): sed-based renames need a distinct-classes check.**
   T9's blanket fighter→warrior sed collided in tests that used both ids as
   DISTINCT classes and left one self-contradictory QA comment (caught in
   polish). For id renames: grep for files using BOTH ids first; those need
   hand-rework, not sed.

## 9. Learnings from the final Fable sprint (2026-07-05/06 — two milestone-dense days)

The densest stretch of the project: Onboarding, Three Pillars,
M-RELEASE build-out, Social Pillar, Content Wave, Economy v1, M-JUICE
core, and the M-ARC cold open all closed with clean opus verdicts; the
public repo + CI + itch deploy pipeline went live. What made it work,
for whoever coordinates next:

1. **The per-track rhythm is the unit of safety**: implement (Opus
   subagent, NO-COMMIT, foreground-only verification in the brief
   verbatim) → controller reads the windowed evidence WITH OWN EYES →
   commit → sync public → next task. Whole-track opus review before the
   track closes. Never two implementers on overlapping files; parallel
   lanes only with explicitly disjoint surfaces (and a transient-red
   re-run rule in both briefs).
2. **Expected-red windows scale**: S2 measured a 28-script red set,
   invoked the plan's subset valve, disclosed 10, and S4 closed them.
   The pattern (disclose → don't fix mid-window → a dedicated Q-task
   closes) has now worked at every size. The valve (ship a SUBSET of
   content to cap the window) is as important as the window itself.
3. **Design-time state corrections beat perfect specs**: every plan
   carries a "plan-time corrections" header; every brief carries
   "the plan text may be stale, these corrections override." Specs
   written days ago are ALWAYS somewhat wrong by execution time.
4. **User-taste gates are cheap to honor**: ship the mechanism, flag
   the copy/pick (veil evolution-form, opener lines, ding choice,
   Erin/Relc pools) — one-line revisable, never blocking, never silent.
5. **The user's directives compound**: max-fidelity, content-never-
   gates-playtests, diegetic-gold, nothing-cut-for-licensing (private
   bundle carries restricted assets; flag downgrades FIRST). Read the
   ROADMAP amendments + HANDOFF queue at session start; they are the
   real spec.
6. **Fable-tier judgment lived in**: plan authorship, canon adjudication
   (three wiki-miss substitutions shipped canon-true), review-verdict
   triage, and reading screenshots skeptically (the sweep-clobber,
   the glyph-artifact, the flat channels). Opus subagents executed
   everything else excellently — including catching MY brief errors
   (classless-hotbar assumption, Lyonette's hair). Trust the
   implementers' corrections; verify their claims.
7. **Infrastructure pays same-day**: the public repo's first CI run
   caught two real defects; the deploy rehearsal caught two script
   bugs; the first tag caught a dead host. Rehearse pipelines BEFORE
   they matter; every failure became a one-line fix + a skill entry.
8. **Skills are the durable memory**: wi-shipping now holds the deploy
   playbook; wi-art-and-sprites holds the PixelLab v1+v2 recipes;
   wi-running-the-machine holds the misfire + integration-rehearsal
   patterns. Post-Fable sessions: propose skill edits via HANDOFF,
   never edit directly (library governance stands).
