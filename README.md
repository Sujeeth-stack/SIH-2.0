# SANGAM — Phase 1, Citizen Engagement Module

A Flutter app for reporting civic problems in Jharkhand. It opens straight onto
the main page — there is no login, no register, no OTP anywhere in the route
table — and every report it sends is written to Postgres.

**Report → Upload → Track.**

---

## What is here

| Path | What it is |
|---|---|
| `sangam_app/` | The Flutter app (Android + Linux desktop targets) |
| `sangam_api/` | Node/Express API, the only thing that touches the database |
| `sangam_api/db/001_init.sql` | The Postgres schema |
| `scripts/` | Start / stop / run / tunnel helpers |
| `DEPLOY.md` | Putting the API on a permanent public address |
| `render.yaml` | Render Blueprint — must stay at the repo root |

The database is a **portable Postgres 16.4** under `~/pgsql`, running on port
**5433** as user `sangam`. It needed no root to install and it is not a system
service — start it with the script below.

---

The deployed API lives at **https://sangam-api-uz80.onrender.com**, which is
the default compiled into the app. Nothing below is needed just to use it —
only to develop against a local stack.

## Running it

```bash
# Terminal 1 — database + API (migrates and seeds on every start)
./scripts/api-start.sh

# Terminal 2 — the app
./scripts/app-run.sh                    # default device
./scripts/app-run.sh emulator-5554      # an Android emulator
flutter devices                         # to list what is attached
```

`app-run.sh` picks the right base URL for you: an Android emulator reaches the
host at `10.0.2.2`, everything else at `127.0.0.1`. Override it with
`API_BASE_URL=... ./scripts/app-run.sh`.

To point the app at a real server:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.in
```

That flag only sets the **default**. At runtime the address is editable in
**Settings → Server**, so one installed APK can follow a backend that moves —
a tunnel URL that changed, a laptop on a new network, or the real deployment
later — without anyone rebuilding it. Whatever is set there is remembered and
wins over the compiled-in value; **Reset** returns to it.

### Letting phones off this Wi-Fi reach the API

A LAN address like `10.122.93.141:4000` only means anything inside your own
network, so a friend's phone elsewhere cannot use it. To publish the local API
on a public HTTPS URL:

```bash
./scripts/tunnel-start.sh
```

It prints a `https://….trycloudflare.com` address — free, no account. Put that
into the app under **Settings → Server → Test and save**.

Two things to know: your laptop has to stay on with the tunnel running, and
the free URL changes every restart (which is exactly what the Settings field
is for). The script forces `--protocol http2`, because QUIC is throttled on
many networks and fails as `timeout: no recent network activity`.

For something that outlives your laptop, see **[DEPLOY.md](DEPLOY.md)** — a
Render blueprint is included, so it is New → Blueprint → Apply, and the API
migrates and seeds itself on first boot.

### Checks

```bash
./scripts/test-all.sh     # flutter analyze + flutter test
```

### Looking inside the database

The portable Postgres bundle ships no `psql`, so use:

```bash
./scripts/db-show.sh                      # counts, status breakdown, recent reports
./scripts/db-show.sh problems             # every report
./scripts/db-show.sh devices              # who has reported, and how much
./scripts/db-show.sh media                # uploaded evidence
./scripts/db-show.sh history JH-DMK-000417
./scripts/db-show.sh sql "SELECT domain, count(*) FROM problems GROUP BY 1"
```

`sql` refuses anything that is not a SELECT — schema changes belong in a
migration under `sangam_api/db/`.

To point a GUI (DBeaver, pgAdmin, TablePlus) at it:

| | |
|---|---|
| Host | `127.0.0.1` |
| Port | **5433** (not 5432) |
| Database | `sangam` |
| User | `sangam` |
| Password | `sangam_dev_pw` |

The server only listens on loopback, so a GUI has to run on this machine.

### Demo data

```bash
cd sangam_api && npm run seed:demo
```

Seven reports across seven districts, one in every status colour, so the
dashboard and the status rail have something to show. Safe to re-run — it
clears its own previous rows first.

---

## Identity without accounts

There are no users. On first launch the app generates a UUID and keeps it in
`SharedPreferences`. Every write carries it.

It is a **bookmark, not a credential**. It answers one question — *whose reports
appear under "My reports"?* — and nothing else. Two consequences, both
deliberate:

- Reinstalling the app mints a new ID, so "My reports" comes up empty. The
  reports are not lost: they stay reachable forever by their printed ID.
- Anyone can look up any report by its public ID. That is the transparency
  path, not a leak.

Reporter details (name, phone, "reporting on behalf of") are optional, saved on
the device, and **never verified**. The app never asserts that a report came
from a Panchayat or a department — it only records what someone typed. In Phase
2 an officer sets `official_source` after checking, and that is the only place
trust is ever asserted.

---

## Data model

Schema lives in `sangam_api/db/001_init.sql` — the v2 baseline with the v3
deltas already folded in, so there are no `users` or `refresh_tokens` tables to
drop.

- `devices` — device UUID, platform, optional self-declared reporter details
- `problems` — the report, `device_id` FK, `reporter_type`, `official_source`
- `problem_media` — one row per photo / video / voice note / document
- `problem_status_history` — the "Updates" timeline; `actor` is free text
  (`citizen` | `system` | `officer:<name>`)
- `districts`, `ref_counters` — 24 Jharkhand districts and the per-district
  counter behind each public ID

