# Art generation list (living)

Rows are PixelLab generation requests the asset pool could not fill. Nothing
here is generated until the user approves a batch (regional kits spec §4.3,
Phase 3). `tools/fill_kit.py` appends a row when a role's selection falls short
of `--need`; `what the pool lacked` is the `--lacked` text the selecting agent
wrote after the pool read.

Insertion: tail — append rows at the end; one open row per (region, role) is
updated in place; a row closes by setting status to `done <sprite ids>` in the
batch PR, never by deletion.

Columns: region · role · have (ids already in the pool) · need (target pool
size) · what the pool lacked · base sprite (existing sprite id to derive
PixelLab object-state variants from) · status (`open` | `done <ids>` | `dropped`).

| region | role | have (ids) | need | what the pool lacked | base sprite | status |
|---|---|---|---|---|---|---|
