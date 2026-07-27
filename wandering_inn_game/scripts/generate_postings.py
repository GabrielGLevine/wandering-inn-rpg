#!/usr/bin/env python3
"""Issue #72 (tier 1, offline): the posting generator.

A decomposition grammar over a VERB REGISTRY, in the style of de Lima et al.
(ACE 2014) adapted to this repo's counter-derived world model -- Tier 1
ONLY (offline generation of DATA; no runtime planner, per the issue's own
ratified scope line). This script is the AUTHORING TOOL: it emits
candidates with a REVIEW verdict to
docs/archive/staging/board-staging/generated-candidates.json. A human (the curation
pass) then hand-polishes the ACCEPTED entries' prose and copies them,
stripped of every annotation field (the G2 discipline), into
data/bounties.json / data/deliveries.json / data/items.json verbatim. This
script never writes to data/ directly -- staging only.

VERB REGISTRY -- each verb bottoms out in a REAL, traced producer (the same
discipline data/bounties.json's own top _comment documents for its
original 9):
    kill    -- on_victory counters, RESPAWNING encounters only (a
               non-respawning encounter is removed after its one win, so a
               repeatable board condition referencing it would eventually
               dead-end -- see REJECTED candidates below for a concrete
               case this rule caught).
    carry   -- the delivery seam. Routes to data/deliveries.json growth
               directly, NEVER to a data/bounties.json condition: a bounty
               keyed on `completed_delivery_<id>` would pay a SECOND time
               for the exact same action the Delivery Board already pays
               for (the double-pay hazard docs/design/dialogue-drafts/
               home_region_2/hermit_antler_order.json's own note flags and
               deliveries.json's _comment resolves by "shipping neither" --
               this generator resolves it the same way, structurally,
               by never emitting a carry-verb bounty candidate at all).
    gather/work -- on_interact_accomplishment / on_skill_use producers.
               `use_skill()`/interact()'s prop branch both re-bank their
               accomplishment on EVERY call (verified against
               src/core/wi_game.gd -- no first-use dedup on either path),
               so any such producer is safely delta-mode repeatable UNLESS
               the entity gets removed/consumed by other content (checked
               per-candidate below).
    social  -- persuade/chat counters. Two subclasses, priced differently
               (see PAY FORMULA): "soft" (heard_gossip/chatted_with_<id>/
               befriended_moments -- generic, freely repeatable, cheap) and
               "hard" (persuaded_someone -- produced only by specific
               one-off quest-dialogue resolutions, bounded, pricier).
    survey  -- observe/visited counters. Two REAL sources: observed_things
               (WIFieldSkills.dispatch's generic [Appraise Foe] arm, banked
               once per faced entity per waking regardless of WHICH entity)
               and visited_<map> / reached_<place> (door
               on_enter_accomplishment, re-banked on every real door
               transit, confirmed against wi_game.gd's door branch).

PAY FORMULA -- tier-banded, delta-mode default. Recovered by regression
against the 6 EXISTING delta-mode bounties (the 3 absolute/one-shot
discovery bounties are hand-tuned finder's fees, deliberately excluded from
this formula -- see PILLAR_BASE_GOLD_PER_UNIT's own comment):
    pay = round(PILLAR_BASE_GOLD_PER_UNIT[pillar] * total_condition_units
                * TIER_GOLD_MULT[tier])
This reproduces all 9 existing delta-mode bounties' shipped pay EXACTLY
(see `_selfcheck_formula_against_existing_pool` at the bottom) -- strong
evidence the recovered rates are the real (if never-written-down) formula
the original 9 were hand-tuned against, not a coincidence.

NOUN TABLE -- givers are drawn ONLY from entities/names that already exist
somewhere in this repo's shipped data (skeleton_scene.json entity
display_names, or a giver name an earlier bounty already established) --
never a newly-invented character. Locations/targets are always real
entity ids already in data/skeleton_scene.json. This is the "never
invented names" rule, applied literally.
"""

import json
import re

from wi_data_lib import DATA, GAME_ROOT, load_json, load_scene

