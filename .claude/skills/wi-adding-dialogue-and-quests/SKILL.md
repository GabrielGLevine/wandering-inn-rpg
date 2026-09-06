---
name: wi-adding-dialogue-and-quests
description: Add or edit conversations, option gates/effects, quests, and character copy.
---

# Add dialogue or quests

`WIDialogue` is a pure graph walker that returns effects; `WIGame` applies them
and refreshes context on every node advance. `WIQuests` derives ordered beats
from accomplishment counters and does not store separate quest progress.

Start with narrative purpose, emotional target, lore dependencies, and any new
canon. Verify canon and first appearance against the Wiki and
`docs/design/spoiler-cutoff.md`; ambiguous post-cutoff material does not enter
new content. Read `docs/design/character-profiles.md` before writing a character.
Check all their existing dialogue, pool, observe, friendly, and quest lines for
voice/fact consistency.

Quest paths need real stages and real cost: distinct locations/interactions and
state changes, with social skill, gold, combat risk, or exploration doing useful
work. A gated skill may skip friction but cannot auto-resolve the quest. Gate
social verbs on an appropriate shipped `[Skill]` when one embodies the action;
class identity gates need a specific reason. A single-task interaction belongs
as a posting/job rather than a multi-stage quest.

Author gates against the visible option list. Accomplishment and boolean gates
hide unmet options; skill/class gates may remain visible-locked. Nodes with
conditional hiding keep an always-available exit. Read the full existing
`text_variants` list before appending because later matching variants win.
Avoid adding purchases/options to hubs pinned by canonical routes; prefer a
separate entity/conversation when existing visible indices or exact arrays would
change.

Priced purchases use the confirmation modal. Other negative-gold narrative
choices use the supported spend tag. A purchase applies nothing until confirmed.
Ending options emit dialogue-ended before their returned effects are applied;
QA waits follow the actual event order.

Write spoken language in the profile’s register. Avoid stock narration,
brochure voice, named emotions, rhetorical openings, symmetric/triadic filler,
and explanatory dash tails. Most lines use no em dash and no more than one.
Hub exits should sound like the character, not a shared template. Bracketed
verbs name real gates, never decoration.

Run data lint, dialogue/content/reachability/shipped-ID tests, affected QA, full
preflight/sweep, and a windowed line/options read. Assert the real interaction,
domain events, exact rendered line/options, costs, and state. Read
[references/dialogue-schema.md](references/dialogue-schema.md) for graph/gate/
effect details and [references/canon-and-voice.md](references/canon-and-voice.md)
before content delivery. Read
[references/pools-and-postings.md](references/pools-and-postings.md) when
editing ambient pools, staged barks, boards, desks, bounties, or leads.
