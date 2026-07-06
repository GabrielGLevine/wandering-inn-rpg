---
name: wi-godot-mcp
description: Use when driving the Godot editor or running game via the godot-ai MCP — live visual iteration, level-design reads, runtime UI inspection, input-driven probes — or when writing a subagent brief that grants MCP access.
---

# Godot MCP (godot-ai) Playbook

Empirically verified 2026-07-04 (Fable spike, plugin 2.8.5, Godot 4.7).
Policy (who/when): wi-running-the-machine. This skill is HOW.

## Prerequisites
- The Godot EDITOR must be open on `wandering_inn_game_v4` with the
  `godot_ai` plugin enabled (it's committed in-tree). No editor = no MCP.
- `session_manage(op="list")` → confirm a session; `session_activate` only
  if several. `readiness: "ready"` means writes will be accepted.

## The proven live-game loop
1. `project_run(mode="main")` — often returns `status: "not_live"` after its
   ~3s window; **that is not a failure.** Poll `editor_state` until
   `game_capture_ready: true` (~10–12s for this project).
2. `editor_screenshot(source="game", max_resolution=640)` — cheap, legible
   read of the live framebuffer (title/inn/street verified). Use
   `max_resolution=0` only when pixel-level judgment is needed.
3. `game_manage(op="input_key", params={key, pressed})` — REAL input; send
   press then release (two calls). Title → menu → New Game works; field
   movement is 2 calls per grid step — fine for short probes, **use a QA
   script for any long path.**
4. `game_manage(op="get_ui_elements")` — full Control dump with `text` +
   global rects: the tool for label overlap/clipping/readability questions.
   ~3–4KB per call; scope with `root_path` when possible.
5. `game_manage(op="get_scene_tree"/"get_node_info")` — runtime
   presentation tree. UI is code-built, so most nodes are anonymous
   (`@Control@N`) — identify by type/text/rect, not by name.
6. `project_manage(op="stop")` when done. Don't leave a game running while
   headless QA runs elsewhere.

## Hard limits (learned, don't rediscover)
- **ObservableBus events are INVISIBLE to `logs_read(source="game")`** —
  the bus writes JSONL to `user://`, not stdout. Bus/event evidence comes
  ONLY from `qa_output/<script>/events.jsonl`. MCP shows you pixels and
  Controls; QA shows you the contract.
- MCP is never verification evidence: gates remain `run_qa.sh` + headless
  CLI per wi-verifying-changes. MCP screenshots may SUPPLEMENT windowed
  reads during iteration, but the final controller-read still uses the QA
  windowed pass (full-res, deterministic camera path).
- Editor-viewport screenshots (`source="viewport_2d"`) are near-useless
  here: no hand-authored scenes (all UI/world built in code at runtime).
  `source="game"` is the useful one.
- `project_run(autosave=true)` (default) persists any in-memory MCP scene
  edits before running. This project makes none by policy — but pass
  `autosave=false` in probes to keep the guarantee explicit.
- NEVER `project_manage(op="settings_set")` or scene/script write verbs on
  this repo — content is `data/*.json` + code via normal file edits; the
  editor is a viewer/driver here, not an author.

## Directing subagents with MCP
- Default: implementer briefs stay headless-only (CLI). Grant MCP in a
  brief ONLY for visual-iteration tasks (composition passes, placement
  tuning, readability sweeps) and name the exact ops allowed.
- One editor session = one driver: never two agents on the MCP
  concurrently (input/screenshot interleaving is unowned state).
- Brief template lines: "Editor is open; use godot-ai MCP: project_run →
  poll editor_state until game_capture_ready → input_key/screenshot loop →
  project_manage stop. max_resolution=640. Do not use scene/script write
  verbs. Final verification is still run_qa.sh per wi-verifying-changes."
- Budget note: every screenshot/UI dump stays resident in the agent's
  context — plan probes (a shot list) before running, don't wander.