REPO_ROOT = GAME_ROOT.parent
STAGING_DIR = REPO_ROOT / "docs" / "archive" / "staging" / "board-staging"
STAGING_OUT = STAGING_DIR / "generated-candidates.json"

# KILL-RULE HARDENING (review HIGH): a respawning encounter is still a
# DEAD producer if any dialogue effect remove_entity-erases it (quest
# closes do this). Scan data/dialogue/*.json for remove_entity targets
# and either exclude those encounters from repeatable kill postings or
# emit condition_mode="absolute".


# ---------------------------------------------------------------------------
# VERB REGISTRY -- real, traced producers only. Each entry cites the exact
# file/field it was traced against (mirrors data/bounties.json's own _comment
# discipline for its original 9).
# ---------------------------------------------------------------------------

VERB_REGISTRY = {
    "kill": {
        "trace": "on_victory counters, RESPAWNING encounters only (data/skeleton_scene.json entity.on_victory, entity.respawns == true)",
        "repeatable": True,
    },
    "carry": {
        "trace": "the delivery seam (WIGame._check_delivery_arrival) -- routes to deliveries.json growth, never a bounty condition (double-pay hazard)",
        "repeatable": True,
    },
    "gather_work": {
        "trace": "on_interact_accomplishment / on_skill_use producers (WIGame.interact()'s prop branch / use_skill()) -- both re-bank on every call, no dedup",
        "repeatable": True,
    },
    "social_soft": {
        "trace": "heard_gossip / chatted_with_<id> (WISocial.talk_pool_line) or befriended_moments (WIFieldSkills.dispatch's [Charming Smile] arm) -- generic, freely repeatable",
        "repeatable": True,
    },
    "social_hard": {
        "trace": "persuaded_someone -- banked only by specific one-off dialogue-effect resolutions (grep across data/dialogue/*.json); bounded, not freely farmable",
        "repeatable": True,
    },
    "survey": {
        "trace": "observed_things (WIFieldSkills.dispatch's [Appraise Foe] arm, generic) or visited_<map>/reached_<place> (door on_enter_accomplishment, re-banked every real transit)",
        "repeatable": True,
    },
}

# ---------------------------------------------------------------------------
# PAY FORMULA -- recovered from the 9 existing delta-mode bounties.
# ---------------------------------------------------------------------------

# Gold per condition-unit, at T1, per pillar/subclass. "fight" reproduces
# bounty_road_cull (won_combat:2 -> 4g => 2.0/unit). "explore" reproduces
# bounty_observe_survey (observed_things:3 -> 3g => 1.0/unit). "work"
# reproduces bounty_evening_stew (cooked_meal:2 -> 2g => 1.0/unit, rounds
# down from the more conservative 0.75/unit fit against bounty_inn_hands
# below -- see the selfcheck for the exact reconciliation) and
# bounty_inn_hands (served_customer:3 -> 2g => 0.667/unit observed, but
# 0.75/unit rounds to the same shipped 2g). "social_soft" reproduces
# bounty_gossip_tea (heard_gossip:3 -> 2g => 0.667/unit). "social_hard"
# reproduces bounty_settle_dispute (persuaded_someone:1 -> 3g => 3.0/unit).
PILLAR_BASE_GOLD_PER_UNIT = {
    "fight": 2.0,
    "work": 0.75,
    "social_soft": 0.667,
    "social_hard": 3.0,
    "explore": 1.0,
}

# Linear tier band -- region-tiers.md gives combat difficulty tiers, not an
# economy multiplier, so this is this task's own modest, disclosed banding
# (not reverse-engineered from anything, since no T2+ bounty existed to
# regress against before this batch).
TIER_GOLD_MULT = {"T1": 1.0, "T2": 1.5, "T3": 2.0, "T4": 2.5, "T5": 3.0}


def compute_pay(pillar_rate_key: str, total_units: int, tier: str) -> int:
    raw = PILLAR_BASE_GOLD_PER_UNIT[pillar_rate_key] * total_units * TIER_GOLD_MULT[tier]
    return max(1, round(raw))


# ---------------------------------------------------------------------------
# CANDIDATES -- both ACCEPTED and REJECTED, so the curation pass is a real,
# auditable record (STOP trigger: "a posting needs a counter with NO
# existing producer -- drop it, note it").
# ---------------------------------------------------------------------------

