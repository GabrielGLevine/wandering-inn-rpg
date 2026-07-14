# Garden of Sanctuary — PixelLab generation batch (2026-07-07)

**Generations fired by THIS lane: 13** (each = one `POST
/v1/generate-image-pixflux`, run SEQUENTIALLY foreground — never
parallel; Tier 1 caps 8 concurrent jobs account-wide and sibling lanes
share the account). Subscription pool read 761 before / 714 after this
lane's window, but the delta includes concurrent sibling-lane spend —
count by submissions, not balance. Budget cap was 35; 22 unspent.

All raw outputs + `manifest.json` + `stoneify.py` at
`potential_assets/pixellab_2026-07-07_garden/` (gitignored central
cache). Outputs are PixelLab = user-owned + redistributable
(TIER-PUBLIC; provenance note goes to
`assets/LICENSES/pixellab-ai-generated-verdict.md` at wiring time).

## The stone-ify post-transform (not a generation — the batch's real find)

`stoneify.py`: deterministic alpha-preserving luminance→4-step-ramp
recolor (`(62,54,44)/(96,86,70)/(130,117,100)/(168,156,138)`, keyed to
the pack statues' beige). Generating "monochrome stone" directly FAILED
twice (pixflux colorizes anyway); generating a good FIGURE and
stone-ifying in post succeeded every time, guarantees palette-exact
memorial stone, and gives the memorial a repeatable idiom: **any sprite
the game ever ships can become a remembrance statue with zero new
generations.**

## Fired (13), keep/reject

| # | id | Endpoint / size | Prompt kernel (abridged) | Verdict |
|---|---|---|---|---|
| 1 | `statue_gnoll` | pixflux 32×48 | stone statue, gnoll warrior, sword point-down, plinth | REJECT (head not canine; colored cloth) — kept as stoneify test source |
| 2 | `statue_drake` | pixflux 32×48 | stone statue, drake soldier, spear+shield, plinth | **KEEP via `statue_drake_stone`** (figure excellent; raw output colored → stone-ified) |
| 3 | `statue_goblin` | pixflux 32×40 | stone statue, small goblin, plinth | REJECT (illegible smudge) |
| 4 | `statue_human` | pixflux 32×48 | stone statue, human w/ apron + offering bowl, plinth | **KEEP via `statue_human_stone`** (stone-ified) |
| 5 | `plinth_empty` | pixflux 32×32 | empty plinth, mist at base | **KEEP via `plinth_empty_stone`** (raw "mist" rendered as water → ramp fixed it) |
| 6 | `garden_door` | pixflux 34×48 | freestanding vine-wreathed arched door, ajar, glow | REJECT (baked-in background wall) |
| 7 | `sky_mist_tile` | pixflux 32×32 | seamless bright cloud tile | REJECT (hard seam, cartoon cloud) |
| 8 | `statue_gnoll_v2` | pixflux 32×48 | wolf-headed, "chess piece" grey-stone phrasing | REJECT (reads as column) |
| 9 | `statue_goblin_v2` | pixflux 32×44 | goblin, "figure fills the frame" | **KEEP via `statue_goblin_v2_stone`** |
| 10 | `garden_door_v2` | pixflux 34×48 | + "isolated object on fully transparent background, no wall/scenery" | **KEEP** — the hero prop |
| 11 | `sky_mist_v2` | pixflux 32×32 | "no clouds, uniform brightness at all four edges" | KEEP as source → `sky_mist_final.png` (local post: per-row mean-drift removal + 4px wrap-blend edges; seam deltas t/b 4.3, l/r 0.5) |
| 12 | `statue_gnoll_v3` | pixflux 32×48 | three-quarter view, muzzle in profile | REJECT (awkward horizontal sword) |
| 13 | `statue_gnoll_v4` | pixflux 32×48 | "canine head with visible snout and ears against the sky", cloak | **KEEP via `statue_gnoll_v4_stone`** — clear wolf profile |

## Final keep set (7 files)

`statue_human_stone.png`, `statue_gnoll_v4_stone.png`,
`statue_drake_stone.png`, `statue_goblin_v2_stone.png`,
`plinth_empty_stone.png` (memorial roster + waiting plinth, all through
the one ramp), `garden_door_v2.png` (Erin's door), `sky_mist_final.png`
(impossible-sky skirt tile, seamless).

## Prompt lessons (for the skill library, via HANDOFF)

- pixflux ignores "monochrome/grey stone" on figure subjects —
  post-recolor instead of re-prompting (2 generations wasted proving
  this).
- "isolated object on fully transparent background, no wall, no
  scenery" fixed the baked-background failure in one retry.
- Species reads at 32px: name the diagnostic silhouette feature
  explicitly and positionally ("canine head with visible snout and ears
  against the sky") — generic "wolf-headed" produced columns and robes.

## Queued, deliberately NOT fired (budget left on the table)

- **Erin-witness prop** (her chair/journal on the rise) — taste-gate:
  whether Erin should be visibly present in HER garden is a user call.
- **Door awakened/glow variant frames** — the door's visual_states can
  tint the base sprite (unlit_lantern precedent); generate only if the
  tint read fails windowed QA.
- **Petal particle sprite** — ambience presets recolor the existing
  leaf particle; no art needed unless the recolor reads poorly.
- **Ground-mist emitter texture** — likely a white-recolored dust
  preset; same rule.
- **More memorial subjects** (Antinium worker, half-Elf…) — add when a
  story beat actually needs one; the stone-ify idiom makes each a
  1-generation task (or zero, if the game already has the figure).
