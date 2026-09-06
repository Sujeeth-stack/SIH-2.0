const { Pool } = require('pg');

// Two ways to connect:
//
//   DATABASE_URL=postgres://user:pass@host/db?sslmode=require   (hosted)
//   PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE                  (local dev)
//
// Every managed provider hands out a DATABASE_URL, so that wins when present.
// The local defaults below point at the portable cluster on 127.0.0.1:5433;
// that password is a throwaway for a loopback-only database and must never be
// reused anywhere reachable.
const url = process.env.DATABASE_URL;

// Managed Postgres requires TLS. Certificates are publicly trusted at Neon,
// Supabase and Render's external hosts, so verification stays on by default.
// PGSSL_NO_VERIFY=1 is the escape hatch for a provider using a self-signed
// certificate — it disables verification, so only set it when you must.
function sslSetting() {
  if (!url) return false;                       // loopback, no TLS needed
  if (process.env.PGSSL === 'disable') return false;
  if (process.env.PGSSL_NO_VERIFY === '1') return { rejectUnauthorized: false };
  return true;
}

const pool = new Pool(
  url
    ? { connectionString: url, ssl: sslSetting(), max: Number(process.env.PG_POOL_MAX || 10) }
    : {
        host: process.env.PGHOST || '127.0.0.1',
        port: Number(process.env.PGPORT || 5433),
        user: process.env.PGUSER || 'sangam',
        password: process.env.PGPASSWORD || 'sangam_dev_pw',
        database: process.env.PGDATABASE || 'sangam',
        max: Number(process.env.PG_POOL_MAX || 10),
      }
);

// A dropped backend (idle timeout, provider restart) must not take the
// process down with it; pg reconnects on the next query.
pool.on('error', (err) => {
  console.error('postgres pool error:', err.message);
});

module.exports = {
  pool,
  isHosted: !!url,
  query: (text, params) => pool.query(text, params),
  // Runs fn inside a transaction, rolling back on any throw.
  async tx(fn) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const out = await fn(client);
      await client.query('COMMIT');
      return out;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  },
};
