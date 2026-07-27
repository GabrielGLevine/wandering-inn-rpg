#!/usr/bin/env python3
"""GH#281: --touching monolith mapping + never-silent contract, and the
wi_data_lib extraction's behavior-identity checks. Run manually:
    python3 scripts/tests/test_derive_touching.py -v
(the same convention as the usage-guard tests -- not wired into CI)."""

import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME_SCRIPTS = REPO_ROOT / "wandering_inn_game" / "scripts"
DERIVE = GAME_SCRIPTS / "derive_qa_surfaces.py"

sys.path.insert(0, str(GAME_SCRIPTS))
import wi_data_lib  # noqa: E402


def touching(paths: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(DERIVE), "--touching", paths],
        capture_output=True, text=True, cwd=str(REPO_ROOT))


class TestMonolithTouching(unittest.TestCase):
    def test_portals_json_names_the_portal_carriers(self):
        # THE GH#281 motivating case: this used to print nothing, exit 0.
        result = touching("data/portals.json")
        names = result.stdout.split()
        self.assertEqual(result.returncode, 0)
        self.assertIn("portal_menu", names)
        self.assertIn("pallass_walkthrough", names)
        self.assertGreaterEqual(len(names), 5)

    def test_each_monolith_derives_nonempty(self):
        for base in ("quests.json", "acts.json", "bounties.json",
                "deliveries.json", "combatants.json", "arenas.json",
                "audio.json", "items.json", "fence_stock.json",
                "classes.json", "progression.json"):
            with self.subTest(base=base):
                result = touching(f"data/{base}")
                self.assertEqual(result.returncode, 0)
                self.assertTrue(result.stdout.strip(),
                    f"{base} derived ZERO crossing scripts -- silent-empty regressed")
                self.assertNotIn("WARNING", result.stderr, base)

    def test_unmapped_path_warns_loudly(self):
        result = touching("data/moods.json")
        self.assertEqual(result.returncode, 0)
        self.assertIn("WARNING", result.stderr)
        self.assertIn("moods.json", result.stderr)
        self.assertIn("zero crossing scripts", result.stderr)

    def test_deleted_fixture_warns(self):
        result = touching("qa/fixtures/typo_no_such_fixture.json,data/portals.json")
        self.assertIn("portal_menu", result.stdout.split())
        self.assertIn("WARNING", result.stderr)
        self.assertIn("typo_no_such_fixture", result.stderr)

    def test_dialogue_control_unchanged(self):
        result = touching("data/dialogue/selys_inn.json")
        self.assertIn("inn_guests_loop", result.stdout.split())
        self.assertNotIn("WARNING", result.stderr)


class TestWiDataLib(unittest.TestCase):
    def test_known_maps_matches_composed_scene(self):
        self.assertEqual(wi_data_lib.known_maps(),
            set(wi_data_lib.load_scene()["maps"].keys()))

    def test_scene_root_fields_survive_composition(self):
        scene = wi_data_lib.load_scene()
        self.assertIn("start_map", scene)
        self.assertIn(scene["start_map"], scene["maps"])


if __name__ == "__main__":
    unittest.main()
