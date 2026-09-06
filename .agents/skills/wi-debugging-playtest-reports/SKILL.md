---
name: wi-debugging-playtest-reports
description: Diagnose a human-reported gameplay failure that green QA did not expose.
---

# Debug the gap between QA and play

Treat the report as correct about the player experience. Green QA may still be
correct about the logic it exercised; locate the missing layer before changing
code.

1. Reproduce the exact route, input, position, timing, save state, and visible
   outcome. Ask only for a missing fact that prevents reproduction.
2. Prove the sim with the cheapest pure test or temporary probe that constructs
   `WIGame` with injected configuration and drives the relevant method. If the
   sim fails, diagnose and fix the pure mechanism.
3. Prove the production input path with QA that walks the reported route using
   real input and asserts intermediate cells/state. Do not substitute teleport,
   direct mutation, mouse, or zero-delay test hooks for a report about doors,
   touch, or timing.
4. Prove presentation and perception windowed. Capture the exact state and read
   it. Compare logical cells/blocking with what is drawn; inspect alpha bounds,
   anchors, scale, layering, affordance, animation, and feedback. Use pixel or
   event measurements when eyes alone are ambiguous.
5. Form one falsifiable hypothesis, run the cheapest decisive probe, fix the
   root cause, add regression coverage at the missing layer, then route final
   evidence through `wi-verifying-changes`.

Common gaps: a padded sprite visually occupies a different cell; solid-looking
decor does not block; a small/occluded prop cannot be found; route assertions
rely on an old bump stop; presentation removes delays under TestDriver so a
tween bug disappears; an explicit input produces no visible response; touch
evidence was actually a mouse click.

If behavior depends on Godot internals, inspect the source matching the installed
engine version when available and cite the relevant file/line. Keep a useful
new failure class as a concise durable trap in the closest project reference;
do not append incident history.
