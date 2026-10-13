// Uji model cadangan Gemini: pindah model saat gangguan sementara,
// tidak pindah saat error konfigurasi, dan menghormati anggaran waktu total.
const { test, describe, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const config = require('../src/config');
const { generateText, LlmUnavailableError } = require('../src/services/llmService');
const { getRecommendation } = require('../src/services/recommendationService');

/** Error mirip axios: dengan respons HTTP (status) atau tanpa (timeout). */
const httpError = (status, message = 'error') =>
  Object.assign(new Error(`Request failed with status code ${status}`), {
    response: { status, data: { error: { message } } },
  });
const timeoutError = (ms) => Object.assign(new Error(`timeout of ${ms}ms exceeded`), { code: 'ECONNABORTED' });

const okResponse = (text) => ({ data: { candidates: [{ content: { parts: [{ text }] } }] } });

/**
 * HTTP palsu: `plan` memetakan nama model -> { ms, result | error }.
 * Jam palsu maju sebanyak `ms` setiap panggilan.
 */
function fakeHttp(plan) {
  const clock = { t: 0 };
  const calls = [];
  const http = {
    post: async (url, _body, options) => {
      const model = decodeURIComponent(url.match(/\/models\/([^:]+):/)[1]);
      calls.push({ model, timeout: options.timeout });
      const step = plan[model];
      clock.t += step.ms ?? 100;
      if (step.error) throw step.error;
      return okResponse(step.text);
    },
  };
  return { http, calls, now: () => clock.t };
}

const ask = (fake, extra = {}) =>
  generateText({
    system: 's',
    messages: [{ role: 'user', text: 'halo' }],
    http: fake.http,
    now: fake.now,
    ...extra,
  });

describe('Model cadangan Gemini', () => {
  let saved;
  beforeEach(() => {
    saved = {
      key: config.geminiApiKey,
      model: config.geminiModel,
      fallbacks: config.geminiFallbackModels,
      timeout: config.externalTimeoutMs,
      budget: config.llmTotalTimeoutMs,
    };
    config.geminiApiKey = 'kunci-uji';
    config.geminiModel = 'utama';
    config.geminiFallbackModels = ['cadangan-1', 'cadangan-2'];
    config.externalTimeoutMs = 8000;
    config.llmTotalTimeoutMs = 12000;
  });
  afterEach(() => {
    config.geminiApiKey = saved.key;
    config.geminiModel = saved.model;
    config.geminiFallbackModels = saved.fallbacks;
    config.externalTimeoutMs = saved.timeout;
    config.llmTotalTimeoutMs = saved.budget;
  });

  test('503 (high demand) di model utama -> dijawab model cadangan', async () => {
    const fake = fakeHttp({
      utama: { ms: 300, error: httpError(503, 'high demand') },
      'cadangan-1': { text: 'jawaban cadangan' },
    });
    assert.strictEqual(await ask(fake), 'jawaban cadangan');
    assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama', 'cadangan-1']);
  });

  test('timeout di model utama -> dijawab model cadangan dengan sisa anggaran', async () => {
    const fake = fakeHttp({
      utama: { ms: 8000, error: timeoutError(8000) },
      'cadangan-1': { text: 'ok' },
    });
    assert.strictEqual(await ask(fake), 'ok');
    // Percobaan kedua dibatasi sisa anggaran: 12000 - 8000 = 4000 ms.
    assert.deepStrictEqual(fake.calls.map((c) => c.timeout), [8000, 4000]);
  });

  test('404 / 429 / 500 juga dianggap gangguan sementara', async () => {
    for (const status of [404, 429, 500]) {
      const fake = fakeHttp({
        utama: { error: httpError(status) },
        'cadangan-1': { text: `ok ${status}` },
      });
      assert.strictEqual(await ask(fake), `ok ${status}`);
    }
  });

  test('401/403/400 (key/permintaan salah) -> tidak mencoba cadangan', async () => {
    for (const status of [400, 401, 403]) {
      const fake = fakeHttp({ utama: { error: httpError(status) }, 'cadangan-1': { text: 'x' } });
      await assert.rejects(ask(fake), (err) => err instanceof LlmUnavailableError && err.message === `LLM error ${status}`);
      assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama']);
    }
  });

  test('respons kosong (mis. diblokir filter) -> tidak mencoba cadangan', async () => {
    const fake = fakeHttp({ utama: { text: '' }, 'cadangan-1': { text: 'x' } });
    await assert.rejects(ask(fake), LlmUnavailableError);
    assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama']);
  });

  test('semua model gagal -> LlmUnavailableError setelah mencoba semuanya', async () => {
    const fake = fakeHttp({
      utama: { error: httpError(503) },
      'cadangan-1': { error: httpError(503) },
      'cadangan-2': { error: httpError(429) },
    });
    await assert.rejects(ask(fake), (err) => err instanceof LlmUnavailableError && err.message === 'LLM error 429');
    assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama', 'cadangan-1', 'cadangan-2']);
  });

  test('sisa anggaran < 1,5 dtk -> cadangan tidak dicoba', async () => {
    const fake = fakeHttp({
      utama: { ms: 11000, error: timeoutError(8000) },
      'cadangan-1': { text: 'terlambat' },
    });
    await assert.rejects(ask(fake), (err) => err.message === 'LLM tidak merespons');
    assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama']);
  });

  test('budgetMs dari pemanggil membatasi total waktu', async () => {
    const fake = fakeHttp({
      utama: { ms: 5000, error: httpError(503) },
      'cadangan-1': { text: 'ok' },
    });
    assert.strictEqual(await ask(fake, { budgetMs: 8000 }), 'ok');
    assert.deepStrictEqual(fake.calls.map((c) => c.timeout), [8000, 3000]);
  });

  test('model duplikat / kosong di daftar diabaikan', async () => {
    config.geminiFallbackModels = ['utama', '', 'cadangan-1', 'cadangan-1'];
    const fake = fakeHttp({
      utama: { error: httpError(503) },
      'cadangan-1': { error: httpError(503) },
    });
    await assert.rejects(ask(fake), LlmUnavailableError);
    assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama', 'cadangan-1']);
  });

  test('tanpa cadangan -> perilaku lama (satu percobaan)', async () => {
    config.geminiFallbackModels = [];
    const fake = fakeHttp({ utama: { error: httpError(503) } });
    await assert.rejects(ask(fake), LlmUnavailableError);
    assert.deepStrictEqual(fake.calls.map((c) => c.model), ['utama']);
  });
});

test('Rekomendasi Plan memakai anggaran LLM = EXTERNAL_TIMEOUT_MS (cuaca sudah ≤ 8 dtk)', async () => {
  let received;
  await getRecommendation(
    {
      spot: { name: 'Uji', category: 'landscape', description: '-', tips: '-' },
      photoType: 'sunset', plannedAtText: '-', score: 90, label: 'Sangat Baik', conditionsText: '-', goldenText: '-',
    },
    {
      generate: async (args) => {
        received = args;
        throw new LlmUnavailableError('uji');
      },
    }
  );
  assert.strictEqual(received.budgetMs, config.externalTimeoutMs);
});
