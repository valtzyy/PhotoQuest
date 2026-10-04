// Cuaca & golden hour dari Open-Meteo (tanpa API key).
//
// Lapisan fallback:
//   1. Cache memori < 30 menit           -> source "cache"
//   2. Panggil Open-Meteo (timeout 8 dtk) -> source "live"
//   3. Gagal -> cache lama (berapa pun umurnya) -> source "cache"
//   4. Tidak ada cache -> estimasi sunrise 05:30 / sunset 17:45 WIB -> source "estimate"
const axios = require('axios');
const config = require('../config');

const OPEN_METEO_URL = 'https://api.open-meteo.com/v1/forecast';
const TIMEZONE = 'Asia/Jakarta';
const WIB_OFFSET_SECONDS = 7 * 3600;
const CACHE_TTL_MS = 30 * 60 * 1000; // 30 menit
const GOLDEN_HOUR_MS = 60 * 60 * 1000; // 60 menit
const FORECAST_DAYS = 7;

// Deskripsi kode cuaca WMO yang dipakai Open-Meteo.
function describeWeatherCode(code) {
  if (code === 0) return 'Cerah';
  if (code === 1) return 'Cerah berawan';
  if (code === 2) return 'Berawan sebagian';
  if (code === 3) return 'Mendung';
  if (code === 45 || code === 48) return 'Berkabut';
  if (code >= 51 && code <= 57) return 'Gerimis';
  if (code >= 61 && code <= 67) return 'Hujan';
  if (code >= 71 && code <= 77) return 'Salju';
  if (code >= 80 && code <= 82) return 'Hujan lokal';
  if (code >= 95) return 'Badai petir';
  return 'Tidak diketahui';
}

// Format offset detik -> "+07:00"
function offsetString(seconds) {
  const sign = seconds >= 0 ? '+' : '-';
  const abs = Math.abs(seconds);
  const hh = String(Math.floor(abs / 3600)).padStart(2, '0');
  const mm = String(Math.floor((abs % 3600) / 60)).padStart(2, '0');
  return `${sign}${hh}:${mm}`;
}

// "2026-10-04T05:21" (waktu lokal Open-Meteo) -> "2026-10-04T05:21:00+07:00"
function withOffset(localIso, offsetSeconds) {
  const base = localIso.length === 16 ? `${localIso}:00` : localIso;
  return `${base}${offsetString(offsetSeconds)}`;
}

// Date -> ISO dengan offset tertentu, mis. "2026-10-04T06:21:00+07:00"
function toOffsetIso(date, offsetSeconds) {
  const shifted = new Date(date.getTime() + offsetSeconds * 1000);
  return `${shifted.toISOString().slice(0, 19)}${offsetString(offsetSeconds)}`;
}

/**
 * Golden hour (definisi aplikasi ini):
 *   pagi = sunrise -> sunrise + 60 menit
 *   sore = sunset - 60 menit -> sunset
 */
function goldenHours(sunriseIso, sunsetIso, offsetSeconds) {
  const sunrise = new Date(sunriseIso);
  const sunset = new Date(sunsetIso);
  return {
    golden_morning: {
      start: toOffsetIso(sunrise, offsetSeconds),
      end: toOffsetIso(new Date(sunrise.getTime() + GOLDEN_HOUR_MS), offsetSeconds),
    },
    golden_evening: {
      start: toOffsetIso(new Date(sunset.getTime() - GOLDEN_HOUR_MS), offsetSeconds),
      end: toOffsetIso(sunset, offsetSeconds),
    },
  };
}

// Ubah respons mentah Open-Meteo menjadi format PhotoQuest.
function fromOpenMeteo(raw, now = new Date()) {
  const offset = raw.utc_offset_seconds ?? WIB_OFFSET_SECONDS;

  const days = raw.daily.time.map((date, i) => {
    const sunrise = withOffset(raw.daily.sunrise[i], offset);
    const sunset = withOffset(raw.daily.sunset[i], offset);
    return { date, sunrise, sunset, ...goldenHours(sunrise, sunset, offset) };
  });

  const hourly = raw.hourly.time.map((t, i) => ({
    time: withOffset(t, offset),
    cloud_cover: raw.hourly.cloud_cover[i],
    precipitation_probability: raw.hourly.precipitation_probability[i],
  }));

  const c = raw.current;
  const current = c
    ? {
        time: withOffset(c.time, offset),
        temperature: c.temperature_2m,
        cloud_cover: c.cloud_cover,
        weather_code: c.weather_code,
        description: describeWeatherCode(c.weather_code),
      }
    : null;

  return {
    source: 'live',
    is_estimate: false,
    fetched_at: now.toISOString(),
    timezone: raw.timezone || TIMEZONE,
    current,
    days,
    hourly,
  };
}

// Estimasi jika API gagal dan belum ada cache: sunrise 05:30, sunset 17:45 WIB.
function estimate(now = new Date()) {
  const days = [];
  for (let i = 0; i < FORECAST_DAYS; i++) {
    // Tanggal kalender WIB untuk hari ke-i
    const wib = new Date(now.getTime() + WIB_OFFSET_SECONDS * 1000 + i * 86400000);
    const date = wib.toISOString().slice(0, 10);
    const sunrise = `${date}T05:30:00+07:00`;
    const sunset = `${date}T17:45:00+07:00`;
    days.push({ date, sunrise, sunset, ...goldenHours(sunrise, sunset, WIB_OFFSET_SECONDS) });
  }
  return {
    source: 'estimate',
    is_estimate: true,
    fetched_at: now.toISOString(),
    timezone: TIMEZONE,
    current: null,
    days,
    hourly: [],
  };
}

/**
 * Factory agar mudah diuji: `fetcher` dan `now` bisa diganti di tes.
 */
function createWeatherService({
  fetcher = (params) =>
    axios.get(OPEN_METEO_URL, { params, timeout: config.externalTimeoutMs }).then((r) => r.data),
  now = () => new Date(),
} = {}) {
  const cache = new Map(); // key "lat,lng" (2 desimal ~ 1 km) -> { data, savedAt }

  async function getWeather(lat, lng) {
    const key = `${lat.toFixed(2)},${lng.toFixed(2)}`;
    const cached = cache.get(key);

    // 1. Cache masih segar (< 30 menit)
    if (cached && now().getTime() - cached.savedAt < CACHE_TTL_MS) {
      return { ...cached.data, source: 'cache' };
    }

    try {
      // 2. Ambil data baru dari Open-Meteo
      const raw = await fetcher({
        latitude: lat,
        longitude: lng,
        daily: 'sunrise,sunset',
        hourly: 'cloud_cover,precipitation_probability',
        current: 'temperature_2m,cloud_cover,weather_code',
        timezone: TIMEZONE,
        forecast_days: FORECAST_DAYS,
      });
      const data = fromOpenMeteo(raw, now());
      cache.set(key, { data, savedAt: now().getTime() });
      return data;
    } catch (err) {
      console.warn('[weather] Open-Meteo gagal:', err.message);
      // 3. Cache lama masih lebih baik daripada estimasi
      if (cached) return { ...cached.data, source: 'cache' };
      // 4. Estimasi
      return estimate(now());
    }
  }

  return { getWeather, clearCache: () => cache.clear() };
}

module.exports = {
  ...createWeatherService(),
  createWeatherService,
  fromOpenMeteo,
  estimate,
  goldenHours,
  describeWeatherCode,
};
