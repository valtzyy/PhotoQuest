// Uji kurs (tanpa internet: fetcher dipalsukan) dan endpoint /currency & /gear.
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');

const { createCurrencyService, crossRates, FALLBACK } = require('../src/services/currencyService');
const currencyService = require('../src/services/currencyService');
const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');

const EUR_TABLE = { date: '2026-10-02', rates: { IDR: 20000, USD: 1.25, JPY: 160 } };

test('Kurs silang dari base EUR: 1 USD = IDR/USD', () => {
  const r = crossRates({ EUR: 1, IDR: 20000, USD: 1.25, JPY: 160 }, 'USD');
  assert.strictEqual(r.USD, 1);
  assert.strictEqual(r.IDR, 16000); // 20000 / 1.25
  assert.strictEqual(r.JPY, 128);
});

test('Base IDR: rates[X] = X per 1 rupiah', () => {
  const r = crossRates({ EUR: 1, IDR: 20000, USD: 1.25, JPY: 160 }, 'IDR');
  assert.strictEqual(r.IDR, 1);
  assert.strictEqual(r.EUR, 1 / 20000);
  assert.ok(Math.abs(1_000_000 * r.USD - 62.5) < 1e-9); // Rp1jt = $62,50
});

describe('getRates: cache 6 jam & fallback', () => {
  function setup(fetcherImpl) {
    let clock = Date.parse('2026-10-05T00:00:00Z');
    let calls = 0;
    const svc = createCurrencyService({
      fetcher: async () => { calls++; return fetcherImpl(); },
      now: () => new Date(clock),
    });
    return { svc, calls: () => calls, advance: (ms) => { clock += ms; } };
  }

  test('Live lalu cache (< 6 jam), ambil ulang setelah 6 jam', async () => {
    const t = setup(async () => EUR_TABLE);
    assert.strictEqual((await t.svc.getRates('IDR')).source, 'live');
    t.advance(5 * 3600 * 1000);
    assert.strictEqual((await t.svc.getRates('USD')).source, 'cache');
    assert.strictEqual(t.calls(), 1);
    t.advance(2 * 3600 * 1000);
    assert.strictEqual((await t.svc.getRates('IDR')).source, 'live');
    assert.strictEqual(t.calls(), 2);
  });

  test('API gagal + ada cache lama -> pakai cache lama', async () => {
    let fail = false;
    const t = setup(async () => { if (fail) throw new Error('timeout'); return EUR_TABLE; });
    await t.svc.getRates();
    t.advance(24 * 3600 * 1000);
    fail = true;
    const r = await t.svc.getRates();
    assert.strictEqual(r.source, 'cache');
    assert.strictEqual(r.rates.USD, 1.25 / 20000);
  });

  test('API gagal + tanpa cache -> kurs tetap, source "fallback"', async () => {
    const t = setup(async () => { throw new Error('ENOTFOUND'); });
    const r = await t.svc.getRates('IDR');
    assert.strictEqual(r.source, 'fallback');
    assert.strictEqual(r.date, FALLBACK.date);
    assert.strictEqual(r.rates.IDR, 1);
  });

  test('Respons tanpa kurs IDR dianggap gagal -> fallback', async () => {
    const t = setup(async () => ({ date: 'x', rates: { USD: 1.1 } }));
    assert.strictEqual((await t.svc.getRates()).source, 'fallback');
  });
});

describe('GET /currency & /gear', () => {
  let server;
  let baseUrl;
  let me;
  let auth;
  const realGetRates = currencyService.getRates;

  before(async () => {
    // Tanpa internet: pakai service dengan fetcher palsu.
    currencyService.getRates = createCurrencyService({ fetcher: async () => EUR_TABLE }).getRates;
    ({ server, baseUrl } = await startServer());
    me = await createTestUser(baseUrl, 'currency');
    auth = { Authorization: `Bearer ${me.token}` };
  });

  after(async () => {
    currencyService.getRates = realGetRates;
    await deleteTestUser(me.email);
    server.close();
    await db.pool.end();
  });

  test('Kurs IDR -> USD/EUR/JPY', async () => {
    const body = await (await fetch(`${baseUrl}/currency?base=idr`, { headers: auth })).json();
    assert.strictEqual(body.data.base, 'IDR');
    assert.deepStrictEqual(Object.keys(body.data.rates).sort(), ['EUR', 'IDR', 'JPY', 'USD']);
  });

  test('Base tidak didukung -> 400', async () => {
    assert.strictEqual((await fetch(`${baseUrl}/currency?base=GBP`, { headers: auth })).status, 400);
  });

  test('Daftar gear seed (urut harga)', async () => {
    const body = await (await fetch(`${baseUrl}/gear`, { headers: auth })).json();
    assert.ok(body.data.length >= 5);
    const prices = body.data.map((g) => g.price_idr);
    assert.deepStrictEqual(prices, [...prices].sort((a, b) => a - b));
  });

  test('Tanpa token -> 401', async () => {
    assert.strictEqual((await fetch(`${baseUrl}/gear`)).status, 401);
  });
});
