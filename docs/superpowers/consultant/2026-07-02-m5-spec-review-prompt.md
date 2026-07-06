# Consultant prompt — M5 spec adversarial review

(Repo access: you have read access to the GitHub repository. Everything referenced is on
`main`. Start with this file's parent repo layout note below.)

You are an external senior game-tech consultant reviewing a milestone design spec for a
solo-developer Godot 4.7 tactical RPG ("The Wandering Inn" fan project, itch web-demo
target). You have NOT followed the project's history — form your own judgment from the
repo. Your reviewer predecessors caught self-contradictions in earlier controller-authored
specs; hunt for those here.

## What to read (in order)
1. `docs/superpowers/specs/2026-07-02-wandering-inn-m5-demo-feel-design.md` — THE SPEC UNDER REVIEW
2. `wandering_inn_game_v4/CLAUDE.md` — architecture, QA conventions, gotchas (binding constraints on any design)
3. `docs/ROADMAP.md` — where M5 sits; the one-week-Fable constraint
4. `HANDOFF.md` — M4 playtest findings that motivated M5
5. Skim for context as needed: `src/world/world.gd`, `src/combat/combat_screen.gd`, `src/ui/*.gd`, `qa/test_driver.gd`, `data/*.json`

## Your task
Adversarially review the M5 spec. Specifically:

1. **Internal contradictions** — any two sections that can't both be true; lane-ownership
   claims vs the actual file structure; QA claims vs how the harness actually works.
2. **The render rework (§1) is the riskiest section.** Assess: SubViewport + integer-scale
   approach vs the existing TestDriver screenshot pipeline (`get_viewport().get_texture()`
   — does that capture the world subviewport or the root?); input routing through
   SubViewportContainer (the game injects real InputEventKey via `Input.parse_input_event`
   — does that reach a SubViewport's world without extra forwarding?); Camera2D +
   TileMapLayer at 16px with existing `ORIGIN` offsets; the claim that all existing QA
   event assertions survive unchanged.
3. **Feasibility vs the one-week constraint** — which lanes are underestimated? What
   would you CUT first if the milestone runs long, given the goal is "stranger plays a
   demo that feels like a game"?
4. **Missing-but-necessary** — anything a shipped demo-feel milestone needs that the spec
   omits (think: window resize behavior, audio on wasm/browser autoplay policies, save
   compatibility across the viewport change, first-run defaults).
5. **The hotbar (§3)** — keyboard-first: any UX incoherence keeping Tab-cycle targeting
   with a numbered hotbar?

## Output format
- Verdict: sound / needs revision (with the blocking list)
- Findings ordered by severity, each: spec section, the problem, concrete failure/cost,
  suggested fix
- The one thing you'd cut first under schedule pressure, and why
- Anything you'd add that the spec missed

Be blunt. Wrong-but-specific beats vague-but-safe.
