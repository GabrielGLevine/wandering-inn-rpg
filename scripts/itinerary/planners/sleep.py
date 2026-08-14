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
        # apply_sleep_preview alone: `classes_after` already carries the merge.
        ledger.apply_sleep_preview(preview)
        return [op]

