# Mobile parity matrix (#503)

Diagnostic record for milestone **01 - Mobile parity and a clear first session**.
Every cell names its evidence class. **Emulated** = Playwright Chromium with a
phone UA/viewport/touch context on the local web export (never evidence about
real iPhone Safari or Android Chrome). **Real** = a physical device with the
recorded OS/browser; fill from the M1 gate (#511). **Untested** stays untested.

| Field | Value |
|---|---|
| Build SHA | working tree of `issue/503-mobile-parity-matrix` at PR time (base `fc226d90`); re-export before repeating any row |
| Export | `qa/web/export_web.sh` → `build/web/` (Godot 4.7.2.stable, Web preset, single-threaded); payload `index.pck` 138.9 MB + `index.wasm` 37.7 MB (176.9 MB uncompressed; itch serves compressed) |
| Runner | `qa/web/run_web_qa.sh <script> <seed> --skip-export --touch --device=iphone|android [--portrait-entry]` |
| Emulated iPhone | Chromium 844×390 landscape, `isMobile`, `hasTouch`, iPhone OS 17.5 Safari UA (`run_web_qa.mjs` DEVICE_PRESETS) |
| Emulated Android | Chromium 915×412 landscape, `isMobile`, `hasTouch`, Pixel 8 Chrome 126 UA |
| Desktop reference | native headless/windowed canonicals (`qa/run_qa.sh`), 1280×720 canvas |
| Real iPhone Safari | **UNTESTED** — no hardware in the recording session; record device model, iOS + Safari version, CSS viewport (`window.innerWidth×innerHeight`), orientation, build SHA |
| Real Android Chrome | **UNTESTED** — same fields |
| Hosting | local HTTP server (`run_web_qa.mjs`); the itch embed and direct itch.io hosting are **UNTESTED** this pass (the embed adds itch's iframe + its own scroll/viewport chrome) |

## Orientation policy (acceptance 4)

Landscape gameplay is the baseline. Portrait on a coarse-pointer device shows
the full-screen rotate overlay (CSS `(orientation:portrait) and (pointer:coarse)`
in `export_presets.cfg` `html/head_include`); the canvas keeps running
underneath, so rotating back reveals the live game with nothing reloaded.
Proof: `--portrait-entry` opens the page at 390×844, reads the overlay
(`display:flex`, `portrait=true coarse=true`), captures `portrait_entry.png`,
rotates to 844×390 via viewport resize without navigation, reads the overlay
hidden, then the script plays through to `QA_RESULT: PASS` — a title-gate tap
the driver computed under the portrait letterbox landed correctly, i.e. the
game was already running before the rotation. Portrait gameplay and native
wrappers stay out of scope.

## Touch smoke (acceptance 3)

`mobile_touch_smoke` (fixture `mobile_tap_start`) uses ONLY `touch_*` steps:
title gesture, Continue row, adjacent-tap talk (×2), paged-dialogue taps (×3),
option taps (×3), tap-to-walk, journal chip — 12 touches, count pinned. On
the web runner with `--touch` the driver publishes each tap in WINDOW pixels
(`Viewport.get_screen_transform()`) and Playwright performs a genuine
`page.touchscreen.tap`; an unserviced request FAILS the step. Negative proof:
the same run without `--touch` reports every request `UNSERVICED` and the
script fails — there is no keyboard or mouse fallback. Natively the taps are
emulated clicks and the `qa_touch` event says `real:false`.

| Run | Result |
|---|---|
| `mobile_touch_smoke 9 --touch --device=iphone --portrait-entry` | PASS; 12 real taps; rotation probe OK; audio smoke PASS |
| `mobile_touch_smoke 9 --touch --device=android` | PASS; 12 real taps; audio smoke PASS |
| `mobile_touch_smoke 9 --device=iphone` (no `--touch`) | FAIL by design: requests unserviced, steps red (no fallback) |
| `qa/run_qa.sh mobile_touch_smoke headless --seed=9` (native) | PASS; 12 emulated taps (`qa_touch real:false`) |

CI runs the iPhone + portrait-entry variant in the web-parity job and pins the
real-tap count and the rotation probe.

## Flow matrix (acceptance 1–2)

Input class per cell: `real-touch` = Playwright touch events; `engine-input`
= the script drives the game through the driver's key/click injectors (the
same code path a desktop run uses, so it proves the FLOW on the web build but
not the finger); `real` = physical device observation.

| Flow | Desktop reference (native canonical) | Emulated iPhone Safari UA (Chromium) | Emulated Android Chrome UA (Chromium) | Real iPhone Safari | Real Android Chrome | Linked repair |
|---|---|---|---|---|---|---|
| Cold start → title gesture gate | `title_flow`, `mobile_tap_check` PASS | real-touch PASS (`mobile_touch_smoke` tap 1) | real-touch PASS | UNTESTED | UNTESTED | — |
| Continue / New Game rows | `title_flow` PASS | real-touch PASS (tap 2); `title_flow` engine-input: `title_flow` FAILS on its desktop pin `selectable_rows: 4` (the web build hides the Quit row → 3); the flow itself proceeds — a script-expectation gap, not a device defect | — | UNTESTED | UNTESTED | — |
| Character creation + name entry (virtual keyboard) | `char_creation` PASS | engine-input PASS (`char_creation`, name typed via `type_text`); keyboard is `html/experimental_virtual_keyboard=true` — its appearance/dismissal is a real-device observation | — | UNTESTED | UNTESTED | #507 copy, #510 keyboard lifecycle |
| Dialogue paging by tap, option taps | `mobile_tap_check` PASS | real-touch PASS (taps 5–10) | real-touch PASS | UNTESTED | UNTESTED | #509 readability |
| Movement (tap-to-walk) + adjacent-tap interact | `mouse_loop` PASS | real-touch PASS (taps 3, 4, 11) | real-touch PASS | UNTESTED | UNTESTED | #506 |
| Field chips / hotbar | `field_chips_loop` PASS | real-touch PASS (tap 12, journal chip) | real-touch PASS | UNTESTED | UNTESTED | #505/#506 |
| Inventory / equipment | `inventory_loop` PASS | engine-input PASS (`inventory_loop`) | — | UNTESTED | UNTESTED | #506 |
| Journal scrolling | `spine_reach` PASS (drag steps) | not exercised by touch this pass | — | UNTESTED | UNTESTED | #506 |
| Combat targeting / cancel / end-turn / results | `combat_touch_input` PASS (engine-injected taps) | engine-input PASS (`combat_touch_input`: adjacent-cell tap move, Dash confirm chip, Attack targeting cancel/re-aim — driver-injected taps) | — | UNTESTED | UNTESTED | #506 |
| Settings | `settings_loop` PASS | engine-input: `settings_loop` FAILS on the same desktop-only `selectable_rows: 4` title pin at step 2; settings surface itself not reached — re-pin for web before reading it as a defect | — | UNTESTED | UNTESTED | #505 |
| Purchases (confirm/cancel) | `purchase_confirm_loop` (#504, PR #531) | pending #504 merge; the modal's Buy/Cancel rows have a `touch_purchase_row` step ready | — | UNTESTED | UNTESTED | #504 |
| Save / reload | `save_load_roundtrip` PASS | engine-input PASS (`save_load_roundtrip`: write + reload through IndexedDB `user://`) (IndexedDB `user://`) | — | UNTESTED (iOS ITP eviction is a real-device concern) | UNTESTED | — |
| Import / export save | `import_export` canonicals | KNOWN BROKEN on itch/mobile web: refusal toast, no file picker | — | UNTESTED | UNTESTED | #253 |
| First-tap audio unlock | n/a | audio smoke PASS on every run (worklets load, output present after the gesture tap) | PASS | UNTESTED (iOS silent-switch/autoplay policy) | UNTESTED | #510 |
| Rotation (portrait entry → landscape) | n/a | PASS (rotation probe; overlay shown/hidden; no reload) | not run | UNTESTED | UNTESTED | #510 |
| Background / foreground resume | n/a | UNTESTED (Playwright cannot background a tab faithfully) | — | UNTESTED | UNTESTED | #510 |

## Reproductions filed / mapped

- **CI "Web parity" job was a no-op since it was written** (found by this
  pass, fixed in the same PR): `perl -e 'exec @ARGV' WI_REQUIRE_AUDIO_OUTPUT=1
  bash …` exec'd a program literally named `WI_REQUIRE_AUDIO_OUTPUT=1`,
  failed silently, exited 0 — empty log, green check. Every prior "web parity
  green" claim was vacuous; the assignment now precedes perl and an empty log
  (no `QA_RESULT: PASS`) fails the step. The runner also fails at the door
  when `index.html` is not served (a missing export used to surface as a
  120s timeout).
- Import Save on mobile web → #253 (pre-existing, confirmed still open; not re-run here).
- No additional concrete defect reproduced under emulation this pass; every
  emulated flow that reached its surface passed. Two canonicals (`title_flow`,
  `settings_loop`) red only on a desktop-specific title pin (`selectable_rows`
  4 vs the web build's 3, Quit row hidden on web) — an evidence gap in the
  scripts, tracked as a follow-up, not a mobile defect. Real-device friction reported by playtesters
  remains unreproduced until hardware observations land — record them in
  this table with device/OS/browser/viewport/build SHA and file per flow.

## How to add a real-device row

1. Open the itch page or direct hosting on the device; note `navigator.userAgent`,
   `innerWidth×innerHeight`, orientation, build SHA (title screen / release tag).
2. Walk the flows above in order; for each failure record exact taps, what
   happened, and a screenshot/recording.
3. Replace `UNTESTED` with `real PASS` / `real FAIL → #n` and link the evidence.
