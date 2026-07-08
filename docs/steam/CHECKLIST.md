# Steam deployment checklist (issue #19)

Everything below is a **USER ACTION** — none of it can be done by an agent
(account creation, payment, identity verification, and 2FA-guarded secrets
all require the human). This file is the handoff: work through it top to
bottom before the `steampipe-upload` CI job in `.github/workflows/release.yml`
can do anything (it's gated `if: vars.STEAM_APP_ID != ''` and stays a green
no-op skeleton until you complete the steps below).

**Binding ruling (issue #20, closed 2026-07-07): the game ships FREE on
Steam, no monetization.** The $100 app fee is a cost paid to get on the
platform for the discovery value, not recouped — do not set a price, do not
enable donations-via-Steam, do not add DLC. Nothing in this pass adds any
payment plumbing; keep it that way when you provision the app.

## 1. Steamworks partner account

- [ ] Create/confirm a Steamworks partner account at
      https://partner.steamgames.com (a personal Steam account can be
      upgraded to a partner account for free; the fee below is per-app, not
      per-account).
- [ ] Complete the account's tax/identity paperwork (required even for a
      free app — Steam still needs a payee of record on file).

## 2. App page + the $100 fee

- [ ] "Submit New App" in the partner site. Pay the **$100 app fee** (a
      cost, not revenue — see the binding ruling above). It is
      recoupable against future sales on that app per Valve's standard
      terms, but this app has none planned, so treat it as sunk.
- [ ] Set the app's pricing to **Free** in the Store Presence /
      Pricing page (not "Free Weekend" or a discount — the base price plan
      must be Free).
- [ ] Note the assigned **App ID** (a numeric id, e.g. `123456`) — this
      becomes the `STEAM_APP_ID` repo VARIABLE (see §5).

## 3. Depots (SteamPipe)

- [ ] In App Admin → SteamPipe → Depots, create two depots: one for the
      Windows build, one for the Linux build (macOS deferred this pass —
      see `docs/superpowers/specs/2026-07-06-m-steam-seed.md` §3, Mac
      notarization is a non-goal for v1). Depot IDs are assigned by Steam,
      NOT derived from the app id — note both numeric ids.
- [ ] These become `STEAM_DEPOT_ID_WINDOWS` / `STEAM_DEPOT_ID_LINUX` (§5).

## 4. A private/unlisted branch — NEVER `default`

