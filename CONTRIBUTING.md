# Contributing

Thanks for your interest! This is a QA-first project: every player-visible
feature ships with an observable event and a scripted playtest assertion.
That architecture is your safety net — if the gate is green, you haven't
broken the game.

## Getting started

1. Install **Godot 4.7** (the project is pinned to it; other versions are
   not supported).
2. Run the game:
   ```bash
   godot --path wandering_inn_game
   ```
3. Run the QA gate (the same thing CI runs):
   ```bash
   # One scripted playtest, headless:
   wandering_inn_game/qa/run_qa.sh combat_walkthrough headless --seed=9
   # The full sweep (what your PR must pass):
   wandering_inn_game/qa/ci_sweep.sh
   ```
   Seeds matter: each script runs at its pinned seed (see
   `wandering_inn_game/AGENTS.md` for the table).

Don't see the real art? The repository ships **fallback art** for a subset
of assets whose licenses don't allow redistribution. The game is fully
playable and testable with fallbacks — see `CONTRIBUTING-ASSETS.md` if you
want to help replace them with original work.

## How changes work here

- **Content is data.** Maps, dialogue, classes, skills, encounters, and
  balance live in `wandering_inn_game/data/*.json`. Most contributions
  never touch engine code.
- **Tune data, never sim.** Balance changes go in data files; the simulation
  core (`src/core/`) changes only for genuinely new mechanics.
- **The sim core stays pure.** `src/core/` has no Node/autoload references;
  presentation only renders what the sim reports.
- **Player-facing text rules (hard requirements, checked in review):**
  - Raw stats (STR/DEX/CON/INT/WIS/CHA) never appear anywhere a player can
    see. HP/MP/AP and damage numbers are fine.
  - No progress-toward text ("3/12 uses", percentages toward a level).
    Advancement is opaque until you sleep — results only.
  - Names, races, skills, and locations follow the canon of The Wandering
    Inn (the wiki is the reference). Don't invent lore in a code PR — for
    new story content, use the quest idea form (see below).

## Pull requests

- **Sign off your commits** (`git commit -s`). We use the
  [Developer Certificate of Origin](https://developercertificate.org/);
  the DCO check must pass.
- **The QA gate must be green** — run the sweep locally before opening
  the PR; CI runs the same commands.
- **Player-visible changes need screenshots.** Run the relevant script
  windowed (`run_qa.sh <script> windowed --seed=N`) and attach the shots.
  If your change is visible to a player, we review what a player sees,
  not just the diff.
- New player-visible features include a bus event + a QA-script assertion
  covering them. If you're unsure how, open the PR as a draft and ask —
  happy to point at an example.
- Maintainer review and merge are handled by the project owner. Releases
  are cut by version tag, so your merged change may ship in a batch.
- Disclose AI assistance in the PR description, including the provider(s)
  used. Commit authorship and `Co-Authored-By` trailers must describe the
  humans and tools that actually produced the commit; do not add a model
  identity by convention when it did not contribute.

## Non-code contributions

- **Quest and content ideas:** use the issue forms (Quest Idea, Dialogue
  Script, Skill Interaction, Map Suggestion). A one-liner is enough to
  start — accepted ideas get worked into a full spec.
- **Art and music:** see `CONTRIBUTING-ASSETS.md` for exact pixel/audio
  specs and the licensing requirements.

## Fan-work status

This is an unofficial, non-commercial fan project set in The Wandering Inn
by pirateaba. Contributions must respect that: nothing commercial, and
setting/lore stays consistent with canon.
