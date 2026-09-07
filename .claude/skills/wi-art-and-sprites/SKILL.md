---
name: wi-art-and-sprites
description: Select, create, register, license, and verify sprites, icons, props, tiles, and visual states.
---

# Add art or sprites

Read `docs/asset-catalog.md` for qualitative fit, then the asset index for exact
paths/dimensions, the scene assembly guide for composition, and
`data/sprites.json` for existing registrations. Do not guess atlas coordinates
or browse whole source packs into context.

Use the highest-fidelity suitable asset available. Furniture and obstacles use
real prop silhouettes, not recolored terrain. A functional or named identity
needs a distinct silhouette; tint only supplies cosmetic variety within one
kind. Player `pc_*` sprite IDs remain exclusive to the player. One rig backs at
most one named character; anonymous extras may share when they remain readable
and canon-compatible.

Measure transparent alpha bounds before setting an anchor. The anchor targets
the actual feet plane, not the frame bottom; verify the character appears
physically adjacent to its logical interaction cell. Tall field sprites may use
a combat-only scale so they do not cover bars or neighbors. Interactive props
must be visible at a glance and solid-looking art must match map blocking.

Treat capability-dependent generation as optional. If an image-generation or
PixelLab tool is actually available, derive prompts from the character profile,
produce directional animation for characters, keep small props/icons simple,
and use larger concept-to-pixel workflows for landmarks. Bound polling and
download results promptly. If these tools are absent, select from licensed
in-hand assets or prepare a concrete generation brief; absence does not block
unrelated implementation.

Never track `potential_assets/` or a manifest-listed private asset. Public-safe
art may commit with its license/provenance record. Redistribution-limited art
ships through the private bundle with a committed fallback and follows
`wi-shipping`. Flag any quality-for-licensing substitution to the user.

Register the sprite, update expected-frame tests and all consumers, import new
images, run leak/data/preflight and affected QA gates, then capture the same
route windowed with the real overlay. Read the screenshot for crop, scale,
anchor, animation, palette, semantic fit, occlusion, affordance, and first-time
clarity. New generation/art direction that requires taste goes to the user with
a prepared comparison. Read [references/asset-recipes.md](references/asset-recipes.md)
for registry and generation details.
