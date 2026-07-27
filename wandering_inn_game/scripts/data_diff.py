#!/usr/bin/env python3
"""data_diff.py -- GH#275: reviewer-facing semantic summary of data/ edits.

ADVISORY ONLY: markdown for PR bodies / review dispatches, never a
required check. The summary is honest by construction: every change is
first computed by a generic deep diff, then domain renderers CLAIM diff
entries they know how to narrate -- whatever is left is listed verbatim
under "Unsummarized changes", so a schema the renderers don't know yet
(they will always trail the data) can never make a change invisible.

Scope rulings (docs/design/2026-07-26-dev-arch-eval-275-280.md #275):
  - combat-numerics domain DROPPED: scripts/harness_shard_diff.sh gives
    the stronger behavioral before/after for balance data; skills/
    classes/combatants edits surface via the unsummarized fallback.
  - portal-menu order is never simulated (the menu is code-built);
    portals.json / portal_menu_when deltas are FLAGGED and the re-pin
    carriers are named via derive_qa_surfaces --touching.
  - dialogue options are id-less array members: matching is positional,
    so a reworded option reads as remove+add -- stated, not hidden.

Usage:
  scripts/data_diff.py                     # working tree vs HEAD
  scripts/data_diff.py REF                 # working tree vs REF
  scripts/data_diff.py REF1 REF2           # REF2 vs REF1 (REF1 = base)
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from wi_data_lib import GAME_ROOT

REPO_ROOT = GAME_ROOT.parent
DATA_PREFIX = "wandering_inn_game/data/"
WORKTREE = "WORKTREE"

GATE_KEYS = ("requires", "hide_when", "present_when", "encounter_when",
	"door_when", "contains_when", "portal_menu_when", "fence_menu_when",
	"complete_when")


def _git(*args: str) -> str:
	return subprocess.run(["git", "-C", str(REPO_ROOT), *args],
		capture_output=True, text=True, check=True).stdout


def changed_files(base: str, target: str) -> list:
	if target == WORKTREE:
		out = _git("diff", "--name-only", base, "--", DATA_PREFIX)
	else:
		out = _git("diff", "--name-only", base, target, "--", DATA_PREFIX)
	return [line for line in out.splitlines() if line.endswith(".json")]


def load_version(ref: str, repo_path: str):
	if ref == WORKTREE:
		p = REPO_ROOT / repo_path
		return json.loads(p.read_text()) if p.is_file() else None
	try:
		return json.loads(_git("show", f"{ref}:{repo_path}"))
	except subprocess.CalledProcessError:
		return None  # file absent at this ref


# --- generic deep diff -------------------------------------------------------

def deep_diff(old, new, path: str = "") -> list:
	"""(path, kind, old, new) entries; kind in added/removed/changed.
	Dicts recurse by key; everything else (including lists) compares
	whole -- domain renderers re-interpret list-valued entries where an
	id/positional story is tellable."""
	entries: list = []
	if isinstance(old, dict) and isinstance(new, dict):
		for k in sorted(set(old) | set(new)):
			sub = f"{path}.{k}" if path else str(k)
			if k not in old:
				entries.append((sub, "added", None, new[k]))
			elif k not in new:
				entries.append((sub, "removed", old[k], None))
			else:
				entries.extend(deep_diff(old[k], new[k], sub))
	elif old != new:
		entries.append((path, "changed", old, new))
	return entries


def _fmt(v) -> str:
	# Backticks swapped out so a value can never open a code span / corrupt
	# the surrounding markdown; content itself is preserved by json.dumps.
	s = json.dumps(v, ensure_ascii=False).replace("`", "'")
	return s if len(s) <= 120 else s[:117] + "..."


# --- domain renderers --------------------------------------------------------
# A renderer may only CLAIM a top-level key when the container is
# well-shaped enough for its narration to be COMPLETE (all members dicts
# with unique ids). Otherwise the key stays unclaimed and the whole-list
# diff entry falls through to the raw listing -- the D5 invariant (a
# summary must never hide a change) is enforced by this gate, reviewed
# against constructed id-less/duplicate-id/non-dict counterexamples.

def _by_id(rows) -> dict:
	out = {}
	for row in rows or []:
		if isinstance(row, dict) and "id" in row:
			out[str(row["id"])] = row
	return out


def _rows_narratable(rows) -> bool:
	"""True iff every member is a dict with a unique id -- the precondition
	for _by_id narration being COMPLETE rather than best-effort."""
	if rows is None:
		return True
	if not isinstance(rows, list):
		return False
	ids = [r.get("id") for r in rows if isinstance(r, dict)]
	return (len(ids) == len(rows) and None not in ids
		and len(set(map(str, ids))) == len(ids))


def _nodes_narratable(nodes) -> bool:
	return isinstance(nodes, dict) and all(
		isinstance(v, dict) for v in nodes.values())


def render_map(map_id: str, old: dict, new: dict) -> list:
	lines: list = []
	old_ents, new_ents = _by_id(old.get("entities")), _by_id(new.get("entities"))
	for eid in sorted(set(old_ents) | set(new_ents)):
		if eid not in old_ents:
			e = new_ents[eid]
			extra = " **[door/portal wiring]**" if any(k in e for k in
				("portal_menu", "portal_menu_when", "door_when", "to_map")) else ""
			lines.append(f"- entity **{eid}** added at {e.get('cell')} "
				f"(kind {e.get('kind')}){extra}")
		elif eid not in new_ents:
			lines.append(f"- entity **{eid}** REMOVED")
		else:
			for p, kind, ov, nv in deep_diff(old_ents[eid], new_ents[eid]):
				top = p.split(".")[0]
				if top == "cell":
					lines.append(f"- entity **{eid}** moved {ov} -> {nv}")
				elif top in GATE_KEYS or top in ("portal_menu", "to_map", "to_cell"):
					lines.append(f"- entity **{eid}** GATING/WIRING `{p}` "
						f"{kind}: {_fmt(ov)} -> {_fmt(nv)}")
				elif top.startswith("_comment"):
					continue
				else:
					lines.append(f"- entity **{eid}** `{p}` {kind}: "
						f"{_fmt(ov)} -> {_fmt(nv)}")
	ob = {tuple(c) for c in old.get("blocked", [])}
	nb = {tuple(c) for c in new.get("blocked", [])}
	if ob != nb:
		if nb - ob:
			lines.append(f"- blocked cells ADDED: {sorted(nb - ob)}")
		if ob - nb:
			lines.append(f"- blocked cells UNBLOCKED: {sorted(ob - nb)}")
	elif old.get("blocked", []) != new.get("blocked", []):
		lines.append("- blocked list reordered/duplicate-collapsed (no cell delta)")
	if old.get("grid") != new.get("grid"):
		lines.append(f"- **grid changed** {old.get('grid')} -> {new.get('grid')}")
	return lines


def render_dialogue(name: str, old: dict, new: dict, shipped: set) -> list:
	lines: list = []
	if old.get("start") != new.get("start"):
		lines.append(f"- start node: {_fmt(old.get('start'))} -> {_fmt(new.get('start'))}")
	old_nodes, new_nodes = old.get("nodes", {}), new.get("nodes", {})
	for nid in sorted(set(old_nodes) | set(new_nodes)):
		if nid not in old_nodes:
			lines.append(f"- node **{nid}** added "
				f"({len(new_nodes[nid].get('options') or [])} option(s))")
			for eff in _effect_counters(new_nodes[nid]):
				lines.append(_counter_line(eff, shipped))
			continue
		if nid not in new_nodes:
			lines.append(f"- node **{nid}** REMOVED")
			continue
		on, nn = old_nodes[nid], new_nodes[nid]
		if on.get("text") != nn.get("text"):
			lines.append(f"- node **{nid}** text reworded")
		oo, no = on.get("options") or [], nn.get("options") or []
		if len(oo) != len(no):
			lines.append(f"- node **{nid}** option count {len(oo)} -> {len(no)} "
				"(positional matching below -- a reworded option reads as remove+add; "
				"**any script pinning this node's option list re-pins**)")
		for i in range(max(len(oo), len(no))):
			o = oo[i] if i < len(oo) else None
			n = no[i] if i < len(no) else None
			if o is None:
				lines.append(f"- node **{nid}** option[{i}] added: {_fmt(n.get('text'))}")
				for eff in n.get("effects", []) or []:
					if isinstance(eff, dict) and "accomplishment" in eff:
						lines.append(_counter_line(str(eff["accomplishment"]), shipped))
			elif n is None:
				lines.append(f"- node **{nid}** option[{i}] REMOVED: {_fmt(o.get('text'))}")
			else:
				for p, kind, ov, nv in deep_diff(o, n, f"option[{i}]"):
					leaf = p.split(".")[-1]
					if leaf.startswith("_comment"):
						continue
					tag = " GATING" if any(g in p for g in GATE_KEYS) else ""
					lines.append(f"- node **{nid}** `{p}`{tag} {kind}: "
						f"{_fmt(ov)} -> {_fmt(nv)}")
					if "effects" in p and isinstance(nv, list):
						for eff in nv:
							if isinstance(eff, dict) and "accomplishment" in eff:
								lines.append(_counter_line(str(eff["accomplishment"]), shipped))
		for p, kind, ov, nv in deep_diff(
				{k: v for k, v in on.items() if k not in ("options", "text")},
				{k: v for k, v in nn.items() if k not in ("options", "text")}):
			if not p.split(".")[0].startswith("_comment"):
				lines.append(f"- node **{nid}** `{p}` {kind}: {_fmt(ov)} -> {_fmt(nv)}")
	return lines


def _effect_counters(node: dict) -> list:
	out = []
	for opt in node.get("options", []) or []:
		for eff in opt.get("effects", []) or []:
			if isinstance(eff, dict) and "accomplishment" in eff:
				out.append(str(eff["accomplishment"]))
	return out


def _counter_line(counter: str, shipped: set) -> str:
	if counter in shipped:
		return f"  - writes counter `{counter}` (already shipped/frozen)"
	return (f"  - **NEW counter name `{counter}` (first write)** -- joins the "
		"freeze list at the next release cut; typo-check it now")


def render_id_catalog(name: str, key: str, old: dict, new: dict) -> list:
	"""quests/acts/bounties/deliveries/portals: id-keyed row lists."""
	lines: list = []
	old_rows, new_rows = _by_id(old.get(key)), _by_id(new.get(key))
	old_order = [r for r in ( [str(x.get('id')) for x in old.get(key, []) if isinstance(x, dict)] )]
	new_order = [r for r in ( [str(x.get('id')) for x in new.get(key, []) if isinstance(x, dict)] )]
	for rid in sorted(set(old_rows) | set(new_rows)):
		if rid not in old_rows:
			lines.append(f"- row **{rid}** added")
		elif rid not in new_rows:
			lines.append(f"- row **{rid}** REMOVED")
		else:
			for p, kind, ov, nv in deep_diff(old_rows[rid], new_rows[rid]):
				top = p.split(".")[0]
				if top.startswith("_comment"):
					continue
				tag = " GATING" if top in GATE_KEYS else ""
				lines.append(f"- row **{rid}** `{p}`{tag} {kind}: {_fmt(ov)} -> {_fmt(nv)}")
	shared = [r for r in old_order if r in new_rows]
	if shared != [r for r in new_order if r in old_rows]:
		lines.append("- **row ORDER changed among surviving ids** -- if this is "
			"portals.json, every portal-menu carrier re-pins")
	return lines


def touching_carriers(paths: list) -> list:
	try:
		out = subprocess.run(
			[sys.executable, str(GAME_ROOT / "scripts" / "derive_qa_surfaces.py"),
			 "--touching", ",".join(paths)],
			capture_output=True, text=True, check=True, cwd=str(REPO_ROOT))
		return out.stdout.split()
	except subprocess.CalledProcessError:
		return []


# --- driver ------------------------------------------------------------------

def summarize_file(rel: str, old, new, shipped: set) -> tuple:
	"""One file's markdown section. Returns (md_lines, unsummarized_count,
	portal_flagged). A renderer's top-level key is CLAIMED (excluded from
	the raw fallback) ONLY when the container passes its narratability
	gate -- D5: the summary must be structurally unable to hide a change."""
	md: list = [f"### {rel}"]
	if old is None:
		md.append("- **new file**")
		old = {}
	if new is None:
		md.append("- **file DELETED**")
		new = {}
	entries = [e for e in deep_diff(old, new)
		if not any(seg.startswith("_comment") for seg in e[0].split("."))]

	lines: list = []
	claimed: set = set()
	portal_flagged = False
	if rel.startswith("maps/"):
		claimed = {"blocked", "grid"}
		if _rows_narratable(old.get("entities")) and _rows_narratable(new.get("entities")):
			claimed.add("entities")
		else:
			lines.append("- **entities list has id-less/duplicate-id/non-dict "
				"members** -- structural narration unavailable; raw diff below")
		lines += render_map(Path(rel).stem, old, new)
		if any("portal_menu" in e[0] for e in entries):
			portal_flagged = True
	elif rel.startswith("dialogue/"):
		claimed = {"start"}
		if _nodes_narratable(old.get("nodes", {})) and _nodes_narratable(new.get("nodes", {})):
			claimed.add("nodes")
			lines += render_dialogue(Path(rel).stem, old, new, shipped)
		else:
			lines.append("- **nodes contains non-object members** -- structural "
				"narration unavailable; raw diff below")
			if old.get("start") != new.get("start"):
				lines.append(f"- start node: {_fmt(old.get('start'))} -> {_fmt(new.get('start'))}")
	elif rel in ("portals.json", "quests.json", "acts.json", "bounties.json", "deliveries.json"):
		key = Path(rel).stem
		if _rows_narratable(old.get(key)) and _rows_narratable(new.get(key)):
			claimed = {key}
			lines += render_id_catalog(rel, key, old, new)
		else:
			lines.append(f"- **{key} rows have id-less/duplicate-id/non-dict "
				"members** -- structural narration unavailable; raw diff below")
		if rel == "portals.json":
			portal_flagged = True

	if lines:
		md.extend(lines)
		md.append("")
	leftover = [e for e in entries if e[0].split(".")[0] not in claimed]
	if leftover:
		md.append(f"- **unsummarized changes ({len(leftover)})** -- outside "
			"every claimed key; raw listing:")
		for p, kind, ov, nv in leftover[:40]:
			md.append(f"  - `{p}` {kind}: {_fmt(ov)} -> {_fmt(nv)}")
		if len(leftover) > 40:
			md.append(f"  - ... {len(leftover) - 40} more")
		md.append("")
	elif not entries and not lines:
		md.append("- (whitespace/_comment-only change)")
		md.append("")
	return md, len(leftover), portal_flagged


def summarize(base: str, target: str) -> str:
	files = changed_files(base, target)
	target_label = "working tree" if target == WORKTREE else target
	md: list = [
		f"## data/ semantic diff -- {base} -> {target_label}",
		"",
		"*Advisory summary (GH#275). Positional option matching; combat "
		"numerics live in `harness_shard_diff.sh`, not here. The loudest "
		"callouts point at qa/ canonicals this tool cannot itself verify -- "
		"it prompts re-pins, it does not prove them.*",
		"",
	]
	if not files:
		md.append("No data/ changes.")
		return "\n".join(md)

	shipped_obj = load_version(target, DATA_PREFIX + "shipped_ids.json")
	if shipped_obj is None:
		md.append("*shipped_ids.json absent at the target ref -- every counter "
			"below reads as a first write; do not treat the NEW flags as "
			"typo signals for refs predating the freeze list.*")
		md.append("")
	shipped = set((shipped_obj or {}).get("accomplishments", []))

	portal_flagged: list = []
	unsummarized_total = 0
	for repo_path in files:
		rel = repo_path[len(DATA_PREFIX):]
		old = load_version(base, repo_path)
		new = load_version(target, repo_path)
		section, leftover_count, flagged = summarize_file(rel, old, new, shipped)
		md.extend(section)
		unsummarized_total += leftover_count
		if flagged:
			portal_flagged.append(repo_path)

	if portal_flagged:
		carriers = touching_carriers(portal_flagged)
		md.append("### Portal-menu impact")
		md.append("- portals.json / `portal_menu*` touched -> **option order on "
			"every carrier may shift; re-pin these canonicals** (derived via "
			"`derive_qa_surfaces --touching`, not simulated):")
		if carriers:
			for c in carriers:
				md.append(f"  - `{c}`")
		else:
			md.append("  - **carrier derivation unavailable/empty -- do NOT read "
				"this as 'no re-pin needed'; run derive_qa_surfaces --touching "
				"by hand (GH#281 never-silent rule)**")
		md.append("")
	if unsummarized_total:
		md.append(f"*{unsummarized_total} change(s) fell through to raw listings "
			"above -- extend a renderer only if the shape recurs.*")
	return "\n".join(md)


def main(argv: list) -> int:
	if len(argv) == 0:
		base, target = "HEAD", WORKTREE
	elif len(argv) == 1:
		base, target = argv[0], WORKTREE
	else:
		base, target = argv[0], argv[1]
	try:
		print(summarize(base, target))
	except subprocess.CalledProcessError as exc:
		print(f"data_diff: git failed for refs '{base}'/'{target}' -- "
			f"{(exc.stderr or '').strip() or exc}", file=sys.stderr)
		return 2
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
