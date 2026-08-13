from __future__ import annotations

from pathlib import Path

from .ledger import Ledger
from .schema import Detour, load_detour


DETOUR_DIR = Path(__file__).resolve().parent / "detours"


class DetourLibrary:
    """The registered earn-detours, matched by CONTRACT rather than by name.

    §8's ruling: detours live in `itinerary/detours/*.yaml`, carry the same
    node schema as an act, and the economy planner picks one by contract match.
    The contract is four things -- the accomplishment state that makes the
    detour real (`requires`/`forbids`), where it can be entered and where it
    leaves you (`entry`/`exit`), and what it is worth (`earns`).
    """

    def __init__(self, directory: str | Path | None = None) -> None:
        self.directory = Path(directory) if directory is not None else DETOUR_DIR
        self.detours: dict[str, Detour] = {}
        if self.directory.is_dir():
            for path in sorted(self.directory.glob("*.yaml")):
                detour = load_detour(path)
                self.detours[detour.id] = detour

    def get(self, detour_id: str) -> Detour:
        if detour_id not in self.detours:
            raise KeyError(f"no such detour: {detour_id} (have {sorted(self.detours)})")
        return self.detours[detour_id]

    def available(self, ledger: Ledger, used: set[str]) -> list[Detour]:
        return [d for d in self.detours.values() if d.id not in used and self._eligible(d, ledger)]

    def match(self, ledger: Ledger, shortfall: int, used: set[str]) -> Detour | None:
        """Cheapest detour that CERTAINLY closes the shortfall.

        Matching is on `earns.min`, never `earns.max`: a detour that only
        might cover the gap leaves the purchase unaffordable in exactly the
        world the interval exists to warn about. Ties break on id so a compile
        is deterministic.
        """
        candidates = [d for d in self.available(ledger, used) if d.earns[0] >= shortfall]
        if not candidates:
            return None
        return sorted(candidates, key=lambda d: (d.earns[0], d.id))[0]

    @staticmethod
    def _eligible(detour: Detour, ledger: Ledger) -> bool:
        accomplishments = ledger.state["accomplishments"]
        if any(int(accomplishments.get(key, 0)) < amount for key, amount in detour.requires.items()):
            return False
        return all(int(accomplishments.get(key, 0)) < amount for key, amount in detour.forbids.items())
