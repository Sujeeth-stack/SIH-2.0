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

// Whether to use TLS, which is not a simple yes/no.
//
// Public Postgres (Neon, Supabase, Render's *external* host) requires TLS.
// But a provider's own private network usually does not terminate it at all:
// Render's internal connection string is a bare hostname like "dpg-abc123-a",
// and forcing TLS there fails with "The server does not support SSL
// connections" — which is exactly how the first deploy broke.
//
// Order: explicit env override, then sslmode in the URL, then the hostname.
function sslSetting() {
  if (!url) return false;                       // loopback, no TLS needed
  if (process.env.PGSSL === 'disable') return false;
  if (process.env.PGSSL === 'require') return true;
  if (process.env.PGSSL_NO_VERIFY === '1') return { rejectUnauthorized: false };

  let host = '';
  let mode = null;
  try {
    const parsed = new URL(url);
    host = parsed.hostname;
    mode = parsed.searchParams.get('sslmode');
  } catch {
    return true;                                // unparseable: assume public
  }

  if (mode === 'disable') return false;
  if (mode) return true;                        // require / verify-* / prefer

  // Private networks do not terminate TLS. A bare name with no dot is one
  // (Render internal, docker links), as are these suffixes, loopback, and the
  // RFC 1918 ranges.
  const privateSuffix = ['.internal', '.flycast', '.local', '.localdomain'];
  if (!host.includes('.')) return false;
  if (privateSuffix.some((suffix) => host.endsWith(suffix))) return false;
  if (host === 'localhost' || host === '::1') return false;
  if (/^127\./.test(host)) return false;
  if (/^10\./.test(host)) return false;
  if (/^192\.168\./.test(host)) return false;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(host)) return false;

  return true;                                  // public host: verify certs
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
