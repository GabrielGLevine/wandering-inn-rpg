# Evidence recipes

## Refactor equivalence

At manifest-pinned seeds, compare the ordered simulation-event subsequence:
remove timestamps and presentation-only `ui_*`/`audio_played` events. Use
scripts that actually exercise each moved arm. A same-tree run/run comparison
establishes expected nondeterminism before judging branch differences.

## Visual change

Capture the real before from the base tree and after from the branch with the
same route and private overlay. Read both as a first-time player. Convert to RGB,
crop the affected region, and confirm the change occurs where expected without
unrelated movement. Idle animation can create noise. Check semantic fit,
legibility, clipping, layering, affordance, and blocked cells as well as pixels.

## Combat/data

Read all current scripts, seeds, fixtures, and tiers from `qa/manifest.json`.
After roster/stat/skill/arena changes, run the balance batch and every
combat-touching canonical. If an outcome changes, diagnose the composition and
derive a justified seed/fixture update; do not seed-shop to hide a defect.

## Failure attribution

To call a failure pre-existing, reproduce it on the actual base tree with a
healthy private overlay and equivalent runtime. `git stash` does not include
gitignored overlay assets. Read the failing script’s full log and `result.json`
before theorizing. Missing result with exit zero is failure. Mass resource-load
errors after asset/script merges usually warrant a clean import check.

## Guard strength

For load-bearing guards, prove the test can fail by mutating the real shipped
input or production seam, confirm the mutation executed, observe red, restore
from an explicit backup, then rerun green. Also verify CI/preflight invokes the
test. Keep mutation probes isolated from all writers.
