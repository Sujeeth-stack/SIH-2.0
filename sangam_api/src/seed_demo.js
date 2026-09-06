// Optional demo data so the dashboard has something to show in a walkthrough.
// Safe to re-run: it clears anything it previously inserted first.
const crypto = require('crypto');
const db = require('./db');
const geo = require('./geo');
const { nextPublicRef } = require('./refs');

const DEMO_DEVICE = '00000000-0000-4000-8000-000000000001';

const SAMPLES = [
  ['Handpump dry for three weeks', 'The only handpump in the tola has run dry. Women walk 2 km for water.',
   'WATER', 'DMK', 180, 'MORE_THAN_MONTH', 'IN_EXECUTION',
   'Block office verified. Tanker arranged while the borewell is deepened.', 'officer:BDO Dumka'],
  ['School toilet blocked since the rains', 'Girls have stopped coming to school after lunch.',
   'SANITATION', 'RAN', 240, 'ONE_TO_FOUR_WEEKS', 'VALIDATED',
   'Verified with the headmaster. Routed to the education engineer.', 'officer:BEEO Ranchi'],
  ['Culvert washed away on the school road', 'Children wade through the drain to reach school.',
   'ROADS', 'HAZ', 320, 'ONE_TO_FOUR_WEEKS', 'ROUTED',
   'Assigned to the rural works division.', 'officer:EE RWD'],
  ['Street light out near the bus stand', 'The stand is dark by 6 pm and unsafe.',
   'ELECTRICITY', 'DHN', 500, 'LESS_THAN_WEEK', 'CLOSED_WITH_IMPACT',
   'Two poles re-wired and switched on. Confirmed by the ward member.', 'officer:JE DMC'],
  ['No ANM visit to the sub-centre for two months', 'Pregnant women are going untested.',
   'HEALTH', 'GUM', 90, 'MORE_THAN_MONTH', 'SUBMITTED', null, null],
  ['Canal breach flooding three fields', 'Standing paddy is under water after the breach.',
   'AGRICULTURE', 'PAL', 45, 'LESS_THAN_WEEK', 'CLASSIFIED',
   'Logged and grouped with two nearby canal reports.', 'system'],
  ['No mobile signal in the panchayat bhawan', 'Nobody can complete an e-KYC without walking to the highway.',
   'CONNECTIVITY', 'SIM', 700, 'MORE_THAN_YEAR', 'REJECTED',
   'Outside district scope — forwarded to the telecom nodal officer.', 'officer:DC Simdega'],
];

async function main() {
  await db.query(
    `INSERT INTO devices (device_id, platform, reporter_name, reporter_type)
     VALUES ($1, 'android', 'Demo reporter', 'CITIZEN')
     ON CONFLICT (device_id) DO NOTHING`,
    [DEMO_DEVICE]
  );

  const removed = await db.query('DELETE FROM problems WHERE device_id = $1', [DEMO_DEVICE]);
  if (removed.rowCount) console.log(`cleared ${removed.rowCount} previous demo reports`);

  for (const [title, description, domain, district, people, duration, status, note, actor] of SAMPLES) {
    const id = crypto.randomUUID();
    const centroid = require('./districts').find((d) => d.code === district);
    const place = geo.reverse(centroid.lat, centroid.lon);

    await db.tx(async (client) => {
      const ref = await nextPublicRef(client, district);
      await client.query(
        `INSERT INTO problems (problem_id, public_ref, title, description, domain, status,
           district_code, location_label, latitude, longitude, people_affected,
           duration_label, consent, device_id, reporter_type, official_source)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,TRUE,$13,'CITIZEN',FALSE)`,
        [id, ref, title, description, domain, status, district, place.label,
         centroid.lat, centroid.lon, people, duration, DEMO_DEVICE]
      );
      await client.query(
        `INSERT INTO problem_status_history (problem_id, status, note, actor)
         VALUES ($1,'SUBMITTED','Report submitted from the SANGAM app.','citizen')`,
        [id]
      );
      if (status !== 'SUBMITTED') {
        await client.query(
          `INSERT INTO problem_status_history (problem_id, status, note, actor)
           VALUES ($1,$2,$3,$4)`,
          [id, status, note, actor]
        );
      }
    });
  }

  const { rows } = await db.query('SELECT count(*)::int n FROM problems WHERE device_id = $1', [DEMO_DEVICE]);
  console.log(`seeded ${rows[0].n} demo reports`);
  await db.pool.end();
}

main().catch((e) => { console.error(e.message); process.exit(1); });
