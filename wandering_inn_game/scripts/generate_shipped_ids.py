#!/usr/bin/env python3
"""Issue #99 (full-game-architecture spec §2.1): the shipped-ids freeze list
generator.

Demo saves must load in the full game FOREVER: every accomplishment counter,
item id, map key, class id, and skill id present in ANY shipped save becomes
permanent API. This script scans the current catalogs + source-traced
producer sites and writes data/shipped_ids.json -- the freeze list a public
release tag cuts. Policy (spec §2.1): a shipped id is never renamed or
re-semanticized, only DEPRECATED-AND-MAPPED inside WISave.DEPRECATED_IDS
(src/core/save.gd). tests/test_shipped_ids.gd is the validator arm: it
FAILS LOUD when a frozen id has vanished from its live catalog with no
covering DEPRECATED_IDS entry.

DETERMINISM: every id list is a SORTED, deduplicated array; the top-level
key order is fixed by this file's own literal dict construction (never a
directory-listing/dict-iteration order) -- rerunning against an unchanged
tree produces a byte-identical file.

FIVE ID CLASSES, and what "disappeared" means for each (spec §2.1's own
"counters need care" callout):
    classes / skills / items -- a frozen id must still be a key in
        data/classes.json / data/skills.json / data/items.json's own id
        list. "Disappeared" = removed from that catalog file entirely.
    maps -- a frozen id must still be a key of the composed data/maps/**
        "maps" dict (WISave.apply's own game.has_map() gate reads this same
        set -- a save standing on a removed map is UNLOADABLE, not just
        content-broken). "Disappeared" = the map key removed from the file.
    accomplishments -- NOT a catalog entry anywhere (they are free-form
        counter ids referenced inline across data/*.json and src/**).
        "Disappeared" = no longer produced by ANY live path this script
        traces (see CENSUS below) -- the exact same shape test_content.gd's
        own produced_accomplishments dict already validates authored
        CONTENT GATES against, extended here to the WIDER set of ids that
        can land in a shipped save's `accomplishments` dict (test_content.gd
        only needs the narrower "referenced by an authored gate" subset;
        this freeze list needs the full "can appear in save state" set).

CENSUS -- accomplishment counter sources, each hand-traced against a real
producer (mirrors test_content.gd's _collect_scene_accomplishments /
_validate_effect discipline, extended past its scope -- see the class
docstring above):
  1. STRUCTURAL_LITERALS -- bare `record_accomplishment("literal")` /
     WICombat._tally(actor, "literal") call sites across src/** (NOT just
     src/core/**: `post_game`'s producer is src/ui/sleep_veil.gd's
     epilogue beat, via Game.sim.record_accomplishment), traced by hand
     (not derivable from any data/*.json scan). KEEP IN SYNC with
     tests/test_shipped_ids.gd's own STRUCTURAL_LITERALS constant -- a new
     bare-literal call site anywhere needs an entry added to BOTH.
  2. Combat action-tally DYNAMIC counters (WICombat._tally_skill_use):
     "<weapon>_skill_used" per distinct skills.json `weapon` tag,
     "<element>_cast" per distinct `element` tag -- genuinely data-driven,
     not hardcoded (a new weapon/element tag value automatically grows this
     set; the freeze list only cares about ids DISAPPEARING, so a NEW tag
     value showing up later is a non-event for the validator).
  3. Scene-derived (data/maps/** entities): on_victory (or the
     "won_combat" structural default WIGame.resolve_combat falls back to
     for a kind:encounter entity with no authored on_victory -- explicit in
     every shipped entity today, defensive for tomorrow),
     on_skill_use.accomplishment (+ its `variants` override),
     on_interact_accomplishment (+ its own `variants` override),
     on_open_accomplishment, on_enter_accomplishment, a non-empty talk_pool
     (-> heard_gossip + chatted_with_<id>), board_rumors[].banks_accomplishment.
  4. Dialogue-effect producers: every `{"accomplishment": id}` effect across
     data/dialogue/*.json.
  5. Board/delivery id-derived: WIGame.accept_bounty/turn_in_bounty and
     their Runner's Guild twins bank on the ACCEPTED id
     ("accepted_bounty_<id>"/"completed_bounty_<id>",
     "accepted_delivery_<id>"/"delivered_<id>"/"completed_delivery_<id>") --
     not scannable from any per-entry data field, so derived here from every
     id in data/bounties.json / data/deliveries.json directly.

NOT covered (STOP-trigger discipline, disclosed rather than silently
skipped): free-form ids typed directly into a fixture/save file's
`accomplishments` dict that no live code path produces would already be
dead weight before this task; none exist in the composed map catalog's own
_comment-documented content as of this cut.
"""

import json

from wi_data_lib import DATA, GAME_ROOT, load_dialogue_graphs, load_json, load_scene

OUT_PATH = DATA / "shipped_ids.json"

RELEASE = "0.16.2"

# ---------------------------------------------------------------------------
# STRUCTURAL_LITERALS -- KEEP IN SYNC with tests/test_shipped_ids.gd's own
# const of the same name (see module docstring, census source 1).
# ---------------------------------------------------------------------------
STRUCTURAL_LITERALS = [
    "observed_things", "befriended_moments", "deliberate_commerce",
    "burned_the_debris", "sneaked_past_danger", "read_the_board",
    "read_the_delivery_board", "door_study_sleeps", "door_awakened",
    "watch_runner_pointed", "reached_two_classes", "garden_door_unlocked",
    "post_game", "victories", "melee_hit", "ranged_hit", "spell_cast",
    "slept",
    "completed_delivery", "blinked_past_danger",
    "warded_danger", "witch_craft_used", "second_door_study_sleeps",
    "dungeon_attuned", "catalyst_attunement_sleeps", "resonance_grown",
    "tended_beasts", "finale_played",
    # v017-L5 (GH#332): banked by wi_game._clear_companion, and only on a
    # TAMED downed-clear. Own row under this lane's anchor rather than
    # appended to the line above, so a sibling lane adding its own
    # code-banked counter appends a row instead of colliding on a shared
    # line. Same shape in tests/test_shipped_ids.gd.
    "companion_lost",
]


