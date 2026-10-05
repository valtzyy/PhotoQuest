// Route AI: Shoot Condition Score (+ rekomendasi) dan Photography Assistant (chat).
const express = require('express');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');
const weatherService = require('../services/weatherService');
const { calculateScore, PHOTO_TYPES } = require('../services/scoreService');
const { getRecommendation } = require('../services/recommendationService');
const { generateText, LlmUnavailableError } = require('../services/llmService');

const router = express.Router();
router.use(requireAuth);

const HOUR_MS = 3600 * 1000;
const DAY_MS = 24 * HOUR_MS;
// Nilai default jika prakiraan per jam tidak tersedia (mis. tanggal > 7 hari).
const DEFAULT_CLOUD = 50;
const DEFAULT_RAIN = 20;

const isPercent = (v) => typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 100;

/** Tanggal kalender WIB "yyyy-MM-dd" dari Date. */
function wibDate(date) {
  return new Date(date.getTime() + 7 * HOUR_MS).toISOString().slice(0, 10);
}

/** Format jam WIB "HH:mm". */
function wibTime(date) {
  return new Date(date.getTime() + 7 * HOUR_MS).toISOString().slice(11, 16);
}

/**
 * Golden hour pada tanggal rencana. Jika tanggal di luar data cuaca (7 hari),
 * pakai jam hari pertama yang digeser ke tanggal tersebut (jam terbit/terbenam
 * di Yogyakarta hanya bergeser beberapa menit dalam sebulan).
 */
function goldenForDate(weather, plannedAt) {
  const target = wibDate(plannedAt);
  const toRange = (r) => ({ start: new Date(r.start), end: new Date(r.end) });
  const day = weather.days.find((d) => d.date === target);
  if (day) {
    return { morning: toRange(day.golden_morning), evening: toRange(day.golden_evening) };
  }
  const first = weather.days[0];
  const shift = Date.parse(`${target}T00:00:00+07:00`) - Date.parse(`${first.date}T00:00:00+07:00`);
  const shifted = (r) => ({
    start: new Date(Date.parse(r.start) + shift),
    end: new Date(Date.parse(r.end) + shift),
  });
  return { morning: shifted(first.golden_morning), evening: shifted(first.golden_evening) };
}

/** Prakiraan per jam terdekat (maks. selisih 1 jam). */
function nearestHour(weather, plannedAt) {
  let best = null;
  let bestDiff = HOUR_MS;
  for (const h of weather.hourly) {
    const diff = Math.abs(Date.parse(h.time) - plannedAt.getTime());
    if (diff <= bestDiff) {
      best = h;
      bestDiff = diff;
    }
  }
  return best;
}

// POST /ai/score { spot_id, photo_type, planned_at, cloud_cover?, rain_prob? }
router.post('/score', async (req, res) => {
  const { spot_id: spotId, photo_type: photoType, planned_at: plannedAtRaw } = req.body || {};
  const { cloud_cover: cloudInput, rain_prob: rainInput } = req.body || {};

  if (!Number.isInteger(spotId)) return fail(res, 400, 'spot_id wajib berupa angka');
  if (!PHOTO_TYPES.includes(photoType)) {
    return fail(res, 400, `photo_type tidak valid. Pilihan: ${PHOTO_TYPES.join(', ')}`);
  }
  const plannedAt = new Date(plannedAtRaw);
  if (typeof plannedAtRaw !== 'string' || Number.isNaN(plannedAt.getTime())) {
    return fail(res, 400, 'planned_at wajib berupa tanggal ISO 8601');
  }
  if (plannedAt.getTime() < Date.now() - DAY_MS || plannedAt.getTime() > Date.now() + 30 * DAY_MS) {
    return fail(res, 400, 'planned_at harus antara kemarin dan 30 hari ke depan');
  }
  for (const [name, v] of [['cloud_cover', cloudInput], ['rain_prob', rainInput]]) {
    if (v !== undefined && v !== null && !isPercent(v)) {
      return fail(res, 400, `${name} harus angka 0–100`);
    }
  }

  const { rows } = await db.query('SELECT * FROM spots WHERE id = $1', [spotId]);
  const spot = rows[0];
  if (!spot) return fail(res, 404, 'Spot tidak ditemukan');

  // Data cuaca spot (live / cache / estimasi) untuk golden hour & prakiraan per jam.
  const weather = await weatherService.getWeather(spot.latitude, spot.longitude);
  const golden = goldenForDate(weather, plannedAt);

  // Kondisi: input manual dari app (pilihan Cerah/Berawan/Hujan) menimpa data API.
  const hour = nearestHour(weather, plannedAt);
  const manual = isPercent(cloudInput) || isPercent(rainInput);
  const cloudCover = isPercent(cloudInput) ? cloudInput : hour?.cloud_cover ?? DEFAULT_CLOUD;
  const rainProb = isPercent(rainInput) ? rainInput : hour?.precipitation_probability ?? DEFAULT_RAIN;
  const conditionSource = manual ? 'manual' : hour ? 'forecast' : 'default';

  const result = calculateScore({ spot, photoType, plannedAt, cloudCover, rainProb, golden });

  const goldenText =
    `pagi ${wibTime(golden.morning.start)}–${wibTime(golden.morning.end)} WIB, ` +
    `sore ${wibTime(golden.evening.start)}–${wibTime(golden.evening.end)} WIB`;
  const { recommendation, source } = await getRecommendation({
    spot,
    photoType,
    plannedAtText: `${wibDate(plannedAt)} pukul ${wibTime(plannedAt)} WIB`,
    score: result.score,
    label: result.label,
    conditionsText: `awan ${Math.round(cloudCover)}%, peluang hujan ${Math.round(rainProb)}%`,
    goldenText,
  });

  return ok(res, {
    ...result,
    conditions: {
      cloud_cover: cloudCover,
      rain_prob: rainProb,
      source: conditionSource, // manual | forecast | default
      weather_source: weather.source, // live | cache | estimate
    },
    golden_hour: golden,
    recommendation,
    recommendation_source: source, // ai | template
  });
});

