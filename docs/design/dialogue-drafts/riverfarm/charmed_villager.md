# charmed_villager.json — companion notes

**Narrative purpose:** the quest's pivot and its best horror-adjacent beat —
an ordinary farmhand speaking the witch's exact words in the wrong register.
Then the freed confession, which retroactively makes the witch sympathetic
(the favor saved a dying mother; the debtor just flinched at paying-time).

## The echo mechanic (the file's whole point)
- Every charmed-state line Tam speaks is a **verbatim copy of a witch pool
  line** (pools/talk_pools.json, witch entries 1–3). `meet` = witch line 1,
  `echo_two` = line 2, `tell` = line 3, `echo_hold` = line 1 again (the
  loop closing is the dread beat).
- **OPEN (spec-ideal):** the spec wants Tam to mirror the witch's CURRENT
  pool line dynamically ("whatever the witch's current pool line is,
  verbatim"). That's a small sim seam (read her `chatted_with_*` index at
  render). This draft pins static copies so it ships without the seam;
  if the seam lands, replace the echo node texts with the mirror read.
  Either way the copies must stay byte-identical to her pool — a
  canon-consistency sweep item.
- "Wrong register" is carried by CONTEXT (turnip row, no kettle) and the
  player options calling it out — not by altering the lines. Do not
  paraphrase the echoes to make them "fit" Tam; the misfit is the tell.
- The **stiller idle + red thread** visual tells are entity/sprite data
  (staging profile); the [Observe] beat here banks `noticed_red_thread`
  and the suggested observe-toast text sits in the `tell` node `_comment`.

## Canon cites
- Charm/geas-collateral witchcraft fits the canon craft frame (prices,
  collateral, collection — Vol. 6 witch arc); no specific canon spell is
  claimed. The red thread is the staging profile's own accent (the witch's
  blood-red thread palette note made diegetic).

## Invented / OPEN
- **"Tam"** — ORIGINAL+flag, deliberately plain, gender-unmarked.
- **The favor's content** (mother's water-lungs, saw spring) — ORIGINAL.
  Chosen so the debtor is sympathetic and the witch's price was FAIR —
  the quest's thesis. Flag if the user wants a pettier favor (changes the
  quest's moral temperature significantly).
- The two confession responses (kind / hard) both bank the same
  accomplishment — tone choice only, no branch debt.

## Wiring notes
- `noticed_red_thread` — flavor accomplishment (gate-referenced nowhere
  yet; future [Witness]-style callbacks could read it). The skill gate
  `{"skill":"observe"}` is visible-locked per the gating split — the
  locked tease on a subtly-wrong NPC is the [Observe] pillar working as
  designed.
- Freed state gates on `blight_lifted` (witch.json banks it on all three
  paths).
- Tam's post-freed pool (pools/talk_pools.json `talk_pool_post`) requires
  `blight_lifted` — same growth machinery as Lyonette C4.

## Softlock audit
`meet` has hidden + locked options and keeps the ungated "(Leave them
be.)" ✓. `echo_two`/`tell` keep ungated ends ✓. `freed` has two ungated
options ✓. No start_combat ✓.
