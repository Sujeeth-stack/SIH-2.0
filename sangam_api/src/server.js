// SANGAM Phase 1 (v3) — citizen engagement API.
// No auth anywhere: identity is a device-generated UUID, which is a bookmark,
// not a credential. Every write records that device_id so "My reports" can be
// answered, and any report stays publicly readable by its public_ref.
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const db = require('./db');
const geo = require('./geo');
const domains = require('./domains');
const districts = require('./districts');
const { nextPublicRef } = require('./refs');

const PORT = Number(process.env.PORT || 4000);
const MEDIA_DIR = path.join(__dirname, '..', 'media');
const DAILY_SUBMIT_LIMIT = Number(process.env.DAILY_SUBMIT_LIMIT || 20);
const MAX_MEDIA_BYTES = 25 * 1024 * 1024;

fs.mkdirSync(MEDIA_DIR, { recursive: true });

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

const REPORTER_TYPES = ['CITIZEN', 'COMMUNITY_GROUP', 'PRI', 'ULB', 'GOVT_DEPT'];
const DOMAIN_CODES = domains.map((d) => d.code);
const MEDIA_KINDS = ['photo', 'video', 'audio', 'doc'];

// Wraps an async handler so a rejected promise becomes a 500 instead of an
// unhandled rejection.
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

function fail(res, status, code, message) {
  return res.status(status).json({ error: { code, message } });
}

// ------------------------------------------------------------------ health
app.get('/health', wrap(async (_req, res) => {
  const { rows } = await db.query('SELECT now() AS now');
  res.json({ status: 'ok', time: rows[0].now, service: 'sangam-api', phase: 1 });
}));

// --------------------------------------------------------------- reference
app.get('/reference/domains', (_req, res) => res.json({ domains }));
app.get('/reference/districts', (_req, res) =>
  res.json({ districts: districts.map(({ code, name }) => ({ code, name })) })
);

// ----------------------------------------------------------------- devices
// Called silently on first launch. Upsert so a reinstall or a language change
// is not an error.
app.post('/devices', wrap(async (req, res) => {
  const { device_id, platform, language } = req.body || {};
  if (!isUuid(device_id)) return fail(res, 400, 'BAD_DEVICE_ID', 'device_id must be a UUID');
  const plat = ['android', 'ios', 'web', 'linux', 'macos', 'windows'].includes(platform)
    ? platform : 'android';

  const { rows } = await db.query(
    `INSERT INTO devices (device_id, platform, language)
     VALUES ($1, $2, COALESCE($3, 'hi'))
     ON CONFLICT (device_id) DO UPDATE
       SET platform = EXCLUDED.platform,
           language = COALESCE($3, devices.language),
           last_seen_at = now()
     RETURNING *`,
    [device_id, plat, language || null]
  );
  res.status(201).json({ device: rows[0] });
}));

// Optional, self-declared reporter details. Nothing here is verified — the
// officer asserts official_source in Phase 2 after checking.
app.patch('/devices/:id', wrap(async (req, res) => {
  const id = req.params.id;
  if (!isUuid(id)) return fail(res, 400, 'BAD_DEVICE_ID', 'device_id must be a UUID');

  const { reporter_name, reporter_phone, reporter_type, reporter_org, language } = req.body || {};
  if (reporter_type && !REPORTER_TYPES.includes(reporter_type)) {
    return fail(res, 400, 'BAD_REPORTER_TYPE', `reporter_type must be one of ${REPORTER_TYPES.join(', ')}`);
  }

  const { rows } = await db.query(
    `UPDATE devices SET
       reporter_name  = COALESCE($2, reporter_name),
       reporter_phone = COALESCE($3, reporter_phone),
       reporter_type  = COALESCE($4, reporter_type),
       reporter_org   = COALESCE($5, reporter_org),
       language       = COALESCE($6, language),
       last_seen_at   = now()
     WHERE device_id = $1
     RETURNING *`,
    [id, reporter_name ?? null, reporter_phone ?? null, reporter_type ?? null,
     reporter_org ?? null, language ?? null]
  );
  if (!rows.length) return fail(res, 404, 'DEVICE_NOT_FOUND', 'Register the device first');
  res.json({ device: rows[0] });
}));

