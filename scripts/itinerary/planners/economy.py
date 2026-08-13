from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

from ..detours import DetourLibrary
from ..ledger import Ledger
from ..schema import Node
from .dialogue import DialoguePlanner
from .route import RoutePlanner


class EconomyError(RuntimeError):
    pass


class EconomyPlanner:
    """Purchases, sales, and the earn-detours that make a purchase possible.

    The interval discipline is the whole point (§2.3). Gold is not a number
    here, it is a range: a 50% loot drop parts its ends, and a purchase is
    only plannable when the LOW end covers the price. When it does not, an
    earn-detour is spliced in from the registered library and the reason is
    stamped into the emitted script as a GOLD/PACING note, so the pacing
    decision is reviewable instead of invisible.
    """

    def __init__(
        self,
        project: str | Path,
        bridge: Any,
        route: RoutePlanner,
        dialogue: DialoguePlanner,
        library: DetourLibrary,
    ) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.route = route
        self.dialogue = dialogue
        self.library = library
        # Set by the compiler after construction: planning a detour means
        # planning ordinary nodes, which only the node dispatcher can do.
        self.plan_node: Callable[[Node, Ledger], list[dict[str, Any]]] | None = None
        self.used_detours: set[str] = set()
        self.notes: list[str] = []
        # Every earn-detour this compile SPLICED IN, with the number that made
        # it necessary. Pass 2 re-reads these against the harvested gold and
        # flags the ones a real run proved unnecessary (§2.3).
        self.insertions: list[dict[str, Any]] = []

    # ------------------------------------------------------------------ buy --

    def plan_buy(self, node_id: str, spec: dict[str, Any], why: str, ledger: Ledger) -> list[dict[str, Any]]:
        vendor_id = str(spec["vendor"])
        item_id = str(spec["item"])
        map_hint = str(spec.get("at", "")) or None
        map_id, entity = self.route.find_entity(vendor_id, map_hint)
        graph_id = str(entity.get("conversation", ""))
        if not graph_id or graph_id not in self.dialogue.graphs:
            raise EconomyError(f"{node_id}: vendor {vendor_id} has no file-backed conversation")

        ops: list[dict[str, Any]] = []
        asking = self._asking_price(node_id, graph_id, item_id)
        if ledger.gold_min < asking:
            ops.extend(self._earn_detour(node_id, ledger, asking - ledger.gold_min, asking, item_id))

        talk_spec = {"npc": vendor_id, "at": map_id, "choose_path": list(spec.get("choose_path", []))}
        before = ledger.gold_interval
        ops.extend(self.dialogue.plan(node_id, talk_spec, why, ledger, entity, map_id))
        price = before[0] - ledger.gold_interval[0]
        if price <= 0:
            raise EconomyError(
                f"{node_id}: choose_path bought nothing -- gold interval went {before} -> {ledger.gold_interval}. "
                "The last anchor must be the priced row itself."
            )
        if item_id not in ledger.state["inventory"]:
            raise EconomyError(f"{node_id}: choose_path did not grant {item_id}")
        return self._splice_transaction(node_id, ops, item_id, {
            "kind": "purchase",
            "price": price,
            "item": item_id,
            "conversation": graph_id,
            # `total` is the sim's resulting gold. It is only knowable while
            # the interval is a POINT; downstream of a chance-gated loot roll
            # it is fiction, so the pin drops to the delta alone (§5: pass 1
            # loosens the risky half, pass 2 tightens it from a real run).
            "total": ledger.gold_interval[0] if ledger.gold_certain else None,
        })

    # ----------------------------------------------------------------- sell --

    def plan_sell(self, node_id: str, spec: dict[str, Any], why: str, ledger: Ledger) -> list[dict[str, Any]]:
        vendor_id = str(spec["vendor"])
        item_id = str(spec["item"])
        map_hint = str(spec.get("at", "")) or None
        map_id, entity = self.route.find_entity(vendor_id, map_hint)
        if item_id not in ledger.state["inventory"]:
            raise EconomyError(f"{node_id}: {item_id} is not carried, so it cannot be sold")
        if item_id in ledger.state["equipped"].values():
            raise EconomyError(f"{node_id}: {item_id} is equipped -- sellable_items() skips worn gear")

        anchors = list(spec.get("choose_path", []))
        if len(anchors) < 2:
            raise EconomyError(
                f"{node_id}: sell needs at least two anchors -- the vendor row that opens the picker, "
                "then the row inside it"
            )
        # The sell picker is a CODE-BUILT graph (`WIShop.build_sell_graph`)
        # published as `<vendor>_sell`, reached by an `open_sell_picker`
        # option that ENDS the vendor's own conversation first.
        entry_spec = {"npc": vendor_id, "at": map_id, "choose_path": anchors[:-1]}
        ops = self.dialogue.plan(node_id, entry_spec, why, ledger, entity, map_id)
        sell_graph = f"{vendor_id}_sell"
        ops.append({"kind": "sell_open", "conversation": sell_graph, "entity": vendor_id})
        row = self._sell_row(node_id, sell_graph, ledger, str(anchors[-1]), item_id)
        ops.append({"kind": "dialogue_choose", "cursor_index": int(row["cursor_index"]), "destination": "sold", "end": False, "next_node": {}, "why": why, "defer_destination": True})
        price = int(row["price"])
        ledger.state["inventory"].remove(item_id)
        ledger.shift_gold(price)
        ledger.accomplishment("deliberate_commerce")
        ops.append({
            "kind": "sale",
            "price": price,
            "item": item_id,
            "conversation": sell_graph,
            "total": ledger.gold_interval[0] if ledger.gold_certain else None,
        })
        return ops

    def _sell_row(self, node_id: str, sell_graph: str, ledger: Ledger, anchor: str, item_id: str) -> dict[str, Any]:
        answer = self.bridge.query(f"visible_options {sell_graph} hub", ledger)
        rows = [r for r in answer.get("options", []) if anchor in str(r.get("text", ""))]
        if len(rows) != 1:
            raise EconomyError(
                f"{node_id}: sell anchor {anchor!r} matched {len(rows)} rows in {sell_graph}; "
                f"rows were {[str(r.get('text', '')) for r in answer.get('options', [])]}"
            )
        row = dict(rows[0])
        # The price is READ OFF the row the game rendered ("Sell: <name>.
        # (+N gold)"), never recomputed -- sell_price folds a [Skill] trade
        # bonus this compiler has no business modelling.
        text = str(row.get("text", ""))
        marker = text.rsplit("(+", 1)
        if len(marker) != 2 or not marker[1].split(" ", 1)[0].isdigit():
            raise EconomyError(f"{node_id}: cannot read a price out of sell row {text!r}")
        row["price"] = int(marker[1].split(" ", 1)[0])
        return row

    # --------------------------------------------------------------- detour --

    def _earn_detour(self, node_id: str, ledger: Ledger, shortfall: int, asking: int, item_id: str) -> list[dict[str, Any]]:
        if self.plan_node is None:
            raise EconomyError("economy planner has no node dispatcher wired")
        detour = self.library.match(ledger, shortfall, self.used_detours)
        if detour is None:
            available = [d.id for d in self.library.available(ledger, self.used_detours)]
            raise EconomyError(
                f"{node_id}: {item_id} asks {asking} gold, the ledger guarantees only {ledger.gold_min}, "
                f"and no registered detour certainly earns the {shortfall} short. Eligible detours: {available}"
            )
        self.used_detours.add(detour.id)
        self.insertions.append({
            "node": node_id,
            "detour": detour.id,
            "asking": asking,
            "floor": ledger.gold_min,
            "item": item_id,
        })
        note = (
            f"GOLD/PACING: {item_id} asks {asking}; the interval floor was {ledger.gold_min} "
            f"(interval {ledger.gold_interval}), so detour {detour.id} (+{detour.earns[0]}..{detour.earns[1]}) "
            f"was inserted. Why: {detour.why}"
        )
        self.notes.append(f"{node_id}: {note}")

        ops: list[dict[str, Any]] = []
        entry_node = Node(f"detour.{detour.id}.entry", "goto", {"map": detour.entry_map}, detour.why, "detour")
        ops.extend(self.plan_node(entry_node, ledger))
        for node in detour.nodes:
            ops.extend(self.plan_node(node, ledger))
        if ledger.map_id != detour.exit_map:
            raise EconomyError(
                f"{node_id}: detour {detour.id} broke its exit contract -- promised {detour.exit_map}, "
                f"left the ledger on {ledger.map_id}"
            )
        if ops:
            ops[0] = dict(ops[0])
            ops[0]["note"] = note
        return ops

    # --------------------------------------------------------------- helpers --

    def _asking_price(self, node_id: str, graph_id: str, item_id: str) -> int:
        """The most a vendor could charge for this item, from graph data alone.

        A vendor often carries the same item twice -- a base row and a
        friend's-price row differing only in which accomplishments sit in
        `requires` vs `hide_when`. Which one is offered is a visible-rows
        question the ORACLE answers during the walk; the affordability
        pre-check runs before that walk, so it takes the dearest price as the
        conservative bar. Over-inserting a detour is a pacing note; under-
        inserting one is an unaffordable purchase and a hung run.
        """
        graph = self.dialogue.graphs[graph_id]
        prices: list[int] = []
        for node in graph["nodes"].values():
            for option in node.get("options", []):
                grants = any(str(effect.get("item", "")) == item_id for effect in option.get("effects", []))
                if not grants:
                    continue
                spend = [-int(e["gold"]) for e in option.get("effects", []) if int(e.get("gold", 0)) < 0]
                if spend:
                    prices.append(max(spend))
        if not prices:
            raise EconomyError(f"{node_id}: no priced row in {graph_id} grants {item_id}")
        return max(prices)

    @staticmethod
    def _splice_transaction(
        node_id: str, ops: list[dict[str, Any]], item_id: str, transaction: dict[str, Any]
    ) -> list[dict[str, Any]]:
        """Put the money events between the BUYING confirm and its destination.

        The engine emits gold_changed -> "Paid N gold." -> item_gained BEFORE
        the purchase node's own `dialogue_node`, so the destination wait has to
        sit after them or the since-cursor sails past the money and the waits
        can never match. The row this attaches to is the one that SPENT --
        a choose_path normally continues on to a closing row, and hanging the
        transaction off that one puts every money wait after the fact.
        """
        buying = [
            index for index, op in enumerate(ops)
            if op["kind"] == "dialogue_choose" and int(op.get("gold_delta", 0)) < 0 and item_id in op.get("grants", [])
        ]
        if len(buying) != 1:
            raise EconomyError(
                f"{node_id}: expected exactly one choose_path row to buy {item_id}, found {len(buying)}"
            )
        index = buying[0]
        choose = dict(ops[index])
        destination = choose.get("next_node") or {}
        choose["defer_destination"] = True
        spliced = ops[:index] + [choose, transaction]
        if destination:
            spliced.append({"kind": "dialogue_node_wait", "next_node": destination})
        return spliced + ops[index + 1:]
