// Matahari terbit/terbenam dihitung langsung dari koordinat (tanpa API).
// Dipakai sebagai cadangan saat Open-Meteo gagal, supaya golden hour tetap akurat.
// Metode: persamaan terbit-terbenam (sunrise equation), akurasi ±2 menit.
const RAD = Math.PI / 180;
const DAY_MS = 86400000;
const J2000_MS = Date.UTC(2000, 0, 1, 12); // Julian Date 2451545.0
const SUN_ALTITUDE = -0.833; // koreksi refraksi atmosfer + jari-jari piringan matahari

/**
 * Sunrise & sunset (instan UTC sebagai Date) untuk tanggal kalender lokal
 * (year, month 1–12, day) di lokasi lat/lng (lng timur positif).
 * Mengembalikan null jika matahari tidak terbit/terbenam (lingkar kutub).
 */
function sunTimes(year, month, day, lat, lng) {
  const n = Math.round((Date.UTC(year, month - 1, day, 12) - J2000_MS) / DAY_MS);
  const meanNoon = n - lng / 360; // hari sejak J2000 saat tengah hari matahari rata-rata

  const anomaly = (357.5291 + 0.98560028 * meanNoon) % 360;
  const center =
    1.9148 * Math.sin(anomaly * RAD) +
    0.02 * Math.sin(2 * anomaly * RAD) +
    0.0003 * Math.sin(3 * anomaly * RAD);
  const eclipticLng = (anomaly + center + 180 + 102.9372) % 360;

  const transit =
    meanNoon + 0.0053 * Math.sin(anomaly * RAD) - 0.0069 * Math.sin(2 * eclipticLng * RAD);
  const sinDecl = Math.sin(eclipticLng * RAD) * Math.sin(23.4397 * RAD);
  const cosDecl = Math.cos(Math.asin(sinDecl));

  const cosHour =
    (Math.sin(SUN_ALTITUDE * RAD) - Math.sin(lat * RAD) * sinDecl) / (Math.cos(lat * RAD) * cosDecl);
  if (cosHour < -1 || cosHour > 1) return null;

  const halfDay = Math.acos(cosHour) / RAD / 360; // dalam hari
  const toDate = (daysSinceJ2000) => new Date(J2000_MS + daysSinceJ2000 * DAY_MS);
  return { sunrise: toDate(transit - halfDay), sunset: toDate(transit + halfDay) };
}

module.exports = { sunTimes };
