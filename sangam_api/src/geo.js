const districts = require('./districts');

function haversineKm(aLat, aLon, bLat, bLon) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLon = toRad(bLon - aLon);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

// Nearest district centroid. Good enough to label a report and to route it
// to a district; it is not a substitute for a real boundary lookup.
function reverse(lat, lon) {
  let best = null;
  for (const d of districts) {
    const km = haversineKm(lat, lon, d.lat, d.lon);
    if (!best || km < best.distance_km) best = { ...d, distance_km: km };
  }
  return {
    district_code: best.code,
    district_name: best.name,
    state: 'Jharkhand',
    distance_km: Math.round(best.distance_km * 10) / 10,
    label: `${best.name}, Jharkhand`,
  };
}

module.exports = { reverse, haversineKm };