// ------------------------------------------------------------------ chat

const MAX_MESSAGE = 1000;
const MAX_HISTORY = 10;
const CONTEXT_KEYS = ['photo_type', 'planned_at', 'score', 'label', 'weather', 'golden_hour'];

/** Ambil hanya field konteks yang dikenal, dipotong pendek (mencegah prompt kebesaran). */
function sanitizeContext(context) {
  if (!context || typeof context !== 'object') return {};
  const clean = {};
  for (const key of CONTEXT_KEYS) {
    const v = context[key];
    if (typeof v === 'string' || typeof v === 'number') clean[key] = String(v).slice(0, 200);
  }
  return clean;
}

function buildSystemPrompt(spot, ctx) {
  const lines = [
    'Kamu adalah "PhotoQuest Assistant", asisten fotografi berbahasa Indonesia untuk fotografer pemula.',
    'Aturan:',
    '- Jawab singkat dan praktis (maksimal 6 kalimat atau 5 poin).',
    '- Fokus pada komposisi, cahaya, waktu pemotretan, dan teknik memotret dengan HP maupun kamera.',
    '- Jika pertanyaan di luar fotografi, tolak dengan sopan dan arahkan kembali ke fotografi.',
    '- Gunakan data konteks di bawah bila relevan; jangan mengarang data cuaca/skor yang tidak diberikan.',
  ];
  if (spot) {
    lines.push(
      '',
      'Konteks spot:',
      `- Nama: ${spot.name} (kategori ${spot.category})`,
      `- Deskripsi: ${spot.description}`,
      `- Waktu terbaik: ${spot.best_time}; cocok untuk: ${spot.photo_types.join(', ')}`,
      `- Tips: ${spot.tips || '-'}`
    );
  }
  const ctxLines = Object.entries(ctx).map(([k, v]) => `- ${k}: ${v}`);
  if (ctxLines.length) lines.push('', 'Konteks rencana pemotretan:', ...ctxLines);
  return lines.join('\n');
}

// POST /ai/chat { message, spot_id?, context?, history? }
router.post('/chat', async (req, res) => {
  const { message, spot_id: spotId, context, history } = req.body || {};
  if (typeof message !== 'string' || !message.trim()) return fail(res, 400, 'Pesan wajib diisi');
  if (message.length > MAX_MESSAGE) return fail(res, 400, `Pesan maksimal ${MAX_MESSAGE} karakter`);

  let spot = null;
  if (spotId !== undefined && spotId !== null) {
    if (!Number.isInteger(spotId)) return fail(res, 400, 'spot_id tidak valid');
    const { rows } = await db.query('SELECT * FROM spots WHERE id = $1', [spotId]);
    spot = rows[0] || null;
  }

  // Riwayat chat dikirim app (disimpan di memori app saja, tidak di database).
  const past = Array.isArray(history)
    ? history
        .filter((m) => m && ['user', 'assistant'].includes(m.role) && typeof m.text === 'string')
        .slice(-MAX_HISTORY)
        .map((m) => ({ role: m.role, text: m.text.slice(0, 2000) }))
    : [];

  try {
    const reply = await generateText({
      system: buildSystemPrompt(spot, sanitizeContext(context)),
      messages: [...past, { role: 'user', text: message.trim() }],
      temperature: 0.7,
    });
    return ok(res, { reply });
  } catch (err) {
    if (err instanceof LlmUnavailableError) {
      return fail(res, 503, 'Assistant sedang tidak tersedia, coba lagi');
    }
    throw err;
  }
});

module.exports = router;
module.exports._internal = { goldenForDate, nearestHour, sanitizeContext, buildSystemPrompt };
