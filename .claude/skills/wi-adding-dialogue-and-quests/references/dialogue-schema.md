# Dialogue and quest schema

A conversation file defines `start` and a `nodes` map. Nodes have speaker/text,
optional ordered `text_variants`, and visible options. Options may have text,
`requires`, `hide_when`, effects, and exactly one destination: `goto` or
`end: true`.

Basic gates use one semantic key: skill, class/level, or accomplishment/count.
The validator owns the small sanctioned compound set (for example a stage plus
skill, or stage plus gold). Inspect `_validate_requires`, `_meets`, and
`_requirement_text` before creating a compound; do not infer arbitrary AND
semantics. Hidden options are removed before index calculation. Always provide
an ungated exit from a conditionally hiding hub.

Effects may bank accomplishments, start quests, remove entities, change gold or
items, and start combat. Inspect `WIGame.dialogue_choose` and its tests for the
current supported set. Combat starts only from an ending option. An `end: true`
choice emits dialogue-ended before its effects; a `goto` applies effects before
the later end.

A priced row shaped as gold requirement plus matching negative-gold effect is a
purchase offer; confirmation applies all effects, including end. Narrative
spending uses the supported `spend` category. Hide a consuming/granting option
when the unique output is already held, or grant a distinct output, so duplicate
inventory cannot consume value for nothing.

Quests contain ID/title and ordered beats with completion predicates. Evaluation
returns the first unmet beat and completed state from current accomplishments.
Shipped quest, item, map, and accomplishment IDs are frozen. New producers must
be discoverable by content/reachability/shipped-ID validators.
