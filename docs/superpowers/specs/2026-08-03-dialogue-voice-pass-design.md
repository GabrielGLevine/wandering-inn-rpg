# Dialogue Voice Pass — de-AI the corpus

**Date:** 2026-08-03
**Status:** Approved (design conversation 2026-08-03; full-pass depth, register-only dullness, bible→fan-out→adversarial execution)
**Scope:** all 71 files in `wandering_inn_game/data/dialogue/` — 1,482 text fields, ~126K chars

## Goal

An external critique (2026-08-03) found the dialogue corpus reads ~100% model-written, with 11 ranked tells. This pass rewrites the prose so a trained reader no longer flags it, without changing what any conversation *does*.

## Non-goals

- No new nodes, quests, options, or gating. Node count per file is frozen.
- No mechanical/QA changes. Prose is uncoupled from QA (verified: no script asserts on dialogue strings).
- No canon changes — names, facts, spoiler cutoff (Book 17 bar / Vol 7 advertised) all hold. [Door of Portals] stays "Magical Door".

## Preservation contract (hard gate, scripted)

After rewrite, byte-identical per file:

- node keys, `start`, graph shape
- `requires` blocks and **`text_variants` array order** (last-match-wins is load-bearing; see `_comment` in `zevara_intro.json`)
- option targets, `effects`, `conditions`, `speaker`
- `_comment` fields (authoring rationale, not prose)

Only `text`-carrying string values change. A structural-diff script (strip prose fields → deep-compare) enforces this in W3; any mismatch fails the file.

**Fact preservation:** every proper noun, number, item, direction, and quest-critical instruction in the old text survives findable in the new text of the *same node* (rewording numbers to words allowed; dropping them is not). Each W2 agent extracts a fact checklist before rewriting and self-verifies after; W3 script cross-checks proper nouns + digits and logs deviations for W4 judgment.

## Register tiers

Dullness lives in **how**, never in **what** (approved: register only, never info). Tier assignment is provisional here; the W1 voice bible is authoritative.

| Tier | Voice | Provisional files |
|---|---|---|
| T0 preserve | Already reads human — light touch only, tells still stripped | rags_*, goblin_parley, ksmvr_*, drayman_dispute, recruit_pell |
| T1 rural/illiterate | Dropped agreement, repeats, avg sentence <9 words, no subordinate clauses, no semicolons | riverfarm_villager, riverfarm_hunter, riverfarm_headman, riverfarm_thicket_patch, peddler_stall |
| T2 trade/working | Shop jargon, interruptions, impatience, concrete nouns | relc_*, renn_hammer, pallass_forge_smith, pallass_*_clerk, pallass_den_keeper, pallass_lift_attendant, pallass_market_local, watch_crate, riverfarm_tallyman, vess_counter, octavia, selys_*, krshia_*, dresk_recruit |
| T3 educated/formal | The only tier where complex syntax survives | pisces_*, hedault_enchanting, olesm_*, zevara_*, ceria_*, yvlon_intro, grimalkin_*, pallass_grimalkin, invrisil_* (incl. wilovan pair — hat-man register per canon), riverfarm_witch, erin_errand (Erin = T3 vocabulary, T2 rhythm), lyonette_tip, patron_serving, room_ledger, door_mounting, dummies_note |
| T4 non-human/construct | Rule-bound, literal, never witty | klbkch_inn, xif, market_watchgolems, forge_calibration_golem, forge_temper_golem |

Combat/exploration bark files (crab_nest, corusdeer_range, razorbeak_nest, kingslayer_den, gallery_vermin_nest, boulevard_duel_ring) are narrator-voiced: each MUST land in a different W2 agent's batch so the five-file template breaks by construction.

## Ban list (budgets, enforced by W3 detector + W4 judgment)

