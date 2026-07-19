# #111 Safe project rename — spec (2026-07-19, Fable)

Scope: design only (GOAL.md item 4b). IMPLEMENTATION IS USER-GATED — this
spec ends with an explicit go/no-go ask. Target rename:
`config/name = "Wandering Inn RPG v4"` → `"Wandering Inn RPG"`.

## 1. Why a bare rename strands every existing save (engine facts, cited)

`user://` identity derives from `application/config/name` at
`core/os/os.cpp:338-353` (4.7-stable): default path =
`<data_path>/<godot_dir>/app_userdata/<get_safe_dir_name(config/name)>`.
Per platform:

| Platform | Resolved current path | Source |
|---|---|---|
| macOS | `~/Library/Application Support/Godot/app_userdata/Wandering Inn RPG v4` | `os_macos.mm:440-442` (data=config path), `:502` ("Godot" capitalized); verified on this machine's disk |
| Linux | `~/.local/share/godot/app_userdata/Wandering Inn RPG v4` | `os_unix.cpp:1142` + `os.cpp:294` (lowercase default) |
| Windows | `%APPDATA%\Godot\app_userdata\Wandering Inn RPG v4` | same `os.cpp` derivation over the Windows data path |
| Web | `/userfs/godot/app_userdata/Wandering Inn RPG v4` inside the per-ORIGIN IndexedDB-backed virtual FS | `os_web.cpp:210-213`; persistence mounts `['/userfs']` wholesale (`platform/web/js/engine/config.js:120`, `library_godot_os.js:133-157`) |

Renaming `config/name` changes the final path segment on every platform.
The old data is NOT deleted — it just stops being `user://` — so every
existing save and `settings.cfg` "disappears" from the game's view.

What lives there today: `user://saves/*.json` (`src/core/game.gd:3`,
enumerated by `src/ui/title_screen.gd:629`) and `user://settings.cfg`
(`src/ui/wi_settings.gd:14`, `src/audio/wi_audio.gd:4`).

Key web consequence: because the ENTIRE `/userfs` tree persists in one
per-origin store, the old directory remains readable at its absolute
virtual path after a rename — the same migration code path works on
native and web, provided the serving ORIGIN is stable (see §4).

## 2. Options enumerated

### A. One-time first-boot path migration (RECOMMENDED)
At Game-autoload startup, before the title screen enumerates slots:
if `user://saves/` is empty/absent AND a legacy dir exists, COPY (never
move) `settings.cfg` + `saves/*.json` into the new `user://`, then write
a `migrated_from_v4` marker so the check short-circuits forever after.
Legacy dir candidates, tried in order:
- native: `OS.get_data_dir()` + `/{Godot,godot}/app_userdata/Wandering Inn RPG v4`
  (both capitalizations — `get_godot_dir_name()` is not exposed to script);
- web: `/userfs/godot/app_userdata/Wandering Inn RPG v4`.
FileAccess absolute paths reach both.
+ Pros: one code path both platforms; legacy dir left intact as rollback;
  logic dies behind the marker; QA-provable with a fixture.
− Cons: copies (not shares) data — a player round-tripping to the OLD
  build after migration writes to the old dir and the marker means new
  builds won't see those newer saves (accepted: old build stops being
  distributed at the same release).

### B. Dual-path read + single-path write
Slot enumeration and settings reads check new path first, fall back to
legacy forever; writes go only to new.
+ Pros: no copy step; newer-old-build saves stay visible.
− Cons: two live read paths in title/settings/audio FOREVER (three
  readers today, more later); every future save-surface change must
  remember the fallback; QA must pin both paths permanently. Rejected:
  permanent complexity for a one-time event.

### C. Export/product-surface-only rename (no `config/name` change)
Rename the itch page, HTML shell title, desktop export file names; keep
`config/name` = v4.
+ Pros: zero save risk, zero code.
− Cons: the window title (defaults from `config/name`) still reads
  "Wandering Inn RPG v4" — the exact surface the rename is FOR. Viable
  only as an interim cosmetic step. Note: `use_custom_user_dir`
  (`os.cpp:341-347`) is NOT a preserve-path tool — it changes the path
  ROOT (drops the `Godot/app_userdata` prefix entirely), stranding saves
  the same way.

## 3. Recommended cut

**Option A**, shipped in one release with the rename itself:
1. `WISaveMigration`-style helper in the Game autoload boot path (file
   I/O lives in Game by architecture rule; sim untouched).
2. `config/name` → "Wandering Inn RPG" in the same PR.
3. Legacy dir left intact (copy-only) — rollback = revert the release.
4. QA isolation is naturally safe: isolated QA HOMEs have no legacy dir,
   so migration no-ops in every existing script.

## 4. Rollout order (three targets)

1. **Desktop (itch Win/Linux zips)** — the release build is testable
   locally against a real pre-rename user dir before anything ships.
2. **GitHub Pages** — our own stable origin; post-deploy probe: load the
   page with a browser profile carrying a pre-rename IndexedDB, confirm
   Continue lights up.
3. **itch HTML5 last** — browser saves key on itch's per-game embed
   origin. Same-game uploads have kept a stable origin historically, but
   this is EXTERNAL behavior we don't control: before pushing, verify the
   live embed origin (devtools on the current build), push, re-verify.
   If itch ever rotates the origin, web saves are lost REGARDLESS of any
   rename — that risk exists today and is not created by this change.

## 5. QA proof plan (gates before the release cut)

- **Fixture leg (native, deterministic, rides the sweep)**: a new QA
  script's setup writes a save fixture + settings.cfg into the LEGACY
  path inside its isolated HOME (`.godot_home/...` — the runner already
  owns HOME), boots the renamed build, asserts: migration toast/marker,
  title `continue_enabled: true`, slot loads, settings values survive
  (existing `ui_title_rendered` + snapshot assertion machinery; no new
  driver verbs). Prove-it-can-fail: run once with the fixture and the
  marker pre-set → migration must NOT re-copy.
- **Old-name-build leg (one-time rehearsal, implementation window)**:
  build at v4 name, create a real save, rebuild renamed, confirm the
  same OS user dir migrates — catches capitalization/path drift the
  synthetic fixture could mask.
- **Web leg (one-time rehearsal)**: Playwright persistent context —
  boot the CURRENT (v4) web build, save; swap in the renamed build on
  the same served origin; confirm Continue + load. Scriptable with the
  existing run_web_qa.mjs server plus a `userDataDir` launch option;
  not a permanent sweep member (needs two builds).
- Standard full bar (sweep + units) — migration code is autoload-side,
  sim streams untouched.

## 6. Go/no-go ask (USER)

The spec recommends Option A in a single release. **Go** = green-light
implementation as a v0.13-window package (est. one focused session:
helper + QA script + rehearsals + release-notes line). **No-go / hold**
= keep `config/name` v4; optionally take Option C's cosmetic itch-page
rename now (zero risk) and revisit. Either answer, #19 Steam stays HOLD
per standing directive.
