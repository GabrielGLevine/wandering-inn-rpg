from __future__ import annotations

from typing import Any

from ..ledger import Ledger


class SleepError(RuntimeError):
    pass


class SleepPlanner:
    def __init__(self, bridge: Any) -> None:
        self.bridge = bridge

    def plan(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        preview = self.bridge.query("progression_preview", ledger)
        has_levels = bool(preview.get("class_gains") or preview.get("level_ups"))
        if "expect_levels" in spec and bool(spec["expect_levels"]) != has_levels:
            raise SleepError(f"{node_id} expect_levels={spec['expect_levels']} but oracle preview is {has_levels}: {preview}")
        consolidation = preview.get("consolidation", {})
        choice = spec.get("consolidation")
        if consolidation and choice not in ("accept", "decline"):
            raise SleepError(f"{node_id} would open an unplanned consolidation modal: {consolidation}")
        op = {"kind": "sleep", "preview": preview, "consolidation_choice": choice}
        ledger.apply_sleep_preview(preview)
        if consolidation and choice == "accept":
            parents = list(consolidation["parents"])
            for parent in parents:
                ledger.state["classes"].pop(str(parent), None)
            ledger.state["classes"][str(consolidation["target"])] = int(consolidation["level"])
            ledger.state["pending_consolidation"] = {}
        elif consolidation and choice == "decline":
            ledger.state["pending_consolidation"] = {}
        return [op]

