"""The quests.json join: which quest events an accomplishment drags behind it.

The 2026-08-13 M3.6 amendment (item 2) rules effect-derived event waits into
the dialogue planner, and the joins are half of what "derived" means. A chosen
option banks `resolved_the_cisterns`; the game answers with
`accomplishment_recorded`, and then -- because a started quest's beat was
waiting on exactly that counter -- with `quest_beat_completed` and possibly
`quest_completed`. All three are shipped claims in the corpus, and all three
come out of data the compiler already holds.

WHY THIS IS NOT A §0 VIOLATION. §0 forbids reimplementing SIM SEMANTICS -- the
questions whose answer depends on live sim state (what rows are visible, where
a walk can go, what a fight does). A quest beat is not one of those: it is a
pure function of `quests.json` and a counter table, evaluated by
`WIQuests.evaluate` with no world in scope, and the amendment names the join
explicitly. What that buys is a coupling this file owes a mirror-of note for:
the two functions below are `WIQuests.beat_index`/`_beat_met` and the emit
order in `WIGame._check_quests`, and if those move, these must.

Mirrors, by file and line:
  * `src/core/quests.gd` -- `_beat_met` (complete_when_any is an OR beside the
    complete_when AND; an empty AND means the beat closes only if the OR is
    also empty), `beat_index`, `evaluate`.
  * `src/core/wi_game.gd` -- `record_accomplishment` (the counter event fires
    BEFORE the quest check), `_check_quests` (beat first, then completion, both
    on the same tick, catalog order), `start_quest` (the started event fires,
    then progress is PRIMED from the counters as they already stand -- so a
    quest started on top of a satisfied beat emits no beat event for it).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .ledger import Ledger


class QuestJoin:
    def __init__(self, project: str | Path) -> None:
        catalog = json.loads((Path(project) / "data/quests.json").read_text(encoding="utf-8"))
        # Catalog ORDER is the emit order: `WIQuests.evaluate` builds its answer
        # by walking this array, and `_check_quests` walks that answer.
        self.quests: list[dict[str, Any]] = list(catalog.get("quests", []))
        self.by_id = {str(quest["id"]): quest for quest in self.quests}

    # ------------------------------------------------------------ evaluation --

    @staticmethod
    def _beat_met(beat: dict[str, Any], accomplishments: dict[str, Any]) -> bool:
        any_of = beat.get("complete_when_any", {}) or {}
        for key, amount in any_of.items():
            if int(accomplishments.get(key, 0)) >= int(amount):
                return True
        all_of = beat.get("complete_when", {}) or {}
        if not all_of:
            return not any_of
        return all(int(accomplishments.get(key, 0)) >= int(amount) for key, amount in all_of.items())

    def _beat_index(self, quest: dict[str, Any], accomplishments: dict[str, Any]) -> int:
        beats = quest.get("beats", [])
        for index, beat in enumerate(beats):
            if not self._beat_met(beat, accomplishments):
                return index
        return len(beats)

    def evaluate(self, ledger: Ledger) -> dict[str, dict[str, Any]]:
        accomplishments = ledger.state["accomplishments"]
        started = ledger.state["started_quests"]
        out: dict[str, dict[str, Any]] = {}
        for quest in self.quests:
            quest_id = str(quest["id"])
            if quest_id not in started:
                continue
            index = self._beat_index(quest, accomplishments)
            out[quest_id] = {"beat_index": index, "completed": index >= len(quest.get("beats", []))}
        return out

    def reprime(self, ledger: Ledger) -> None:
        """`WIGame.reprime_quests`: what a loaded save's progress starts at.

        An itinerary that opens on a fixture inherits its started quests, and
        without this every beat those quests had already closed would look like
        it closed again at the first accomplishment the run banks.
        """
        ledger.quest_progress = self.evaluate(ledger)

    # ------------------------------------------------------------ the events --

    def record(self, ledger: Ledger, accomplishment_id: str, amount: int = 1) -> list[dict[str, Any]]:
        """`record_accomplishment` + `_check_quests`, as a wait list."""
        ledger.accomplishment(accomplishment_id, amount)
        waits: list[dict[str, Any]] = [{
            "type": "accomplishment_recorded",
            "payload_contains": {
                "id": accomplishment_id,
                "count": int(ledger.state["accomplishments"][accomplishment_id]),
            },
        }]
        waits.extend(self.check(ledger))
        return waits

    def check(self, ledger: Ledger) -> list[dict[str, Any]]:
        if not ledger.state["started_quests"]:
            return []
        now = self.evaluate(ledger)
        waits: list[dict[str, Any]] = []
        for quest_id, progress in now.items():
            previous = ledger.quest_progress.get(quest_id, {"beat_index": 0, "completed": False})
            if progress["beat_index"] > int(previous["beat_index"]) and not progress["completed"]:
                waits.append({"type": "quest_beat_completed", "payload_contains": {"id": quest_id, "beat": progress["beat_index"]}})
            if progress["completed"] and not bool(previous["completed"]):
                waits.append({"type": "quest_beat_completed", "payload_contains": {"id": quest_id, "beat": progress["beat_index"]}})
                waits.append({"type": "quest_completed", "payload_contains": {"id": quest_id}})
        ledger.quest_progress = now
        return waits

    def start(self, ledger: Ledger, quest_id: str) -> list[dict[str, Any]]:
        """`start_quest`: the started event, then progress PRIMED not compared."""
        if quest_id in ledger.state["started_quests"]:
            return []
        ledger.state["started_quests"].append(quest_id)
        if quest_id in self.by_id:
            ledger.quest_progress[quest_id] = self.evaluate(ledger)[quest_id]
        return [{"type": "quest_started", "payload_contains": {"id": quest_id}}]