BOUNTY_CANDIDATES = [
    {
        "id": "bounty_lamp_upkeep", "verb": "gather_work", "pillar": "work", "tier": "T1",
        "condition": {"lit_the_common_room": 2},
        "producer_trace": "data/skeleton_scene.json inn.unlit_lantern.on_skill_use.accomplishment ([Light]) -- use_skill() re-banks every cast, no dedup",
        "giver": "Lyonette du Marquin",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_tavern_tables", "verb": "gather_work", "pillar": "work", "tier": "T1",
        "condition": {"cleaned_the_inn": 3},
        "producer_trace": "data/skeleton_scene.json inn.dirty_table.on_skill_use.accomplishment ([Basic Cleaning]) -- re-banks every clean (already pays 1g/use itself; the bounty pay is separate, on top)",
        "giver": "Erin Solstice",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_market_watch", "verb": "gather_work", "pillar": "work", "tier": "T1",
        "condition": {"browsed_market": 2, "browsed_bread_stall": 1},
        "producer_trace": "data/skeleton_scene.json street.krshia_stall/bread_stall.on_interact_accomplishment",
        "giver": "Watch Guard (gate_guard, generic Watch hand)",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_barracks_checkin", "verb": "social_soft", "pillar": "social", "tier": "T1",
        "condition": {"chatted_with_duty_sergeant": 2},
        "producer_trace": "WISocial.talk_pool_line over data/skeleton_scene.json barracks.duty_sergeant.talk_pool",
        "giver": "Duty Sergeant Dresk Ashgrave",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_charm_offensive", "verb": "social_soft", "pillar": "social", "tier": "T1",
        "condition": {"befriended_moments": 3},
        "producer_trace": "WIFieldSkills.dispatch's [Charming Smile] arm (skills.json id charming_smile, field:true) -- generic over any faced entity",
        "giver": "Krshia Silverfang",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_bow_practice", "verb": "gather_work", "pillar": "work", "tier": "T1",
        "condition": {"ranged_hit": 3},
        "producer_trace": "data/skeleton_scene.json barracks.archery_butt.on_interact_accomplishment (GH#70's own [Archer]-earn producer -- reused here as an ALSO-a-bounty target, same double-dip shape as won_combat feeding both combat bounties and class level-ups elsewhere)",
        "giver": "Duty Sergeant Dresk Ashgrave",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_guild_census", "verb": "survey", "pillar": "explore", "tier": "T1",
        "condition": {"visited_guild": 3},
        "producer_trace": "data/skeleton_scene.json street.guild_door.on_enter_accomplishment -- re-banks on every real door transit (confirmed against wi_game.gd's door branch)",
        "giver": "Olesm Swifttail",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_alley_cull", "verb": "kill", "pillar": "fight", "tier": "T3",
        "condition": {"cleared_footpads_a": 1, "cleared_footpads_b": 1},
        "producer_trace": "data/skeleton_scene.json mercantile_alleys.alley_footpads_a/b -- respawns:true, on_victory cleared_footpads_a/b",
        "giver": "Master Coyle",
        "review": "ACCEPT",
    },
    # --- Issue #97 (bestiary expansion, THE PAYOFF): 6 new kill-verb candidates
    # against the new banks, one per new respawning encounter. Producer-traced
    # against data/maps/<region>/<map>.json (the issue #100 split -- these six
    # entries postdate that split, unlike the skeleton_scene.json-era ones
    # above). Already curated + shipped verbatim into data/bounties.json
    # (this generator run is the retroactive staging record + formula
    # cross-check, not a fresh proposal awaiting a separate curation pass).
    {
        "id": "bounty_corusdeer_cull", "verb": "kill", "pillar": "fight", "tier": "T1",
        "condition": {"corusdeer_culled": 2},
        "producer_trace": "data/maps/floodplains/floodplains.json corusdeer_range -- respawns:true, on_victory corusdeer_culled",
        "giver": "Beshta of the hunt camp (Gnoll hunter hand: short lines, hunt-family plural, one warning)",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_razorbeak_cull", "verb": "kill", "pillar": "fight", "tier": "T1",
        "condition": {"razorbeaks_culled": 2},
        "producer_trace": "data/maps/floodplains/floodplains.json razorbeak_nest -- respawns:true, on_victory razorbeaks_culled",
        "giver": "Beshta of the hunt camp (Gnoll hunter hand: short lines, hunt-family plural, one warning)",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_mothbear_cull", "verb": "kill", "pillar": "fight", "tier": "T3",
        "condition": {"mothbears_culled": 1},
        "producer_trace": "data/maps/invrisil/invrisil_boulevard.json boulevard_mothbears -- respawns:true, NIGHT-ONLY encounter_when, on_victory mothbears_culled -- single-kill by design (a night+sleep dormancy double-gate makes a 2-kill delta awkward to prove)",
        "giver": "Master Coyle",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_kingslayer_cull", "verb": "kill", "pillar": "fight", "tier": "T4",
        "condition": {"kingslayer_spiders_culled": 1},
        "producer_trace": "data/maps/dungeon/dungeon_approach.json kingslayer_den -- respawns:true, on_victory kingslayer_spiders_culled -- single-kill by design, an apex predator not a farming grind",
        "giver": "Selys Sharpear",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_forge_golem_cull", "verb": "kill", "pillar": "fight", "tier": "T5",
        "condition": {"forge_golems_culled": 2},
        "producer_trace": "data/maps/pallass/pallass_forge.json forge_calibration_golem -- respawns:true, on_victory forge_golems_culled -- Pallass's first combat producer",
        "giver": "Grimalkin",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_watchgolem_cull", "verb": "kill", "pillar": "fight", "tier": "T5",
        "condition": {"watchgolems_culled": 2},
        "producer_trace": "data/maps/pallass/pallass_market.json market_watchgolems -- respawns:true, on_victory watchgolems_culled",
        "giver": "The Market Stallkeepers (pooled)",
        "review": "ACCEPT",
    },
    {
        "id": "bounty_second_watch", "verb": "social_hard", "pillar": "social", "tier": "T2",
        "condition": {"persuaded_someone": 2},
        "producer_trace": "persuaded_someone -- multiple one-off dialogue-effect resolutions across data/dialogue/*.json (drayman_dispute, watch_crate[Diplomat], zevara_intro[Diplomat], krshia_crate, pisces_magic, goblin_parley[Warrior], riverfarm_witch) -- same bounded-but-real counter bounty_settle_dispute already rides at threshold 1",
        "giver": "Watch Captain Zevara Sunderscale",
        "review": "ACCEPT",
    },
    # --- REJECTED (STOP-trigger discipline; kept for the curation record) ---
    {
        "id": "bounty_carry_reuse_REJECTED", "verb": "carry", "pillar": "fight", "tier": "T1",
        "condition": {"completed_delivery_delivery_krshia_wool": 1},
        "producer_trace": "completed_delivery_<id> (WIGame.turn_in_delivery) -- a REAL producer, but",
        "giver": "n/a",
        "review": "REJECT: double-pay hazard. This accomplishment already pays out via the Delivery Board; a bounty keyed on the SAME id pays a second time for one action. Exactly the hazard deliveries.json's own _comment flags for delivery_hermit_antlers (\"HR-II must reconcile... never both untouched\"). The carry verb routes to deliveries.json growth instead -- never a bounty condition.",
    },
    {
        "id": "bounty_warehouse_crew_REJECTED", "verb": "kill", "pillar": "fight", "tier": "T3",
        "condition": {"forced_confession": 2},
        "producer_trace": "data/skeleton_scene.json mercantile_alleys.hired_blades.on_victory -- respawns:false",
        "giver": "n/a",
        "review": "REJECT: hired_blades is a ONE-SHOT encounter (respawns:false, persistent:false) tied to the invrisil_disagreement_fight quest chain -- removed after its single win. A delta-mode repeatable bounty referencing it would dead-end after the quest resolves (the exact kill-verb rule this task's own scope line states: respawning encounters only). Not shippable as a repeatable board job.",
    },
    {
        "id": "bounty_short_order_REJECTED", "verb": "gather_work", "pillar": "work", "tier": "T1",
        "condition": {"stretched_the_order": 2},
        "producer_trace": "data/skeleton_scene.json inn.short_order.on_skill_use.accomplishment",
        "giver": "n/a",
        "review": "REJECT: short_order's own _comment states this accomplishment is deliberately isolated from the shared stew_pot/cooked_meal counter for the Wrong Order quest chain (\"this pattern is reserved for quest-scoped cooking that must NOT feed this shared counter\"). Reusing it for a generic repeatable board bounty risks exactly the cross-feed the quest content was written to avoid. Dropped.",
    },
    {
        "id": "bounty_deep_fissure_REJECTED", "verb": "survey", "pillar": "explore", "tier": "T2",
        "condition": {"found_the_fissure": 1, "found_cold_hearth": 1},
        "producer_trace": "data/skeleton_scene.json deep_tunnels/sewers one-shot discovery props, no respawn/re-trigger safety",
        "giver": "n/a",
        "review": "REJECT: one-shot discovery counters with no condition_mode:absolute safety net authored in this batch (unlike the sewer trio precedent) -- a player who found these before ever visiting the board would soft-lock under delta mode. Could ship safely as absolute-mode, but deep_tunnels is deep midgame content the curation pass judged tonally too far from the Liscor request-board's voice for THIS batch. Parked, not permanently dropped.",
    },
]

