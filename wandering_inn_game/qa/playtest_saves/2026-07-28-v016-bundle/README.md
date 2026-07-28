# The Full Sitting — 2026-07-28 (v0.16 bundle + v0.15 carryover + one organic run)

Fourteen states, one paper read, ~an hour. Everything the taste queue
holds, in one place. Judge lines are what no agent can rule on — the QA
record for all of it is green.

**Suggested order:** `00` first (organic play, while your eyes are
fresh and unspoiled by judge-point framing) → v0.16 states 01–06 →
v0.15 carryover 07–13 (ends on the finale, which wants an unhurried
watch) → the paper read whenever.

## 0. `00-just-play-riverfarm.json` — the organic run (start here)
Wake at the inn. Both Riverfarm quests unstarted, their leads armed.
**Do:** play naturally — check the journal (two new leads point at the
village square), take the Door to Riverfarm, follow whichever lead
pulls you, pick whatever route feels right, see it through to the
report. Take the second quest if you're enjoying it.
**Judge:** everything the judge-point states can't show — do the hooks
pull, does route CHOICE feel real (three genuinely different answers,
not three buttons), does the mill/hut interior payoff after the quest,
does the pacing of one full quest sit right? This is also the only
state that reads #211's challenge-weighted leveling in the wild.

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

## The v0.15 carryover (never sat; six asks, states 07–13)

Full context for each lives in docs/VISUAL-LOG.md §"v0.15 Playtest-State
bundle" — short forms here.

### 7–8. `07-cellar-vermin.json` / `08-briar-hollow.json` — camouflage tints
**Do:** fight both boards. **Judge:** magic-touched, or the same animal
in three colours? Watch the unnamed violet/cold-blue vermin especially —
the ember one gets naming cover ("Ember-Touched Vermin"), its siblings
don't; if any tint reads as a recolour it'll be there, and the cheap fix
is a NAME, not a colour. The briar rust: unmistakable, but do the
collectors still read as *plants*?

### 9. `09-the-warden.json` — the Ruin Warden at 3.51 cells
He fell from 7.62 (half the board's width). **Do:** take the vault
fight. **Judge:** did the drop cost him boss presence? (Bonus, same
board: the windup overlay was brightened ~2.5x without an in-fight
windowed read — do the telegraphs read?)

### 10. `10-toast-over-journal.json` — deliberate overlap
**Do:** open the journal, let a sleep/level toast land. **Judge:** a
1-line toast draws over the journal's blank corner (zero text hidden —
the information-losing case is fixed). "World kept moving" charm, or
broken? Lever is the toast's Y anchor if broken.

### 11. `11-pallass-day.json` — walled-city lights at noon
**Do:** walk both Pallass tiers at day. **Judge:** should the crystal
lamps burn at noon (`lights_by_day` opt-out, one data key per map), or
is the dead-lamp day grade right for a stone city?

### 12. `12-grimalkin-seated.json` — Grimalkin in the inn
Measurement refuted the "too big" claim (he's 1.25x Relc, exactly
canon); what crowds the room is his 2.9-cell arms-out WIDTH. **Do:**
look at the (14,5) seat. **Judge:** if he still FEELS too big, the
lever is the seat or the art — never the scale.

### 13. `13-the-finale.json` — the paced lines (save for last)
**Do:** sleep into the finale; watch at real pace, uninterrupted.
**Judge:** RHYTHM only (copy is measured + pinned). QA structurally
skips the pacing — no agent has ever seen this at speed. The one ask on
the whole list only you can answer.

## The paper read — gossip-ladder scaling (no save)

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
