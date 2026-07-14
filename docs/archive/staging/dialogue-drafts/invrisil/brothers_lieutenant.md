# brothers_lieutenant.json — companion notes

**Narrative purpose:** "A Gentleman's Disagreement" give-beat, the
three-door signpost, and the marker reward. Tone target: courtesy so
complete it reads as menace, warmth underneath — the spec's key line opens
the hub verbatim.

## Canon cites (wiki checks 2026-07-06)
- **Brothers of Serendipitous Meetings**: verified via wiki search
  (faction page 404s but 44 member/chapter results). Confirmed members:
  **Wilovan** (dedicated page: tall Gnoll, dapper vest, tall hat,
  "[Blackguard Gentleman of the Streets]", partner Ratici, "originally
  from Invrisil"), **Crimshaw**, **Normen and Alcaz**. Signature canon
  line, from Wilovan's page: *"perfect gentlemen. Until the hats come
  off"* — hats-off = violence. Used here: the hat-restored-at-the-gate
  beat, hats-off arithmetic in the fixer's rumor, and "recover, never
  steal" (spec + canon register).
- The Brothers' honor code (no clip more than owed, courtesy to marks) is
  canon; the marker's "trouble will beg your pardon and step around you"
  extends it.

## Invented / OPEN
- **Speaker "Mister Sable" = ORIGINAL+flag, and here's the conflict:**
  the staging profile pins the lieutenant as HUMAN (bowler-class hat,
  cudgel-like-umbrella), but the best canon anchor, Wilovan, is a
  **Gnoll**. A profile-contradicting name is a defect per the writing
  contract, so this draft stays ORIGINAL. **User decision:** (a) keep
  Mister Sable (safe), (b) recast as Wilovan and amend the staging
  profile to Gnoll (bigger canon spend, best voice fit), or (c) use
  Crimshaw (confirmed member, thinner canon detail = lower contradiction
  risk; race unverified in my fetches — check his page first).
- **"Mister Farley"** (the framed Brother) — ORIGINAL+flag. Offstage in
  v1 (he's in a cell; his release is narrated).
- **"sir" throughout** — profile says "sir/miss every sentence"; PC gender
  is cosmetic sim data with no dialogue-conditional machinery. OPEN:
  either accept "sir" universally (drafted), or the impl lane adds a
  gendered-token seam (bigger than this quest warrants — recommend
  accepting "sir" v1 or degendering to "friend", which weakens the tell).
- "Wister's Alley," "Coyle and Sons" — ORIGINAL Invrisil dressing.

## Wiring notes
- Resolution gates on `merchant_fate_decided` (banked at
  merchant_prince.json's fork — EITHER ending), so the report works for
  all three paths + both fates; per-fate flavor via `marker` variants.
  Path flavor (how you cornered him) lives on Coyle's side.
- `brothers_marker` — items.json entry needed. Its two mechanical
  meanings per spec: footpad encounters go dormant (alley safe-passage —
  dormant machinery as reward; impl: `remove_entity` or a dormant flag on
  the footpad entities, owned by the encounter lane) + a parlor
  fence/vendor surface (v1 can stub as `marker_terms` flavor; the fence
  shop is a later M-GEAR surface — OPEN).
- The FIGHT door's combat starts from merchant_prince.json (the blades
  answer to Coyle), not here; "a man would be honored to attend" is the
  spec's context-ally hook (lieutenant fields in the warehouse fight —
  encounter-lane wiring).
- Quest `a_gentlemans_disagreement` beats suggestion: take
  (`took_brothers_job`) → corner Coyle (`merchant_fate_decided`) → report
  (`brothers_job_done`).

## Softlock audit
Hub: hidden options + ungated "Evening." ✓. commission/why_you keep
ungated declines ✓. No start_combat here ✓.
