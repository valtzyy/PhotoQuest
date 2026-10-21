// Uji perhitungan matahari terbit/terbenam (tanpa internet).
const { test } = require('node:test');
const assert = require('node:assert');

const { sunTimes } = require('../src/services/solarService');

const WIB_MS = 7 * 3600 * 1000;
const wibMinutes = (date) => {
  const d = new Date(date.getTime() + WIB_MS);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
};

test('Yogyakarta 21 Okt 2026 sesuai Open-Meteo (05:13 / 17:32 WIB) dengan selisih <= 3 menit', () => {
  const { sunrise, sunset } = sunTimes(2026, 10, 21, -7.797, 110.37);
  assert.ok(Math.abs(wibMinutes(sunrise) - (5 * 60 + 13)) <= 3, `sunrise ${sunrise.toISOString()}`);
  assert.ok(Math.abs(wibMinutes(sunset) - (17 * 60 + 32)) <= 3, `sunset ${sunset.toISOString()}`);
});

test('Sunrise selalu sebelum sunset dan siang berdurasi ±12 jam di khatulistiwa', () => {
  for (const [m, d] of [[1, 15], [4, 1], [7, 10], [12, 31]]) {
    const { sunrise, sunset } = sunTimes(2026, m, d, -7.797, 110.37);
    const hours = (sunset - sunrise) / 3600000;
    assert.ok(hours > 11.5 && hours < 12.6, `bulan ${m}: ${hours} jam`);
  }
});

test('Lokasi kutub saat malam/siang polar -> null', () => {
  assert.strictEqual(sunTimes(2026, 12, 21, 89, 0), null);
});
