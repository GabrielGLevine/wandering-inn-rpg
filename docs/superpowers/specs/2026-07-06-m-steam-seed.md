# M-STEAM — Steam Deployment Groundwork (SEED)

Status: user-seeded 2026-07-06 ("when we have time"); chain tail item.
Seed-level: the gates, the gaps, the pipeline shape. NOT scheduled.

## 0. THE GATE (before anything else): the non-commercial promise

The pirateaba fanworks policy + our own README/LICENSE framing are
NON-COMMERCIAL. **A FREE Steam release keeps that promise** ($100 app
fee is a cost we pay, not revenue we take). ANY paid path — price tag,
donations-via-Steam, DLC — requires pirateaba's EXPLICIT written
permission first. ⚑ User decision at scheduling: free-on-Steam
(recommended; discovery value alone) vs ask-permission-first.

## 1. What Steam needs that itch/web doesn't

1. **Desktop native exports** (Win/Linux/macOS presets — templates
   already pinned; the game is engine-portable today). New export
   presets + per-platform smoke QA (the web-parity idiom, natively).
2. **Controller support** — the REAL gap. The game is keyboard-driven
   (arrows/numbers/E/I/J/Esc). Steam (esp. Deck verification) wants
   full pad play: an input-mapping pass (Godot actions already
   abstract keys — the work is pad bindings + a UI hints swap
   [keycap→button glyphs] + focus-navigation in panels). This is the
   milestone's engineering center; everything else is plumbing.
3. **Steamworks**: GodotSteam (GDExtension) IF we want
   achievements/cloud/overlay — v1 can ship WITHOUT any SDK
   (plain desktop build on a free app page is valid). Recommend:
   v1 no-SDK; achievements later (our accomplishment counters map
   1:1 to achievements — a gift).
4. **Build pipeline**: release.yml gains desktop-export jobs +
   SteamPipe upload (steamcmd + depot configs; secrets: the Steam
   build account credentials — the butler pattern repeated).
5. **Store assets**: capsule art set (exact-size pack: 460x215,
   231x87, 616x353, 1232x706 header/library), 5+ screenshots
   (windowed pipeline has them), a 30-60s trailer (NEW capability —
   flag; simplest path: scripted playthrough + OBS capture, human
   or a future session with screen tooling).
6. **Paper cuts**: age-rating questionnaire (mild fantasy violence),
   privacy (offline, none), saves live in user:// per-platform
   (document; Steam Cloud = a later config once stable).

## 2. Sequencing

After the current chain tail (post-8f) or opportunistically once
controller support is wanted for its own sake (Deck players overlap
web-demo players). Pipeline + presets are a day; controller support
is the real milestone; store assets ride the art pipeline.

## 3. Non-goals (v1)

Paid anything; achievements/cloud (v2 with GodotSteam); Mac
notarization headaches if macOS lags (ship Win/Linux first — Deck is
Linux); localization (its own future milestone).