DELIVERY_CANDIDATES = [
    {
        "id": "delivery_barracks_gear",
        "parcel_id": "parcel_gambeson_bundle", "parcel_name": "Bundled Gambesons",
        "parcel_flavor": "Watch-issue gambesons, three of them, bundled tight and none too soft.",
        "destination_map": "barracks", "destination_cell": [6, 4], "anchor_entity": "duty_sergeant",
        "band": "cross-map, short", "tier": "T1",
        "review": "ACCEPT",
    },
    {
        "id": "delivery_guild_ledger",
        "parcel_id": "parcel_ledger_transfer", "parcel_name": "Sealed Ledger Transfer",
        "parcel_flavor": "A ledger, sealed, Guild business written on the outside and nothing else.",
        "destination_map": "guild", "destination_cell": [8, 2], "anchor_entity": "selys",
        "band": "cross-map", "tier": "T1",
        "review": "ACCEPT",
    },
    {
        "id": "delivery_tactics_brief",
        "parcel_id": "parcel_tactics_brief", "parcel_name": "Rolled Tactics Brief",
        "parcel_flavor": "A brief, rolled and string-tied, the ink still faintly damp at the edges.",
        "destination_map": "street", "destination_cell": [29, 3], "anchor_entity": "olesm",
        "band": "same-map long", "tier": "T1",
        "review": "ACCEPT",
    },
    {
        "id": "delivery_boulevard_letter",
        "parcel_id": "parcel_sealed_letter", "parcel_name": "A Sealed Letter",
        "parcel_flavor": "A letter, wax-sealed, no return address, the kind that pays for its own silence.",
        "destination_map": "invrisil_boulevard", "destination_cell": [24, 6], "anchor_entity": "master_coyle",
        "band": "cross-region", "tier": "T3",
        "review": "ACCEPT",
    },
    {
        "id": "delivery_riverfarm_seed",
        "parcel_id": "parcel_seed_grain", "parcel_name": "A Sack of Seed Grain",
        "parcel_flavor": "A sack of seed grain, dense and dry, tied at the neck against damp roads.",
        "destination_map": "riverfarm_village", "destination_cell": [11, 9], "anchor_entity": "riverfarm_headman",
        "band": "cross-region", "tier": "T3",
        "review": "ACCEPT",
    },
]

