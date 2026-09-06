const db = require('./db');
const districts = require('./districts');

/// Idempotent: safe on every boot. Does not close the pool, unlike seed.js
/// which is a one-shot CLI.
module.exports = async function seedDistricts() {
  for (const d of districts) {
    await db.query(
      `INSERT INTO districts (code, name, state_code) VALUES ($1, $2, 'JH')
       ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name`,
      [d.code, d.name]
    );
    await db.query(
      `INSERT INTO ref_counters (district_code) VALUES ($1) ON CONFLICT DO NOTHING`,
      [d.code]
    );
  }
};
