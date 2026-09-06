"""Exercise drift detection for conditional references, not only skill routers."""
import importlib.util
from pathlib import Path
import tempfile
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('sync_guidance', Path(__file__).parents[1] / 'sync_agent_guidance.py')
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


def test_reference_edits_and_extra_files_are_detected():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        canonical, mirror = root / 'canonical', root / 'mirror'
        for base in (canonical, mirror):
            (base / 'example/references').mkdir(parents=True)
            (base / 'example/SKILL.md').write_text('skill')
            (base / 'example/references/schema.md').write_text('original schema')
        (root / 'wandering_inn_game').mkdir()
        for adapter in (root / 'CLAUDE.md', root / 'wandering_inn_game/CLAUDE.md'):
            adapter.write_text('Read AGENTS.md')
        with patch.multiple(SYNC, ROOT=root, CANONICAL_SKILLS=canonical, CLAUDE_SKILLS=mirror):
            assert SYNC.check() == 0
            (mirror / 'example/references/schema.md').write_text('stale schema')
            assert SYNC.check() == 1
            assert SYNC.write() == 0
            (mirror / 'example/references/extra.md').write_text('stale orphan')
            assert SYNC.check() == 1
