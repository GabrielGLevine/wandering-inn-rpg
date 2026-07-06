# Krshia Silverfang — stage copy companion

Profile contract: measured, proud of her stock, Silverfang pragmatism;
"Hrr." SPARINGLY. Wiki: Krshia_Silverfang.

## Voice-lint pass

"Hrr" budget: shipped base pool uses it 1-in-4 lines; staged copy holds
that ratio — stage-2 pool 1/3 (line 1 only), stage-3 pool 0/3, nodes 2
across 4 nodes. PASS on the sparingly rule.

Stage-2 pool:
- "you have earned handling privileges" — dry merchant humor, warmth
  priced in merchant terms. PASS.
- "the way I remember debts. Better, even." — Silverfang pragmatism:
  gratitude expressed as ledger-keeping. PASS.
- "That is all the economics you need." — plain-speech contract kept. PASS.

Stage-3 pool:
- "you make the other customers braver" — affection as observed commerce,
  never a named feeling. PASS.
- honey-bread line — a concrete gift, the correct Gnoll register for care;
  "Do not tell the Watch I do favorites" keeps the dignity. PASS.
- "Whole ears." — Gnoll idiom, wrong-size phrase on purpose. PASS. No
  contractions anywhere (she doesn't use them in shipped copy — checked
  against her pool + krshia_crate.json; the staged copy matches).

## Warming audit

Stage 1 prices you. Stage 2 credits you (debts remembered). Stage 3
trusts you (favorites, and the promise finally spoken). Each step is
bought with a real event on her ledger — nothing softens for free.

## Canon anchors + flags

- **Tribe pride (stage 2): SAFE.** Silverfang as a plains tribe and her
  city-Gnoll standing are early canon.
- ⚑ **The plan (stage 3): OBLIQUED.** Canon (wiki): ten years collecting
  spellbooks to bring to the once-a-decade Meeting of Tribes, so Gnolls
  can have their own [Mages]. Staged copy says "something Gnolls have been
  told we cannot have" and "a gathering, some years off" — never
  'spellbook', never 'Meeting of Tribes' by name. Reasons: (a) the plan is
  her guarded long game, (b) naming the artifact invites a content
  promise (a heist arc) we haven't scoped. User gates any sharpening.
- The perk grant rides `krshia_plans_two` ("front-of-stall price is the
  back-of-stall price") so the discount arrives DIEGETICALLY at the same
  moment she trusts you with the plan — recommended wiring is gating the
  cheap shop rows on `heard_krshia_plans: 1` for exactly that reason.

## Conditions + new counter

- `crate_returned` (krshia_crate.json) and `chatted_with_krshia` (shipped
  pool) both exist. `heard_krshia_plans` is NEW, banked on the unlock
  option itself (the asked_lyonette_guild pattern) — one authored bank, in
  the same file that reads it.

## Softlock guard note

Her hub keeps the ungated "Just visiting." exit. The plans option is
double-gated (requires + hide_when after hearing) — same
retire-after-firing shape as the shipped smooth-over option. Shop-row
swaps for the discount shift VISIBLE indices in the `shop` node:
`economy_loop` drives the charm buy by rendered index and must be in the
disclosure sweep.
