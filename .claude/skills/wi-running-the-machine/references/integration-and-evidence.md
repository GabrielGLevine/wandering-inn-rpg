# Integration and close evidence

## Lane brief

Supply: issue/task; exact base SHA and branch; numbered acceptance clauses;
owned files and forbidden overlaps; relevant architecture/domain contracts;
commands and artifacts required; known dirty state; exact next handoff action.
Use a clean-context dispatch (`fork_turns: "none"`) for native agents. Reuse a
worker for its fix round. Discover Git/network/window capability rather than
asserting it from provider identity.

## Integration

- One mutator or mutation probe per worktree at any moment.
- Commit or otherwise make the lane state recoverable before destructive test
  mutations. Restore probes with explicit backups and compare the restored file;
  never use checkout/reset against a dirty file.
- Rebase/merge against the current issue branch before claiming integration.
  Resolve current-state logs semantically; regenerate generated outputs on the
  composed tree.
- Record the final tree SHA before gates. Any later edit invalidates affected
  evidence. Never run unit suites concurrently with a QA sweep in one tree.
- For squash merges compare `<train-tip>^{tree}` with the integrated tree;
  `git cherry` cannot prove a squash landed.

## Review and PR close

Independent review tries to refute each acceptance claim using the real trigger,
runtime wiring, exact diff, fixture changes, and gate invocation. Quotes and
hashes are claims until checked against artifacts. A disclosed failure is only
acceptable if no required CI job runs it and the issue explicitly allows it.

The PR body records: problem and resulting behavior; choices made; per-clause
validation; player-visible/windowed proof; physical touch/device/timing status;
new-agent traps; deferrals. Read `gh pr checks` and its failing logs before any
merge command. Admin ability to merge does not make a failed check acceptable.
