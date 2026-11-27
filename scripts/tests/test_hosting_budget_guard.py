"""CI collector for the Hosting budget kill-switch tests.

CI runs `python3 -m pytest -q scripts/`; the function and its tests live with
the function in infra/hosting-budget-guard/ (so the deployed source is one
self-contained directory). This shim re-exports those tests so the existing
CI job executes them -- no new job, no new dependency (the core is stdlib).
"""

import importlib.util
import sys
from pathlib import Path

_PATH = Path(__file__).resolve().parents[2] / "infra" / "hosting-budget-guard" / "tests" / "test_guard.py"
_SPEC = importlib.util.spec_from_file_location("wi_hosting_budget_guard_tests", _PATH)
_MODULE = importlib.util.module_from_spec(_SPEC)
sys.modules[_SPEC.name] = _MODULE
_SPEC.loader.exec_module(_MODULE)

globals().update({name: value for name, value in vars(_MODULE).items() if not name.startswith("__")})
