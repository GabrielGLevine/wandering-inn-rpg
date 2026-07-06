<!-- Thanks for contributing! Fill this in so a reviewer can trust the change fast. -->

## What & why

<!-- One or two sentences: what does this change do, and why? -->

## How to verify

<!-- The exact command(s) a reviewer can run to see it. e.g.
     wandering_inn_game_v4/qa/run_qa.sh combat_walkthrough headless --seed=9 -->

## Gate checklist

- [ ] The full QA gate passes locally: `wandering_inn_game_v4/qa/ci_sweep.sh` is green.
- [ ] Any new player-visible feature has a QA script (or an extension of one) that asserts it — passing tests are not enough; the assertion must cover what a player actually sees.
- [ ] Tuning changes touch **data** (`wandering_inn_game_v4/data/*.json`), never the sim core.
- [ ] No raw stats (STR/DEX/CON/…) are shown anywhere in UI or toast text. Player-facing text shows race, class, level, skills, HP/MP, and gear only.
- [ ] New/changed content follows Wandering Inn canon (the Wandering Inn Wiki is the source of truth), not invented lore.

## Windowed screenshots (required for player-visible changes)

<!-- If this changes anything a player sees, attach windowed screenshots.
     Generate them with e.g.:
       wandering_inn_game_v4/qa/run_qa.sh <script> windowed --seed=<seed>
     and drag the qa_output/<script>/*.png files in here.
     Double-check no screenshot leaks raw stats. -->

## DCO sign-off

By submitting this PR, I certify the [Developer Certificate of Origin](https://developercertificate.org/).

- [ ] Every commit is signed off (`git commit -s`) — the trailer reads `Signed-off-by: Your Name <you@example.com>`.