app.get('/devices/:id', wrap(async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 400, 'BAD_DEVICE_ID', 'device_id must be a UUID');
  const { rows } = await db.query('SELECT * FROM devices WHERE device_id = $1', [req.params.id]);
  if (!rows.length) return fail(res, 404, 'DEVICE_NOT_FOUND', 'Unknown device');
  res.json({ device: rows[0] });
}));

// ---------------------------------------------------------------- problems
// Idempotent on problem_id: the client mints the UUID, so a retry after a
// timeout re-reads the existing row instead of creating a duplicate.
app.post('/problems', wrap(async (req, res) => {
  const b = req.body || {};
  const deviceId = b.device_id || req.get('X-Device-Id');
  if (!isUuid(deviceId)) return fail(res, 400, 'BAD_DEVICE_ID', 'device_id must be a UUID');

  const problemId = isUuid(b.problem_id) ? b.problem_id : crypto.randomUUID();
  const title = (b.title || '').trim();
  if (title.length < 3) return fail(res, 400, 'BAD_TITLE', 'Give the problem a short title');
  if (title.length > 200) return fail(res, 400, 'BAD_TITLE', 'Title is too long');

  const domain = DOMAIN_CODES.includes(b.domain) ? b.domain : 'OTHER';

  // Already stored? Return it unchanged — this is the idempotency path.
  const existing = await db.query(
    `SELECT * FROM problems WHERE problem_id = $1`, [problemId]
  );
  if (existing.rows.length) {
    return res.status(200).json({ problem: existing.rows[0], idempotent: true });
  }

  // Device must exist before a report can reference it.
  await db.query(
    `INSERT INTO devices (device_id, platform) VALUES ($1, $2)
     ON CONFLICT (device_id) DO UPDATE SET last_seen_at = now()`,
    [deviceId, b.platform || 'android']
  );

  const { rows: limitRows } = await db.query(
    `SELECT count(*)::int AS n FROM problems
      WHERE device_id = $1 AND created_at > now() - interval '1 day'`,
    [deviceId]
  );
  if (limitRows[0].n >= DAILY_SUBMIT_LIMIT) {
    return fail(res, 429, 'DAILY_LIMIT',
      `You have sent ${DAILY_SUBMIT_LIMIT} reports today. Please try again tomorrow.`);
  }

  // Resolve district from coordinates when the client did not name one.
  let districtCode = b.district_code || null;
  let locationLabel = b.location_label || null;
  const lat = typeof b.latitude === 'number' ? b.latitude : null;
  const lon = typeof b.longitude === 'number' ? b.longitude : null;
  if (!districtCode && lat !== null && lon !== null) {
    const g = geo.reverse(lat, lon);
    districtCode = g.district_code;
    if (!locationLabel) locationLabel = g.label;
  }

  const problem = await db.tx(async (client) => {
    const publicRef = await nextPublicRef(client, districtCode);
    const { rows: dev } = await client.query(
      'SELECT reporter_type FROM devices WHERE device_id = $1', [deviceId]
    );
    const reporterType = dev[0]?.reporter_type || 'CITIZEN';

    const { rows } = await client.query(
      `INSERT INTO problems (
         problem_id, public_ref, title, description, domain, status,
         district_code, location_label, latitude, longitude,
         people_affected, duration_label, consent,
         device_id, reporter_type, official_source
       ) VALUES ($1,$2,$3,$4,$5,'SUBMITTED',$6,$7,$8,$9,$10,$11,$12,$13,$14,FALSE)
       RETURNING *`,
      [problemId, publicRef, title, (b.description || '').trim(), domain,
       districtCode, locationLabel, lat, lon,
       Number.isInteger(b.people_affected) ? b.people_affected : null,
       b.duration_label || null, b.consent === true,
       deviceId, reporterType]
    );

    await client.query(
      `INSERT INTO problem_status_history (problem_id, status, note, actor)
       VALUES ($1, 'SUBMITTED', $2, 'citizen')`,
      [problemId, 'Report submitted from the SANGAM app.']
    );
    return rows[0];
  });

  res.status(201).json({ problem });
}));