Public IDs read `JH-DMK-000417`: state, district, and a per-district sequence.
The counter row is locked `FOR UPDATE` during allocation, so two people
submitting from Dumka at the same moment can never be given the same number.

---

## API

No `Authorization` header on any endpoint. The device ID rides along as
`X-Device-Id` purely so the server can attribute and rate-limit writes.

| Method | Endpoint | Notes |
|---|---|---|
| `GET` | `/health` | |
| `POST` | `/devices` | Upsert; called silently on first launch |
| `PATCH` | `/devices/:id` | Optional reporter details |
| `POST` | `/problems` | **Idempotent on `problem_id`** |
| `GET` | `/problems?device_id=&since=` | "My reports", delta via `since` |
| `GET` | `/problems/:id` | Detail + media + status history |
| `GET` | `/problems/ref/:public_ref` | Public lookup by printed ID |
| `POST` | `/problems/:id/media` | multipart upload |
| `GET` | `/media/:id` | Serves the file |
| `POST` | `/problems/:id/status` | Officer note — Phase 2 stand-in |
| `GET` | `/geo/reverse?lat=&lon=` | Nearest district centroid |
| `GET` | `/analytics/summary` | Dashboard counts, read-open |
| `GET` | `/reference/domains`, `/reference/districts` | Chip and picker data |

**Idempotency.** The app mints `problem_id` before it submits, so a retry after
a timeout re-reads the existing row rather than filing a second report.

**Rate limit.** 20 submissions per device per day. The 21st gets a 429 and a
plain sentence, not an error code.

---

## Deviations from the written spec

Three, all deliberate, none silent:

1. **No local SQLite / no offline outbox.** The spec is offline-first with Drift
   and a `SyncService`; this build writes straight to Postgres, per the decision
   to make Postgres the only store. The cost is real and worth stating plainly:
   **a report cannot be submitted with no network**, so the airplane-mode item
   in the Phase 1 test checklist cannot pass as written. Home shows a "cannot
   reach the server" banner instead. Everything needed to add the offline layer
   later is isolated behind `SangamApi` — no screen would have to change.

2. **Media upload is multipart, not presign/confirm.** `POST /media/presign` +
   `/media/:id/confirm` assumes MinIO. With no object store in Phase 1, the API
   takes the file directly and records the row, which keeps every byte
   accounted for in Postgres. Swapping in presigned S3 URLs later touches one
   method.

3. **Express, not NestJS.** The backend is ~450 lines serving the same contract.
   Nothing in the app depends on which framework is behind it.

Also worth knowing: `/geo/reverse` matches against district centroids rather
than real boundaries. It is accurate enough to label and route a report, and a
reporter near a district line can always correct it with "Adjust district".

---

## Design system

"Clean civic white", exactly as specified: one blue accent (`#1F5FBF`), 1 px
borders instead of shadows, an 8-pt spacing grid, 48 px minimum tap targets,
Inter with Noto Sans Devanagari behind it so Hindi never falls back to a system
font. Tokens live in `lib/core/theme.dart` and nothing hard-codes a colour
outside `AppColors`.

Both faces are **bundled as assets** (`assets/fonts/`) rather than fetched at
runtime, so type renders identically offline and on first launch. Note that any
explicit `TextStyle` in a component theme must carry `kFontFamily` and
`kFontFallback` — a bare `TextStyle` drops the family and silently falls back
to the platform font.

The one memorable element is the **report card**: a quiet white card with a
4 px coloured rail down its left edge that tracks the status. Everything else
stays out of the way. The dashboard draws its bars from the same tokens rather
than pulling in a chart library.

Motion is limited to a single 400 ms check on submit, and it respects the
system's reduced-motion setting.

---

## Screens

Home · Report (3 steps) · Submitted · My reports · Report detail · Dashboard ·
Public lookup · Settings. Bottom navigation is three tabs — Home, My reports,
Dashboard — with labels always visible.

---

## Tests

`flutter test` runs 26 tests:

- **`widget_test.dart`** — status vocabulary and the report card, no network.
- **`home_ui_test.dart`** — drives Home through a stubbed HTTP adapter:
  the first frame is the main page, no login text exists anywhere, reports
  render with ID and status, the empty state appears, and an unreachable
  server degrades to a banner rather than a dead screen.
- **`screens_golden_test.dart`** — renders every screen at 390x844 and writes
  a PNG to `test/screens/`. Regenerate with
  `flutter test test/screens_golden_test.dart --update-goldens`. It loads the
  bundled fonts plus MaterialIcons, so the images show real type and real
  icons rather than the test framework's placeholder boxes. This is how to
  review the UI without a device, and it catches type regressions — it already
  caught button labels silently falling back to the platform font.
- **`e2e_test.dart`** — hits the **real API and Postgres**: a submitted report
  is persisted, resolves its own district from coordinates, is idempotent on
  re-post, and comes back by public ID. These skip themselves when the API is
  not running, so the suite stays green without a backend.

---

## Known gaps for Phase 2

- Offline submission (see deviation 1).
- Hindi strings — the type stack is ready, the copy is still English.
- Map preview on Report step 2 is a location card, not a rendered map.
- The officer console. `POST /problems/:id/status` exists so the Updates
  timeline can be exercised end to end, and it is deliberately unauthenticated
  in Phase 1 — it must be put behind the officer's login before this is exposed
  beyond a development machine.
