# #111 Safe project rename — release checklist (v0.13 window)

Status: **FULLY VERIFIED 2026-07-20** — v0.13.0 shipped; rehearsal 1 (native) passed on the user machine with real data; rehearsal 2 (web) user-confirmed on the live deploy ("Rename migration successful"). This checklist is CLOSED.

Original status: **CODE SHIPPED** (config/name → "Wandering Inn RPG"; boot-ordered
`user://` carry-over in `WISaveMigration` + `Game._migrate_legacy_userdir`).
The two REHEARSAL legs below are the spec's one-time manual gates — they run
in the release-cut session, before the tagged build ships, and are NOT sweep
members (each needs two builds / a real pre-rename user dir).

## What ships in code (done, on `main` via this PR)
- `application/config/name` = "Wandering Inn RPG" (was "…v4").
- `WISaveMigration` (pure static copy) + `Game._migrate_legacy_userdir` at
  autoload boot: if `user://` has no `.json` saves and no `migrated_from_v4`
  marker, COPY (never move) `settings.cfg` + `saves/*.json` from the
  same-parent `Wandering Inn RPG v4` sibling, then drop the marker. One code
  path native + web.
- Automated proof: `test_save_rename` (copy / no-clobber / count / sibling
  derivation) + `save_rename_migration` canonical (run_qa.sh `legacy_seed`
  seeds a real pre-rename save → boot migrates it → Continue lights up →
  loads byte-faithfully). Rides the unit suite + full sweep.

## Rehearsal legs (run at the release cut — GATES)

### 1. Native old-name-build round-trip (catches capitalization/path drift)
1. `git stash`-free: check out the **pre-rename** commit (or temporarily set
   config/name back to "…v4"), export a desktop build, run it, create a real
   save (play to a known state, e.g. reach the guild, note gold).
2. Check out this build (renamed), run the SAME desktop export against the
   SAME OS user account. Expect: first launch shows **Continue enabled**, the
   save loads to the known state, `settings.cfg` values survive.
3. Confirm the legacy dir is still present (copy-only, rollback intact) and a
   `migrated_from_v4` marker now exists in the new dir.
- macOS path pair (verified this machine):
  `~/Library/Application Support/Godot/app_userdata/Wandering Inn RPG v4`
  → `…/Wandering Inn RPG`.

### 2. Web persistence round-trip (Playwright persistent context)
1. Serve the CURRENT (pre-rename) web build; in a persistent browser profile
   (`userDataDir`), save a game (writes the origin's IndexedDB `/userfs`).
2. Swap in the renamed web build on the **same served origin**; reload.
   Expect: Continue lights up, loads. (The whole `/userfs` tree persists per
   origin, so the legacy `app_userdata/Wandering Inn RPG v4` dir is still
   readable at boot and the same copy path runs.)
3. Scriptable via the existing `run_web_qa.mjs` server + a `userDataDir`
   launch option. Not a permanent sweep member (needs two builds).

## Rollout order (three targets — spec §4)
1. **Desktop (itch Win/Linux zips)** — testable locally against a real
   pre-rename user dir before anything ships (rehearsal 1).
2. **GitHub Pages** — our own stable origin; post-deploy, load with a browser
   profile carrying a pre-rename IndexedDB, confirm Continue.
3. **itch HTML5 last** — verify the live embed origin (devtools) is unchanged
   before + after push. If itch ever rotates the per-game origin, web saves
   are lost REGARDLESS of any rename — that risk pre-exists this change.

## Release-notes line
> Renamed the game to **Wandering Inn RPG**. Your existing saves and settings
> carry over automatically the first time you launch this version — nothing to
> do on your end.

## Rollback
Revert this PR (restores config/name "…v4"). The legacy dir was never
touched (copy-only), so a reverted build reads its original saves unchanged.
The `migrated_from_v4` marker in the new dir is inert after a revert.