// "My reports" for a device, or a delta since a timestamp.
app.get('/problems', wrap(async (req, res) => {
  const deviceId = req.query.device_id || req.get('X-Device-Id');
  if (!isUuid(deviceId)) return fail(res, 400, 'BAD_DEVICE_ID', 'device_id must be a UUID');

  const since = req.query.since ? new Date(String(req.query.since)) : null;
  if (since && Number.isNaN(since.getTime())) {
    return fail(res, 400, 'BAD_SINCE', 'since must be an ISO-8601 timestamp');
  }
  const limit = Math.min(Number(req.query.limit) || 100, 200);

  const { rows } = await db.query(
    `SELECT p.*, d.name AS district_name,
            (SELECT count(*)::int FROM problem_media m WHERE m.problem_id = p.problem_id) AS media_count
       FROM problems p
       LEFT JOIN districts d ON d.code = p.district_code
      WHERE p.device_id = $1
        AND ($2::timestamptz IS NULL OR p.updated_at > $2::timestamptz)
      ORDER BY p.created_at DESC
      LIMIT $3`,
    [deviceId, since ? since.toISOString() : null, limit]
  );
  res.json({ problems: rows, server_time: new Date().toISOString() });
}));

// Public lookup by printed ID — deliberately open, this is the transparency path.
app.get('/problems/ref/:public_ref', wrap(async (req, res) => {
  const ref = String(req.params.public_ref).trim().toUpperCase();
  const { rows } = await db.query(
    `SELECT problem_id FROM problems WHERE upper(public_ref) = $1`, [ref]
  );
  if (!rows.length) return fail(res, 404, 'NOT_FOUND', 'No report with that ID');
  res.json(await detail(rows[0].problem_id));
}));

app.get('/problems/:id', wrap(async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 400, 'BAD_ID', 'problem_id must be a UUID');
  const out = await detail(req.params.id);
  if (!out) return fail(res, 404, 'NOT_FOUND', 'No such report');
  res.json(out);
}));

async function detail(problemId) {
  const { rows } = await db.query(
    `SELECT p.*, d.name AS district_name
       FROM problems p LEFT JOIN districts d ON d.code = p.district_code
      WHERE p.problem_id = $1`,
    [problemId]
  );
  if (!rows.length) return null;
  const media = await db.query(
    `SELECT media_id, kind, mime_type, byte_size, created_at
       FROM problem_media WHERE problem_id = $1 ORDER BY created_at`,
    [problemId]
  );
  const history = await db.query(
    `SELECT id, status, note, actor, created_at
       FROM problem_status_history WHERE problem_id = $1 ORDER BY created_at`,
    [problemId]
  );
  return {
    problem: rows[0],
    media: media.rows.map((m) => ({ ...m, url: `/media/${m.media_id}` })),
    history: history.rows,
  };
}

// ------------------------------------------------------------------- media
// Direct multipart upload. The spec's presign/confirm pair assumes MinIO;
// with no object store in Phase 1 the API writes the file to disk and records
// the row, which keeps every byte accounted for in Postgres.
// Held in memory, then written to Postgres. A hosted filesystem is rebuilt on
// every deploy, so anything left on disk is lost; the database is the only
// durable store Phase 1 has.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_MEDIA_BYTES },
});

app.post('/problems/:id/media', upload.single('file'), wrap(async (req, res) => {
  const problemId = req.params.id;
  if (!isUuid(problemId)) return fail(res, 400, 'BAD_ID', 'problem_id must be a UUID');
  if (!req.file) return fail(res, 400, 'NO_FILE', 'Attach a file field named "file"');

  const owner = await db.query('SELECT device_id FROM problems WHERE problem_id = $1', [problemId]);
  if (!owner.rows.length) return fail(res, 404, 'NOT_FOUND', 'No such report');

  const kind = MEDIA_KINDS.includes(req.body.kind) ? req.body.kind : 'photo';
  const mediaId = crypto.randomUUID();
  const { rows } = await db.query(
    `INSERT INTO problem_media
       (media_id, problem_id, kind, mime_type, byte_size, content)
     VALUES ($1,$2,$3,$4,$5,$6)
     RETURNING media_id, kind, mime_type, byte_size, created_at`,
    [mediaId, problemId, kind, req.file.mimetype, req.file.size, req.file.buffer]
  );
  await db.query('UPDATE problems SET updated_at = now() WHERE problem_id = $1', [problemId]);
  res.status(201).json({ media: { ...rows[0], url: `/media/${mediaId}` } });
}));

