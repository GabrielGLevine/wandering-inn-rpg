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
| invrisil | shop_door | invrisil_shop_door, invrisil_shop_door_1, invrisil_shop_door_2 | 3 | pool has no ready shopfront door; the only candidate shape (6, green double door) is buried in a stacked slice; the owned shopfront_door (door_street 3) is the real shop door and is absent from this pool [shopfront_door is the art of the current invrisil_shop_door] | invrisil_shop_door | done invrisil_shop_door, invrisil_shop_door_1, invrisil_shop_door_2 |
| invrisil | facade_panel | - | 4 | the pool is round fence posts and plank strips; there is no wall module (timber-frame panel, plaster, or masonry) that tiles beside the existing windows and doors. Current invrisil_timber_panel stays by default. | invrisil_timber_panel | open |
| invrisil | roofline | - | 3 | neither pool contains a roofline module (eave, slate, tile, parapet). Current invrisil_roofline stays. | invrisil_roofline | open |
| invrisil | lamp_street | - | 2 | no tall, formal post lamp in the navy-and-brass family of the boulevard; 7 is the only standing lamp and it is short and rough. Current street_lamp stays. | street_lamp | open |
| invrisil | shop_sign | invrisil_hanging_sign, invrisil_shop_sign_1 | 3 | a third readable shop sign without inn lettering | invrisil_hanging_sign | open |
| invrisil | door_street | door, invrisil_door_street_2, invrisil_door_street_3, invrisil_door_street_4 | 1 | a second OWNED street door so the public build keeps door variety (official build already has pack variety) | owned_fallback_door | open |
| invrisil | standin_good_vantage | - | 1 | pool has no neat multi-crate freight stack. Needed: two tidy waist-high stacks (2-3 strapped/stencilled shipping crates each) with a one-tile gap, wall-attached, clean enough for the marble boulevard, 48x32 or 64x32 footprint, no heavy black outline so it does not read as the alley pack crate. Leads: owned lift_cargo_pallet (strapped + tagged, 64x64) and set_pieces/dock_cargo_pile (112x80) were not on any sheet and could not be judged. Current crate stays. | crate | open |
| invrisil | standin_shadowed_nook | - | 1 | a nook is architecture, not a container; the pool holds only containers and cemetery props. Needed: a wall-attached dark recess (arched or square niche, 16x32 or 32x32) in the alley's blue-grey brick with a deep shadow interior and a sliver of lit edge, so it reads as somewhere to stand rather than something to loot; selection/focus must stay the only bright element. Current crate stays. | crate | open |
| invrisil | standin_sealed_bale | - | 1 | no cloth/goods bale in the pool. Needed: a rectangular pressed bale in burlap or canvas, cross-corded, with a red/dark wax factor's seal and two pinned paper tallies visible on the top face, 32x32, muted Invrisil palette, silhouette squarer and lower than a sack and flatter than a crate. Reference: owned 32x32 item icon sealed_factor_bale (READY, inventory angle not top-down). Current crate stays. | sealed_factor_bale | open |
| invrisil | shop_door | invrisil_shop_door, invrisil_shop_door_2 | 3 | #608 art read dropped the glazed invrisil_shop_door_1: its glass top on the glass shopfront band read as a window, not a threshold. Needed: a third solid shopfront door (frame, handle, step) that reads as an entrance against glass. | invrisil_shop_door | open |
| invrisil | curb_marble | - | 2 | #608 art read: the boulevard's marble square has no curb or paving-transition tiles, so the marble patch reads as a hard-edged lighter rectangle under the fountain. Needed: marble-to-street curb edges and corners in the boulevard's pale stone. | tileset_marble_wang4x4 | open |
| invrisil | lamp_wall | sconce, invrisil_lamp_wall_1 | 3 | #608 art read: there is no wall lantern with a bracket, glass and flame for the alleys, and the public fallback reads as a floating yellow blob. Needed: a wall-mounted lantern, plus an owned version that can serve as the public fallback. | sconce | open |
| invrisil | workbench | - | 1 | #608 art read: the alley workbench cluster reads as a grey tool jumble. Needed: a grouped workbench set-piece (bench, vice, tools) built as one prop. | - | open |
| invrisil | paving_apron | - | 1 | #608 art read: the cross-street's dark paving blocks read as unfinished patches; a 1-cell curb or edge would make them read as shop aprons. Needed: a curb or apron edge around them. | - | open |
