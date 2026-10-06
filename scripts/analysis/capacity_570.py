#!/usr/bin/env python3
"""Report catalog arithmetic for #570; does not simulate equip or combat."""

import argparse
import itertools
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "wandering_inn_game/data"
DOC = ROOT / "docs/design/570-capacity-analysis.md"
START = "<!-- capacity-570:begin -->"
END = "<!-- capacity-570:end -->"
CAPACITIES = (2, 3, 4, 5)
LOADOUTS = {
    "A: current shop pair": ("hunters_fang_talisman", "hedge_ward_charm"),
    "B: current pair + Stonescale": (
        "hunters_fang_talisman", "hedge_ward_charm", "stonescale_talisman"),
    "C: current grown trio": (
        "hunters_fang_talisman", "hedge_ward_charm", "phosphor_pendant"),
    "D: shield + two Hedault pieces": (
        "hedaults_wardstone", "hedaults_hunters_fang", "hedaults_traveler_charm"),
    "E: earned Lichbone alone": ("lichbone_wand",),
    "F: earned Lichbone + Fang": ("lichbone_wand", "hunters_fang_talisman"),
    "G: earned Lichbone + pair": (
        "lichbone_wand", "hunters_fang_talisman", "hedge_ward_charm"),
    "H: earned Anchor + pair": (
        "anchor_sliver", "hunters_fang_talisman", "hedge_ward_charm"),
    "I: two costly pieces": ("lichbone_wand", "anchor_sliver"),
    "J: four pieces, budget fits": (
        "copper_luck_band", "hunters_fang_talisman", "hedge_ward_charm", "phosphor_pendant"),
}


def read(relative):
    return json.loads((DATA / relative).read_text())


def grant_option(filename, node, item_id, required_item=None):
    options = read(f"dialogue/{filename}.json")["nodes"][node]["options"]
    matches = [option for option in options
               if any(effect.get("item") == item_id
                      for effect in option.get("effects", []))
               and option.get("requires", {}).get("item") == required_item]
    if len(matches) != 1:
        raise ValueError(f"Expected one acquisition arm for {item_id}: {len(matches)}")
    option = matches[0]
    spent = -sum(effect.get("gold", 0) for effect in option["effects"])
    if spent <= 0 or spent != option["requires"]["gold"]:
        raise ValueError(f"Acquisition gate/payment mismatch for {item_id}")
    if required_item and not any(effect.get("remove_item") == required_item
                                 for effect in option["effects"]):
        raise ValueError(f"Upgrade does not consume {required_item}")
    return spent


def report():
    items = {item["id"]: item for item in read("items.json")["items"]}
    skills = {skill["id"]: skill for skill in read("skills.json")["skills"]}
    lines = ["| Loadout | Resonance | Accessory positions | Flat HP | Flat damage | Flat reduction | Item-granted Skills | Budget fits 2 / 3 / 4 / 5 |",
             "|---|---:|---:|---:|---:|---:|---|---|"]
    for name, ids in LOADOUTS.items():
        records = [items[item_id] for item_id in ids]
        if len(set(ids)) != len(ids) or any(item["kind"] != "accessory" for item in records):
            raise ValueError(f"Expected distinct accessories: {name}")
        totals = {field: sum(item.get(field, 0) for item in records)
                  for field in ("resonance", "hp_mod", "damage_mod", "damage_reduction")}
        abilities = sorted({ability for item in records for ability in item.get("abilities", [])})
        names = ", ".join(skills[ability]["display_name"] for ability in abilities) or "—"
        fits = " / ".join("yes" if totals["resonance"] <= cap else "no" for cap in CAPACITIES)
        lines.append(f"| {name} | {totals['resonance']} | {len(ids)} | {totals['hp_mod']} | "
                     f"{totals['damage_mod']} | {totals['damage_reduction']} | {names} | {fits} |")

    useful = [item for item in items.values() if item.get("kind") == "accessory"
              and item.get("resonance", 0) > 0
              and (any(item.get(field, 0) for field in ("hp_mod", "damage_mod", "damage_reduction"))
                   or item.get("abilities"))]
    lines += ["", f"Catalog scope: {len(useful)} positive-resonance accessories with a nonzero flat modifier or an ability.",
              "", "| Capacity | Single items | Two-item sets | Three-item sets |",
              "|---:|---:|---:|---:|"]
    for cap in CAPACITIES:
        counts = [sum(sum(item["resonance"] for item in group) <= cap
                      for group in itertools.combinations(useful, size)) for size in (1, 2, 3)]
        lines.append(f"| {cap} | {' | '.join(map(str, counts))} |")

    fang = grant_option("krshia_crate", "charms", "hunters_fang_talisman")
    hedge = grant_option("krshia_crate", "charms", "hedge_ward_charm")
    stone = grant_option("krshia_crate", "charms", "stonescale_talisman")
    pendant = grant_option("invrisil_wilovan", "fence", "phosphor_pendant")
    bead = grant_option("riverfarm_witch", "shop", "witch_wardstone_bead")
    shield = bead + grant_option("hedault_enchanting", "hub", "hedaults_wardstone", "witch_wardstone_bead")
    keen = fang + grant_option("hedault_enchanting", "hub", "hedaults_hunters_fang", "hunters_fang_talisman")
    ward_fee = grant_option("hedault_enchanting", "hub", "hedaults_traveler_charm", "traveler_charm")
    lines += ["", "Actual dialogue gold debits (excluding travel and prerequisites):",
              "", f"- A: {fang + hedge}g; B: {fang + hedge + stone}g; C: {fang + hedge + pendant}g.",
              f"- True-Set Wardstone: {shield}g = {bead}g bead + {shield - bead}g fee; Keen-Set Hunters Fang: {keen}g = {fang}g fang + {keen - fang}g fee.",
              f"- D: {shield + keen}g plus the Traveler's Charm acquisition cost plus its {ward_fee}g upgrade fee.",
              f"- G/H: an earned unpriced item plus {fang + hedge}g for the purchased pair."]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check the document's generated table against current data")
    args = parser.parse_args()
    generated = report()
    if args.check:
        document = DOC.read_text()
        actual = document.split(START, 1)[1].split(END, 1)[0].strip()
        if actual != generated:
            raise SystemExit("FAIL: #570 document tables differ from current catalog/dialogue data")
        print("PASS: #570 catalog arithmetic and acquisition tables match current data")
    else:
        print(generated)


if __name__ == "__main__":
    main()
