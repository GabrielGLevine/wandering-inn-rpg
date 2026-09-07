# Progression schema and registration

Classes contain `stat_growth`, optional `gained_by.accomplishment`, `inherits`,
optional `evolution`, and ordered `levels` with `level`, `requires` or
`requires_any`, and `grants`. `requires_any` succeeds when one branch clears;
an empty map does not grant a free level.

Evolution considers its configured level, use threshold, dominance rule,
targets, and balanced grants. A dominant branch replaces the class; a balanced
branch preserves generalist identity and must flow through `granted_skills`.
Consolidation rows contain `parent_lines`, minimum parent/combined levels, and
target. Derive merge floors using `WIProgression._consolidation_merged_level`.

For a new lineage-specific consolidation target, first identify the existing
rule the pair falls through to. That baseline is the mechanical anchor: copy its
growth and level-requirement curve, and mirror the granted skill’s costs,
effects, cooldown, and weapon-gating presence. Change only lineage identity,
canon flavor, description, and distinct icon/art unless the issue separately
authorizes balance. `inherits` names the two held parents. The narrow new row
must precede the broad baseline row and be pinned in both parent directions.

Skills contain ID/display name, contexts, optional AP/MP costs, optional combat
weapon, field weapon where applicable, icon, effect, and description. Read the
effect parser/tests for the current supported effect types rather than extending
from a prose list. Hotbar skills need registered icons. Player descriptions use
canon prose and visible stat grammar.

Registration surfaces commonly include effect-text expected rows, combat data
validation, sprite expected frames, fixture coherence, dialogue skill gates,
manifest/derived QA surfaces, hotbar slot pins, combat spine loadouts, and
shipped-ID producer scans. Find sibling registrations in the current source.
Code-banked accomplishment literals must be visible to both the shipped-ID
generator and its test. Edit mixed-format shipped JSON surgically, preferably
with `scripts/splice_json.py`.
