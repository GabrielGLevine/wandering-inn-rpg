# CHOICE LOG (controller judgment calls — user defers by standing directive 2026-07-18)

Newest first. Each entry: the call, the alternatives, why. Choices that
change shipped behavior also live in their PR bodies; this is the
cross-release index of them.

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
