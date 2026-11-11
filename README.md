# Town — Capacitor shell project

The house-wide app-packaging step for Town (Tyler, 2026-11-06 12:56 MST),
built 2026-11-07 by the estate closeout run as the retroactive packaging
step for Town — the last product still marked OWED in the program's
packaging ledger (`../../STATUS.md`, "Packaging status, all 43"). It
follows the house pattern set by the Munchland shell and the ReviewPort
shell (`../reviewport-shell/`): the shell loads the live web app rather
than bundling a copy of it. Record: `../town.md` (addendum appended by
this run). Sequencing call for Town: **WEB-FIRST** — per Tyler's own
ruling for Town (2026-11-06 12:54 MST), the web app leads and this
packaging is the finishing step; gate (b) of Town's cycle record also
carries Tyler-gated founder decisions (real accounts / backend hosting)
that this scaffold does not advance.

## What this is

A thin Capacitor shell over Town's live web app.

- **App name, every surface:** exactly `Town` — config `appName`, the
  `www/` stub title, and the door's PWA manifest `name` + `short_name`.
  Nothing added, per the NAME EXACTNESS LAW (Tyler, 2026-11-06 12:56
  MST): no "Town by BuckThem," no subtitle, no longer forms.
- **appId:** `com.getperkwatch.town` — a **PROPOSAL only**, following
  the house pattern of the sibling shells. No bundle ID is settled for
  Town; the proposal is recorded here as proposed, never as confirmed.
- **Loads:** `https://buckthem.com/town` — the product's live web
  address on the BuckThem umbrella (live and serving 200 over valid
  HTTPS, re-verified 2026-11-07).
- **Icon / splash:** none. `resources/` is deliberately empty — no icon
  file exists for Town in its trees (the umbrella entry carries no icon;
  its generated page carries no icon asset). None was invented here.
  The door's PWA manifest carries the same honest state: an empty icon
  list.
- **Native touches:** per Town's cycle record (gate (b)), the shipping
  shell is to include push notifications, native share, app icon/splash,
  and full-screen chrome. This scaffold deliberately adds **no** plugin
  dependencies beyond the house set: push/share plugins are wired at the
  native build step, once the backend-hosting decision (Tyler's gate)
  exists for them to talk to. Recorded here so the requirement is not
  lost — it is not claimed done.

## The door manifest (built with this step, local tree)

The installable-shortcut half of the packaging lives on the umbrella
door, following the exact mechanism every sibling product used (see
e.g. `../aircheck.md`): a per-entry `manifest` object carrying only
`href` (`/town/manifest.webmanifest`) was inserted into Town's entry in
`~/workspace/buckthem-27-program/site/products.json` (surgical textual
insertion; backup `products.json.bak-pre-townpack-20261107`), and
`public/town/manifest.webmanifest` was written with `name` and
`short_name` exactly `Town`, `display: "standalone"`, `start_url` and
`scope` `/town/`, `theme_color` / `background_color` `#faf7f2` (the
umbrella site's own `--paper`), description "Town — " + the entry's own
tagline verbatim, and an empty icon list. The site was regenerated with
`build-site.py`: across the whole `public/` tree the **only** changed
file is `public/town/index.html`, and its only change is the added line
`<link rel="manifest" href="/town/manifest.webmanifest">` (byte-diff
against the pre-step page). Local server check: `/town` 200,
`/town/manifest.webmanifest` 200 as `application/manifest+json`.
**Not yet deployed:** the Hetzner deploy of the umbrella tree is a
separate parent-lane step (one-writer rule) — until it runs, the live
site serves the pre-step Town page without the manifest link.

**True-width render check (2026-11-07, same run):** the local tree's
`/town` page was rendered in the Playwright-bundled Chromium at 390 px
and 1280 px — horizontal overflow = none at either width, title exactly
"Town", and the page inspected visually at both widths (clean
single-column layout, name-exactness surfaces correct). This also
closes, for the changed surfaces, the Final Report's named limitation
that true-width pixel verification was environment-blocked from this VM:
the managed Chromium binary still refuses to start here, but the
Playwright-bundled Chromium launches cleanly.

## How far it got (verified 2026-11-07)

- Config audit passed: `capacitor.config.json` parses; `appName` reads
  back exactly `Town`; `webDir` is `www`; `backgroundColor` is
  `#faf7f2`; the proposed `appId` reads back as above; `server.url`
  reads back exactly `https://buckthem.com/town`. `package.json` is
  valid with the house Capacitor dependency set (^6.1.2 +
  `@capacitor/assets` ^3.0.5).
- **No SDKs were installed, no platform project was generated, and no
  native compilation was attempted** — per the packaging step's rules.

## What remains for the native compile step (Tyler-gated)

1. Tyler confirms or replaces the proposed bundle ID, and supplies
   icon/art if he wants any (art iterates as mockups in the parent
   lane, per his ruling).
2. Town's own founder decisions from its cycle record: real
   accounts/backend hosting, the named external service for the
   API/auto-share machinery, trademark counsel, the "Sit by" veto —
   all Tyler's, none advanced here.
3. On Tyler's Mac: `npm install`, `npx cap add ios`,
   `npx cap add android`, `npm run assets`, `npx cap sync`, wire the
   push/share plugins, then build/sign in Xcode / Android Studio —
   behind PerkWatch on the shared runner.
4. Apple Developer / Google Play enrollment + fees, store records, and
   submission — all Tyler's gates, none attempted here.