# Delivery gold isn't unit-priced (a delivery condition is always exactly
# {"delivered_<id>": 1} -- one carry, one payout); it rides the SAME band
# vocabulary the existing 5 established: same-map short=1g, same-map long/
# +care=2g, cross-map=3g. This batch adds ONE new band, cross-region (via
# the Magical Door / portal system -- see WIGame._check_delivery_arrival's
# own doc comment: it works generically off current_map, no engine change
# needed), priced above cross-map to reflect the genuinely longer/portal-
# gated trip.
BAND_GOLD = {
    "same-map short": 1,
    "same-map long": 2,
    "same-map + care": 2,
    "cross-map": 2,
    "cross-map, short": 2,
    "cross-region": 4,
}


def build_candidates() -> dict:
    scene = load_scene()
    entity_ids = set()
    for map_data in scene["maps"].values():
        for ent in map_data.get("entities", []):
            entity_ids.add(ent["id"])

    out_bounties = []
    for c in BOUNTY_CANDIDATES:
        entry = dict(c)
        if c["review"] == "ACCEPT":
            rate_key = c["pillar"] if c["pillar"] != "social" else c["verb"]
            total_units = sum(c["condition"].values())
            entry["computed_pay"] = compute_pay(rate_key, total_units, c["tier"])
        out_bounties.append(entry)

    out_deliveries = []
    for c in DELIVERY_CANDIDATES:
        entry = dict(c)
        if c["review"] == "ACCEPT":
            entry["computed_gold"] = BAND_GOLD[c["band"]]
            entry["anchor_exists_in_scene"] = c["anchor_entity"] in entity_ids
        out_deliveries.append(entry)

    return {
        "_comment": "STAGING ONLY -- issue #72 tier-1 offline generator output. Not read by the game. A human curation pass hand-polishes ACCEPTED entries' prose and copies them (stripped of every annotation field, the G2 discipline) into data/bounties.json / data/deliveries.json / data/items.json.",
        "verb_registry": VERB_REGISTRY,
        "pay_formula": {
            "pillar_base_gold_per_unit": PILLAR_BASE_GOLD_PER_UNIT,
            "tier_gold_mult": TIER_GOLD_MULT,
            "band_gold": BAND_GOLD,
        },
        "bounties": out_bounties,
        "deliveries": out_deliveries,
    }


