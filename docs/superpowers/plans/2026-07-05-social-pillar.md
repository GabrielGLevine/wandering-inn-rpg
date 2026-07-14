# Social Pillar v1 Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Project skills READ-ONLY for subagents. Controller commits per green task. Implementer briefs carry the FOREGROUND-ONLY verification mandate verbatim.

**Goal:** The ratified Social Pillar v1 (spec `docs/superpowers/specs/2026-07-05-social-pillar-design.md`): rotating talk pools re-armed by sleep, the shared per-waking first-use dedup seam (resolves TP review M1 for [Observe] too), and [Diplomat] with a 2-skill kit.

**Architecture:** One sim seam (talk-pool rotation + per-waking dicts + sleep reset) in `wi_game.gd`; everything else data. Save fields additive/tolerant-default (no version bump). 33rd canonical script.

## Global Constraints

- Stats hidden; opaque-until-sleep (pool lines/kit copy: results only, no counts).
- Canon from wiki.wanderinginn.com (NOT fandom); misses escalate with flagged fallback.
- Rotation is `counter % pool_size` — zero rng (no canonical seed risk from rotation itself).
- NPCs without `talk_pool` byte-untouched; S2 discloses the expected-red set for NPCs that gain one; S4 closes it (O5 discipline).
- Suite = `qa/ci_sweep.sh` (32 → 33); zero-warning grep; alarm-wrap; NO COMMIT by implementers.

---

### Task S1: sim seam — talk pools, per-waking dedup, sleep re-arm

**Files:** Modify `src/core/wi_game.gd` (interact path: an npc entity with `talk_pool` and `social_talked[id]` unset → play pool line at index `chatted_with_<id> % len`, bank `chatted_with_<id>` + `heard_gossip`, set flag, emit via the existing dialogue_line/toast idiom [trace which surface `gate_guard`'s plain `dialogue_line` uses — that's the shipped no-graph precedent]; flag set → fall through to today's conversation behavior EXACTLY; `sleep()`: clear `social_talked` + `entity_first_use` [the shared dedup dict — also consulted by the P3 observe bank and S3's friendly bank]); Modify `src/core/save.gd` (two additive tolerant-default fields, used_skills precedent — NO version bump; migration untouched); Modify observe's bank site (first-use-per-entity-per-waking via the shared dict — resolves TP M1); Test: `tests/test_sim_core.gd` cases (pool rotation determinism incl. wraparound; same-waking fallthrough; sleep re-arm; observe dedup now banks once per entity per waking; save round-trip of both dicts).
- **Interfaces produced:** `talk_pool: ["line", ...]` entity field (strings, canon-voiced, data); `social_talked`/`entity_first_use` sim dicts; sleep clears both.

### Task S2: content — pools + persuade counter unification

**Files:** Modify `data/skeleton_scene.json` (or the dialogue files if S1 landed the pool there — read S1's report): `talk_pool` (2–4 lines each, canon-voiced) on Erin, Relc, Krshia, Selys, Pisces, gate_guard; Modify `data/dialogue/goblin_parley*.json` + the watch_sergeant persuade + any other persuade-class option: ADD `persuaded_someone` accomplishment effect (keep existing effects — additive).
- **DISCLOSURE REQUIRED:** enumerate every canonical script that interacts with a pool-gaining NPC as its FIRST action of a waking (their event stream gains a pool line + banks before the conversation graph) — list expected-reds explicitly; run the untouched remainder green. The pool-on-first-talk changes `dialogue_started` timing for scripts that talk to Erin/Relc/Krshia/Selys/Pisces/gate_guard — this is the plan's biggest risk; S2 may choose to ship pools on a SUBSET (e.g. Erin + Krshia + gate_guard only) if the red set is unacceptably wide, documenting the deferral.

### Task S3: [Diplomat] + kit

**Files:** Modify `data/classes.json` (diplomat: gained_by persuaded_someone [+ heard_gossip if multi-key traces as supported — document]; levels 2–6 on chatted/gossip/befriended thresholds); `data/skills.json` ([Friendly Face]: field-tagged, faced-NPC `friendly_line` mechanism [S1's observe-precedent seam — needs the small dispatch addition in wi_game.gd mirroring P3's observe field read, banking `befriended_moments` through the shared dedup dict]; [Calming Words]: combat, existing slowed-class status re-flavored — data only); `data/skeleton_scene.json` (`friendly_line` strings on the pool NPCs); icons via the PF sync_assets glyph pattern; tests (gained_by; friendly bank dedup; content validation).
- CANON-CHECK [Diplomat] + both skill names (wiki); escalate misses.
- Harness: diplomat cell measured-only IF the AI can field [Calming Words]; melee-profile AI likely never casts it — document like piercing_strikes, cell optional.

### Task S4: QA — social_loop canonical + window close

**Files:** New `qa/scripts/social_loop.json` (spec §5's route; fixture allowed); re-path/re-pin S2's disclosed reds; `wandering_inn_game_v4/CLAUDE.md` (+row, count 33, S1 seam architecture note) + `qa/ci_sweep.sh` (+social_loop, count comment).
- Exit: full 33-script sweep green, zero grep hits.

### Task SF: gate + docs + opus whole-branch review

- Full gate; HANDOFF playtest checklist (does day-2 social play EXIST now? do pool lines feel alive or canned? does [Diplomat] arrival read earned?); ledger; opus review method hints: pool×dialogue_started composition on every canonical script, sleep()'s three clears (phase + social_talked + entity_first_use) ordering vs autosave, save round-trip of new dicts through defeat-reload, S2 red-set honesty, observe-dedup regression (level_up via observe farming must be DEAD).

## Self-review notes
- Spec §2→S1/S2, §3→S3, §4→S1 (shared dict), §5→S4, §6 respected.
- Biggest risk = S2's expected-red set (pool-on-first-talk shifts streams); subset-shipping is the pressure valve, disclosed not silent.
- [Friendly Face] needs a small wi_game dispatch addition (observe-precedent) — S3 owns it, S1's report must document the observe seam's exact shape for S3 to mirror.
