# talk_pools.json — companion notes

Rotating small-talk pools (2-3 lines each, 4 for the hired toll-goblin
growth pool) for every staged character with a voice contract. Shape and
rotation semantics per the shipped S1 seam (index = `chatted_with_<id> %
size`, zero rng; `talk_pool_post` growth per Lyonette C4).

## Per-character notes + canon cites
- **hermit_sorven** — profile: short declaratives, never asks twice.
  "Two of those I can stock" = the barter-ethics note as a joke about
  patience.
- **toll_goblin** — base pool = bridge-pride; `talk_pool_post` (requires
  `hired_toll_goblin`) = the spec's "mechanical informant": every hired
  line is TRUE in-game intel delivered with total sincerity — corusdeer
  ("antlers ORANGE. Not on fire. Checked twice." — canon: ignitable
  antlers), the Rock Crab ("boulder ... MOVED"), the post-Act-II raid
  escalation. Duplicated in toll_goblin.json's `_hired_talk_pool` —
  keep one authoritative at wiring.
- **riverfarm_witch** — line 1 is THE echo source (charmed_villager
  copies must stay byte-identical). All three lines price something.
- **charmed_villager** — charmed pool = verbatim witch copies (the tell;
  dynamic-mirror seam OPEN, see charmed_villager.md). Freed post-pool
  keys on `blight_lifted`; "her laugh wasn't borrowed too" is the arc in
  one line.
- **riverfarm_headman** — ledger + farm-policy voice; the half-swallowed
  warmth ("...It's a bit hospitality").
- **brothers_lieutenant** — sir-every-sentence, apology-before-threat
  ("begging your pardon for the hypothetical"). Canon hat arithmetic
  (Wilovan page: "perfect gentlemen. Until the hats come off").
- **merchant_prince** — prices, appraisal-as-flattery, the never-raised
  voice made explicit.
- **street_fixer** — trade cant + genuinely liking the gossip (the
  rowboat fish she admits might just be a fish).
- **grimalkin** — canon [Sinew Magus] (wiki-verify at 8e time): numbered
  points, fitness-empiricism, effort-vs-excuses. The broken "there was no
  three" list IS the numbered-points tic used against itself.
- **pallass_tier_clerk** — profile: titles-and-precision, warmth behind
  exact paperwork ("Warmly. In writing.").
- **ceria** — canon: traps-first pragmatism ("clean means something eats
  the dust"), Ksmvr-patience, and the gloves tease (skeletal hand HIDDEN
  v1 per staging — the line teases without revealing; cut it if even a
  tease is too canon-sensitive. **Flagged.**)
- **yvlon** — canon: Byres silver, hidden metal arms hinted only at
  handshake-strength ("the short version is also long"), soldier
  self-deprecation.
- **ksmvr** — canon: reports intentions before acting ("I am waving"),
  earnest-literal idiom misfires ("There is no ice present"), the
  Captain-Ceria/Comrade-Yvlon address forms (canon diction).

## OPEN
- Entity ids are suggestions; map lane owns the real ids.
- Grimalkin + tier clerk are 8e (generate LAST per staging) — pools
  drafted now so the voice exists; wiki-verify Grimalkin's page before
  wiring (staging says canon-check at content time).
- Ceria/Yvlon/Ksmvr are 8d dungeon cast — pools only cover overworld/
  camp small-talk; their quest graphs are a separate task.
