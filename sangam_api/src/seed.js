const db = require('./db');
const districts = require('./districts');

async function main() {
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
  const { rows } = await db.query('SELECT count(*)::int AS n FROM districts');
  console.log(`seeded ${rows[0].n} districts`);
  await db.pool.end();
}

main().catch((e) => { console.error(e.message); process.exit(1); });
