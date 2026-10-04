// Uji weatherService tanpa internet (fetcher & waktu dipalsukan) + validasi route.
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');

const {
  createWeatherService,
  fromOpenMeteo,
  estimate,
  describeWeatherCode,
} = require('../src/services/weatherService');
const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');

// Contoh respons Open-Meteo (format sama dengan respons asli).
const RAW = {
  timezone: 'Asia/Jakarta',
  utc_offset_seconds: 25200,
  current: { time: '2026-10-04T15:00', temperature_2m: 30.1, cloud_cover: 40, weather_code: 2 },
  daily: {
    time: ['2026-10-04', '2026-10-05'],
    sunrise: ['2026-10-04T05:21', '2026-10-05T05:21'],
    sunset: ['2026-10-04T17:32', '2026-10-05T17:32'],
  },
  hourly: {
    time: ['2026-10-04T16:00', '2026-10-04T17:00'],
    cloud_cover: [35, 50],
    precipitation_probability: [10, 20],
  },
};

describe('fromOpenMeteo & golden hour', () => {
  const data = fromOpenMeteo(RAW, new Date('2026-10-04T08:00:00Z'));

  test('Waktu lokal diberi offset +07:00', () => {
    assert.strictEqual(data.days[0].sunrise, '2026-10-04T05:21:00+07:00');
    assert.strictEqual(data.hourly[0].time, '2026-10-04T16:00:00+07:00');
  });

  test('Golden hour pagi = sunrise s/d sunrise + 60 menit', () => {
    assert.deepStrictEqual(data.days[0].golden_morning, {
      start: '2026-10-04T05:21:00+07:00',
      end: '2026-10-04T06:21:00+07:00',
    });
  });

  test('Golden hour sore = sunset - 60 menit s/d sunset', () => {
    assert.deepStrictEqual(data.days[0].golden_evening, {
      start: '2026-10-04T16:32:00+07:00',
      end: '2026-10-04T17:32:00+07:00',
    });
  });

  test('Cuaca saat ini + deskripsi kode WMO', () => {
    assert.strictEqual(data.source, 'live');
    assert.strictEqual(data.current.temperature, 30.1);
    assert.strictEqual(data.current.description, 'Berawan sebagian');
    assert.strictEqual(describeWeatherCode(63), 'Hujan');
  });
});

test('Estimasi: sunrise 05:30 & sunset 17:45 WIB, ditandai is_estimate', () => {
  // 20:00 UTC = 03:00 WIB tanggal berikutnya -> tanggal harus mengikuti WIB
  const e = estimate(new Date('2026-10-04T20:00:00Z'));
  assert.strictEqual(e.source, 'estimate');
  assert.strictEqual(e.is_estimate, true);
  assert.strictEqual(e.days[0].date, '2026-10-05');
  assert.strictEqual(e.days[0].sunrise, '2026-10-05T05:30:00+07:00');
  assert.strictEqual(e.days[0].golden_evening.start, '2026-10-05T16:45:00+07:00');
  assert.strictEqual(e.days.length, 7);
});

describe('getWeather: cache 30 menit & fallback', () => {
  function setup(fetcherImpl) {
    let clock = new Date('2026-10-04T08:00:00Z').getTime();
    let calls = 0;
    const svc = createWeatherService({
      fetcher: async (params) => {
        calls++;
        return fetcherImpl(params);
      },
      now: () => new Date(clock),
    });
    return {
      svc,
      calls: () => calls,
      advance: (ms) => { clock += ms; },
    };
  }

  test('Panggilan kedua < 30 menit memakai cache (Open-Meteo tidak dipanggil lagi)', async () => {
    const t = setup(async () => RAW);
    assert.strictEqual((await t.svc.getWeather(-7.7829, 110.3671)).source, 'live');
    t.advance(10 * 60 * 1000);
    assert.strictEqual((await t.svc.getWeather(-7.7831, 110.3669)).source, 'cache'); // ~sama setelah dibulatkan
    assert.strictEqual(t.calls(), 1);
  });

  test('Setelah 30 menit -> ambil ulang', async () => {
    const t = setup(async () => RAW);
    await t.svc.getWeather(-7.78, 110.36);
    t.advance(31 * 60 * 1000);
    assert.strictEqual((await t.svc.getWeather(-7.78, 110.36)).source, 'live');
    assert.strictEqual(t.calls(), 2);
  });

  test('API gagal + ada cache lama -> pakai cache lama', async () => {
    let fail = false;
    const t = setup(async () => {
      if (fail) throw new Error('timeout of 8000ms exceeded');
      return RAW;
    });
    await t.svc.getWeather(-7.78, 110.36);
    t.advance(2 * 60 * 60 * 1000); // 2 jam, cache sudah kedaluwarsa
    fail = true;
    const r = await t.svc.getWeather(-7.78, 110.36);
    assert.strictEqual(r.source, 'cache');
    assert.strictEqual(r.days[0].sunrise, '2026-10-04T05:21:00+07:00');
  });

  test('API gagal + tanpa cache -> estimasi', async () => {
    const t = setup(async () => { throw new Error('ENOTFOUND'); });
    const r = await t.svc.getWeather(-7.78, 110.36);
    assert.strictEqual(r.source, 'estimate');
    assert.strictEqual(r.is_estimate, true);
  });
});

describe('GET /weather (validasi)', () => {
  let server;
  let baseUrl;
  let me;

  before(async () => {
    ({ server, baseUrl } = await startServer());
    me = await createTestUser(baseUrl, 'weather');
  });

  after(async () => {
    await deleteTestUser(me.email);
    server.close();
    await db.pool.end();
  });

  test('Tanpa token -> 401', async () => {
    assert.strictEqual((await fetch(`${baseUrl}/weather?lat=-7.7&lng=110.3`)).status, 401);
  });

  test('lat/lng tidak valid -> 400', async () => {
    const auth = { Authorization: `Bearer ${me.token}` };
    for (const q of ['', '?lat=abc&lng=110', '?lat=-95&lng=110', '?lat=-7.7']) {
      const res = await fetch(`${baseUrl}/weather${q}`, { headers: auth });
      assert.strictEqual(res.status, 400, `query "${q}" seharusnya 400`);
    }
  });
});
