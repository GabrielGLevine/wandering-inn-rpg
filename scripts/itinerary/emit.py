from __future__ import annotations

from copy import deepcopy
from typing import Any, Iterable


PANEL_SETTLE_FRAMES = 30
# combat_walkthrough/crate_fight/second_wind_loop all let the board finish
# tearing down before reading post-fight state; the banking itself is
# synchronous and earlier, so this is settle, not a race workaround.
COMBAT_SETTLE_FRAMES = 5
# `turn_started {id: pc}` and `combat_finished` are the two waits that span a
# whole AI playback, so they carry the corpus's longer ceilings rather than the
# 5s default every other wait uses.
TURN_TIMEOUT_SEC = 10
COMBAT_TIMEOUT_SEC = 20
# The sleep veil plays out before the epilogue can render, so the run's last
# two waits sit behind an animation rather than behind a frame.
EPILOGUE_TIMEOUT_SEC = 15
# `ui_map_rendered` is a presentation confirmation that arrives a beat after
# `map_changed`; the corpus gives it a frame budget rather than a wait.
MAP_RENDER_SETTLE_FRAMES = 10
# The corpus's album hold: long enough that a human watching a windowed run
# sees the frame the capture took. Under headless it is a no-op.
ALBUM_HOLD_FRAMES = 240

# ---------------------------------------------------------- creation UI --
# §8's ruling: the creation choreography is UI-cursor knowledge, so its layout
# constants live in the emitter beside the steps they shape rather than in an
# itinerary or a planner. All four are read off `src/ui/char_creation.gd` --
# PC_OPTIONS' row-major 2x3 grid, and the two setup prompts' option arrays --
# and §8 says to revisit them only when the creation UI itself changes.
CREATION_RACES = ("human", "drake", "gnoll")
CREATION_GENDERS = ("m", "f")
CREATION_DIFFICULTY_OPTIONS = ["Bronze Rank", "Silver Rank", "Gold Rank"]
CREATION_HINTS_OPTIONS = ["Yes", "No"]
# The 2026-07-07 rewrite made the GDI opener one race-neutral system readout;
# the race rides in the payload cosmetically.
GDI_OPENER_LINES = 4


class EmitError(RuntimeError):
    pass


