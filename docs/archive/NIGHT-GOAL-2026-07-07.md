# NIGHT-GOAL — autonomous run, night of 2026-07-07

**Charter for the overnight controller.** Read alongside `GOAL-CHAIN.md`
(the armed master ladder — this file is tonight's slice of it plus
night-specific policy). The machine, guardrails, and worktree/merge rules
in GOAL-CHAIN apply verbatim and are not restated. Position ledger:
`.superpowers/sdd/progress.md` (tail = exact position — trust it over
memory). Live state doc: `HANDOFF.md` (keep it updated as you go).

## Where the day ended (2026-07-07)
- Chain steps 1-4 CLOSED: M-ARC, cleanup, M-LEGIBILITY (opus READY TO
  SHIP), M-GEAR (opus READY TO SHIP). K1 + K2 landed (49 canonicals once
  K2 is committed — check the ledger tail + `git status` FIRST; if K2's
  lane work is still uncommitted in the tree, run its controller loop
  before anything else: report at
  `.superpowers/sdd/fp-handoff/task-k2-sneak-report.md`).
- **CLAUDE.md audit report** at
  `.superpowers/sdd/fp-handoff/claudemd-audit-report.md` (game +
  top-level) — corrections are night task 2. If the file doesn't exist,
  the audit lane died — re-dispatch read-only or leave queued.

## Tonight's ordered objectives — ARCHITECTURE-FIRST HYBRID
## (user-ratified 2026-07-07 after the consultant code review; supersedes
## the earlier chain-order list. Rationale: extraction/manifest/mirror
## surgery needs Fable-level capability; content waves are successor-safe.)

