"""Regression checks for concise, source-linked agent guidance."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT_GUIDANCE = ROOT / "wandering_inn_game" / "AGENTS.md"


def test_project_guidance_stays_bootstrap_sized_and_source_linked() -> None:
	text = PROJECT_GUIDANCE.read_text()
	assert len(text.encode()) <= 30_000
	assert "## Canonical QA seed table" not in text
	assert "res://tests/test_" not in text
	assert "no human playtest" not in text.lower()
	assert "current `VERSION :=" not in text
	for required in (
		"qa/manifest.json",
		"docs/QA-SCRIPT-NOTES.md",
		"scripts/preflight.sh --full",
		"Humans gate FEEL",
	):
		assert required in text


def test_root_guidance_does_not_duplicate_volatile_project_values() -> None:
	text = (ROOT / "AGENTS.md").read_text()
	for retired in (
		"canonical QA seed table",
		"160 licensed asset paths",
		"GDScript ≤20% comment lines",
		"`_comment` text ≤15%",
	):
		assert retired not in text


def test_start_skill_matches_root_bootstrap_order() -> None:
	text = (ROOT / ".agents" / "skills" / "wi-start-here" / "SKILL.md").read_text()
	positions = [
		text.index("`wandering_inn_game/AGENTS.md`"),
		text.index("GitHub Issues/Milestones"),
		text.index("`HANDOFF.md`"),
		text.index("`.superpowers/sdd/progress.md`"),
	]
	assert positions == sorted(positions)


def test_architecture_history_receives_displaced_project_context() -> None:
	text = (ROOT / "wandering_inn_game" / "docs" / "ARCHITECTURE-HISTORY.md").read_text()
	assert "last audited **2026-08-10**" in text
	assert "one current-state summary paragraph per live system" not in text
	for required in (
		"## 2026-08-10 AGENTS.md split audit",
		"### Post-audit combat extensions",
		"`auto_pre_combat`",
		"`WISettings`",
		"same-map presence reconciliation",
		"AudioWorklet",
		"### Operational traps migrated from AGENTS.md",
	):
		assert required in text


def test_document_map_describes_the_split_authorities() -> None:
	text = (ROOT / "docs" / "DOC-MAP.md").read_text()
	assert "Last verified: **2026-08-11**" in text
	assert "QA seed table" not in text
	assert "bootstrap contracts, authority map, commands, architecture boundaries" in text
	assert "Detailed current mechanisms, history, and rationale" in text
	assert "Compact index of unresolved and still-governing rulings" in text


def test_canonical_skills_do_not_restore_retired_guidance() -> None:
	texts = {
		path: path.read_text()
		for path in sorted((ROOT / ".agents" / "skills").glob("*/SKILL.md"))
	}
	for path, text in texts.items():
		for retired in (
			"seed table: wandering_inn_game/AGENTS.md",
			"AGENTS.md's compact seed table",
			"`wandering_inn_game/AGENTS.md` canonical seed table",
			"qa/ci_sweep.sh`'s `CANON` array",
			"All work on `main`",
			"wi-godot-mcp",
		):
			assert retired not in text, f"{path.relative_to(ROOT)}: {retired}"
	assert "mechanically concatenating both sides" in texts[
		ROOT / ".agents" / "skills" / "wi-running-the-machine" / "SKILL.md"
	]


def test_manifest_and_discovery_own_dynamic_qa_inventories() -> None:
	sweep = (ROOT / "wandering_inn_game" / "qa" / "ci_sweep.sh").read_text()
	assert "qa/manifest.json is the ONE source of truth" in sweep
	assert "AGENTS_MD" not in sweep
	assert "Canonical QA seed table" not in sweep

	preflight = (ROOT / "scripts" / "preflight.sh").read_text()
	assert 'wandering_inn_game/tests/test_*.gd' in preflight


def test_handoff_stays_current_state_only() -> None:
	text = (ROOT / "HANDOFF.md").read_text()
	assert len(text.encode()) <= 12_000
	for retired_heading in (
		"## DONE",
		"## superseded RUNNING",
		"## ARCHIVED RUNNING",
	):
		assert retired_heading not in text
	for required in (
		"## Current state",
		"## User-held",
		"## Queue",
		"## Commands and environment",
	):
		assert required in text


def test_choice_log_stays_a_decision_index() -> None:
	text = (ROOT / "docs" / "CHOICE-LOG.md").read_text()
	assert len(text.encode()) <= 30_000
	assert "git show 1aee127d:docs/CHOICE-LOG.md" in text
	assert "What adversarial review caught" not in text
	for required in (
		"## Open decisions",
		"## Current product and system rulings",
		"#432",
		"[Rope Arrow]",
		"[Pick Lock]",
	):
		assert required in text
