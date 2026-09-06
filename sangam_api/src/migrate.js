// Creates the database if missing, then applies db/*.sql in filename order.
const fs = require('fs');
const path = require('path');
const { Client, Pool } = require('pg');

// See the note in db.js: these are local-dev defaults, override via env.
const CFG = {
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5433),
  user: process.env.PGUSER || 'sangam',
  password: process.env.PGPASSWORD || 'sangam_dev_pw',
};
const DBNAME = process.env.PGDATABASE || 'sangam';

// A hosted provider creates the database for us and usually forbids CREATE
// DATABASE, so this step only applies to the local cluster.
async function ensureDatabase() {
  if (process.env.DATABASE_URL) return;
  const admin = new Client({ ...CFG, database: 'postgres' });
  await admin.connect();
  const { rowCount } = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [DBNAME]);
  if (rowCount === 0) {
    await admin.query(`CREATE DATABASE ${DBNAME}`);
    console.log(`created database ${DBNAME}`);
  } else {
    console.log(`database ${DBNAME} already present`);
  }
  await admin.end();
}

async function applyTo(pool) {
  const dir = path.join(__dirname, '..', 'db');
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
  for (const f of files) {
    const sql = fs.readFileSync(path.join(dir, f), 'utf8');
    await pool.query(sql);
    console.log(`applied ${f}`);
  }
  const t = await pool.query(
    `SELECT table_name FROM information_schema.tables
      WHERE table_schema='public' ORDER BY table_name`
  );
  console.log('tables:', t.rows.map((r) => r.table_name).join(', '));
}

/// Used by the server on boot so a deploy needs no separate migrate step.
async function migrate() {
  await ensureDatabase();
  const db = require('./db');
  await applyTo(db.pool);
}

async function main() {
  await ensureDatabase();
  const pool = process.env.DATABASE_URL
    ? require('./db').pool
    : new Pool({ ...CFG, database: DBNAME });
  await applyTo(pool);
  await pool.end();
}

module.exports = { migrate };

if (require.main === module) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
