#!/usr/bin/env python3
"""Resource ledger for a continuous QA journey, read from its events.jsonl.

Reports per fight: encounter, map, entry and exit HP/MP, result, rounds and
items used, plus the route's sleeps, reloads, gold, equipment changes and
out-of-combat recovery. Entry/exit come from `resources_changed`
(`combat_entry` / `combat_victory`); a defeat's exit is its last in-combat
resource change and its rollback state the next rendered field vitals. A fight
that ends in a load without `combat_finished` (pause-menu Abandon) is recorded
as `abandoned` with the same exit/rollback treatment.

    python3 scripts/journey_ledger.py wandering_inn_game/qa_output/<script>/events.jsonl [--json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _vitals(state: dict | None) -> str:
	if not state:
		return "?"
	text = f"{state.get('hp')}/{state.get('max_hp')} HP"
	if state.get("max_mp"):
		text += f", {state.get('mp')}/{state.get('max_mp')} MP"
	if state.get("mp_potion_doses"):
		text += f", {state.get('mp_potion_doses')} doses"
	return text


def _close(ledger: dict, fight: dict, result: str) -> None:
	fight["result"] = result
	if fight["exit"] is None:
		fight["exit"] = fight.get("last_action") or fight["entry"]
	ledger["fights"].append(fight)


def build(events: list[dict]) -> dict:
	ledger: dict = {"fights": [], "sleeps": [], "reloads": [], "gold": [], "equipment": [], "recovery": [], "maps": []}
	current_map = ""
	vitals: dict | None = None
	fight: dict | None = None
	awaiting_rollback: dict | None = None
	finished: dict | None = None
	for event in events:
		kind = event.get("type")
		payload = event.get("payload", {})
		if kind == "map_changed":
			current_map = str(payload.get("map", ""))
			ledger["maps"].append(current_map)
		elif kind == "combat_preparing":
			if fight is not None and fight["entry"] is not None:
				_close(ledger, fight, "abandoned")
				awaiting_rollback = fight
			finished = None
			fight = {"encounter": payload.get("encounter"), "map": current_map, "entry": None, "exit": None,
				"result": None, "rounds": None, "items": [], "before_entry": vitals}
		elif kind == "resources_changed":
			after = payload.get("after")
			reason = payload.get("reason")
			if fight is not None and reason == "combat_entry":
				fight["entry"] = after
			elif reason == "combat_victory":
				target = fight if fight is not None else finished
				if target is not None:
					target["exit"] = after
			elif reason == "sleep":
				ledger["sleeps"].append({"map": current_map, "source": payload.get("source"), "after": after})
			elif reason == "equipment":
				ledger["equipment"].append({"map": current_map, "source": payload.get("source"),
					"before": payload.get("before"), "after": after})
			elif fight is None and reason not in ("combat_action", "item_use"):
				ledger["recovery"].append({"map": current_map, "reason": reason, "source": payload.get("source"),
					"before": payload.get("before"), "after": after})
			if fight is not None and reason == "combat_action" and after:
				fight["last_action"] = after
			vitals = after or vitals
		elif kind == "item_use_settled" and payload.get("committed"):
			row = {"item": payload.get("item"), "context": payload.get("context"), "map": current_map,
				"before": payload.get("before"), "after": payload.get("after"),
				"dose": payload.get("dose_number"), "exposure": payload.get("exposure_after"), "ap_cost": payload.get("ap_cost")}
			if fight is not None:
				fight["items"].append(row)
			else:
				ledger["recovery"].append({"map": current_map, "reason": "item_use", "source": row["item"],
					"before": row["before"], "after": row["after"], "exposure": row["exposure"]})
		elif kind == "combat_finished" and fight is not None:
			fight["rounds"] = payload.get("rounds")
			fight["result"] = "draw" if payload.get("draw") else ("win" if payload.get("victory") else "loss")
			if fight["result"] != "win" and fight["exit"] is None:
				fight["exit"] = fight.get("last_action")
			ledger["fights"].append(fight)
			if fight["result"] == "loss":
				awaiting_rollback = fight
			finished = fight
			fight = None
		elif kind == "game_loaded":
			ledger["reloads"].append({"reason": payload.get("reason") or "load", "map": current_map})
			if fight is not None and fight["entry"] is not None:
				_close(ledger, fight, "abandoned")
				awaiting_rollback = fight
			if fight is not None:
				finished = None
				fight = None
		elif kind == "ui_resources_rendered" and awaiting_rollback is not None and payload.get("surface") == "field":
			awaiting_rollback["rollback"] = payload.get("after")
			vitals = payload.get("after") or vitals
			awaiting_rollback = None
		elif kind == "gold_changed":
			ledger["gold"].append({"delta": payload.get("delta"), "source": payload.get("source"),
				"total": payload.get("total"), "map": current_map})
	for row in ledger["fights"]:
		row.pop("last_action", None)
		row.pop("before_entry", None)
	attempts: dict = {}
	for row in ledger["fights"]:
		attempts.setdefault(row["encounter"], []).append(row["result"])
	earned = sum(g["delta"] for g in ledger["gold"] if (g["delta"] or 0) > 0)
	spent = -sum(g["delta"] for g in ledger["gold"] if (g["delta"] or 0) < 0)
	ledger["summary"] = {
		"fights": len(ledger["fights"]),
		"wins": sum(1 for r in ledger["fights"] if r["result"] == "win"),
		"losses": sum(1 for r in ledger["fights"] if r["result"] == "loss"),
		"abandoned": sum(1 for r in ledger["fights"] if r["result"] == "abandoned"),
		"retried": {k: v for k, v in attempts.items() if len(v) > 1},
		"sleeps": len(ledger["sleeps"]),
		"gold_earned": earned,
		"gold_spent": spent,
		"gold_final": ledger["gold"][-1]["total"] if ledger["gold"] else 0,
		"final_vitals": vitals,
	}
	return ledger


def markdown(ledger: dict) -> str:
	lines = ["| # | Encounter | Map | Entry | Exit | Result | Rounds | Items |", "|---|---|---|---|---|---|---|---|"]
	for index, row in enumerate(ledger["fights"], 1):
		items = "; ".join(f"{i['item']} (dose {i['dose']})" if i.get("dose") else str(i["item"]) for i in row["items"]) or "-"
		exit_text = _vitals(row["exit"])
		if row["result"] in ("loss", "abandoned"):
			exit_text += f" → rollback {_vitals(row.get('rollback'))}"
		lines.append(f"| {index} | {row['encounter']} | {row['map']} | {_vitals(row['entry'])} | {exit_text} | {row['result']} | {row['rounds']} | {items} |")
	summary = ledger["summary"]
	lines += ["", f"Fights {summary['fights']} (wins {summary['wins']}, losses {summary['losses']}, abandoned {summary['abandoned']}); "
		f"retried {summary['retried'] or 'none'}; sleeps {summary['sleeps']}; gold +{summary['gold_earned']} "
		f"-{summary['gold_spent']} = {summary['gold_final']}; final {_vitals(summary['final_vitals'])}.", ""]
	lines.append("Sleeps: " + ("; ".join(f"{s['map']} {s['source']} → {_vitals(s['after'])}" for s in ledger["sleeps"]) or "none"))
	lines.append("Recovery outside combat: " + ("; ".join(f"{r['map']} {r['reason']}:{r['source']} {_vitals(r['before'])} → {_vitals(r['after'])}" for r in ledger["recovery"]) or "none"))
	lines.append("Equipment: " + ("; ".join(f"{e['map']} {e['source']} {_vitals(e['before'])} → {_vitals(e['after'])}" for e in ledger["equipment"]) or "none"))
	lines.append("Reloads: " + ("; ".join(f"{r['reason']}@{r['map']}" for r in ledger["reloads"]) or "none"))
	lines.append("Gold: " + ("; ".join(f"{g['source']} {g['delta']:+d}→{g['total']}" for g in ledger["gold"]) or "none"))
	return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("events", type=Path)
	parser.add_argument("--json", action="store_true")
	args = parser.parse_args(argv)
	events = [json.loads(line) for line in args.events.read_text().splitlines() if line.strip()]
	ledger = build(events)
	sys.stdout.write(json.dumps(ledger, indent=1) + "\n" if args.json else markdown(ledger))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
