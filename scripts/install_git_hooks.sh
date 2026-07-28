#!/bin/bash
# Point THIS worktree at the tracked hooks (worktree-scoped so lane
# worktrees opt in individually — never flips mid-flight lanes).
# Usage: bash scripts/install_git_hooks.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config extensions.worktreeConfig true
git config --worktree core.hooksPath scripts/git-hooks
chmod +x scripts/git-hooks/pre-commit
echo "hooks active for this worktree: $(git rev-parse --show-toplevel) -> scripts/git-hooks"
