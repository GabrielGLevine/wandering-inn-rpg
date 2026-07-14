# The Wandering Inn RPG (unofficial fan game)

A top-down pixel RPG set in the world of
[The Wandering Inn](https://wanderinginn.com) by pirateaba. You arrive at
Erin's inn with no class and no skills — what you become is up to how you
play: fight, work, talk, or study your way into classes and let them grow,
merge, and evolve while you sleep.

**[▶ Play the demo](#)** *(itch.io link lands with the first public release)*
— runs in your browser; saves live in your browser on this device.

**Spoilers:** safe for readers caught up through **Volume 7** of the web
serial (ebooks: through the Volume 7 books). The game isn't set at any
single moment in the story — it draws characters, places, and Skills
from across Volumes 1–7, and never references anything past that line.

## The pitch

- **Classes find you.** No class-select screen. Spar with a guardsman and
  wake up a [Warrior]; help around the inn and the inn notices; learn magic
  from a haughty mage who insists you're doing it wrong.
- **Leveling is a mystery.** Advancement happens when you sleep, announced
  the way the books do it. No XP bars, no "3/12 uses" counters — the world
  tells you results, never progress.
- **Three pillars.** Combat, social play, and puzzles are all first-class:
  a [Barmaid] with a mop is as real a build as a [Warrior] with a spear.

## Running from source

Requires **Godot 4.7**.

```bash
godot --path wandering_inn_game
```

Some art and music in official builds comes from licensed packs that can't
be redistributed here — the repository builds with fallback placeholders
for those, and is fully playable and testable. Want to help replace them
with original art? See `CONTRIBUTING-ASSETS.md`.

## Contributing

Everything is open to contribution — code, quests, dialogue, art, music,
ideas:

- **Code / content PRs:** start with [CONTRIBUTING.md](CONTRIBUTING.md).
  The project is QA-first: scripted playtests gate every change, and your
  PR runs the same gate in CI.
- **Quest & story ideas:** open a Quest Idea issue — a one-liner like
  *"the player goes with a goblin tribe to clear a mothbear infestation"*
  is enough to start. Accepted ideas get developed into full specs.
- **Art & music:** [CONTRIBUTING-ASSETS.md](CONTRIBUTING-ASSETS.md) has
  the exact pixel and audio specs.

## Fan-work status & licenses

Unofficial, non-commercial fan project, made with love and **not endorsed
by pirateaba** — per the [fanworks policy](https://wanderinginn.com/fanworks-permissions):
full credit to pirateaba, nothing here is sold or monetized, and nothing
here is official. Code is MIT ([LICENSE](LICENSE)); media licensing is
per-asset ([ATTRIBUTION.md](ATTRIBUTION.md)). The Wandering Inn, its
world, and its characters belong to pirateaba. Read the serial at
[wanderinginn.com](https://wanderinginn.com).

## AI disclosure

This game is built with substantial AI assistance, openly: development
is coordinated and implemented with Claude Code (Anthropic) and Codex
(OpenAI), working
with a human director; a portion of the pixel art (several character
sprites and props) is AI-generated via PixelLab and disclosed per-asset
in [ATTRIBUTION.md](ATTRIBUTION.md); writing is drafted by AI under
human canon review against the source serial. The model-neutral skills
used to build it ship in this repo (`.agents/skills/`), with generated
provider adapters — contributors
using AI tooling are welcome, and AI-assisted contributions must be
disclosed in PRs per [CONTRIBUTING.md](CONTRIBUTING.md).