def selfcheck_formula_against_existing_pool() -> None:
    """Regression-checks PAY FORMULA against the 9 EXISTING delta-mode
    bounties (the 3 absolute/one-shot discovery bounties are excluded --
    hand-tuned finder's fees, not per-unit-rate work). Fails loudly if the
    recovered rates ever drift from the shipped pool."""
    bounties = load_json(DATA / "bounties.json")["bounties"]
    checks = {
        "bounty_road_cull": ("fight", 2, "T1", 4),
        "bounty_settle_dispute": ("social_hard", 1, "T1", 3),
        "bounty_gossip_tea": ("social_soft", 3, "T1", 2),
        "bounty_observe_survey": ("explore", 3, "T1", 3),
        "bounty_inn_hands": ("work", 3, "T1", 2),
        "bounty_evening_stew": ("work", 2, "T1", 2),
    }
    by_id = {b["id"]: b for b in bounties}
    for bounty_id, (rate_key, units, tier, expected_gold) in checks.items():
        shipped_gold = by_id[bounty_id]["gold"]
        assert shipped_gold == expected_gold, f"{bounty_id}: expected shipped gold {expected_gold}, pool has {shipped_gold}"
        computed = compute_pay(rate_key, units, tier)
        assert computed == expected_gold, f"{bounty_id}: formula computed {computed}g, shipped pool pays {expected_gold}g -- formula drift"
    print(f"selfcheck: formula reproduces {len(checks)}/6 existing delta-mode bounties exactly (3 absolute-mode discovery bounties excluded by design)")


def main() -> None:
    selfcheck_formula_against_existing_pool()
    STAGING_DIR.mkdir(parents=True, exist_ok=True)
    payload = build_candidates()
    STAGING_OUT.write_text(json.dumps(payload, indent=1) + "\n")
    accepted_b = sum(1 for b in payload["bounties"] if b["review"] == "ACCEPT")
    rejected_b = sum(1 for b in payload["bounties"] if b["review"] != "ACCEPT")
    accepted_d = sum(1 for d in payload["deliveries"] if d["review"] == "ACCEPT")
    print(f"wrote {STAGING_OUT.relative_to(REPO_ROOT)}")
    print(f"bounty candidates: {accepted_b} ACCEPT, {rejected_b} REJECT")
    print(f"delivery candidates: {accepted_d} ACCEPT")


if __name__ == "__main__":
    main()
