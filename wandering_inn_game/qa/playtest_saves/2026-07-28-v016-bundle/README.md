# v0.16 Playtest-State Bundle — 2026-07-28 (seven asks, one sitting)

The v0.16 "Region Depth" taste-queue bundle. Six prepared states + one
paper read. Each state loads into the **playtest** slot; judge lines are
what no agent can rule on — everything below is FEEL, not correctness
(the QA record for all of it is green).

## Restore (per state, then launch and Continue → playtest slot)

```bash
cp "wandering_inn_game/qa/playtest_saves/2026-07-28-v016-bundle/<file>" \
  "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/playtest.json"
```

A "save is from an older version" notice on load is expected (v5 saves,
migration path covered by tests). One known global bug while you play:
an NPC line served in the first ~1.5s after a map loads renders nothing
(GH#324) — wait a beat before the first talk.

## The six states

### 1. `01-goblin-ally-fight.json` — the wave's marquee moment
Rags camp, scavengers pressing the hollow's lip (north edge).
**Do:** walk north, interact with the scavenger press, take the fight.
**Judge:** does fighting BESIDE goblins — Rags and a spear-carrier in
your line, green bars against orange — *land*? Is ally-vs-enemy legible
mid-melee, and do the three rust-tinted scavengers read as a band or as
triplets? (Their tint separation is a logged watch item.)

### 2. `02-witch-hut-dusk.json` — the hut door after the y-sort fix
Witch's hollow west edge, dusk already falling.
**Do:** face west; walk to the door at the hollow's edge (one cell
left), open it, step in and back out.
**Judge:** at dusk, is the door findable WITHOUT knowing it's there?
Post-fix it draws in front of the canopy — but it is a freestanding
frame with no hut art behind it (logged: MAP/OLD-HUT-HAS-NO-HUT). Is
that acceptable fiction for now, or does it need bespoke art before
v0.17?

### 3. `03-lady-ring-box.json` — the nobility register
Inside the stationer's, daytime; the Lady sits at the far chair.
**Do:** talk to her; take the commission; read all three of her nodes
(the glass-stone confession, the "two assets left" line, the Magnolia
line). Optionally talk to the scribe twice for the house-paper line.
**Judge:** does the noble register read as intended — composed, proud,
never naming her house? Is the oblique Magnolia line the right weight
(aware, not fan-service)? This is the wave's voice bar for #318 before
any Magnolia content is specced.

### 4. `04-den-shop.json` — the region's counterweight room
Standing inside the den shop, facing the counter.
**Do:** look; talk to the keeper; read the credit board and the low
bench observables; step out to the market tier and back in.
**Judge:** does the warm-timber-against-slate contrast land — is this
the room that makes Pallass feel inhabited? (The whole point of the
interior, per the spec.)

### 5. `05-line-stalkers.json` — creature or two-headed bug
Witch's hollow, near the denning line (the fight state).
**Do:** approach the den, start the fight, look at the two stalkers on
adjacent cells.
**Judge:** the pair still overlaps into what our shots read as "one
two-headed creature" (open VISUAL-LOG row, north stalker's HP bar
occluded). Live and moving: creature, or bug? Your call decides whether
the fix is cell spacing, art, or nothing.

### 6. `06-payoff-toast.json` — GH#325, live repro (rule on the fix)
Adventurer's Rest, the quiet handoff ready (hat on the third peg).
**Do:** hang the hat (peg rail, north wall), lay the coat (the chair
with the coat), take the wrong coat on the way past — then STAND STILL
and watch the toast queue; run it again and walk immediately instead.
**Judge:** the route's punchline ("nobody raised a voice and nobody
raised an eye") queues BEHIND "Autosaved." and dies unread if you move.
Ship the v0.16.1 hotfix now (authored toasts jump housekeeping), or
bundle it into v0.17?

## 7. The paper read — gossip-ladder scaling (no save)

Balance-bound adjudication; numbers in docs/CHOICE-LOG.md (v0.16 close
block). Short form: the world's talkable census grew 44 → 53 NPCs
(max ~48 `heard_gossip`/waking, was 39) while every gossip-fed class
threshold stood still — [Diplomat]'s entry (3) clears on waking one,
its L10 rung (57) inside two, [Innkeeper]'s L14 alternate likewise.
Every future content wave widens this for free. Recommendation:
scale the gossip rungs with the census (data-only change) — or
explicitly accept "social levels fast in a bigger world" as design.
Wages were ruled fine and are not the lever (CHOICE-LOG).

## Verdict capture

Drop verdicts in any form — a numbered list in chat is fine. Anything
ruled "fix it" gets filed + scheduled; "fine as-is" gets its VISUAL-LOG
row closed with your word as the evidence.

NOT canonical QA fixtures: the fixture-coherence bar does not apply to
these six files (each mirrors the shipped fixture named in its
`_comment`, which does hold that bar).