- [ ] In App Admin → SteamPipe → Builds, create a branch that is NOT
      `default` (e.g. `unlisted-ci`) and mark it **not visible to the
      public** (Steam's branch visibility setting; no password needed if
      "not listed" is enough for your test purposes, but a password-gated
      branch is stronger). This is the branch every CI upload targets — the
      `steampipe-upload` job actively refuses to run if the resolved branch
      is `default` (see release.yml's guard).
- [ ] Only promote a build from that branch to `default` (the public
      depot) by hand, after you've verified it in Steam client on the
      private branch. CI never does this automatically.
- [ ] This branch name becomes `STEAM_BRANCH` (§5, defaults to
      `unlisted-ci` in the workflow if you don't set it — but you still
      need the branch to exist and not be public).

## 5. CI secrets + variables (the butler-secret pattern, extended)

Repo → Settings → Secrets and variables → Actions. Follow the SAME split
`wi-shipping` already uses for the itch push (`BUTLER_API_KEY` = a secret,
`ITCH_TARGET` = a plaintext value in the workflow) — Steam's build-account
credential is the secret; the app id/branch/depot ids are plaintext repo
**Variables** (not secrets — they're not sensitive, and gating the job on
`vars.STEAM_APP_ID != ''` only works with a Variable, not a Secret, which
GitHub Actions can't read in an `if:` condition pre-job).

**Secrets:**
- [ ] `STEAM_BUILD_ACCOUNT` — the Steam account **username** used to log
      steamcmd in (create a dedicated limited-permission build account in
      Steamworks, not your personal login — App Admin → Users & Permissions
      → Manage Groups, grant it "Edit App Metadata" + SteamPipe build
      permissions only).
- [ ] `STEAM_CONFIG_VDF` — a base64-encoded `config.vdf`. Produced by a
      **one-time interactive login** on a trusted local machine (NOT CI):
      ```
      steamcmd +login <STEAM_BUILD_ACCOUNT> +quit
      ```
      (enter the password and Steam Guard code when prompted — this
      captures an authorized session so CI never sees a 2FA prompt). Then:
      ```
      base64 -i ~/Library/Application\ Support/Steam/config/config.vdf | pbcopy
      ```
      (path varies by OS/steamcmd location — `~/.steam/steamcmd/config/config.vdf`
      on Linux). Paste as the secret value. **Re-mint this whenever the
      build account's password or Steam Guard state changes.**

**Variables:**
- [ ] `STEAM_APP_ID` — from §2. Setting this is what flips
      `steampipe-upload` from a permanent no-op skeleton to a live job —
      double check the branch/depot values below are ALSO set before you
      set this one, since the job runs on the very next tag push.
- [ ] `STEAM_BRANCH` — from §4 (e.g. `unlisted-ci`). Never `default`.
- [ ] `STEAM_DEPOT_ID_WINDOWS` — from §3.
- [ ] `STEAM_DEPOT_ID_LINUX` — from §3.

## 6. First test upload

- [ ] Push a version tag (`git tag vX.Y.Z && git push origin vX.Y.Z`) same
      as any normal release; `desktop-exports` builds Win+Linux, then
      `steampipe-upload` pushes them to the private branch from §4.
- [ ] Verify in Steam client: SteamPipe → betas → opt into the private
      branch, download, confirm it boots (placeholder art is expected until
      the private asset bundle is wired into a Steam-specific build step —
      today's exports use the same placeholder-fallback tree ci.yml already
      builds on, per issue #19's scope).
- [ ] Only after that manual verification: promote to `default` by hand in
      the partner site, or update `STEAM_BRANCH` once you're comfortable
      automating further.

## 7. Store page content (non-CI, also user actions)

- [ ] Capsule art: `docs/steam/capsules/` has all four exact sizes already
      assembled (460×215, 231×87, 616×353, 1232×706) — upload as-is, or
      regenerate via `python3 docs/steam/make_capsules.py` once real
      licensed art is wired in (today's source is placeholder-fallback
      game art, per issue #19 scope).
- [ ] Screenshots: `docs/steam/screenshots/` has 5 at 1280×720 (inn,
      combat, dialogue, night street, guild board) — upload as-is or swap
      for freshly captured ones once real art lands.
- [ ] Store description / short description / tags — not scoped to this
      issue; write these directly in the partner site when ready.
- [ ] Age rating questionnaire (mild fantasy violence, per the M-STEAM
      seed spec §1.6) — fill out in the partner site.
- [ ] Privacy policy — the game is fully offline with no telemetry/data
      collection, so the questionnaire answer is "none collected."

## 8. Trailer — NOT delivered this pass (flagged, per the brief's danger list)

> **TOOLING UPDATE (2026-07-08): the capture half is now UNBLOCKED** —
> macOS Screen Recording permission granted + verified (`screencapture`,
> `ffmpeg -f avfoundation`). Remaining work for the trailer is the
> SCRIPTED-PLAYTHROUGH half (a QA-script-driven windowed run captured at
> 30fps + cut points) — a normal agent task now, no new capability
> needed. See wi-verifying-changes' OS-capture section.

**A 30-60s trailer is scoped but explicitly NOT built in this pass.** This
is called out deliberately, not silently dropped:

- The M-STEAM seed spec (`docs/superpowers/specs/2026-07-06-m-steam-seed.md`
  §1.5) and issue #19 itself both flag trailer capture as "a genuinely new
  capability with no existing tooling" — the QA pipeline takes still
  screenshots (`qa/run_qa.sh <script> windowed`), not video, and there is no
  screen-capture-to-video tooling in this repo today.
- What it would need: (a) a scripted playthrough QA route long enough to
  read as a trailer (30-60s of varied footage — inn, combat, street,
  dialogue — the existing scripts already know these routes), (b) a
  screen/window capture tool driving the same windowed QA run (OBS or
  `ffmpeg`'s screen-capture input are the obvious candidates on macOS/CI),
  (c) basic edit/cut assembly (even a single unedited continuous capture
  would clear Steam's bar, but title-card + music would need a human or a
  future session with video-editing tooling), (d) a decision on whether CI
  can produce this headlessly at all — windowed QA runs need a real
  window server (confirmed working locally for screenshots this pass;
  untested for continuous video capture) or a human sits down and records
  a manual playthrough instead.
- Recommendation: treat this as its own follow-up task once the screenshot
  pipeline above is validated with real (non-placeholder) art — a trailer
  cut against placeholder-fallback rectangles is not worth shipping, but
  the *tooling investigation* (can a windowed QA run be captured to video
  headlessly in CI, or does this stay human-recorded) can start any time.
