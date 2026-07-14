# Content Wave v1 Implementation Plan (night Track C)

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Project skills READ-ONLY for subagents. Controller commits per green task. FOREGROUND-ONLY verification in every brief.

**Goal:** The pinned Content Wave spec (`docs/superpowers/specs/2026-07-05-content-wave-design.md` §1-§5): the Liscor Sewers map, Olesm/Lyonette/Zevara, two three-path quests.

**Architecture:** Content = data throughout. ONE traced sim-adjacent risk: the grate-as-gated-transition (spec §4) — trace door machinery first; smallest seam if genuinely missing. Sprites: PixelLab per B1/B3 recipes (Olesm = Drake base recolor prompt; Lyonette/Zevara humanoid) or documented stand-ins.

## Global Constraints

- Canon (wiki.wanderinginn.com) for every name/voice; misses escalate flagged.
- Stats hidden / opaque-until-sleep; explaining beats (§9 discipline); three-pillar path parity per quest.
- Suite 33 → 36-37 by CF; disclosure discipline for any street/gate-touching edit (gate_district_walkthrough is sensitive).
- NO COMMIT by implementers; windowed reads controller-read; shots outside qa_output.

---

### Task C1: the Liscor Sewers map + atmosphere + encounters

**Files:** data/skeleton_scene.json (new `sewers` map ~20×14, cave biome; entry via street `sewer_grate` — TRACE the door mechanism: if door entities are the only transition, the grate needs a door-shaped record gated on the quest accomplishment via the established `hide_when`/gating idiom — spec §4's one sanctioned seam if data can't express it; exit back to street); data/combatants.json + data/arenas.json (shield_spider pair + a sewers arena w/ walls; vermin trash pack; balance harness cells MEASURED); data/moods.json (sewers dark pin per cave_mouth precedent + 1-2 light anchors + water-channel ambience rects); sprites (shield spider: PixelLab per B recipes or cave-bat/spider stand-in flagged).
**QA:** new canonical `sewers_walkthrough` (teleport-assisted peek NOT canonical — walk the real grate entry once the gate opens; may need C3's quest banked via fixture — coordinate: the fixture can pre-bank the quest-open accomplishment, DOCUMENT).
**Gate:** 33 existing green (street edits disclosed!), +sewers_walkthrough, harness cells, windowed mood/encounter shots.

### Task C2: three characters

**Files:** data/skeleton_scene.json (Olesm at the Guild frontage; Lyonette inn/street per wiki-timeline check [spec's flag: if her inn era postdates our slice, street presence]; Zevara at the gate); data/dialogue/{olesm_intro,lyonette_intro,zevara_intro}.json (canon-voiced graphs; Olesm's tactician-recognition variant gated on classes.tactician; Zevara persuade option banks persuaded_someone); talk_pool lines ×3 (S1 seam — DISCLOSURE: new pooled NPCs on street/gate CAN shift gate_district_walkthrough etc. — enumerate + close in-task or defer to C4's window with the list); observe/friendly_line strings; sprites (PixelLab: Olesm smaller blue-scaled Drake w/ ledger; Lyonette blonde young woman, worn fine clothes; Zevara blue-scaled Drake in Watch armor w/ officer bearing — or flagged stand-ins).
**Gate:** sweep w/ disclosures closed or listed; windowed portraits read.

### Task C3: Quest 1 "Something in the Cisterns" (Olesm → sewers)

**Files:** dialogue additions (Olesm gives; Zevara witness beat); quest data (counter-derived beats per WIQuests); the three paths: FIGHT (clear the nest encounter), TALK (Zevara persuade chain), SKILL ([Observe] the nest ledge — gates gracefully when observe unknown); rewards incl. gold IF Track D landed (else accomplishment+item, note).
**QA:** canonical `cisterns_fight` + `cisterns_talk` (+ observe path folded into one of them or third script — judgment per crate precedent, document); CLAUDE.md + ci_sweep rows.

### Task C4: Quest 2 "The Wrong Order" (Lyonette, social) + window close

**Files:** dialogue (Lyonette gives; Krshia smooth-over path); paths: intimidate (street encounter reuse), TALK (Krshia persuade), SKILL (basic_cooking/cleaning field-skill save via use_skill_field on a prop); post-quest Lyonette pool-line unlock (the first pool-growth: a talk_pool line gated... trace whether pools support gating; if not, swap the whole pool via a second entity record trick or DEFER the growth beat, document).
**QA:** canonical `wrong_order_loop` (best-path coverage + negatives); CLOSE any disclosure window left from C1-C3; CLAUDE.md/ci_sweep counts final (36-37).

### Task CF: gate + opus whole-branch review

- Full sweep + units + harness + web parity; windowed set read; HANDOFF playtest checklist (sewers atmosphere, three voices, quest path parity, grate-gate feel); opus hints: grate-gate × save-compat (old saves at street with the quest un-banked), quest-counter composition with existing quests journal, pool disclosure honesty, canon voice spot-check vs wiki, harness cells sanity.

## Self-review notes
- Spec §1→C1, §2→C2, §3→C3/C4, §4 QA split per task, §5 non-goals respected.
- Riskiest: C1's grate-gate seam + C2's pooled-NPC disclosure on the gate map. Both carry explicit trace-first instructions.
- Antinium candidates (B1 park) NOT consumed — no Antinium character in this wave (Klbkch would be the natural cut; spec chose Olesm/Lyonette/Zevara; keep).
