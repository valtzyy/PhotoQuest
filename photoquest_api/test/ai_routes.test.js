// Uji route /ai/score, /ai/chat, /sessions dan request ke Gemini — TANPA internet.
// Key Gemini dikosongkan sebelum config dimuat (dotenv tidak menimpa env yang sudah ada),
// sehingga LLM dianggap tidak tersedia -> rekomendasi template & chat 503.
process.env.GEMINI_API_KEY = '';

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');

const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');
const weatherService = require('../src/services/weatherService');
const config = require('../src/config');
const { generateText } = require('../src/services/llmService');

let server;
let baseUrl;
let me;
let auth;
let spot;

// Cuaca palsu (tanpa Open-Meteo): estimasi + satu data per jam untuk besok 17:00 WIB.
const plannedIso = (() => {
  const d = new Date(Date.now() + 24 * 3600 * 1000 + 7 * 3600 * 1000);
  return `${d.toISOString().slice(0, 10)}T17:00:00+07:00`;
})();
const realGetWeather = weatherService.getWeather;

before(async () => {
  weatherService.getWeather = async () => {
    const w = weatherService.estimate(new Date());
    w.hourly = [{ time: plannedIso, cloud_cover: 40, precipitation_probability: 10 }];
    return w;
  };
  ({ server, baseUrl } = await startServer());
  me = await createTestUser(baseUrl, 'ai');
  auth = { Authorization: `Bearer ${me.token}`, 'Content-Type': 'application/json' };
  ({ rows: [spot] } = await db.query("SELECT * FROM spots WHERE name = 'Tebing Breksi'"));
});

after(async () => {
  weatherService.getWeather = realGetWeather;
  await deleteTestUser(me.email);
  server.close();
  await db.pool.end();
});

const post = async (path, body) => {
  const res = await fetch(`${baseUrl}${path}`, { method: 'POST', headers: auth, body: JSON.stringify(body) });
  return { status: res.status, body: await res.json() };
};

describe('POST /ai/score', () => {
  test('Skor + rincian + rekomendasi template saat LLM tidak tersedia', async () => {
    const r = await post('/ai/score', { spot_id: spot.id, photo_type: 'sunset', planned_at: plannedIso });
    assert.strictEqual(r.status, 200);
    const d = r.body.data;
    assert.ok(d.score >= 0 && d.score <= 100);
    assert.deepStrictEqual(d.breakdown.map((b) => b.key), ['timing', 'cloud', 'rain', 'spot']);
    assert.strictEqual(d.conditions.source, 'forecast');
    assert.strictEqual(d.conditions.cloud_cover, 40);
    assert.strictEqual(d.recommendation_source, 'template');
    assert.ok(Array.isArray(d.recommendation.composition));
    // 17:00 WIB ada di golden hour sore estimasi (16:45–17:45)
    assert.strictEqual(d.breakdown[0].score, 40);
  });

  test('Cuaca manual menimpa prakiraan', async () => {
    const r = await post('/ai/score', {
      spot_id: spot.id, photo_type: 'sunset', planned_at: plannedIso, cloud_cover: 95, rain_prob: 85,
    });
    assert.strictEqual(r.body.data.conditions.source, 'manual');
    assert.strictEqual(r.body.data.conditions.rain_prob, 85);
  });

  test('Validasi input -> 400 / 404', async () => {
    assert.strictEqual((await post('/ai/score', { photo_type: 'sunset', planned_at: plannedIso })).status, 400);
    assert.strictEqual((await post('/ai/score', { spot_id: spot.id, photo_type: 'selfie', planned_at: plannedIso })).status, 400);
    assert.strictEqual((await post('/ai/score', { spot_id: spot.id, photo_type: 'sunset', planned_at: 'besok' })).status, 400);
    assert.strictEqual((await post('/ai/score', { spot_id: spot.id, photo_type: 'sunset', planned_at: plannedIso, cloud_cover: 150 })).status, 400);
    assert.strictEqual((await post('/ai/score', { spot_id: 999999, photo_type: 'sunset', planned_at: plannedIso })).status, 404);
  });
});

describe('POST /ai/chat', () => {
  test('LLM tidak tersedia -> 503 dengan pesan ramah', async () => {
    const r = await post('/ai/chat', { message: 'Tips foto sunset?', spot_id: spot.id });
    assert.strictEqual(r.status, 503);
    assert.strictEqual(r.body.message, 'Assistant sedang tidak tersedia, coba lagi');
  });

  test('Pesan kosong / terlalu panjang -> 400', async () => {
    assert.strictEqual((await post('/ai/chat', { message: '  ' })).status, 400);
    assert.strictEqual((await post('/ai/chat', { message: 'a'.repeat(1001) })).status, 400);
  });
});

test('Request ke Gemini: header API key, role "model", JSON mode', async () => {
  const saved = { key: config.geminiApiKey, model: config.geminiModel };
  config.geminiApiKey = 'kunci-uji';
  config.geminiModel = 'gemini-uji';
  let captured;
  const fakeHttp = {
    post: async (url, body, options) => {
      captured = { url, body, options };
      return { data: { candidates: [{ content: { parts: [{ text: '{"ok":true}' }] } }] } };
    },
  };
  try {
    const text = await generateText({
      system: 'sistem',
      messages: [{ role: 'user', text: 'halo' }, { role: 'assistant', text: 'hai' }, { role: 'user', text: 'tips?' }],
      json: true,
      http: fakeHttp,
    });
    assert.strictEqual(text, '{"ok":true}');
    assert.match(captured.url, /\/models\/gemini-uji:generateContent$/);
    assert.ok(!captured.url.includes('kunci-uji'), 'API key tidak boleh ada di URL');
    assert.strictEqual(captured.options.headers['x-goog-api-key'], 'kunci-uji');
    assert.strictEqual(captured.options.timeout, config.externalTimeoutMs);
    assert.deepStrictEqual(captured.body.contents.map((c) => c.role), ['user', 'model', 'user']);
    assert.strictEqual(captured.body.generationConfig.responseMimeType, 'application/json');
    assert.strictEqual(captured.body.systemInstruction.parts[0].text, 'sistem');
  } finally {
    config.geminiApiKey = saved.key;
    config.geminiModel = saved.model;
  }
});

describe('/sessions', () => {
  test('Simpan sesi lalu tampil di daftar', async () => {
    const created = await post('/sessions', {
      spot_id: spot.id, photo_type: 'sunset', planned_at: plannedIso, score: 88,
      recommendation: { timing: 'tes' },
    });
    assert.strictEqual(created.status, 201);
    const list = await (await fetch(`${baseUrl}/sessions`, { headers: auth })).json();
    assert.strictEqual(list.data[0].spot_name, 'Tebing Breksi');
    assert.strictEqual(list.data[0].score, 88);
    assert.deepStrictEqual(list.data[0].recommendation, { timing: 'tes' });
  });

  test('Skor di luar 0–100 -> 400', async () => {
    const r = await post('/sessions', { spot_id: spot.id, photo_type: 'sunset', planned_at: plannedIso, score: 150 });
    assert.strictEqual(r.status, 400);
  });
});
