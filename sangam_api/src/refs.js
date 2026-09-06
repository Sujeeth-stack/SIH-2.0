// public_ref allocation: JH-DMK-000417
// Counter row is locked FOR UPDATE so two concurrent submits in the same
// district can never be handed the same number.
async function nextPublicRef(client, districtCode) {
  const code = districtCode || 'RAN';
  await client.query(
    `INSERT INTO ref_counters (district_code) VALUES ($1) ON CONFLICT DO NOTHING`,
    [code]
  );
  const { rows } = await client.query(
    `UPDATE ref_counters SET last_value = last_value + 1
      WHERE district_code = $1 RETURNING last_value`,
    [code]
  );
  const n = String(rows[0].last_value).padStart(6, '0');
  return `JH-${code}-${n}`;
}
module.exports = { nextPublicRef };
