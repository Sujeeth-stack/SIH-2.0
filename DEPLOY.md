# Deploying the SANGAM API

Goal: a permanent `https://…` address that works whether or not your laptop is
on, so the app stops depending on a tunnel URL that changes every restart.

You only need to do this once. Afterwards you put the address into the app under
**Settings → Server → Test and save**, and it stays put.

---

## Render (recommended — free, no card)

1. Push this repo to GitHub (already done: `Sujeeth-stack/SIH-2.0`).
2. Sign up at https://render.com with your GitHub account.
3. **New → Blueprint**, pick the `SIH-2.0` repo, **Apply**.

`render.yaml` has to be at the repository root — Render never looks inside
subdirectories for it.

### If the repo does not appear in the list

Render lists repos only for the GitHub account it is connected to. If you
signed into Render with a different GitHub account than the one that owns
`SIH-2.0`, it will not be there. Two ways out:

- **Deploy by URL.** The Blueprint page has a *Public Git repository* field.
  Paste `https://github.com/Sujeeth-stack/SIH-2.0` — the repo is public, so no
  account connection is needed at all.
- **Grant access.** Log into GitHub as the account that owns the repo, then
  install the Render GitHub App on it
  (https://github.com/apps/render → Configure → pick the account → allow
  `SIH-2.0`). Reload Render and it appears.

`render.yaml` does the rest: it creates the web service and a Postgres
instance, sets `DATABASE_URL` on the service, and the API migrates and seeds
the 24 districts on first boot. No shell step.

You end up with something like `https://sangam-api.onrender.com`. Check it:

```
https://sangam-api.onrender.com/health
```

### Two things about Render's free tier

- **The service sleeps after ~15 minutes idle.** The next request wakes it and
  takes 30–60 seconds. Mid-demo that reads as a hang, so open `/health` a
  minute before you present to warm it up.
- **The free Postgres expires after 30 days.** Fine for a hackathon. To avoid
  it, use Neon below.

## Neon for the database (free, does not expire)

Worth doing if this has to live longer than a month.

1. Sign up at https://neon.tech, create a project.
2. Copy the connection string — it looks like
   `postgres://user:pass@ep-xxx.aws.neon.tech/neondb?sslmode=require`
3. In Render → your service → **Environment**, replace `DATABASE_URL` with it.
4. Delete the Render database if you no longer want it.

The API migrates the new database on its next boot.

## Any other host

The API needs one variable and nothing else:

```
DATABASE_URL=postgres://user:pass@host:5432/dbname?sslmode=require
```

Optional: `PORT` (default 4000), `DAILY_SUBMIT_LIMIT` (default 20),
`SKIP_MIGRATE=1` to disable migrate-on-boot, `PGSSL_NO_VERIFY=1` only if your
provider uses a self-signed certificate.

A `Dockerfile` is included for hosts without a Node buildpack (Fly.io, Koyeb,
Cloud Run).

---

## Pointing the app at it

No rebuild needed. In the app: **Settings → Server**, paste the address, tap
**Test and save**. It probes the server before saving, so a typo is reported
there rather than making every screen look broken.

To make it the default for new installs, rebuild with:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://sangam-api.onrender.com
```

---

## What changed to make this deployable

- **`DATABASE_URL` support with TLS.** Managed Postgres requires it; the
  local loopback cluster still uses the `PG*` variables and no TLS.
- **Media moved into Postgres.** Uploads used to be written to `./media` on
  disk. A hosted filesystem is rebuilt on every deploy, so photos would have
  vanished while their database rows survived — reports pointing at 404s. The
  bytes now live in a `bytea` column, which is the only durable store Phase 1
  has. Old on-disk rows are still served if their file is present.
- **Migrate and seed on boot.** Hosted platforms give you no shell step, so
  the server applies `db/*.sql` and seeds the districts before it listens.
  Every migration is idempotent, so repeated boots are harmless.

### The one limit to know

Media in Postgres is the right call for Phase 1, but it is not free: Neon's
free tier gives 0.5 GB and Render's 1 GB. At roughly 300 KB per compressed
photo that is a few thousand images — ample for a demo, not for a district
rollout. Phase 2 should move the bytes to S3/R2 and put the key back in
`storage_key`, which the serving code already falls back to.
