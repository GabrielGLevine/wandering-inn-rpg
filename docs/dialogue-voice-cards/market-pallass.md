# Cluster: market-pallass — T2 clerk + T4 watchgolem bark

Read `docs/dialogue-voice-bible.md` first. The stamp clerk is Pallass officialese with a repressed sense of procedure-as-honor; the golems are a bark-class encounter. Antithesis grants: zero for both.

## pallass_market_clerk.json

**BANNED:** Ban 2: "The tier doesn't sleep, and neither, apparently, do you." (hub tv[0] — quip on a hub variant; dies). Ban 1-adjacent: "That is a real document and it is not nothing." (`queue_entry`) — defensive balance; dies (see sample). Watch-list: "I don't set the price and I don't move it, whatever they taught you to say back home." — anaphora-lite but genuinely clerkish; keep. "State whatever this window is for." (hub tv[4]) — dry; keep, it is impatience not wit. "do not say I sent you, because I did not, I endorsed." (`queue_entry_done`) — the endorse/sent distinction is procedure-pedantry, not the bureaucracy gag; keep but do not sharpen it.

**FORCED:** Window officialese: sponsor, posted rate, entry side, countersign. Impatience beats: at least one sentence cut short by the next customer's existence. PEAK: no button — this window does not do landings.

**CANON-VOICE:** A market-tier stamp clerk of Pallass. Believes the paper system is what keeps nine tiers from falling on each other, and is not entirely wrong. Rude by economy, not malice; a correct document is the only compliment he pays.

**SAMPLE:** node `queue_entry` —
> Before: `Held correctly. The entry side is mine and the entry side is clear. What is not clear is the release side, and I cannot endorse a release I do not hold. I can endorse that the entry is clean. That is a real document and it is not nothing.`
> After: `Held correctly. The entry side is mine, and the entry side is clear. The release side is the forge office's, not this window's. I can endorse the entry as clean. Take that to the permit window and ask for the countersign. Next.`

The defensive balance dies; a plain instruction and a "Next." take the slot — the queue never stops.

## market_watchgolems.json

**BANNED:** Bark-class; nothing on the hard list — this bark already avoids the understatement template. Do not import one.

**FORCED:** Shape: **stillness-then-simultaneity** — the wrongness is that two things move as one. Keep the permit-read option flavor intact ("Let the carving read it" is mechanical instruction). 2–4 sentences, no verdict closer.

**CANON-VOICE:** Narrator, paired Watch-golems on stall duty in Pallass. Municipal constructs: not menacing, not curious — on schedule. The unease is procedural.

**SAMPLE:** node `confront` —
> Before: `Two grey shapes flank a stall of unclaimed crates, carved plating catching the tier's flat light. Neither has moved in the time you've watched. Both turn to face you at once.`
> After: `Two grey shapes flank a stall of unclaimed crates, carved plating catching the tier's flat light. Neither has moved since you first looked. Both faces come around to you at the same moment, on the same silent hinge.`
