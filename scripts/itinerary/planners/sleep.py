from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..ledger import Ledger


# GH#167: `_maybe_fire_tremor_pointer` -- the pointer's three claims are fixed text.
TREMOR_QUEST = "something_beneath"
TREMOR_TOAST = "A Watch runner is looking for you."

class SleepError(RuntimeError):
    pass


class SleepPlanner:
    def __init__(self, bridge: Any, project: str | Path | None = None) -> None:
        self.bridge = bridge
        # #434 Act II: the class-gained toast is DERIVABLE (sleep_beat.gd
        # `_class_gained_toast`: "[Name] class gained! — [Skill], ..." over the
        # level-1 grants), so the sleep op carries it when the catalogs are at
        # hand; the unit harness passes no project and pins nothing.
        self.class_names: dict[str, str] = {}
        self.level1_grants: dict[str, list[str]] = {}
        self.skill_names: dict[str, str] = {}
        if project is not None:
            root = Path(project)
            classes = json.loads((root / "data/classes.json").read_text(encoding="utf-8"))
            for row in classes.get("classes", []):
                cid = str(row.get("id", ""))
                self.class_names[cid] = str(row.get("display_name", cid))
                self.level1_grants[cid] = [str(g) for lv in row.get("levels", []) if int(lv.get("level", 0)) == 1 for g in lv.get("grants", [])]
            skills = json.loads((root / "data/skills.json").read_text(encoding="utf-8"))
            for row in skills.get("skills", []):
                self.skill_names[str(row.get("id", ""))] = str(row.get("display_name", row.get("id", "")))

    def class_gained_toast(self, class_id: str) -> str | None:
        if class_id not in self.class_names:
            return None
        base = f"[{self.class_names[class_id]}] class gained!"
        names = [self.skill_names.get(g, g) for g in self.level1_grants.get(class_id, [])]
        return base if not names else f"{base} — {', '.join(names)}"

    def plan(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        preview = self.bridge.query("progression_preview", ledger)
        has_levels = bool(preview.get("class_gains") or preview.get("level_ups"))
        if "expect_levels" in spec and bool(spec["expect_levels"]) != has_levels:
            raise SleepError(f"{node_id} expect_levels={spec['expect_levels']} but oracle preview is {has_levels}: {preview}")
        # #472: there is no modal and no choice. A qualifying sleep MERGES, so the
        # plan's job is to declare the merge it expects rather than to answer for
        # it. `expect_merge` mirrors `expect_levels`: state it and it is checked,
        # omit it and the preview simply governs.
        consolidation = preview.get("consolidation", {})
        expected = spec.get("expect_merge")
        if expected is not None:
            if not consolidation:
                raise SleepError(f"{node_id} expect_merge={expected} but the oracle previews no merge: {preview}")
            actual = {"target": str(consolidation["target"]), "level": int(consolidation["level"])}
            if expected != actual:
                raise SleepError(f"{node_id} expect_merge={expected} but the oracle previews {actual}")
        merge = ({"target": str(consolidation["target"]), "level": int(consolidation["level"])}
            if consolidation else None)
        op = {"kind": "sleep", "preview": preview, "merge": merge, "epilogue": bool(spec.get("expect_epilogue", False))}
        toasts = {cid: self.class_gained_toast(str(cid)) for cid in preview.get("class_gains", [])}
        op["class_gained_toasts"] = {cid: text for cid, text in toasts.items() if text}
        if spec.get("expect_veil_lines") is not None:
            op["expect_veil_lines"] = int(spec["expect_veil_lines"])
        # apply_sleep_preview alone: `classes_after` already carries the merge.
        ledger.apply_sleep_preview(preview)
        # sleep_beat.gd past the level chain: the two-class bank, then the
        # tremor pointer (GH#167) -- an accomplishment, a quest start, and a
        # sticky toast, in that order, all before the veil renders.
        if preview.get("reached_two_classes") and int(ledger.state["accomplishments"].get("reached_two_classes", 0)) < 1:
            ledger.accomplishment("reached_two_classes")
        op["tremor_pointer"] = bool(preview.get("tremor_pointer", False))
        if op["tremor_pointer"]:
            ledger.accomplishment("watch_runner_pointed")
            if TREMOR_QUEST not in ledger.state["started_quests"]:
                ledger.state["started_quests"].append(TREMOR_QUEST)
        return [op]