1. **Close the CLAUDE.md corrections + slimming lane** (in flight —
   consultant endorses: "execute aggressively; rules stay, narratives
   move"). Controller loop, three commits, reviewer pass per its brief.
2. **ARCH-1 — qa/manifest.json, one source of truth**: script → seed →
   fixture(→ optional timeout) manifest; `ci_sweep.sh` READS it (no more
   hardcoded CANON array); the CLAUDE.md compact seed table carries a
   generated-from-manifest marker + a unit/CI check that table and
   manifest agree (or the table is generated — implementer's call,
   disclose). Kills the two-sources drift class (three hand-synced count
   fixes today alone).
3. **ARCH-2 — mirror drift-bombs**: promote `_weapon_gated_kit` to ONE
   static pure function (wi_game + sim_combat_batch both call it — THE
   tuning authority must measure the shipped game by construction); same
   for the G4 accessory-sum mirror if it factors cleanly; `_bb_escape`'s
   three copies → one UIChrome home (keep the placeholder form; update
   the three call sites + their doc comments; combat_move_input's
   escaped pin must stay byte-identical).
4. **ARCH-3 — const key catalog (minimum viable)**: a shared
   const/StringName catalog for the hot combatant/entity dict keys
   (skills/stats/hp/max_hp/damage_mod/side/alive/...) adopted in
   src/core/** call sites; NO typed wrapper layer tonight (flagged as a
   successor-hostile bridge too far — catalog only, purity untouched).
5. **ARCH-4 — THE wi_game EXTRACTION** (the big one; budget the largest
   block): extract injected pure sub-sims per the existing
   WIProgression/WIQuests/WIDialogue pattern — WIEconomy (gold/shop/
   loot), WISocial (talk pools/social counters/befriend), and the
   field-skill dispatch (use_skill_field's seam family). HARD
   CONSTRAINTS: save serialize shape BYTE-UNCHANGED (extraction is
   internal — WISave round-trip proves it); event emission order
   preserved (canonical scripts are the tripwire); comment density
   trimmed to constraints-only IN THE MOVED CODE (history lives in
   git/reports — consultant finding); full gates + a MANDATORY opus
   whole-branch review before commit-close. If the extraction runs long,
   land it sub-sim by sub-sim (each independently green) — never a big
   bang.
6. **K4 — ghost-skill wiring** (post-extraction, wires into the new
   homes): heal/second_wind (incl. the same-side-guard ally-targeting
   fix), the 0-cost move_pool_bonus passives, icy_floor if it fits;
   un-suppress L1 lines + re-pins; harness re-run + expected seed
   re-derivations. Fable-appropriate by the consultant's own logic.
7. **GDI copy wave** (user-approved verbatim at
   docs/design/gdi-copy-staging.md) + the ratified vibration refusal
   line swap + pins. Small.
7b. **POLISH WAVE (machine-playtest bugs, user-relayed 2026-07-07 —
   cheap fixes, outsized first-impression payoff):** (1) boulder sprite
   region excludes Rocks.png's baked "PALETTE :" label (shift below
   ~y8; windowed re-verify sewers/training yard/deep tunnels); (2)
   message_layer TOAST panel gains the wrapped-line budget (the M-FP F
   class — it reached every panel EXCEPT toasts; 3-line toasts clip at
   the fold); (3) tutor panel same budget (Relc's "Earned, not given"
   clips); (4) dialogue pagination: break at sentence boundary where
   possible + a continuation cue. VISUAL-LOG has the full entries.
   Windowed-verify per wi-machine-playtest — now BINDING after every
   player-facing wave and at milestone closes (canonical protocol:
   wandering_inn_game/qa/MACHINE-PLAYTEST.md).
7c. **"NO KILLING GOBLINS" micro-wave (user directive 2026-07-07)**:
   the iconic sign out front + the narrative reconciliation — full seed
   with canon cites and staged, voice-linted copy at
   docs/superpowers/specs/2026-07-07-no-killing-goblins-seed.md.
   Parts 1+2 (sign prop by the floodplains inn door, interact/observe
   toasts with the canon-fixed wording, one Relc line + one Erin
   won_combat text_variant) = one small content task; SEQUENCE AFTER
   lane 7b releases data/sprites.json. All four copy lines ship with
   ⚑ open for the morning pass. Part 3 (goblins_spared counter, spare
   options, the Rags arc) is SEED-ONLY tonight — the counter may ride
   K4 if trivially additive; the arc goes to the step-8 expansion
   queue.
8. **SUCCESSOR BRIEFS (insurance, produced in idle gaps — NOT a
   substitute for doing the work)**: dispatch-ready briefs for K2b/K3/
   Social II/M-DEPTH at docs/superpowers/successor-briefs/ (COMMITTED — DONE, 5 briefs + INDEX; K3 brief binds the decided canon packet docs/design/k3-canon-verdicts.md), so
   WHEREVER tonight ends is a clean pickup point. A staging lane may
   write these in parallel; they must never displace an execution lane.
   Each rung below uses its brief as the dispatch brief (same document —
   that's the point).

## The chain resumes (user amendment 2026-07-07: attempt the ENTIRE
## charter — the architecture work reorders the night, it does not
## shrink it. These are full objectives, not a deferred afterthought.)

9. **K2b — hotbar loadout** (USER-RATIFIED model: slotted loadout,
   journal-assigned; unslotted = not fielded that fight; AUTO default =
   byte-parity with today; combat keeps Attack/Dash pinned at slots
   1/2): skills-wave plan Task K2b. Full task loop + review. Also owns
   the K2 fix wave's disclosed readout drop-row UX trade (3+ field
   skills silently drop the overflow row on screen) — this task
   restructures that surface.
10. **K3 — the new Skills** (user rulings bind, HANDOFF RESOLVED block):
   canon names wiki-verified (WebFetch; gear canon pass is the
   annotation exemplar); renames provisional frost_touch/kindle/sneak
   as pure data + pin updates; stealth's home is a **[Rogue]-line
   earned class** (wiki-verify the class name; guile/stealth counters;
   grant POST-onboarding per K2's onboarding-integrity constraint in
   the sneak skill's _comment); [Mage] [Invisibility] as a K3-OPTIONAL
   second stealth verb (queue if it needs new machinery); **[Observe]
   renames** to a canon-verified Skill-sounding name ([Owl's Vision] is
   the user's exemplar — verify attestation first); the
   Skill-names-never-action-verbs principle audits the whole kit
   (rename clear failures canon-cited, flag borderliners). Also owns
   the K2-flagged equip/unequip sneak-break gap adjudication.
11. **KF — Skills-wave close**: gate + docs + opus whole-branch review
   over K1+K2+K2b+K3+K4; fix wave; windowed set controller-read; a
   wi-machine-playtest rotation; HANDOFF playtest checklist; ledger;
   sync.
12. **Social Pillar II (chain step 6)** — USER-RATIFIED: execute with
   the STAGED copy as-is (docs/design/social-2-staging/ + the 10
   dialogue drafts); its 18 ⚑ taste flags stay OPEN for the morning
   pass. LINEAR stages per the ratified spec (no points system). Full
   task loop per its spec/plan; opus close.
13. **M-DEPTH (chain step 7)**: DP1 (Liscor interiors) the moment
   Social II closes; then DP2 → DP3 → DP4 → DP5 → DPF in order per
   docs/superpowers/plans/2026-07-06-m-depth.md. Per-milestone close
   discipline unchanged.
14. **GOAL-CHAIN step 8a staging** (Portals/Garden expansion prep) if
   M-DEPTH closes — and onward down GOAL-CHAIN; the ladder has no
   bottom tonight.
15. **NEVER IDLE** (unchanged): if lanes are blocked/reviewing —
   (a) successor briefs above; (b) expansion-cast canon pre-verification;
   (c) PixelLab cast generation (park-only); (d) VISUAL-LOG fix briefs;
   (e) small consultant Improvements as micro-tasks (get_parent chain
   caching in char_creation/title_screen; world_labels idle-skip).

## Night-specific policy
- **Deploy: AUTO-TAG APPROVED (user, 2026-07-07).** Iff every closed
  milestone's gate + opus verdict is clean AND public CI is green on
  the final sync: tag `v0.3.0` at the LAST clean milestone boundary
  (`git tag v0.3.0 && git push origin v0.3.0` in
  ~/wandering-inn-rpg-public per wi-shipping — HEAD-based sync FIRST).
  One tag maximum. Any doubt → don't tag, queue for morning.
- **User gates never block:** every taste/canon call gets the
  recommended option + a ⚑ HANDOFF entry, and the run continues. Check
  HANDOFF's "RESOLVED 2026-07-07" block before flagging duplicates; do
  not resolve taste flags yourself.
- **Model policy:** sonnet implementers/reviewers; opus for whole-branch
  reviews ONLY; fable = controller + staging writing. Final Fable day —
  bias toward SPEND (user directive), throttle only on visible waste.
- **Worktree lanes:** allowed for genuinely disjoint surfaces per the
  hardened rules in wi-running-the-machine (file-map intersection vs
  git status AND live-lane reports BEFORE any copy-merge; re-gate the
  MERGED tree — the K1/L2 clobber is the cautionary tale). In doubt →
  serialize.
- **Verification:** wi-verifying-changes verbatim. Failed asserts HANG
  (alarm-wrap). Zero-warning grep. Windowed shots controller-read.
  Counts: never trust a hardcoded number — count tests/test_*.gd and
  ci_sweep.sh's CANON.
- **Subagents:** FOREGROUND-ONLY verification verbatim in every brief;
  0-tool garbled misfire → re-dispatch once; "waiting" stall → jolt
  ("STOP WAITING — notifications CANNOT reach you"); NO-COMMIT
  implementers; controller stages EXPLICIT lane-reported paths; never
  `git add -A` while any lane is live.

## Stop conditions (clean boundary + `=== SESSION STOP ===` ledger entry)
**There are exactly TWO sanctioned stops: usage exhaustion and
suspected repo damage. "Objectives complete" is NOT a stop** — last
night's run stopped early with budget remaining (user complaint,
2026-07-07): tonight, finishing the numbered list means CONTINUE down
GOAL-CHAIN past objective 14 and the NEVER-IDLE ladder. If
you are considering stopping, first answer in the ledger: "what is the
next startable step or staging lane, and why can't I start it?" — if
the answer isn't 'usage' or 'damage', start it.
- Usage exhaustion → finish the in-flight controller loop if cheap,
  else park with the lane's report path in the ledger; update HANDOFF;
  write MORNING_SUMMARY.md.
- A red surviving two distinct fix attempts → park THAT ITEM (document
  in ledger + HANDOFF), move to the next independent objective — a
  parked red is never a session stop.
- Anything smelling like data loss / repo damage → STOP, document,
  never "fix" forward.

## Morning deliverables
- `MORNING_SUMMARY.md`: per-milestone verdicts + commits, the ⚑ queue
  consolidated (each flag with a one-line recommendation), playtest
  checklists, deploy state (tagged or queued), three most valuable next
  actions.
- HANDOFF + ledger current as of the final action, not summarized after.