def catalog_ids(catalog: dict, key: str) -> list:
    return sorted({str(entry["id"]) for entry in catalog.get(key, [])})


def map_ids(scene: dict) -> list:
    return sorted(str(k) for k in scene.get("maps", {}))


def produced_accomplishments(scene: dict, graphs: dict, skills: dict, bounties: dict, deliveries: dict) -> list:
    out = set(STRUCTURAL_LITERALS)

    for skill in skills.get("skills", []):
        if "weapon" in skill:
            out.add("%s_skill_used" % skill["weapon"])
        if "element" in skill:
            out.add("%s_cast" % skill["element"])

    for map_data in scene.get("maps", {}).values():
        for entity in map_data.get("entities", []):
            if entity.get("kind") == "encounter":
                victory = entity.get("on_victory", "won_combat")
                victory_ids = victory if isinstance(victory, list) else [victory]
                out.update(str(v) for v in victory_ids)
            skill_use = entity.get("on_skill_use", {})
            if "accomplishment" in skill_use:
                out.add(str(skill_use["accomplishment"]))
            for variant in skill_use.get("variants", []):
                if "accomplishment" in variant:
                    out.add(str(variant["accomplishment"]))
            # v0.16 close: the per-skill arm map (`skill_uses`) wins over
            # `on_skill_use` at runtime (wi_game.gd:427-433) and test_content
            # already counts its arms as producers (:466-469); omitting it
            # here shipped-froze around two live counters (flood_prep_done).
            for arm in entity.get("skill_uses", {}).values():
                if not isinstance(arm, dict):
                    continue
                if "accomplishment" in arm:
                    out.add(str(arm["accomplishment"]))
                for variant in arm.get("variants", []):
                    if "accomplishment" in variant:
                        out.add(str(variant["accomplishment"]))
            if "on_interact_accomplishment" in entity:
                out.add(str(entity["on_interact_accomplishment"]))
                for variant in entity.get("variants", []):
                    if "accomplishment" in variant:
                        out.add(str(variant["accomplishment"]))
            if "on_open_accomplishment" in entity:
                # Task 2.3: String|Array, the on_victory contract above. A bare
                # str() over a list would freeze one garbage "['a', 'b']" id and
                # silently drop the real ones.
                opened = entity["on_open_accomplishment"]
                opened_ids = opened if isinstance(opened, list) else [opened]
                out.update(str(o) for o in opened_ids)
            if "on_enter_accomplishment" in entity:
                out.add(str(entity["on_enter_accomplishment"]))
            if entity.get("talk_pool"):
                out.add("heard_gossip")
                out.add("chatted_with_%s" % entity["id"])
            for rumor in entity.get("board_rumors", []):
                out.add(str(rumor["banks_accomplishment"]))

    for graph in graphs.values():
        for node in graph.get("nodes", {}).values():
            for option in node.get("options", []):
                for effect in option.get("effects", []):
                    if "accomplishment" in effect:
                        out.add(str(effect["accomplishment"]))

    for bounty in bounties.get("bounties", []):
        bid = str(bounty["id"])
        out.add("accepted_bounty_%s" % bid)
        out.add("completed_bounty_%s" % bid)
    for delivery in deliveries.get("deliveries", []):
        did = str(delivery["id"])
        out.add("accepted_delivery_%s" % did)
        out.add("delivered_%s" % did)
        out.add("completed_delivery_%s" % did)

    return sorted(out)


def build_payload() -> dict:
    classes = load_json(DATA / "classes.json")
    skills = load_json(DATA / "skills.json")
    items = load_json(DATA / "items.json")
    scene = load_scene()
    bounties = load_json(DATA / "bounties.json")
    deliveries = load_json(DATA / "deliveries.json")
    graphs = load_dialogue_graphs()

    return {
        "_comment": (
            "GENERATED by scripts/generate_shipped_ids.py -- do not hand-edit. "
            "Issue #99 (full-game-architecture spec section 2.1): the shipped-ids "
            "freeze contract. Every id below was reachable in a real shipped save "
            "as of `release` and is now PERMANENT API: never renamed or "
            "re-semanticized, only deprecated-and-mapped via "
            "WISave.DEPRECATED_IDS (src/core/save.gd). "
            "tests/test_shipped_ids.gd fails loud if any id here has vanished "
            "from its live catalog without a covering DEPRECATED_IDS entry. "
            "Regenerate at every public release tag (re-run this script; a "
            "clean tree yields a byte-identical file, so a diff means the "
            "catalogs genuinely grew since the last cut)."
        ),
        "release": RELEASE,
        "classes": catalog_ids(classes, "classes"),
        "skills": catalog_ids(skills, "skills"),
        "items": catalog_ids(items, "items"),
        "maps": map_ids(scene),
        "accomplishments": produced_accomplishments(scene, graphs, skills, bounties, deliveries),
    }


def main() -> None:
    payload = build_payload()
    OUT_PATH.write_text(json.dumps(payload, indent=1) + "\n")
    counts = {k: len(v) for k, v in payload.items() if isinstance(v, list)}
    print("wrote %s (release %s)" % (OUT_PATH.relative_to(GAME_ROOT), payload["release"]))
    for id_class, count in counts.items():
        print("  %s: %d" % (id_class, count))


if __name__ == "__main__":
    main()