| # | Tell | Rule |
|---|---|---|
| 1 | Antithesis "X, not Y" | ≤1 per NPC lifetime; corpus budget ≤30 (from 62 strict / 185 loose) |
| 2 | Button/epigram closer | Never on hub, shop, bark, or repeat nodes. ≤1 per conversation graph, at its emotional peak |
| 3 | Sentiment-then-deflect | ≤2 corpus-wide, each a different shape (from 13) |
| 4 | CAPS emphasis | 0 (from 48 nodes) |
| 5 | Mid-line ellipsis | 0 (from 48 nodes); leading-ellipsis stage beats also 0 |
| 6 | "the whole of / the entire" closer | 0 (from 12+) |
| 7 | Prose triads | Triads live in quest structure, never in the sentence; labelled "three things" speeches rewritten |
| 8 | Character names the theme | 0 — the reframe is the player's to make (e.g. forge_smith "Nobody was wrong. That was the whole problem." dies) |
| 9 | Recursive-bureaucracy gag | 1 instance survives (3 today) |
| 10 | "Apparent object isn't the real one" reveal | ≤2 of 4 quests keep it; other two get different shapes |
| 11 | Combat-bark template (sensory + dry understatement) | 5 different shapes |

**Replacement mandate:** a deleted button is never mere truncation. It is replaced by a concrete physical detail, an action beat, or a plainly unfinished fact. The bible includes worked before/after pairs per tier. This is the pass's biggest quality risk: stripped-but-flat is *worse to play* than AI-flagged-but-snappy.

## Execution

| Wave | Who | Work |
|---|---|---|
| W1 | **Fable** (1 agent) | `docs/dialogue-voice-bible.md`: global bans operationalized, tier definitions with worked samples, final tier/cluster assignments, and 71 constraint cards (BANNED / FORCED / CANON-VOICE / one worked sample each) |
| W2 | **Opus** fan-out | One agent per speaker-cluster (~30). Agent sees ONLY its own files + its cards + the bible — never sibling files, blocking house-style convergence. Same-speaker files share an agent (voice coherence is wanted there); same-tier different-speaker files never share one. Each agent: extract fact checklist → rewrite → self-verify facts + bans. |
| W3 | script | Structural diff (must be 100% clean) + tell-detector regexes (tells 1, 4, 5, 6) + proper-noun/digit fact cross-check. Hard gate. |
| W4 | **Opus** fan-out, fresh context | Per-file adversarial detector: re-runs the original 11-tell critique cold, never sees rewrite rationale. Verdict PASS / FAIL with quoted lines. Budget tells (2, 3, 9, 10, 11) checked corpus-wide by one aggregator agent. |
| W5 | Opus | Failures loop to a fresh W2-style agent with the W4 verdict appended to the card. Max 2 loops per file, then escalate to Fable. |
| W6 | **Fable** (1 agent) + QA | Fable spot-adjudicates ~10 files against the original critique. Then full QA sweep + machine playtest per `wi-verifying-changes` / `wi-machine-playtest` (dialogue = player-facing surface). |

Models: Fable = bible + final adjudication (architecture/adjudication slot). Opus = volume rewrite + detection. No Codex in this pass (prose, not code).

Wave discipline: `wi-usage-guard` before each dispatch; judgment calls logged to CHOICE-LOG per wave-autonomy doctrine, never blocked on user-gates. Lanes own whole files; no two agents touch one file in a wave.

## Verification

1. W3 script gates: structural diff, detector regexes, fact cross-check — all 71 files.
2. W4 cold-reader verdicts: PASS required on all files; budget-tell aggregate within limits.
3. Existing QA suite green (`run_qa.sh` sweep) — proves no structural regression reached runtime.
4. Machine playtest at close — dialogue renders, variants fire, nothing reads broken in play.
5. Fable close adjudication on sample — the "would a trained reader flag it" bar.

## Risks

- **Flatness** (top risk): mitigated by replacement mandate + worked samples + Fable adjudication, not by hope.
- **Re-uniforming:** blocked structurally — blind sibling isolation in W2; W4 aggregator watches cross-file repeats.
- **Fact loss:** triple net (agent checklist, W3 script, W4 cold read).
- **Token weight:** full-milestone-scale job. Usage guard at each wave; W2 batches sized to pace.
- **T0 overcorrection:** cards for T0 files say "strip tells, change nothing else"; W4 checks drift against original text.

## Open items

- None blocking. Tier table above is provisional; Fable's W1 bible finalizes it (logged to CHOICE-LOG if it moves files between tiers).
