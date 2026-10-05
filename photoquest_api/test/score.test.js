// Uji Shoot Condition Score (deterministik) dan validasi rekomendasi LLM.
const { test, describe } = require('node:test');
const assert = require('node:assert');

const {
  calculateScore,
  timingScore,
  cloudScore,
  rainScore,
  spotMatchScore,
  labelFor,
} = require('../src/services/scoreService');
const {
  getRecommendation,
  validateRecommendation,
  extractJson,
  TEMPLATES,
} = require('../src/services/recommendationService');
const { LlmUnavailableError } = require('../src/services/llmService');

const at = (hhmm) => new Date(`2026-10-10T${hhmm}:00+07:00`);
const GOLDEN = {
  morning: { start: at('05:21'), end: at('06:21') },
  evening: { start: at('16:32'), end: at('17:32') },
};
const SPOT = { category: 'landscape', photo_types: ['sunset', 'landscape'], best_time: 'sunset' };

describe('Timing cahaya (40)', () => {
  const t = (time, photoType = 'sunset', spotCategory = 'landscape') =>
    timingScore({ plannedAt: at(time), golden: GOLDEN, photoType, spotCategory }).score;

  test('Di dalam golden hour -> 40', () => {
    assert.strictEqual(t('17:00'), 40);
    assert.strictEqual(t('05:30'), 40);
  });

  test('Turun linear: 1 jam -> 30, ≥ 3 jam -> 10', () => {
    assert.strictEqual(t('18:32'), 30);
    assert.strictEqual(t('20:32'), 10);
    assert.strictEqual(t('23:59'), 10);
  });

  test('Tengah hari (11–14) maksimal 10 untuk lanskap, tidak untuk street', () => {
    // 13:45 berjarak 2,78 jam dari golden sore -> tanpa batas = 12,2
    assert.strictEqual(t('13:45', 'landscape'), 10);
    assert.strictEqual(t('13:45', 'street', 'street'), 12.2);
  });
});

describe('Tutupan awan (30)', () => {
  test('Lanskap/sunset ideal 20–60%', () => {
    assert.strictEqual(cloudScore(40, 'sunset').score, 30);
    assert.strictEqual(cloudScore(0, 'landscape').score, 20);
    assert.strictEqual(cloudScore(80, 'landscape').score, 17.5);
  });

  test('Street/arsitektur ideal 0–50%', () => {
    assert.strictEqual(cloudScore(0, 'street').score, 30);
    assert.strictEqual(cloudScore(50, 'architecture').score, 30);
    assert.strictEqual(cloudScore(75, 'street').score, 17.5);
  });

  test('Awan 100% = 5 poin untuk semua jenis foto', () => {
    for (const type of ['landscape', 'sunset', 'street', 'architecture', 'portrait']) {
      assert.strictEqual(cloudScore(100, type).score, 5, type);
    }
  });
});

test('Peluang hujan (20) = 20 × (1 − rain/100)', () => {
  assert.strictEqual(rainScore(0).score, 20);
  assert.strictEqual(rainScore(50).score, 10);
  assert.strictEqual(rainScore(100).score, 0);
});

test('Kecocokan spot (10): keduanya 10, salah satu 5, tidak ada 0', () => {
  const m = (photoType, time) => spotMatchScore({ spot: SPOT, photoType, plannedAt: at(time) }).score;
  assert.strictEqual(m('sunset', '17:00'), 10);
  assert.strictEqual(m('street', '17:00'), 5);
  assert.strictEqual(m('sunset', '07:00'), 5);
  assert.strictEqual(m('street', '07:00'), 0);
});

test('Label skor sesuai batas 80/60/40', () => {
  assert.strictEqual(labelFor(80), 'Sangat Baik');
  assert.strictEqual(labelFor(79), 'Baik');
  assert.strictEqual(labelFor(60), 'Baik');
  assert.strictEqual(labelFor(59), 'Cukup');
  assert.strictEqual(labelFor(40), 'Cukup');
  assert.strictEqual(labelFor(39), 'Kurang');
});

test('Skor total: kondisi ideal = 100, kondisi buruk < 40, dan deterministik', () => {
  const input = {
    spot: SPOT, photoType: 'sunset', plannedAt: at('17:00'), cloudCover: 40, rainProb: 0, golden: GOLDEN,
  };
  const best = calculateScore(input);
  assert.strictEqual(best.score, 100);
  assert.strictEqual(best.label, 'Sangat Baik');
  assert.deepStrictEqual(best.breakdown.map((b) => b.max), [40, 30, 20, 10]);
  assert.deepStrictEqual(calculateScore(input), best); // input sama -> hasil sama

  const worst = calculateScore({ ...input, plannedAt: at('12:30'), cloudCover: 100, rainProb: 90, photoType: 'street' });
  assert.ok(worst.score < 40, `skor ${worst.score}`);
  assert.strictEqual(worst.label, 'Kurang');
});

describe('Rekomendasi LLM: validasi JSON & fallback template', () => {
  const VALID = {
    composition: ['Rule of thirds', 'Foreground batu'],
    timing: 'Datang 16:00',
    position: 'Menghadap barat',
    stability: 'Pakai tripod',
    tips: ['Turunkan eksposur'],
  };
  const ctx = {
    spot: { name: 'Tebing Breksi', category: 'landscape', description: '-', tips: '-' },
    photoType: 'sunset', plannedAtText: '-', score: 90, label: 'Sangat Baik', conditionsText: '-', goldenText: '-',
  };

  test('JSON di dalam blok ```json``` tetap terbaca', () => {
    assert.deepStrictEqual(extractJson('```json\n{"a":1}\n```'), { a: 1 });
  });

  test('Field hilang / tipe salah -> ditolak', () => {
    assert.throws(() => validateRecommendation({ ...VALID, tips: 'bukan array' }));
    assert.throws(() => validateRecommendation({ ...VALID, timing: '' }));
    assert.throws(() => validateRecommendation([]));
  });

  test('LLM mengembalikan JSON valid -> source "ai"', async () => {
    const r = await getRecommendation(ctx, { generate: async () => JSON.stringify(VALID) });
    assert.strictEqual(r.source, 'ai');
    assert.deepStrictEqual(r.recommendation, VALID);
  });

  test('JSON rusak -> template sesuai jenis foto', async () => {
    const r = await getRecommendation(ctx, { generate: async () => '{"composition": [' });
    assert.strictEqual(r.source, 'template');
    assert.deepStrictEqual(r.recommendation, TEMPLATES.sunset);
  });

  test('LLM timeout/tidak tersedia -> template', async () => {
    const r = await getRecommendation(ctx, {
      generate: async () => { throw new LlmUnavailableError('LLM tidak merespons'); },
    });
    assert.strictEqual(r.source, 'template');
  });

  test('Semua template memenuhi format wajib', () => {
    for (const [type, t] of Object.entries(TEMPLATES)) {
      assert.doesNotThrow(() => validateRecommendation(t), type);
    }
  });
});