app.get('/media/:id', wrap(async (req, res) => {
  if (!isUuid(req.params.id)) return fail(res, 400, 'BAD_ID', 'media_id must be a UUID');
  const { rows } = await db.query(
    `SELECT content, storage_key, mime_type FROM problem_media WHERE media_id = $1`,
    [req.params.id]
  );
  if (!rows.length) return fail(res, 404, 'NOT_FOUND', 'No such media');

  const row = rows[0];
  if (row.mime_type) res.type(row.mime_type);
  // Evidence never changes once uploaded.
  res.set('Cache-Control', 'public, max-age=31536000, immutable');

  if (row.content) return res.send(row.content);

  // Rows created before media moved into the database still point at a file.
  if (row.storage_key) {
    const file = path.join(MEDIA_DIR, path.basename(row.storage_key));
    if (fs.existsSync(file)) return res.sendFile(file);
  }
  return fail(res, 410, 'GONE', 'That file is no longer stored');
}));

// --------------------------------------------------------- status updates
// Phase 2 belongs to the officer console; this endpoint exists now so the
// "Updates" timeline in the app can be exercised end to end.
app.post('/problems/:id/status', wrap(async (req, res) => {
  const problemId = req.params.id;
  if (!isUuid(problemId)) return fail(res, 400, 'BAD_ID', 'problem_id must be a UUID');
  const { status, note, actor } = req.body || {};
  if (!status) return fail(res, 400, 'BAD_STATUS', 'status is required');

  const updated = await db.tx(async (client) => {
    const { rows } = await client.query(
      `UPDATE problems SET status = $2, updated_at = now()
        WHERE problem_id = $1 RETURNING *`,
      [problemId, status]
    );
    if (!rows.length) return null;
    await client.query(
      `INSERT INTO problem_status_history (problem_id, status, note, actor)
       VALUES ($1,$2,$3,$4)`,
      [problemId, status, note || null, actor || 'officer:demo']
    );
    return rows[0];
  });
  if (!updated) return fail(res, 404, 'NOT_FOUND', 'No such report');
  res.json({ problem: updated });
}));

// --------------------------------------------------------------------- geo
app.get('/geo/reverse', (req, res) => {
  const lat = Number(req.query.lat);
  const lon = Number(req.query.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return fail(res, 400, 'BAD_COORDS', 'lat and lon must be numbers');
  }
  res.json(geo.reverse(lat, lon));
});

// --------------------------------------------------------------- analytics
app.get('/analytics/summary', wrap(async (_req, res) => {
  const [byStatus, byDistrict, byDomain, totals] = await Promise.all([
    db.query(`SELECT status, count(*)::int AS count FROM problems GROUP BY status ORDER BY count DESC`),
    db.query(
      `SELECT p.district_code AS code, COALESCE(d.name, 'Unknown') AS name, count(*)::int AS count
         FROM problems p LEFT JOIN districts d ON d.code = p.district_code
        GROUP BY p.district_code, d.name ORDER BY count DESC`
    ),
    db.query(`SELECT domain, count(*)::int AS count FROM problems GROUP BY domain ORDER BY count DESC`),
    db.query(
      `SELECT count(*)::int AS total,
              count(*) FILTER (WHERE status IN ('CLOSED_WITH_IMPACT','DEPLOYED'))::int AS resolved,
              count(*) FILTER (WHERE status NOT IN ('CLOSED_WITH_IMPACT','DEPLOYED','REJECTED'))::int AS open
         FROM problems`
    ),
  ]);
  res.json({
    totals: totals.rows[0],
    by_status: byStatus.rows,
    by_district: byDistrict.rows,
    by_domain: byDomain.rows,
    generated_at: new Date().toISOString(),
  });
}));

// ------------------------------------------------------------------ errors
app.use((err, _req, res, _next) => {
  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return fail(res, 413, 'FILE_TOO_LARGE', 'Each file must be under 25 MB');
  }
  console.error(err);
  fail(res, 500, 'SERVER_ERROR', 'Something went wrong on the server');
});

app.use((_req, res) => fail(res, 404, 'NO_ROUTE', 'Unknown endpoint'));

async function start() {
  // Bring the schema up to date before serving. Hosted deploys have no shell
  // step, and running this twice is harmless — every migration is idempotent.
  if (process.env.SKIP_MIGRATE !== '1') {
    try {
      await require('./migrate').migrate();
      if (process.env.SEED_DISTRICTS !== '0') {
        await require('./seed_districts')();
      }
    } catch (e) {
      console.error('migration failed:', e.message);
      process.exit(1);
    }
  }
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`sangam-api listening on http://0.0.0.0:${PORT}`);
  });
}

if (require.main === module) start();

module.exports = app;
