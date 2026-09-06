const { Pool } = require('pg');

// Local development defaults. The database listens on 127.0.0.1 only and
// this password is a throwaway for that local cluster — always override it
// with PGPASSWORD (and the rest) in any deployed environment.
const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5433),
  user: process.env.PGUSER || 'sangam',
  password: process.env.PGPASSWORD || 'sangam_dev_pw',
  database: process.env.PGDATABASE || 'sangam',
  max: 10,
});

module.exports = {
  pool,
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
