# Repository operating contract

This public repository is the working repository. Treat every tracked file as
publishable. The active game is `wandering_inn_game/`; read its `AGENTS.md`
when a task touches the game.

## Choose the work from user intent

The current user request is the process owner. An explicit task overrides
queue autopick. For “continue project work,” resume the live item in
`HANDOFF.md`; otherwise inspect the GitHub issue queue and choose the highest
priority unblocked issue. `taste-gate` and `USER-SESSION` items wait for the
user. Read only the relevant issue, current-state section, and project skill.

An accepted issue or design authorizes routine reversible implementation in
its scope. Ask only when a missing choice would materially change the result,
for a new taste/canon ruling, or for a consequential action outside existing
authorization. Carry prior authorization forward, including the issue PR and
merge workflow. Sending messages or making purchases needs explicit user
authorization. Prepare a concrete result before requesting a missing decision.

## Branches, ownership, and closure

Issue work uses `issue/<n>-<slug>` and closes through a pull request using
`.github/PULL_REQUEST_TEMPLATE/issue-close.md`. Its body records choices,
validation, player-visible proof, context for the next agent, and deferrals.
Squash-merge only after required CI and independent review pass. Non-issue
guidance, ledger, and typo-class housekeeping may land directly on `main`.

One mutating process owns a worktree at a time. Parallel lanes require
disjoint worktrees and explicit, non-overlapping file ownership; two workers
must never edit or mutation-test the same tree. Content under different map
region directories is usually disjoint; shared catalogs and generated outputs
are not. Merge lanes into the issue branch, regenerate derived files on the
composed tree, then re-run integration gates. Verify squash integration by
tree identity, not commit ancestry.

Keep `HANDOFF.md` as current state: issue, branch/base SHA, owned dirty paths,
completed evidence, blockers, and exact next action. GitHub issues and PRs are
the durable work/closure record. Respect each log document's declared
`Insertion: head` or `Insertion: tail` rule.

Comments preserve constraints, ordering dependencies, payload shapes, and traps.
Remove provenance, review narrative, and code restatement; let
`scripts/comment_census.py --check` enforce current limits.

## Public assets and secrets

Files named by `wandering_inn_game/assets_manifest.json`, everything under
`potential_assets/`, and local API-key files are never public or tracked.
Licensed assets reach official builds through the private asset bundle;
committed fallbacks keep the public checkout runnable. `scripts/leak_check.sh`
is authoritative. A new licensed asset requires the manifest entry, generated
ignore block, and private bundle release before public code references it.
Never reduce game quality merely to make an asset public; flag the licensing
choice to the user.

## Product rules

Canon names, races, classes, skills, and locations come from the Wandering Inn
Wiki. New content obeys `docs/design/spoiler-cutoff.md` and character voice
obeys `docs/design/character-profiles.md`. Player-facing currency is race,
class, level, `[Skills]`, HP/MP/AP, damage, gold, and gear. Raw attribute names
stay out by default; a clarity exception updates the enforcing tripwire.
Progress toward class/evolution thresholds remains opaque until sleep.

Every player-facing change needs proof of the actual gameplay trigger, the
domain event, rendered confirmation, and a windowed read of what the player
sees. Mouse input does not prove touch. Scripted input proves only the exercised
route and timing. Acceptance naming touch/device/tween behavior needs that path, or is
reported as unproven and queued for the appropriate human/device check.

## Skills and capabilities

`.agents/skills/` is canonical; regenerate provider mirrors with
`python3 scripts/sync_agent_guidance.py --write`. Start with `wi-start-here`
and use one task-specific process owner. Superpowers and Godot-specific skills
are optional references when actually available and useful; their absence does
not block work. Discover network, Git, window, and tool capabilities rather
than inferring them from a provider name.