class Emitter:
    def emit(self, node_id: str, operations: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
        emitted: list[dict[str, Any]] = []
        for operation in operations:
            steps = self._emit_operation(operation)
            # An op may name its OWN provenance -- detour nodes are planned
            # inside the node that needed them, but a failure in one must map
            # back to the detour, not to the purchase that pulled it in.
            stamp = str(operation.get("itin") or node_id)
            for step in steps:
                step["_itin"] = stamp
            if operation.get("note") and steps:
                steps[0]["_comment"] = str(operation["note"])
            emitted.extend(steps)
        return emitted

    def _emit_operation(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        steps: list[dict[str, Any]] = []
        kind = str(operation.get("kind", ""))
        if kind == "walk":
            steps.extend(deepcopy(operation["steps"]))
        elif kind == "face_target":
            steps.append({"action": "move", "direction": operation["direction"], "steps": 1})
        elif kind == "transition":
            steps.extend([
                {"action": "press", "name": "interact"},
                {"action": "wait_for_event", "type": "map_changed", "payload_contains": {"map": operation["map"], "cell": operation["cell"]}, "timeout_sec": 5},
                {"action": "assert_state", "path": "current_map", "equals": operation["map"]},
                {"action": "assert_state", "path": "player_cell", "equals": operation["cell"]},
            ])
        elif kind == "portal_transition":
            steps.extend([
                {"action": "press", "name": "interact"},
                {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": "portal_menu", "entity": operation["entity"]}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_dialogue_shown", "timeout_sec": 5},
            ])
            if int(operation["menu_index"]) > 1:
                steps.append({"action": "move", "direction": "down", "steps": int(operation["menu_index"]) - 1})
            steps.extend([
                {"action": "press", "name": "confirm"},
                {"action": "wait_for_event", "type": "dialogue_ended", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "map_changed", "payload_contains": {"map": operation["map"], "cell": operation["cell"]}, "timeout_sec": 5},
                {"action": "assert_state", "path": "current_map", "equals": operation["map"]},
                {"action": "assert_state", "path": "player_cell", "equals": operation["cell"]},
            ])
        elif kind == "pool_line":
            steps.extend([
                {"action": "press", "name": "interact"},
                {"action": "wait_for_event", "type": "dialogue_line", "payload_contains": {"speaker": operation["speaker"]}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_dialogue_rendered", "timeout_sec": 5},
                {"action": "wait_frames", "frames": PANEL_SETTLE_FRAMES},
            ])
        elif kind == "dialogue_open":
            steps.extend([
                {"action": "press", "name": "interact"},
                {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": operation["conversation"], "entity": operation["entity"]}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_dialogue_shown", "timeout_sec": 5},
            ])
        elif kind == "dialogue_choose":
            cursor = int(operation["cursor_index"])
            if cursor:
                steps.append({"action": "move", "direction": "down", "steps": cursor})
            confirm: dict[str, Any] = {"action": "press", "name": "confirm"}
            if operation.get("why"):
                confirm["_comment"] = f"CHOICE: {operation['why']}"
            steps.append(confirm)
            # WHERE the effect waits go is the engine's own order, not a
            # preference (`WIGame.dialogue_choose`): `choose()` emits
            # DIALOGUE_ENDED before returning, the owner then applies the
            # effects, and only then does it `advance()` to the next node. So
            # on a closing row the announcements land AFTER the teardown pair,
            # and on a continuing row they land BEFORE the destination. Get
            # this backwards and every wait sails past the since-cursor.
            effect_waits = [self._effect_wait(row) for row in operation.get("effect_waits", [])]
            if operation.get("hands_off_to_combat"):
                # The board replaces the panel: no teardown, no destination.
                steps.extend(effect_waits)
            elif operation.get("end"):
                steps.extend([
                    {"action": "wait_for_event", "type": "dialogue_ended", "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "ui_dialogue_hidden", "timeout_sec": 5},
                ])
                steps.extend(effect_waits)
                steps.append({"action": "wait_frames", "frames": PANEL_SETTLE_FRAMES})
            else:
                steps.extend(effect_waits)
                if operation.get("destination") and not operation.get("defer_destination"):
                    steps.append(self._destination_wait(operation.get("next_node", {})))
        elif kind == "dialogue_node_wait":
            # The deferred half of a `dialogue_choose`: used when engine
            # events (a purchase's gold/toast/item chain) land BETWEEN the
            # confirm and the destination node.
            steps.append(self._destination_wait(operation.get("next_node", {})))
        elif kind == "map_rendered":
            # The arrival's PRESENTATION half (M3.6 amendment item 3).
            # `map_changed` is the sim's claim; this is the one that says the
            # destination was drawn, and it is an assert rather than a wait
            # because the render is already behind the settle frames.
            steps.extend([
                {"action": "wait_frames", "frames": MAP_RENDER_SETTLE_FRAMES},
                {"action": "assert_event_logged", "type": "ui_map_rendered", "payload_contains": {"map": str(operation["map"])}},
            ])
        elif kind == "sleep":
            steps.extend(self._sleep_steps(operation))
        elif kind == "fixture_prelude":
            steps.extend(self._fixture_prelude_steps(operation))
        elif kind == "creation_prelude":
            steps.extend(self._creation_prelude_steps(operation))
        elif kind == "fight":
            steps.extend(self._fight_steps(operation))
        elif kind == "journal":
            steps.extend(self._journal_steps(operation))
        elif kind == "shot":
            steps.append({"action": "screenshot", "name": str(operation["name"])})
        elif kind == "assert_state":
            steps.append(self._assert_state_step(operation))
        elif kind == "assert_event":
            steps.append(self._event_assert_step("assert_event_logged", operation))
        elif kind == "assert_event_absent":
            steps.append(self._event_assert_step("assert_event_absent", operation))
        elif kind == "inventory_open":
            steps.extend([
                {"action": "press", "name": "inventory"},
                {"action": "wait_for_event", "type": "ui_inventory_shown", "timeout_sec": 5},
            ])
        elif kind == "inventory_cursor":
            cursor = int(operation["cursor_index"])
            if cursor:
                steps.append({"action": "move", "direction": "down", "steps": cursor})
            steps.append({
                "action": "wait_for_event", "type": "ui_inventory_selection_rendered",
                "payload_contains": {"cursor": cursor, "item": str(operation["item"])}, "timeout_sec": 5,
            })
        elif kind == "inventory_equip":
            steps.extend([
                {"action": "press", "name": "confirm"},
                {"action": "wait_for_event", "type": "item_equipped", "payload_contains": {"item": str(operation["item"]), "slot": str(operation["slot"])}, "timeout_sec": 5},
                {"action": "assert_state", "path": f"equipped.{operation['slot']}", "equals": str(operation["item"])},
            ])
        elif kind == "inventory_unequip":
            # ITEM_UNEQUIPPED carries only {slot} -- no item id -- so the
            # state assert is what proves WHICH slot cleared.
            steps.extend([
                {"action": "press", "name": "confirm"},
                {"action": "wait_for_event", "type": "item_unequipped", "payload_contains": {"slot": str(operation["slot"])}, "timeout_sec": 5},
                {"action": "assert_state", "path": f"equipped.{operation['slot']}", "equals": ""},
            ])
        elif kind == "inventory_close":
            steps.extend([
                {"action": "press", "name": "inventory"},
                {"action": "wait_for_event", "type": "ui_inventory_hidden", "timeout_sec": 5},
            ])
        elif kind == "field_skill":
            steps.extend(self._field_skill_steps(operation))
        elif kind == "prop_interact":
            steps.extend(self._prop_interact_steps(operation))
        elif kind == "purchase":
            steps.extend(self._purchase_steps(operation))
        elif kind == "sell_open":
            steps.extend([
                {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": str(operation["conversation"]), "entity": str(operation["entity"])}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_dialogue_shown", "timeout_sec": 5},
            ])
        elif kind == "sale":
            steps.extend(self._sale_steps(operation))
        elif kind == "raw":
            steps.extend(deepcopy(operation["steps"]))
        else:
            raise EmitError(f"unknown semantic operation: {kind}")
        return steps

    # ------------------------------------------------------------ M2 shapes --

    def _fixture_prelude_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """Drive the title to CONTINUE so the seeded fixture is what loads.

        This is UI-cursor knowledge, not world knowledge, so it lives here as a
        fixed prelude (§8's ruling for the creation choreography, same class).
        It is required, not optional: the driver's own `_skip_title` presses
        confirm twice and starts a NEW GAME, which would discard the fixture
        entirely and run the itinerary against a blank sim.
        """
        return [
            {"action": "wait_for_event", "type": "ui_title_gate_rendered", "timeout_sec": 5},
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_title_rendered", "timeout_sec": 5},
            {"action": "move", "direction": "down", "steps": 1},
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "game_loaded", "timeout_sec": 5},
            {"action": "wait_for_event", "type": "world_ready", "timeout_sec": 5},
            {"action": "assert_state", "path": "current_map", "equals": str(operation["map"])},
            {"action": "assert_state", "path": "player_cell", "equals": list(operation["cell"])},
        ]

    def _fight_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        if str(operation.get("mode", "autoplay")) == "driven":
            return self._driven_fight_steps(operation)
        steps: list[dict[str, Any]] = []
        steps.extend(self._board_opens(operation))
        beats = operation.get("beats", {})
        for name in beats.get("before_turn", []):
            steps.append(self._beat_wait(name))
        if operation.get("turn_wait", True):
            # Six of the twelve shipped fights carry no `turn_started` wait
            # (M3.6 amendment item 3): the autoplay step waits for the board to
            # hand it a turn anyway, so the wait is a pin on WHOSE turn opens,
            # not a synchronisation the run needs. Where a fight has an ally,
            # or a shot that must land on the PC's own turn, it matters -- and
            # `turn_wait: false` is how a fight without one says so.
            steps.append({"action": "wait_for_event", "type": "turn_started", "payload_contains": {"id": "pc"}, "timeout_sec": TURN_TIMEOUT_SEC})
        for name in operation.get("shots", []):
            steps.append({"action": "screenshot", "name": str(name)})
        steps.extend([
            {"action": "combat_autoplay", "max_turns": int(operation["max_turns"]), "policy": str(operation["policy"])},
            {"action": "wait_for_event", "type": "combat_finished", "payload_contains": {"victory": True}, "timeout_sec": COMBAT_TIMEOUT_SEC},
        ])
        for name in beats.get("after_combat", []):
            steps.append(self._beat_wait(name))
        steps.extend(self._board_closes(operation))
        return steps

    def _board_opens(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """How the board arrives -- the emitter's promise in every fight mode."""
        steps: list[dict[str, Any]] = []
        if operation.get("entry", "interact") == "interact":
            steps.append({"action": "press", "name": "interact"})
        started: dict[str, Any] = {"action": "wait_for_event", "type": "combat_started", "timeout_sec": 5}
        arena = str(operation.get("arena", ""))
        if arena:
            # A payload-tight `combat_started` (M3.6 amendment item 3): the
            # shipped warden pins its arena, and an unpinned wait is a LOOSER
            # claim than the corpus makes rather than a different one.
            started["payload_contains"] = {"arena": arena}
        steps.extend([started, {"action": "wait_for_event", "type": "ui_combat_shown", "timeout_sec": 5}])
        for ally in operation.get("allies", []):
            steps.append({"action": "assert_state", "path": f"combat.combatants.{ally}.side", "equals": "player"})
        return steps

    def _board_closes(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """The dismiss, the banking window it opens, and the victory pins.

        `resolve_combat()` runs ON the dismiss press, not at `combat_finished`,
        so an encounter's `on_victory` deposits land BETWEEN this confirm and
        `ui_combat_hidden`. Before M3.6 the emitter only ever read them as
        state afterwards, which is true but weaker -- it cannot tell a counter
        that banked here from one that banked three nodes ago.
        """
        steps: list[dict[str, Any]] = [{"action": "press", "name": "confirm"}]
        for row in operation.get("banks_after_dismiss", []):
            steps.append(self._effect_wait(row))
        steps.extend([
            {"action": "wait_for_event", "type": "ui_combat_hidden", "timeout_sec": 5},
            {"action": "wait_frames", "frames": COMBAT_SETTLE_FRAMES},
        ])
        for pin in operation.get("victory_pins", []):
            steps.append(self._assert_state_step(pin))
        return steps

    @staticmethod
    def _beat_wait(name: str) -> dict[str, Any]:
        return {
            "action": "wait_for_event", "type": "ui_tutor_line_rendered",
            "payload_contains": {"beat": str(name)}, "timeout_sec": 5,
        }

    # -------------------------------------------------------- M3.5 shapes --

    def _driven_fight_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """A fight whose opening turns are played by hand (2026-08-13 §3.2).

        The emitter keeps the three things that are ITS promise in every fight
        -- how the board opens, that the run dismisses the result banner before
        pressing anything else, and that the win is pinned -- and hands the
        author everything between. That split is what makes the turn list
        exact-class in a golden: the frame it sits inside is fixed, so a
        difference inside it is a difference in the choreography and nothing
        else.
        """
        steps: list[dict[str, Any]] = self._board_opens(operation)
        for entry in operation.get("turns", []):
            steps.extend(self._turn_steps(entry, operation))
        # Same tail as an autoplayed fight, and for the same reason: the result
        # banner eats the next press until it is dismissed.
        steps.extend(self._board_closes(operation))
        return steps

    def _turn_steps(self, entry: dict[str, Any], operation: dict[str, Any]) -> list[dict[str, Any]]:
        if "press" in entry:
            return [{"action": "press", "name": str(entry["press"])}]
        if "beat" in entry:
            # The tutor line is the reason driven mode exists: `combat_tutor`
            # fires one per teaching moment, in order, and an autoplayed board
            # skips the moments instead of failing on them.
            return [{
                "action": "wait_for_event", "type": "ui_tutor_line_rendered",
                "payload_contains": {"beat": str(entry["beat"])}, "timeout_sec": 5,
            }]
        if "await" in entry:
            step: dict[str, Any] = {"action": "wait_for_event", "type": str(entry["await"]), "timeout_sec": 5}
            where = entry.get("where") or {}
            if where:
                step["payload_contains"] = deepcopy(where)
            return [step]
        if "logged" in entry:
            return [self._event_assert_step(
                "assert_event_logged", {"type": entry["logged"], "payload_contains": entry.get("where") or {}}
            )]
        if "pin" in entry:
            return [self._assert_state_step(entry["pin"])]
        if "settle" in entry:
            return [{"action": "wait_frames", "frames": int(entry["settle"])}]
        if "shot" in entry:
            return [{"action": "screenshot", "name": str(entry["shot"])}]
        if "autoplay" in entry:
            # The handover: everything after this is the policy's. The victory
            # wait rides with it so `expect: victory` stays the emitter's claim
            # and not something a turn list can forget to make.
            return [
                {"action": "combat_autoplay", "max_turns": int(operation["max_turns"]), "policy": str(operation["policy"])},
                {"action": "wait_for_event", "type": "combat_finished", "payload_contains": {"victory": True}, "timeout_sec": COMBAT_TIMEOUT_SEC},
            ]
        raise EmitError(f"unknown driven-turn entry: {sorted(entry)}")

    def _journal_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """Open the book, optionally capture it, close it (2026-08-13 §3.2).

        A journal beat has NO world effect -- it banks nothing, moves nothing,
        and draws no rng -- which is exactly why it needed a primitive rather
        than a planner: there is nothing here for a planner to decide. What it
        does have is a panel, and a panel left open eats the next press, so the
        close is the emitter's and not the author's.
        """
        shown: dict[str, Any] = {"action": "wait_for_event", "type": "ui_journal_shown", "timeout_sec": 5}
        act = str(operation.get("act", ""))
        if act:
            shown["payload_contains"] = {"act_id": act}
        steps: list[dict[str, Any]] = [{"action": "press", "name": "journal"}, shown]
        capture = str(operation.get("capture", ""))
        if capture:
            steps.append({"action": "screenshot", "name": capture})
        steps.extend([
            {"action": "press", "name": "journal"},
            {"action": "wait_for_event", "type": "ui_journal_hidden", "timeout_sec": 5},
        ])
        return steps

    def _creation_prelude_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """Drive the title gate through character creation into the world (§8).

        §8 rules this UI-cursor knowledge rather than world knowledge, so it
        lives here as a fixed prelude keyed by `creation:` scalars, the same
        class as `fixture_prelude`. What varies is which card the picker lands
        on and what the confirmation pins; the CHOREOGRAPHY -- gate, menu, pick,
        name, difficulty, hints -- is the screen's, not the itinerary's.

        The picker is PC_OPTIONS' own 2x3 row-major grid (`char_creation.gd`):
        column from the race order, row from the gender, so the cursor is
        `row * 3 + col` and the tap index the driver takes is that plus one
        (`test_driver.gd` calls `card_rect(card_n - 1)`).
        """
        races = list(operation.get("races", CREATION_RACES))
        genders = list(operation.get("genders", CREATION_GENDERS))
        race, gender = str(operation["race"]), str(operation["gender"])
        if race not in races or gender not in genders:
            raise EmitError(f"creation: {race}/{gender} is not a card on the picker grid")
        cursor = genders.index(gender) * len(races) + races.index(race)
        sprite = f"pc_{race}_{gender}"
        shots = operation.get("shots", {})
        steps: list[dict[str, Any]] = [
            {"action": "wait_for_event", "type": "ui_title_gate_rendered", "timeout_sec": 5}
        ]
        steps.extend(self._album(shots.get("gate")))
        steps.extend([
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_title_rendered", "timeout_sec": 5},
        ])
        steps.extend(self._album(shots.get("menu")))
        steps.extend([
            # New Game, not Continue: the second row is the fixture path.
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_char_creation_rendered", "payload_contains": {"step": "pick"}, "timeout_sec": 5},
        ])
        if cursor % len(races):
            steps.append({"action": "move", "direction": "right", "steps": cursor % len(races)})
        if cursor // len(races):
            steps.append({"action": "move", "direction": "down", "steps": cursor // len(races)})
        steps.extend(self._album(shots.get("picker")))
        steps.extend([
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_char_creation_rendered", "payload_contains": {"step": "name"}, "timeout_sec": 5},
        ])
        if operation.get("tap_back", False):
            # The mouse-click round trip: Esc backs up to PICK re-highlighting
            # the card just confirmed, and a TAP on that same card re-commits
            # it. Coverage for the pointer path, which the keyboard route
            # never exercises -- and the reason the card index is derived
            # rather than written down.
            steps.extend([
                {"action": "press", "name": "cancel"},
                {"action": "wait_for_event", "type": "ui_char_creation_rendered", "payload_contains": {"step": "pick"}, "timeout_sec": 5},
                {"action": "click_char_creation_card", "card": cursor + 1},
                {"action": "wait_for_event", "type": "ui_char_creation_rendered", "payload_contains": {"step": "name"}, "timeout_sec": 5},
            ])
        steps.append({"action": "type_text", "text": str(operation["name"])})
        steps.extend(self._album(shots.get("name")))
        steps.extend([
            # The NAME step no longer commits (#106/#346): two setup prompts
            # follow it, and this control reads Continue.
            {"action": "click_char_creation_begin"},
            {"action": "wait_for_event", "type": "ui_char_creation_rendered",
             "payload_contains": {"step": "difficulty", "options": list(operation.get("difficulty_options", CREATION_DIFFICULTY_OPTIONS)), "cursor": int(operation["difficulty_step"])},
             "timeout_sec": 5},
        ])
        steps.extend(self._album(shots.get("difficulty")))
        steps.extend([
            # Both setup prompts OPEN ON THE LIVE SETTING (#346/#338), so the
            # cursor is already where the itinerary asked for and confirm takes
            # the row it is on. A prelude that walked the cursor would be
            # asserting the default rather than reading it.
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_char_creation_rendered",
             "payload_contains": {"step": "hints", "options": list(operation.get("hints_options", CREATION_HINTS_OPTIONS)), "cursor": 0 if operation["hints"] else 1},
             "timeout_sec": 5},
        ])
        steps.extend(self._album(shots.get("hints")))
        steps.extend([
            {"action": "click_char_creation_card", "card": 1 if operation["hints"] else 2},
            {"action": "wait_for_event", "type": "ui_char_creation_confirmed", "payload_contains": {
                "pc_name": str(operation["name"]), "pc_race": race, "pc_gender": gender,
                "difficulty_step": int(operation["difficulty_step"]), "quest_hints": bool(operation["hints"]),
            }, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "world_ready", "timeout_sec": 5},
            {"action": "wait_for_event", "type": "ui_gdi_opener_rendered", "payload_contains": {"lines": int(operation.get("opener_lines", GDI_OPENER_LINES)), "race": race}, "timeout_sec": 5},
            {"action": "assert_state", "path": "pc_name", "equals": str(operation["name"])},
            {"action": "assert_state", "path": "pc_race", "equals": race},
            {"action": "assert_state", "path": "pc_gender", "equals": gender},
            {"action": "assert_state", "path": "pc_sprite", "equals": sprite},
            # The RENDERED binding, not just the sim field: `from_start` because
            # world.gd draws the entities before this prelude's cursor exists.
            {"action": "wait_for_event", "type": "ui_entities_rendered", "payload_contains": {"pc_sprite": sprite}, "from_start": True, "timeout_sec": 5},
        ])
        steps.extend(self._album(shots.get("world")))
        return steps

    @staticmethod
    def _album(name: Any) -> list[dict[str, Any]]:
        """An album beat: the capture and the hold that lets a human see it."""
        if not name:
            return []
        return [{"action": "screenshot", "name": str(name)}, {"action": "wait_frames", "frames": ALBUM_HOLD_FRAMES}]

    def _field_skill_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        payload: dict[str, Any] = {"skill": str(operation["skill"])}
        if operation.get("target"):
            payload["target"] = str(operation["target"])
        else:
            payload["context"] = "exploration"
        steps: list[dict[str, Any]] = [
            # press_field_skill resolves the hotbar slot from the live bar --
            # never hand-press hotbar_N, the index is equipment-dependent.
            {"action": "press_field_skill", "skill": str(operation["skill"])},
            {"action": "wait_for_event", "type": "skill_used", "payload_contains": payload, "timeout_sec": 5},
        ]
        sneak = str(operation.get("sneak", ""))
        if sneak:
            # A stance cast, not a working: `_toggle_sneak` emits SKILL_USED,
            # then the lifetime edge, then its own line. There is no
            # `ui_toast_rendered` here on purpose -- the claim is the domain
            # event and the authored copy, not that a toast widget drew.
            steps.extend([
                {"action": "wait_for_event", "type": f"sneak_{'started' if sneak == 'start' else 'ended'}", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "toast",
                 "payload_contains": {"text": "You soften your step." if sneak == "start" else "You straighten up."},
                 "timeout_sec": 5},
            ])
            return steps
        if operation.get("accomplishment"):
            steps.append({"action": "wait_for_event", "type": "accomplishment_recorded", "payload_contains": {"id": str(operation["accomplishment"])}, "timeout_sec": 5})
        steps.append({"action": "wait_for_event", "type": "ui_toast_rendered", "timeout_sec": 5})
        return steps

    def _prop_interact_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        steps: list[dict[str, Any]] = [{"action": "press", "name": "interact"}]
        if operation.get("accomplishment"):
            steps.append({"action": "wait_for_event", "type": "accomplishment_recorded", "payload_contains": {"id": str(operation["accomplishment"]), "count": int(operation["count"])}, "timeout_sec": 5})
        if operation.get("toast"):
            steps.append({"action": "wait_for_event", "type": "toast", "payload_contains": {"text": str(operation["toast"])}, "timeout_sec": 5})
        steps.append({"action": "wait_for_event", "type": "ui_toast_rendered", "timeout_sec": 5})
        return steps

    def _purchase_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        # Emission order is the engine's, not a preference: spend_gold emits
        # gold_changed BEFORE the "Paid N gold." toast, and the item grant
        # lands after both.
        gold_payload: dict[str, Any] = {"delta": -int(operation["price"]), "source": str(operation["conversation"])}
        if operation.get("total") is not None:
            gold_payload["total"] = int(operation["total"])
        return [
            {"action": "wait_for_event", "type": "gold_changed", "payload_contains": gold_payload, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "toast", "payload_contains": {"text": f"Paid {int(operation['price'])} gold."}, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "item_gained", "payload_contains": {"item": str(operation["item"])}, "timeout_sec": 5},
        ]

    def _sale_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        # sell_item removes the item FIRST (item_lost), then pays (gold_changed
        # + "Earned N gold."), then banks deliberate_commerce.
        gold_payload: dict[str, Any] = {"delta": int(operation["price"]), "source": str(operation["conversation"])}
        if operation.get("total") is not None:
            gold_payload["total"] = int(operation["total"])
        return [
            {"action": "wait_for_event", "type": "item_lost", "payload_contains": {"item": str(operation["item"]), "source": str(operation["conversation"])}, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "gold_changed", "payload_contains": gold_payload, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "toast", "payload_contains": {"text": f"Earned {int(operation['price'])} gold."}, "timeout_sec": 5},
        ]

    @staticmethod
    def _effect_wait(row: dict[str, Any]) -> dict[str, Any]:
        """One planner-derived announcement, as a wait (M3.6 amendment item 2)."""
        step: dict[str, Any] = {"action": "wait_for_event", "type": str(row["type"]), "timeout_sec": 5}
        payload = row.get("payload_contains") or {}
        if payload:
            step["payload_contains"] = deepcopy(payload)
        return step

    @staticmethod
    def _destination_wait(next_node: dict[str, Any]) -> dict[str, Any]:
        payload = {key: value for key, value in next_node.items() if value != ""}
        wait: dict[str, Any] = {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5}
        if payload:
            wait["payload_contains"] = payload
        return wait

    @staticmethod
    def _assert_state_step(operation: dict[str, Any]) -> dict[str, Any]:
        step: dict[str, Any] = {"action": "assert_state", "path": str(operation["path"])}
        if "contains" in operation:
            step["contains"] = deepcopy(operation["contains"])
        elif "equals" in operation:
            step["equals"] = deepcopy(operation["equals"])
        else:
            raise EmitError(f"assert_state on {operation['path']!r} needs equals or contains")
        return step

    @staticmethod
    def _event_assert_step(action: str, operation: dict[str, Any]) -> dict[str, Any]:
        step: dict[str, Any] = {"action": action, "type": str(operation["type"])}
        payload = operation.get("payload_contains") or {}
        if payload:
            step["payload_contains"] = deepcopy(payload)
        return step

    def _sleep_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        preview = operation["preview"]
        steps: list[dict[str, Any]] = [
            {"action": "press", "name": "interact"},
            {"action": "wait_for_event", "type": "phase_changed", "payload_contains": {"slept": True}, "timeout_sec": 5},
        ]
        for class_id in preview.get("class_gains", []):
            steps.append({"action": "wait_for_event", "type": "class_gained", "payload_contains": {"class": class_id}, "timeout_sec": 5})
        for gain in preview.get("level_ups", []):
            steps.append({"action": "wait_for_event", "type": "class_level_up", "payload_contains": {"class": gain["class"], "level": gain["level"]}, "timeout_sec": 5})
        # #472: consolidation APPLIES inside the sleep beat -- no offer, no modal,
        # no press. The merge event therefore lands strictly BEFORE the veil
        # renders, and wait_for_event's cursor is forward-only, so this order is
        # itself the beat-order pin.
        consolidation = preview.get("consolidation", {})
        if consolidation:
            steps.extend([
                {"action": "wait_for_event", "type": "consolidation_accepted", "payload_contains": {"target": consolidation["target"], "level": consolidation["level"]}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_sleep_veil_rendered", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_sleep_veil_finished", "timeout_sec": 5},
                {"action": "assert_state", "path": "classes", "equals": preview["classes_after"]},
            ])
        else:
            steps.extend([
                {"action": "wait_for_event", "type": "ui_sleep_veil_rendered", "timeout_sec": 5},
                # The retired `pending_consolidation` pin said "no merge is
                # queued". Its replacement says the stronger thing directly: no
                # merge HAPPENED on this sleep.
                {"action": "assert_event_absent", "type": "consolidation_accepted"},
                {"action": "assert_state", "path": "classes", "equals": preview["classes_after"]},
            ])
        if operation.get("epilogue"):
            # The run's last claim (M3.6 amendment item 3): the GDI epilogue is
            # an observer beat with no world effect, the same class as a
            # `journal` read, and it is what makes the final sleep the END of a
            # playthrough rather than one more night. Both waits carry the
            # veil's own long ceiling -- the epilogue renders behind a full
            # sleep animation, not behind a frame.
            if not any(str(step.get("type", "")) == "ui_sleep_veil_finished" for step in steps):
                steps.append({"action": "wait_for_event", "type": "ui_sleep_veil_finished", "timeout_sec": EPILOGUE_TIMEOUT_SEC})
            steps.append({"action": "wait_for_event", "type": "ui_gdi_epilogue_rendered", "timeout_sec": EPILOGUE_TIMEOUT_SEC})
        return steps
