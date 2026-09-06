// One-shot CLI wrapper around the district seed.
const db = require('./db');
const seedDistricts = require('./seed_districts');

async function main() {
  await seedDistricts();
  const { rows } = await db.query('SELECT count(*)::int AS n FROM districts');
  console.log(`seeded ${rows[0].n} districts`);
  await db.pool.end();
}

main().catch((e) => { console.error(e.message); process.exit(1); });
