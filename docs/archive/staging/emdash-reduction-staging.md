# Em-Dash Reduction Pass — STAGED replacements (corpus-wide)

**Ruling** (user playtest, 2026-07-07): "em dashes are still being serially overused
across dialogue." Budget per `.claude/skills/wi-adding-dialogue-and-quests/SKILL.md`:
at most ONE em-dash per line, most lines ZERO, a dash must earn its interruption
(real self-interruption or turn, not rhythm decoration), and the elaborating
continuation ("X — and Y that restates X") is banned outright.

**How to apply**: each entry is an exact OLD → NEW string replacement. OLD strings
are verbatim file content (no escaped quotes exist in any target file — plain
find/replace is safe). Where a line has a `PINS:` annotation, the SAME old string
appears verbatim in the listed QA/test files and must be replaced there in the same
pass, or the pinned run goes red. Entries with no PINS grep clean across
`qa/scripts/` and `tests/` (verified by full `grep -rn '—'` sweep, 135 hits triaged).

**Voice judgments applied** (per character profile, not blanket count):
- **Relc / Vess** barrel — taken to zero dashes everywhere (periods; they punch, they don't pause).
- **Krshia** speaks in measured, complete declaratives — dash was never her rhythm; taken to zero.
- **Olesm** flusters and genuinely self-interrupts — keeps his "Oh —" startle beats and two mid-thought turns; everything decorative cut.
- **Pisces** earns precise parenthetical pauses — keeps 4; loses only a list-colon and one address-comma case.
- **Zevara** keeps her gratitude-choke tic ("And — thank you") and two hard turns; loses all topic-dash decoration.
- **Lyonette** keeps her two composed self-correction beats; loses the paired-dash narration.
- **Erin** keeps her one genuine self-interruption.
- **Narration / observe / toast copy** (no character voice to protect): decorative dashes → period or colon.
- **System/GDI copy**: prose dashes removed; the GDI veil lines were already dash-free.

**⚑ items** (kept — user adjudicates, see final section): 4.

---

## Convention exemption (⚑A — adjudicate ONCE, not per line)

The **label-separator dash** — `"[Skill Name] — body"`, `"[Class] class gained! — [skills]"`,
`"[Warrior Level 2 → 5] — unlocked …"`, `"N AP — effect"`, `"Press I — your pack."`,
`"Esc — menu"` — is a structural separator, not prose. It is generated in code
(`src/core/effect_text.gd`, `src/core/progression.gd` toast builders, `src/ui/journal.gd`,
`src/ui/field_hotbar.gd`, `src/combat/combat_hud.gd`, `src/ui/message_layer.gd`) AND
mirrored in ~30 data strings (all `field_ambient`/`freeze_toast` in `data/skills.json`,
all `on_skill_use.toast` bodies in `data/skeleton_scene.json`) AND pinned in ~40
QA/test lines (`tests/test_effect_text.gd`, `tests/test_sim_core.gd:390,646,667,1084`,
class-gained toasts across `field_skills_loop`/`mage_unlock_loop`/`social_loop`/
`rogue_earn_loop`/`lantern_check`/`work_loop`/`wrong_order_loop`/`economy_loop`/
`sewers_walkthrough`/`crate_light`).

**Recommendation: EXEMPT.** One dash per line, doing genuine separator work, in the
System's register. Converting to a colon is a coherent alternative but is a
format-wide code+data+test migration — its own pass if the user wants it, not part
of this mechanical sweep. **The BODIES of these lines are held to zero prose dashes**
(one body violated this; fixed under skeleton_scene sewers[8] below).

Also exempt as typographic conventions (not prose):
- Signed-note signature dashes: `Bring patience. — S.S.` (guild board) and
  `Start with the market run. — the counter` (runners' guild).
- The canon inn sign (wording canon-fixed, ch. 1.18; PIN `qa/scripts/tutorial_flow.json:62`):
  `A hand-painted board, letters gone bold where they were traced twice: THE WANDERING INN — NO KILLING GOBLINS.` — DO NOT TOUCH.
- Relc's mid-word cut-off `very— actually, no.` in `relc_descent.json` (the canonical
  earned self-interruption; no space, not a spaced em-dash).

---

## data/dialogue/dummies_note.json — 1 replaced

`.nodes.note.text` (prop note; system-adjacent copy, dash-free bar)
- OLD: `Two battered Watch training dummies on little wheels. One has a face painted on. It has seen things. Relc runs the drills — talk to him.`
- NEW: `Two battered Watch training dummies on little wheels. One has a face painted on. It has seen things. Relc runs the drills. Talk to him.`

## data/dialogue/erin_errand.json — 0 replaced, 1 earned

`.nodes.erin_home_two.text` — `Okay — no more feelings before lunch, house rule.` —
KEPT. Erin genuinely interrupting her own sincerity; this is her documented tic.

## data/dialogue/krshia_crate.json — 22 replaced, 0 kept

Krshia's voice is measured, formal, no contractions — her authority reads BETTER in
full-stop declaratives; every dash here was rhythm decoration on top of that voice.

1. `.nodes.hub.text`
- OLD: `Hrr. My crate — gone from the storeroom three nights past. Sewers, I think. Scavengers do not knock first.`
- NEW: `Hrr. My crate. Gone from the storeroom three nights past. Sewers, I think. Scavengers do not knock first.`

2. `.nodes.hub.text_variants[2].text`
- OLD: `You have the look of someone come to ask a favor. Speak plainly — I have no patience for the other kind.`
- NEW: `You have the look of someone come to ask a favor. Speak plainly. I have no patience for the other kind.`
- PINS: `qa/scripts/wrong_order_talk.json:25`

3. `.nodes.hub.options[1].text` (player)
- OLD: `The scavengers dragged it into a cellar — I've seen it myself. (Light)`
- NEW: `The scavengers dragged it into a cellar. I've seen it myself. (Light)`

4. `.nodes.hub.options[3].text` (player)
- OLD: `The inn's order ran short. Extend it on a good word — for Lyonette's sake. (Persuade)`
- NEW: `The inn's order ran short. Extend it on a good word, for Lyonette's sake. (Persuade)`

5. `.nodes.hub.options[6].text` (player)
- OLD: `Silverfang — that's your tribe?`
- NEW: `Silverfang. That's your tribe?`
- PINS: `qa/scripts/stages_loop.json:23`, `qa/scripts/stages_loop.json:28`, `qa/scripts/stages_loop.json:54`

6. `.nodes.krshia_tribe.text`
- OLD: `My tribe, yes. Plains east and south of here — many hearths, one name. A Gnoll in a city is still her tribe's Gnoll; the distance changes nothing that matters. The necklace is not decoration. It is a promise I carry.`
- NEW: `My tribe, yes. Plains east and south of here: many hearths, one name. A Gnoll in a city is still her tribe's Gnoll; the distance changes nothing that matters. The necklace is not decoration. It is a promise I carry.`

7. `.nodes.krshia_tribe_two.text`
- OLD: `Hrr. Ask me when you have known me longer than one crate. A promise spoken cheap gets spent cheap — this is true of coin and truer of words.`
- NEW: `Hrr. Ask me when you have known me longer than one crate. A promise spoken cheap gets spent cheap. This is true of coin and truer of words.`

8. `.nodes.krshia_plans.text`
- OLD: `So you remembered. Hrr. Then hear a little of it. Every coin this stall clears past its keep goes toward something for the tribes — something Gnolls have been told we cannot have, and are done being told. There is a gathering, some years off. I mean to stand up at it with full hands. That stays between you, me, and the wool.`
- NEW: `So you remembered. Hrr. Then hear a little of it. Every coin this stall clears past its keep goes toward something for the tribes. Something Gnolls have been told we cannot have, and are done being told. There is a gathering, some years off. I mean to stand up at it with full hands. That stays between you, me, and the wool.`
- PINS: `qa/scripts/stages_loop.json:59`

9. `.nodes.krshia_plans_two.text`
- OLD: `You will, if the city behaves and the thieves stay bored. And since you are now a keeper of Silverfang business — for you, the front-of-stall price is the back-of-stall price. Do not announce it.`
- NEW: `You will, if the city behaves and the thieves stay bored. And you are now a keeper of Silverfang business. For you, the front-of-stall price is the back-of-stall price. Do not announce it.`

10. `.nodes.shop.text`
- OLD: `Silverfang goods — best in Liscor, and I will hear no argument on it. Cheapest at the front, the good stock where a browsing hand drifts. Coin on the counter and it is yours. No discounts, no haggling. I remember faces.`
- NEW: `Silverfang goods. Best in Liscor, and I will hear no argument on it. Cheapest at the front, the good stock where a browsing hand drifts. Coin on the counter and it is yours. No discounts, no haggling. I remember faces.`

11. `.nodes.shop.options[1].text` (player)
- OLD: `That Silverfang hunting knife — good steel. (15 gold)`
- NEW: `That Silverfang hunting knife. Good steel. (15 gold)`
- PINS: `qa/scripts/d2_shop_shot.json:24`, `qa/scripts/d2_shop_shot.json:34` (inside options arrays)

12. `.nodes.shop.options[6].text` (player)
- OLD: `The old charm-cord — friend's price. (4 gold)`
- NEW: `The old charm-cord, friend's price. (4 gold)`
- PINS: `qa/scripts/stages_loop.json:70`

13. `.nodes.shop.options[7].text` (player)
- OLD: `That Silverfang hunting knife — friend's price. (13 gold)`
- NEW: `That Silverfang hunting knife, friend's price. (13 gold)`
- PINS: `qa/scripts/stages_loop.json:71`

14. `.nodes.shop.options[8].text` (player)
- OLD: `The wool-lined cloak — friend's price. (16 gold)`
- NEW: `The wool-lined cloak, friend's price. (16 gold)`
- PINS: `qa/scripts/stages_loop.json:72`

15. `.nodes.shop.options[9].text` (player)
- OLD: `The boiled-leather jerkin — friend's price. (22 gold)`
- NEW: `The boiled-leather jerkin, friend's price. (22 gold)`
- PINS: `qa/scripts/stages_loop.json:73`

16. `.nodes.charms.text`
- OLD: `Hrr. The charmed stock — costs more because it does more. Wear too much of it at once and it starts to argue with itself, so choose with sense. Coin on the counter, same as the rest.`
- NEW: `Hrr. The charmed stock costs more because it does more. Wear too much of it at once and it starts to argue with itself, so choose with sense. Coin on the counter, same as the rest.`

17. `.nodes.charms.options[0].text` (player)
- OLD: `That copper ring — can't hurt. (4 gold)`
- NEW: `That copper ring. Can't hurt. (4 gold)`
- PINS: `qa/scripts/d2_shop_shot.json:39` (inside options array)

18. `.nodes.charms.options[5].text` (player)
- OLD: `The stone-scale — the one under the counter. (35 gold)`
- NEW: `The stone-scale, the one under the counter. (35 gold)`
- PINS: `qa/scripts/d2_shop_shot.json:39` (same options array as #17 — one edit site covers both)

19. `.nodes.bought.text`
- OLD: `Sold. Wear it, use it — and do not bring it back to me broken expecting sympathy. Anything else catch your eye?`
- NEW: `Sold. Wear it, use it, and do not bring it back to me broken expecting sympathy. Anything else catch your eye?`
- PINS: `qa/scripts/d2_shop_shot.json:30`, `qa/scripts/economy_loop.json:119`

20. `.nodes.accepted.text`
- OLD: `Good. Sewer grates, south of here — start there. Careful of teeth.`
- NEW: `Good. Sewer grates, south of here. Start there. Careful of teeth.`

21. `.nodes.thanks.text`
- OLD: `Hrr. Yes. This is mine. My thanks — do not expect a discount, but my thanks.`
- NEW: `Hrr. Yes. This is mine. My thanks. Do not expect a discount, but my thanks.`

22. `.nodes.smoothed.text`
- OLD: `Hrr. For the barmaid, then. She is prickly, that one, but she works — I have watched her learn it. The order goes out full, and no word of the shortfall reaches Erin from my stall. You speak plainly and you speak for a friend. That, I respect.`
- NEW: `Hrr. For the barmaid, then. She is prickly, that one, but she works. I have watched her learn it. The order goes out full, and no word of the shortfall reaches Erin from my stall. You speak plainly and you speak for a friend. That, I respect.`

## data/dialogue/lyonette_tip.json — 0 replaced, 1 earned (⚑C)

`.nodes.gratitude.text` — `...without a ledger open. — Here. It's what I could scrape together...` —
KEPT. The sentence-initial dash is her cutting herself off to physically thrust the
coin pouch over — a composed self-correction turned gesture, squarely her earned
category. PIN (unchanged, listed for awareness): `qa/scripts/wrong_order_loop.json:79`.
See ⚑C.

## data/dialogue/olesm_intro.json — 22 replaced, 2 kept whole (worst offender #2: 28 dashes)

Olesm keeps his genuine startle/turn beats: `hub.text` (`Oh — hello. One moment;...`)
and `resolution` (`filing this under 'problems the Council pays adventurers for' — which, as of today, includes you.`).
Four 2-dash lines are cut to their ONE earned dash each.

1. `.nodes.hub.text_variants[0].text` (2 → 1; keeps the "Oh — hello" startle)
- OLD: `Oh — hello. You have the look of someone who counts the exits on the way into a room. A [Tactician]? Truly? I so rarely get to talk shop — sit, sit. Well. Stand. How can I help?`
- NEW: `Oh — hello. You have the look of someone who counts the exits on the way into a room. A [Tactician]? Truly? I so rarely get to talk shop. Sit, sit. Well. Stand. How can I help?`

2. `.nodes.hub.text_variants[2].text`
- OLD: `You climbed back out. I confess I ran the odds while you were down there and did not care for them. Tell me it's over — I have a column that badly wants a number in it.`
- NEW: `You climbed back out. I confess I ran the odds while you were down there and did not care for them. Tell me it's over. I have a column that badly wants a number in it.`

3. `.nodes.hub.options[0].text` (player)
- OLD: `That board — you're playing yourself?`
- NEW: `That board. You're playing yourself?`

4. `.nodes.hub.options[3].text` (player)
- OLD: `Zevara sent me. The tunnels under the cisterns — what do you have?`
- NEW: `Zevara sent me. The tunnels under the cisterns. What do you have?`

5. `.nodes.olesm_chess_invite.text`
- OLD: `The board's been out since Tuesday, if you want the honest count. I'm not going to pretend otherwise. Whenever you're ready — I'll even let you have white, which should tell you how confident I am.`
- NEW: `The board's been out since Tuesday, if you want the honest count. I'm not going to pretend otherwise. Whenever you're ready. I'll even let you have white, which should tell you how confident I am.`

6. `.nodes.olesm_doubt_two.text` (clerk's colon — very Olesm)
- OLD: `So do I. That's the strange arithmetic of the job — you train your whole life for a day you pray never comes, and the better you are, the more boring the city stays. Liscor is very boring. I'm quietly proud of that.`
- NEW: `So do I. That's the strange arithmetic of the job: you train your whole life for a day you pray never comes, and the better you are, the more boring the city stays. Liscor is very boring. I'm quietly proud of that.`

7. `.nodes.olesm_ambition.text`
- OLD: `Honestly? There's a class above mine. [Strategist]. Cities write to theirs. Armies wait on them. Some nights I can almost see the shape of the level — like a move you know is on the board and cannot find yet. ...I've started writing to other [Tacticians]. Comparing games, doctrine, mistakes. Perhaps it becomes nothing. Perhaps it becomes something every city wants a copy of.`
- NEW: `Honestly? There's a class above mine. [Strategist]. Cities write to theirs. Armies wait on them. Some nights I can almost see the shape of the level, like a move you know is on the board and cannot find yet. ...I've started writing to other [Tacticians]. Comparing games, doctrine, mistakes. Perhaps it becomes nothing. Perhaps it becomes something every city wants a copy of.`

8. `.nodes.briefing.text` (2 → 1; keeps the earned "map it — but do NOT" turn)
- OLD: `I mapped your ledge sketches against the city plans. There's a gallery below the cisterns older than Liscor's walls — and something has been widening it. Kill it, chase it off, or map it — but do NOT let it follow you up. …Take Relc. Please.`
- NEW: `I mapped your ledge sketches against the city plans. There's a gallery below the cisterns older than Liscor's walls, and something has been widening it. Kill it, chase it off, or map it — but do NOT let it follow you up. …Take Relc. Please.`

9. `.nodes.chess.text`
- OLD: `Both sides, yes — it's the only honest way to learn how the enemy thinks. You have to want to win as them. A human beat me across this very board once, so thoroughly I nearly thanked her. I did thank her. Best thing to happen to my game in years.`
- NEW: `Both sides, yes. It's the only honest way to learn how the enemy thinks. You have to want to win as them. A human beat me across this very board once, so thoroughly I nearly thanked her. I did thank her. Best thing to happen to my game in years.`

10. `.nodes.chess_two.text` (the dash was the banned amplifier shape)
- OLD: `A loss you understand is worth ten wins you don't. That isn't just chess — that's the whole job. If only the Council read reports the way I read a board.`
- NEW: `A loss you understand is worth ten wins you don't. That isn't just chess. That's the whole job. If only the Council read reports the way I read a board.`

11. `.nodes.resonance.text`
- OLD: `The weak point? Everyone points at the gap in the south wall. It isn't. It's that Liscor has never been besieged long enough to learn its own supply — morale holds until the third hungry week, and no one has ever counted past the second. ...You already knew that. I can see you did. It is, honestly, a relief not to be the only one in the room doing that arithmetic.`
- NEW: `The weak point? Everyone points at the gap in the south wall. It isn't. It's that Liscor has never been besieged long enough to learn its own supply. Morale holds until the third hungry week, and no one has ever counted past the second. ...You already knew that. I can see you did. It is, honestly, a relief not to be the only one in the room doing that arithmetic.`

12. `.nodes.resonance_two.text`
- OLD: `I would like that. Genuinely. Bring a board — we'll settle the wall and the war in one afternoon.`
- NEW: `I would like that. Genuinely. Bring a board. We'll settle the wall and the war in one afternoon.`

13. `.nodes.cisterns.text` (list-introducing colon)
- OLD: `Worried is the professional term, yes. The market's had reports — things moving under the grates, a cistern gone foul, a fishmonger who swears something looked back at him from the dark. Probably nothing. I do not care for probably-nothings under a walled city. ...Actually. You have the look of someone who finishes things. Would you go down and settle it?`
- NEW: `Worried is the professional term, yes. The market's had reports: things moving under the grates, a cistern gone foul, a fishmonger who swears something looked back at him from the dark. Probably nothing. I do not care for probably-nothings under a walled city. ...Actually. You have the look of someone who finishes things. Would you go down and settle it?`

14. `.nodes.cisterns.text_variants[0].text`
- OLD: `You're back. The cisterns — any word? The grate's open now, and whatever's nesting down there will not count itself.`
- NEW: `You're back. The cisterns. Any word? The grate's open now, and whatever's nesting down there will not count itself.`

15. `.nodes.cisterns.text_variants[1].text`
- OLD: `You've the look of someone who's swung a blade recently. The nest under the market — is it settled? Tell me straight.`
- NEW: `You've the look of someone who's swung a blade recently. The nest under the market. Is it settled? Tell me straight.`

16. `.nodes.cisterns.text_variants[3].text`
- OLD: `You came back with your skin — and, unless I misread you, with a picture in your head. You mapped it, didn't you. Show me.`
- NEW: `You came back with your skin and, unless I misread you, with a picture in your head. You mapped it, didn't you. Show me.`

17. `.nodes.cisterns.options[1].text` (player)
- OLD: `It's dealt with — I cleared the nest myself.`
- NEW: `It's dealt with. I cleared the nest myself.`

18. `.nodes.cisterns.options[2].text` (player)
- OLD: `The Watch swept it — Captain Zevara's people handled it.`
- NEW: `The Watch swept it. Captain Zevara's people handled it.`

19. `.nodes.cisterns.options[3].text` (player)
- OLD: `I didn't fight it. I mapped it — the nest, the count, the exits. [Appraise Foe]`
- NEW: `I didn't fight it. I mapped it: the nest, the count, the exits. [Appraise Foe]`

20. `.nodes.cisterns_brief.text` (2 → 1; keeps the earned spec dash — a colon there would nest inside the What:/Where:/How: frame)
- OLD: `Thank you. Here's what I have. What: something's nested in the old cisterns under the market — the reports say spiders, big ones, silver-backed, the kind that climb up from the Dungeon when a wall cracks. Where: down the green sewer-grate off the south square. It's rusted, but it'll open now that someone official wants it open. How: I genuinely don't mind. Put a blade through it, get the Watch to sweep it, or just bring me a proper picture of what's down there — count, size, exits. A map is as good as a corpse to me, and cheaper in bandages. Settle it however suits you, then come tell me it's done.`
- NEW: `Thank you. Here's what I have. What: something's nested in the old cisterns under the market. The reports say spiders, big ones, silver-backed, the kind that climb up from the Dungeon when a wall cracks. Where: down the green sewer-grate off the south square. It's rusted, but it'll open now that someone official wants it open. How: I genuinely don't mind. Put a blade through it, get the Watch to sweep it, or just bring me a proper picture of what's down there — count, size, exits. A map is as good as a corpse to me, and cheaper in bandages. Settle it however suits you, then come tell me it's done.`

21. `.nodes.cisterns_done.text`
- OLD: `Then it's over, and the city's quieter for it. That's real work — the kind nobody thanks you for, so let me be the exception. You've the Council's gratitude, and mine, which comes with more paperwork but rather more warmth. If you ever want a game, or a job that needs a clear head, you know where the board is.`
- NEW: `Then it's over, and the city's quieter for it. That's real work, the kind nobody thanks you for, so let me be the exception. You've the Council's gratitude, and mine, which comes with more paperwork but rather more warmth. If you ever want a game, or a job that needs a clear head, you know where the board is.`

22. `.nodes.cisterns_intel.text` (2 → 1; keeps the earned "and mine, doubled" addendum)
- OLD: `...Oh, this is lovely work. You counted them. Exits, chokepoints, the drop where the tunnel falls away — the whole shape of the problem on one page. Now the Watch goes in knowing the ground instead of bleeding to learn it. A map IS as good as a corpse, and I have never once gotten to say that to someone who agreed. Take the Council's thanks — and mine, doubled, because you did it the clever way.`
- NEW: `...Oh, this is lovely work. You counted them. Exits, chokepoints, the drop where the tunnel falls away. The whole shape of the problem on one page. Now the Watch goes in knowing the ground instead of bleeding to learn it. A map IS as good as a corpse, and I have never once gotten to say that to someone who agreed. Take the Council's thanks — and mine, doubled, because you did it the clever way.`

## data/dialogue/peddler_stall.json — 1 replaced

`.nodes.hub.options[0].text` (player)
- OLD: `That gambeson — Watch-issue? (20 gold)`
- NEW: `That gambeson. Watch-issue? (20 gold)`

## data/dialogue/pisces_magic.json — 2 replaced, 4 earned

KEPT (Pisces's precise pauses, one per line, all genuine):
`greet` (`A [Necromancer], yes — and before your hand drifts to that sword...` — preemptive interruption),
`pisces_fence` (`My father's trade — his grip, his footwork, his opinions on both.`),
`pisces_fence_two` (`Next question — preferably about magic...` — fussy redirect),
`lesson_mana` (`carries a reserve — mana` — the term lands on the pause).

1. `.nodes.lesson_casting.text` (lecture list → lecturer's colon)
- OLD: `A sword asks only your arm. A spell asks your mind and your mana in the same instant — intent, shape, and cost, released together or not at all. Fumble any one of the three and you have merely gestured. Precision, traveler. Whatever the Watch mutters about my craft, it taught me precision.`
- NEW: `A sword asks only your arm. A spell asks your mind and your mana in the same instant: intent, shape, and cost, released together or not at all. Fumble any one of the three and you have merely gestured. Precision, traveler. Whatever the Watch mutters about my craft, it taught me precision.`

2. `.nodes.sealed.text` (2 → 1; keeps the earned self-correction `opened — crudely, but opened`)
- OLD: `There. The channel is opened — crudely, but opened. Sleep on it; the shape settles by morning, as these things do. And traveler — when your first orb kindles, you will understand why I do not apologize for what I am.`
- NEW: `There. The channel is opened — crudely, but opened. Sleep on it; the shape settles by morning, as these things do. And, traveler, when your first orb kindles, you will understand why I do not apologize for what I am.`

## data/dialogue/relc_descent.json — 2 replaced, 1 earned

KEPT: `alone_confirm` — `You're either very brave or very— actually, no.` (mid-word
cut-off, the canonical earned dash; see convention exemptions).

1. `.nodes.join.text` (2 → 0; Relc barrels)
- OLD: `Bones. Old fires. Something's been living down here a good long while — and it just heard us walk in. ...Deep tunnels, huh? You know what lives in deep tunnels? Me. As of today. Come on — you swing, I'll skewer.`
- NEW: `Bones. Old fires. Something's been living down here a good long while, and it just heard us walk in. ...Deep tunnels, huh? You know what lives in deep tunnels? Me. As of today. Come on. You swing, I'll skewer.`

2. `.nodes.alone_confirm.options[1].text` (player)
- OLD: `[On second thought — with me.]`
- NEW: `[On second thought, with me.]`

## data/dialogue/relc_intro.json — 9 replaced, 0 kept (Relc → zero dashes)

1. `.nodes.meet.text`
- OLD: `Oi. Hold up. Big spear, bored Drake, official business — that's me covered. You came off the inn hill. Name and errand.`
- NEW: `Oi. Hold up. Big spear, bored Drake, official business. That's me covered. You came off the inn hill. Name and errand.`

2. `.nodes.meet.text_variants[0].text`
- OLD: `Hah — the inn's errand-runner. Road's been quiet since you passed. Mostly.`
- NEW: `Hah! The inn's errand-runner. Road's been quiet since you passed. Mostly.`

3. `.nodes.meet.text_variants[1].text`
- OLD: `There's the dummy-slayer. Straw fears you. Come here — I owe you something for the show.`
- NEW: `There's the dummy-slayer. Straw fears you. Come here. I owe you something for the show.`

4. `.nodes.banter.text`
- OLD: `Relc. Senior Guardsman, best spear in Liscor, currently guarding grass. The inn feeds you, the city taxes you — everything between is my road, so behave on it. There's goblins about, if the walk gets boring.`
- NEW: `Relc. Senior Guardsman, best spear in Liscor, currently guarding grass. The inn feeds you, the city taxes you. Everything between is my road, so behave on it. There's goblins about, if the walk gets boring.`

5. `.nodes.warns.text`
- OLD: `Goblins on the road since the thaw — a warband near the gate with a chief who's got actual teeth. Old stones to the north-east? Stay off them. And if the pond looks deep, that's because it is.`
- NEW: `Goblins on the road since the thaw. A warband near the gate with a chief who's got actual teeth. Old stones to the north-east? Stay off them. And if the pond looks deep, that's because it is.`

6. `.nodes.spar_offer.text` — **HEAVIEST PIN IN THE CORPUS (10 sites)**
- OLD: `Ha! Good instinct — everyone swings wrong until someone laughs at them. Watch keeps training dummies in the gatehouse; I drag a couple out when gate duty gets slow. Don't ask about the wheels. Rules are simple: you move, you hit, you don't cry.`
- NEW: `Ha! Good instinct. Everyone swings wrong until someone laughs at them. Watch keeps training dummies in the gatehouse; I drag a couple out when gate duty gets slow. Don't ask about the wheels. Rules are simple: you move, you hit, you don't cry.`
- PINS: `qa/scripts/combat_walkthrough.json:22`, `qa/scripts/quest_errand_parley.json:192`, `qa/scripts/dialogue_walkthrough.json:380`, `qa/scripts/gate_district_walkthrough.json:109`, `qa/scripts/dialogue_hub_loop.json:209`, `qa/scripts/quest_errand_fight.json:170`, `qa/scripts/save_load_roundtrip.json:170`, `qa/scripts/status_first_encounter.json:30`, `qa/scripts/relc_tutorial.json:96`, `qa/scripts/relc_tutorial.json:158`

7. `.nodes.spar_offer.text_variants[0].text`
- OLD: `Again? Fine. The dummies heal fast — perk of being straw. Same rules: move, hit, no crying.`
- NEW: `Again? Fine. The dummies heal fast. Perk of being straw. Same rules: move, hit, no crying.`

8. `.nodes.gift.text` (2 → 0)
- OLD: `My spare spear. Held gates wider than that one. Now listen — owning a weapon and HOLDING it are different things: press I, that's your pack. Put the spear in your hand before the road checks your grip. Sword arm, spear arm — the weapon you carry decides which of your moves come with you.`
- NEW: `My spare spear. Held gates wider than that one. Now listen. Owning a weapon and HOLDING it are different things: press I, that's your pack. Put the spear in your hand before the road checks your grip. Sword arm, spear arm. The weapon you carry decides which of your moves come with you.`
- PINS: `qa/scripts/relc_tutorial.json:531`

9. `.nodes.relc_army.text`
- OLD: `Ha! No. Army, before. Liscor's got one — it just never comes home. I did. Walls pay worse, but nobody makes you march in the rain, and I am DONE with marching. Best decision I ever made, after the spear.`
- NEW: `Ha! No. Army, before. Liscor's got one. It just never comes home. I did. Walls pay worse, but nobody makes you march in the rain, and I am DONE with marching. Best decision I ever made, after the spear.`

## data/dialogue/selys_delivery.json — 3 replaced

1. `.nodes.hub.options[4].text` (player)
- OLD: `Shivertail — any relation to the Guildmistress?`
- NEW: `Shivertail. Any relation to the Guildmistress?`

2. `.nodes.selys_gran_two.text`
- OLD: `Everyone behind this counter did, once. Then you log your first casualty report. The desk keeps more people alive than a sword does — that took me years to believe, so you don't have to believe it today. Now stop making me sincere during business hours.`
- NEW: `Everyone behind this counter did, once. Then you log your first casualty report. The desk keeps more people alive than a sword does. That took me years to believe, so you don't have to believe it today. Now stop making me sincere during business hours.`

3. `.nodes.selys_board_pick.text`
- OLD: `One job. I flagged it because the client isn't insane and the pay is honest — a courier run out to Riverfarm, nothing that bites back. Bring me the receipt and I'll square you from the Guild's own purse, not the client's excuse for one.`
- NEW: `One job. I flagged it because the client isn't insane and the pay is honest: a courier run out to Riverfarm, nothing that bites back. Bring me the receipt and I'll square you from the Guild's own purse, not the client's excuse for one.`

## data/dialogue/watch_crate.json — 1 replaced

`.nodes.hub.text_variants[0].text`
- OLD: `Grates are quiet now. Good — one less thing.`
- NEW: `Grates are quiet now. Good. One less thing.`

## data/dialogue/zevara_intro.json — 11 replaced, 4 earned

KEPT (genuine turns in her dry register):
`zevara_oath` (`...and the facts worse — and then the chair was mine.` — the bitter punch),
`zevara_oath_two` (`But — thank you.` — gratitude-choke tic, see ⚑B),
`seal` (`bricking that gallery before sundown — 'for now,' before you say it.` — preempting the player),
`sweep_argue.options[1]` (player: `Actually — never mind.` — real self-interruption).

1. `.nodes.hub.text_variants[0].text`
- OLD: `The thing under the market — I hear it's handled. Good. I sleep worse than you'd think over not knowing what's beneath my own streets. However you settled it, the Watch owes you a quiet night. Don't tell the others I said so.`
- NEW: `The thing under the market. I hear it's handled. Good. I sleep worse than you'd think over not knowing what's beneath my own streets. However you settled it, the Watch owes you a quiet night. Don't tell the others I said so.`

2. `.nodes.hub.text_variants[2].text`
- OLD: `The one who went down the tunnels and climbed back out. The gallery's bricked and the streets are quiet. I've a report with your name on it that I'll deny writing. Rest — you've earned a boring week. Take it before the next one.`
- NEW: `The one who went down the tunnels and climbed back out. The gallery's bricked and the streets are quiet. I've a report with your name on it that I'll deny writing. Rest. You've earned a boring week. Take it before the next one.`

3. `.nodes.hub.options[1].text` (player; restructured — fragment-plus-demand read as decoration)
- OLD: `The cisterns under the market — I need the Watch to sweep them.`
- NEW: `I need the Watch to sweep the cisterns under the market.`

4. `.nodes.zevara_bounties.options[1].text` (player)
- OLD: `The cistern nest is gone — you know that one firsthand.`
- NEW: `The cistern nest is gone. You know that one firsthand.`

5. `.nodes.summons.text`
- OLD: `There you are. The cisterns crew found something under the new grates — tunnels nobody dug, going DOWN. Olesm's maps say they shouldn't exist. You've been down there; you're going again. This time for the Watch.`
- NEW: `There you are. The cisterns crew found something under the new grates: tunnels nobody dug, going DOWN. Olesm's maps say they shouldn't exist. You've been down there; you're going again. This time for the Watch.`

6. `.nodes.summons_send.text`
- OLD: `Good. See Olesm before you climb down — he's been up since the second bell drawing what shouldn't be there, and he'll want you carrying it. And take Relc. That's not the suggestion it sounds like.`
- NEW: `Good. See Olesm before you climb down. He's been up since the second bell drawing what shouldn't be there, and he'll want you carrying it. And take Relc. That's not the suggestion it sounds like.`

7. `.nodes.shift.text`
- OLD: `Ten years of long shifts. Six weeks of leave across all of them — do the arithmetic and then don't ask why I look like this. My Senior Guardsmen are a spearmaster who won't stop talking and an Antinium who won't start, and the wall stands in spite of both of them. Don't tell either of them the streak's holding. They'll take the credit.`
- NEW: `Ten years of long shifts. Six weeks of leave across all of them. Do the arithmetic and then don't ask why I look like this. My Senior Guardsmen are a spearmaster who won't stop talking and an Antinium who won't start, and the wall stands in spite of both of them. Don't tell either of them the streak's holding. They'll take the credit.`

8. `.nodes.authority.text`
- OLD: `He should. I signed his posting and I read his reports — both of them, the real one and the one where nothing happened. Liscor's Watch runs on people who'd rather stand a boring gate than let an interesting one through. Long may it bore us.`
- NEW: `He should. I signed his posting and I read his reports: both of them, the real one and the one where nothing happened. Liscor's Watch runs on people who'd rather stand a boring gate than let an interesting one through. Long may it bore us.`

9. `.nodes.sweep_pitch.options[0].text` (player)
- OLD: `If it's under the city and it's moving, it's already Watch business — I'm just the one telling you before it's an emergency instead of a form.`
- NEW: `If it's under the city and it's moving, it's already Watch business. I'm just the one telling you before it's an emergency instead of a form.`

10. `.nodes.sweep_argue.text`
- OLD: `...Before it's an emergency. Hm. You argue like someone who's read a casualty report. Fine — make it plain. What am I actually sending them into?`
- NEW: `...Before it's an emergency. Hm. You argue like someone who's read a casualty report. Fine. Make it plain. What am I actually sending them into?`

11. `.nodes.swept.text` (2 → 1; keeps the `And — good work.` choke, see ⚑B)
- OLD: `Spiders from the Dungeon. Wonderful. That's exactly the small-now-large-later I'd rather pay for in overtime than in funerals. Consider it swept — I'll pull a squad at dusk and burn the silk out before it spreads. You did right bringing it to me clean, before it had teeth. Go tell whoever set you on this that the Watch has it. And — good work. That's rarer from my side of the gate than you'd think.`
- NEW: `Spiders from the Dungeon. Wonderful. That's exactly the small-now-large-later I'd rather pay for in overtime than in funerals. Consider it swept. I'll pull a squad at dusk and burn the silk out before it spreads. You did right bringing it to me clean, before it had teeth. Go tell whoever set you on this that the Watch has it. And — good work. That's rarer from my side of the gate than you'd think.`

## data/skeleton_scene.json — 44 replaced, 14 earned (worst offender #1: 72 dashes)

KEPT as earned (verbatim, for the reviewer's eye):
- inn `entities[1].talk_pool[2]` — `Most don't. — Well. Don't let it go to your head.` (Lyonette recovery pivot, ⚑C family)
- inn `entities[1].talk_pool_stages[0].lines[1]` — `No, I insist — I'm allowed to insist...` (Lyonette composed self-assertion)
- street `entities[2].friendly_line` — `And — thank you. Genuinely.` (Zevara tic, ⚑B)
- street `entities[3].talk_pool_stages[0].lines[0]` — `Oh — you! No no, the tally can wait.` (Olesm startle)
- street `entities[3].talk_pool_stages[0].lines[2]` — `so — efficiency.` (Olesm stammer-conclusion)
- street `entities[10].talk_pool_stages[0].lines[2]` — `There — advice worth coin, given freely.` (Pisces presentation beat)
- street `entities[12].talk_pool_stages[1].lines[0]` — `Good — you.` (Krshia's one genuine clipped recognition; her only surviving dash)
- floodplains `entities[1].toast` — inn sign, CANON, untouchable (PIN `qa/scripts/tutorial_flow.json:62`)
- sewers `entities[3].toast` — `a map of channels — and a fresh scratch...` (dash continuation adds a NEW fact — the discovery beat; PIN unchanged `qa/scripts/sewers_walkthrough.json:588`)
- deep_tunnels `entities[1].observe` — `knew how to keep a fire — or learned how, the way they say these things learn...` (or-correction carrying Raskghar moon-lore)
- deep_tunnels `entities[3].observe` — `they are the door — and the lock.` (two-beat punch, new fact)
- barracks `entities[3].observe` — `Duty-mundane... — until it isn't.` (genuine turn)
- guild `entities[2].observe` + runners_guild `entities[2].observe` — signature dashes (convention)

Separator-convention lines (⚑A, bodies verified dash-free, unchanged): inn `entities[2]/[6]/[9]/[10].on_skill_use.toast`, street `entities[15].on_skill_use.toast` (PIN `qa/scripts/crate_light.json:162` unchanged), sewers `entities[1].burn_toast` (PIN `qa/scripts/sewers_walkthrough.json:278` unchanged).

### inn

1. `.maps.inn.entities[1].friendly_line` (2 → 0; restructure kills the paired-dash narration, keeps Lyonette's composure)
- OLD: `Lyonette's chin lifts, then — despite itself — softens. You're kind. People are not, usually, to the help. ...It is a small thing. It is not nothing. Sit where you like; I'll bring something hot.`
- NEW: `Lyonette's chin lifts, then softens despite itself. You're kind. People are not, usually, to the help. ...It is a small thing. It is not nothing. Sit where you like; I'll bring something hot.`

2. `.maps.inn.entities[1].talk_pool_stages[0].lines[0]`
- OLD: `You covered for me. With the order, I mean. You didn't have to — and you didn't make it a story to tell later. That is... rare. Thank you.`
- NEW: `You covered for me. With the order, I mean. You didn't have to, and you didn't make it a story to tell later. That is... rare. Thank you.`

3. `.maps.inn.entities[5].toast`
- OLD: `Faded arcane script — you can't read a word of it. Whoever penned this knew magic you don't. Someone in the city must.`
- NEW: `Faded arcane script. You can't read a word of it. Whoever penned this knew magic you don't. Someone in the city must.`

### inn_upstairs

4. `.maps.inn_upstairs.entities[2].observe`
- OLD: `Lyonette's door, shut the way she shuts most things — completely, and without discussion. Whatever the room looks like behind it, you'll have to imagine it; she's not one to leave doors, or herself, half open.`
- NEW: `Lyonette's door, shut the way she shuts most things: completely, and without discussion. Whatever the room looks like behind it, you'll have to imagine it; she's not one to leave doors, or herself, half open.`

### street

5. `.maps.street.entities[1].observe`
- OLD: `Watch armor, kept. He stands the post properly — weight even, eyes on the gap in the wall. Bored, but the boredom is a discipline, not a lapse.`
- NEW: `Watch armor, kept. He stands the post properly: weight even, eyes on the gap in the wall. Bored, but the boredom is a discipline, not a lapse.`

6. `.maps.street.entities[1].dialogue[0].text`
- OLD: `Keep the gate clear. And if you're headed out — the road's got goblins on it lately. Watch knows. Watch is dealing with it.`
- NEW: `Keep the gate clear. And if you're headed out, the road's got goblins on it lately. Watch knows. Watch is dealing with it.`
- PINS: `qa/scripts/gate_district_walkthrough.json:492`, `qa/scripts/gate_district_walkthrough.json:500` (the :500 pin carries a `Watch Guard: ` prefix — replace the embedded text)

7. `.maps.street.entities[2].observe`
- OLD: `Oldblood Drake, light scales, a scar down the left of her jaw she's long past explaining. She reads the gate the way a clerk reads a ledger — every figure accounted for, and every one of them a suspect.`
- NEW: `Oldblood Drake, light scales, a scar down the left of her jaw she's long past explaining. She reads the gate the way a clerk reads a ledger: every figure accounted for, and every one of them a suspect.`

8. `.maps.street.entities[2].talk_pool_stages[0].lines[2]`
- OLD: `If you're between jobs, see me about bounty work. The Watch pays slow, but it pays — and I sign faster for people who don't invoice me for heroics.`
- NEW: `If you're between jobs, see me about bounty work. The Watch pays slow, but it pays. And I sign faster for people who don't invoice me for heroics.`

9. `.maps.street.entities[3].observe` (2 → 0)
- OLD: `Thin, sky-blue scales, ink drying on three of his claws. A chess board waits at his elbow mid-game — played against himself, to feel how the other side thinks. His eyes are a wild, patterned blue — the one soft thing about a man who counts exits.`
- NEW: `Thin, sky-blue scales, ink drying on three of his claws. A chess board waits at his elbow mid-game, played against himself, to feel how the other side thinks. His eyes are a wild, patterned blue, the one soft thing about a man who counts exits.`

10. `.maps.street.entities[3].friendly_line` (3 → 0 — single worst line in the corpus; stammer preserved with Olesm's own ellipsis idiom)
- OLD: `Olesm brightens like a lamp. Oh — a friendly face. Most people's eyes glaze when I mention troop dispersal. Yours didn't. Would you — that is — care to see the board sometime? No pressure. A little pressure.`
- NEW: `Olesm brightens like a lamp. Oh! A friendly face. Most people's eyes glaze when I mention troop dispersal. Yours didn't. Would you... that is... care to see the board sometime? No pressure. A little pressure.`

11. `.maps.street.entities[3].talk_pool[2]`
- OLD: `Supply lines, sightlines, morale — a city is only a very slow battle, and Liscor has been winning it for centuries. I intend to keep the streak.`
- NEW: `Supply lines, sightlines, morale: a city is only a very slow battle, and Liscor has been winning it for centuries. I intend to keep the streak.`

12. `.maps.street.entities[3].dialogue[0].text` (semicolon — matches his hub line's own punctuation)
- OLD: `One moment — three columns into a tally. Say hello properly and I'll lose my place gladly.`
- NEW: `One moment; three columns into a tally. Say hello properly and I'll lose my place gladly.`

13. `.maps.street.entities[5].toast`
- OLD: `Warm bread smell over the whole row. No one's minding the stall this exact moment — the loaves aren't going anywhere without a fight.`
- NEW: `Warm bread smell over the whole row. No one's minding the stall this exact moment. The loaves aren't going anywhere without a fight.`
- PINS: `qa/scripts/barracks_walkthrough.json:23`

14. `.maps.street.entities[7].toast`
- OLD: `Silverfang goods, honest prices. The Gnoll shopkeeper is off haggling elsewhere — a sign says she remembers faces, and debts.`
- NEW: `Silverfang goods, honest prices. The Gnoll shopkeeper is off haggling elsewhere. A sign says she remembers faces, and debts.`
- PINS: `qa/scripts/gate_district_walkthrough.json:531`

15. `.maps.street.entities[10].talk_pool_stages[0].lines[0]` (Pisces — but this dash was an elaborating continuation, not a pause)
- OLD: `Ah. You. Acceptable timing — I was on the verge of being bored, and you are marginally better than boredom. I do not say that to many.`
- NEW: `Ah. You. Acceptable timing. I was on the verge of being bored, and you are marginally better than boredom. I do not say that to many.`

16. `.maps.street.entities[11].observe` (2 → 1; keeps the earned specification, drops the pair)
- OLD: `Rust holds the bars, not a lock. The draft is steady — a tunnel, not a pit — and the skittering keeps its distance. Something down there has learned to avoid shadows.`
- NEW: `Rust holds the bars, not a lock. The draft is steady — a tunnel, not a pit. The skittering keeps its distance. Something down there has learned to avoid shadows.`

17. `.maps.street.entities[12].talk_pool_stages[0].lines[0]`
- OLD: `Hrr. The crate-finder. Sit, look, touch even — you have earned handling privileges.`
- NEW: `Hrr. The crate-finder. Sit, look, touch even. You have earned handling privileges.`
- PINS: `qa/scripts/stages_loop.json:44`, `qa/scripts/stages_loop.json:45` (the :45 pin carries a `Krshia: ` prefix — replace the embedded text)

18. `.maps.street.entities[15].observe`
- OLD: `A plain door with dark behind it. The dust on the sill is scuffed one way — something was dragged in, and not dragged out.`
- NEW: `A plain door with dark behind it. The dust on the sill is scuffed one way. Something was dragged in, and not dragged out.`

### floodplains

19. `.maps.floodplains.entities[2].observe`
- OLD: `Something square and man-made rests on the pond floor a stride out from the bank, furred with silt. Too far to reach across open water — but water can be made to bear weight, if you know the trick of cold.`
- NEW: `Something square and man-made rests on the pond floor a stride out from the bank, furred with silt. Too far to reach across open water. But water can be made to bear weight, if you know the trick of cold.`

20. `.maps.floodplains.entities[2].toast`
- OLD: `Kneeling on the ice, you lever the silt-caked strongbox free. Drake-work, old, its lock long rusted through — and inside, dry against all odds, a few keepsakes someone drowned here meant never to be found.`
- NEW: `Kneeling on the ice, you lever the silt-caked strongbox free. Drake-work, old, its lock long rusted through. Inside, dry against all odds, a few keepsakes someone drowned here meant never to be found.`

21. `.maps.floodplains.entities[7].observe`
- OLD: `A Drake built like a barracks door, spear worn smooth from use, standing at ease the way only dangerous people stand. He watches the road and everyone on it — including you, now.`
- NEW: `A Drake built like a barracks door, spear worn smooth from use, standing at ease the way only dangerous people stand. He watches the road and everyone on it. Including you, now.`

22. `.maps.floodplains.entities[7].talk_pool_stages[0].lines[0]` (Relc → zero)
- OLD: `Hah! There's my favorite punching bag. Kidding — the dummies are my favorite. You're a close third after lunch.`
- NEW: `Hah! There's my favorite punching bag. Kidding. The dummies are my favorite. You're a close third after lunch.`

23. `.maps.floodplains.entities[7].talk_pool_stages[1].lines[1]` (Relc → zero)
- OLD: `Zevara smiled this week. Actual smile. The warren's sealed and the city's still standing — I'm taking full credit and handing you most of it.`
- NEW: `Zevara smiled this week. Actual smile. The warren's sealed and the city's still standing. I'm taking full credit and handing you most of it.`

### sewers

24. `.maps.sewers.entities[1].locked_toast`
- OLD: `Sodden timber and tarred rope, jammed wall to wall. You could haul at it for an hour, or you could burn it — if you had the means to make fire.`
- NEW: `Sodden timber and tarred rope, jammed wall to wall. You could haul at it for an hour, or you could burn it, if you had the means to make fire.`

25. `.maps.sewers.entities[4].toast`
- OLD: `A ruined crate, half-sunk in silt. Merchant stamps still show under the rot — lost cargo, swallowed by the sewers and picked clean.`
- NEW: `A ruined crate, half-sunk in silt. Merchant stamps still show under the rot: lost cargo, swallowed by the sewers and picked clean.`

26. `.maps.sewers.entities[7].observe`
- OLD: `Two of them, banded carapaces catching the moss-light, waiting where the silk is thickest. Their legs test the air toward you. Behind them the tunnel drops away — and more eyes catch the light down there than you want to count.`
- NEW: `Two of them, banded carapaces catching the moss-light, waiting where the silk is thickest. Their legs test the air toward you. Behind them the tunnel drops away, and more eyes catch the light down there than you want to count.`

27. `.maps.sewers.entities[8].on_skill_use.toast` (2 → 1; separator dash stays per ⚑A, the PROSE dash goes — this was the one separator body violating the zero-prose-dash bar)
- OLD: `[Appraise Foe] — You lie flat on the ledge and read the nest like a map. Two sentries on the silk, a brood-hollow behind them, and a tunnel dropping away toward the Dungeon proper — that's where the rest of them are. Count, size, exits: you have it all, and you never had to draw a blade.`
- NEW: `[Appraise Foe] — You lie flat on the ledge and read the nest like a map. Two sentries on the silk, a brood-hollow behind them, and a tunnel dropping away toward the Dungeon proper. That's where the rest of them are. Count, size, exits: you have it all, and you never had to draw a blade.`
- PINS: `qa/scripts/cisterns_scout.json:52`

28. `.maps.sewers.entities[8].locked_toast`
- OLD: `The ledge overlooks the nest — a perfect vantage, if you had the eye to read one. You don't, quite. Not yet.`
- NEW: `The ledge overlooks the nest: a perfect vantage, if you had the eye to read one. You don't, quite. Not yet.`

29. `.maps.sewers.entities[9].observe`
- OLD: `The floor gave way here, not long ago — a raw crack breathing air colder and older than the sewers ever hold. The claw-scores on its lip all point one way: down. Something climbed up through this, and means to again.`
- NEW: `The floor gave way here, not long ago: a raw crack breathing air colder and older than the sewers ever hold. The claw-scores on its lip all point one way: down. Something climbed up through this, and means to again.`

30. `.maps.sewers.entities[9].toast`
- OLD: `A fresh fissure splits the sewer floor, exhaling a dry, breathing cold from far below. Deep gouges rake the stone lip — something big has been using this as a door.`
- NEW: `A fresh fissure splits the sewer floor, exhaling a dry, breathing cold from far below. Deep gouges rake the stone lip. Something big has been using this as a door.`

### deep_tunnels

31. `.maps.deep_tunnels.entities[1].toast`
- OLD: `A fire-pit ringed with blackened stones, its ashes cold. Whoever tended it had hands enough to strike a spark — and left gnawed bones banked around the edge, cracked for their marrow.`
- NEW: `A fire-pit ringed with blackened stones, its ashes cold. Whoever tended it had hands enough to strike a spark, and left gnawed bones banked around the edge, cracked for their marrow.`
- PINS: `qa/scripts/deep_descent.json:148`

32. `.maps.deep_tunnels.entities[2].observe` (2 → 0)
- OLD: `A midden of cracked bones, marrow sucked clean. Gnoll, most of them. A few too large to name. They have been sorted — almost stacked — as though something down here counts its meals and keeps the score.`
- NEW: `A midden of cracked bones, marrow sucked clean. Gnoll, most of them. A few too large to name. They have been sorted, almost stacked, as though something down here counts its meals and keeps the score.`

33. `.maps.deep_tunnels.entities[2].toast`
- OLD: `A heap of gnawed bones, splintered for their marrow. Some are Gnoll. One is a Drake's. They are stacked, not scattered — and that is worse than if they had been.`
- NEW: `A heap of gnawed bones, splintered for their marrow. Some are Gnoll. One is a Drake's. They are stacked, not scattered. And that is worse than if they had been.`
- PINS: `qa/scripts/deep_descent.json:291`

34. `.maps.deep_tunnels.entities[4].observe`
- OLD: `The passage opens into a vast pillared gallery, its floor packed smooth by generations of pacing feet. Eyes catch your light far back in the dark and slide away. This is where they den — and where the big one waits, breathing slow in the black.`
- NEW: `The passage opens into a vast pillared gallery, its floor packed smooth by generations of pacing feet. Eyes catch your light far back in the dark and slide away. This is where they den, and where the big one waits, breathing slow in the black.`

35. `.maps.deep_tunnels.entities[5].observe`
- OLD: `It fills the gallery mouth like a landslide that learned to breathe — upright, moon-grey, a pale mane over shoulders wider than a doorway. Old scars cross its hide, and a Gnoll's picked bones lie stacked at its feet. Its eyes hold on you with something worse than hunger: thought.`
- NEW: `It fills the gallery mouth like a landslide that learned to breathe: upright, moon-grey, a pale mane over shoulders wider than a doorway. Old scars cross its hide, and a Gnoll's picked bones lie stacked at its feet. Its eyes hold on you with something worse than hunger: thought.`

### guild

36. `.maps.guild.entities[1].observe`
- OLD: `A Drake behind a counter she clearly wishes were taller. Tired, sharp, quick with a ledger — she has sized up a hundred adventurers today and found most of them wanting.`
- NEW: `A Drake behind a counter she clearly wishes were taller. Tired, sharp, quick with a ledger. She has sized up a hundred adventurers today and found most of them wanting.`

37. `.maps.guild.entities[1].talk_pool_stages[0].lines[2]`
- OLD: `Rough week on the board. If you're taking work, take the sane jobs — I flag the sane ones. It's not a service everyone gets.`
- NEW: `Rough week on the board. If you're taking work, take the sane jobs. I flag the sane ones. It's not a service everyone gets.`

38. `.maps.guild.entities[2].toast`
- OLD: `The Request Board. Paper three layers deep in places — new notices pinned straight over the dead ones. Two or three have fresh ink.`
- NEW: `The Request Board. Paper three layers deep in places. New notices pinned straight over the dead ones. Two or three have fresh ink.`

39. `.maps.guild.entities[3].toast`
- OLD: `A second board, smaller and less official — lost gear, room-for-rent scraps, one challenge to a duel that's clearly gone unanswered a long time.`
- NEW: `A second board, smaller and less official: lost gear, room-for-rent scraps, one challenge to a duel that's clearly gone unanswered a long time.`
- PINS: `qa/scripts/guild_interior_walkthrough.json:46`

40. `.maps.guild.entities[3].observe`
- OLD: `Handbills and scraps overlapping the request board's edge — the Guild's actual business spills past its own furniture. Somebody wants a lost warhammer back. Somebody else is renting a room, quiet tenants only.`
- NEW: `Handbills and scraps overlapping the request board's edge. The Guild's actual business spills past its own furniture. Somebody wants a lost warhammer back. Somebody else is renting a room, quiet tenants only.`

### barracks

41. `.maps.barracks.entities[1].talk_pool[0]`
- OLD: `Sergeant Ashgrave. If you're here to report something, the slate's on the wall — write it plain.`
- NEW: `Sergeant Ashgrave. If you're here to report something, the slate's on the wall. Write it plain.`
- PINS: `qa/scripts/barracks_walkthrough.json:62`, `qa/scripts/barracks_walkthrough.json:63` (the :63 pin carries a `Dresk: ` prefix — replace the embedded text)

42. `.maps.barracks.entities[2].observe`
- OLD: `Tidier than her schedule allows. A stack of gate-shift reports pinned under a paperweight shaped vaguely like a threat. She is almost never behind it — the gate keeps her busier than her own office does.`
- NEW: `Tidier than her schedule allows. A stack of gate-shift reports pinned under a paperweight shaped vaguely like a threat. She is almost never behind it. The gate keeps her busier than her own office does.`

43. `.maps.barracks.entities[3].locked_toast`
- OLD: `Barred, and empty behind the bars — you can tell by the quiet. Whatever ends up in here hasn't happened yet.`
- NEW: `Barred, and empty behind the bars. You can tell by the quiet. Whatever ends up in here hasn't happened yet.`
- PINS: `qa/scripts/barracks_walkthrough.json:84`

### runners_guild

44. `.maps.runners_guild.entities[1].talk_pool[0]` (Vess barrels like Relc)
- OLD: `Runner's Guild! Board's live — take a slip, show me, go. Rules, quick: the parcel's yours until it's theirs. Sleep on a run and it comes back here, and you carry the shame instead. No pay for shame.`
- NEW: `Runner's Guild! Board's live. Take a slip, show me, go. Rules, quick: the parcel's yours until it's theirs. Sleep on a run and it comes back here, and you carry the shame instead. No pay for shame.`
- PINS: `qa/scripts/delivery_loop.json:52`

## data/bounties.json — 2 replaced

(`giver` attribution strings; even if currently render-adjacent, hold them to the bar)

1. `.bounties[0].giver`
- OLD: `The Watch (duty-sergeant's hand — terse, no wasted ink)`
- NEW: `The Watch (duty-sergeant's hand, terse, no wasted ink)`

2. `.bounties[1].giver`
- OLD: `Watch Captain Zevara Sunderscale (dry, overworked, duty-first — longer hand than the sergeant's, and tired)`
- NEW: `Watch Captain Zevara Sunderscale (dry, overworked, duty-first; longer hand than the sergeant's, and tired)`

## data/deliveries.json — 2 replaced

1. `.deliveries[0].slip_copy` (dispatch register: full stops)
- OLD: `TO: Silverfang stall, market row. One wool bolt. Same waking. The Gnoll pays for dry, not for fast — it rains here, keep the paper on it.`
- NEW: `TO: Silverfang stall, market row. One wool bolt. Same waking. The Gnoll pays for dry, not for fast. It rains here, keep the paper on it.`

2. `.deliveries[2].slip_copy`
- OLD: `TO: Watch Captain Sunderscale, the gate. Dispatches. Priority. If a guardsman stops you, show the seals and keep walking — that is what the seals are FOR. Before the shift bell.`
- NEW: `TO: Watch Captain Sunderscale, the gate. Dispatches. Priority. If a guardsman stops you, show the seals and keep walking. That is what the seals are FOR. Before the shift bell.`

## data/items.json — 5 replaced (lore = resident diction, dash-free)

1. `.items[2].lore`
- OLD: `Goblin forges run on scavenge — plow edges, cartwheel rims. Whoever hammered this understood one thing about swords, and it was the edge.`
- NEW: `Goblin forges run on scavenge: plow edges, cartwheel rims. Whoever hammered this understood one thing about swords, and it was the edge.`

2. `.items[7].lore`
- OLD: `The old stones outside the city give up trinkets like this after a hard rain, and nobody living remembers who strung them. Hold it to your ear and it hums, faintly — most owners decide not to ask a second question.`
- NEW: `The old stones outside the city give up trinkets like this after a hard rain, and nobody living remembers who strung them. Hold it to your ear and it hums, faintly. Most owners decide not to ask a second question.`

3. `.items[8].lore`
- OLD: `Silverfang steel comes south with the tribe's caravans and gets worked plains-side, the old way, before it ever sees a city stall. Krshia could sell three times what her kin send her — she says so to anyone who buys one.`
- NEW: `Silverfang steel comes south with the tribe's caravans and gets worked plains-side, the old way, before it ever sees a city stall. Krshia could sell three times what her kin send her. She says so to anyone who buys one.`

4. `.items[9].lore`
- OLD: `Plains wool, city loom — Gnoll caravans sell the fleece and Drake weavers argue the price, and the cloak comes out warmer than the bargaining. The Floodplains rain finds every cheaper seam.`
- NEW: `Plains wool, city loom: Gnoll caravans sell the fleece and Drake weavers argue the price, and the cloak comes out warmer than the bargaining. The Floodplains rain finds every cheaper seam.`

5. `.items[14].lore`
- OLD: `Shed scales with stone in them turn up in the southern hills, and enchanters pay well for the rare one that takes a binding. Drakes find wearing another Drake's scale distasteful — the stall keeps this one under the counter.`
- NEW: `Shed scales with stone in them turn up in the southern hills, and enchanters pay well for the rare one that takes a binding. Drakes find wearing another Drake's scale distasteful; the stall keeps this one under the counter.`

## data/skills.json — 4 replaced (descriptions only; all `field_ambient`/`freeze_toast` separator lines unchanged per ⚑A, bodies verified dash-free)

1. `.skills[30].description` ([Appraise Foe])
- OLD: `A measuring look that reads a room, a person, a problem — and files it away for later.`
- NEW: `A measuring look that reads a room, a person, a problem, and files it away for later.`

2. `.skills[32].description` ([Soothe Clientele])
- OLD: `A word and a refilled glass, and the room's troubles ease — patrons forget whatever was gnawing at them.`
- NEW: `A word and a refilled glass, and the room's troubles ease. Patrons forget whatever was gnawing at them.`

3. `.skills[33].description` ([Unerring Aim])
- OLD: `Whatever you throw finds its mark — a mug slid down the bar, a rag, or a troublemaker's head.`
- NEW: `Whatever you throw finds its mark: a mug slid down the bar, a rag, or a troublemaker's head.`

4. `.skills[35].description` ([Server's Prescience])
- OLD: `You know what a guest wants before they raise a hand — the empty cup, the missing fork, the order about to be called.`
- NEW: `You know what a guest wants before they raise a hand: the empty cup, the missing fork, the order about to be called.`

## data/arenas.json — 10 replaced (Relc tutor lines → zero dashes)

### arenas[2] (training_yard)

1. `.arenas[2].tutor_lines[0].line`
- OLD: `Relc: Loose grip, dead stance — we'll fix both. Arrows move you. Three easy steps a turn, so use your legs before anything fancy.`
- NEW: `Relc: Loose grip, dead stance. We'll fix both. Arrows move you. Three easy steps a turn, so use your legs before anything fancy.`

2. `.arenas[2].tutor_lines[1].line`
- OLD: `Relc: That's walking. Now get next to one and press 1 — that's your arm. Numbers are your moves, remember them.`
- NEW: `Relc: That's walking. Now get next to one and press 1. That's your arm. Numbers are your moves, remember them.`

3. `.arenas[2].tutor_lines[2].line`
- OLD: `Relc: Steps run out, see? Slot 2 — [Dash]. Costs you wind, buys you stride.`
- NEW: `Relc: Steps run out, see? Slot 2: [Dash]. Costs you wind, buys you stride.`

4. `.arenas[2].tutor_lines[3].line`
- OLD: `Relc: And the legs are back. Wind for stride — that trade wins fights.`
- NEW: `Relc: And the legs are back. Wind for stride. That trade wins fights.`

5. `.arenas[2].tutor_lines[5].line`
- OLD: `Relc: Ha! Straw everywhere. When you're spent, press E — end your turn on YOUR terms.`
- NEW: `Relc: Ha! Straw everywhere. When you're spent, press E. End your turn on YOUR terms.`

6. `.arenas[2].tutor_lines[7].line`
- OLD: `Relc: Not bad for someone who smells of dish soap. Sleep is where a fight settles into your bones — do that. Then come see me; I owe you something.`
- NEW: `Relc: Not bad for someone who smells of dish soap. Sleep is where a fight settles into your bones. Do that. Then come see me; I owe you something.`

### arenas[3]

7. `.arenas[3].tutor_lines[0].line`
- OLD: `Relc: Real ones this time — stay behind me if you have to. You slept, so check your numbers: 3 and up are your [Skills] now. Earned, not given.`
- NEW: `Relc: Real ones this time. Stay behind me if you have to. You slept, so check your numbers: 3 and up are your [Skills] now. Earned, not given.`

8. `.arenas[3].tutor_lines[1].line`
- OLD: `Relc: That one puts everything behind one blow. What your slots hold follows the weapon you carry — sword skills for a sword arm, spear skills for mine.`
- NEW: `Relc: That one puts everything behind one blow. What your slots hold follows the weapon you carry: sword skills for a sword arm, spear skills for mine.`

9. `.arenas[3].tutor_lines[2].line`
- OLD: `Relc: THAT'S the stuff. Attacks keep you alive — [Skills] win the fight. Sleep grows both.`
- NEW: `Relc: THAT'S the stuff. Attacks keep you alive. [Skills] win the fight. Sleep grows both.`

10. `.arenas[3].tutor_lines[3].line` (2 → 0)
- OLD: `Relc: Road's clear. Liscor's through the gate — tell the Watch that Relc let you pass. See the sign? Her inn, her rule — but under her roof? Don't.`
- NEW: `Relc: Road's clear. Liscor's through the gate. Tell the Watch that Relc let you pass. See the sign? Her inn, her rule. But under her roof? Don't.`

## data/classes.json — 1 replaced

`.classes[2].aspiration.text`
- OLD: `Far down this road waits the title of [Swordmaster] — earned by certification, or by defeating one.`
- NEW: `Far down this road waits the title of [Swordmaster], earned by certification, or by defeating one.`

## src/ui/sleep_veil.gd — 0 replaced

GDI opener/epilogue proclamations are already dash-free. `EPILOGUE_LINK_LINE`
(`"— The story continues at wanderinginn.com —"`, line 135) uses paired framing
dashes as typography (a "— fin —" frame, not prose) and is user-approved verbatim
copy from `docs/design/gdi-copy-staging.md` (2026-07-07, same day as this ruling).
KEPT; listed as ⚑D pro forma. (The file's other dashes are code comments — out of scope.)

## src — player-facing string literals (addendum; found via pin-trace, same corpus family)

The sweep of QA pins surfaced player-facing dialogue that lives in code, not data
(Selys board lines in `src/core/bounties.gd`, Vess counter lines in
`src/core/bounties.gd`/`src/core/wi_game.gd`, system toasts). Staged here so the
corpus pass is actually corpus-wide. Keybind/label separators (`Press I — your pack.`,
`Esc — menu ...`, `Autosaved. (Esc — save/load anytime)`, `Dash — %d AP: ...`,
`▼  more — press Enter`, `%s hesitates — %s.`) fall under ⚑A and are unchanged.

KEPT (earned): `src/core/bounties.gd:139` — `Done? …So it is. Here — counted twice, because the last adventurer counted once, loudly, and was wrong. ...` —
Selys's coin-shove gesture dash (same beat as Lyonette's, ⚑C). Pins unchanged:
`qa/scripts/board_loop.json:106`, `qa/scripts/dp2_fixwave_absolute_verify.json:27`.

1. `src/core/bounties.gd:90` (Selys)
- OLD: `That one? Fine. Logged. Don't die over a handful of gold — it's paperwork for me and embarrassing for you.`
- NEW: `That one? Fine. Logged. Don't die over a handful of gold. It's paperwork for me and embarrassing for you.`
- PINS: `qa/scripts/board_loop.json:50`, `qa/scripts/board_loop.json:138`

2. `src/core/bounties.gd:156` (Selys)
- OLD: `Hand it back? Fine. I'll cross it off — no pay, no mark against you. It goes back on the board for someone with follow-through.`
- NEW: `Hand it back? Fine. I'll cross it off: no pay, no mark against you. It goes back on the board for someone with follow-through.`
- PINS: `qa/scripts/board_loop.json:148`

3. `src/core/bounties.gd:170` (Vess)
- OLD: `Gate, floodplains, the hill. Two legs and the road's got goblins, which is why it pays three. Runners move FAST — that's the whole trade. Fast things don't get grabbed.`
- NEW: `Gate, floodplains, the hill. Two legs and the road's got goblins, which is why it pays three. Runners move FAST. That's the whole trade. Fast things don't get grabbed.`

4. `src/core/bounties.gd:214` (Vess)
- OLD: `Slip says the mark, not the counter. I can't pay you for carrying it AROUND, that's just… walking. Go on — daylight's a budget.`
- NEW: `Slip says the mark, not the counter. I can't pay you for carrying it AROUND, that's just… walking. Go on. Daylight's a budget.`

5. `src/core/bounties.gd:216` (Vess; 2 → 1 — keeps the genuine mid-officialese laugh-interruption)
- OLD: `Mark confirmed — hah — sorry, came in at a sprint myself. Coin's counted. Nice legs on that run. Hawk started on a board like this one, you know. Well. A board LIKE it.`
- NEW: `Mark confirmed. Hah — sorry, came in at a sprint myself. Coin's counted. Nice legs on that run. Hawk started on a board like this one, you know. Well. A board LIKE it.`
- PINS: `qa/scripts/delivery_loop.json:106`

6. `src/core/wi_game.gd:1412` (board-refresh toast)
- OLD: `New paper went up this morning. Old postings come down whether they're done or not — ink's cheap, wall space isn't.`
- NEW: `New paper went up this morning. Old postings come down whether they're done or not. Ink's cheap, wall space isn't.`

7. `src/core/wi_game.gd:1557` (Vess)
- OLD: `Parcel came back on the night ledger. Happens. Happens ONCE, usually. Board's still live — take another slip and run it like you mean it.`
- NEW: `Parcel came back on the night ledger. Happens. Happens ONCE, usually. Board's still live. Take another slip and run it like you mean it.`
- PINS: `qa/scripts/delivery_loop.json:150`, `qa/scripts/delivery_loop.json:164`

8. `src/core/wi_game.gd:1920` (system toast)
- OLD: `No room left for another charm — something has to come off first.`
- NEW: `No room left for another charm. Something has to come off first.`
- PINS: `tests/test_sim_core.gd:1084`

9. `src/core/wi_game.gd:2369` (consolidation flavor suffix)
- OLD: ` The change came later than most — but it holds all the same.`
- NEW: ` The change came later than most, but it holds all the same.`
- NOTE: leading space is part of the string — preserve it.

10. `src/ui/consolidation_prompt.gd:97` (system dream copy)
- OLD: `You dream of two roads becoming one. [%s] and [%s] could consolidate into [%s] — or hold to their own shapes.`
- NEW: `You dream of two roads becoming one. [%s] and [%s] could consolidate into [%s], or hold to their own shapes.`

11. `src/ui/title_screen.gd:263` (system notice)
- OLD: `Save is from an older version — start a New Game`
- NEW: `Save is from an older version. Start a New Game`

12. `src/ui/pause_menu.gd:28` (system prompt; `\n` is part of the string — preserve it)
- OLD: `Unsaved progress since the\nlast autosave is lost — quit?`
- NEW: `Unsaved progress since the\nlast autosave is lost. Quit?`

13. `src/core/field_skills.gd:167` (system toast; the period fragment keeps the ominous beat)
- OLD: `Frost races across the water and locks it solid. You can cross now — until it thaws.`
- NEW: `Frost races across the water and locks it solid. You can cross now. Until it thaws.`

---

## ⚑ Adjudication items (user rules on these; everything else applies mechanically)

- **⚑A — Label-separator dash convention** (`[Skill] — body`, `N AP — effect`,
  keybind hints, class-gained/level-span toasts). Recommendation: exempt as
  structure, keep. Alternative: global switch to colon — a separate code+data+test
  migration (touches `effect_text.gd`, `progression.gd`, `journal.gd`,
  `field_hotbar.gd`, `combat_hud.gd`, `message_layer.gd`, ~30 data strings, ~40 pins).
- **⚑B — Zevara's gratitude-choke tic**, 3 kept instances of the same construction:
  `But — thank you.` (zevara_intro `zevara_oath_two`), `And — thank you. Genuinely.`
  (skeleton street `entities[2].friendly_line`), `And — good work.` (zevara_intro
  `swept`). Judged an earned, deliberate character tic (she physically balks at
  saying it), but it IS the same dash three times on one character — cut to one
  survivor if that still reads as serial.
- **⚑C — The gesture dash** (`— Here.` / `Here —` while handing something over):
  Lyonette (`lyonette_tip` `gratitude`, pinned `wrong_order_loop.json:79`), Lyonette
  (skeleton inn `talk_pool[2]` `— Well.`), Selys (`bounties.gd:139`). Kept — a real
  physical beat, not rhythm — but it's the same device on two characters; user call.
- **⚑D — `EPILOGUE_LINK_LINE`** framing dashes (sleep_veil.gd:135): typographic
  frame, user-approved verbatim same day as the ruling. Kept; flag pro forma.

## Summary

| | count |
|---|---|
| Lines examined (containing at least one em-dash, player-facing) | 183 (+ ~36 separator-convention lines under ⚑A) |
| Lines with staged replacements | **155** |
| — of which multi-dash lines cut to one earned dash | 8 |
| — of which multi-dash lines cut to zero | 7 |
| Lines left as earned (incl. canon sign, signatures, cut-off dash) | 28 |
| ⚑ adjudication items | 4 (⚑A convention, ⚑B Zevara tic, ⚑C gesture dash, ⚑D link line) |
| Replacement lines with QA/test pins to move in the same pass | 24 old-strings across 30 pin sites (each listed inline above) |

Worst offenders (pre-pass dash count): `data/skeleton_scene.json` (72),
`data/dialogue/olesm_intro.json` (28), `data/dialogue/krshia_crate.json` (22).

**Implementer checklist**: apply pairs top to bottom (plain find/replace, whole-string
match); apply every `PINS:` edit in the same commit; then `qa/run_qa.sh` the pinned
scripts (`combat_walkthrough`, `relc_tutorial`, `stages_loop`, `d2_shop_shot`,
`board_loop`, `delivery_loop`, `barracks_walkthrough`, `gate_district_walkthrough`,
`deep_descent`, `cisterns_scout`, `guild_interior_walkthrough`, `wrong_order_talk`,
`economy_loop`, `dialogue_walkthrough`, `quest_errand_parley`, `quest_errand_fight`,
`save_load_roundtrip`, `status_first_encounter`, `dialogue_hub_loop`,
`dp2_fixwave_absolute_verify`) plus the unit suites, grepping runs for `SCRIPT ERROR`
per the verification skill. Every NEW line above was written against the full voice
lint (no banned tells introduced; no elaborating continuations survive; surviving
dashes are one-per-line and earn their interruption).

## Controller adjudications (2026-07-07, apply-wave = zero open questions)
- (A) Label-separator convention (`[Skill] — body`, `N AP — effect`):
  EXEMPT. UI grammar, not prose; a colon migration is its own
  code+data+test change with no prose-quality payoff.
- (B) Zevara's gratitude-choke dash (×3): keep ONE (the strongest beat,
  the apply wave picks the earliest), replace the other two per the
  staged alternatives.
- (C) The shared hand-over gesture dash (Lyonette + Selys): keep
  Lyonette's (composed-gesture is HER register), replace Selys's.
- (D) The wanderinginn.com frame line: KEEP verbatim (user-approved
  copy).
