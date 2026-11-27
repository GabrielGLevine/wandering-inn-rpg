# Art bundle pending (living)

Pack slices that `tools/wire_asset.py` refused to wire because their source
sheet is not under `wandering_inn_game/assets/` (exit 3, `BUNDLE-PENDING
<source_sheet>`). Pack art may only be wired as a `region` row on an
already-bundled sheet; a new sheet needs a manifest row and a private bundle
release (`wi-shipping`), which Phase 0 does not allow, so the request waits here.

Insertion: tail — append rows; delete a row in the commit that wires its
candidate. One row per candidate path.

Columns: date · source_sheet (pack path under `potential_assets/`) · candidate
(the slice PNG) · sprite_id (the id the wiring asked for) · region ([x, y, w, h]
on the source sheet).

| date | source_sheet | candidate | sprite_id | region |
|---|---|---|---|---|
