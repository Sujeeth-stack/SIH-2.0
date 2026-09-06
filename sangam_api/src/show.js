#!/usr/bin/env node
// A quick look inside the database, since the portable Postgres bundle ships
// no psql. Usage:
//   node src/show.js              summary + recent reports
//   node src/show.js problems     every report
//   node src/show.js devices      registered devices
//   node src/show.js media        uploaded evidence
//   node src/show.js history <public_ref>   the Updates timeline for one report
//   node src/show.js sql "SELECT ..."       any read-only query
const db = require('./db');

const [, , cmd = 'summary', ...rest] = process.argv;

function table(rows) {
  if (!rows.length) return console.log('  (no rows)');
  console.table(rows);
}

async function main() {
  switch (cmd) {
    case 'summary': {
      const counts = await db.query(`
        SELECT
          (SELECT count(*) FROM devices)                AS devices,
          (SELECT count(*) FROM problems)               AS problems,
          (SELECT count(*) FROM problem_media)          AS media,
          (SELECT count(*) FROM problem_status_history) AS updates,
          (SELECT count(*) FROM districts)              AS districts`);
      console.log('\n== row counts ==');
      table(counts.rows);

      const byStatus = await db.query(
        `SELECT status, count(*)::int AS n FROM problems GROUP BY status ORDER BY n DESC`);
      console.log('== by status ==');
      table(byStatus.rows);

      const recent = await db.query(`
        SELECT p.public_ref, p.title, p.status, d.name AS district,
               to_char(p.created_at,'DD Mon HH24:MI') AS created
          FROM problems p LEFT JOIN districts d ON d.code = p.district_code
         ORDER BY p.created_at DESC LIMIT 15`);
      console.log('== 15 most recent reports ==');
      table(recent.rows);
      break;
    }

    case 'problems': {
      const r = await db.query(`
        SELECT p.public_ref, p.title, p.domain, p.status, d.name AS district,
               p.people_affected, p.device_id,
               to_char(p.created_at,'DD Mon HH24:MI') AS created
          FROM problems p LEFT JOIN districts d ON d.code = p.district_code
         ORDER BY p.created_at DESC`);
      table(r.rows);
      break;
    }

    case 'devices': {
      const r = await db.query(`
        SELECT d.device_id, d.platform, d.reporter_name, d.reporter_type,
               (SELECT count(*)::int FROM problems p WHERE p.device_id = d.device_id) AS reports,
               to_char(d.last_seen_at,'DD Mon HH24:MI') AS last_seen
          FROM devices d ORDER BY d.last_seen_at DESC`);
      table(r.rows);
      break;
    }

    case 'media': {
      const r = await db.query(`
        SELECT m.media_id, m.kind, m.mime_type, m.byte_size, p.public_ref
          FROM problem_media m JOIN problems p USING (problem_id)
         ORDER BY m.created_at DESC`);
      table(r.rows);
      break;
    }

    case 'history': {
      const ref = rest[0];
      if (!ref) return console.log('Usage: node src/show.js history JH-DMK-000417');
      const r = await db.query(`
        SELECT h.status, h.actor, h.note,
               to_char(h.created_at,'DD Mon HH24:MI') AS at
          FROM problem_status_history h JOIN problems p USING (problem_id)
         WHERE upper(p.public_ref) = upper($1)
         ORDER BY h.created_at`, [ref]);
      table(r.rows);
      break;
    }

    case 'sql': {
      const q = rest.join(' ');
      if (!q) return console.log('Usage: node src/show.js sql "SELECT ..."');
      if (!/^\s*select/i.test(q)) {
        console.error('Only SELECT is allowed here — use a migration for changes.');
        process.exit(1);
      }
      const r = await db.query(q);
      table(r.rows);
      break;
    }

    default:
      console.log('Unknown command. Try: summary | problems | devices | media | history <ref> | sql "..."');
  }
  await db.pool.end();
}

main().catch((e) => { console.error(e.message); process.exit(1); });
