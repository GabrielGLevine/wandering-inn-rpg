# The Wandering Inn RPG (unofficial fan game)

A top-down pixel RPG set in the world of
[The Wandering Inn](https://wanderinginn.com) by pirateaba. You arrive at
Erin's inn with no class and no skills — what you become is up to how you
play: fight, work, talk, or study your way into classes and let them grow,
merge, and evolve while you sleep.

**[▶ Play the demo](https://gabrielglevine.github.io/wandering-inn-rpg/)**
— runs in your browser; saves live in your browser on this device. The
demo tracks the latest
[release](https://github.com/GabrielGLevine/wandering-inn-rpg/releases).

**Spoilers:** safe for readers caught up through **Volume 7** of the web
serial (ebooks: through the Volume 7 books). The game isn't set at any
single moment in the story — it draws characters, places, and Skills
from across Volumes 1–7, and never references anything past that line.

## Running from source

Requires **Godot 4.7** (the project is pinned to it; other versions are not
supported).

```bash
git clone https://github.com/GabrielGLevine/wandering-inn-rpg.git
cd wandering-inn-rpg
godot --path wandering_inn_game
```

To check a fresh machine has everything the gates need — engine version,
Python deps, git hooks, and the optional licensed-asset overlay — run:

```bash
bash scripts/setup_dev_env.sh --check   # report only; drop --check to set it up
```

The project is QA-first: every player-visible feature ships with a scripted
playtest that asserts it. Run the same gate CI runs:

```bash
wandering_inn_game/qa/ci_sweep.sh
```

Some art and music in official builds comes from licensed packs that can't
be redistributed here — the repository builds with fallback placeholders
for those, and is fully playable and testable. Want to help replace them
with original art? See [CONTRIBUTING-ASSETS.md](CONTRIBUTING-ASSETS.md).

## Contributing

Everything is open to contribution — code, quests, dialogue, art, music,
ideas:

- **Code / content PRs:** start with [CONTRIBUTING.md](CONTRIBUTING.md).
  Scripted playtests gate every change, and your PR runs the same gate in
  CI. Commits are signed off (DCO).
- **Ideas — no code needed.** The
  [issue forms](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/new/choose)
  cover quests, dialogue scripts, maps, [Skill] interactions, and anything
  else. A one-liner like *"the player goes with a goblin tribe to clear a
  mothbear infestation"* is enough to start; accepted ideas get developed
  into full specs.
- **Playtest feedback:** play the demo, then file a Playtest feedback
  issue — bugs, confusion, pacing, things you loved. Past playtest
  sittings have driven whole releases.
- **Art & music:** [CONTRIBUTING-ASSETS.md](CONTRIBUTING-ASSETS.md) has
  the exact pixel and audio specs.

Everyone here follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Fan-work status & licenses

Unofficial, non-commercial fan project, made with love and **not endorsed
by pirateaba** — per the [fanworks policy](https://wanderinginn.com/fanworks-permissions):
full credit to pirateaba, nothing here is sold or monetized, and nothing
here is official. Code is MIT ([LICENSE](LICENSE)); media licensing is
per-asset ([ATTRIBUTION.md](ATTRIBUTION.md)). The Wandering Inn, its
world, and its characters belong to pirateaba. Read the serial at
[wanderinginn.com](https://wanderinginn.com).

## AI disclosure

This game is built with substantial AI assistance, openly. A portion of the pixel art (several character sprites and props) is AI-generated via PixelLab and disclosed per-asset in [ATTRIBUTION.md](ATTRIBUTION.md). The model-neutral skills used to build it
ship in this repo ([`.agents/skills/`](.agents/skills)), with generated
provider adapters. Contributors using AI tooling are welcome, and
AI-assisted contributions must be disclosed in PRs per
[CONTRIBUTING.md](CONTRIBUTING.md).
