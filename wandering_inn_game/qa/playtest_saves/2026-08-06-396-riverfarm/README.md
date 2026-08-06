# #396 Riverfarm redesign — three reads (2026-08-06)

Everything here loads from **Title → Playtest States** (debug builds only). It
installs into the game's own dedicated `playtest` slot and loads it directly,
so your real saves are untouched — nothing to copy, nothing to restore.

Launch: `/usr/local/bin/godot --path wandering_inn_game`

Riverfarm's Hunter is gone. In his place stands **A Shepherd** — same frozen
ids underneath, new character, new quest (`a_winter_of_teeth`), and the briar
fight is solo now. Eloise's [Hedge Witch] lesson is wrapped in a quest of its
own (`the_makings`). The gates are green and prove none of the things below.

The three states sit at the TAIL of the picker's curated list, in story order.

---

## 1. Meet him — is he a different man?

**Load: `winter_teeth_start`.** Riverfarm village, day, standing beside him.
The quest has not been offered.

Talk to him. Take "The wolves. Say what you need." then "Where do I start?"
Then walk the map: the lamb pen east of the well (three lambs, one of them
down), the stacked hurdles south of it, and the bone-sign out in the west
field margin.

**The questions:** (a) does he read as a SHEPHERD at a glance — before any
copy — or as the hunter in a different hat? The hat and the crook are doing
that work on purpose. (b) His hub opens with "Just passing through." as row 1
and the quest offer as row 2, cursor on row 1. Does that cost you the quest on
a reflex confirm? (c) The bone pile in the west field is the TRACK route's
prop; can you see it while you interact with it, or is the skill legend panel
in the way? Press `H` to collapse the legend and compare.

## 2. The night watch, with him in it

**Load: `winter_watch_agreed_night`.** Night is already armed, the watch is
already agreed, and he fields as your ally. Geared warrior 10.

Walk WEST off your start cell to the field edge. The pack takes you at the
fences and A Shepherd fights beside you.

**The question:** can you read HIS health? The turn banner names him and the
feed narrates his hits, but at night his HP numerals sit on a near-black
sprite. If you cannot tell when he is about to go down, that is the finding —
the whole point of a fight with an ally is deciding whether to spend a turn on
him.

## 3. Eloise's craft, mid-chore

**Load: `makings_mid_tend`.** `the_makings` is live and her pot is already
full; you are in the village, one cell east of the lamb pen.

Tend the limping lamb (the one lying apart from the pair), then take the hollow
path west and sit her kettle. Sleep at the inn afterwards to bank the class.

**The questions:** does the chore-quest read as a quest, or as busywork with a
title? She says the chore is the least of it — do the two chores make that
feel true, or does the class arrive because you ticked two boxes? And the
kettle scene is her landing beat: does it land?

---

## What is deliberately odd

- The shepherd's dialogue file still has `thicket_*` nodes in it. Those are the
  RETIRED quest, kept completable forever for old saves; a fresh save can never
  reach them. If you see "Fences before deer." you are in the legacy arm.
- The lamb pen is present for every save now (it used to require the retired
  quest's counter), so its observe still mentions "after the thicket business"
  as background even on a fresh file.
- A pre-bank save (one that beat the wolves before ever talking to him) gets a
  hub line acknowledging it — "You stood a watch before I ever asked." — and
  can then accept and immediately report. That reads intentional to machine
  eyes; if it reads as a bug to yours, say so and the spec's `watch_stood`
  fallback gets built.
